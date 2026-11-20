"""A24 Website content, A25 Localized content, and the live text changes the clients fetch."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Area = Literal["app", "site", "admin"]
TextLang = Literal["en", "hi", "gu", "es", "fr"]


class PublicTextsOut(BaseModel):
    texts: dict[str, dict[str, str]] = Field(
        description="language -> key -> text; only texts changed by staff"
    )
    preview: bool = Field(False, description="True when unpublished website changes are included")


class FieldValue(BaseModel):
    live: str | None = Field(description="What people see now; null = the built-in text")
    draft: str | None = Field(description="Saved, not published; null with has_draft = back to built-in")
    has_draft: bool


class AdminPageField(BaseModel):
    key: str
    label: str = Field(description="eyebrow, headline, subheadline, primary_button, question, seo_title, …")
    n: int | None = Field(None, description="Question number for FAQ fields")
    max: int
    multiline: bool
    values: dict[str, FieldValue]


class AdminPageSection(BaseModel):
    key: str = Field(description="hero, problem, how, faq, final, why, seo")
    fields: list[AdminPageField]


class AdminPageOut(BaseModel):
    page: str
    path: str
    trade: str | None = None
    sections: list[AdminPageSection]
    drafts: int
    edited_at: datetime | None
    edited_by: str | None


class AdminPageRow(BaseModel):
    page: str
    path: str
    trade: str | None = None
    drafts: int = Field(description="Texts changed but not published")
    changed: int = Field(description="Live texts that differ from the built-in ones")
    edited_at: datetime | None


class AdminPagesOut(BaseModel):
    pages: list[AdminPageRow]
    can_act: bool
    web_url: str


class AdminPageSave(BaseModel):
    model_config = ConfigDict(extra="forbid")
    values: dict[str, dict[TextLang, str | None]] = Field(
        description="key -> language -> text; empty or null = back to the built-in text"
    )


class AdminPreviewIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    lang: TextLang = "en"


class AdminPreviewOut(BaseModel):
    url: str = Field(description="The website page with unpublished changes; the link works for 1 hour")


class AdminTextRow(BaseModel):
    key: str
    lang: str
    value: str | None = Field(description="Live change; null = built-in text")
    draft: str | None = None
    has_draft: bool = False
    reviewed_at: datetime | None
    reviewed_by: str | None
    updated_at: datetime


class AdminTextsOut(BaseModel):
    rows: list[AdminTextRow] = Field(description="Only texts that were changed or reviewed")
    can_act: bool


class AdminTextChange(BaseModel):
    model_config = ConfigDict(extra="forbid")
    key: str = Field(max_length=160)
    lang: TextLang
    set_value: bool = Field(False, description="True to change the text (value null/empty = built-in)")
    value: str | None = Field(None, max_length=2000)
    reviewed: bool | None = Field(None, description="Mark (or unmark) that a person checked this text")


class AdminTextsIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    changes: list[AdminTextChange] = Field(min_length=1, max_length=2000)
