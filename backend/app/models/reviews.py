"""Customer reviews (M15 review states, M31 ask for review, M44, M45, W29).

A technician or manager asks for a review on a job. The rating link goes to the customer with the approved
report (Day 0); reminders (Day 2) and one AI call (Day 5) are planned on the request and run with the
follow-up worker. The customer rates on the report page: one rating for the service, one for the
technician, quick tags and words.

Review request: queued -> link_sent -> reminded -> ai_call_scheduled -> ai_call_done -> rated
| opted_out | stopped | paused_no_credits. Cancelling a queued request removes it (back to "not asked").
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin

REQUEST_STATUSES = (
    "queued",
    "link_sent",
    "reminded",
    "ai_call_scheduled",
    "ai_call_done",
    "rated",
    "opted_out",
    "stopped",
    "paused_no_credits",
)

# Quick tags the customer can tick on the rating page; the apps write them in each language.
POSITIVE_TAGS = ("on_time", "clean_work", "explained_clearly", "polite", "fixed_first_time")
NEGATIVE_TAGS = ("late", "messy", "not_fixed", "not_explained", "rude")


class ReviewSettings(TimestampMixin, Base):
    """One row per company (M46). A company without a row uses these defaults."""

    __tablename__ = "review_settings"

    company_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), primary_key=True
    )
    ask_on_share: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    reminder_enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    reminder_channels: Mapped[list] = mapped_column(
        JSONB, default=lambda: ["sms", "email"], server_default=sql('\'["sms", "email"]\'::jsonb')
    )
    low_rating_alert: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    show_public_reviews: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    reminder_day: Mapped[int] = mapped_column(SmallInteger, default=2, server_default=sql("2"))
    ai_call_enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    ai_call_day: Mapped[int] = mapped_column(SmallInteger, default=5, server_default=sql("5"))
    techs_can_request: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    techs_see_reviews: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sql("true"))
    low_rating_threshold: Mapped[int] = mapped_column(SmallInteger, default=2, server_default=sql("2"))
    google_review_url: Mapped[str | None] = mapped_column(String(500))


class ReviewRequest(IdMixin, TimestampMixin, Base):
    __tablename__ = "review_requests"
    __table_args__ = (UniqueConstraint("job_id", name="uq_review_requests_job"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"))
    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    contact_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("customer_contacts.id", ondelete="SET NULL")
    )
    requested_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    status: Mapped[str] = mapped_column(String(24), default="queued")
    share_link_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("share_links.id", ondelete="SET NULL"))
    channels: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reminder_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ai_call_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    opted_out_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    opt_out_source: Mapped[str | None] = mapped_column(String(16))  # link, stop_reply, call
    stopped_reason: Mapped[str | None] = mapped_column(String(40))


class ReviewRequestEvent(IdMixin, Base):
    __tablename__ = "review_request_events"

    request_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("review_requests.id", ondelete="CASCADE"), index=True
    )
    step: Mapped[str] = mapped_column(String(24))  # requested, link_sent, reminder, ai_call, rated, opted_out
    channel: Mapped[str | None] = mapped_column(String(16))
    status: Mapped[str] = mapped_column(String(16), default="done")
    credits_used: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))


class Review(IdMixin, TimestampMixin, Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("request_id", name="uq_reviews_request"),)

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    request_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("review_requests.id", ondelete="CASCADE"))
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    technician_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    rating: Mapped[int] = mapped_column(SmallInteger)  # the service, 1-5
    technician_rating: Mapped[int | None] = mapped_column(SmallInteger)  # the technician, 1-5
    tags: Mapped[list] = mapped_column(JSONB, default=list, server_default=sql("'[]'::jsonb"))
    comment: Mapped[str | None] = mapped_column(Text)
    reviewer_name: Mapped[str | None] = mapped_column(String(160))
    source: Mapped[str] = mapped_column(String(16), default="link")  # link, reply, ai_call
    public_allowed: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    wants_call_back: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    status: Mapped[str] = mapped_column(String(16), default="published")  # published, flagged, hidden
    # A37 moderation: why it was held (personal_data, abuse, spam), the customer's words before phone
    # numbers and emails were hidden (staff only), and who decided
    flag_reason: Mapped[str | None] = mapped_column(String(16))
    comment_original: Mapped[str | None] = mapped_column(Text)
    moderated_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("staff_users.id", ondelete="SET NULL"))
    moderated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    moderation_note: Mapped[str | None] = mapped_column(String(300))


class ReviewReply(IdMixin, TimestampMixin, Base):
    __tablename__ = "review_replies"

    review_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    author_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    text: Mapped[str] = mapped_column(Text)
    ai_suggested: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))


class ReviewFollowup(TimestampMixin, Base):
    """Low-rating follow-up (M45): open -> contacted -> resolved, with a private note for the team."""

    __tablename__ = "review_followups"

    review_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reviews.id", ondelete="CASCADE"), primary_key=True
    )
    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(16), default="open")
    private_note: Mapped[str | None] = mapped_column(Text)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))


class AiCall(IdMixin, Base):
    """One Day 5 AI review call (A38 call log), or what happened instead of it.

    Outcomes: rated, voicemail_sms, call_back, no_answer, opted_out, wrong_person, skipped_dnd,
    failed_sms (the provider failed, the link went by SMS), no_provider_sms (no voice provider is
    connected, the link went by SMS), not_sent (nothing could go: no credits or no phone).
    """

    __tablename__ = "ai_calls"

    company_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"), index=True)
    request_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("review_requests.id", ondelete="CASCADE"), index=True
    )
    contact_name: Mapped[str | None] = mapped_column(String(160))
    place: Mapped[str | None] = mapped_column(String(160))  # the customer or site, shown under the name
    phone: Mapped[str | None] = mapped_column(String(20))
    language: Mapped[str | None] = mapped_column(String(8))  # the language spoken on the call
    outcome: Mapped[str] = mapped_column(String(24))
    rating: Mapped[int | None] = mapped_column(SmallInteger)
    wants_call_back: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    callback_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    seconds: Mapped[int] = mapped_column(Integer, default=0, server_default=sql("0"))
    cost_usd: Mapped[float] = mapped_column(Float, default=0, server_default=sql("0"))
    provider: Mapped[str | None] = mapped_column(String(24))
    provider_call_id: Mapped[str | None] = mapped_column(String(80))
    transcript: Mapped[str | None] = mapped_column(Text)
    script_version: Mapped[int | None] = mapped_column(Integer)
    error: Mapped[str | None] = mapped_column(String(300))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"), index=True)
