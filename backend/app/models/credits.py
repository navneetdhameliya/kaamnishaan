"""Follow-up credits: each company gets its plan's credits every month (unused ones don't carry over)
plus any bought top-ups (these stay until used). Reminders by SMS or WhatsApp and AI review calls use
credits; email is free."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin


class CreditWallet(TimestampMixin, Base):
    __tablename__ = "credit_wallets"

    company_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), primary_key=True
    )
    period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    plan_credits: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))  # this month's
    plan_used: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    topup_credits: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))  # left


class CreditEntry(IdMixin, Base):
    """Every credit that comes in (monthly grant, top-up) or goes out (a reminder, an AI call)."""

    __tablename__ = "credit_entries"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(16))  # grant, topup, reminder, ai_call
    channel: Mapped[str | None] = mapped_column(String(16))  # sms, whatsapp, call
    credits: Mapped[int] = mapped_column(Integer)  # + in, - out
    review_request_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("review_requests.id", ondelete="SET NULL")
    )
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"), index=True)
