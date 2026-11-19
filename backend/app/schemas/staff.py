"""Admin panel: staff log in (A01), setup (first time or after a reset) and the dashboard (A03)."""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

from app.schemas.identity import _In

StaffRole = Literal["super_admin", "admin", "support"]


class StaffLoginIn(_In):
    email: EmailStr
    password: str = Field(max_length=256)
    code: str | None = Field(default=None, max_length=12, description="6 digits from the authenticator app")
    recovery_code: str | None = Field(
        default=None, max_length=16, description="Instead of code: e.g. 7f3a-91c0"
    )


class StaffRefreshIn(_In):
    refresh_token: str = Field(max_length=200)


class StaffOut(BaseModel):
    id: uuid.UUID
    name: str
    email: str
    role: StaffRole
    recovery_codes_left: int


class StaffSessionOut(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int = Field(description="Seconds the access token works")
    session_ends_at: datetime = Field(description="Log in again after this, even when active")
    staff: StaffOut


class StaffSetupInfo(BaseModel):
    email: str
    name: str
    is_reset: bool = Field(description="True when this account was set up before (new password and phone)")
    secret: str = Field(description="For typing into the authenticator by hand")
    otpauth_uri: str = Field(description="Show as a QR code")


class StaffSetupIn(_In):
    token: str = Field(max_length=1000)
    password: str = Field(max_length=256)
    code: str = Field(max_length=12)


class StaffSetupOut(StaffSessionOut):
    recovery_codes: list[str] = Field(description="Shown once. Each works one time instead of a code.")


# ---- A03 dashboard ----------------------------------------------------------------------------------
class Stat(BaseModel):
    value: float
    previous: float = Field(description="Same length of time just before")


class Money(BaseModel):
    currency: str
    amount_minor: int


class DayCount(BaseModel):
    day: date
    approved: int
    ai_drafts: int


class PlanMixRow(BaseModel):
    code: str
    name: str
    prices: dict[str, int]
    companies: int


class TopCompany(BaseModel):
    id: uuid.UUID
    name: str
    trade: str | None
    plan: str
    reports: int


class AttentionRow(BaseModel):
    kind: Literal["near_limit", "past_due", "trial_ending", "new_leads"]
    count: int
    example: str | None = Field(default=None, description="One company or lead to name")
    used: int | None = None
    limit: int | None = None


class ActivityRow(BaseModel):
    kind: Literal["company_created", "lead_demo", "lead_contact", "lead_newsletter", "staff_joined"]
    title: str = Field(description="Company, person or ticket the event is about")
    at: datetime


class DashboardOut(BaseModel):
    days: int
    since: datetime
    active_companies: Stat
    technicians: Stat
    reports_sent: Stat
    ai_cost_usd: Stat
    ai_cost_per_report_usd: float | None
    monthly_revenue: list[Money] = Field(
        description="From the plans of paying companies (status active); no payments are taken yet"
    )
    reports_per_day: list[DayCount]
    plan_mix: list[PlanMixRow]
    top_companies: list[TopCompany]
    attention: list[AttentionRow]
    activity: list[ActivityRow]
