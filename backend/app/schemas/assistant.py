"""M36 Ask KaamNishaan AI."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class AskIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    text: str = Field(min_length=1, max_length=500)


class SourceReport(BaseModel):
    id: uuid.UUID
    number: str
    job_id: uuid.UUID
    customer: str
    status: str
    at: datetime
    cover_url: str | None


class SourceJob(BaseModel):
    id: uuid.UUID
    title: str
    customer: str
    status: str
    photos: list[str] = Field(description="Up to 3 thumbnails")
    missing: list[Literal["before", "during", "after", "checklists", "voice"]] = Field(
        description="Proof steps not done yet (open jobs only)"
    )


class AssistantMessageOut(BaseModel):
    id: uuid.UUID
    role: Literal["user", "assistant"]
    text: str
    at: datetime
    reports: list[SourceReport] = []
    jobs: list[SourceJob] = []
    photo_count: int = Field(0, description="Photos on the jobs the answer used")


class AssistantOut(BaseModel):
    data: list[AssistantMessageOut]
    used: int = Field(description="Questions asked by the company this month")
    limit: int | None = Field(description="null = no limit")
    paused: bool = Field(description="This month's questions are used up")
    renews_at: datetime
    available: bool = Field(description="false while the AI service isn't set up")


class AskOut(BaseModel):
    question: AssistantMessageOut
    answer: AssistantMessageOut
    used: int
    limit: int | None
    paused: bool
