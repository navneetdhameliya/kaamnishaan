"""Admin panel: A16 Subscriptions, A17 Plans and pricing, A18 Payments."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.admin_companies import CompanyBadge, CompanyStatus
from app.schemas.staff import AdminMoney

CURRENCIES = ("INR", "USD")


# ---- A16 Subscriptions -----------------------------------------------------------------------------
class AdminSubRow(BaseModel):
    id: uuid.UUID
    name: str
    plan_code: str
    plan: str
    price: AdminMoney | None = Field(description="Monthly price in the company's currency; None = custom")
    status: CompanyStatus
    badge: CompanyBadge
    trial_days_left: int | None
    renews_at: datetime | None = Field(description="Trial end, or when the next month starts")
    seats: int
    seat_limit: int | None


class AdminSubKpis(BaseModel):
    mrr: list[AdminMoney] = Field(description="Plan price of every active company, per currency")
    paying: int = Field(description="Active companies on a paid plan")
    on_free: int = Field(description="Active companies on a free plan")
    trials: int
    trials_ending_7d: int
    past_due: int
    cancelled_30d: int


class AdminSubList(BaseModel):
    kpis: AdminSubKpis
    items: list[AdminSubRow]
    total: int
    page: int
    page_size: int


# ---- A17 Plans and pricing --------------------------------------------------------------------------
class AdminPlan(BaseModel):
    code: str
    name: dict[str, str] = Field(description="Per language")
    prices: dict[str, int] = Field(description="Monthly price in minor units per currency; empty = custom")
    technician_limit: int | None
    report_limit_monthly: int | None
    monthly_credits: int | None
    ai_questions_monthly: int | None
    most_popular: bool
    is_public: bool = Field(description="Shown on the website and at sign-up")
    features: list[str]
    support: str | None
    companies: int = Field(description="Companies on this plan (not cancelled)")
    trials: int


class AdminPack(BaseModel):
    id: uuid.UUID
    credits: int
    prices: dict[str, int]
    active: bool


class AdminTrial(BaseModel):
    model_config = ConfigDict(extra="forbid")
    plan_code: str
    days: int = Field(ge=3, le=60)


class AdminPlansOut(BaseModel):
    plans: list[AdminPlan]
    packs: list[AdminPack]
    trial: AdminTrial
    currencies: list[str]
    can_act: bool
    pricing_url: str = Field(description="The website pricing page")


class AdminPlanIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: dict[Literal["en", "hi", "gu", "es", "fr"], str]
    prices: dict[str, int] = Field(description="Empty = custom price (talk to us)")
    technician_limit: int | None = Field(None, ge=1, le=100_000)
    report_limit_monthly: int | None = Field(None, ge=1, le=1_000_000)
    monthly_credits: int | None = Field(None, ge=0, le=1_000_000)
    ai_questions_monthly: int | None = Field(None, ge=0, le=1_000_000)
    most_popular: bool
    is_public: bool

    @field_validator("name")
    @classmethod
    def _names(cls, v: dict) -> dict:
        if not (v.get("en") or "").strip():
            raise ValueError("An English name is needed")
        if any(len(x) > 40 for x in v.values()):
            raise ValueError("Names are 40 characters at most")
        return {k: x.strip() for k, x in v.items() if x and x.strip()}

    @field_validator("prices")
    @classmethod
    def _prices(cls, v: dict) -> dict:
        if set(v) - set(CURRENCIES):
            raise ValueError("Prices are in INR and USD")
        if any(x < 0 or x > 100_000_000 for x in v.values()):
            raise ValueError("Price out of range")
        if v and set(v) != set(CURRENCIES):
            raise ValueError("Give a price in every currency, or none for a custom price")
        return v


class AdminPackIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    prices: dict[str, int]
    active: bool

    @field_validator("prices")
    @classmethod
    def _prices(cls, v: dict) -> dict:
        if set(v) != set(CURRENCIES) or any(x <= 0 or x > 100_000_000 for x in v.values()):
            raise ValueError("Give a price above 0 in INR and USD")
        return v


# ---- A18 Payments -----------------------------------------------------------------------------------
class AdminPaymentsOut(BaseModel):
    connected: bool = Field(description="False until online payments are set up (testing phase)")
    provider: str | None = Field(description="The planned provider")
    items: list[dict] = Field(default_factory=list)
