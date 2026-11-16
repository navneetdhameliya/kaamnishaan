import uuid

from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.jobs import member
from app.core.deps import Principal, get_db
from app.schemas.checklists import (
    TypedNoteCreate,
    VoiceNoteCreate,
    VoiceNoteList,
    VoiceNoteOut,
    VoiceNotePatch,
)
from app.schemas.identity import Locale
from app.services import voice as svc
from app.tasks import enqueue

router = APIRouter(tags=["voice notes"])


class RetranscribeIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    language_hint: Locale | None = None


async def _created(db: AsyncSession, p: Principal, v, created: bool, response: Response) -> VoiceNoteOut:
    if created:
        await db.commit()
        await enqueue("transcribe_voice_note", note_id=str(v.id))
        await db.refresh(v)
    else:
        response.status_code = status.HTTP_200_OK
    return await svc.note_out(db, p, v)


@router.get("/jobs/{job_id}/voice-notes", response_model=VoiceNoteList)
async def list_notes(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> VoiceNoteList:
    return await svc.list_notes(db, p, job_id)


@router.post("/jobs/{job_id}/voice-notes", response_model=VoiceNoteOut, status_code=201)
async def add_voice_note(
    job_id: uuid.UUID,
    body: VoiceNoteCreate,
    response: Response,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> VoiceNoteOut:
    """Confirm an audio upload (POST /uploads with kind=audio first).

    Transcription starts in the background."""
    v, created = await svc.add_voice_note(db, p, job_id, body)
    return await _created(db, p, v, created, response)


@router.post("/jobs/{job_id}/notes", response_model=VoiceNoteOut, status_code=201)
async def add_typed_note(
    job_id: uuid.UUID,
    body: TypedNoteCreate,
    response: Response,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> VoiceNoteOut:
    """A typed note when the microphone is off (M27)."""
    v, created = await svc.add_typed_note(db, p, job_id, body)
    return await _created(db, p, v, created, response)


@router.get("/voice-notes/{note_id}", response_model=VoiceNoteOut)
async def get_note(
    note_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> VoiceNoteOut:
    return await svc.note_out(db, p, await svc._visible(db, p, note_id))


@router.patch("/voice-notes/{note_id}", response_model=VoiceNoteOut)
async def edit_note(
    note_id: uuid.UUID,
    body: VoiceNotePatch,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> VoiceNoteOut:
    return await svc.note_out(db, p, await svc.edit(db, p, note_id, body))


@router.post("/voice-notes/{note_id}/retranscribe", response_model=VoiceNoteOut)
async def retranscribe(
    note_id: uuid.UUID,
    body: RetranscribeIn | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> VoiceNoteOut:
    v = await svc.retranscribe(db, p, note_id, body.language_hint if body else None)
    await db.commit()
    await enqueue("transcribe_voice_note", note_id=str(v.id))
    await db.refresh(v)
    return await svc.note_out(db, p, v)


@router.delete("/voice-notes/{note_id}", status_code=204)
async def delete_note(
    note_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    await svc.delete(db, p, note_id)
    return Response(status_code=204)
