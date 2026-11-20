"""A38 AI review calls in the admin panel: health of the voice provider, numbers, settings, script, log."""

import uuid
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import now
from app.models import AiCall, Company, ReviewRequest
from app.providers.voice import get_voice
from app.schemas.admin_ai_calls import (
    AdminAiCallKpis,
    AdminAiCallRow,
    AdminAiCallSettings,
    AdminAiCallsOut,
    AdminCallScript,
    AdminScriptStep,
    AdminTestCallOut,
    AdminVoiceProvider,
)
from app.schemas.admin_companies import AdminOption
from app.services import ai_calls, audit, platform

INSTEAD = ("no_provider_sms", "failed_sms", "no_credits_sms", "not_sent")  # no call was placed
NOT_PLACED = (*INSTEAD, "skipped_dnd")
ANSWERED = ("rated", "call_back", "opted_out", "wrong_person")


def _script(s: platform.AiCallScript) -> AdminCallScript:
    return AdminCallScript(
        version=s.version,
        opening=platform.OPENING,
        steps=[AdminScriptStep(key=x.key, text=x.text) for x in s.steps],
    )


async def page(db: AsyncSession, *, page: int, page_size: int, can_act: bool) -> AdminAiCallsOut:
    t = now()
    voice = get_voice()
    status = await platform.voice_status(db)
    waiting = int(
        await db.scalar(
            select(func.count()).where(
                ReviewRequest.status.in_(ai_calls.DUE), ReviewRequest.ai_call_at.is_not(None),
                ReviewRequest.ai_call_at <= t,
            )
        ) or 0
    )  # fmt: skip

    since = t - timedelta(days=30)
    recent = AiCall.at >= since
    placed_q = recent & AiCall.outcome.not_in(NOT_PLACED)
    placed, answered, rated, opted, cost = (
        await db.execute(
            select(
                func.count(),
                func.count().filter(AiCall.outcome.in_(ANSWERED)),
                func.count().filter(AiCall.outcome == "rated"),
                func.count().filter(AiCall.outcome == "opted_out"),
                func.coalesce(func.sum(AiCall.cost_usd), 0),
            ).where(placed_q)
        )
    ).one()
    instead = int(await db.scalar(select(func.count()).where(recent, AiCall.outcome.in_(INSTEAD))) or 0)

    total = int(await db.scalar(select(func.count()).select_from(AiCall)) or 0)
    rows = (
        await db.execute(
            select(AiCall, Company.name)
            .join(Company, Company.id == AiCall.company_id)
            .order_by(AiCall.at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()
    ps = await platform.ai_call_settings(db)
    return AdminAiCallsOut(
        provider=AdminVoiceProvider(
            connected=voice is not None, name=voice.name if voice else None,
            down_since=status.get("down_since") if voice else None, waiting=waiting,
        ),
        kpis=AdminAiCallKpis(
            calls=placed, answered=round(answered / placed, 4) if placed else None,
            rated=round(rated / answered, 4) if answered else None,
            opted_out=round(opted / placed, 4) if placed else None,
            cost_per_call_usd=round(float(cost) / placed, 4) if placed else None, sms_instead=instead,
        ),
        settings=AdminAiCallSettings(**ps.model_dump()),
        script=_script(await platform.ai_call_script(db)),
        calls=[
            AdminAiCallRow(
                id=c.id, at=c.at, company=AdminOption(value=str(c.company_id), label=name),
                contact_name=c.contact_name, place=c.place, language=c.language, seconds=c.seconds,
                outcome=c.outcome, rating=c.rating, wants_call_back=c.wants_call_back,
                callback_at=c.callback_at, cost_usd=c.cost_usd,
            )
            for c, name in rows
        ],
        total=total, page=page, page_size=page_size, can_act=can_act,
    )  # fmt: skip


async def save_settings(
    db: AsyncSession, body: AdminAiCallSettings, *, staff_id: uuid.UUID, ip: str | None
) -> AdminAiCallSettings:
    before = await platform.ai_call_settings(db)
    after = platform.AiCallSettings(**body.model_dump(exclude={"skip_dnd", "only_if_no_rating"}))
    await platform.set_ai_call_settings(db, after, staff_id=staff_id)
    changed = {k: v for k, v in after.model_dump().items() if getattr(before, k) != v}
    if changed:
        await audit.record(db, "staff.ai_call_settings_updated", staff_id=staff_id, target_type="platform",
                           data=changed, ip=ip)  # fmt: skip
    return AdminAiCallSettings(**after.model_dump())


async def save_step(
    db: AsyncSession, key: str, text: str, *, staff_id: uuid.UUID, ip: str | None
) -> AdminCallScript:
    if key not in {k for k, _ in platform.SCRIPT_STEPS}:
        raise AppError("not_found", "That script step doesn't exist.", status=404)
    if key == "greeting" and "{job}" not in text:
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"text": "needs_job"}, status=422
        )
    out = await platform.set_script_step(db, key, text, staff_id=staff_id)
    await audit.record(db, "staff.ai_call_script_updated", staff_id=staff_id, target_type="platform",
                       data={"step": key, "version": out.version}, ip=ip)  # fmt: skip
    return _script(out)


async def test(db: AsyncSession, phone: str, *, staff_id: uuid.UUID, ip: str | None) -> AdminTestCallOut:
    r = await ai_calls.test_call(db, phone)
    if r is None:
        raise AppError("no_voice_provider", "No voice provider is connected, so calls can't be placed yet.",
                       status=409)  # fmt: skip
    await audit.record(db, "staff.ai_call_test", staff_id=staff_id, target_type="platform",
                       data={"outcome": r.outcome}, ip=ip)  # fmt: skip
    return AdminTestCallOut(outcome=r.outcome, seconds=r.seconds)
