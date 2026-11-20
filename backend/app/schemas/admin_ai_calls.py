"""Admin panel: A38 AI review calls (settings, call script, call log)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.admin_companies import AdminOption

CallOutcome = Literal[
    "rated", "voicemail_sms", "call_back", "no_answer", "opted_out", "wrong_person", "skipped_dnd",
    "failed_sms", "no_provider_sms", "no_credits_sms", "not_sent",
]  # fmt: skip


class AdminVoiceProvider(BaseModel):
    connected: bool = Field(description="False until a voice provider is added (D-115)")
    name: str | None
    down_since: datetime | None = Field(description="The provider has been failing since then")
    waiting: int = Field(description="Calls due now and not placed yet")


class AdminAiCallKpis(BaseModel):
    calls: int = Field(description="Calls placed, last 30 days")
    answered: float | None = Field(description="0–1 of calls placed")
    rated: float | None = Field(description="0–1 of answered calls")
    opted_out: float | None = Field(description="0–1 of calls placed")
    cost_per_call_usd: float | None
    sms_instead: int = Field(description="Due calls that sent the rating link by SMS instead, last 30 days")


class AdminAiCallSettings(BaseModel):
    model_config = ConfigDict(extra="forbid")
    voice: Literal["warm", "bright", "formal"]
    language: Literal["report", "en"]
    hours: Literal["10-19", "9-20", "11-18"]
    attempts: Literal["call_voicemail", "two_calls", "call_only"]
    record: bool
    skip_dnd: bool = Field(True, description="Always on")
    only_if_no_rating: bool = Field(True, description="Always on")


class AdminScriptStep(BaseModel):
    key: str
    text: str


class AdminCallScript(BaseModel):
    version: int
    opening: str = Field(description="Said first on every call; can't be changed")
    steps: list[AdminScriptStep]


class AdminScriptStepIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    text: str = Field(min_length=10, max_length=600)


class AdminAiCallRow(BaseModel):
    id: uuid.UUID
    at: datetime
    company: AdminOption
    contact_name: str | None
    place: str | None
    language: str | None
    seconds: int
    outcome: CallOutcome
    rating: int | None
    wants_call_back: bool
    callback_at: datetime | None
    cost_usd: float


class AdminAiCallsOut(BaseModel):
    provider: AdminVoiceProvider
    kpis: AdminAiCallKpis
    settings: AdminAiCallSettings
    script: AdminCallScript
    calls: list[AdminAiCallRow]
    total: int
    page: int
    page_size: int
    can_act: bool


class AdminTestCall(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    phone: str = Field(min_length=8, max_length=20)


class AdminTestCallOut(BaseModel):
    outcome: str
    seconds: int
