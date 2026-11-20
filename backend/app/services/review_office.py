"""The office side of reviews: customer reviews with replies and low-rating follow-ups (M45), where each
request stands (M45 requests), the settings (M46) and the Day 2 reminder sender.

Reminders go out when they are due. There is no always-on worker on the free server, so they are sent
when the office opens the reviews screens and when POST /cron/review-followups is called (any scheduler).
The Day 5 AI call waits for a voice provider: it stays planned and is never claimed as made.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import Forbidden, NotFound
from app.core.security import now
from app.models import (
    Company,
    Customer,
    CustomerContact,
    Job,
    Report,
    Review,
    ReviewFollowup,
    ReviewReply,
    ReviewRequest,
    ReviewRequestEvent,
    ReviewSettings,
    ShareLink,
    User,
)
from app.providers.storage import get_storage
from app.schemas.reviews import (
    CompanyReviewItem,
    FollowupIn,
    FollowupOut,
    ReplyOut,
    RequestCounts,
    RequestItem,
    RequestsPage,
    ReviewCounts,
    ReviewSettingsIn,
    ReviewSettingsOut,
    ReviewsPage,
    SuggestionOut,
)
from app.schemas.work import PersonRef
from app.services import audit, credits, sharing
from app.services.report_labels import label
from app.services.reports import rlabel
from app.services.reviews import STARTED, _items, settings_for

WAITING = ("queued", *STARTED, "paused_no_credits")


def _office(p: Principal) -> None:
    if "jobs.view_all" not in p.permissions:
        raise Forbidden("forbidden", "Only owners and managers can see this.")


def _person(u: User | None) -> PersonRef | None:
    if u is None:
        return None
    url = get_storage().presign_get(u.avatar_key) if u.avatar_key else None
    return PersonRef(id=u.id, name=u.name or "", avatar_url=url)


# ---- customer reviews (M45) ----------------------------------------------------------------------
async def reviews_page(db: AsyncSession, p: Principal, filter_: str) -> ReviewsPage:
    _office(p)
    await send_due(db, p.company_id)
    s = await settings_for(db, p.company_id)
    everything = list(
        (
            await db.execute(
                select(Review)
                .where(Review.company_id == p.company_id, Review.status == "published")
                .order_by(Review.created_at.desc())
            )
        ).scalars()
    )
    replied = set(
        (
            await db.execute(
                select(ReviewReply.review_id).where(ReviewReply.review_id.in_([r.id for r in everything]))
            )
        ).scalars()
    )
    low = {r.id for r in everything if r.rating <= s.low_rating_threshold}
    needs = {r.id for r in everything if r.id not in replied}
    shown = [
        r for r in everything
        if filter_ == "all"
        or (filter_ == "needs_reply" and r.id in needs)
        or (filter_ == "low" and r.id in low)
    ]  # fmt: skip
    breakdown = [0, 0, 0, 0, 0]
    for r in everything:
        breakdown[r.rating - 1] += 1
    techs = {
        u.id: u
        for u in (
            await db.execute(
                select(User).where(User.id.in_({r.technician_id for r in shown if r.technician_id}))
            )
        ).scalars()
    }
    follow = {
        f.review_id: f
        for f in (
            await db.execute(
                select(ReviewFollowup).where(ReviewFollowup.review_id.in_([r.id for r in shown]))
            )
        ).scalars()
    }
    links = {
        req_id: (number, phone)
        for req_id, number, phone in (
            await db.execute(
                select(ReviewRequest.id, Report.number, CustomerContact.phone)
                .join(Report, Report.id == ReviewRequest.report_id)
                .outerjoin(CustomerContact, CustomerContact.id == ReviewRequest.contact_id)
                .where(ReviewRequest.id.in_([r.request_id for r in shown]))
            )
        ).all()
    }
    data = []
    for r, j, item in await _items(db, shown):
        f = follow.get(r.id)
        number, phone = links.get(r.request_id, (None, None))
        data.append(
            CompanyReviewItem(
                **item.model_dump(),
                job_id=j.id,
                customer_id=j.customer_id,
                report_number=rlabel(number) if number else None,
                contact_phone=phone,
                tags=list(r.tags or []),
                technician=_person(techs.get(r.technician_id)),
                wants_call_back=r.wants_call_back,
                low=r.id in low,
                needs_reply=r.id in needs,
                followup=FollowupOut(status=f.status, private_note=f.private_note, resolved_at=f.resolved_at)
                if f
                else None,
            )
        )
    return ReviewsPage(
        average=round(sum(r.rating for r in everything) / len(everything), 1) if everything else None,
        count=len(everything),
        breakdown=breakdown,
        counts=ReviewCounts(all=len(everything), needs_reply=len(needs), low=len(low)),
        data=data,
    )


async def _review(db: AsyncSession, p: Principal, review_id: uuid.UUID) -> Review:
    _office(p)
    r = await db.get(Review, review_id)
    if not r or r.company_id != p.company_id or r.status != "published":
        raise NotFound("not_found", "Review not found.")
    return r


async def reply(db: AsyncSession, p: Principal, review_id: uuid.UUID, text: str) -> ReplyOut:
    """One reply per review (sending again changes it). Shown on the customer's page and to the technician."""
    r = await _review(db, p, review_id)
    rp = (await db.execute(select(ReviewReply).where(ReviewReply.review_id == r.id))).scalar_one_or_none()
    if rp:
        rp.text, rp.author_id = text, p.user.id
    else:
        rp = ReviewReply(review_id=r.id, author_id=p.user.id, text=text)
        db.add(rp)
    await audit.record(
        db, "review.replied", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="review", target_id=r.id,
    )  # fmt: skip
    await db.flush()
    await db.refresh(rp)
    return ReplyOut(author=_person(p.user), text=rp.text, created_at=rp.created_at)


SUGGEST = {
    "en": (
        "Thank you, {name}! We are glad the work went well. See you at the next service.",
        "Thank you, {name}. We are sorry it was not better. We will call you to put it right.",
    ),
    "hi": (
        "धन्यवाद, {name}! खुशी है कि काम अच्छा रहा। अगली सर्विस पर मिलते हैं।",
        "धन्यवाद, {name}। माफ़ कीजिए, यह बेहतर नहीं रहा। हम इसे ठीक करने के लिए आपको कॉल करेंगे।",
    ),
    "gu": (
        "આભાર, {name}! કામ સારું રહ્યું તેનો આનંદ છે. આગલી સર્વિસમાં મળીએ.",
        "આભાર, {name}. માફ કરશો, આ વધુ સારું ન રહ્યું. તેને ઠીક કરવા અમે તમને કૉલ કરીશું.",
    ),
    "es": (
        "¡Gracias, {name}! Nos alegra que el trabajo saliera bien. Nos vemos en el próximo servicio.",
        "Gracias, {name}. Sentimos que no fuera mejor. Le llamaremos para solucionarlo.",
    ),
    "fr": (
        "Merci, {name} ! Ravis que l’intervention se soit bien passée. À la prochaine visite.",
        "Merci, {name}. Désolés que ce n’ait pas été mieux. Nous vous appelons pour arranger cela.",
    ),
}


async def suggest(db: AsyncSession, p: Principal, review_id: uuid.UUID, lang: str) -> SuggestionOut:
    """A short reply to start from, in the app's language. Warm for 4-5 stars, sorry for the rest."""
    r = await _review(db, p, review_id)
    good, sorry = SUGGEST.get(lang, SUGGEST["en"])
    name = (r.reviewer_name or "").strip() or {"hi": "जी", "gu": "જી"}.get(lang, "")
    text = (good if r.rating >= 4 else sorry).format(name=name)
    return SuggestionOut(text=text.replace(" , ", ", ").replace(", !", "!").replace(", .", "."))


async def followup(db: AsyncSession, p: Principal, review_id: uuid.UUID, body: FollowupIn) -> FollowupOut:
    r = await _review(db, p, review_id)
    f = await db.get(ReviewFollowup, r.id, with_for_update=True)
    if f is None:
        f = ReviewFollowup(review_id=r.id, company_id=r.company_id, status="open")
        db.add(f)
    if body.private_note is not None:
        f.private_note = body.private_note or None
    if body.status:
        f.status = body.status
        f.resolved_at, f.resolved_by = (now(), p.user.id) if body.status == "resolved" else (None, None)
    await db.flush()
    return FollowupOut(status=f.status, private_note=f.private_note, resolved_at=f.resolved_at)


# ---- review requests (M45) ------------------------------------------------------------------------
async def requests_page(db: AsyncSession, p: Principal, status: str) -> RequestsPage:
    _office(p)
    await send_due(db, p.company_id)
    s = await settings_for(db, p.company_id)
    rows = (
        await db.execute(
            select(ReviewRequest, Job, Customer.name)
            .join(Job, Job.id == ReviewRequest.job_id)
            .join(Customer, Customer.id == Job.customer_id)
            .where(ReviewRequest.company_id == p.company_id)
            .order_by(ReviewRequest.updated_at.desc())
        )
    ).all()
    group = {"waiting": WAITING, "rated": ("rated",), "opted_out": ("opted_out", "stopped")}
    counts = RequestCounts(**{k: sum(1 for req, _, _ in rows if req.status in v) for k, v in group.items()})
    shown = [(req, j, name) for req, j, name in rows if req.status in group.get(status, WAITING)]
    from app.services.evidence import thumbs_for

    thumbs = await thumbs_for(db, [j.id for _, j, _ in shown], each=1)
    techs = {
        u.id: u
        for u in (
            await db.execute(
                select(User).where(User.id.in_({j.assigned_to for _, j, _ in shown if j.assigned_to}))
            )
        ).scalars()
    }
    reviews = {
        r.request_id: r
        for r in (
            await db.execute(select(Review).where(Review.request_id.in_([req.id for req, _, _ in shown])))
        ).scalars()
    }
    data = []
    for req, j, name in shown:
        step, at = None, None
        if req.status == "link_sent" and s.reminder_enabled and req.reminder_at:
            step, at = "reminder", req.reminder_at
        elif req.status in ("link_sent", "reminded") and s.ai_call_enabled and req.ai_call_at:
            step, at = "ai_call", req.ai_call_at
        rv = reviews.get(req.id)
        data.append(
            RequestItem(
                id=req.id, job_id=j.id, customer=name, cover_url=(thumbs.get(j.id) or [None])[0],
                technician=_person(techs.get(j.assigned_to)), status=req.status, sent_at=req.sent_at,
                next_step=step, next_at=at,
                rating=rv.technician_rating or rv.rating if rv else None, source=rv.source if rv else None,
            )
        )  # fmt: skip
    return RequestsPage(counts=counts, data=data)


# ---- settings (M46) ---------------------------------------------------------------------------------
def _settings_out(s: ReviewSettings, can_edit: bool) -> ReviewSettingsOut:
    return ReviewSettingsOut(
        ask_on_share=s.ask_on_share, reminder_enabled=s.reminder_enabled, reminder_day=s.reminder_day,
        reminder_channels=list(s.reminder_channels or ["sms", "email"]), ai_call_enabled=s.ai_call_enabled,
        ai_call_day=s.ai_call_day, call_window="10:00-19:00", low_rating_alert=s.low_rating_alert,
        low_rating_threshold=s.low_rating_threshold, techs_can_request=s.techs_can_request,
        techs_see_reviews=s.techs_see_reviews, show_public_reviews=s.show_public_reviews,
        google_review_url=s.google_review_url, can_edit=can_edit,
    )  # fmt: skip


async def get_settings(db: AsyncSession, p: Principal) -> ReviewSettingsOut:
    _office(p)
    return _settings_out(await settings_for(db, p.company_id), True)


async def update_settings(db: AsyncSession, p: Principal, body: ReviewSettingsIn) -> ReviewSettingsOut:
    _office(p)
    s = await db.get(ReviewSettings, p.company_id, with_for_update=True)
    if s is None:
        s = await settings_for(db, p.company_id)
        db.add(s)
    changes = {
        k: v
        for k, v in body.model_dump(exclude_unset=True).items()
        if v is not None or k == "google_review_url"
    }
    for k, v in changes.items():
        setattr(s, k, (v or None) if k == "google_review_url" else v)
    await audit.record(
        db, "review_settings.updated", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="company", target_id=p.company_id, data={"changed": sorted(changes)},
    )  # fmt: skip
    await db.flush()
    return _settings_out(s, True)


# ---- the Day 2 reminder ----------------------------------------------------------------------------
async def send_due(db: AsyncSession, company_id: uuid.UUID | None = None, at: datetime | None = None) -> int:
    """Send every reminder that is due (one company, or all). Returns how many went out."""
    t = at or now()
    q = select(ReviewRequest).where(
        ReviewRequest.status.in_(("link_sent", "paused_no_credits")),
        ReviewRequest.reminder_at.is_not(None),
        ReviewRequest.reminder_at <= t,
    )
    if company_id:
        q = q.where(ReviewRequest.company_id == company_id)
    sent = 0
    for req in (await db.execute(q.with_for_update(skip_locked=True))).scalars().all():
        s = await settings_for(db, req.company_id)
        if not s.reminder_enabled:
            continue
        sent += await _remind(db, s, req, t)
    if sent:
        await db.flush()
    return sent


async def _remind(db: AsyncSession, s: ReviewSettings, req: ReviewRequest, t: datetime) -> int:
    job = await db.get(Job, req.job_id)
    rep = await db.get(Report, req.report_id)
    company = await db.get(Company, req.company_id)
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    link = await db.get(ShareLink, req.share_link_id) if req.share_link_id else None
    if not (job and rep and contact and link) or sharing.link_state(link) != "active":
        req.status, req.stopped_reason = "stopped", "link_gone"
        return 0
    url = f"{sharing.link_url(link)}?rate=1"
    lang = rep.language
    ask = label(lang, "review_reminder", company=company.name, job=job.title, link=url)
    text = f"{ask} {label(lang, 'stop')}"
    texts = sharing._texts(company.name, rep, job, url, contact.name, link.expires_at.astimezone(UTC))
    texts.sms = texts.whatsapp = text
    texts.email_body = f"{text}\n"
    done, broke = [], False
    for ch in s.reminder_channels or ["sms", "email"]:
        to = contact.email if ch == "email" else contact.phone
        if not to or (ch == "email" and not sharing.email_on()):
            continue
        if not await credits.can_spend(db, company, ch):
            broke = True  # SMS and WhatsApp need credits; email is free
            db.add(ReviewRequestEvent(request_id=req.id, step="reminder", channel=ch, status="no_credits"))
            continue
        msg = await sharing._deliver(db, rep, link, ch, to, texts, None, template="review_reminder")
        db.add(ReviewRequestEvent(request_id=req.id, step="reminder", channel=ch, status=msg.status))
        if msg.status == "sent":
            await credits.spend(db, company, ch, "reminder", req.id)
            done.append(ch)
    if done:
        req.status = "reminded"
    elif broke:
        req.status = "paused_no_credits"  # stays due: it goes when credits are back
    else:
        req.reminder_at = None  # nothing could go; don't try every time
    return 1 if done else 0


async def count_waiting(db: AsyncSession, company_id: uuid.UUID) -> int:
    return (
        await db.scalar(
            select(func.count())
            .select_from(ReviewRequest)
            .where(ReviewRequest.company_id == company_id, ReviewRequest.status.in_(WAITING))
        )
    ) or 0
