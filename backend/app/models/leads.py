"""Website leads before anyone has an account: W03 demos, W05 contact messages, W25 newsletter emails."""

from datetime import datetime

from sqlalchemy import DateTime, Identity, Integer, String, Text
from sqlalchemy import text as sql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin


class Lead(IdMixin, TimestampMixin, Base):
    __tablename__ = "leads"

    # shown to the person as "KN-20418"
    number: Mapped[int] = mapped_column(Integer, Identity(start=20001), unique=True)
    kind: Mapped[str] = mapped_column(String(16), index=True)  # demo, contact, newsletter
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(254), index=True)
    phone: Mapped[str | None] = mapped_column(String(20))
    company: Mapped[str | None] = mapped_column(String(120))
    team_size: Mapped[str | None] = mapped_column(String(16))
    trade: Mapped[str | None] = mapped_column(String(48))
    topic: Mapped[str | None] = mapped_column(String(24))
    message: Mapped[str | None] = mapped_column(Text)
    # the demo's start (one booking per time)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    lang: Mapped[str] = mapped_column(String(5), default="en", server_default="en")
    ip: Mapped[str | None] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16), default="new", server_default=sql("'new'"))  # new, done
