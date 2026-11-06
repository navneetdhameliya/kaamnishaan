"""Owner/manager dashboard (M13), technician Today (M12), profile counts (M37), and the sync feed
the app's offline store reads (GET /sync/changes).

Photos and reports arrive in later steps; their counts are 0 until then.
"""

from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError
from app.core.security import now
from app.models import Customer, Job, JobEvent, Membership, User
from app.schemas.work import (
    Dashboard,
    DayCount,
    MeStats,
    Onboarding,
    SyncChanges,
    TeamNow,
    Today,
    TodayStats,
)
from app.services.jobs import CLOSED, day_bounds, items, job_out, local_today, tz

SYNC_PAGE = 200
SYNC_OVERLAP = timedelta(seconds=2)  # re-send a little; the app keeps the highest version per job


async def dashboard(db: AsyncSession, p: Principal) -> Dashboard:
    p.require("jobs.view_all")
    today = local_today(p)
    start, end = day_bounds(p, today)
    base = select(Job).where(Job.company_id == p.company_id, Job.deleted_at.is_(None))
    sub = base.where(Job.scheduled_at >= start, Job.scheduled_at < end).subquery()
    by_status = dict((await db.execute(select(sub.c.status, func.count()).group_by(sub.c.status))).all())
    done_today = (
        await db.execute(
            select(func.count()).where(
                Job.company_id == p.company_id, Job.completed_at >= start, Job.completed_at < end
            )
        )
    ).scalar_one()
    to_review = (
        await db.execute(
            select(func.count()).where(
                Job.company_id == p.company_id, Job.deleted_at.is_(None), Job.status == "in_review"
            )
        )
    ).scalar_one()

    week_start, _ = day_bounds(p, today - timedelta(days=6))
    completed = (
        (
            await db.execute(
                select(Job.completed_at).where(Job.company_id == p.company_id, Job.completed_at >= week_start)
            )
        )
        .scalars()
        .all()
    )
    per_day = {}
    for t in completed:
        d = t.astimezone(tz(p)).date()
        per_day[d] = per_day.get(d, 0) + 1
    week = [
        DayCount(
            date=today - timedelta(days=i),
            completed=per_day.get(today - timedelta(days=i), 0),
            reports_sent=0,
        )
        for i in range(6, -1, -1)
    ]

    members = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(Membership.company_id == p.company_id, Membership.status == "active")
        )
    ).all()
    running = {
        j.assigned_to: j
        for j in (
            await db.execute(base.where(Job.status == "in_progress").order_by(Job.started_at))
        ).scalars()
    }
    team_now = [
        TeamNow(
            id=u.id,
            name=u.name or "",
            role=m.role,
            status="on_job" if u.id in running else "idle",
            current_job=f"J-{running[u.id].number}" if u.id in running else None,
        )  # fmt: skip
        for m, u in members
        if m.role != "owner" or u.id in running
    ]
    team_now.sort(key=lambda t: (t.status != "on_job", t.name.lower()))

    invited = (
        len(members) > 1
        or (
            await db.execute(
                select(func.count()).where(
                    Membership.company_id == p.company_id, Membership.status == "invited"
                )
            )
        ).scalar_one()
        > 0
    )
    any_job = (await db.execute(base.with_only_columns(Job.id).limit(1))).first() is not None
    return Dashboard(
        date=today,
        today={
            "unassigned": by_status.get("unassigned", 0),
            "assigned": by_status.get("assigned", 0),
            "in_progress": by_status.get("in_progress", 0),
            "done": done_today,
        },
        to_review=to_review,
        week=week,
        team_now=team_now,
        onboarding=Onboarding(team_invited=invited, first_job_created=any_job, first_report_sent=False),
    )


async def today(db: AsyncSession, p: Principal) -> Today:
    d = local_today(p)
    start, end = day_bounds(p, d)
    mine = select(Job).where(
        Job.company_id == p.company_id, Job.deleted_at.is_(None), Job.assigned_to == p.user.id
    )
    todays = (
        (
            await db.execute(
                mine.where(Job.scheduled_at >= start, Job.scheduled_at < end).order_by(
                    Job.scheduled_at, Job.number
                )
            )
        )
        .scalars()
        .all()
    )
    current = (
        await db.execute(mine.where(Job.status == "in_progress").order_by(Job.started_at.desc()).limit(1))
    ).scalar_one_or_none()
    upcoming = [j for j in todays if j.status == "assigned" and (not current or j.id != current.id)]
    return Today(
        date=d,
        name=p.user.name or "",
        company=p.company.name if p.company else None,
        stats=TodayStats(
            jobs=len([j for j in todays if j.status != "cancelled"]),
            done=len([j for j in todays if j.status in ("in_review", "completed")]),
            photos=0,
        ),
        current_job=(await items(db, [current]))[0] if current else None,
        next_jobs=await items(db, upcoming),
        unread=0,
    )


async def stats(db: AsyncSession, p: Principal) -> MeStats:
    done = (
        await db.execute(
            select(func.count()).where(
                Job.company_id == p.company_id,
                Job.assigned_to == p.user.id,
                Job.status.in_(("in_review", "completed")),
            )
        )
    ).scalar_one()
    team = customers = to_review = None
    if "team.view" in p.permissions:
        team = (
            await db.execute(
                select(func.count()).where(
                    Membership.company_id == p.company_id, Membership.status == "active"
                )
            )
        ).scalar_one()
    if "customers.manage" in p.permissions:
        customers = (
            await db.execute(
                select(func.count()).where(Customer.company_id == p.company_id, Customer.deleted_at.is_(None))
            )
        ).scalar_one()
    if "reports.approve" in p.permissions:
        to_review = (
            await db.execute(
                select(func.count()).where(
                    Job.company_id == p.company_id, Job.deleted_at.is_(None), Job.status == "in_review"
                )
            )
        ).scalar_one()
    return MeStats(
        jobs_done=done, photos=0, reports_sent=0, team=team, customers=customers, to_review=to_review
    )


async def sync_changes(db: AsyncSession, p: Principal, since: str | None) -> SyncChanges:
    """Jobs changed since the cursor, for the app's offline store.

    First sync (no cursor): open jobs plus anything changed in the last 30 days.
    The cursor is the newest updated_at sent; the next call overlaps it by 2 seconds.
    """
    since_at = None
    if since:
        try:
            since_at = datetime.fromisoformat(since)
        except ValueError as e:
            raise AppError(
                "validation_error", "This sync position is not valid.", fields={"since": "invalid"}
            ) from e

    q = select(Job).where(Job.company_id == p.company_id)
    if "jobs.view_all" not in p.permissions:
        q = q.where(Job.assigned_to == p.user.id)
    if since_at:
        q = q.where(Job.updated_at > since_at - SYNC_OVERLAP)
    else:
        q = q.where(Job.deleted_at.is_(None)).where(
            (Job.status.not_in(CLOSED)) | (Job.updated_at > now() - timedelta(days=30))
        )
    rows = (await db.execute(q.order_by(Job.updated_at, Job.id).limit(SYNC_PAGE + 1))).scalars().all()
    page = list(rows[:SYNC_PAGE])
    live = [j for j in page if j.deleted_at is None]
    removed = [j.id for j in page if j.deleted_at is not None]

    if since_at and "jobs.view_all" not in p.permissions:
        # jobs moved from this technician to someone else drop out of their phone too
        moved = (
            (
                await db.execute(
                    select(JobEvent.job_id)
                    .join(Job, Job.id == JobEvent.job_id)
                    .where(
                        JobEvent.company_id == p.company_id,
                        JobEvent.type.in_(("assigned", "unassigned")),
                        JobEvent.data["previous"].astext == str(p.user.id),
                        JobEvent.at > since_at - SYNC_OVERLAP,
                        (Job.assigned_to.is_(None)) | (Job.assigned_to != p.user.id),
                    )
                )
            )
            .scalars()
            .all()
        )
        removed.extend(m for m in moved if m not in removed)

    cursor_at = page[-1].updated_at if page else (since_at or now())
    return SyncChanges(
        jobs=[await job_out(db, p, j) for j in live],
        removed_job_ids=removed,
        cursor=cursor_at.isoformat(),
        has_more=len(rows) > SYNC_PAGE,
    )
