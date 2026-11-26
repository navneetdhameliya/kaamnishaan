"""Customer reviews: asking (M31, M15), the rating link with the approved report (Day 0), the customer's
rating on the report page (W29) and the technician's own reviews (M44).

Day 2 reminders and the Day 5 AI call are planned on each request (`reminder_at`, `ai_call_at`) so the
screens can show them; the follow-up worker that sends them comes with credits (next reviews step).
"""

import uuid
from datetime import UTC, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.core.security import now
from app.models import (
    Company,
    CustomerContact,
    Evidence,
    Job,
    Report,
    Review,
    ReviewReply,
    ReviewRequest,
    ReviewRequestEvent,
    ReviewSettings,
    ShareLink,
    User,
)
from app.models.reviews import POSITIVE_TAGS
from app.providers.storage import get_storage
from app.schemas.reviews import (
    JobReview,
    MyReviews,
    PublicReviewState,
    RatedOut,
    ReplyOut,
    ReviewBrief,
    ReviewIn,
    ReviewListItem,
    ReviewOut,
    TagCount,
)
from app.schemas.sharing import PublicPraise
from app.schemas.work import PersonRef
from app.services import audit, messages, moderation, platform, sharing
from app.services.reports import DONE, rlabel

REPEAT_WINDOW = timedelta(hours=24)  # A37: a second review from one phone within a day is held
STARTED = ("link_sent", "reminded", "ai_call_scheduled", "ai_call_done")


# ---- settings ------------------------------------------------------------------------------------
async def settings_for(db: AsyncSession, company_id: uuid.UUID) -> ReviewSettings:
    """The company's review settings, or the defaults (M46 edits them later)."""
    s = await db.get(ReviewSettings, company_id)
    if s:
        return s
    return ReviewSettings(
        company_id=company_id, ask_on_share=True, reminder_enabled=True, reminder_channels=["sms", "email"],
        reminder_day=2, ai_call_enabled=True, ai_call_day=5, low_rating_alert=True, low_rating_threshold=2,
        techs_can_request=True, techs_see_reviews=True, show_public_reviews=False,
    )  # fmt: skip


def _zone(company: Company) -> ZoneInfo:
    try:
        return ZoneInfo(company.timezone)
    except Exception:  # noqa: BLE001 - a bad stored zone falls back to India
        return ZoneInfo("Asia/Kolkata")


def _plan(company: Company, start: datetime, days: int) -> datetime:
    """[days] after [start], at 11:00 in the company's time zone (when people read messages)."""
    zone = _zone(company)
    day = start.astimezone(zone).date() + timedelta(days=days)
    return datetime.combine(day, time(11, 0), tzinfo=zone).astimezone(UTC)


# ---- reading -------------------------------------------------------------------------------------
async def _report(db: AsyncSession, job: Job) -> Report | None:
    return (await db.execute(select(Report).where(Report.job_id == job.id))).scalar_one_or_none()


async def _request(db: AsyncSession, job_id: uuid.UUID, lock: bool = False) -> ReviewRequest | None:
    q = select(ReviewRequest).where(ReviewRequest.job_id == job_id)
    if lock:
        q = q.with_for_update()
    return (await db.execute(q)).scalar_one_or_none()


async def _reachable(db: AsyncSession, contact: CustomerContact | None) -> bool:
    """A phone, or an email while email is on."""
    if contact is None:
        return False
    return bool(contact.phone or (contact.email and await sharing.email_on(db)))


def _manager(p: Principal) -> bool:
    return "jobs.view_all" in p.permissions


def _brief(r: Review) -> ReviewBrief:
    return ReviewBrief(
        id=r.id, rating=r.rating, technician_rating=r.technician_rating, comment=r.comment, source=r.source,
        created_at=r.created_at,
    )  # fmt: skip


async def job_review(db: AsyncSession, p: Principal, job: Job) -> JobReview | None:
    """The "Customer review" card on a job (M15). None until the job has a report."""
    rep = await _report(db, job)
    if rep is None:
        return None
    s = await settings_for(db, job.company_id)
    req = await _request(db, job.id)
    if req is None:
        mine = job.assigned_to == p.user.id
        contact = await sharing._contact(db, job)
        reason = None
        if not _manager(p) and not mine:
            reason = "not_assigned"
        elif not _manager(p) and not s.techs_can_request:
            reason = "not_allowed"
        elif not await _reachable(db, contact):
            reason = "no_contact"
        return JobReview(
            status="not_requested", can_request=reason is None, blocked_reason=reason,
            contact_name=contact.name if contact else None, contact_phone=contact.phone if contact else None,
            ai_call_enabled=s.ai_call_enabled,
        )  # fmt: skip
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    who = await db.get(User, req.requested_by) if req.requested_by else None
    review = (
        await db.execute(select(Review).where(Review.request_id == req.id, Review.status == "published"))
    ).scalar_one_or_none()  # a review held or hidden by KaamNishaan (A37) is not shown
    return JobReview(
        status=req.status,
        request_id=req.id,
        can_request=False,
        can_cancel=req.status == "queued" and (req.requested_by == p.user.id or _manager(p)),
        requested_by=PersonRef(id=who.id, name=who.name or "") if who else None,
        requested_by_me=req.requested_by == p.user.id,
        contact_name=contact.name if contact else None,
        contact_phone=contact.phone if contact else None,
        sent_at=req.sent_at,
        channels=list(req.channels or []),
        reminder_at=req.reminder_at if s.reminder_enabled else None,
        ai_call_at=req.ai_call_at if s.ai_call_enabled else None,
        ai_call_enabled=s.ai_call_enabled,
        opted_out_at=req.opted_out_at,
        opt_out_source=req.opt_out_source,
        review=_brief(review) if review and (s.techs_see_reviews or _manager(p)) else None,
    )


# ---- asking --------------------------------------------------------------------------------------
async def request_review(db: AsyncSession, p: Principal, job: Job) -> JobReview:
    """M31 "Ask for review" / M15 "Request review". Sent now when the report is approved; otherwise it
    waits and goes with the approval."""
    rep = await _report(db, job)
    if rep is None:
        raise Conflict("no_report", "Send the report first, then ask for a review.")
    s = await settings_for(db, job.company_id)
    if not _manager(p):
        if job.assigned_to != p.user.id:
            raise Forbidden("forbidden", "Only the technician on this job or a manager can ask.")
        if not s.techs_can_request:
            raise Forbidden("reviews_not_allowed", "Your company asks for reviews itself.")
    if await _request(db, job.id, lock=True):
        raise Conflict("already_requested", "A review was already asked for this job.")
    contact = await sharing._contact(db, job)
    if not await _reachable(db, contact):
        raise AppError(
            "contact_missing", "Add the customer's phone or email first.", fields={"contact": "missing"}
        )
    req = ReviewRequest(
        company_id=job.company_id, job_id=job.id, report_id=rep.id, contact_id=contact.id,
        requested_by=p.user.id, status="queued",
    )  # fmt: skip
    db.add(req)
    await db.flush()
    db.add(ReviewRequestEvent(request_id=req.id, step="requested"))
    if rep.status in DONE:
        await _send(db, p, req, rep, job, contact)
    await audit.record(
        db, "review.requested", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="job", target_id=job.id, data={"status": req.status},
    )  # fmt: skip
    await db.flush()
    return await job_review(db, p, job)


async def cancel(db: AsyncSession, p: Principal, request_id: uuid.UUID) -> None:
    """Cancel while it waits for approval: the job goes back to "not asked yet"."""
    req = await db.get(ReviewRequest, request_id, with_for_update=True)
    if not req or req.company_id != p.company_id:
        raise NotFound("not_found", "Review request not found.")
    if req.requested_by != p.user.id and not _manager(p):
        raise Forbidden("forbidden", "Only the person who asked, or a manager, can cancel.")
    if req.status != "queued":
        raise Conflict(
            "invalid_transition", "The link has already gone to the customer.", {"status": req.status}
        )
    await db.delete(req)
    await db.flush()


async def share_default(db: AsyncSession, job: Job) -> str:
    """M35: is "Ask for a review" on by default, or was a review already asked for this job?"""
    if await _request(db, job.id):
        return "asked"
    return "on" if (await settings_for(db, job.company_id)).ask_on_share else "off"


async def with_share(
    db: AsyncSession, p: Principal, rep: Report, job: Job, contact: CustomerContact | None,
    link: ShareLink, channels: list[str], ask: bool | None,
) -> None:  # fmt: skip
    """M35 Send with "Ask for a review": the report link already opens the rating, so this is Day 0."""
    s = await settings_for(db, job.company_id)
    if not (s.ask_on_share if ask is None else ask) or contact is None:
        return
    if not _manager(p) and not (s.techs_can_request and job.assigned_to == p.user.id):
        return
    if await _request(db, job.id, lock=True):
        return
    company = await db.get(Company, job.company_id)
    t = now()
    req = ReviewRequest(
        company_id=job.company_id, job_id=job.id, report_id=rep.id, contact_id=contact.id,
        requested_by=p.user.id, status="link_sent", sent_at=t, channels=channels, share_link_id=link.id,
        reminder_at=_plan(company, t, s.reminder_day) if s.reminder_enabled else None,
        ai_call_at=_plan(company, t, s.ai_call_day) if s.ai_call_enabled else None,
    )  # fmt: skip
    db.add(req)
    await db.flush()
    db.add(ReviewRequestEvent(request_id=req.id, step="requested"))
    for ch in channels:
        db.add(ReviewRequestEvent(request_id=req.id, step="link_sent", channel=ch, status="sent"))


async def on_report_approved(db: AsyncSession, p: Principal, rep: Report, job: Job) -> None:
    """A request that waited for approval goes out now, with the report (Day 0)."""
    req = await _request(db, job.id, lock=True)
    if not req or req.status != "queued":
        return
    contact = (
        await db.get(CustomerContact, req.contact_id) if req.contact_id else await sharing._contact(db, job)
    )
    if not await _reachable(db, contact):
        req.status, req.stopped_reason = "stopped", "no_contact"
        return
    await _send(db, p, req, rep, job, contact)


async def _send(
    db: AsyncSession, p: Principal, req: ReviewRequest, rep: Report, job: Job, contact: CustomerContact
) -> None:
    """Day 0: the report link, opening on the rating, by SMS and email."""
    company = await db.get(Company, job.company_id)
    s = await settings_for(db, job.company_id)
    channels = [c for c, to in (("sms", contact.phone), ("email", contact.email)) if to]
    mail_on = await sharing.email_on(db)
    channels = [c for c in channels if c != "email" or mail_on]
    if not channels:
        req.status, req.stopped_reason = "stopped", "no_contact"
        return
    link = await sharing._ensure_link(
        db, rep, channels[0], p.user.id, contact.name, contact.phone, contact.email
    )
    url = f"{sharing.link_url(link)}?rate=1"
    texts = sharing._texts(
        company.name, rep, job, url, contact.name, link.expires_at.astimezone(),
        await messages.load(db), "report_review",
    )  # fmt: skip
    sent = []
    for ch in channels:
        to = contact.email if ch == "email" else contact.phone
        msg = await sharing._deliver(db, rep, link, ch, to, texts, p.user.id, template="report_review")
        db.add(ReviewRequestEvent(request_id=req.id, step="link_sent", channel=ch, status=msg.status))
        if msg.status == "sent":
            sent.append(ch)
    if not sent:
        req.status, req.stopped_reason = "stopped", "delivery_failed"
        return
    await sharing._mark_shared(db, p, rep, job, sent)
    t = now()
    req.status, req.sent_at, req.channels, req.share_link_id = "link_sent", t, sent, link.id
    req.reminder_at = _plan(company, t, s.reminder_day) if s.reminder_enabled else None
    req.ai_call_at = _plan(company, t, s.ai_call_day) if s.ai_call_enabled else None


# ---- the customer's report page (W29) ------------------------------------------------------------
async def public_state(db: AsyncSession, rep: Report) -> PublicReviewState:
    job = await db.get(Job, rep.job_id)
    req = await _request(db, job.id)
    review = (
        (await db.execute(select(Review).where(Review.request_id == req.id))).scalar_one_or_none()
        if req
        else None
    )
    tech = await db.get(User, job.assigned_to) if job.assigned_to else None
    return PublicReviewState(
        can_rate=review is None,
        rated=review is not None,
        rating=review.rating if review else None,
        technician=(tech.name or "").split(" ")[0] or None if tech else None,
        can_edit=bool(review) and await _editable(db, review),
        technician_rating=review.technician_rating if review else None,
        tags=list(review.tags or []) if review else [],
        comment=review.comment if review else None,
    )


EDIT_DAYS = 7  # D-149


async def _editable(db: AsyncSession, review: Review) -> bool:
    """A review from the link can be changed for 7 days, until the company has replied to it."""
    if (
        review.source != "link"
        or review.status == "hidden"
        or now() - review.created_at > timedelta(days=EDIT_DAYS)
    ):
        return False
    return not (await db.execute(select(ReviewReply.id).where(ReviewReply.review_id == review.id))).first()


async def _for_link(db: AsyncSession, token: str) -> tuple[Report, Job, ReviewRequest]:
    _, rep = await sharing._link(db, token)
    job = await db.get(Job, rep.job_id)
    req = await _request(db, job.id, lock=True)
    if req is None:  # rated without being asked (the report was shared on its own)
        contact = await sharing._contact(db, job)
        req = ReviewRequest(
            company_id=job.company_id, job_id=job.id, report_id=rep.id,
            contact_id=contact.id if contact else None, status="link_sent", sent_at=now(),
        )  # fmt: skip
        db.add(req)
        await db.flush()
    return rep, job, req


async def rate(db: AsyncSession, token: str, body: ReviewIn) -> RatedOut:
    rep, job, req = await _for_link(db, token)
    if (await db.execute(select(Review.id).where(Review.request_id == req.id))).first():
        raise Conflict("already_rated", "Thank you, this job was already rated.")
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    comment, original, reason = await _checked(db, body.comment or None, job.company_id, contact)
    review = Review(
        company_id=job.company_id, request_id=req.id, job_id=job.id, technician_id=job.assigned_to,
        rating=body.rating, technician_rating=body.technician_rating, tags=body.tags,
        comment=comment, comment_original=original,
        reviewer_name=body.name or (contact.name if contact else None),
        source="link", public_allowed=body.public_allowed, wants_call_back=body.wants_call_back,
        status="flagged" if reason else "published", flag_reason=reason,
    )  # fmt: skip
    db.add(review)
    req.status = "rated"
    db.add(ReviewRequestEvent(request_id=req.id, step="rated", channel="link"))
    await db.flush()
    s = await settings_for(db, job.company_id)
    if not reason:  # a held review reaches the company when KaamNishaan publishes it (A37)
        await tell(db, review)
    return RatedOut(review_id=review.id, google_review_url=s.google_review_url if body.rating >= 4 else None)


async def edit(db: AsyncSession, token: str, body: ReviewIn) -> RatedOut:
    """W29 "Edit your review" (D-149): the customer changes stars, tags or words; checked again like a
    new one. The company is told again only when the stars drop to a low rating."""
    rep, job, req = await _for_link(db, token)
    review = (await db.execute(select(Review).where(Review.request_id == req.id))).scalar_one_or_none()
    if review is None:
        raise NotFound("not_rated", "This job hasn't been rated yet.")
    if not await _editable(db, review):
        raise Conflict("review_locked", "This review can't be changed any more.")
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    comment, original, reason = await _checked(db, body.comment or None, job.company_id, contact)
    was = review.rating
    review.rating, review.technician_rating, review.tags = body.rating, body.technician_rating, body.tags
    review.comment, review.comment_original = comment, original
    review.public_allowed, review.wants_call_back = body.public_allowed, body.wants_call_back
    if body.name:
        review.reviewer_name = body.name
    if reason:
        review.status, review.flag_reason = "flagged", reason
    db.add(ReviewRequestEvent(request_id=req.id, step="rated", channel="edit"))
    await db.flush()
    s = await settings_for(db, job.company_id)
    low = s.low_rating_threshold
    if not reason and body.rating <= low < was:
        await tell(db, review)
    return RatedOut(review_id=review.id, google_review_url=s.google_review_url if body.rating >= 4 else None)


async def from_call(
    db: AsyncSession, req: ReviewRequest, *, rating: int, comment: str | None, wants_call_back: bool,
    public_allowed: bool,
) -> Review:  # fmt: skip
    """A38: the customer rated on the Day 5 AI call. Same review rules as the link (A37)."""
    job = await db.get(Job, req.job_id)
    contact = await db.get(CustomerContact, req.contact_id) if req.contact_id else None
    text, original, reason = await _checked(db, comment or None, job.company_id, contact)
    review = Review(
        company_id=job.company_id, request_id=req.id, job_id=job.id, technician_id=job.assigned_to,
        rating=rating, tags=[], comment=text, comment_original=original,
        reviewer_name=contact.name if contact else None, source="ai_call", public_allowed=public_allowed,
        wants_call_back=wants_call_back, status="flagged" if reason else "published", flag_reason=reason,
    )  # fmt: skip
    db.add(review)
    req.status = "rated"
    db.add(ReviewRequestEvent(request_id=req.id, step="rated", channel="ai_call"))
    await db.flush()
    if not reason:
        await tell(db, review)
    return review


async def _checked(
    db: AsyncSession, comment: str | None, company_id: uuid.UUID, contact: CustomerContact | None
) -> tuple[str | None, str | None, str | None]:
    """A37 review rules: (comment to show, the words before hiding contact details, why it is held)."""
    rules = await platform.review_rules(db)
    original, reason = None, None
    if comment and rules.hide_contact:
        hidden, found = moderation.hide_contact(comment)
        if found:
            original, comment, reason = comment, hidden, "personal_data"
    if rules.block_repeats and contact and contact.phone:
        same_phone = await db.scalar(
            select(func.count())
            .select_from(Review)
            .join(ReviewRequest, ReviewRequest.id == Review.request_id)
            .join(CustomerContact, CustomerContact.id == ReviewRequest.contact_id)
            .where(
                Review.company_id == company_id,
                CustomerContact.phone == contact.phone,
                Review.created_at >= now() - REPEAT_WINDOW,
            )
        )
        if same_phone:
            reason = "spam"
    if comment and rules.flag_abuse and moderation.is_abusive(original or comment):
        reason = "abuse"
    return comment, original, reason


async def tell(db: AsyncSession, review: Review) -> None:
    """A new review: the technician sees it (when allowed); a low one alerts the office and opens a
    follow-up."""
    from app.models import ReviewFollowup
    from app.services import notifications

    job = await db.get(Job, review.job_id)
    s = await settings_for(db, review.company_id)

    stars = review.technician_rating or review.rating
    params = {**await notifications.job_params(db, job), "rating": str(review.rating)}
    if s.techs_see_reviews and job.assigned_to:
        await notifications.notify(
            db, company_id=job.company_id, to=[job.assigned_to], kind="review_received", actor_id=None,
            job=job, params={**params, "rating": str(stars)},
        )  # fmt: skip
    if review.rating <= s.low_rating_threshold:
        db.add(ReviewFollowup(review_id=review.id, company_id=job.company_id, status="open"))
        if s.low_rating_alert:
            await notifications.notify(
                db, company_id=job.company_id, to=await notifications.reviewers(db, job.company_id),
                kind="low_rating", actor_id=None, job=job, params=params,
            )  # fmt: skip


async def opt_out(db: AsyncSession, token: str) -> None:
    """ "Don't ask me again" on the page: no more messages or calls for this job."""
    _, _, req = await _for_link(db, token)
    if req.status == "rated":
        return
    req.status, req.opted_out_at, req.opt_out_source = "opted_out", now(), "link"
    db.add(ReviewRequestEvent(request_id=req.id, step="opted_out", channel="link"))
    await db.flush()


# ---- My reviews (M44) ----------------------------------------------------------------------------
async def _items(db: AsyncSession, reviews: list[Review]) -> list[tuple[Review, Job, ReviewListItem]]:
    if not reviews:
        return []
    from app.models import Customer
    from app.services.evidence import thumbs_for

    jobs = {
        j.id: j
        for j in (await db.execute(select(Job).where(Job.id.in_({r.job_id for r in reviews})))).scalars()
    }
    names = dict(
        (
            await db.execute(
                select(Customer.id, Customer.name).where(
                    Customer.id.in_({j.customer_id for j in jobs.values()})
                )
            )
        ).all()
    )
    thumbs = await thumbs_for(db, list(jobs), each=1)
    replies: dict[uuid.UUID, ReplyOut] = {}
    for rp, author in (
        await db.execute(
            select(ReviewReply, User)
            .outerjoin(User, User.id == ReviewReply.author_id)
            .where(ReviewReply.review_id.in_([r.id for r in reviews]))
            .order_by(ReviewReply.created_at)
        )
    ).all():
        replies[rp.review_id] = ReplyOut(
            author=PersonRef(id=author.id, name=author.name or "") if author else None,
            text=rp.text,
            created_at=rp.created_at,
        )
    out = []
    for r in reviews:
        j = jobs[r.job_id]
        out.append(
            (
                r,
                j,
                ReviewListItem(
                    id=r.id, rating=r.rating, technician_rating=r.technician_rating, comment=r.comment,
                    reviewer_name=r.reviewer_name, source=r.source, customer=names.get(j.customer_id, ""),
                    job_title=j.title, cover_url=(thumbs.get(j.id) or [None])[0], created_at=r.created_at,
                    reply=replies.get(r.id),
                ),
            )
        )  # fmt: skip
    return out


async def my_reviews(db: AsyncSession, p: Principal) -> MyReviews:
    """The technician's own reviews this year, newest first, with the average and the good tags."""
    s = await settings_for(db, p.company_id)
    if not s.techs_see_reviews and not _manager(p):
        raise Forbidden("reviews_hidden", "Your company keeps reviews for managers.")
    company = await db.get(Company, p.company_id)
    zone = _zone(company)
    year_start = datetime(now().astimezone(zone).year, 1, 1, tzinfo=zone)
    reviews = list(
        (
            await db.execute(
                select(Review)
                .where(
                    Review.company_id == p.company_id, Review.technician_id == p.user.id,
                    Review.status == "published", Review.created_at >= year_start,
                )
                .order_by(Review.created_at.desc())
            )
        ).scalars()
    )  # fmt: skip
    stars = [r.technician_rating or r.rating for r in reviews]
    counts: dict[str, int] = {}
    for r in reviews:
        for t in r.tags or []:
            if t in POSITIVE_TAGS:
                counts[t] = counts.get(t, 0) + 1
    return MyReviews(
        average=round(sum(stars) / len(stars), 1) if stars else None,
        count=len(stars),
        share_4_plus=round(100 * sum(1 for x in stars if x >= 4) / len(stars)) if stars else 0,
        tags=[TagCount(key=k, count=v) for k, v in sorted(counts.items(), key=lambda kv: -kv[1])],
        data=[item for _, _, item in await _items(db, reviews)],
    )


async def get_review(db: AsyncSession, p: Principal, review_id: uuid.UUID) -> ReviewOut:
    r = await db.get(Review, review_id)
    if (
        not r
        or r.company_id != p.company_id
        or r.status != "published"
        or (not _manager(p) and r.technician_id != p.user.id)
    ):
        raise NotFound("not_found", "Review not found.")
    [(_, job, item)] = await _items(db, [r])
    rep = await _report(db, job)
    tech = await db.get(User, r.technician_id) if r.technician_id else None
    storage = get_storage()
    shots: dict[str, str] = {}
    for stage, key in (
        await db.execute(
            select(Evidence.stage, Evidence.thumb_key)
            .where(Evidence.job_id == job.id, Evidence.deleted_at.is_(None), Evidence.thumb_key.is_not(None))
            .order_by(Evidence.taken_at)
        )
    ).all():
        if stage == "before":
            shots.setdefault("before", key)
        elif stage == "after":
            shots["after"] = key  # the last after photo
    return ReviewOut(
        **item.model_dump(),
        tags=list(r.tags or []),
        job_id=job.id,
        report_number=rlabel(rep.number) if rep else None,
        technician=PersonRef(id=tech.id, name=tech.name or "") if tech else None,
        before_url=storage.presign_get(shots["before"]) if "before" in shots else None,
        after_url=storage.presign_get(shots["after"]) if "after" in shots else None,
        public_allowed=r.public_allowed,
        wants_call_back=r.wants_call_back,
    )


async def public_praise(db: AsyncSession, company_id: uuid.UUID, job_id: uuid.UUID) -> list[PublicPraise]:
    """D-149: with "Show good reviews" on (M46), the report page shows up to 3 recent 4-5 star reviews with
    words, from customers who said they may be shown; first names only, never this job's own."""
    s = await settings_for(db, company_id)
    if not s.show_public_reviews:
        return []
    rows = (
        await db.scalars(
            select(Review)
            .where(
                Review.company_id == company_id,
                Review.job_id != job_id,
                Review.status == "published",
                Review.public_allowed.is_(True),
                Review.rating >= 4,
                Review.comment.is_not(None),
                Review.comment != "",
            )
            .order_by(Review.created_at.desc())
            .limit(3)
        )
    ).all()
    return [
        PublicPraise(
            rating=r.rating,
            comment=r.comment,
            name=(r.reviewer_name or "").split(" ")[0] or None,
            at=r.created_at,
        )
        for r in rows
    ]
