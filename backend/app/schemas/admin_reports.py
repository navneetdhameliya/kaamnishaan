"""Admin panel: A14 Reports (every company's reports) and A15 Report details. Read-only."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.admin_companies import AdminOption
from app.schemas.reports import ReportStatus

AiCheck = Literal["passed", "failed_check", "missing_evidence", "unsupported_claim", "not_checked"]


class AdminReportJob(BaseModel):
    id: uuid.UUID
    number: str
    title: str
    customer: str


class AdminReportRow(BaseModel):
    id: uuid.UUID
    number: str = Field(description="R-1042")
    status: ReportStatus
    language: str
    job: AdminReportJob
    company: AdminOption
    technician: str | None
    check: AiCheck = Field(description="The first problem the AI checks found, or passed")
    check_count: int = Field(description="How many problems of that kind")
    created_at: datetime
    shared_at: datetime | None


class AdminReportList(BaseModel):
    items: list[AdminReportRow]
    total: int
    page: int
    page_size: int
    counts: dict[str, int] = Field(description="Reports per status for the current search, company and dates")
    companies: list[AdminOption]


class AdminReportFlag(BaseModel):
    kind: Literal["missing_evidence", "failed_check", "unsupported_claim"]
    text: str


class AdminReportChange(BaseModel):
    reasons: list[str]
    note: str | None
    by: str | None
    at: datetime
    resolved_at: datetime | None


class AdminReportLink(BaseModel):
    channel: str
    recipient: str | None = Field(description="Name, with the phone or email partly hidden")
    created_at: datetime
    expires_at: datetime
    revoked: bool
    opens: int
    last_opened_at: datetime | None


class AdminReportVersion(BaseModel):
    version: int
    event: str
    source: str
    by: str | None
    at: datetime


class AdminReportPhoto(BaseModel):
    stage: str
    url: str


class AdminReportDetail(BaseModel):
    id: uuid.UUID
    number: str
    status: ReportStatus
    language: str
    job: AdminReportJob
    company: AdminOption
    technician: str | None
    drafted_by: Literal["ai", "template"] | None
    edited_by: list[str] = Field(description="People who changed the text after the draft")
    summary: str | None
    work_done: str | None
    advice: str | None
    photos: list[AdminReportPhoto]
    sentences: int
    sentences_linked: int
    checks_passed: int
    checks_failed: int
    flags: list[AdminReportFlag]
    ai_prompt_version: int | None
    ai_tokens: int
    ai_cost_usd: float
    error: str | None
    submitted_by: str | None
    submitted_at: datetime | None
    approved_by: str | None
    approved_at: datetime | None
    shared_at: datetime | None
    acknowledged_at: datetime | None
    acknowledged_name: str | None
    changes: list[AdminReportChange]
    links: list[AdminReportLink]
    versions: list[AdminReportVersion]
    pdf_url: str | None = Field(description="Short-lived download link when the PDF is ready")
    created_at: datetime
