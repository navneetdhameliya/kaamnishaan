"""A08 Users list and A09 User details for KaamNishaan staff, plus two actions: turn a person off
(or back on) and sign them out everywhere. Both are written to the audit log with the reason."""

import uuid
from datetime import timedelta

from sqlalchemy import Select, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import AuditLog, AuthSession, Company, Invitation, Job, JobEvent, Membership, Report, User
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_users import (
    AdminUserActivity,
    AdminUserCompany,
    AdminUserCounts,
    AdminUserDetail,
    AdminUserList,
    AdminUserRow,
)
from app.services import audit

ROLES = ("technician", "manager", "owner")
# what a person did that the details page lists (other audit entries stay in the audit log)
SHOWN = (
    "job.created",
    "job.assigned",
    "job.cancelled",
    "report.submitted",
    "report.approved",
    "report.changes_requested",
    "report.sent",
    "customer.created",
    "team.invited",
    "team.joined",
    "review.replied",
    "password.reset",
)


def _on_job():
    return (
        select(Job.id)
        .where(Job.assigned_to == User.id, Job.status == "in_progress", Job.deleted_at.is_(None))
        .correlate(User)
        .exists()
    )


def _name():
    """The person's name, or for someone not joined yet, the name on their latest invitation."""
    invited = (
        select(Invitation.name)
        .where(Invitation.membership_id == Membership.id)
        .order_by(Invitation.created_at.desc())
        .limit(1)
        .correlate(Membership)
        .scalar_subquery()
    )
    return func.coalesce(User.name, invited)


def _login(u: User, invited: bool) -> str:
    if invited:
        return "invited"
    return "email" if u.email and u.password_hash else "phone"


def _filtered(q, role, status, language, company_id) -> Select:
    stmt = (
        select(Membership, User, Company)
        .join(User, User.id == Membership.user_id)
        .join(Company, Company.id == Membership.company_id)
    )
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                User.name.ilike(like),
                User.email.ilike(like),
                User.phone.ilike(like),
                Company.name.ilike(like),
            )
        )
    if role:
        stmt = stmt.where(Membership.role == role)
    if status == "disabled":
        stmt = stmt.where(User.status == "disabled")
    elif status:
        stmt = stmt.where(Membership.status == status, User.status != "disabled")
    else:
        stmt = stmt.where(Membership.status != "removed")
    if language:
        stmt = stmt.where(User.app_language == language, Membership.status == "active")
    if company_id:
        stmt = stmt.where(Membership.company_id == company_id)
    return stmt


async def users(
    db: AsyncSession,
    *,
    q: str | None,
    role: str | None,
    status: str | None,
    language: str | None,
    company_id: uuid.UUID | None,
    page: int,
    page_size: int,
) -> AdminUserList:
    base = _filtered(q, None, status, language, company_id)
    found = base.with_only_columns(Membership.role, Membership.status).subquery()
    by_role = dict((await db.execute(select(found.c.role, func.count()).group_by(found.c.role))).all())
    invited = int(await db.scalar(select(func.count()).where(found.c.status == "invited")) or 0)
    if role:
        base = base.where(Membership.role == role)
    total = int(
        await db.scalar(select(func.count()).select_from(base.with_only_columns(Membership.id).subquery()))
        or 0
    )

    on_job = _on_job().label("on_job")
    rows = (
        await db.execute(
            base.add_columns(on_job, _name().label("shown"))
            .order_by(User.last_seen_at.desc().nulls_last(), Membership.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()
    company = None
    if company_id:
        c = await db.get(Company, company_id)
        company = AdminOption(value=str(company_id), label=c.name) if c else None
    return AdminUserList(
        items=[
            AdminUserRow(
                membership_id=m.id,
                user_id=u.id,
                name=shown,
                phone=u.phone,
                email=u.email,
                company_id=c.id,
                company=c.name,
                role=m.role,
                login=_login(u, m.status == "invited"),
                language=None if m.status == "invited" else u.app_language,
                status="disabled" if u.status == "disabled" else m.status,
                on_job=bool(busy),
                last_seen_at=u.last_seen_at,
                invited_at=m.created_at if m.status == "invited" else None,
            )
            for m, u, c, busy, shown in rows
        ],
        total=total,
        page=page,
        page_size=page_size,
        counts=AdminUserCounts(
            all=sum(by_role.values()), invited=invited, **{r: by_role.get(r, 0) for r in ROLES}
        ),
        company=company,
    )


async def _user(db: AsyncSession, user_id: uuid.UUID) -> User:
    u = await db.get(User, user_id)
    if not u:
        raise NotFound("user_not_found", "This person doesn't exist.")
    return u


async def user(db: AsyncSession, user_id: uuid.UUID) -> AdminUserDetail:
    u = await _user(db, user_id)
    t = now()
    since = t - timedelta(days=30)
    links = (
        await db.execute(
            select(Membership, Company)
            .join(Company, Company.id == Membership.company_id)
            .where(Membership.user_id == u.id)
            .order_by(Membership.created_at)
        )
    ).all()
    invited_only = bool(links) and all(m.status == "invited" for m, _ in links)
    name = u.name
    if not name and links:
        name = await db.scalar(
            select(Invitation.name)
            .where(Invitation.membership_id.in_([m.id for m, _ in links]))
            .order_by(Invitation.created_at.desc())
            .limit(1)
        )
    sessions = (
        (
            await db.execute(
                select(AuthSession)
                .where(
                    AuthSession.user_id == u.id, AuthSession.revoked_at.is_(None), AuthSession.expires_at > t
                )
                .order_by(AuthSession.last_used_at.desc().nulls_last())
            )
        )
        .scalars()
        .all()
    )
    device = None
    if sessions and (sessions[0].platform or sessions[0].app_version):
        s0 = sessions[0]
        platform = {"android": "Android", "ios": "iOS", "web": "Web"}.get(s0.platform or "", s0.platform)
        device = " · ".join(x for x in (platform, s0.app_version and f"app {s0.app_version}") if x)

    async def n(q) -> int:
        return int(await db.scalar(q) or 0)

    jobs = await n(
        select(func.count()).where(
            or_(Job.assigned_to == u.id, Job.created_by == u.id),
            Job.created_at >= since,
            Job.deleted_at.is_(None),
        )
    )
    reports = await n(select(func.count()).where(Report.created_by == u.id, Report.created_at >= since))
    changes = await n(
        select(func.count())
        .select_from(JobEvent)
        .join(Job, Job.id == JobEvent.job_id)
        .where(Job.assigned_to == u.id, JobEvent.to_status == "changes_requested", JobEvent.at >= since)
    )
    on_job = await n(
        select(func.count()).where(
            Job.assigned_to == u.id, Job.status == "in_progress", Job.deleted_at.is_(None)
        )
    )
    activity = (
        await db.execute(
            select(AuditLog.action, AuditLog.created_at)
            .where(AuditLog.actor_id == u.id, AuditLog.action.in_(SHOWN))
            .order_by(AuditLog.created_at.desc())
            .limit(6)
        )
    ).all()
    return AdminUserDetail(
        id=u.id,
        name=name,
        phone=u.phone,
        email=u.email,
        email_verified=u.email_verified_at is not None,
        login=_login(u, invited_only),
        status=u.status,
        app_language=u.app_language,
        created_at=u.created_at,
        last_seen_at=u.last_seen_at,
        on_job=on_job > 0,
        device=device,
        active_sessions=len(sessions),
        companies=[
            AdminUserCompany(
                membership_id=m.id,
                company_id=c.id,
                company=c.name,
                role=m.role,
                status=m.status,
                joined_at=m.joined_at or (m.created_at if m.status == "active" else None),
                report_language=c.report_language,
            )
            for m, c in links
        ],
        jobs_30d=jobs,
        reports_30d=reports,
        changes_asked_30d=changes,
        activity=[AdminUserActivity(action=a, at=at) for a, at in activity],
    )


async def _end_sessions(db: AsyncSession, user_id: uuid.UUID) -> int:
    r = await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=now())
    )
    return r.rowcount or 0


async def set_active(
    db: AsyncSession, user_id: uuid.UUID, *, active: bool, reason: str, staff_id: uuid.UUID, ip: str | None
) -> AdminUserDetail:
    """Turn a person off for every company (they can't log in; their sessions end) or back on."""
    u = await _user(db, user_id)
    if active and u.status != "disabled":
        raise AppError("not_disabled", "This person is not turned off.", status=409)
    if not active and u.status == "disabled":
        raise AppError("already_disabled", "This person is already turned off.", status=409)
    if active:
        joined = await db.scalar(
            select(func.count()).where(Membership.user_id == u.id, Membership.status == "active")
        )
        u.status = "active" if joined or u.password_hash else "invited"
        ended = 0
    else:
        u.status = "disabled"
        ended = await _end_sessions(db, u.id)
    await audit.record(
        db,
        "staff.user_enabled" if active else "staff.user_disabled",
        staff_id=staff_id,
        target_type="user",
        target_id=u.id,
        data={"reason": reason.strip(), "sessions_ended": ended},
        ip=ip,
    )
    await db.flush()
    return await user(db, u.id)


async def sign_out(
    db: AsyncSession, user_id: uuid.UUID, *, reason: str, staff_id: uuid.UUID, ip: str | None
) -> AdminUserDetail:
    """End every session: the person logs in again on each phone (OTP) or browser."""
    u = await _user(db, user_id)
    ended = await _end_sessions(db, u.id)
    await audit.record(
        db,
        "staff.user_signed_out",
        staff_id=staff_id,
        target_type="user",
        target_id=u.id,
        data={"reason": reason.strip(), "sessions_ended": ended},
        ip=ip,
    )
    await db.flush()
    return await user(db, u.id)
