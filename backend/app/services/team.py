"""Team list, role changes, removal, and phone invites (M10, M40).

Invite lifecycle: pending -> accepted / declined / expired (7 days) / revoked.
An invited person gets a membership with status "invited" so seats are counted from the first SMS.
"""

import uuid
from datetime import timedelta

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import Principal
from app.core.errors import Conflict, Forbidden, Gone, NotFound, PlanLimit, RateLimited
from app.core.security import digest, normalize_phone, now, random_token
from app.models import AuthSession, Company, Invitation, Job, Membership, Plan, User
from app.providers.messaging import SMS_TEMPLATES, send_sms
from app.schemas.identity import (
    InviteCompany,
    InviteCreate,
    InviteOut,
    InvitePreview,
    InviterOut,
    ListMeta,
    MemberList,
    MemberOut,
    MyInvite,
)
from app.services import audit

INVITE_TTL = timedelta(days=7)
RESEND_AFTER = timedelta(seconds=60)


def _invite_status(inv: Invitation) -> str:
    if inv.accepted_at:
        return "accepted"
    if inv.declined_at:
        return "declined"
    if inv.revoked_at:
        return "revoked"
    if inv.expires_at < now():
        return "expired"
    return "pending"


def _open_invite_filter():
    return (
        Invitation.accepted_at.is_(None),
        Invitation.declined_at.is_(None),
        Invitation.revoked_at.is_(None),
    )


# ---- team list -------------------------------------------------------------------------------
async def list_members(
    db: AsyncSession, company_id: uuid.UUID, role: str | None, q: str | None
) -> MemberList:
    open_invites = (
        await db.execute(
            select(Invitation.membership_id, Invitation.id, Invitation.name, Invitation.created_at)
            .where(Invitation.company_id == company_id, *_open_invite_filter())
            .order_by(Invitation.created_at)
        )
    ).all()
    latest = {mid: (iid, name) for mid, iid, name, _ in open_invites}  # newest wins
    sent = {mid: at for mid, _, _, at in open_invites}
    members = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(Membership.company_id == company_id, Membership.status.in_(("active", "invited")))
        )
    ).all()
    rows = [(m, u, *latest.get(m.id, (None, None))) for m, u in members]
    counts = {"all": len(rows), "owner": 0, "manager": 0, "technician": 0, "invited": 0}
    for m, *_ in rows:
        counts[m.role] += 1
        counts["invited"] += m.status == "invited"

    def keep(m: Membership, u: User, inv_name: str | None) -> bool:
        if role and m.role != role:
            return False
        if q:
            needle = q.lower()
            hay = " ".join(filter(None, [u.name, inv_name, u.phone])).lower()
            return needle in hay
        return True

    # today's jobs and who is on one now (M40); "driving" needs live location (later)
    from app.services.jobs import day_bounds_for

    start_, end_ = day_bounds_for(await db.get(Company, company_id))
    load = dict(
        (
            await db.execute(
                select(Job.assigned_to, func.count())
                .where(
                    Job.company_id == company_id, Job.deleted_at.is_(None), Job.status != "cancelled",
                    Job.scheduled_at >= start_, Job.scheduled_at < end_,
                )
                .group_by(Job.assigned_to)
            )
        ).all()
    )  # fmt: skip
    busy = set(
        (
            await db.execute(
                select(Job.assigned_to).where(
                    Job.company_id == company_id, Job.deleted_at.is_(None), Job.status == "in_progress"
                )
            )
        ).scalars()
    )
    from app.providers.storage import get_storage

    storage = get_storage()

    def live(m: Membership, u: User) -> str | None:
        if m.status != "active" or m.role != "technician":
            return None
        return "on_job" if u.id in busy else "idle"

    order = {"owner": 0, "manager": 1, "technician": 2}
    items = [
        MemberOut(
            id=u.id,
            name=u.name or inv_name or "",
            phone=u.phone,
            role=m.role,
            status=m.status,
            invite_id=inv_id if m.status == "invited" else None,
            joined_at=m.joined_at,
            avatar_url=storage.presign_get(u.avatar_key) if u.avatar_key else None,
            live_status=live(m, u),
            jobs_today=load.get(u.id, 0),
            invited_at=sent.get(m.id) if m.status == "invited" else None,
        )
        for m, u, inv_id, inv_name in sorted(
            rows, key=lambda r: (order[r[0].role], (r[1].name or r[3] or ""))
        )
        if keep(m, u, inv_name)
    ]
    return MemberList(data=items, meta=ListMeta(counts=counts))


async def _member(db: AsyncSession, company_id: uuid.UUID, user_id: uuid.UUID) -> tuple[Membership, User]:
    row = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(
                Membership.company_id == company_id,
                Membership.user_id == user_id,
                Membership.status.in_(("active", "invited")),
            )
        )
    ).first()
    if not row:
        raise NotFound("member_not_found", "Team member not found.")
    return row


async def get_member(db: AsyncSession, p: Principal, user_id: uuid.UUID) -> MemberOut:
    members = await list_members(db, p.company_id, None, None)
    for m in members.data:
        if m.id == user_id:
            return m
    raise NotFound("member_not_found", "Team member not found.")


def _can_manage(p: Principal, m: Membership) -> None:
    if m.user_id == p.user.id:
        raise Forbidden("cannot_change_self", "You can't change your own role or remove yourself.")
    if m.role == "owner":
        raise Forbidden("cannot_change_owner", "The owner can't be changed here.")
    if m.role == "manager" and "team.manage_managers" not in p.permissions:
        raise Forbidden("owner_only", "Only the owner can manage managers.")


async def change_role(db: AsyncSession, p: Principal, user_id: uuid.UUID, role: str) -> MemberOut:
    m, u = await _member(db, p.company_id, user_id)
    _can_manage(p, m)
    if role == "manager":
        p.require("team.manage_managers")
    if role != m.role:
        if role == "technician":
            await _check_seats(db, p.company)
        old, m.role = m.role, role
        await db.execute(
            update(Invitation)
            .where(Invitation.membership_id == m.id, *_open_invite_filter())
            .values(role=role)
        )
        await audit.record(
            db, "team.role_changed", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
            target_type="user", target_id=u.id, data={"before": old, "after": role},
        )  # fmt: skip
        await db.flush()
    return await get_member(db, p, user_id)


async def remove(db: AsyncSession, p: Principal, user_id: uuid.UUID) -> None:
    m, u = await _member(db, p.company_id, user_id)
    _can_manage(p, m)
    m.status = "removed"
    await db.execute(
        update(Invitation)
        .where(Invitation.membership_id == m.id, *_open_invite_filter())
        .values(revoked_at=now())
    )
    # their open sessions lose this company at once (every request re-checks membership too)
    await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == m.user_id, AuthSession.active_company_id == p.company_id)
        .values(active_company_id=None)
    )
    await audit.record(
        db, "team.removed", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="user", target_id=u.id, data={"role": m.role},
    )  # fmt: skip


# ---- invites (company side) --------------------------------------------------------------------
async def _check_seats(db: AsyncSession, company: Company) -> None:
    plan = await db.get(Plan, company.plan_code)
    if not plan or plan.technician_limit is None:
        return
    used = (
        await db.execute(
            select(func.count()).where(
                Membership.company_id == company.id,
                Membership.role == "technician",
                Membership.status.in_(("active", "invited")),
            )
        )
    ).scalar_one()
    if used >= plan.technician_limit:
        raise PlanLimit(
            "seat_limit_reached",
            "Your plan has no free technician seats. Upgrade to add more.",
            {"limit": plan.technician_limit, "used": used, "plan": plan.code},
        )


def _sms_text(inviter: str, company: str, link: str) -> str:
    return SMS_TEMPLATES["invite"].format(inviter=inviter, company=company, link=link)


async def _issue(
    db: AsyncSession, p: Principal, m: Membership, phone: str, name: str, lang: str
) -> InviteOut:
    token = random_token(24)
    inv = Invitation(
        company_id=m.company_id,
        membership_id=m.id,
        phone=phone,
        name=name,
        role=m.role,
        sms_language=lang,
        token_hash=digest(token),
        expires_at=now() + INVITE_TTL,
        invited_by=p.user.id,
    )
    db.add(inv)
    await db.flush()
    link = f"{get_settings().web_url}/join/{token}"
    inviter = p.user.name or "Your team"
    await send_sms(phone, "invite", inviter=inviter, company=p.company.name, link=link)
    return InviteOut(
        id=inv.id, user_id=m.user_id, phone=phone, name=name, role=m.role, status="pending",
        expires_at=inv.expires_at, sms_preview=_sms_text(inviter, p.company.name, link), link=link,
    )  # fmt: skip


async def invite(db: AsyncSession, p: Principal, body: InviteCreate, ip: str | None) -> InviteOut:
    p.require("team.invite_manager" if body.role == "manager" else "team.invite_technician")
    phone = normalize_phone(body.phone, p.company.country or get_settings().default_country)
    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    m = None
    if user:
        m = (
            await db.execute(
                select(Membership).where(Membership.company_id == p.company_id, Membership.user_id == user.id)
            )
        ).scalar_one_or_none()
        if m and m.status in ("active", "invited"):
            raise Conflict(
                "phone_in_team",
                "This number is already on your team."
                if m.status == "active"
                else "This number is already invited.",
                {
                    "existing_member": {
                        "user_id": str(user.id),
                        "status": m.status,
                        "role": m.role,
                        "name": user.name or await _invite_name(db, m),
                    }
                },
                fields={"phone": "phone_in_team"},
            )
    if body.role == "technician":
        await _check_seats(db, p.company)
    if not user:
        user = User(phone=phone, status="invited")
        db.add(user)
        await db.flush()
    if m:  # removed earlier: bring back as invited
        m.role, m.status, m.invited_by, m.joined_at = body.role, "invited", p.user.id, None
    else:
        m = Membership(
            company_id=p.company_id, user_id=user.id, role=body.role, status="invited", invited_by=p.user.id
        )
        db.add(m)
    await db.flush()
    out = await _issue(db, p, m, phone, body.name, body.sms_language or p.company.report_language)
    await audit.record(
        db, "team.invited", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="invite", target_id=out.id, data={"role": body.role}, ip=ip,
    )  # fmt: skip
    return out


async def _invite_name(db: AsyncSession, m: Membership) -> str:
    return (
        await db.execute(
            select(Invitation.name)
            .where(Invitation.membership_id == m.id)
            .order_by(Invitation.created_at.desc())
        )
    ).scalar() or ""


def preview(p: Principal) -> InvitePreview:
    """M40 shows the SMS while the form is filled; the real link is made when it is sent."""
    link = f"{get_settings().web_url}/join/…"
    return InvitePreview(text=_sms_text(p.user.name or "Your team", p.company.name, link))


async def _company_invite(db: AsyncSession, p: Principal, invite_id: uuid.UUID) -> Invitation:
    inv = (
        await db.execute(
            select(Invitation).where(Invitation.id == invite_id, Invitation.company_id == p.company_id)
        )
    ).scalar_one_or_none()
    if not inv:
        raise NotFound("invite_not_found", "Invite not found.")
    p.require("team.invite_manager" if inv.role == "manager" else "team.invite_technician")
    return inv


async def resend(db: AsyncSession, p: Principal, invite_id: uuid.UUID) -> InviteOut:
    inv = await _company_invite(db, p, invite_id)
    status = _invite_status(inv)
    if status in ("accepted", "declined", "revoked"):
        raise Gone(f"invite_{status}" if status != "revoked" else "invite_revoked", "This invite is closed.")
    if now() - inv.created_at < RESEND_AFTER:
        raise RateLimited("rate_limited", "Please wait a minute before sending again.", {"resend_after": 60})
    m = await db.get(Membership, inv.membership_id)
    inv.revoked_at = now()  # the old link stops working; a fresh 7-day invite replaces it
    return await _issue(db, p, m, inv.phone, inv.name, inv.sms_language)


async def revoke(db: AsyncSession, p: Principal, invite_id: uuid.UUID) -> None:
    inv = await _company_invite(db, p, invite_id)
    if _invite_status(inv) not in ("pending", "expired"):
        return
    inv.revoked_at = now()
    m = await db.get(Membership, inv.membership_id)
    if m and m.status == "invited":
        m.status = "removed"
    await audit.record(
        db, "team.invite_revoked", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="invite", target_id=inv.id,
    )  # fmt: skip


# ---- invites (invited person's side) ------------------------------------------------------------
async def my_invites(db: AsyncSession, user: User, include_expired: bool = True) -> list[MyInvite]:
    if not user.phone:
        return []
    inviter = User.__table__.alias("inviter")
    q = (
        select(Invitation, Company, inviter.c.name, inviter.c.phone)
        .join(Company, Company.id == Invitation.company_id)
        .join(inviter, inviter.c.id == Invitation.invited_by)
        .join(Membership, Membership.id == Invitation.membership_id)
        .where(Invitation.phone == user.phone, *_open_invite_filter(), Membership.status == "invited")
        .order_by(Invitation.created_at.desc())
    )
    if not include_expired:
        q = q.where(Invitation.expires_at > now())
    out = []
    for inv, c, by_name, by_phone in (await db.execute(q)).all():
        out.append(
            MyInvite(
                id=inv.id,
                company=InviteCompany(id=c.id, name=c.name, trade=c.industry_slug, country=c.country),
                invited_by=InviterOut(name=by_name or "", phone=by_phone),
                role=inv.role,
                sent_at=inv.created_at,
                expires_at=inv.expires_at,
                status="expired" if inv.expires_at < now() else "pending",
            )
        )
    return out


async def _my_open_invite(db: AsyncSession, user: User, invite_id: uuid.UUID) -> Invitation:
    inv = await db.get(Invitation, invite_id, with_for_update=True)
    if not inv or inv.phone != user.phone:
        raise NotFound("invite_not_found", "Invite not found.")
    status = _invite_status(inv)
    if status == "expired":
        raise Gone("invite_expired", "This invite has expired. Ask for a new one.")
    if status != "pending":
        raise Gone("invite_revoked", "This invite is no longer valid.")
    return inv


async def accept(db: AsyncSession, user: User, session_id: uuid.UUID, invite_id: uuid.UUID):
    inv = await _my_open_invite(db, user, invite_id)
    m = await db.get(Membership, inv.membership_id)
    if not m or m.user_id != user.id or m.status != "invited":
        raise Gone("invite_revoked", "This invite is no longer valid.")
    t = now()
    inv.accepted_at = t
    m.status, m.joined_at = "active", t
    if user.status == "invited":
        user.status = "active"
    if not user.name:
        user.name = inv.name
    sess = await db.get(AuthSession, session_id)
    if sess:
        sess.active_company_id = m.company_id
    await audit.record(
        db, "team.joined", company_id=m.company_id, actor_id=user.id, actor_role=m.role,
        target_type="user", target_id=user.id,
    )  # fmt: skip
    await db.flush()
    return m, await db.get(Company, m.company_id)


async def decline(db: AsyncSession, user: User, invite_id: uuid.UUID) -> None:
    inv = await _my_open_invite(db, user, invite_id)
    inv.declined_at = now()
    m = await db.get(Membership, inv.membership_id)
    if m and m.status == "invited":
        m.status = "removed"
    await audit.record(
        db, "team.invite_declined", company_id=inv.company_id, actor_id=user.id,
        target_type="invite", target_id=inv.id,
    )  # fmt: skip
