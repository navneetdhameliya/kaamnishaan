"""A37 Reviews and ratings: every company's customer reviews, the reviews held by the review rules, and
the rules themselves.

A review held by a rule (status "flagged") is not shown to the company yet. Staff publish it (the
company then gets it like any new review) or hide it. A hidden review can be put back. Staff never edit a
customer's words; the only change is the automatic hiding of phone numbers and emails.
"""

import csv
import io
import uuid
from collections.abc import Iterable
from datetime import timedelta

from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import (
    Company,
    Job,
    Report,
    Review,
    ReviewFollowup,
    ReviewReply,
    StaffUser,
    User,
)
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_reviews import (
    AdminReviewDetail,
    AdminReviewKpis,
    AdminReviewList,
    AdminReviewReply,
    AdminReviewRow,
    AdminReviewRules,
)
from app.services import audit, platform
from app.services.admin_companies import _csv_safe
from app.services.jobs import label as jlabel
from app.services.reviews import tell

LOW = 2  # "low ratings": 2 stars or less


def _filters(q: str | None, rating: str | None, status: str | None, company_id: uuid.UUID | None) -> list:
    tech = User.__table__.alias("tech")
    where: list = []
    if q:
        like = f"%{q.strip()}%"
        where.append(
            or_(
                Review.comment.ilike(like),
                Review.reviewer_name.ilike(like),
                Company.name.ilike(like),
                Job.title.ilike(like),
                Review.technician_id.in_(select(tech.c.id).where(tech.c.name.ilike(like))),
            )
        )
    if rating == "low":
        where.append(Review.rating <= LOW)
    elif rating:
        where.append(Review.rating == int(rating))
    if status in ("flagged", "published", "hidden"):
        where.append(Review.status == status)
    elif status == "followup":
        where.append(
            Review.id.in_(select(ReviewFollowup.review_id).where(ReviewFollowup.status == "open")),
            Review.status == "published",
        )
    elif status == "replied":
        where.append(Review.id.in_(select(ReviewReply.review_id)))
    if company_id:
        where.append(Review.company_id == company_id)
    return where


def _base(where: list):
    return (
        select(Review, Company, Job, User.name)
        .join(Company, Company.id == Review.company_id)
        .join(Job, Job.id == Review.job_id)
        .outerjoin(User, User.id == Review.technician_id)
        .where(*where)
    )


async def _rows(db: AsyncSession, rows) -> list[AdminReviewRow]:
    ids = [r.id for r, *_ in rows]
    follow = dict(
        (await db.execute(select(ReviewFollowup.review_id, ReviewFollowup.status).where(
            ReviewFollowup.review_id.in_(ids)))).all()
    ) if ids else {}  # fmt: skip
    replied = set(
        (await db.execute(select(ReviewReply.review_id).where(ReviewReply.review_id.in_(ids)))).scalars()
    ) if ids else set()  # fmt: skip
    return [
        AdminReviewRow(
            id=r.id,
            comment=r.comment,
            reviewer_name=r.reviewer_name,
            job_title=j.title,
            company=AdminOption(value=str(c.id), label=c.name),
            technician=tech,
            rating=r.rating,
            status=r.status,
            flag_reason=r.flag_reason,
            followup=follow.get(r.id),
            replied=r.id in replied,
            created_at=r.created_at,
        )  # fmt: skip
        for r, c, j, tech in rows
    ]


ORDER = (case((Review.status == "flagged", 0), else_=1), Review.created_at.desc())


async def reviews(
    db: AsyncSession, *, q: str | None, rating: str | None, status: str | None,
    company_id: uuid.UUID | None, page: int, page_size: int,
) -> AdminReviewList:  # fmt: skip
    where = _filters(q, rating, status, company_id)
    total = int(await db.scalar(select(func.count()).select_from(_base(where).subquery())) or 0)
    rows = (
        await db.execute(_base(where).order_by(*ORDER).offset((page - 1) * page_size).limit(page_size))
    ).all()

    since = now() - timedelta(days=30)
    recent = (Review.created_at >= since) & (Review.status != "hidden")
    stats = select(func.avg(Review.rating), func.count(), func.count().filter(Review.rating <= LOW))
    avg, n, low = (await db.execute(stats.where(recent))).one()
    shared = int(await db.scalar(select(func.count()).where(Report.shared_at >= since)) or 0)
    flagged = int(await db.scalar(select(func.count()).where(Review.status == "flagged")) or 0)
    companies = (
        await db.execute(
            select(Company.id, Company.name)
            .where(Company.id.in_(select(Review.company_id)))
            .order_by(Company.name)
        )
    ).all()
    return AdminReviewList(
        items=await _rows(db, rows), total=total, page=page, page_size=page_size,
        kpis=AdminReviewKpis(
            average_rating=round(float(avg), 1) if avg is not None else None, reviews_30d=n,
            share_rate=round(n / shared, 4) if shared else None, low_30d=low,
            low_rate=round(low / n, 4) if n else None, flagged=flagged,
        ),
        companies=[AdminOption(value=str(i), label=name) for i, name in companies],
    )  # fmt: skip


async def _one(db: AsyncSession, review_id: uuid.UUID) -> tuple[Review, Company, Job, str | None]:
    row = (await db.execute(_base([Review.id == review_id]))).first()
    if not row:
        raise NotFound("not_found", "Review not found.")
    return tuple(row)  # type: ignore[return-value]


async def detail(db: AsyncSession, review_id: uuid.UUID, *, can_act: bool) -> AdminReviewDetail:
    r, c, j, tech = await _one(db, review_id)
    [row] = await _rows(db, [(r, c, j, tech)])
    reply = None
    rp = (
        await db.execute(
            select(ReviewReply, User.name).outerjoin(User, User.id == ReviewReply.author_id)
            .where(ReviewReply.review_id == r.id)
        )
    ).first()  # fmt: skip
    if rp:
        reply = AdminReviewReply(text=rp[0].text, by=rp[1], at=rp[0].created_at)
    mod = await db.get(StaffUser, r.moderated_by) if r.moderated_by else None
    return AdminReviewDetail(
        **row.model_dump(), comment_original=r.comment_original, technician_rating=r.technician_rating,
        tags=list(r.tags or []), source=r.source, job_number=jlabel(j.number), reply=reply,
        moderated_by=mod.name if mod else None, moderated_at=r.moderated_at,
        moderation_note=r.moderation_note, can_act=can_act,
    )  # fmt: skip


async def _decide(
    db: AsyncSession, review_id: uuid.UUID, *, to: str, allowed: tuple[str, ...], code: str,
    note: str | None, staff_id: uuid.UUID, ip: str | None,
) -> Review:  # fmt: skip
    r = await db.get(Review, review_id, with_for_update=True)
    if not r:
        raise NotFound("not_found", "Review not found.")
    if r.status not in allowed:
        raise AppError(code, "This review has already been dealt with.", status=409)
    before = r.status
    r.status, r.moderated_by, r.moderated_at, r.moderation_note = to, staff_id, now(), note
    await db.flush()
    if before == "flagged" and to == "published":
        await tell(db, r)  # the company and technician hear about it now, like any new review
    action = {"published": "staff.review_published", "hidden": "staff.review_hidden"}[to]
    if before == "hidden":
        action = "staff.review_restored"
    await audit.record(
        db, action, staff_id=staff_id, company_id=r.company_id, target_type="review", target_id=r.id,
        data={"from": before, "reason": r.flag_reason, **({"note": note} if note else {})}, ip=ip,
    )  # fmt: skip
    return r


async def publish(db: AsyncSession, review_id: uuid.UUID, *, staff_id: uuid.UUID, ip: str | None) -> None:
    await _decide(db, review_id, to="published", allowed=("flagged",), code="not_flagged", note=None,
                  staff_id=staff_id, ip=ip)  # fmt: skip


async def hide(
    db: AsyncSession, review_id: uuid.UUID, reason: str, *, staff_id: uuid.UUID, ip: str | None
) -> None:
    await _decide(db, review_id, to="hidden", allowed=("flagged", "published"), code="already_hidden",
                  note=reason, staff_id=staff_id, ip=ip)  # fmt: skip


async def restore(db: AsyncSession, review_id: uuid.UUID, *, staff_id: uuid.UUID, ip: str | None) -> None:
    await _decide(db, review_id, to="published", allowed=("hidden",), code="not_hidden", note=None,
                  staff_id=staff_id, ip=ip)  # fmt: skip


async def rules(db: AsyncSession) -> AdminReviewRules:
    return AdminReviewRules(**(await platform.review_rules(db)).model_dump())


async def set_rules(
    db: AsyncSession, body: AdminReviewRules, *, staff_id: uuid.UUID, ip: str | None
) -> AdminReviewRules:
    before = await platform.review_rules(db)
    after = await platform.set_review_rules(db, platform.ReviewRules(**body.model_dump()), staff_id=staff_id)
    changed = {k: v for k, v in after.model_dump().items() if getattr(before, k) != v}
    if changed:
        await audit.record(db, "staff.review_rules_updated", staff_id=staff_id, target_type="platform",
                           data=changed, ip=ip)  # fmt: skip
    return AdminReviewRules(**after.model_dump())


CSV_HEADER = ("Date", "Company", "Technician", "Job", "Customer", "Rating", "Status", "Reason", "Review")


async def reviews_csv(
    db: AsyncSession, *, q: str | None, rating: str | None, status: str | None, company_id: uuid.UUID | None
) -> Iterable[str]:
    rows = (
        await db.execute(_base(_filters(q, rating, status, company_id)).order_by(*ORDER).limit(50_000))
    ).all()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(CSV_HEADER)
    for r, c, j, tech in rows:
        w.writerow([_csv_safe(x) for x in (
            r.created_at.date().isoformat(), c.name, tech or "", j.title, r.reviewer_name or "", r.rating,
            r.status, r.flag_reason or "", r.comment or "",
        )])  # fmt: skip
    return [buf.getvalue()]
