"""Reports (M30–M33), their versions and change requests; background task status; AI usage and prompts.

Report status (API document, State machines → Report):
    generating -> draft | generation_failed
    draft -> pending_review (submit; evidence locks; job in_review)
    pending_review -> approved (job completed) | changes_requested (job changes_requested)
    changes_requested -> generating (redraft) | pending_review (resubmit)
    approved -> shared -> acknowledged   (Step 1f)
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

REPORT_STATUSES = (
    "generating", "generation_failed", "draft", "pending_review", "changes_requested", "approved", "shared",
    "acknowledged",
)  # fmt: skip
SECTIONS = ("summary", "work_done", "advice")


class Report(IdMixin, TimestampMixin, Base):
    __tablename__ = "reports"
    __table_args__ = (
        UniqueConstraint("company_id", "number", name="uq_reports_company_number"),
        UniqueConstraint("job_id", name="uq_reports_job"),
    )

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"))
    number: Mapped[int] = mapped_column(Integer)  # shown as R-1042
    status: Mapped[str] = mapped_column(
        str_enum(*REPORT_STATUSES, name="report_status"), default="generating"
    )
    language: Mapped[str] = mapped_column(String(5))
    summary: Mapped[str | None] = mapped_column(Text)
    work_done: Mapped[str | None] = mapped_column(Text)
    advice: Mapped[str | None] = mapped_column(Text)
    # which section came from where: {"summary": "ai" | "template" | "technician" | "manager"}
    section_sources: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=sql("'{}'::jsonb"))
    # sentence -> evidence links the AI gave: {"summary": [{"text": "...", "refs": ["photo:<id>", ...]}]}
    evidence_links: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=sql("'{}'::jsonb"))
    flags: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))
    source_counts: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=sql("'{}'::jsonb"))
    checks_passed: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    checks_failed: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    drafted_by: Mapped[str | None] = mapped_column(String(16))  # ai | template
    ai_prompt_version: Mapped[int | None] = mapped_column(Integer)
    ai_tokens: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    ai_cost_usd: Mapped[float] = mapped_column(Float, default=0, server_default=sql("0"))
    error: Mapped[str | None] = mapped_column(String(300))
    task_id: Mapped[uuid.UUID | None] = mapped_column()
    version: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    submitted_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    approved_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ReportVersion(IdMixin, Base):
    """Every change to the text: v1 AI draft, v2 edited by the technician, v3 approved... (A15)."""

    __tablename__ = "report_versions"
    __table_args__ = (UniqueConstraint("report_id", "version", name="uq_report_versions"),)

    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    version: Mapped[int] = mapped_column(Integer)
    sections: Mapped[dict] = mapped_column(JSONB)
    source: Mapped[str] = mapped_column(String(16))  # ai, template, technician, manager
    event: Mapped[str] = mapped_column(String(24))  # drafted, edited, regenerated, submitted, approved
    edited_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class ChangeRequest(IdMixin, Base):
    __tablename__ = "change_requests"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    reasons: Mapped[list[str]] = mapped_column(ARRAY(String(32)))
    note: Mapped[str | None] = mapped_column(Text)
    requested_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class BackgroundTask(IdMixin, TimestampMixin, Base):
    """What GET /tasks/{id} shows while a long job runs (M31 "making your report")."""

    __tablename__ = "background_tasks"

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    type: Mapped[str] = mapped_column(String(32))  # report_draft, section_regenerate
    status: Mapped[str] = mapped_column(
        str_enum("queued", "running", "done", "failed", name="task_status"), default="queued"
    )
    steps: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))
    target_type: Mapped[str | None] = mapped_column(String(32))
    target_id: Mapped[uuid.UUID | None] = mapped_column()
    error: Mapped[str | None] = mapped_column(String(300))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AIUsage(IdMixin, Base):
    """One row per AI call, for cost per report and the A20 usage screens."""

    __tablename__ = "ai_usage"

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="SET NULL"), index=True
    )
    task: Mapped[str] = mapped_column(String(32))
    model: Mapped[str] = mapped_column(String(64))
    tokens_in: Mapped[int] = mapped_column(Integer, default=0)
    tokens_out: Mapped[int] = mapped_column(Integer, default=0)
    audio_seconds: Mapped[float] = mapped_column(Float, default=0)
    cost_usd: Mapped[float] = mapped_column(Float, default=0)
    related_id: Mapped[uuid.UUID | None] = mapped_column()
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class PromptVersion(IdMixin, TimestampMixin, Base):
    """Prompts are data, versioned and edited in A21; one live version per task."""

    __tablename__ = "prompt_versions"
    __table_args__ = (UniqueConstraint("task", "version", name="uq_prompt_versions"),)

    task: Mapped[str] = mapped_column(String(32))
    version: Mapped[int] = mapped_column(Integer)
    system_prompt: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        str_enum("draft", "live", "retired", name="prompt_status"), default="draft"
    )
    live: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
