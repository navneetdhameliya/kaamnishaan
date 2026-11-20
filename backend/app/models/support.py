"""Support (A28, M47): help requests from the app, answered by KaamNishaan staff; and announcements (A29)
that staff send to people's Messages in the app."""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Identity, Integer, String, Text
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

TICKET_CATEGORIES = ("problem", "question", "billing", "feature")
TICKET_STATUSES = ("open", "waiting", "solved")  # waiting = on the person who asked
AUDIENCES = ("everyone", "owners_managers", "owners", "company")


class SupportTicket(IdMixin, TimestampMixin, Base):
    __tablename__ = "support_tickets"

    # shown as "T-1042"
    number: Mapped[int] = mapped_column(Integer, Identity(start=1001), unique=True)
    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), index=True)
    job_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("jobs.id", ondelete="SET NULL"))
    subject: Mapped[str] = mapped_column(String(140))
    category: Mapped[str] = mapped_column(str_enum(*TICKET_CATEGORIES, name="ticket_category"))
    status: Mapped[str] = mapped_column(
        str_enum(*TICKET_STATUSES, name="ticket_status"), default="open", index=True
    )
    priority: Mapped[str] = mapped_column(
        str_enum("normal", "high", name="ticket_priority"), default="normal"
    )
    lang: Mapped[str] = mapped_column(String(5), default="en", server_default="en")
    app_version: Mapped[str | None] = mapped_column(String(40))
    last_message_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))
    last_from: Mapped[str] = mapped_column(String(8), default="user", server_default="user")  # user, staff
    solved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SupportMessage(IdMixin, Base):
    __tablename__ = "support_messages"

    ticket_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("support_tickets.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    staff_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("staff_users.id", ondelete="SET NULL"))
    body: Mapped[str] = mapped_column(Text)
    internal: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))  # staff only
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class Announcement(IdMixin, TimestampMixin, Base):
    __tablename__ = "announcements"

    audience: Mapped[str] = mapped_column(str_enum(*AUDIENCES, name="announcement_audience"))
    company_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    title: Mapped[dict] = mapped_column(JSONB)  # per language; English always
    body: Mapped[dict] = mapped_column(JSONB)
    send_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    recipients: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("staff_users.id", ondelete="SET NULL"))
