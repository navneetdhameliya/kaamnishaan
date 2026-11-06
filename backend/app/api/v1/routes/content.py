"""Public catalog for the website and apps: plans with prices, industries. No sign-in needed."""

from typing import Literal

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_db
from app.models import CreditPack, Industry, Plan
from app.schemas.identity import (
    CreditPackOut,
    CreditRules,
    IndustryList,
    IndustryOut,
    Money,
    PlanPublic,
    PublicPlans,
)

router = APIRouter(prefix="/content", tags=["content"])
Locale = Literal["en", "hi", "gu", "es", "fr"]


def _t(names: dict, locale: str) -> str:
    return names.get(locale) or names.get("en") or next(iter(names.values()), "")


@router.get("/plans", response_model=PublicPlans)
async def plans(
    response: Response,
    currency: Literal["INR", "USD"] = "INR",
    locale: Locale = "en",
    db: AsyncSession = Depends(get_db),
) -> PublicPlans:
    rows = (await db.execute(select(Plan).where(Plan.is_public.is_(True)).order_by(Plan.sort))).scalars()
    packs = (
        await db.execute(select(CreditPack).where(CreditPack.active.is_(True)).order_by(CreditPack.sort))
    ).scalars()
    response.headers["Cache-Control"] = "public, max-age=300"
    return PublicPlans(
        plans=[
            PlanPublic(
                code=p.code,
                name=_t(p.name, locale),
                price=Money(amount_minor=p.prices[currency], currency=currency)
                if currency in p.prices
                else None,
                technician_limit=p.technician_limit,
                report_limit_monthly=p.report_limit_monthly,
                monthly_credits=p.monthly_credits,
                most_popular=p.most_popular,
                features=sorted(k for k, v in (p.features or {}).items() if v),
            )
            for p in rows
        ],
        credit_packs=[
            CreditPackOut(
                id=c.id, credits=c.credits, price=Money(amount_minor=c.prices[currency], currency=currency)
            )
            for c in packs
            if currency in c.prices
        ],
        credit_rules=CreditRules(),
        trial_days=get_settings().trial_days,
    )


@router.get("/industries", response_model=IndustryList)
async def industries(
    response: Response, locale: Locale = "en", db: AsyncSession = Depends(get_db)
) -> IndustryList:
    rows = (
        await db.execute(select(Industry).where(Industry.status == "live").order_by(Industry.sort))
    ).scalars()
    response.headers["Cache-Control"] = "public, max-age=300"
    return IndustryList(items=[IndustryOut(slug=i.slug, name=_t(i.name, locale)) for i in rows])
