"""PDF (M34), sharing (M35) and the customer report page (W27)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

Channel = Literal["sms", "whatsapp", "email"]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class PdfOut(BaseModel):
    status: Literal["building", "ready", "failed"]
    url: str | None = Field(description="Signed download link, valid 15 minutes")
    filename: str
    pages: int | None
    size: int | None
    sha256: str | None = Field(description="Fingerprint of the file, to check a forwarded copy")
    built_at: datetime | None
    error: str | None


class ShareLinkOut(BaseModel):
    id: uuid.UUID
    url: str
    channel: Literal["sms", "whatsapp", "email", "copy"]
    status: Literal["active", "expired", "revoked"]
    expires_at: datetime
    open_count: int
    first_opened_at: datetime | None
    last_opened_at: datetime | None
    created_at: datetime


class Recipient(BaseModel):
    name: str | None
    phone: str | None
    email: str | None


class ChannelOut(BaseModel):
    key: Channel
    available: bool
    to: str | None
    reason: Literal["no_phone", "no_email"] | None


class Preview(BaseModel):
    language: str
    sms: str
    whatsapp: str
    email_subject: str
    email_body: str


class MessageOut(BaseModel):
    id: uuid.UUID
    channel: Channel
    to: str
    status: str
    error: str | None
    created_at: datetime


class ShareInfo(BaseModel):
    report_id: uuid.UUID
    report_status: str
    can_share: bool
    blocked_by: Literal["not_approved"] | None
    recipient: Recipient | None
    channels: list[ChannelOut]
    link: ShareLinkOut | None
    preview: Preview | None
    sent: list[MessageOut]


class ShareLinkIn(_In):
    channel: Literal["sms", "whatsapp", "email", "copy"] = "copy"


class SendIn(_In):
    channels: list[Channel] = Field(min_length=1, max_length=3)
    name: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(
        default=None, max_length=20, description="Defaults to the customer's main contact"
    )
    email: EmailStr | None = None


# ---- customer report page (no login; the token in the link is the key) --------------------------
class PublicPhoto(BaseModel):
    id: uuid.UUID
    stage: str
    url: str
    thumb_url: str | None
    taken_at: datetime


class PublicPair(BaseModel):
    subject: str | None
    before: PublicPhoto
    after: PublicPhoto


class PublicItem(BaseModel):
    question: str
    answer: str
    passed: bool | None


class PublicChecklist(BaseModel):
    name: str
    items: list[PublicItem]


class PublicCompany(BaseModel):
    name: str
    logo_url: str | None


class Acknowledgement(BaseModel):
    at: datetime
    name: str
    organisation: str | None


class PublicReport(BaseModel):
    number: str
    job_number: str
    title: str
    customer: str
    address: str | None
    technician: str | None
    approved_by: str | None
    approved_at: datetime | None
    completed_at: datetime | None
    company: PublicCompany
    language: str = Field(description="Language the report text was written in")
    lang: str = Field(description="Language used for checklist questions on this page")
    languages: list[str]
    summary: str | None
    work_done: list[str]
    advice: list[str]
    pairs: list[PublicPair]
    photos: list[PublicPhoto]
    checklists: list[PublicChecklist]
    photos_locked_at: datetime | None
    acknowledged: Acknowledgement | None
    link_expires_at: datetime
    pdf_ready: bool
    fingerprint: str | None = Field(description="SHA-256 of the PDF")


class AcknowledgeIn(_In):
    name: str = Field(min_length=1, max_length=120)
    organisation: str | None = Field(default=None, max_length=160)


class IssueIn(_In):
    message: str = Field(min_length=3, max_length=1000)
    contact: str | None = Field(default=None, max_length=160)


class IssueOut(BaseModel):
    id: uuid.UUID
    received_at: datetime


class NewLinkOut(BaseModel):
    sent_to: str | None = Field(description="Masked phone or email the new link went to")
    channel: Channel | None
    company_notified: bool
