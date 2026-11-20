"""Admin panel: A39 Message templates."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Channel = Literal["sms", "whatsapp", "email"]
Lang = Literal["en", "hi", "gu", "es", "fr"]
TemplateKey = Literal["report_review", "review_reminder", "day5_sms", "report_link"]


class AdminTemplateText(BaseModel):
    channel: Channel
    language: Lang
    text: str | None = Field(description="SMS and WhatsApp, without the STOP line (added on send)")
    subject: str | None = Field(description="Email")
    body: str | None = Field(description="Email")
    edited: bool = Field(description="Changed by KaamNishaan staff (else the built-in text)")
    checked: bool = Field(description="Checked by a person; other languages start as 'needs review'")


class AdminTemplate(BaseModel):
    key: TemplateKey
    channels: list[Channel]
    placeholders: list[str]
    sample: dict[str, str] = Field(description="Values for the preview; the link is as long as a real one")
    email_only: list[str] = Field(description="Placeholders that only work in emails")
    texts: list[AdminTemplateText]


class AdminTemplatesOut(BaseModel):
    templates: list[AdminTemplate]
    stop: dict[str, str] = Field(description="The STOP line added to SMS and WhatsApp, per language")
    sms_live: bool = Field(description="False while SMS is console-only (not really sent)")
    whatsapp_live: bool
    email_live: bool
    can_act: bool


class AdminTemplateIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text: str | None = Field(None, max_length=2000)
    subject: str | None = Field(None, max_length=2000)
    body: str | None = Field(None, max_length=5000)


class AdminTemplateTest(AdminTemplateIn):
    template: TemplateKey
    channel: Channel
    language: Lang
    to: str = Field(min_length=5, max_length=200, description="A phone number, or an email for email")


class AdminTemplateTestOut(BaseModel):
    sent: bool = Field(description="False when the channel isn't connected yet; nothing really went out")
    to: str
    text: str | None
    subject: str | None
    body: str | None
