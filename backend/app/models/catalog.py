"""Platform catalog: industries, plans, credit packs. Read by website, apps and admin."""

from sqlalchemy import Boolean, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin


class Industry(TimestampMixin, Base):
    __tablename__ = "industries"

    slug: Mapped[str] = mapped_column(String(48), primary_key=True)
    name: Mapped[dict] = mapped_column(JSONB)  # {"en": "HVAC", "hi": "..."}
    status: Mapped[str] = mapped_column(String(16), default="live")
    sort: Mapped[int] = mapped_column(Integer, default=0)


class Plan(TimestampMixin, Base):
    __tablename__ = "plans"

    code: Mapped[str] = mapped_column(String(24), primary_key=True)
    name: Mapped[dict] = mapped_column(JSONB)
    # monthly price in minor units per currency, e.g. {"INR": 49900, "USD": 900}; {} = contact us
    prices: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=text("'{}'::jsonb"))
    technician_limit: Mapped[int | None] = mapped_column(Integer)
    report_limit_monthly: Mapped[int | None] = mapped_column(Integer)  # None = fair use
    monthly_credits: Mapped[int | None] = mapped_column(Integer)
    ai_questions_monthly: Mapped[int | None] = mapped_column(Integer)
    most_popular: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    features: Mapped[dict] = mapped_column(JSONB, default=dict, server_default=text("'{}'::jsonb"))
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    sort: Mapped[int] = mapped_column(Integer, default=0)


class CreditPack(IdMixin, TimestampMixin, Base):
    __tablename__ = "credit_packs"

    credits: Mapped[int] = mapped_column(Integer)
    prices: Mapped[dict] = mapped_column(JSONB)
    active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    plan_code: Mapped[str | None] = mapped_column(ForeignKey("plans.code"))  # None = available on all plans
    sort: Mapped[int] = mapped_column(Integer, default=0)
