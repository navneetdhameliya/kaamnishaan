"""KaamNishaan's own staff for the admin panel (A01–A36). Separate from app users: a staff account
never belongs to a company, and always logs in with a password plus an authenticator code (D-08)."""

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum

STAFF_ROLES = ("super_admin", "admin", "support")


class StaffUser(IdMixin, TimestampMixin, Base):
    __tablename__ = "staff_users"

    email: Mapped[str] = mapped_column(String(254), unique=True)  # stored lower-case
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(str_enum(*STAFF_ROLES, name="staff_role"), default="admin")
    # invited: has a setup link and has not chosen a password yet (also after a reset)
    status: Mapped[str] = mapped_column(
        str_enum("invited", "active", "disabled", name="staff_status"), default="invited"
    )
    password_hash: Mapped[str | None] = mapped_column(String(255))
    totp_secret: Mapped[str | None] = mapped_column(String(255))  # encrypted with the server key
    totp_last_step: Mapped[int | None] = mapped_column(BigInteger)  # a code works only once
    recovery_codes: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))
    # goes up with every new setup link, so older links stop working
    setup_version: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    lang: Mapped[str] = mapped_column(String(2), default="en", server_default="en")  # A36 panel language


class StaffSession(IdMixin, TimestampMixin, Base):
    __tablename__ = "staff_sessions"

    staff_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("staff_users.id", ondelete="CASCADE"), index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))  # never extended
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ip: Mapped[str | None] = mapped_column(String(64))
    user_agent: Mapped[str | None] = mapped_column(String(255))
