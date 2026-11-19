"""Admin panel A08 Users and A09 User details. A row is one person in one company (a membership)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.admin_companies import AdminOption
from app.schemas.identity import _In

Role = Literal["owner", "manager", "technician"]
Login = Literal["email", "phone", "invited"]


class AdminUserRow(BaseModel):
    membership_id: uuid.UUID
    user_id: uuid.UUID
    name: str | None
    phone: str | None
    email: str | None
    company_id: uuid.UUID
    company: str
    role: Role
    login: Login = Field(description="email: email + password; phone: phone + OTP; invited: not joined yet")
    language: str | None = Field(description="App language; None while invited")
    status: Literal["active", "invited", "removed", "disabled"] = Field(
        description="disabled: turned off by KaamNishaan staff (for every company)"
    )
    on_job: bool = Field(description="Has a job in progress now")
    last_seen_at: datetime | None
    invited_at: datetime | None


class AdminUserCounts(BaseModel):
    all: int
    technician: int
    manager: int
    owner: int
    invited: int


class AdminUserList(BaseModel):
    items: list[AdminUserRow]
    total: int
    page: int
    page_size: int
    counts: AdminUserCounts
    company: AdminOption | None = Field(description="The company filter, when one is set")


class AdminUserCompany(BaseModel):
    membership_id: uuid.UUID
    company_id: uuid.UUID
    company: str
    role: Role
    status: str
    joined_at: datetime | None
    report_language: str


class AdminUserActivity(BaseModel):
    action: str = Field(description="Audit action, e.g. report.sent")
    at: datetime


class AdminUserDetail(BaseModel):
    id: uuid.UUID
    name: str | None
    phone: str | None
    email: str | None
    email_verified: bool
    login: Login
    status: Literal["active", "invited", "disabled"]
    app_language: str
    created_at: datetime
    last_seen_at: datetime | None
    on_job: bool
    device: str | None = Field(description="Latest signed-in device, e.g. android · app 1.0.4")
    active_sessions: int
    companies: list[AdminUserCompany]
    jobs_30d: int
    reports_30d: int
    changes_asked_30d: int
    activity: list[AdminUserActivity]


class AdminUserAction(_In):
    reason: str = Field(min_length=3, max_length=300, description="Written to the audit log")
