"""Voice notes (M27–M29) and typed notes when the microphone is off.

The audio is evidence: it is never changed and locks with the job's photos. Transcription runs in the
background; until an OpenAI key is set, notes stay "uploaded" and show "waiting for transcription".
"""

import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.core.security import now
from app.models import Job, User, VoiceNote
from app.providers.ai import get_ai
from app.providers.storage import get_storage
from app.schemas.checklists import (
    TypedNoteCreate,
    VoiceNoteCreate,
    VoiceNoteItem,
    VoiceNoteList,
    VoiceNoteOut,
    VoiceNotePatch,
)
from app.schemas.identity import ListMeta
from app.schemas.work import PersonRef
from app.services import audit
from app.services.evidence import CAPTURE_STATUSES, take_upload
from app.services.jobs import get_job

EXCERPT = 120


def _check_capture(job: Job) -> None:
    if job.status not in CAPTURE_STATUSES:
        if job.status in ("in_review", "completed"):
            raise Conflict("evidence_locked", "The report was sent, so notes are locked.")
        raise Conflict("job_not_started", "Start the job before adding notes.", {"status": job.status})


def text_for_report(v: VoiceNote) -> str | None:
    return v.transcript_edited or v.transcript_translated or v.transcript_original


async def _existing(db: AsyncSession, p: Principal, client_uuid) -> VoiceNote | None:
    if not client_uuid:
        return None
    return (
        await db.execute(
            select(VoiceNote).where(
                VoiceNote.company_id == p.company_id, VoiceNote.client_uuid == client_uuid
            )
        )
    ).scalar_one_or_none()


async def add_voice_note(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, body: VoiceNoteCreate
) -> tuple[VoiceNote, bool]:
    p.require("evidence.capture")
    job = await get_job(db, p, job_id, lock=True)
    if found := await _existing(db, p, body.client_uuid):
        return found, False
    _check_capture(job)
    up, size = await take_upload(db, p, body.upload_id, "audio")
    v = VoiceNote(
        company_id=p.company_id,
        job_id=job.id,
        client_uuid=body.client_uuid,
        kind="audio",
        audio_key=up.key,
        content_type=up.content_type,
        size=size,
        duration_s=body.duration_s,
        language_hint=body.language_hint,
        status="uploaded",
        recorded_at=body.recorded_at,
        recorded_by=p.user.id,
    )
    db.add(v)
    await db.flush()
    return v, True


async def add_typed_note(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, body: TypedNoteCreate
) -> tuple[VoiceNote, bool]:
    p.require("evidence.capture")
    job = await get_job(db, p, job_id, lock=True)
    if found := await _existing(db, p, body.client_uuid):
        return found, False
    _check_capture(job)
    v = VoiceNote(
        company_id=p.company_id,
        job_id=job.id,
        client_uuid=body.client_uuid,
        kind="typed",
        status="transcribed",
        transcript_original=body.text,
        detected_language=p.user.app_language,
        recorded_at=now(),
        recorded_by=p.user.id,
        confidence=1.0,
    )
    db.add(v)
    await db.flush()
    return v, True


async def _visible(db: AsyncSession, p: Principal, note_id: uuid.UUID) -> VoiceNote:
    v = (
        await db.execute(
            select(VoiceNote).where(
                VoiceNote.id == note_id, VoiceNote.company_id == p.company_id, VoiceNote.deleted_at.is_(None)
            )
        )
    ).scalar_one_or_none()
    if not v:
        raise NotFound("voice_note_not_found", "Note not found.")
    await get_job(db, p, v.job_id)  # technicians: only their own jobs
    return v


async def _names(db: AsyncSession, ids: set) -> dict:
    if not ids:
        return {}
    return {u.id: u.name or "" for u in (await db.execute(select(User).where(User.id.in_(ids)))).scalars()}


def _item(v: VoiceNote, names: dict) -> dict:
    text = text_for_report(v)
    return dict(
        id=v.id,
        job_id=v.job_id,
        kind=v.kind,
        status=v.status,
        waiting_for="transcription_service"
        if v.kind == "audio" and v.status == "uploaded" and get_ai() is None
        else None,
        duration_s=v.duration_s,
        language=v.detected_language or v.language_hint,
        excerpt=(text[:EXCERPT] + "…") if text and len(text) > EXCERPT else text,
        audio_url=get_storage().presign_get(v.audio_key) if v.audio_key else None,
        recorded_at=v.recorded_at,
        recorded_by=PersonRef(id=v.recorded_by, name=names.get(v.recorded_by, "")),
        locked=v.locked_at is not None,
    )


def _can_edit(p: Principal, v: VoiceNote) -> bool:
    return v.locked_at is None and (v.recorded_by == p.user.id or "jobs.view_all" in p.permissions)


async def note_out(db: AsyncSession, p: Principal, v: VoiceNote) -> VoiceNoteOut:
    names = await _names(db, {v.recorded_by})
    return VoiceNoteOut(
        **_item(v, names),
        transcript_original=v.transcript_original,
        transcript_translated=v.transcript_translated,
        translated_to=v.translated_to,
        transcript_edited=v.transcript_edited,
        text_for_report=text_for_report(v),
        confidence=v.confidence,
        error=v.error,
        can_edit=_can_edit(p, v),
    )


async def list_notes(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> VoiceNoteList:
    job = await get_job(db, p, job_id)
    rows = list(
        (
            await db.execute(
                select(VoiceNote)
                .where(VoiceNote.job_id == job.id, VoiceNote.deleted_at.is_(None))
                .order_by(VoiceNote.recorded_at)
            )
        ).scalars()
    )
    names = await _names(db, {v.recorded_by for v in rows})
    counts = {
        "all": len(rows),
        "audio": sum(v.kind == "audio" for v in rows),
        "typed": sum(v.kind == "typed" for v in rows),
    }
    return VoiceNoteList(data=[VoiceNoteItem(**_item(v, names)) for v in rows], meta=ListMeta(counts=counts))


async def edit(db: AsyncSession, p: Principal, note_id: uuid.UUID, body: VoiceNotePatch) -> VoiceNote:
    v = await _visible(db, p, note_id)
    if v.locked_at:
        raise Conflict("evidence_locked", "The report was sent, so notes are locked.")
    if not _can_edit(p, v):
        raise Forbidden("forbidden", "Only the person who recorded this note or a manager can change it.")
    v.transcript_edited = body.transcript_edited
    await db.flush()
    return v


async def retranscribe(
    db: AsyncSession, p: Principal, note_id: uuid.UUID, language_hint: str | None
) -> VoiceNote:
    v = await _visible(db, p, note_id)
    if v.kind != "audio":
        raise AppError("validation_error", "Typed notes don't need transcribing.")
    if v.status == "transcribing":
        return v
    if language_hint:
        v.language_hint = language_hint
    v.status, v.error = "uploaded", None
    await db.flush()
    return v


async def delete(db: AsyncSession, p: Principal, note_id: uuid.UUID) -> None:
    v = await _visible(db, p, note_id)
    if v.locked_at:
        raise Conflict("evidence_locked", "The report was sent, so notes are locked.")
    if not _can_edit(p, v):
        raise Forbidden("forbidden", "Only the person who recorded this note or a manager can remove it.")
    v.deleted_at = now()
    await audit.record(
        db,
        "voice_note.deleted",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="voice_note",
        target_id=v.id,
        data={"job_id": str(v.job_id), "kind": v.kind},
    )


async def lock_notes(db: AsyncSession, job_id: uuid.UUID) -> int:
    r = await db.execute(
        update(VoiceNote)
        .where(VoiceNote.job_id == job_id, VoiceNote.locked_at.is_(None), VoiceNote.deleted_at.is_(None))
        .values(locked_at=now())
    )
    return r.rowcount or 0


async def count_for_job(db: AsyncSession, job_id: uuid.UUID) -> int:
    from sqlalchemy import func

    return (
        await db.execute(
            select(func.count()).where(VoiceNote.job_id == job_id, VoiceNote.deleted_at.is_(None))
        )
    ).scalar_one()
