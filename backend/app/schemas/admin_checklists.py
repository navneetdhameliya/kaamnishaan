"""Admin panel A23 Checklist templates: KaamNishaan's own (global) checklists, in all 5 languages."""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from app.schemas.admin_companies import AdminOption
from app.schemas.identity import Locale, _In

LangState = Literal["ready", "review", "missing"]


class AdminChecklistRow(BaseModel):
    id: uuid.UUID
    name: str
    trade: str | None
    trade_name: str | None
    status: Literal["draft", "published", "archived"]
    question_count: int
    photo_questions: int
    languages: dict[str, LangState] = Field(
        description="Per language: ready, review (machine translated, not checked yet) or missing"
    )
    used_by: int = Field(description="Companies that used it on a job or copied it")
    updated_at: datetime


class AdminChecklistCounts(BaseModel):
    all: int
    needs_translation: int
    drafts: int


class AdminChecklistList(BaseModel):
    items: list[AdminChecklistRow]
    total: int
    counts: AdminChecklistCounts
    trades: list[AdminOption]


class AdminChecklistOption(BaseModel):
    key: str
    label: dict[str, str]


class AdminChecklistQuestion(BaseModel):
    id: uuid.UUID
    position: int
    type: str
    text: dict[str, str]
    help: dict[str, str]
    text_status: dict[str, str]
    options: list[AdminChecklistOption]
    unit: str | None
    min_value: float | None
    max_value: float | None
    photo_rule: str
    required: bool
    condition: dict[str, Any] | None
    reference_image_url: str | None = Field(
        None, description="The photo showing what a good answer looks like"
    )


class AdminChecklistDetail(BaseModel):
    id: uuid.UUID
    key: str | None
    name: dict[str, str]
    source_language: str
    trade: str | None
    trade_name: str | None
    minutes: int | None
    status: Literal["draft", "published", "archived"]
    version: int
    used_by: int
    updated_at: datetime
    languages: dict[str, LangState]
    questions: list[AdminChecklistQuestion]
    ai_available: bool = Field(description="False when no AI key is set: translations can only be typed")
    trades: list[AdminOption]


class AdminChecklistCreate(_In):
    name: str = Field(min_length=1, max_length=120, description="In English (the source language)")
    trade: str
    minutes: int | None = Field(default=None, ge=1, le=240)


class AdminChecklistPatch(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    names: dict[Locale, str] | None = Field(default=None, description="The name in other languages")
    trade: str | None = None
    minutes: int | None = Field(default=None, ge=1, le=240)
    status: Literal["draft", "published", "archived"] | None = None


class AdminChecklistApprove(_In):
    language: Locale


class AdminTranslateOut(BaseModel):
    queued: int = Field(description="Questions sent for machine translation")
    ai_available: bool
