"""A38 Day 5 AI review call: for jobs still without a rating, an AI voice agent calls the customer.

No voice provider is connected yet (D-115): a due call then sends the rating link by SMS instead and the
call log says "no voice provider". When a provider is added (providers/voice.py) the same step places
real calls. Calls only go during the calling hours in the company's time zone, never to a job that is
already rated or where the customer opted out, and every call starts with the AI and recording notice.
"""

import logging
import uuid
from datetime import UTC, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import (
    AiCall,
    Company,
    Customer,
    CustomerContact,
    Job,
    Report,
    ReviewRequest,
    ReviewRequestEvent,
)
from app.providers.voice import CallRequest, CallResult, get_voice
from app.services import credits, platform
from app.services.review_office import send_link
from app.services.reviews import _zone, from_call, settings_for

log = logging.getLogger(__name__)

DUE = ("link_sent", "reminded")


def _window(hours: str) -> tuple[int, int]:
    a, b = hours.split("-")
    return int(a), int(b)


def next_window(company: Company, hours: str, t: datetime) -> datetime | None:
    """None when [t] is inside the calling hours; otherwise when they next open (company's time zone)."""
    zone = _zone(company)
    local = t.astimezone(zone)
    start, end = _window(hours)
    if start <= local.hour < end:
        return None
    day = local.date() + (timedelta(days=1) if local.hour >= end else timedelta())
    return datetime.combine(day, time(start, 0), tzinfo=zone).astimezone(UTC)


async def _log(db: AsyncSession, req: ReviewRequest, company: Company, outcome: str, **kw) -> AiCall:
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    job = await db.get(Job, req.job_id)
    customer = await db.get(Customer, job.customer_id) if job else None
    call = AiCall(
        company_id=company.id, request_id=req.id, contact_name=contact.name if contact else None,
        place=customer.name if customer else None, phone=contact.phone if contact else None,
        outcome=outcome, **kw,
    )  # fmt: skip
    db.add(call)
    return call


async def _sms_instead(db: AsyncSession, req: ReviewRequest) -> bool:
    done, _ = await send_link(db, req, ["sms"], "reminder")
    return bool(done)


async def call_due(db: AsyncSession, company_id: uuid.UUID | None = None, at: datetime | None = None) -> int:
    """Run every Day 5 call that is due (one company, or all). Returns how many were handled."""
    t = at or now()
    q = select(ReviewRequest).where(
        ReviewRequest.status.in_(DUE), ReviewRequest.ai_call_at.is_not(None), ReviewRequest.ai_call_at <= t
    )
    if company_id:
        q = q.where(ReviewRequest.company_id == company_id)
    rows = (await db.execute(q.with_for_update(skip_locked=True))).scalars().all()
    if not rows:
        return 0
    ps = await platform.ai_call_settings(db)
    script = await platform.ai_call_script(db)
    handled = 0
    for req in rows:
        company = await db.get(Company, req.company_id)
        s = await settings_for(db, req.company_id)
        if not s.ai_call_enabled or company.status == "suspended":
            req.ai_call_at = None  # the company turned calls off: don't keep looking at it
            continue
        later = next_window(company, ps.hours, t)
        if later:
            req.ai_call_at = later  # outside calling hours: wait for the window
            continue
        handled += 1
        req.ai_call_at = None
        await _one(db, req, company, ps, script, t)
    await db.flush()
    return handled


async def _one(db, req, company, ps, script, t) -> None:
    rep = await db.get(Report, req.report_id)
    lang = (rep.language if rep and ps.language == "report" else "en") or "en"
    voice = get_voice()
    if voice is None:
        sent = await _sms_instead(db, req)
        await _log(db, req, company, "no_provider_sms" if sent else "not_sent", language=lang)
        if req.status in DUE:
            req.status = "ai_call_done"
        return
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    if not (contact and contact.phone):
        await _log(db, req, company, "not_sent", language=lang, error="no phone number")
        req.status = "ai_call_done"
        return
    if not await credits.can_spend(db, company, "ai_call"):
        sent = await _sms_instead(db, req)
        await _log(db, req, company, "no_credits_sms" if sent else "not_sent", language=lang)
        req.status = "ai_call_done"
        return
    job = await db.get(Job, req.job_id)
    call = CallRequest(
        to=contact.phone, language=lang, voice=ps.voice, record=ps.record,
        opening=platform.OPENING.format(company=company.name),
        steps=_steps(script, job.title, (job.completed_at or req.created_at).date().isoformat()),
        voicemail=ps.attempts != "call_only",
    )  # fmt: skip
    try:
        result: CallResult = await voice.call(call)
    except Exception as e:  # noqa: BLE001 - the provider is down: the customer still gets the link
        log.warning("voice provider failed: %s", e)
        if not (await platform.voice_status(db)).get("down_since"):
            await platform.set_voice_down(db, t.isoformat())
        sent = await _sms_instead(db, req)
        await _log(db, req, company, "failed_sms" if sent else "not_sent", language=lang, provider=voice.name,
                   error=f"{type(e).__name__}: {e}"[:300], script_version=script.version)  # fmt: skip
        req.status = "ai_call_done"
        return
    if (await platform.voice_status(db)).get("down_since"):
        await platform.set_voice_down(db, None)
    await _record(db, req, company, result, lang, voice.name, script.version, ps, t)


async def _record(db, req, company, r: CallResult, lang, provider, version, ps, t) -> None:
    outcome = {"voicemail": "voicemail_sms", "dnd": "skipped_dnd"}.get(r.outcome, r.outcome)
    charged = r.outcome not in ("dnd",)
    if charged:
        await credits.spend(db, company, "ai_call", "ai_call", req.id)
    db.add(ReviewRequestEvent(request_id=req.id, step="ai_call", channel="voice", status=outcome,
                              credits_used=credits.COST["ai_call"] if charged else 0))  # fmt: skip
    callback_at = None
    req.status = "ai_call_done"
    if r.outcome == "rated" and r.rating:
        await from_call(db, req, rating=r.rating, comment=r.comment, wants_call_back=r.wants_call_back,
                        public_allowed=r.public_allowed)  # fmt: skip
    elif r.outcome in ("voicemail", "no_answer"):
        if ps.attempts == "two_calls" and r.outcome == "no_answer":
            req.status, req.ai_call_at = "reminded", t + timedelta(days=1)  # one more try tomorrow
            outcome = "no_answer"
        elif not await _sms_instead(db, req):
            outcome = "no_answer"
    elif r.outcome == "call_back" and r.callback_in_minutes:
        callback_at = t + timedelta(minutes=r.callback_in_minutes)
        req.status, req.ai_call_at = "reminded", callback_at
    elif r.outcome == "opted_out":
        req.status, req.opted_out_at, req.opt_out_source = "opted_out", t, "call"
        db.add(ReviewRequestEvent(request_id=req.id, step="opted_out", channel="call"))
    elif r.outcome == "wrong_person":
        req.status, req.stopped_reason = "stopped", "wrong_contact"
    await _log(
        db, req, company, outcome, language=lang, rating=r.rating, wants_call_back=r.wants_call_back,
        callback_at=callback_at, seconds=r.seconds, cost_usd=r.cost_usd, provider=provider,
        provider_call_id=r.provider_call_id, transcript=r.transcript if ps.record else None,
        script_version=version,
    )  # fmt: skip


def _steps(script, job: str, day: str) -> list[dict]:
    return [{"key": x.key, "text": x.text.replace("{job}", job).replace("{date}", day)} for x in script.steps]


async def test_call(db: AsyncSession, phone: str, *, language: str = "en") -> CallResult | None:
    """A38 "Test call to my phone": the live script, to staff's own phone. None when no provider."""
    voice = get_voice()
    if voice is None:
        return None
    ps = await platform.ai_call_settings(db)
    script = await platform.ai_call_script(db)
    req = CallRequest(
        to=phone, language=language, voice=ps.voice, record=False, test=True,
        opening=platform.OPENING.format(company="KaamNishaan"), steps=_steps(script, "AC service", "today"),
    )  # fmt: skip
    return await voice.call(req)
