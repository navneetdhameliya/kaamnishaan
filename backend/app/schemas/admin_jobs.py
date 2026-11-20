"""Admin panel: A11 Jobs (every company's jobs) and A12 Job details. Read-only."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.admin_companies import AdminOption

JobStatus = Literal[
    "unassigned", "assigned", "in_progress", "in_review", "changes_requested", "completed", "cancelled"
]


class AdminProof(BaseModel):
    done: int
    total: int = Field(description="Before, during, after photos, checklists (if any), voice note")


class AdminJobRow(BaseModel):
    id: uuid.UUID
    number: str = Field(description="J-2231")
    title: str
    customer: str
    company: AdminOption
    technician: str | None
    status: JobStatus
    proof: AdminProof
    when: datetime = Field(description="Scheduled time, or when it was created")
    is_quick_job: bool


class AdminJobList(BaseModel):
    items: list[AdminJobRow]
    total: int
    page: int
    page_size: int
    counts: dict[str, int] = Field(description="Jobs per status for the current search, company and dates")
    companies: list[AdminOption] = Field(description="Companies with jobs, for the filter")


class AdminJobPlace(BaseModel):
    address: str | None
    site_lat: float | None
    site_lng: float | None
    started_at: datetime | None
    start_lat: float | None = Field(description="Where the technician pressed Start")
    start_lng: float | None
    start_distance_m: int | None = Field(description="Start point to the site, when both are known")


class AdminJobChecklist(BaseModel):
    name: str
    answered: int
    total: int
    done: bool


class AdminJobPhotos(BaseModel):
    before: int
    during: int
    after: int
    voice_notes: int


class AdminJobReport(BaseModel):
    number: str = Field(description="R-1042")
    status: str
    submitted_at: datetime | None
    approved_at: datetime | None
    shared_at: datetime | None
    acknowledged_at: datetime | None
    change_requests: int
    open_count: int = Field(description="How many times the customer opened the report link")


class AdminTimelineItem(BaseModel):
    type: str = Field(
        description="created, assigned, unassigned, started, edited, cancelled, photos, voice, "
        "report_submitted, changes_requested, approved, shared, acknowledged"
    )
    at: datetime
    until: datetime | None = Field(None, description="For grouped photos: the last one")
    actor: str | None = None
    data: dict = Field(default_factory=dict)


class AdminJobDetail(BaseModel):
    id: uuid.UUID
    number: str
    title: str
    description: str | None
    status: JobStatus
    is_quick_job: bool
    company: AdminOption
    industry: str | None
    customer: str
    contact: str | None
    technician: str | None
    scheduled_at: datetime | None
    duration_min: int | None
    created_at: datetime
    completed_at: datetime | None
    cancel_reason: str | None
    place: AdminJobPlace
    checklists: list[AdminJobChecklist]
    photos: AdminJobPhotos
    proof: AdminProof
    report: AdminJobReport | None
    timeline: list[AdminTimelineItem]
