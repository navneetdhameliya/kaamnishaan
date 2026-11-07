"""Uploads, photos, notes, before/after pairs and the capture hub (M19–M23)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import ListMeta
from app.schemas.work import PersonRef

Stage = Literal["before", "during", "after"]
UploadKind = Literal["photo", "audio", "logo", "avatar", "signature"]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class UploadCreate(_In):
    kind: UploadKind
    content_type: str = Field(examples=["image/jpeg"])
    size: int | None = Field(default=None, ge=1, description="Bytes, if known; checked again on confirm")


class UploadOut(BaseModel):
    upload_id: uuid.UUID
    url: str
    method: Literal["PUT"]
    headers: dict[str, str]
    max_bytes: int
    expires_at: datetime


class EvidenceCreate(_In):
    upload_id: uuid.UUID
    stage: Stage
    taken_at: datetime
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    shot_slot: str | None = Field(default=None, max_length=64)
    client_uuid: uuid.UUID | None = Field(
        default=None, description="Made on the phone; a retry returns the same photo"
    )


class EvidenceOut(BaseModel):
    id: uuid.UUID
    job_id: uuid.UUID
    stage: Stage
    shot_slot: str | None
    url: str = Field(description="Full photo, signed link valid about 15 minutes")
    thumb_url: str | None
    width: int | None
    height: int | None
    size: int
    processing: Literal["pending", "ready", "failed"]
    taken_at: datetime
    taken_by: PersonRef
    lat: float | None
    lng: float | None
    locked: bool
    locked_at: datetime | None
    notes_count: int


class NoteIn(_In):
    text: str = Field(min_length=1, max_length=1000)


class NoteOut(BaseModel):
    id: uuid.UUID
    author: PersonRef
    text: str
    created_at: datetime


class EvidenceDetail(EvidenceOut):
    notes: list[NoteOut]
    can_delete: bool


class PairIn(_In):
    before_id: uuid.UUID
    after_id: uuid.UUID
    subject: str | None = Field(default=None, max_length=120)
    use_in_report: bool = True


class PairOut(BaseModel):
    id: uuid.UUID
    before: EvidenceOut
    after: EvidenceOut
    subject: str | None
    use_in_report: bool


class EvidenceList(BaseModel):
    data: list[EvidenceOut]
    meta: ListMeta
    pairs: list[PairOut]


class ProofStep(BaseModel):
    key: Literal["before", "during", "after", "checklist", "voice"]
    count: int
    required: bool
    done: bool
    thumbs: list[str] = Field(default_factory=list, description="Up to 3 latest thumbnail links")


class Proof(BaseModel):
    job_id: uuid.UUID
    status: str
    steps: list[ProofStep]
    can_make_report: bool
    blocked_by: Literal["job_not_started", "need_before_photo", "need_after_photo", "evidence_locked"] | None
    locked: bool
