"""Users, companies, memberships, invitations, login challenges, sessions, devices.

A user can belong to several companies (D-11). The active company lives on the session
and is copied into each access token.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import INET, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, IdMixin, TimestampMixin

LOCALES = ("en", "hi", "gu", "es", "fr")
ROLES = ("owner", "manager", "technician")


def str_enum(*values: str, name: str) -> Enum:
    """Plain VARCHAR + CHECK constraint (easy to extend in migrations)."""
    return Enum(*values, name=name, native_enum=False, create_constraint=True, length=32)


class User(IdMixin, TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("phone IS NOT NULL OR email IS NOT NULL", name="phone_or_email"),)

    phone: Mapped[str | None] = mapped_column(String(20), unique=True)
    email: Mapped[str | None] = mapped_column(String(254), unique=True)
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    password_hash: Mapped[str | None] = mapped_column(String(255))
    name: Mapped[str | None] = mapped_column(String(120))
    avatar_key: Mapped[str | None] = mapped_column(String(255))
    # the person's own work ("Your work" on M11), separate from the company's trade
    trade: Mapped[str | None] = mapped_column(ForeignKey("industries.slug"))
    app_language: Mapped[str] = mapped_column(str_enum(*LOCALES, name="locale"), default="en")
    status: Mapped[str] = mapped_column(
        str_enum("invited", "active", "disabled", name="user_status"), default="active"
    )
    theme: Mapped[str] = mapped_column(
        str_enum("system", "light", "dark", name="theme"), default="system", server_default="system"
    )
    is_super_admin: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    memberships: Mapped[list["Membership"]] = relationship(
        back_populates="user", foreign_keys="Membership.user_id"
    )


class Company(IdMixin, TimestampMixin, Base):
    __tablename__ = "companies"

    name: Mapped[str] = mapped_column(String(120))
    industry_slug: Mapped[str | None] = mapped_column(ForeignKey("industries.slug"))
    country: Mapped[str] = mapped_column(String(2), default="IN")
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Kolkata")
    currency: Mapped[str] = mapped_column(String(3), default="INR")
    report_language: Mapped[str] = mapped_column(str_enum(*LOCALES, name="locale"), default="en")
    logo_key: Mapped[str | None] = mapped_column(String(255))
    plan_code: Mapped[str] = mapped_column(ForeignKey("plans.code"), default="professional")
    status: Mapped[str] = mapped_column(
        str_enum("trial", "active", "past_due", "suspended", "cancelled", name="company_status"),
        default="trial",
    )
    trial_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    settings: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=text("'{}'::jsonb"))
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))


class Membership(IdMixin, TimestampMixin, Base):
    __tablename__ = "memberships"
    __table_args__ = (UniqueConstraint("company_id", "user_id", name="uq_memberships_company_user"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(str_enum(*ROLES, name="role"))
    status: Mapped[str] = mapped_column(
        str_enum("invited", "active", "removed", name="membership_status"), default="active"
    )
    invited_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    joined_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    daily_job_capacity: Mapped[int] = mapped_column(Integer, default=6, server_default=text("6"))  # M17

    user: Mapped[User] = relationship(back_populates="memberships", foreign_keys=[user_id])
    company: Mapped[Company] = relationship()


class Invitation(IdMixin, TimestampMixin, Base):
    __tablename__ = "invitations"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    membership_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("memberships.id", ondelete="CASCADE"))
    phone: Mapped[str] = mapped_column(String(20), index=True)
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(str_enum(*ROLES, name="role"))
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    sms_language: Mapped[str] = mapped_column(
        str_enum(*LOCALES, name="locale"), default="en", server_default="en"
    )
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    declined_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    invited_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))


class OtpChallenge(IdMixin, TimestampMixin, Base):
    __tablename__ = "otp_challenges"

    phone: Mapped[str] = mapped_column(String(20), index=True)
    code_hash: Mapped[str] = mapped_column(String(64))
    purpose: Mapped[str] = mapped_column(
        str_enum("login", "verify_phone", name="otp_purpose"), default="login"
    )
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ip: Mapped[str | None] = mapped_column(INET)


class LoginAttempt(IdMixin, Base):
    """Email/password tries, for the 5-fails-then-15-minutes lockout (M06, A01)."""

    __tablename__ = "login_attempts"

    identifier: Mapped[str] = mapped_column(String(254), index=True)  # lower-cased email
    success: Mapped[bool] = mapped_column(Boolean)
    ip: Mapped[str | None] = mapped_column(INET)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))


class AuthSession(IdMixin, TimestampMixin, Base):
    __tablename__ = "sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    active_company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="SET NULL")
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(64))
    device_id: Mapped[str | None] = mapped_column(String(128))
    platform: Mapped[str | None] = mapped_column(String(16))
    app_version: Mapped[str | None] = mapped_column(String(32))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Device(IdMixin, TimestampMixin, Base):
    __tablename__ = "devices"
    __table_args__ = (UniqueConstraint("user_id", "push_token", name="uq_devices_user_token"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    push_token: Mapped[str] = mapped_column(String(512))
    platform: Mapped[str] = mapped_column(
        str_enum("android", "ios", "ipados", "macos", "web", name="platform")
    )
    app_version: Mapped[str | None] = mapped_column(String(32))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class CompanyCounter(Base):
    """Per-company human numbers: J-2231, R-1042, INV-3108."""

    __tablename__ = "company_counters"

    company_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), primary_key=True
    )
    key: Mapped[str] = mapped_column(String(16), primary_key=True)
    value: Mapped[int] = mapped_column(Integer, default=0)


class AuditLog(IdMixin, Base):
    """Append-only: who did what (A31)."""

    __tablename__ = "audit_logs"

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("companies.id", ondelete="SET NULL"), index=True
    )
    actor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    # set instead of actor_id when KaamNishaan staff did it in the admin panel
    staff_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("staff_users.id", ondelete="SET NULL"))
    actor_role: Mapped[str | None] = mapped_column(String(32))
    action: Mapped[str] = mapped_column(String(64))
    target_type: Mapped[str | None] = mapped_column(String(32))
    target_id: Mapped[str | None] = mapped_column(String(64))
    data: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=text("'{}'::jsonb"))
    ip: Mapped[str | None] = mapped_column(INET)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("now()"), index=True
    )  # A31 sorts and filters by time
