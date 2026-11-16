"""Checklist templates, job checklists and answers, manager questions, voice notes (M24–M29).

Texts are stored per language in JSON ({"en": "...", "hi": "..."}) with a status per language
(ready, needs_review, missing), so the app shows the job's language and falls back to the source.

When a checklist is attached to a job, the template's questions are copied into the job checklist
(snapshot), so later template edits never change a job that is already running.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

QUESTION_TYPES = ("yes_no", "pass_fail", "number", "text", "choice", "photo", "signature")
PHOTO_RULES = ("none", "always", "if_no", "if_fail")


class ChecklistTemplate(IdMixin, TimestampMixin, Base):
    __tablename__ = "checklist_templates"

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), index=True
    )  # null = global template (made by KaamNishaan, A23)
    trade: Mapped[str | None] = mapped_column(ForeignKey("industries.slug"))
    key: Mapped[str | None] = mapped_column(String(64), unique=True)  # stable key for seeded global templates
    name: Mapped[dict] = mapped_column(JSONB)  # per language
    source_language: Mapped[str] = mapped_column(String(5), default="en", server_default="en")
    minutes: Mapped[int | None] = mapped_column(Integer)  # "About 5 min" on M24
    version: Mapped[int] = mapped_column(Integer, default=1, server_default=sql("1"))
    status: Mapped[str] = mapped_column(
        str_enum("draft", "published", "archived", name="template_status"), default="published"
    )
    usage_count: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    copied_from: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("checklist_templates.id", ondelete="SET NULL")
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))


class ChecklistQuestion(IdMixin, TimestampMixin, Base):
    __tablename__ = "checklist_questions"

    template_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("checklist_templates.id", ondelete="CASCADE"), index=True
    )
    position: Mapped[int] = mapped_column(Integer)
    type: Mapped[str] = mapped_column(str_enum(*QUESTION_TYPES, name="question_type"))
    text: Mapped[dict] = mapped_column(JSONB)  # per language
    help: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=sql("'{}'::jsonb"))
    text_status: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=sql("'{}'::jsonb"))
    options: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))  # choice
    unit: Mapped[str | None] = mapped_column(String(16))  # number: "psi", "°C", "A"
    min_value: Mapped[float | None] = mapped_column(Float)
    max_value: Mapped[float | None] = mapped_column(Float)
    photo_rule: Mapped[str] = mapped_column(str_enum(*PHOTO_RULES, name="photo_rule"), default="none")
    reference_image_key: Mapped[str | None] = mapped_column(String(255))
    required: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    condition: Mapped[dict | None] = mapped_column(JSONB)  # {"question_id": "...", "equals": "no"}
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ShotSlot(IdMixin, Base):
    """Camera hints for a trade or template (M20: "Show the clean filter up close")."""

    __tablename__ = "shot_slots"
    __table_args__ = (UniqueConstraint("template_id", "key", name="uq_shot_slots_template_key"),)

    template_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("checklist_templates.id", ondelete="CASCADE"))
    stage: Mapped[str] = mapped_column(String(16))
    key: Mapped[str] = mapped_column(String(64))
    prompt: Mapped[dict] = mapped_column(JSONB)
    position: Mapped[int] = mapped_column(Integer, default=0)


class JobChecklist(IdMixin, TimestampMixin, Base):
    """A checklist attached to one job. Called a "checklist submission" in the API."""

    __tablename__ = "job_checklists"
    __table_args__ = (UniqueConstraint("job_id", "template_id", name="uq_job_checklists_job_template"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    template_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("checklist_templates.id"))
    template_version: Mapped[int] = mapped_column(Integer)
    name: Mapped[dict] = mapped_column(JSONB)
    minutes: Mapped[int | None] = mapped_column(Integer)
    questions: Mapped[list] = mapped_column(JSONB)  # snapshot of the template's questions
    answered_count: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    total: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    added_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))


class ChecklistAnswer(IdMixin, TimestampMixin, Base):
    __tablename__ = "checklist_answers"
    __table_args__ = (
        UniqueConstraint("job_checklist_id", "question_id", name="uq_checklist_answers_question"),
        UniqueConstraint("company_id", "client_uuid", name="uq_checklist_answers_client"),
    )

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    job_checklist_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("job_checklists.id", ondelete="CASCADE"), index=True
    )
    question_id: Mapped[uuid.UUID] = mapped_column()  # id inside the snapshot
    client_uuid: Mapped[uuid.UUID | None] = mapped_column()
    value: Mapped[dict] = mapped_column(JSONB)  # {"v": "yes" | 12.5 | "text" | "option_key"}
    photo_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("evidence.id"))
    signature_key: Mapped[str | None] = mapped_column(String(255))
    answered_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    answered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ManagerQuestion(IdMixin, TimestampMixin, Base):
    """'Not sure? Ask your manager' from a checklist question or photo (M25)."""

    __tablename__ = "manager_questions"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    job_checklist_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("job_checklists.id", ondelete="SET NULL")
    )
    question_id: Mapped[uuid.UUID | None] = mapped_column()
    photo_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("evidence.id"))
    text: Mapped[str] = mapped_column(Text)
    asked_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    answer: Mapped[str | None] = mapped_column(Text)
    answered_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


VOICE_STATUSES = ("uploaded", "transcribing", "transcribed", "unclear", "failed")


class VoiceNote(IdMixin, TimestampMixin, Base):
    """A voice note (audio) or a typed note when the microphone is off (kind = typed)."""

    __tablename__ = "voice_notes"
    __table_args__ = (UniqueConstraint("company_id", "client_uuid", name="uq_voice_notes_company_client"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    client_uuid: Mapped[uuid.UUID | None] = mapped_column()
    kind: Mapped[str] = mapped_column(str_enum("audio", "typed", name="note_kind"), default="audio")
    audio_key: Mapped[str | None] = mapped_column(String(255))
    content_type: Mapped[str | None] = mapped_column(String(80))
    size: Mapped[int | None] = mapped_column(BigInteger)
    sha256: Mapped[str | None] = mapped_column(String(64))
    duration_s: Mapped[float | None] = mapped_column(Float)
    language_hint: Mapped[str | None] = mapped_column(String(5))  # chip chosen on M27
    detected_language: Mapped[str | None] = mapped_column(String(8))
    status: Mapped[str] = mapped_column(str_enum(*VOICE_STATUSES, name="voice_status"), default="uploaded")
    transcript_original: Mapped[str | None] = mapped_column(Text)
    transcript_translated: Mapped[str | None] = mapped_column(Text)
    translated_to: Mapped[str | None] = mapped_column(String(5))
    transcript_edited: Mapped[str | None] = mapped_column(Text)
    confidence: Mapped[float | None] = mapped_column(Float)
    error: Mapped[str | None] = mapped_column(String(300))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    recorded_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
