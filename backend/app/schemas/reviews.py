"""Customer reviews: the review card on a job (M15), asking (M31), My reviews (M44) and the rating on the
customer's report page (W29)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.reviews import NEGATIVE_TAGS, POSITIVE_TAGS
from app.schemas.work import PersonRef

RequestStatus = Literal[
    "not_requested",
    "queued",
    "link_sent",
    "reminded",
    "ai_call_scheduled",
    "ai_call_done",
    "rated",
    "opted_out",
    "stopped",
    "paused_no_credits",
]


class ReviewBrief(BaseModel):
    id: uuid.UUID
    rating: int = Field(description="The service, 1-5")
    technician_rating: int | None = Field(description="The technician, 1-5")
    comment: str | None
    source: Literal["link", "reply", "ai_call"]
    created_at: datetime


class JobReview(BaseModel):
    """The "Customer review" card on a job (M15)."""

    status: RequestStatus
    request_id: uuid.UUID | None = None
    can_request: bool = Field(description="Request review shows (not asked yet, and allowed)")
    blocked_reason: Literal["no_report", "no_contact", "not_allowed", "not_assigned"] | None = None
    can_cancel: bool = False
    requested_by: PersonRef | None = None
    requested_by_me: bool = False
    contact_name: str | None = None
    contact_phone: str | None = None
    sent_at: datetime | None = None
    channels: list[str] = Field(default_factory=list, description="How the link went: sms, whatsapp, email")
    reminder_at: datetime | None = Field(default=None, description="Day 2 reminder (planned or done)")
    ai_call_at: datetime | None = Field(default=None, description="Day 5 AI call, if still no rating")
    ai_call_enabled: bool = True
    opted_out_at: datetime | None = None
    opt_out_source: str | None = None
    review: ReviewBrief | None = None


class ReplyOut(BaseModel):
    author: PersonRef | None
    text: str
    created_at: datetime


class ReviewListItem(BaseModel):
    id: uuid.UUID
    rating: int
    technician_rating: int | None
    comment: str | None
    reviewer_name: str | None
    source: Literal["link", "reply", "ai_call"]
    customer: str
    job_title: str
    cover_url: str | None
    created_at: datetime
    reply: ReplyOut | None


class TagCount(BaseModel):
    key: str
    count: int


class MyReviews(BaseModel):
    """M44: the technician's own reviews this year, newest first."""

    average: float | None = Field(
        description="Average stars for the technician (or the service when not given)"
    )
    count: int
    share_4_plus: int = Field(description="Percent of reviews with 4 stars or more")
    tags: list[TagCount] = Field(description="Good tags, most given first")
    data: list[ReviewListItem]


class ReviewOut(ReviewListItem):
    """M44 review details."""

    tags: list[str]
    job_id: uuid.UUID
    report_number: str | None
    technician: PersonRef | None
    before_url: str | None
    after_url: str | None
    public_allowed: bool
    wants_call_back: bool


# ---- the customer's report page (W29) ----------------------------------------------------------------------
class PublicReviewState(BaseModel):
    can_rate: bool
    rated: bool
    rating: int | None = None
    technician: str | None = Field(default=None, description="The technician's first name, for 'Rate Ramesh'")
    positive_tags: list[str] = Field(default_factory=lambda: list(POSITIVE_TAGS))
    negative_tags: list[str] = Field(default_factory=lambda: list(NEGATIVE_TAGS))


class ReviewIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    rating: int = Field(ge=1, le=5, description="The service")
    technician_rating: int | None = Field(default=None, ge=1, le=5)
    tags: list[str] = Field(default_factory=list, max_length=10)
    comment: str | None = Field(default=None, max_length=1000)
    name: str | None = Field(default=None, max_length=160)
    public_allowed: bool = False
    wants_call_back: bool = False

    @field_validator("tags")
    @classmethod
    def _known(cls, v: list[str]) -> list[str]:
        known = set(POSITIVE_TAGS) | set(NEGATIVE_TAGS)
        bad = [t for t in v if t not in known]
        if bad:
            raise ValueError(f"unknown tags: {', '.join(bad)}")
        return list(dict.fromkeys(v))


class RatedOut(BaseModel):
    review_id: uuid.UUID
    google_review_url: str | None = Field(description="Shown after 4-5 stars, when the company set one")
