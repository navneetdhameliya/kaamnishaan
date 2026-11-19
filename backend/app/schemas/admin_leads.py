"""Admin panel: website leads (W03 demo bookings, W05 contact messages, W25 newsletter emails)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.identity import _In

LeadKind = Literal["demo", "contact", "newsletter"]
LeadStatus = Literal["new", "contacted", "done", "spam"]


class AdminLeadRow(BaseModel):
    id: uuid.UUID
    number: int = Field(description="Shown as KN-20001")
    kind: LeadKind
    status: LeadStatus
    name: str
    email: str
    company: str | None
    topic: str | None
    starts_at: datetime | None = Field(description="Demo time")
    preview: str | None = Field(description="Start of the message")
    created_at: datetime


class AdminLeadCounts(BaseModel):
    new: int = Field(description="Demos and messages not handled yet")
    demo: int
    contact: int
    newsletter: int
    done: int = Field(description="Contacted, done or spam")


class AdminLeadList(BaseModel):
    items: list[AdminLeadRow]
    total: int
    page: int
    page_size: int
    counts: AdminLeadCounts


class AdminLeadDetail(AdminLeadRow):
    phone: str | None
    team_size: str | None
    trade: str | None = Field(description="Industry name in the asked language")
    message: str | None
    lang: str
    note: str | None
    handled_by: str | None = Field(description="Staff name")
    handled_at: datetime | None
    company_id: uuid.UUID | None = Field(
        description="A KaamNishaan company whose owner has this email, if any"
    )
    company_name: str | None


class AdminLeadUpdate(_In):
    status: LeadStatus | None = None
    note: str | None = Field(default=None, max_length=2000, description="Replaces the note; empty clears it")
