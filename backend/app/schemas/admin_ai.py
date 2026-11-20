"""Admin panel: A20 AI usage and cost."""

import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

AiTask = Literal["report_draft", "transcription", "translation", "assistant"]


class AdminAiDay(BaseModel):
    day: date
    report_draft: float = Field(description="USD")
    transcription: float
    translation: float
    assistant: float


class AdminAiCompany(BaseModel):
    id: uuid.UUID
    name: str
    cost_usd: float


class AdminAiModel(BaseModel):
    task: AiTask
    model: str
    calls: int
    avg_cost_usd: float | None = Field(description="Per call; per minute of audio for transcription")
    per_minute: bool
    error_rate: float | None = Field(description="0–1, failed calls out of all calls")


class AdminAiUsageOut(BaseModel):
    days: int
    configured: bool = Field(description="False when no OpenAI key is set: nothing is sent to AI")
    total_cost_usd: float
    budget_usd: float | None = Field(description="Monthly AI budget; null when not set")
    cost_per_report_usd: float | None = Field(description="All AI cost divided by reports drafted")
    target_per_report_usd: float | None
    reports_drafted: int
    draft_success: float | None = Field(description="0–1, report drafts that worked")
    voice_minutes: float
    per_day: list[AdminAiDay]
    companies: list[AdminAiCompany] = Field(description="Most expensive first, up to 4")
    others_cost_usd: float = Field(description="Every other company, plus calls not tied to a company")
    others_count: int
    models: list[AdminAiModel]
