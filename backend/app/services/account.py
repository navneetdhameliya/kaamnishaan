"""Deleting an account (D-130).

The person's own details (name, phone, email, password, photo) are wiped at once and they are logged
out everywhere. Their work (jobs, photos, reports) stays with the company, shown as "Deleted user".
An owner whose company has other people must first hand it to one of them; a company where they are
the only member is closed with the account.
"""

import logging
import uuid

from sqlalchemy import delete as sql_delete
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Forbidden, NotFound
from app.core.security import now
from app.models import AuthSession, Company, Device, Invitation, Job, Membership, OtpChallenge, User
from app.providers.storage import get_storage
from app.schemas.account import DeletionCheck, DeletionCompany, OwnerCandidate
from app.services import audit

log = logging.getLogger(__name__)
DELETED_NAME = "Deleted user"
OPEN_JOBS = ("unassigned", "assigned", "in_progress", "changes_requested")


async def check(db: AsyncSession, user: User) -> DeletionCheck:
    mine = (
        await db.execute(
            select(Membership, Company)
            .join(Company, Company.id == Membership.company_id)
            .where(Membership.user_id == user.id, Membership.status == "active")
            .order_by(Company.name)
        )
    ).all()
    out = []
    for m, c in mine:
        others = (
            await db.execute(
                select(User.id, User.name, Membership.role)
                .join(Membership, Membership.user_id == User.id)
                .where(
                    Membership.company_id == c.id,
                    Membership.status == "active",
                    User.id != user.id,
                    User.deleted_at.is_(None),
                )
                .order_by(User.name)
            )
        ).all()
        owner = m.role == "owner"
        other_owner = any(r == "owner" for _, _, r in others)
        out.append(
            DeletionCompany(
                company_id=c.id,
                name=c.name,
                role=m.role,  # type: ignore[arg-type]
                others=len(others),
                closes=owner and not others,
                needs_new_owner=owner and bool(others) and not other_owner,
                candidates=[OwnerCandidate(user_id=i, name=n or "", role=r) for i, n, r in others]  # type: ignore[arg-type]
                if owner and not other_owner
                else [],
            )
        )
    return DeletionCheck(
        can_delete=not any(c.needs_new_owner for c in out),
        companies=out,
        open_jobs=await open_jobs(db, user.id),
    )


async def change_owner(db: AsyncSession, p: Principal, user_id: uuid.UUID) -> None:
    if p.role != "owner" or not p.company:
        raise Forbidden("forbidden", "Only the owner can hand over the company.")
    if user_id == p.user.id:
        raise AppError("validation_error", "Pick someone else.", fields={"user_id": "self"})
    target = await db.scalar(
        select(Membership).where(
            Membership.company_id == p.company.id,
            Membership.user_id == user_id,
            Membership.status == "active",
        )
    )
    if not target:
        raise NotFound("member_not_found", "This person isn't in your team.")
    before = target.role
    target.role = "owner"
    p.membership.role = "manager"  # type: ignore[union-attr]
    await audit.record(
        db,
        "team.owner_changed",
        company_id=p.company.id,
        actor_id=p.user.id,
        actor_role="owner",
        target_type="user",
        target_id=user_id,
        data={"role": [before, "owner"]},
    )
    await db.flush()


async def delete(db: AsyncSession, user: User, reason: str | None) -> None:
    c = await check(db, user)
    if not c.can_delete:
        blocked = [x.name for x in c.companies if x.needs_new_owner]
        raise AppError(
            "owner_has_team",
            "Choose a new owner for your company first.",
            {"companies": blocked},
            status=409,
        )
    t = now()
    for x in c.companies:
        if x.closes:
            company = await db.get(Company, x.company_id)
            if company and company.status != "cancelled":
                company.status = "cancelled"
                await audit.record(
                    db,
                    "company.closed_by_owner",
                    company_id=company.id,
                    actor_id=user.id,
                    actor_role="owner",
                    target_type="company",
                    target_id=company.id,
                    data={"reason": reason},
                )
        else:
            await audit.record(
                db,
                "team.left",
                company_id=x.company_id,
                actor_id=user.id,
                actor_role=x.role,
                target_type="user",
                target_id=user.id,
                data={"account_deleted": True},
            )

    # open jobs go back to the office to give to someone else
    await db.execute(
        update(Job)
        .where(Job.assigned_to == user.id, Job.status.in_(("assigned", "unassigned")))
        .values(assigned_to=None, status="unassigned")
    )
    await db.execute(
        update(Job).where(Job.assigned_to == user.id, Job.status.in_(OPEN_JOBS)).values(assigned_to=None)
    )
    memberships = select(Membership.id).where(Membership.user_id == user.id)
    await db.execute(
        update(Invitation)
        .where(
            Invitation.membership_id.in_(memberships),
            Invitation.accepted_at.is_(None),
            Invitation.revoked_at.is_(None),
        )
        .values(revoked_at=t)
    )
    await db.execute(update(Membership).where(Membership.user_id == user.id).values(status="removed"))
    await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=t)
    )
    await db.execute(sql_delete(Device).where(Device.user_id == user.id))
    if user.phone:
        await db.execute(sql_delete(OtpChallenge).where(OtpChallenge.phone == user.phone))
    if user.avatar_key:
        try:
            await get_storage().delete(user.avatar_key)
        except Exception:  # noqa: BLE001 - the photo is unlinked either way
            log.warning("could not delete avatar %s", user.avatar_key)

    user.name, user.phone, user.email, user.email_verified_at = DELETED_NAME, None, None, None
    user.password_hash, user.avatar_key, user.trade = None, None, None
    user.status, user.deleted_at = "disabled", t
    await audit.record(
        db,
        "account.deleted",
        actor_id=user.id,
        target_type="user",
        target_id=user.id,
        data={"reason": reason, "companies": len(c.companies)},
    )
    await db.flush()


async def open_jobs(db: AsyncSession, user_id: uuid.UUID) -> int:
    return int(
        await db.scalar(select(func.count()).where(Job.assigned_to == user_id, Job.status.in_(OPEN_JOBS)))
        or 0
    )
