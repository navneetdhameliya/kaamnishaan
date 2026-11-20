"""Admin panel: A37 Reviews and ratings (every company's customer reviews, and the review rules)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.admin_companies import AdminOption

ReviewState = Literal["published", "flagged", "hidden"]
FlagReason = Literal["personal_data", "abuse", "spam"]
ReviewStatusFilter = Literal["flagged", "published", "hidden", "followup", "replied"]


class AdminReviewRow(BaseModel):
    id: uuid.UUID
    comment: str | None = Field(description="As shown, with phone numbers and emails hidden")
    reviewer_name: str | None
    job_title: str
    company: AdminOption
    technician: str | None
    rating: int
    status: ReviewState
    flag_reason: FlagReason | None
    followup: Literal["open", "resolved"] | None = Field(description="The company's manager is following up")
    replied: bool
    created_at: datetime


class AdminReviewKpis(BaseModel):
    average_rating: float | None = Field(description="Last 30 days, all companies (hidden ones left out)")
    reviews_30d: int
    share_rate: float | None = Field(description="0–1, reviews ÷ reports shared in the last 30 days")
    low_30d: int = Field(description="2 stars or less")
    low_rate: float | None
    flagged: int = Field(description="Waiting for KaamNishaan to check, any age")


class AdminReviewList(BaseModel):
    items: list[AdminReviewRow]
    total: int
    page: int
    page_size: int
    kpis: AdminReviewKpis
    companies: list[AdminOption] = Field(description="Companies with reviews, for the filter")


class AdminReviewReply(BaseModel):
    text: str
    by: str | None
    at: datetime


class AdminReviewDetail(AdminReviewRow):
    comment_original: str | None = Field(description="Before contact details were hidden (staff only)")
    technician_rating: int | None
    tags: list[str]
    source: Literal["link", "reply", "ai_call"]
    job_number: str
    reply: AdminReviewReply | None
    moderated_by: str | None
    moderated_at: datetime | None
    moderation_note: str | None
    can_act: bool = Field(description="False for support staff")


class AdminReviewHide(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    reason: str = Field(min_length=3, max_length=300)


class AdminReviewRules(BaseModel):
    model_config = ConfigDict(extra="forbid")
    hide_contact: bool
    flag_abuse: bool
    block_repeats: bool
