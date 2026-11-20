"""Admin panel A04 Companies and A05 Company details."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

from app.schemas.identity import Locale, _In

CompanyStatus = Literal["trial", "active", "past_due", "suspended", "cancelled"]
# what the list shows: the status, or "near_limit" for a paying company at 90 % of its monthly reports
CompanyBadge = Literal["trial", "active", "past_due", "suspended", "cancelled", "near_limit"]


class AdminOption(BaseModel):
    value: str
    label: str


class AdminCompanyRow(BaseModel):
    id: uuid.UUID
    name: str
    owner_name: str | None
    owner_email: str | None
    country: str
    industry: str | None
    plan_code: str
    plan: str
    technicians: int = Field(description="Active technicians")
    technician_limit: int | None = Field(description="Seats in the plan; None = no limit")
    reports_30d: int
    status: CompanyStatus
    badge: CompanyBadge
    trial_days_left: int | None
    created_at: datetime


class AdminCompanyCounts(BaseModel):
    all: int
    trial: int
    active: int
    past_due: int
    suspended: int
    cancelled: int


class AdminCompanyList(BaseModel):
    items: list[AdminCompanyRow]
    total: int = Field(description="Matching the search and filters")
    page: int
    page_size: int
    counts: AdminCompanyCounts = Field(
        description="Per status, for the tabs (search and other filters applied)"
    )
    plans: list[AdminOption]
    industries: list[AdminOption]
    countries: list[str]


class AdminPlanInfo(BaseModel):
    code: str
    name: str
    prices: dict[str, int]
    technician_limit: int | None
    report_limit_monthly: int | None


class AdminTeamMember(BaseModel):
    id: uuid.UUID
    name: str | None
    role: str
    login: Literal["email", "phone"]
    language: str
    status: str
    last_seen_at: datetime | None


class AdminCompanyDetail(BaseModel):
    id: uuid.UUID
    name: str
    industry_slug: str | None
    status: CompanyStatus
    suspended_at: datetime | None
    suspend_reason: str | None
    badge: CompanyBadge
    trial_ends_at: datetime | None
    created_at: datetime
    country: str
    currency: str
    timezone: str
    report_language: str
    industry: str | None
    plan: AdminPlanInfo
    owner_name: str | None
    owner_email: str | None
    owner_phone: str | None
    owner_user_id: uuid.UUID | None
    owner_pending: bool = Field(description="The owner was invited by KaamNishaan and hasn't joined yet")
    health: Literal["good", "quiet", "at_risk"] = Field(
        description="at_risk: past due or suspended; quiet: nobody active for 14 days; else good"
    )
    last_active_at: datetime | None
    cycle_start: datetime
    cycle_end: datetime
    jobs_this_cycle: int
    reports_this_cycle: int
    technicians: int
    members: int
    approval_minutes_median: float | None = Field(description="Job completed → report approved, last 30 days")
    ai_cost_30d_usd: float
    ai_cost_per_report_usd: float | None
    team: list[AdminTeamMember] = Field(description="Owner, managers, then technicians; first 5")
    upgrade_to: AdminPlanInfo | None = Field(
        description="The next plan when this one's reports or seats are used up, else None"
    )


class AdminCompanyCreate(_In):
    """A06. The owner joins with their phone: they log in with an OTP and accept the invite."""

    name: str = Field(min_length=1, max_length=120)
    trade: str
    country: str = Field(default="IN", pattern=r"^[A-Z]{2}$")
    report_language: Locale = "en"
    owner_name: str = Field(min_length=1, max_length=120)
    owner_phone: str = Field(min_length=6, max_length=24)
    owner_email: EmailStr | None = None
    plan: str = "professional"


class AdminCompanyUpdate(_In):
    """A07. The owner's own details are changed on their user page, not here."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    trade: str | None = None
    country: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    report_language: Locale | None = None
    plan: str | None = None
    trial_ends_at: datetime | None = Field(default=None, description="Only for a company in trial")


class AdminCompanyReason(_In):
    reason: str = Field(min_length=3, max_length=300, description="Written to the audit log")


class AdminOwnerInvite(BaseModel):
    company: AdminCompanyDetail
    invite_link: str = Field(description="Shown once. The SMS is sent too when SMS is set up.")
    sms_text: str
