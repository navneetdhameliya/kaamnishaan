"""No-login endpoints the apps and website call first: /config and /plans."""

from typing import Literal

from fastapi import APIRouter, Depends, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_db
from app.models import ChecklistTemplate, CreditPack, Industry, Plan
from app.providers.ai import get_ai
from app.schemas.identity import (
    AppLinks,
    ConfigOut,
    CountryOut,
    CreditPackOut,
    CreditRules,
    LanguageOut,
    Money,
    PlansOut,
    TradeOut,
)
from app.services.auth import PASSWORD_MIN
from app.services.credits import plan_out

router = APIRouter(tags=["config"])
Locale = Literal["en", "hi", "gu", "es", "fr"]

LANGUAGES = [("en", "English"), ("hi", "हिन्दी"), ("gu", "ગુજરાતી"), ("es", "Español"), ("fr", "Français")]
# India first; the rest match the website's country list. Admin-editable later (A35).
COUNTRIES = [
    ("IN", "India", "+91", "🇮🇳"), ("US", "United States", "+1", "🇺🇸"), ("GB", "United Kingdom", "+44", "🇬🇧"),
    ("AE", "United Arab Emirates", "+971", "🇦🇪"), ("CA", "Canada", "+1", "🇨🇦"),
    ("AU", "Australia", "+61", "🇦🇺"),
    ("ES", "Spain", "+34", "🇪🇸"), ("FR", "France", "+33", "🇫🇷"), ("MX", "Mexico", "+52", "🇲🇽"),
]  # fmt: skip


def _t(names: dict, locale: str) -> str:
    return names.get(locale) or names.get("en") or next(iter(names.values()), "")


@router.get("/config", response_model=ConfigOut)
async def config(response: Response, locale: Locale = "en", db: AsyncSession = Depends(get_db)) -> ConfigOut:
    trades = (
        await db.execute(select(Industry).where(Industry.status == "live").order_by(Industry.sort))
    ).scalars()
    ready = dict(
        (
            await db.execute(
                select(ChecklistTemplate.trade, func.count())
                .where(ChecklistTemplate.company_id.is_(None), ChecklistTemplate.status == "published")
                .group_by(ChecklistTemplate.trade)
            )
        ).all()
    )
    response.headers["Cache-Control"] = "public, max-age=300"
    s = get_settings()
    return ConfigOut(
        languages=[LanguageOut(code=c, native_name=n) for c, n in LANGUAGES],
        countries=[CountryOut(code=c, name=n, dial_code=d, flag=f) for c, n, d, f in COUNTRIES],
        trades=[
            TradeOut(key=i.slug, name=_t(i.name, locale), checklists=ready.get(i.slug, 0)) for i in trades
        ],
        default_country=s.default_country,
        password_min_length=PASSWORD_MIN,
        min_app_version="1.0.0",
        maintenance=False,
        features={
            "signups": True,
            "ai_drafting": True,
            "ai_assistant": get_ai() is not None,
            "email": get_settings().email_enabled,
        },
        app_links=AppLinks(android=s.android_app_url, ios=s.ios_app_url),
    )


@router.get("/plans", response_model=PlansOut)
async def plans(
    response: Response,
    currency: Literal["INR", "USD"] = "INR",
    locale: Locale = "en",
    db: AsyncSession = Depends(get_db),
) -> PlansOut:
    rows = (await db.execute(select(Plan).where(Plan.is_public.is_(True)).order_by(Plan.sort))).scalars()
    packs = (
        await db.execute(select(CreditPack).where(CreditPack.active.is_(True)).order_by(CreditPack.sort))
    ).scalars()
    response.headers["Cache-Control"] = "public, max-age=300"
    return PlansOut(
        currency=currency,
        plans=[plan_out(p, currency, locale) for p in rows],
        credit_packs=[
            CreditPackOut(
                id=c.id, credits=c.credits, price=Money(amount=c.prices[currency], currency=currency)
            )
            for c in packs
            if currency in c.prices
        ],
        credit_rules=CreditRules(),
        trial_days=get_settings().trial_days,
    )
