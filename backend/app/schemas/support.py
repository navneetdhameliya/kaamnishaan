"""M47 Help (app) and A28 Support tickets / A29 Notifications (admin panel)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

TicketCategory = Literal["problem", "question", "billing", "feature"]
TicketStatus = Literal["open", "waiting", "solved"]
Audience = Literal["everyone", "owners_managers", "owners", "company"]
LANGS = ("en", "hi", "gu", "es", "fr")


# ---- app (M47 Help) ---------------------------------------------------------------------------------
class TicketCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    category: TicketCategory
    subject: str = Field(min_length=3, max_length=140)
    body: str = Field(min_length=10, max_length=4000)
    job_id: uuid.UUID | None = None
    app_version: str | None = Field(None, max_length=40)


class TicketReply(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    body: str = Field(min_length=1, max_length=4000)


class TicketMessageOut(BaseModel):
    id: uuid.UUID
    from_support: bool
    author: str | None = Field(description="The person's name; None for KaamNishaan support")
    body: str
    created_at: datetime


class TicketOut(BaseModel):
    id: uuid.UUID
    number: str = Field(description="T-1042")
    subject: str
    category: TicketCategory
    status: TicketStatus
    job_id: uuid.UUID | None
    created_at: datetime
    last_message_at: datetime
    last_from: Literal["user", "staff"]
    messages: list[TicketMessageOut] = Field(default_factory=list, description="Only on GET one")


class TicketList(BaseModel):
    data: list[TicketOut]


# ---- admin (A28) -------------------------------------------------------------------------------------
class AdminTicketRow(BaseModel):
    id: uuid.UUID
    number: str
    subject: str
    category: TicketCategory
    status: TicketStatus
    priority: Literal["normal", "high"]
    company: str | None
    company_id: uuid.UUID | None
    person: str | None
    created_at: datetime
    last_message_at: datetime
    last_from: Literal["user", "staff"]


class AdminTicketList(BaseModel):
    items: list[AdminTicketRow]
    total: int
    page: int
    page_size: int
    counts: dict[str, int] = Field(description="open, waiting, solved, high (open or waiting)")


class AdminTicketMessage(BaseModel):
    id: uuid.UUID
    from_support: bool
    internal: bool
    author: str | None
    body: str
    created_at: datetime


class AdminTicketDetail(AdminTicketRow):
    plan: str | None
    company_status: str | None
    person_role: str | None
    person_phone: str | None
    lang: str
    app_version: str | None
    job_id: uuid.UUID | None
    job_number: str | None
    messages: list[AdminTicketMessage]


class AdminTicketReply(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    body: str = Field(min_length=1, max_length=4000)
    internal: bool = False
    solve: bool = Field(False, description="Send and mark solved")


class AdminTicketPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: TicketStatus | None = None
    priority: Literal["normal", "high"] | None = None


# ---- admin (A29) -------------------------------------------------------------------------------------
class AdminRule(BaseModel):
    kind: str
    on: bool
    to: str = Field(description="owner, manager, technician, office (owners and managers)")
    channel: Literal["in_app", "email"]
    available: bool = Field(description="False when it needs a service that isn't set up (email)")


class AdminAnnouncementOut(BaseModel):
    id: uuid.UUID
    audience: Audience
    company: str | None
    title: dict[str, str]
    body: dict[str, str]
    send_at: datetime
    sent_at: datetime | None
    cancelled_at: datetime | None
    recipients: int
    by: str | None


class AdminNotificationsOut(BaseModel):
    rules: list[AdminRule]
    announcements: list[AdminAnnouncementOut]
    audience_sizes: dict[str, int] = Field(description="People each audience reaches now")
    can_act: bool


class AdminRulesIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    on: dict[str, bool]


class AdminAnnouncementIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    audience: Audience
    company_id: uuid.UUID | None = None
    title: dict[Literal["en", "hi", "gu", "es", "fr"], str]
    body: dict[Literal["en", "hi", "gu", "es", "fr"], str]
    send_at: datetime | None = Field(None, description="Empty = now")

    @field_validator("title", "body")
    @classmethod
    def _english(cls, v: dict, info) -> dict:
        limit = 80 if info.field_name == "title" else 600
        clean = {k: x.strip() for k, x in v.items() if x and x.strip()}
        if not clean.get("en"):
            raise ValueError("English is needed")
        if any(len(x) > limit for x in clean.values()):
            raise ValueError(f"At most {limit} characters")
        return clean
