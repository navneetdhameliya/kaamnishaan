"""Create a company (owner + 14-day Professional trial, no card) and change its details or settings."""

from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import now
from app.models import AuthSession, Company, Industry, Membership, User
from app.schemas.identity import CompanyCreate, CompanySettings, CompanySettingsUpdate, CompanyUpdate
from app.services import audit
from app.services.evidence import take_upload_for

CURRENCY_BY_COUNTRY = {"IN": "INR"}


async def check_trade(db: AsyncSession, slug: str) -> None:
    ind = await db.get(Industry, slug)
    if not ind or ind.status != "live":
        raise AppError("validation_error", "Pick a trade from the list.", fields={"trade": "unknown"})


async def create_company(
    db: AsyncSession, user: User, session_id, body: CompanyCreate, ip: str | None
) -> tuple[Company, Membership]:
    await check_trade(db, body.trade)
    t = now()
    company = Company(
        name=body.name,
        industry_slug=body.trade,
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
    membership = Membership(
        company_id=company.id, user_id=user.id, role="owner", status="active", joined_at=t
    )
    db.add(membership)
    sess = await db.get(AuthSession, session_id)
    if sess:  # the new company becomes the one this session works in
        sess.active_company_id = company.id
    await audit.record(
        db, "company.created", company_id=company.id, actor_id=user.id, actor_role="owner",
        target_type="company", target_id=company.id, data={"name": company.name}, ip=ip,
    )  # fmt: skip
    await db.flush()
    return company, membership


async def update_company(
    db: AsyncSession, company: Company, body: CompanyUpdate, actor: User, role: str
) -> Company:
    before, after = {}, {}
    for field, col in (("name", "name"), ("trade", "industry_slug"), ("timezone", "timezone")):
        value = getattr(body, field)
        if value is None or value == getattr(company, col):
            continue
        if field == "trade":
            await check_trade(db, value)
        before[field], after[field] = getattr(company, col), value
        setattr(company, col, value)
    if body.logo_upload_id is not None:
        up, _ = await take_upload_for(db, actor.id, body.logo_upload_id, "logo")
        before["logo"], after["logo"] = bool(company.logo_key), True
        company.logo_key = up.key
    if after:
        await audit.record(
            db, "company.updated", company_id=company.id, actor_id=actor.id, actor_role=role,
            target_type="company", target_id=company.id, data={"before": before, "after": after},
        )  # fmt: skip
    await db.flush()
    return company


async def update_settings(
    db: AsyncSession, company: Company, body: CompanySettingsUpdate, actor: User, role: str
) -> Company:
    changes = body.model_dump(exclude_none=True)
    before = {}
    if "report_language" in changes:
        before["report_language"] = company.report_language
        company.report_language = changes.pop("report_language")
    if changes:
        current = company.settings or {}
        before.update({k: current.get(k) for k in changes})
        company.settings = {**current, **changes}
    if before:
        await audit.record(
            db, "company.settings_changed", company_id=company.id, actor_id=actor.id, actor_role=role,
            target_type="company", target_id=company.id,
            data={"before": before, "after": body.model_dump(exclude_none=True)},
        )  # fmt: skip
    await db.flush()
    return company
