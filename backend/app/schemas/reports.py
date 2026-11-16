"""Reports (M30–M33), task status (M31 making) and versions (A15)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import ListMeta
from app.schemas.work import PersonRef

ReportStatus = Literal[
    "generating",
    "generation_failed",
    "draft",
    "pending_review",
    "changes_requested",
    "approved",
    "shared",
    "acknowledged",
]
SectionKey = Literal["summary", "work_done", "advice"]
ChangeReason = Literal[
    "missing_photos", "wrong_details", "unclear_text", "failed_check_not_explained", "other"
]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class TaskStep(BaseModel):
    key: str
    status: Literal["waiting", "running", "done", "failed"]


class TaskOut(BaseModel):
    id: uuid.UUID
    type: str
    status: Literal["queued", "running", "done", "failed"]
    steps: list[TaskStep]
    target_type: str | None
    target_id: uuid.UUID | None
    error: str | None
    created_at: datetime
    finished_at: datetime | None


class ReportStarted(BaseModel):
    task_id: uuid.UUID
    report_id: uuid.UUID
    status: ReportStatus


class JobBrief(BaseModel):
    id: uuid.UUID
    number: str
    title: str
    status: str
    customer: str
    technician: PersonRef | None
    photos: int = 0
    cover_url: str | None = None


class ReportListItem(BaseModel):
    id: uuid.UUID
    number: str
    status: ReportStatus
    job: JobBrief
    drafted_by: Literal["ai", "template"] | None
    flags: int
    submitted_at: datetime | None
    waiting_minutes: int | None = Field(description="Minutes since it was sent for review")
    approved_at: datetime | None
    change_note: str | None
    updated_at: datetime


class ReportList(BaseModel):
    data: list[ReportListItem]
    meta: ListMeta


class SentenceLink(BaseModel):
    section: SectionKey
    text: str
    refs: list[str]


class ReportFlag(BaseModel):
    kind: Literal["missing_evidence", "failed_check", "unsupported_claim"]
    text: str
    ref: str | None = None


class EvidenceSummary(BaseModel):
    photos: dict[str, int]
    pairs: int
    checks_passed: int
    checks_failed: int
    notes: int
    thumbs: list[str]


class ChangeRequestOut(BaseModel):
    id: uuid.UUID
    reasons: list[ChangeReason]
    note: str | None
    requested_by: PersonRef
    created_at: datetime
    resolved_at: datetime | None


class ReportOut(BaseModel):
    id: uuid.UUID
    number: str
    status: ReportStatus
    language: str
    job: JobBrief
    summary: str | None
    work_done: str | None
    advice: str | None
    section_sources: dict[str, str]
    links: list[SentenceLink]
    flags: list[ReportFlag]
    evidence: EvidenceSummary
    drafted_by: Literal["ai", "template"] | None
    task_id: uuid.UUID | None
    error: str | None
    version: int
    change_requests: list[ChangeRequestOut]
    submitted_by: PersonRef | None
    submitted_at: datetime | None
    approved_by: PersonRef | None
    approved_at: datetime | None
    shared_at: datetime | None
    acknowledged_at: datetime | None
    pdf_status: Literal["building", "ready", "failed"] | None
    actions: list[str] = Field(
        description="edit, regenerate, redraft, submit, approve, request_changes, share"
    )
    updated_at: datetime


class ReportPatch(_In):
    summary: str | None = Field(default=None, max_length=2000)
    work_done: str | None = Field(default=None, max_length=6000)
    advice: str | None = Field(default=None, max_length=2000)


class ChangesIn(_In):
    reasons: list[ChangeReason] = Field(min_length=1, max_length=5)
    note: str | None = Field(default=None, max_length=1000)


class VersionOut(BaseModel):
    version: int
    event: str
    source: str
    edited_by: PersonRef | None
    sections: dict[str, str | None]
    created_at: datetime


class VersionList(BaseModel):
    data: list[VersionOut]
    meta: ListMeta
