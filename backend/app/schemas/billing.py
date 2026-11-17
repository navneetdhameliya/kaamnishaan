"""M41 Plan and billing, and Follow-up credits."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.identity import CreditPackOut, CreditRules, PlanOut


class UsageTile(BaseModel):
    key: Literal["technicians", "reports", "ai_questions", "credits"]
    used: int
    limit: int | None = Field(description="null = no limit")


class BillingOut(BaseModel):
    plan: PlanOut
    status: str = Field(description="trial, active, past_due, suspended, cancelled")
    trial_ends_at: datetime | None
    period_start: datetime
    renews_at: datetime = Field(description="When this month's limits and credits start again")
    company: str
    usage: list[UsageTile]
    upgrade: PlanOut | None = Field(description="The next plan up, if any")
    payments_ready: bool = Field(description="false until online payment is switched on")


class CreditUse(BaseModel):
    kind: Literal["reminders", "ai_calls", "emails"]
    credits: int
    count: int


class CreditsOut(BaseModel):
    balance: int | None = Field(description="Credits left (this month's + top-ups); null = no limit")
    plan_credits: int | None
    plan_used: int
    topup_credits: int
    plan: str
    renews_at: datetime
    uses: list[CreditUse]
    packs: list[CreditPackOut]
    rules: CreditRules
    payments_ready: bool
