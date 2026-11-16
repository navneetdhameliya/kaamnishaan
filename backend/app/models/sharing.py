"""Sending an approved report to the customer (M34, M35) and the customer's report page (W27).

A share link's token is never stored: only its SHA-256. The token is rebuilt from the link id and the
server secret (HMAC), so M35 can show the current link again. Changing KN_SECRET_KEY turns every link off.

Share link: active -> expired (30 days) | revoked.  Message: queued -> sent -> delivered | failed.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy import text as sql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

CHANNELS = ("sms", "whatsapp", "email", "copy")


class ShareLink(IdMixin, TimestampMixin, Base):
    __tablename__ = "share_links"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    channel: Mapped[str] = mapped_column(str_enum(*CHANNELS, name="share_channel"))
    recipient_name: Mapped[str | None] = mapped_column(String(160))
    phone: Mapped[str | None] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(254))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    first_opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    open_count: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    new_link_requested_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Message(IdMixin, Base):
    """Every message sent to a customer. Credits per SMS or WhatsApp are counted from Step 2."""

    __tablename__ = "messages"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    report_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("reports.id", ondelete="CASCADE"), index=True
    )
    share_link_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("share_links.id", ondelete="SET NULL"))
    channel: Mapped[str] = mapped_column(str_enum("sms", "whatsapp", "email", name="message_channel"))
    to: Mapped[str] = mapped_column(String(254))
    template: Mapped[str] = mapped_column(String(48))
    language: Mapped[str] = mapped_column(String(5))
    body: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        str_enum("queued", "sent", "delivered", "read", "failed", "bounced", name="message_status"),
        default="queued",
    )
    provider_id: Mapped[str | None] = mapped_column(String(120))
    error: Mapped[str | None] = mapped_column(String(300))
    sent_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class ReportIssue(IdMixin, Base):
    """ "Report a problem" from the customer page, and "send me a new link" for a copied link."""

    __tablename__ = "report_issues"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    share_link_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("share_links.id", ondelete="SET NULL"))
    kind: Mapped[str] = mapped_column(str_enum("problem", "new_link", name="report_issue_kind"))
    message: Mapped[str | None] = mapped_column(Text)
    contact: Mapped[str | None] = mapped_column(String(160))
    status: Mapped[str] = mapped_column(
        str_enum("open", "resolved", name="report_issue_status"), default="open"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
