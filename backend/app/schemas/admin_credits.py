"""Admin panel: A40 Usage and credits."""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import Money


class AdminCreditKpis(BaseModel):
    used_30d: int = Field(description="Credits used by every company in the last 30 days")
    included_30d: int = Field(description="Monthly credits given in the last 30 days")
    topup_credits_30d: int = Field(description="Credits added by top-ups and staff in the last 30 days")
    topups_30d: int
    sms_30d: int
    whatsapp_30d: int
    calls_30d: int
    out_of_credits: int = Field(description="Companies that can't send reminders now")
    paused_requests: int = Field(description="Reminders waiting for credits")


class AdminCreditRules(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sms: int = Field(ge=1, le=20)
    whatsapp: int = Field(ge=1, le=20)
    ai_call: int = Field(ge=1, le=100)


class AdminPlanCredits(BaseModel):
    code: str
    name: str
    monthly_credits: int | None = Field(description="None = no limit (custom plans)")
    companies: int


class AdminCreditPack(BaseModel):
    credits: int
    prices: list[Money]


class AdminCreditRow(BaseModel):
    company_id: uuid.UUID
    company: str
    plan: str
    included: int | None = Field(description="This month's plan credits; None = no limit")
    used: int = Field(description="Plan credits used this month")
    topup_left: int
    topups: int = Field(description="Top-ups and staff additions, all time")
    status: Literal["unlimited", "ok", "low", "out"]


class AdminCreditsOut(BaseModel):
    kpis: AdminCreditKpis
    rules: AdminCreditRules
    plans: list[AdminPlanCredits]
    packs: list[AdminCreditPack]
    items: list[AdminCreditRow]
    total: int
    page: int
    page_size: int
    can_act: bool


class AdminCreditRulesIn(AdminCreditRules):
    plans: dict[str, int | None] = Field(
        default_factory=dict, description="Monthly credits per plan code; None = no limit"
    )


class AdminCreditAdjust(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    credits: int = Field(ge=-100_000, le=100_000, description="Add (+) or take back (−) top-up credits")
    reason: str = Field(min_length=3, max_length=300)
