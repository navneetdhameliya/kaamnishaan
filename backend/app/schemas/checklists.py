"""Checklists and voice notes.

Templates (M26), job checklists and answers (M24, M25), manager questions, voice notes (M27–M29).
"""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.evidence import EvidenceOut
from app.schemas.identity import ListMeta, Locale
from app.schemas.work import PersonRef

QuestionType = Literal["yes_no", "pass_fail", "number", "text", "choice", "photo", "signature"]
PhotoRule = Literal["none", "always", "if_no", "if_fail"]
TextStatus = Literal["ready", "needs_review", "missing"]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


# ---- templates -------------------------------------------------------------------------------
class TemplateCreate(_In):
    name: str = Field(min_length=1, max_length=120)
    trade: str | None = None
    minutes: int | None = Field(default=None, ge=1, le=240)
    language: Locale | None = Field(
        default=None, description="Language you type in; default: your app language"
    )


class TemplatePatch(_In):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    trade: str | None = None
    minutes: int | None = Field(default=None, ge=1, le=240)
    status: Literal["draft", "published", "archived"] | None = None


class TemplateListItem(BaseModel):
    id: uuid.UUID
    name: str
    trade: str | None
    minutes: int | None
    scope: Literal["global", "company"]
    status: str
    version: int
    question_count: int
    usage_count: int
    needs_translation: int


class TemplateList(BaseModel):
    data: list[TemplateListItem]
    meta: ListMeta


class OptionIn(_In):
    key: str | None = Field(default=None, max_length=40, pattern=r"^[a-z0-9_]+$")
    label: str = Field(min_length=1, max_length=80)


class ConditionIn(_In):
    question_id: uuid.UUID
    equals: str | float | bool


class QuestionIn(_In):
    type: QuestionType
    text: str = Field(min_length=1, max_length=200)
    help: str | None = Field(default=None, max_length=300)
    options: list[OptionIn] = Field(default_factory=list, max_length=12)
    unit: str | None = Field(default=None, max_length=16)
    min_value: float | None = None
    max_value: float | None = None
    photo_rule: PhotoRule = "none"
    required: bool = True
    condition: ConditionIn | None = None
    position: int | None = Field(default=None, ge=1)
    reference_upload_id: uuid.UUID | None = Field(default=None, description="Photo uploaded with kind=photo")


class QuestionPatch(_In):
    text: str | None = Field(default=None, min_length=1, max_length=200)
    help: str | None = Field(default=None, max_length=300)
    options: list[OptionIn] | None = Field(default=None, max_length=12)
    unit: str | None = Field(default=None, max_length=16)
    min_value: float | None = None
    max_value: float | None = None
    photo_rule: PhotoRule | None = None
    required: bool | None = None
    condition: ConditionIn | None = None
    clear_condition: bool = False
    position: int | None = Field(default=None, ge=1)
    reference_upload_id: uuid.UUID | None = None
    remove_reference: bool = Field(default=False, description="Take the reference photo off the question")
    translations: dict[Locale, str] | None = Field(
        default=None, description="Fix a translation by hand (marks it ready)"
    )


class OptionOut(BaseModel):
    key: str
    label: str


class TemplateQuestionOut(BaseModel):
    id: uuid.UUID
    position: int
    type: QuestionType
    text: str
    text_all: dict[str, str]
    text_status: dict[str, TextStatus]
    help: str | None
    options: list[OptionOut]
    unit: str | None
    min_value: float | None
    max_value: float | None
    photo_rule: PhotoRule
    required: bool
    condition: dict | None
    reference_image_url: str | None


class TemplateOut(TemplateListItem):
    language: str
    questions: list[TemplateQuestionOut]
    editable: bool


# ---- job checklists and answers ----------------------------------------------------------------
class AttachChecklist(_In):
    template_id: uuid.UUID


class JobChecklistItem(BaseModel):
    id: uuid.UUID
    template_id: uuid.UUID
    name: str
    minutes: int | None
    answered: int
    total: int
    status: Literal["not_started", "in_progress", "done"]
    completed_at: datetime | None


class JobChecklistList(BaseModel):
    data: list[JobChecklistItem]
    meta: ListMeta


class AnswerOut(BaseModel):
    value: Any
    photo: EvidenceOut | None
    signature_url: str | None
    answered_at: datetime
    answered_by: PersonRef
    locked: bool


class QuestionOut(BaseModel):
    id: uuid.UUID
    position: int
    type: QuestionType
    text: str
    translation_status: TextStatus
    help: str | None
    options: list[OptionOut]
    unit: str | None
    min_value: float | None
    max_value: float | None
    photo_rule: PhotoRule
    required: bool
    condition: dict | None = Field(
        default=None, description="'Show if' rule {question_id, equals}, so the app can follow it offline"
    )
    visible: bool = Field(description="False when its 'show if' condition is not met")
    photo_needed: bool = Field(description="The photo rule applies and no photo is attached yet")
    reference_image_url: str | None
    answer: AnswerOut | None


class SubmissionOut(BaseModel):
    id: uuid.UUID
    job_id: uuid.UUID
    name: str
    language: str
    answered: int
    total: int
    status: Literal["not_started", "in_progress", "done"]
    locked: bool
    questions: list[QuestionOut]


class AnswerIn(_In):
    value: str | float | bool | None = None
    photo_id: uuid.UUID | None = Field(
        default=None, description="Evidence id of a photo taken for this question"
    )
    signature_upload_id: uuid.UUID | None = None
    client_uuid: uuid.UUID | None = None


class ManagerQuestionIn(_In):
    text: str = Field(min_length=1, max_length=1000)
    job_checklist_id: uuid.UUID | None = None
    question_id: uuid.UUID | None = None
    photo_id: uuid.UUID | None = None


class ManagerAnswerIn(_In):
    answer: str = Field(min_length=1, max_length=1000)


class ManagerQuestionOut(BaseModel):
    id: uuid.UUID
    job_id: uuid.UUID
    job_checklist_id: uuid.UUID | None
    question_id: uuid.UUID | None
    photo: EvidenceOut | None
    text: str
    asked_by: PersonRef
    asked_at: datetime
    answer: str | None
    answered_by: PersonRef | None
    answered_at: datetime | None


class ManagerQuestionList(BaseModel):
    data: list[ManagerQuestionOut]
    meta: ListMeta


# ---- voice notes ---------------------------------------------------------------------------------
class VoiceNoteCreate(_In):
    upload_id: uuid.UUID
    duration_s: float = Field(gt=0, le=600, description="Up to 10 minutes")
    recorded_at: datetime
    language_hint: Locale | None = None
    client_uuid: uuid.UUID | None = None


class TypedNoteCreate(_In):
    text: str = Field(min_length=1, max_length=4000)
    client_uuid: uuid.UUID | None = None


class VoiceNotePatch(_In):
    transcript_edited: str = Field(min_length=1, max_length=8000)


VoiceStatus = Literal["uploaded", "transcribing", "transcribed", "unclear", "failed"]


class VoiceNoteItem(BaseModel):
    id: uuid.UUID
    job_id: uuid.UUID
    kind: Literal["audio", "typed"]
    status: VoiceStatus
    waiting_for: Literal["transcription_service"] | None = None
    duration_s: float | None
    language: str | None
    excerpt: str | None
    audio_url: str | None
    recorded_at: datetime
    recorded_by: PersonRef
    locked: bool


class VoiceNoteList(BaseModel):
    data: list[VoiceNoteItem]
    meta: ListMeta


class VoiceNoteOut(VoiceNoteItem):
    transcript_original: str | None
    transcript_translated: str | None
    translated_to: str | None
    transcript_edited: str | None
    text_for_report: str | None = Field(description="Edited text, else the translation, else the original")
    confidence: float | None
    error: str | None
    can_edit: bool


# ---- website: ready checklists for a trade (W18–W23) -----------------------------------------
class PublicChecklistQuestion(BaseModel):
    text: str
    type: str
    unit: str | None = None
    photo_rule: str = Field(description="none / always / if_no / if_fail")
    required: bool


class PublicChecklistTemplate(BaseModel):
    key: str | None
    name: str
    minutes: int | None
    question_count: int
    photo_questions: int = Field(description="questions that take or may ask for a photo")
    languages: list[str] = Field(description="languages every question is written in")
    questions: list[PublicChecklistQuestion]


class PublicChecklistTemplates(BaseModel):
    trade: str
    language: str
    items: list[PublicChecklistTemplate]
