"""Admin panel: A19 AI configuration, A21 Prompt management, A22 Industries."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services.platform import AiConfig


# ---- A19 --------------------------------------------------------------------------------------------
class AdminAiConfigOut(BaseModel):
    config: AiConfig
    text_models: list[str]
    transcribe_models: list[str]
    key_set: bool = Field(description="The AI key is set on the server")
    month_spend_usd: float
    can_act: bool


# ---- A21 --------------------------------------------------------------------------------------------
PromptTask = Literal["report_draft", "assistant", "translation"]


class AdminPromptVersion(BaseModel):
    version: int
    status: Literal["draft", "live", "retired"]
    system_prompt: str
    note: str | None
    edited_by: str | None
    published_by: str | None
    published_at: datetime | None
    created_at: datetime
    updated_at: datetime
    reports: int | None = Field(None, description="report_draft: reports written with this version")
    flagged: int | None = Field(None, description="report_draft: of those, with invented-work flags")


class AdminPromptStats(BaseModel):
    runs: int = Field(description="Calls in the last 30 days")
    failed: int
    avg_tokens: int
    avg_cost_usd: float


class AdminPrompt(BaseModel):
    task: PromptTask
    live: int | None
    draft: int | None
    variables: list[str]
    versions: list[AdminPromptVersion] = Field(description="Newest first")
    stats: AdminPromptStats


class AdminPromptsOut(BaseModel):
    prompts: list[AdminPrompt]
    can_act: bool


class AdminPromptDraftIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    system_prompt: str = Field(min_length=40, max_length=12000)
    note: str | None = Field(None, max_length=200)

    @field_validator("system_prompt")
    @classmethod
    def _language(cls, v: str) -> str:
        if "{language}" not in v:
            raise ValueError("Keep {language} in the prompt")
        return v.strip()


# ---- A22 --------------------------------------------------------------------------------------------
class AdminIndustry(BaseModel):
    slug: str
    name: dict[str, str]
    status: Literal["live", "draft"]
    sort: int
    companies: int
    checklists: int = Field(description="Ready-made checklists for this trade")
    default_checklist: str | None
    default_questions: int | None


class AdminIndustriesOut(BaseModel):
    items: list[AdminIndustry]
    can_act: bool


class AdminIndustryIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    slug: str | None = Field(
        None, pattern=r"^[a-z][a-z0-9-]{1,46}[a-z0-9]$", description="New industries only"
    )
    name: dict[Literal["en", "hi", "gu", "es", "fr"], str]
    status: Literal["live", "draft"]
    sort: int = Field(ge=0, le=999)

    @field_validator("name")
    @classmethod
    def _names(cls, v: dict) -> dict:
        if not (v.get("en") or "").strip():
            raise ValueError("An English name is needed")
        if any(len(x) > 48 for x in v.values()):
            raise ValueError("Names are 48 characters at most")
        return {k: x.strip() for k, x in v.items() if x and x.strip()}
