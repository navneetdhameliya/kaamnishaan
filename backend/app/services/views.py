"""Turn database rows into API shapes (one place, so every endpoint answers the same way)."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import permissions_for
from app.models import Company, Membership, User
from app.schemas.identity import CompanyChoice, CompanyOut, CompanySettings, MeOut


def company_out(c: Company) -> CompanyOut:
    s = c.settings or {}
    return CompanyOut(
        id=c.id,
        name=c.name,
        industry=c.industry_slug,
        country=c.country,
        timezone=c.timezone,
        report_language=c.report_language,
        status=c.status,
        trial_ends_at=c.trial_ends_at,
        settings=CompanySettings(**{k: v for k, v in s.items() if k in CompanySettings.model_fields}),
    )


def me_out(user: User, company: Company | None = None, membership: Membership | None = None) -> MeOut:
    role = membership.role if membership else None
    return MeOut(
        id=user.id,
        name=user.name or "",
        phone=user.phone,
        email=user.email,
        app_language=user.app_language,
        role=role,
        company=company_out(company) if company else None,
        permissions=sorted(permissions_for(role, company.settings if company else None)),
    )


async def active_memberships(db: AsyncSession, user_id: uuid.UUID) -> list[tuple[Membership, Company]]:
    rows = await db.execute(
        select(Membership, Company)
        .join(Company, Company.id == Membership.company_id)
        .where(Membership.user_id == user_id, Membership.status == "active")
        .order_by(Company.name)
    )
    return [(m, c) for m, c in rows.all()]


def choices(rows: list[tuple[Membership, Company]], active_id: uuid.UUID | None) -> list[CompanyChoice]:
    return [CompanyChoice(company_id=c.id, name=c.name, role=m.role, active=c.id == active_id) for m, c in rows]
