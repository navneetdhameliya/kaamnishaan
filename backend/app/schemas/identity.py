"""Request and response bodies for config, login, profile, companies, team and invites.

Names follow "KaamNishaan — API Analysis (Final version)". Lists answer {data, meta}; single objects
are returned as they are.
"""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

Locale = Literal["en", "hi", "gu", "es", "fr"]
Role = Literal["owner", "manager", "technician"]
Theme = Literal["system", "light", "dark"]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ListMeta(BaseModel):
    counts: dict[str, int] = Field(default_factory=dict)
    next_cursor: str | None = None


# ---- config ------------------------------------------------------------------------
class LanguageOut(BaseModel):
    code: Locale
    native_name: str


class CountryOut(BaseModel):
    code: str
    name: str
    dial_code: str
    flag: str


class TradeOut(BaseModel):
    key: str
    name: str


class ConfigOut(BaseModel):
    languages: list[LanguageOut]
    countries: list[CountryOut]
    trades: list[TradeOut]
    default_country: str
    password_min_length: int
    min_app_version: str
    maintenance: bool
    features: dict[str, bool]


# ---- auth -----------------------------------------------------------------------
class OtpSend(_In):
    phone: str = Field(min_length=6, max_length=20)
    purpose: Literal["login", "verify_phone"] = "login"


class OtpSent(BaseModel):
    challenge_id: uuid.UUID
    resend_after: int = Field(description="Seconds until another code can be asked for")
    expires_at: datetime


class OtpVerify(_In):
    challenge_id: uuid.UUID
    code: str = Field(pattern=r"^[0-9]{4}$")
    device_id: str | None = Field(default=None, max_length=128)


class EmailLogin(_In):
    email: EmailStr
    password: str = Field(max_length=256)


class Register(_In):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(max_length=256)
    phone: str | None = None
    accept_terms: Literal[True]


class TokenBody(_In):
    token: str


class EmailBody(_In):
    email: EmailStr


class PasswordReset(_In):
    token: str
    password: str = Field(max_length=256)


class RefreshBody(_In):
    refresh_token: str


class SwitchCompany(_In):
    company_id: uuid.UUID


# ---- people & companies -------------------------------------------------------------
class CompanySettings(BaseModel):
    technicians_can_share: bool = False
    technicians_can_request_reviews: bool = True
    techs_see_reviews: bool = True


class CompanyOut(BaseModel):
    id: uuid.UUID
    name: str
    trade: str | None
    country: str
    timezone: str
    currency: str
    report_language: Locale
    logo_url: str | None = None
    plan: str
    status: str
    trial_ends_at: datetime | None
    settings: CompanySettings


class MeOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    email: str | None
    email_verified: bool
    avatar_url: str | None = None
    app_language: Locale
    theme: Theme
    role: Role | None
    company: CompanyOut | None
    permissions: list[str]


class CompanyChoice(BaseModel):
    company_id: uuid.UUID
    name: str
    logo_url: str | None = None
    role: Role
    active: bool


class InviterOut(BaseModel):
    name: str
    phone: str | None


class InviteCompany(BaseModel):
    id: uuid.UUID
    name: str
    logo_url: str | None = None
    trade: str | None
    country: str


class MyInvite(BaseModel):
    id: uuid.UUID
    company: InviteCompany
    invited_by: InviterOut
    role: Role
    sent_at: datetime
    expires_at: datetime
    status: Literal["pending", "expired"]


class SessionOut(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: MeOut
    needs: list[Literal["profile", "choose_company", "create_or_join_company", "email_verification"]]
    companies: list[CompanyChoice]
    invites: list[MyInvite]


class MeUpdate(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)


class Preferences(_In):
    app_language: Locale | None = None
    theme: Theme | None = None


class EmailChange(_In):
    email: EmailStr


class DeviceRegister(_In):
    push_token: str = Field(min_length=8, max_length=512)
    platform: Literal["android", "ios", "ipados", "macos", "web"]
    app_version: str | None = Field(default=None, max_length=32)


class CompanyCreate(_In):
    name: str = Field(min_length=1, max_length=120)
    trade: str
    country: str = Field(default="IN", pattern=r"^[A-Z]{2}$")
    timezone: str = "Asia/Kolkata"


class CompanyUpdate(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    trade: str | None = None
    timezone: str | None = None


class CompanySettingsUpdate(_In):
    technicians_can_share: bool | None = None
    technicians_can_request_reviews: bool | None = None
    techs_see_reviews: bool | None = None
    report_language: Locale | None = None


# ---- team & invites --------------------------------------------------------------------
class MemberOut(BaseModel):
    id: uuid.UUID = Field(description="The person's user id")
    name: str
    phone: str | None
    avatar_url: str | None = None
    role: Role
    status: Literal["invited", "active"]
    invite_id: uuid.UUID | None = None
    joined_at: datetime | None = None
    live_status: Literal["on_job", "driving", "idle", "offline"] | None = None
    jobs_today: int = 0


class MemberList(BaseModel):
    data: list[MemberOut]
    meta: ListMeta


class MemberPatch(_In):
    role: Literal["manager", "technician"]


class InviteCreate(_In):
    phone: str
    name: str = Field(min_length=1, max_length=120)
    role: Literal["technician", "manager"]
    sms_language: Locale | None = None


class InviteOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    phone: str
    name: str
    role: Role
    status: Literal["pending", "accepted", "declined", "expired", "revoked"]
    expires_at: datetime
    sms_preview: str
    link: str


class MyInviteList(BaseModel):
    data: list[MyInvite]
    meta: ListMeta


class MyCompanies(BaseModel):
    data: list[CompanyChoice]
    meta: ListMeta


# ---- plans -----------------------------------------------------------------------------
class Money(BaseModel):
    amount: int = Field(description="Minor units: paise or cents")
    currency: Literal["INR", "USD"]


class PlanOut(BaseModel):
    code: str
    name: str
    price: Money | None = Field(description="null = contact us")
    technician_limit: int | None
    report_limit_monthly: int | None = Field(description="null = fair use")
    ai_questions_monthly: int | None
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


class PlansOut(BaseModel):
    currency: Literal["INR", "USD"]
    plans: list[PlanOut]
    credit_packs: list[CreditPackOut]
    credit_rules: CreditRules
    trial_days: int


class Ok(BaseModel):
    ok: bool = True
    details: dict[str, Any] = Field(default_factory=dict)
