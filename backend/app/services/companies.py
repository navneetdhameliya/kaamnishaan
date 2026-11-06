"""Create a company (owner + 14-day Professional trial) and change its details."""

from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import now
from app.models import AuthSession, Company, Industry, Membership, User
from app.schemas.identity import CompanyCreate, CompanySettings, CompanyUpdate
from app.services import audit

CURRENCY_BY_COUNTRY = {"IN": "INR"}


async def _check_industry(db: AsyncSession, slug: str) -> None:
    if not await db.get(Industry, slug):
        raise AppError("unknown_industry", "Pick an industry from the list.", {"field": "industry"})


async def create_company(
    db: AsyncSession, user: User, session_id, body: CompanyCreate, ip: str | None
) -> tuple[Company, Membership]:
    await _check_industry(db, body.industry)
    t = now()
    company = Company(
        name=body.name,
        industry_slug=body.industry,
        country=body.country,
        timezone=body.timezone,
        currency=CURRENCY_BY_COUNTRY.get(body.country, "USD"),
        report_language="en",
        plan_code="professional",
        status="trial",
        trial_ends_at=t + timedelta(days=get_settings().trial_days),
        settings=CompanySettings().model_dump(),
        created_by=user.id,
    )
    db.add(company)
    await db.flush()
    membership = Membership(company_id=company.id, user_id=user.id, role="owner", status="active", joined_at=t)
    db.add(membership)
    # the new company becomes the one this session works in
    sess = await db.get(AuthSession, session_id)
    if sess:
        sess.active_company_id = company.id
    await audit.record(
        db, "company.created", company_id=company.id, actor_id=user.id, actor_role="owner",
        target_type="company", target_id=company.id, data={"name": company.name}, ip=ip,
    )  # fmt: skip
    await db.flush()
    return company, membership


async def update_company(db: AsyncSession, company: Company, body: CompanyUpdate, actor: User, role: str) -> Company:
    changed: dict = {}
    if body.name is not None:
        company.name = changed["name"] = body.name
    if body.industry is not None:
        await _check_industry(db, body.industry)
        company.industry_slug = changed["industry"] = body.industry
    if body.report_language is not None:
        company.report_language = changed["report_language"] = body.report_language
    if body.settings is not None:
        allowed = CompanySettings.model_fields
        unknown = set(body.settings) - set(allowed)
        if unknown:
            raise AppError("unknown_setting", "Some settings are not known.", {"fields": sorted(unknown)})
        for k, v in body.settings.items():
            if not isinstance(v, bool):
                raise AppError("invalid_setting", "Settings must be on or off.", {"field": k})
        company.settings = {**(company.settings or {}), **body.settings}
        changed["settings"] = body.settings
    if changed:
        await audit.record(
            db, "company.updated", company_id=company.id, actor_id=actor.id, actor_role=role,
            target_type="company", target_id=company.id, data=changed,
        )  # fmt: skip
    await db.flush()
    return company
