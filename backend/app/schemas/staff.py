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
    lang: Literal["en", "hi", "gu", "es", "fr"] = Field("en", description="Admin panel language (A36)")


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
class AdminStat(BaseModel):
    value: float
    previous: float = Field(description="Same length of time just before")


class AdminMoney(BaseModel):
    currency: str
    amount_minor: int


class AdminDayCount(BaseModel):
    day: date
    approved: int
    ai_drafts: int


class AdminPlanMixRow(BaseModel):
    code: str
    name: str
    prices: dict[str, int]
    companies: int


class AdminTopCompany(BaseModel):
    id: uuid.UUID
    name: str
    trade: str | None
    plan: str
    reports: int


class AdminAttentionRow(BaseModel):
    kind: Literal["near_limit", "past_due", "trial_ending", "new_leads"]
    count: int
    example: str | None = Field(default=None, description="One company or lead to name")
    used: int | None = None
    limit: int | None = None


class AdminActivityRow(BaseModel):
    kind: Literal["company_created", "lead_demo", "lead_contact", "lead_newsletter", "staff_joined"]
    title: str = Field(description="Company, person or ticket the event is about")
    at: datetime


class AdminDashboardOut(BaseModel):
    days: int
    since: datetime
    active_companies: AdminStat
    technicians: AdminStat
    reports_sent: AdminStat
    ai_cost_usd: AdminStat
    ai_cost_per_report_usd: float | None
    monthly_revenue: list[AdminMoney] = Field(
        description="From the plans of paying companies (status active); no payments are taken yet"
    )
    reports_per_day: list[AdminDayCount]
    plan_mix: list[AdminPlanMixRow]
    top_companies: list[AdminTopCompany]
    attention: list[AdminAttentionRow]
    activity: list[AdminActivityRow]


# ---- A36 My profile -----------------------------------------------------------------------------------
class StaffProfileIn(_In):
    name: str = Field(min_length=1, max_length=120)
    lang: Literal["en", "hi", "gu", "es", "fr"]


class StaffPasswordIn(_In):
    current_password: str = Field(max_length=256)
    new_password: str = Field(max_length=256)
    code: str = Field(max_length=12, description="6 digits from the authenticator app")


class StaffCodeIn(_In):
    code: str = Field(max_length=12, description="6 digits from the authenticator app")


class StaffRecoveryOut(BaseModel):
    recovery_codes: list[str] = Field(description="Shown once; the old codes stop working")


class StaffDevice(BaseModel):
    id: uuid.UUID
    device: str = Field(description='e.g. "Chrome on macOS"')
    ip: str | None
    started_at: datetime
    last_used_at: datetime | None
    ends_at: datetime
    current: bool


class StaffDevices(BaseModel):
    items: list[StaffDevice]
