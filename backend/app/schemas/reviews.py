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
    # D-149 "Edit your review": for 7 days, until the company replies; the customer's answers to start from
    can_edit: bool = False
    technician_rating: int | None = None
    tags: list[str] = Field(default_factory=list)
    comment: str | None = None
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


# ---- the office: customer reviews (M45) ------------------------------------------------------------
class FollowupOut(BaseModel):
    status: Literal["open", "contacted", "resolved"]
    private_note: str | None
    resolved_at: datetime | None


class CompanyReviewItem(ReviewListItem):
    job_id: uuid.UUID
    customer_id: uuid.UUID
    report_number: str | None
    contact_phone: str | None = Field(description="For M45 'Call now'")
    tags: list[str]
    technician: PersonRef | None
    wants_call_back: bool
    low: bool = Field(description="At or under the company's low-rating line (2 stars by default)")
    needs_reply: bool
    followup: FollowupOut | None


class ReviewCounts(BaseModel):
    all: int
    needs_reply: int
    low: int


class ReviewsPage(BaseModel):
    average: float | None
    count: int
    breakdown: list[int] = Field(description="How many 1, 2, 3, 4 and 5 star reviews (index 0 is 1 star)")
    counts: ReviewCounts
    data: list[CompanyReviewItem]


class ReplyIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    text: str = Field(min_length=1, max_length=1000)


class SuggestionOut(BaseModel):
    text: str


class FollowupIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    status: Literal["open", "contacted", "resolved"] | None = None
    private_note: str | None = Field(default=None, max_length=2000)


# ---- review requests (M45) ----------------------------------------------------------------------
class RequestItem(BaseModel):
    id: uuid.UUID
    job_id: uuid.UUID
    customer: str
    cover_url: str | None
    technician: PersonRef | None
    status: RequestStatus
    sent_at: datetime | None
    next_step: Literal["reminder", "ai_call"] | None = Field(
        description="What happens next, if nothing changes"
    )
    next_at: datetime | None
    rating: int | None
    source: Literal["link", "reply", "ai_call"] | None


class RequestCounts(BaseModel):
    waiting: int
    rated: int
    opted_out: int


class RequestsPage(BaseModel):
    counts: RequestCounts
    data: list[RequestItem]


# ---- settings (M46) -----------------------------------------------------------------------------------
Channel = Literal["sms", "whatsapp", "email"]


class ReviewSettingsOut(BaseModel):
    ask_on_share: bool
    reminder_enabled: bool
    reminder_day: int
    reminder_channels: list[Channel]
    ai_call_enabled: bool
    ai_call_day: int
    call_window: str = Field(description="When AI calls may happen, local time")
    low_rating_alert: bool
    low_rating_threshold: int
    techs_can_request: bool
    techs_see_reviews: bool
    show_public_reviews: bool
    google_review_url: str | None
    can_edit: bool


class ReviewSettingsIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    ask_on_share: bool | None = None
    reminder_enabled: bool | None = None
    reminder_channels: list[Channel] | None = Field(default=None, min_length=1)
    ai_call_enabled: bool | None = None
    low_rating_alert: bool | None = None
    techs_can_request: bool | None = None
    techs_see_reviews: bool | None = None
    show_public_reviews: bool | None = None
    google_review_url: str | None = Field(default=None, max_length=500)

    @field_validator("google_review_url")
    @classmethod
    def _url(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return v
        if " " in v or "." not in v:
            raise ValueError("not a web address")
        return v if v.startswith(("http://", "https://")) else f"https://{v}"
