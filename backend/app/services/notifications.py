"""In-app messages (M42). Made where things happen (jobs, reports); never for the person who did it."""

import uuid

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.paging import MAX_LIMIT, decode_cursor, next_cursor
from app.core.security import now
from app.models import Job, Membership, Notification, User
from app.providers.storage import get_storage
from app.schemas.identity import ListMeta
from app.schemas.notifications import NotificationList, NotificationOut
from app.schemas.work import PersonRef


async def notify(
    db: AsyncSession,
    *,
    company_id: uuid.UUID,
    to: list[uuid.UUID | None],
    kind: str,
    actor_id: uuid.UUID | None,
    job: Job | None = None,
    report_id: uuid.UUID | None = None,
    params: dict[str, str | None] | None = None,
) -> None:
    from app.services import platform  # A29: messages switched off for everyone aren't made

    if kind != "announcement" and not (await platform.notification_rules(db)).allows(kind):
        return
    clean = {k: str(v) for k, v in (params or {}).items() if v not in (None, "")}
    for user_id in dict.fromkeys(u for u in to if u and u != actor_id):
        db.add(
            Notification(
                company_id=company_id,
                user_id=user_id,
                kind=kind,
                actor_id=actor_id,
                job_id=job.id if job else None,
                report_id=report_id,
                params=clean,
            )
        )


async def job_params(db: AsyncSession, job: Job) -> dict[str, str | None]:
    """The customer's name, the job's title and when it is."""
    from app.models import Customer

    name = await db.scalar(select(Customer.name).where(Customer.id == job.customer_id))
    return {
        "customer": name,
        "job": job.title,
        "scheduled_at": job.scheduled_at.isoformat() if job.scheduled_at else None,
    }


async def reviewers(db: AsyncSession, company_id: uuid.UUID, approving: bool = False) -> list[uuid.UUID]:
    """Owners and managers of the company. [approving]: who can approve a report, so the owners only on
    plans without manager approvals (D-148)."""
    roles = ("owner", "manager")
    if approving:
        from app.models import Company
        from app.services import plan_features

        company = await db.get(Company, company_id)
        if company and not plan_features.has(company, "manager_approvals"):
            roles = ("owner",)
    rows = await db.execute(
        select(Membership.user_id).where(
            Membership.company_id == company_id,
            Membership.status == "active",
            Membership.role.in_(roles),
        )
    )
    return list(rows.scalars())


async def owners(db: AsyncSession, company_id: uuid.UUID) -> list[uuid.UUID]:
    """The company's owners: they look after the plan and paying."""
    rows = await db.execute(
        select(Membership.user_id).where(
            Membership.company_id == company_id, Membership.status == "active", Membership.role == "owner"
        )
    )
    return list(rows.scalars())


def _where(p: Principal):
    return (Notification.user_id == p.user.id, Notification.company_id == p.company_id)


async def unread_count(db: AsyncSession, p: Principal) -> int:
    return (
        await db.scalar(
            select(func.count()).select_from(Notification).where(*_where(p), Notification.read_at.is_(None))
        )
    ) or 0


async def list_notifications(
    db: AsyncSession, p: Principal, cursor: str | None, limit: int
) -> NotificationList:
    from app.services.evidence import covers

    limit = max(1, min(limit, MAX_LIMIT))
    offset = decode_cursor(cursor)
    rows = list(
        (
            await db.execute(
                select(Notification)
                .where(*_where(p))
                .order_by(Notification.created_at.desc(), Notification.id.desc())
                .offset(offset)
                .limit(limit + 1)
            )
        ).scalars()
    )
    page = rows[:limit]
    job_ids = {n.job_id for n in page if n.job_id}
    jobs = list((await db.execute(select(Job).where(Job.id.in_(job_ids)))).scalars()) if job_ids else []
    cover = await covers(db, jobs)
    actor_ids = {n.actor_id for n in page if n.actor_id}
    actors = (
        {u.id: u for u in (await db.execute(select(User).where(User.id.in_(actor_ids)))).scalars()}
        if actor_ids
        else {}
    )
    storage = get_storage()

    def person(uid: uuid.UUID | None) -> PersonRef | None:
        u = actors.get(uid) if uid else None
        if u is None:
            return None
        return PersonRef(
            id=u.id, name=u.name or "", avatar_url=storage.presign_get(u.avatar_key) if u.avatar_key else None
        )

    items = [
        NotificationOut(
            id=n.id,
            kind=n.kind,
            params=n.params or {},
            actor=person(n.actor_id),
            job_id=n.job_id,
            report_id=n.report_id,
            cover_url=cover.get(n.job_id) if n.job_id else None,
            read=n.read_at is not None,
            created_at=n.created_at,
        )
        for n in page
    ]
    return NotificationList(
        data=items,
        meta=ListMeta(
            counts={"unread": await unread_count(db, p)}, next_cursor=next_cursor(offset, limit, len(rows))
        ),
    )


async def mark_read(db: AsyncSession, p: Principal, ids: list[uuid.UUID] | None) -> int:
    q = update(Notification).where(*_where(p), Notification.read_at.is_(None))
    if ids is not None:
        q = q.where(Notification.id.in_(ids))
    await db.execute(q.values(read_at=now()))
    await db.flush()
    return await unread_count(db, p)
