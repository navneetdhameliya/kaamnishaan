"""A31 Audit logs: every recorded action, newest first, with readable actors and targets."""

import csv
import io
import uuid
from collections import defaultdict
from datetime import timedelta

from sqlalchemy import String, cast, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import AuditLog, Company, Customer, Invitation, Job, Lead, Report, StaffUser, User
from app.schemas.admin_audit import AdminAuditActor, AdminAuditList, AdminAuditRow
from app.schemas.admin_companies import AdminOption

SECURITY_STAFF = ("staff.login", "staff.login_failed", "staff.logout", "staff.setup_done", "staff.reset",
                  "staff.invited", "staff.session_reuse")  # fmt: skip
PREFIX_GROUP = {
    "session.": "security",
    "password.": "security",
    "email.": "security",
    "staff.": "admin",
    "company.": "company",
    "team.": "team",
    "job.": "jobs",
    "customer.": "jobs",
    "evidence.": "jobs",
    "voice_note.": "jobs",
    "checklist.": "jobs",
    "report.": "reports",
    "share_link.": "reports",
    "review.": "reports",
    "review_settings.": "reports",
}
GROUPS = ("security", "admin", "company", "team", "jobs", "reports")


def group_of(action: str) -> str:
    if action in SECURITY_STAFF:
        return "security"
    return next((g for p, g in PREFIX_GROUP.items() if action.startswith(p)), "other")


def _group_filter(g: str):
    if g == "security":
        return or_(
            AuditLog.action.in_(SECURITY_STAFF),
            *[AuditLog.action.startswith(p) for p, x in PREFIX_GROUP.items() if x == g],
        )
    if g == "admin":
        return AuditLog.action.startswith("staff.") & AuditLog.action.not_in(SECURITY_STAFF)
    prefixes = [p for p, x in PREFIX_GROUP.items() if x == g]
    return or_(*[AuditLog.action.startswith(p) for p in prefixes])


def _change(data: dict) -> str | None:
    """'new → contacted' from {"from","to"} or {"status": {"from","to"}} / {"role": {...}}."""
    for v in (data, data.get("status"), data.get("role"), data.get("plan")):
        if isinstance(v, dict) and "from" in v and "to" in v:
            return f"{v['from']} → {v['to']}"
    return None


def _filtered(*, q, actor, group, company_id, days):
    stmt = (
        select(AuditLog)
        .outerjoin(User, User.id == AuditLog.actor_id)
        .outerjoin(StaffUser, StaffUser.id == AuditLog.staff_id)
        .where(AuditLog.created_at >= now() - timedelta(days=days))
    )
    if actor == "staff":
        stmt = stmt.where(AuditLog.staff_id.is_not(None))
    elif actor == "user":
        stmt = stmt.where(AuditLog.actor_id.is_not(None))
    elif actor == "system":
        stmt = stmt.where(AuditLog.actor_id.is_(None), AuditLog.staff_id.is_(None))
    if group:
        stmt = stmt.where(_group_filter(group))
    if company_id:
        stmt = stmt.where(AuditLog.company_id == company_id)
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                AuditLog.action.ilike(like),
                AuditLog.target_id.ilike(like),
                AuditLog.target_type.ilike(like),
                cast(AuditLog.data, String).ilike(like),
                cast(AuditLog.ip, String).ilike(like),
                User.name.ilike(like),
                User.email.ilike(like),
                User.phone.ilike(like),
                StaffUser.name.ilike(like),
                StaffUser.email.ilike(like),
            )
        )
    return stmt


async def _names(db: AsyncSession, logs: list[AuditLog]) -> dict:
    """Readable names for every actor, company and target on the page, a few queries in all."""
    ids: dict[str, set] = defaultdict(set)
    for x in logs:
        if x.actor_id:
            ids["user"].add(x.actor_id)
        if x.staff_id:
            ids["staff"].add(x.staff_id)
        if x.company_id:
            ids["company"].add(x.company_id)
        if x.target_type and x.target_id:
            try:
                ids[x.target_type].add(uuid.UUID(x.target_id))
            except ValueError:
                pass
    out: dict[tuple[str, uuid.UUID], str] = {}

    async def fetch(kind: str, model, *cols, fmt=lambda r: r[1]):
        if not ids.get(kind):
            return
        for r in (await db.execute(select(model.id, *cols).where(model.id.in_(ids[kind])))).all():
            out[(kind, r[0])] = fmt(r)

    await fetch("user", User, User.name, User.phone, User.email, fmt=lambda r: r[1] or r[2] or r[3])
    await fetch("staff", StaffUser, StaffUser.name, StaffUser.role, fmt=lambda r: f"{r[1]}|{r[2]}")
    await fetch("company", Company, Company.name)
    await fetch("lead", Lead, Lead.number, fmt=lambda r: f"KN-{r[1]}")
    await fetch("report", Report, Report.number, fmt=lambda r: f"R-{r[1]}")
    await fetch("job", Job, Job.number, Job.title, fmt=lambda r: f"J-{r[1]} {r[2]}".strip())
    await fetch("customer", Customer, Customer.name)
    await fetch("invite", Invitation, Invitation.name)
    return out


def _row(x: AuditLog, names: dict) -> AdminAuditRow:
    if x.staff_id:
        name, _, role = names.get(("staff", x.staff_id), "|").partition("|")
        actor = AdminAuditActor(kind="staff", id=x.staff_id, name=name or None, role=role or None)
    elif x.actor_id:
        actor = AdminAuditActor(
            kind="user", id=x.actor_id, name=names.get(("user", x.actor_id)), role=x.actor_role
        )
    elif x.action == "staff.login_failed":
        actor = AdminAuditActor(kind="unknown", id=None, name=None, role=None)
    else:
        actor = AdminAuditActor(kind="system", id=None, name=None, role=None)
    target = None
    if x.target_type and x.target_id:
        try:
            key = (x.target_type, uuid.UUID(x.target_id))
            target = names.get(key)
            if x.target_type == "staff" and target:
                target = target.partition("|")[0]
        except ValueError:
            target = x.target_id
    if x.action == "staff.login_failed" and not target:
        target = (x.data or {}).get("email")
    return AdminAuditRow(
        id=x.id,
        at=x.created_at,
        actor=actor,
        action=x.action,
        group=group_of(x.action),
        target_type=x.target_type,
        target_id=x.target_id,
        target=target,
        change=_change(x.data or {}),
        company_id=x.company_id,
        company=names.get(("company", x.company_id)) if x.company_id else None,
        ip=str(x.ip) if x.ip else None,
        data=x.data or {},
    )


async def logs(
    db: AsyncSession, *, q, actor, group, company_id, days: int, page: int, page_size: int
) -> AdminAuditList:
    stmt = _filtered(q=q, actor=actor, group=group, company_id=company_id, days=days)
    total = int(
        await db.scalar(select(func.count()).select_from(stmt.with_only_columns(AuditLog.id).subquery())) or 0
    )
    rows = list(
        (
            await db.execute(
                stmt.order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        ).scalars()
    )
    names = await _names(db, rows)
    company = None
    if company_id:
        c = await db.get(Company, company_id)
        company = AdminOption(value=str(company_id), label=c.name) if c else None
    return AdminAuditList(
        items=[_row(x, names) for x in rows], total=total, page=page, page_size=page_size, company=company
    )


EXPORT_LIMIT = 50_000


def _csv_safe(v: object) -> str:
    s = "" if v is None else str(v)
    return "'" + s if s[:1] in ("=", "+", "-", "@", "\t", "\r") else s


async def logs_csv(db: AsyncSession, **filters) -> str:
    stmt = _filtered(**filters).order_by(AuditLog.created_at.desc(), AuditLog.id.desc()).limit(EXPORT_LIMIT)
    rows = list((await db.execute(stmt)).scalars())
    names = await _names(db, rows)
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(("Time (UTC)", "Actor", "Actor type", "Role", "Action", "Target", "Change", "Company", "IP"))
    for x in rows:
        r = _row(x, names)
        w.writerow(
            [
                _csv_safe(v)
                for v in (
                    r.at.strftime("%Y-%m-%d %H:%M:%S"),
                    r.actor.name,
                    r.actor.kind,
                    r.actor.role,
                    r.action,
                    r.target or r.target_type,
                    r.change,
                    r.company,
                    r.ip,
                )
            ]
        )
    return "﻿" + buf.getvalue()
