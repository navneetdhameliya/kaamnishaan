"""Request and response bodies for login, profile, companies and team. Mirrors shared/api/openapi.yaml."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

Locale = Literal["en", "hi", "gu", "es", "fr"]
Role = Literal["owner", "manager", "technician"]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


# ---- auth -----------------------------------------------------------------------
class OtpRequest(_In):
    phone: str = Field(min_length=6, max_length=20)
    purpose: Literal["login", "verify_phone"] = "login"


class OtpRequested(BaseModel):
    challenge_id: uuid.UUID
    resend_after_s: int


class OtpVerify(_In):
    challenge_id: uuid.UUID
    code: str = Field(pattern=r"^[0-9]{4}$")
    device_id: str | None = Field(default=None, max_length=128)


class EmailLogin(_In):
    email: EmailStr
    password: str = Field(max_length=256)
    otp: str | None = None


class OwnerSignup(_In):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=256)
    phone: str | None = None
    accept_terms: Literal[True]


class TokenBody(_In):
    token: str


class EmailBody(_In):
    email: EmailStr


class PasswordReset(_In):
    token: str
    password: str = Field(min_length=8, max_length=256)


class RefreshBody(_In):
    refresh_token: str


class SwitchCompany(_In):
    company_id: uuid.UUID


# ---- people & companies -------------------------------------------------------------
class CompanySettings(BaseModel):
    technicians_can_share: bool = False
    technicians_can_request_reviews: bool = True


class CompanyOut(BaseModel):
    id: uuid.UUID
    name: str
    industry: str | None
    country: str
    timezone: str
    report_language: Locale
    logo_url: str | None = None
    status: str
    trial_ends_at: datetime | None
    settings: CompanySettings


class MeOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    email: str | None
    avatar_url: str | None = None
    app_language: Locale
    role: Role | None
    company: CompanyOut | None
    permissions: list[str]


class CompanyChoice(BaseModel):
    company_id: uuid.UUID
    name: str
    logo_url: str | None = None
    role: Role
    active: bool


class SessionOut(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: MeOut
    needs: list[Literal["profile", "choose_company", "create_or_join_company", "email_verification"]]
    companies: list[CompanyChoice]


class MeUpdate(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    app_language: Locale | None = None
    avatar_evidence_upload: bool | None = None


class DeviceRegister(_In):
    push_token: str = Field(min_length=8, max_length=512)
    platform: Literal["android", "ios", "macos", "web"]
    app_version: str | None = Field(default=None, max_length=32)


class CompanyCreate(_In):
    name: str = Field(min_length=1, max_length=120)
    industry: str
    country: str = Field(default="IN", pattern=r"^[A-Z]{2}$")
    timezone: str = "Asia/Kolkata"


class CompanyUpdate(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    industry: str | None = None
    report_language: Locale | None = None
    settings: dict | None = None


# ---- team -----------------------------------------------------------------------------
class PersonRef(BaseModel):
    id: uuid.UUID
    name: str
    avatar_url: str | None = None


class MemberOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    avatar_url: str | None = None
    role: Role
    status: Literal["invited", "active", "removed"]
    live_status: Literal["on_job", "driving", "idle", "offline"] | None = None
    jobs_today: int = 0


class MemberList(BaseModel):
    items: list[MemberOut]


class InvitationCreate(_In):
    phone: str
    name: str = Field(min_length=1, max_length=120)
    role: Literal["technician", "manager"]


class MemberPatch(_In):
    role: Role | None = None
    status: Literal["active", "removed"] | None = None


class InvitationPreview(BaseModel):
    company_name: str
    company_logo_url: str | None = None
    invited_by: PersonRef
    role: Role


class PendingInvitation(InvitationPreview):
    id: uuid.UUID


class MyCompanies(BaseModel):
    items: list[CompanyChoice]
    invitations: list[PendingInvitation]


# ---- public content ---------------------------------------------------------------------
class Money(BaseModel):
    amount_minor: int
    currency: Literal["INR", "USD"]


class PlanPublic(BaseModel):
    code: str
    name: str
    price: Money | None
    technician_limit: int | None
    report_limit_monthly: int | None
    monthly_credits: int | None
    most_popular: bool
    features: list[str]


class CreditPackOut(BaseModel):
    id: uuid.UUID
    credits: int
    price: Money


class CreditRules(BaseModel):
    sms: int = 1
    whatsapp: int = 1
    ai_call: int = 10
    email: int = 0


class PublicPlans(BaseModel):
    plans: list[PlanPublic]
    credit_packs: list[CreditPackOut]
    credit_rules: CreditRules
    trial_days: int


class IndustryOut(BaseModel):
    slug: str
    name: str
    image_url: str | None = None
    page_slug: str | None = None


class IndustryList(BaseModel):
    items: list[IndustryOut]
