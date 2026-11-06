"""Invite people by phone, resend, change role or remove, and accept an invitation."""

import uuid
from datetime import timedelta

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, Gone, NotFound, PlanLimit, RateLimited
from app.core.security import digest, normalize_phone, now, random_token
from app.models import AuthSession, Company, Invitation, Membership, Plan, User
from app.providers.messaging import send_sms
from app.schemas.identity import (
    InvitationCreate,
    InvitationPreview,
    MemberOut,
    MemberPatch,
    PendingInvitation,
    PersonRef,
)
from app.services import audit

INVITE_TTL = timedelta(days=7)
RESEND_AFTER = timedelta(seconds=60)


def member_out(m: Membership, u: User, invited_name: str | None = None) -> MemberOut:
    return MemberOut(id=m.id, name=u.name or invited_name or "", phone=u.phone, role=m.role, status=m.status)


async def list_members(db: AsyncSession, company_id: uuid.UUID, role: str | None) -> list[MemberOut]:
    pending_name = (
        select(Invitation.name)
        .where(Invitation.membership_id == Membership.id, Invitation.accepted_at.is_(None))
        .order_by(Invitation.created_at.desc())
        .limit(1)
        .scalar_subquery()
    )
    q = (
        select(Membership, User, pending_name)
        .join(User, User.id == Membership.user_id)
        .where(Membership.company_id == company_id, Membership.status != "removed")
        .order_by(Membership.role, func.coalesce(User.name, pending_name))
    )
    if role:
        q = q.where(Membership.role == role)
    return [member_out(m, u, n) for m, u, n in (await db.execute(q)).all()]


async def _check_technician_limit(db: AsyncSession, company: Company) -> None:
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
            "technician_limit",
            "Your plan has no free technician seats. Upgrade to add more.",
            {"limit": plan.technician_limit, "used": used, "plan": plan.code},
        )


async def _issue(db: AsyncSession, p: Principal, m: Membership, phone: str, name: str) -> Invitation:
    token = random_token(24)
    inv = Invitation(
        company_id=m.company_id,
        membership_id=m.id,
        phone=phone,
        name=name,
        role=m.role,
        token_hash=digest(token),
        expires_at=now() + INVITE_TTL,
        invited_by=p.user.id,
    )
    db.add(inv)
    await db.flush()
    link = f"{get_settings().web_url}/join/{token}"
    await send_sms(phone, "invite", inviter=p.user.name or "Your team", company=p.company.name, link=link)
    return inv


async def invite(db: AsyncSession, p: Principal, body: InvitationCreate, ip: str | None) -> MemberOut:
    p.require("team.invite_manager" if body.role == "manager" else "team.invite_technician")
    phone = normalize_phone(body.phone, p.company.country or get_settings().default_country)
    if body.role == "technician":
        await _check_technician_limit(db, p.company)

    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    if not user:
        user = User(phone=phone, status="invited")
        db.add(user)
        await db.flush()
    m = (
        await db.execute(
            select(Membership).where(Membership.company_id == p.company.id, Membership.user_id == user.id)
        )
    ).scalar_one_or_none()
    if m and m.status == "active":
        raise Conflict("already_member", "This person is already on your team.")
    if m and m.status == "invited":
        raise Conflict("already_invited", "This person is already invited. Use resend instead.")
    if m:  # was removed before: invite again
        m.role, m.status, m.invited_by, m.joined_at = body.role, "invited", p.user.id, None
    else:
        m = Membership(company_id=p.company.id, user_id=user.id, role=body.role, status="invited", invited_by=p.user.id)
        db.add(m)
    await db.flush()
    await _issue(db, p, m, phone, body.name)
    await audit.record(
        db, "team.invited", company_id=p.company.id, actor_id=p.user.id, actor_role=p.role,
        target_type="membership", target_id=m.id, data={"role": body.role}, ip=ip,
    )  # fmt: skip
    return member_out(m, user, body.name)


async def resend(db: AsyncSession, p: Principal, id_: uuid.UUID) -> None:
    """`id_` may be the invitation id or the member id shown in the team list."""
    inv = (
        await db.execute(
            select(Invitation)
            .where(
                Invitation.company_id == p.company.id,
                or_(Invitation.id == id_, Invitation.membership_id == id_),
                Invitation.accepted_at.is_(None),
                Invitation.revoked_at.is_(None),
            )
            .order_by(Invitation.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if not inv:
        raise NotFound("invitation_not_found", "No open invitation found.")
    p.require("team.invite_manager" if inv.role == "manager" else "team.invite_technician")
    if now() - inv.created_at < RESEND_AFTER:
        raise RateLimited("resend_too_soon", "Please wait a minute before sending again.")
    m = await db.get(Membership, inv.membership_id)
    inv.revoked_at = now()  # the old link stops working
    await _issue(db, p, m, inv.phone, inv.name)


async def patch_member(db: AsyncSession, p: Principal, member_id: uuid.UUID, body: MemberPatch) -> MemberOut:
    p.require("team.manage")
    row = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(Membership.id == member_id, Membership.company_id == p.company.id)
        )
    ).first()
    if not row:
        raise NotFound("member_not_found", "Team member not found.")
    m, u = row
    if m.user_id == p.user.id:
        raise Forbidden("cannot_change_self", "You can't change your own role or remove yourself.")
    if m.role == "owner":
        raise Forbidden("cannot_change_owner", "The owner can't be changed here.")
    if body.role == "owner":
        raise Forbidden("cannot_make_owner", "Ownership transfer is not available yet.")
    if p.role != "owner" and (m.role == "manager" or body.role == "manager"):
        raise Forbidden("owner_only", "Only the owner can manage managers.")
    if body.role and body.role != m.role:
        if body.role == "technician" and m.status != "removed":
            await _check_technician_limit(db, p.company)
        m.role = body.role
        await db.execute(
            update(Invitation)
            .where(Invitation.membership_id == m.id, Invitation.accepted_at.is_(None))
            .values(role=body.role)
        )
    if body.status == "removed" and m.status != "removed":
        m.status = "removed"
        await db.execute(
            update(Invitation)
            .where(Invitation.membership_id == m.id, Invitation.accepted_at.is_(None), Invitation.revoked_at.is_(None))
            .values(revoked_at=now())
        )
        await db.execute(
            update(AuthSession)
            .where(AuthSession.user_id == m.user_id, AuthSession.active_company_id == p.company.id)
            .values(active_company_id=None)
        )
    elif body.status == "active" and m.status == "removed":
        raise AppError("invite_again", "Invite this person again to bring them back.")
    await audit.record(
        db, "team.member_changed", company_id=p.company.id, actor_id=p.user.id, actor_role=p.role,
        target_type="membership", target_id=m.id, data=body.model_dump(exclude_none=True),
    )  # fmt: skip
    await db.flush()
    return member_out(m, u)


# ---- the invited person's side ------------------------------------------------------------
async def _open_invitation(db: AsyncSession, **where) -> tuple[Invitation, Company, User]:
    q = (
        select(Invitation, Company, User)
        .join(Company, Company.id == Invitation.company_id)
        .join(User, User.id == Invitation.invited_by)
    )
    for k, v in where.items():
        q = q.where(getattr(Invitation, k) == v)
    row = (await db.execute(q)).first()
    if not row:
        raise Gone("invitation_invalid", "This invitation is not valid.")
    inv, c, by = row
    if inv.accepted_at:
        raise Gone("invitation_used", "This invitation was already accepted.")
    if inv.revoked_at:
        raise Gone("invitation_revoked", "This invitation was cancelled. Ask for a new one.")
    if inv.expires_at < now():
        raise Gone("invitation_expired", "This invitation has expired. Ask for a new one.")
    return inv, c, by


def _preview(inv: Invitation, c: Company, by: User) -> InvitationPreview:
    return InvitationPreview(
        company_name=c.name, invited_by=PersonRef(id=by.id, name=by.name or ""), role=inv.role
    )


async def preview(db: AsyncSession, token: str) -> InvitationPreview:
    return _preview(*await _open_invitation(db, token_hash=digest(token)))


async def pending_for(db: AsyncSession, user: User) -> list[PendingInvitation]:
    if not user.phone:
        return []
    rows = await db.execute(
        select(Invitation, Company, User)
        .join(Company, Company.id == Invitation.company_id)
        .join(User, User.id == Invitation.invited_by)
        .join(Membership, Membership.id == Invitation.membership_id)
        .where(
            Invitation.phone == user.phone,
            Invitation.accepted_at.is_(None),
            Invitation.revoked_at.is_(None),
            Invitation.expires_at > now(),
            Membership.status == "invited",
        )
        .order_by(Invitation.created_at.desc())
    )
    return [PendingInvitation(id=inv.id, **_preview(inv, c, by).model_dump()) for inv, c, by in rows.all()]


async def accept(db: AsyncSession, user: User, session_id: uuid.UUID, *, token: str | None = None,
                 invitation_id: uuid.UUID | None = None) -> tuple[Membership, Company]:  # fmt: skip
    if token is not None:
        inv, c, _ = await _open_invitation(db, token_hash=digest(token))
    else:
        inv, c, _ = await _open_invitation(db, id=invitation_id)
    if inv.phone != user.phone:
        raise Forbidden("invitation_wrong_phone", "This invitation is for a different phone number.")
    m = await db.get(Membership, inv.membership_id)
    if not m or m.status != "invited" or m.user_id != user.id:
        raise Gone("invitation_invalid", "This invitation is not valid.")
    t = now()
    inv.accepted_at = t
    m.status, m.joined_at = "active", t
    if user.status == "invited":
        user.status = "active"
    if not user.name:
        user.name = inv.name
    sess = await db.get(AuthSession, session_id)
    if sess:
        sess.active_company_id = c.id
    await audit.record(
        db, "team.joined", company_id=c.id, actor_id=user.id, actor_role=m.role,
        target_type="membership", target_id=m.id,
    )  # fmt: skip
    await db.flush()
    return m, c
