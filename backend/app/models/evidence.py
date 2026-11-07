"""Uploads and job evidence (M19–M23).

Evidence locks when the report is submitted: from then on a database trigger refuses to change or
delete the photo, its stage, time, author or place. Notes can still be added after lock.
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
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

UPLOAD_KINDS = ("photo", "audio", "logo", "avatar", "signature")
STAGES = ("before", "during", "after")


class Upload(IdMixin, Base):
    """A slot the app uploads one file into; used once by the call that confirms it."""

    __tablename__ = "uploads"

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(str_enum(*UPLOAD_KINDS, name="upload_kind"))
    content_type: Mapped[str] = mapped_column(String(80))
    key: Mapped[str] = mapped_column(String(255), unique=True)
    max_bytes: Mapped[int] = mapped_column(BigInteger)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class Evidence(IdMixin, TimestampMixin, Base):
    __tablename__ = "evidence"
    __table_args__ = (UniqueConstraint("company_id", "client_uuid", name="uq_evidence_company_client"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    client_uuid: Mapped[uuid.UUID | None] = mapped_column()
    stage: Mapped[str] = mapped_column(str_enum(*STAGES, name="evidence_stage"))
    shot_slot: Mapped[str | None] = mapped_column(String(64))  # e.g. "outdoor_unit" from the shot prompts
    file_key: Mapped[str] = mapped_column(String(255))
    thumb_key: Mapped[str | None] = mapped_column(String(255))
    content_type: Mapped[str] = mapped_column(String(80))
    size: Mapped[int] = mapped_column(BigInteger)
    sha256: Mapped[str | None] = mapped_column(String(64))  # fingerprint: proves the photo never changed
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)
    processing: Mapped[str] = mapped_column(
        str_enum("pending", "ready", "failed", name="evidence_processing"),
        default="pending",
        server_default="pending",
    )
    taken_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    taken_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    lat: Mapped[float | None] = mapped_column(Float)
    lng: Mapped[float | None] = mapped_column(Float)
    locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class EvidenceNote(IdMixin, Base):
    __tablename__ = "evidence_notes"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    evidence_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("evidence.id", ondelete="CASCADE"), index=True)
    author_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class PhotoPair(IdMixin, TimestampMixin, Base):
    __tablename__ = "photo_pairs"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    before_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("evidence.id"))
    after_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("evidence.id"))
    subject: Mapped[str | None] = mapped_column(String(120))
    use_in_report: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
