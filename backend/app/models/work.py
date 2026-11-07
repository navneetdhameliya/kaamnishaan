"""Customers, their sites, contacts and equipment, and jobs with their timeline (M12–M18, A11, A12).

Every table carries company_id; every query filters by the company in the access token.
Rows that reports or audits point to are soft-deleted (deleted_at), never removed.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

JOB_STATUSES = (
    "unassigned",
    "assigned",
    "in_progress",
    "in_review",
    "changes_requested",
    "completed",
    "cancelled",
)


class VersionMixin:
    """Edits send If-Match: <version>; a stale edit gets 409 with the server copy."""

    version: Mapped[int] = mapped_column(Integer, default=1, server_default=text("1"))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Customer(IdMixin, TimestampMixin, VersionMixin, Base):
    __tablename__ = "customers"
    __table_args__ = (UniqueConstraint("company_id", "client_uuid", name="uq_customers_company_client"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    photo_key: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    client_uuid: Mapped[uuid.UUID | None] = mapped_column()


class CustomerContact(IdMixin, TimestampMixin, Base):
    __tablename__ = "customer_contacts"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    title: Mapped[str | None] = mapped_column(String(80))
    phone: Mapped[str | None] = mapped_column(String(20), index=True)
    email: Mapped[str | None] = mapped_column(String(254))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    review_opt_out_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Site(IdMixin, TimestampMixin, Base):
    __tablename__ = "sites"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id", ondelete="CASCADE"), index=True)
    label: Mapped[str | None] = mapped_column(String(80))  # "Head office", "Warehouse 2"
    address_line1: Mapped[str] = mapped_column(String(200))
    address_line2: Mapped[str | None] = mapped_column(String(200))
    city: Mapped[str | None] = mapped_column(String(80))
    state: Mapped[str | None] = mapped_column(String(80))
    postcode: Mapped[str | None] = mapped_column(String(16))
    country: Mapped[str] = mapped_column(String(2), default="IN")
    lat: Mapped[float | None] = mapped_column(Float)
    lng: Mapped[float | None] = mapped_column(Float)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Equipment(IdMixin, TimestampMixin, Base):
    __tablename__ = "equipment"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    site_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("sites.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(80))  # "Split AC", "Rooftop unit"
    brand: Mapped[str | None] = mapped_column(String(80))
    model: Mapped[str | None] = mapped_column(String(80))
    capacity: Mapped[str | None] = mapped_column(String(40))  # "1.5 ton"
    location: Mapped[str | None] = mapped_column(String(80))  # room or area
    last_service_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    photo_key: Mapped[str | None] = mapped_column(String(255))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Job(IdMixin, TimestampMixin, VersionMixin, Base):
    __tablename__ = "jobs"
    __table_args__ = (
        UniqueConstraint("company_id", "number", name="uq_jobs_company_number"),
        UniqueConstraint("company_id", "client_uuid", name="uq_jobs_company_client"),
        Index("ix_jobs_company_status_scheduled", "company_id", "status", "scheduled_at"),
        Index("ix_jobs_assignee_scheduled", "assigned_to", "scheduled_at"),
        Index("ix_jobs_company_updated", "company_id", "updated_at"),
    )

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    number: Mapped[int] = mapped_column(Integer)  # shown as J-2231
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id"))
    site_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("sites.id"))
    contact_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("customer_contacts.id"))
    equipment_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("equipment.id"))
    title: Mapped[str] = mapped_column(String(160))
    description: Mapped[str | None] = mapped_column(Text)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_min: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(str_enum(*JOB_STATUSES, name="job_status"), default="unassigned")
    assigned_to: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    is_quick_job: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    start_lat: Mapped[float | None] = mapped_column(Float)
    start_lng: Mapped[float | None] = mapped_column(Float)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancel_reason: Mapped[str | None] = mapped_column(String(300))
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    client_uuid: Mapped[uuid.UUID | None] = mapped_column()


class JobEvent(IdMixin, Base):
    """Append-only job timeline (M15, A12). Never updated."""

    __tablename__ = "job_events"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(32))  # created, assigned, unassigned, started, cancelled, edited
    from_status: Mapped[str | None] = mapped_column(String(32))
    to_status: Mapped[str | None] = mapped_column(String(32))
    actor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    data: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=text("'{}'::jsonb"))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))
