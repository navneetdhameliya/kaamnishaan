"""A10 Roles and permissions: the role table (read from the rules the server enforces, so it can't drift)
and KaamNishaan staff accounts (invite, role, turn off/on, new setup link). Super admins only."""

import uuid

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.permissions import permissions_for
from app.core.security import now
from app.models import StaffSession, StaffUser
from app.schemas.admin_staff import AdminRoleCell, AdminRoleRow, AdminStaffRow
from app.services import audit
from app.services import staff as staff_svc

COLUMNS = ("super_admin", "owner", "manager", "technician", "customer")


def _cell(value: str, note: str | None = None) -> AdminRoleCell:
    return AdminRoleCell(value=value, note=note)


def matrix() -> list[AdminRoleRow]:
    """Company roles come from core/permissions.py; "if allowed" = a switch each company sets."""
    owner, manager = permissions_for("owner"), permissions_for("manager")
    tech = permissions_for("technician", {})
    tech_all = permissions_for(
        "technician", {"technicians_can_share": True, "technicians_can_request_reviews": True}
    )

    def company(*perms: str, tech_note: str | None = None) -> dict[str, AdminRoleCell]:
        def has(ps):
            return any(p in ps for p in perms)

        if has(tech):
            t = _cell("partial", tech_note) if tech_note else _cell("yes")
        elif has(tech_all):
            t = _cell("partial", "if_allowed")
        else:
            t = _cell("no")
        return {
            "owner": _cell("yes" if has(owner) else "no"), "manager": _cell("yes" if has(manager) else "no"),
            "technician": t, "customer": _cell("no"),
        }  # fmt: skip

    no = _cell("no")
    rows = [
        ("platform", {"super_admin": _cell("yes"), "owner": no, "manager": no, "technician": no,
                      "customer": no}),
        ("company", {"super_admin": _cell("yes"), **company("company.manage", "billing.manage")}),
        ("users", {"super_admin": _cell("yes"), **company("team.invite_manager", "team.invite_technician")}),
        ("jobs", {"super_admin": no, **company("jobs.create", "jobs.create_quick", tech_note="quick_job")}),
        ("capture", {"super_admin": no, **company("evidence.capture")}),
        ("approve", {"super_admin": no, **company("reports.approve")}),
        ("share", {"super_admin": no, **company("reports.share")}),
        ("reviews", {"super_admin": _cell("yes"), **company("reviews.request")}),
        ("checklists", {"super_admin": _cell("yes"), **company("checklists.manage")}),
        ("view_report", {"super_admin": no, "owner": no, "manager": no, "technician": no,
                         "customer": _cell("partial", "secure_link")}),
        ("audit", {"super_admin": _cell("yes"), **company("audit.view")}),
    ]  # fmt: skip
    out = []
    for key, cells in rows:
        if key == "users":  # managers may invite technicians only
            cells["manager"] = _cell("partial", "technicians")
        if key == "audit" and cells["owner"].value == "yes":
            cells["owner"] = _cell("partial", "own_company")
        out.append(AdminRoleRow(key=key, cells={c: cells[c] for c in COLUMNS}))
    return out


def staff_matrix() -> list[AdminRoleRow]:
    """The admin panel's own roles, as enforced in routes/admin.py."""
    y, n = _cell("yes"), _cell("no")
    rows = {
        "look": (y, y, y),  # every page
        "change": (y, y, n),  # companies, users, reviews, checklists, credits, AI calls, templates
        "platform": (y, n, n),  # platform and email settings, staff accounts
    }
    return [
        AdminRoleRow(key=k, cells={"super_admin": a, "admin": b, "support": c})
        for k, (a, b, c) in rows.items()
    ]


def _row(s: StaffUser, me: uuid.UUID) -> AdminStaffRow:
    return AdminStaffRow(
        id=s.id, name=s.name, email=s.email, role=s.role, status=s.status, last_login_at=s.last_login_at,
        created_at=s.created_at, me=s.id == me,
    )  # fmt: skip


async def staff_list(db: AsyncSession, me: uuid.UUID) -> list[AdminStaffRow]:
    rows = (await db.execute(select(StaffUser).order_by(StaffUser.created_at))).scalars().all()
    return [_row(s, me) for s in rows]


async def invite(
    db: AsyncSession, *, name: str, email: str, role: str, by: uuid.UUID
) -> tuple[AdminStaffRow, str]:
    email = email.strip().lower()
    if await db.scalar(select(StaffUser.id).where(StaffUser.email == email)):
        raise AppError("staff_exists", "Someone already has a staff account with this email.",
                       fields={"email": "taken"}, status=409)  # fmt: skip
    s = StaffUser(email=email, name=name.strip(), role=role, status="invited")
    db.add(s)
    await db.flush()
    link = await staff_svc.issue_setup_link(db, s, by=by, via="admin_panel")
    return _row(s, by), link


async def _other(db: AsyncSession, staff_id: uuid.UUID, me: uuid.UUID) -> StaffUser:
    s = await db.get(StaffUser, staff_id, with_for_update=True)
    if not s:
        raise NotFound("not_found", "Staff member not found.")
    if s.id == me:
        raise AppError("not_yourself", "Ask another super admin to change your own account.", status=409)
    return s


async def _last_super(db: AsyncSession, s: StaffUser) -> bool:
    others = await db.scalar(
        select(func.count()).where(
            StaffUser.role == "super_admin", StaffUser.status != "disabled", StaffUser.id != s.id
        )
    )
    return s.role == "super_admin" and not others


async def change(
    db: AsyncSession, staff_id: uuid.UUID, *, role: str | None, active: bool | None, by: uuid.UUID,
    ip: str | None,
) -> AdminStaffRow:  # fmt: skip
    s = await _other(db, staff_id, by)
    if ((role and role != "super_admin") or active is False) and await _last_super(db, s):
        raise AppError("last_super_admin", "Keep at least one super admin.", status=409)
    if role and role != s.role:
        await audit.record(db, "staff.role_changed", staff_id=by, target_type="staff", target_id=s.id,
                           data={"from": s.role, "to": role}, ip=ip)  # fmt: skip
        s.role = role
    if active is False and s.status != "disabled":
        s.status = "disabled"
        await db.execute(
            update(StaffSession)
            .where(StaffSession.staff_id == s.id, StaffSession.revoked_at.is_(None))
            .values(revoked_at=now())
        )  # signed out everywhere at once
        await audit.record(db, "staff.disabled", staff_id=by, target_type="staff", target_id=s.id, ip=ip)
    elif active is True and s.status == "disabled":
        s.status = "active" if s.password_hash else "invited"
        await audit.record(db, "staff.enabled", staff_id=by, target_type="staff", target_id=s.id, ip=ip)
    await db.flush()
    return _row(s, by)


async def new_link(db: AsyncSession, staff_id: uuid.UUID, *, by: uuid.UUID) -> tuple[AdminStaffRow, str]:
    """A fresh setup link: their password and authenticator are cleared and they're signed out."""
    s = await _other(db, staff_id, by)
    if s.status == "disabled":
        raise AppError("staff_disabled", "Turn the account back on first.", status=409)
    link = await staff_svc.issue_setup_link(db, s, by=by, via="admin_panel")
    return _row(s, by), link
