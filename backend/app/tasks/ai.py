"""AI background tasks: transcribe voice notes, translate typed notes and checklist questions.

Each task is safe to run twice. Without an OpenAI key they do nothing and leave the work waiting.
"""

import uuid

from app.core.db import SessionLocal
from app.models import ChecklistQuestion, ChecklistTemplate, Company, Job, VoiceNote
from app.providers.ai import get_ai
from app.providers.storage import get_storage, sha256
from app.tasks import task

LANGS = ("en", "hi", "gu", "es", "fr")
MIN_CONFIDENCE = 0.45


async def _report_language(db, job_id) -> str:
    job = await db.get(Job, job_id)
    company = await db.get(Company, job.company_id)
    return company.report_language or "en"


@task
async def transcribe_voice_note(ctx, note_id: str) -> str:
    ai = get_ai()
    async with SessionLocal() as db:
        v = await db.get(VoiceNote, uuid.UUID(note_id))
        if not v or v.deleted_at:
            return "skipped"
        target = await _report_language(db, v.job_id)

        if v.kind == "typed":  # only a translation is needed
            if ai and v.transcript_original and v.detected_language != target and not v.transcript_translated:
                try:
                    (v.transcript_translated,) = await ai.translate(
                        [v.transcript_original], target, v.detected_language
                    )
                    v.translated_to = target
                except Exception as e:  # noqa: BLE001 - the note itself is fine; translation can be retried
                    v.error = f"translation failed: {type(e).__name__}"[:300]
                await db.commit()
            return "typed"

        if v.status not in ("uploaded", "failed", "unclear"):
            return "skipped"
        if not ai:
            return "waiting"  # stays "uploaded"; app shows "waiting for transcription"
        v.status = "transcribing"
        await db.commit()
        try:
            data = await get_storage().read(v.audio_key)
            if not v.sha256:
                v.sha256 = sha256(data)
            filename = v.audio_key.rsplit("/", 1)[-1]
            result = await ai.transcribe(data, filename, v.content_type or "audio/mp4", v.language_hint)
            v.transcript_original = result.text or None
            v.detected_language = result.language or v.language_hint
            v.confidence = result.confidence
            words = len((result.text or "").split())
            if words < 2 or (result.confidence is not None and result.confidence < MIN_CONFIDENCE):
                v.status = "unclear"  # M29 "couldn't understand": record again or retry
            else:
                if v.detected_language and v.detected_language != target:
                    (v.transcript_translated,) = await ai.translate(
                        [result.text], target, v.detected_language
                    )
                    v.translated_to = target
                v.status = "transcribed"
            v.error = None
        except Exception as e:  # noqa: BLE001
            v.status = "failed"
            v.error = f"{type(e).__name__}: {e}"[:300]
        await db.commit()
        return v.status


@task
async def translate_checklist_question(ctx, question_id: str) -> str:
    ai = get_ai()
    if not ai:
        return "waiting"  # other languages stay "missing"; the app shows the source language
    async with SessionLocal() as db:
        q = await db.get(ChecklistQuestion, uuid.UUID(question_id))
        if not q or q.deleted_at:
            return "skipped"
        t = await db.get(ChecklistTemplate, q.template_id)
        src = t.source_language
        texts, status = dict(q.text), dict(q.text_status or {})
        helps = dict(q.help or {})
        options = [dict(o, label=dict(o["label"])) for o in q.options or []]
        for lang in LANGS:
            if lang == src or status.get(lang) == "ready":
                continue
            items = (
                [texts[src]] + ([helps[src]] if helps.get(src) else []) + [o["label"][src] for o in options]
            )
            out = await ai.translate(items, lang, src)
            texts[lang] = out[0]
            i = 1
            if helps.get(src):
                helps[lang] = out[1]
                i = 2
            for o, label in zip(options, out[i:], strict=True):
                o["label"][lang] = label
            status[lang] = "needs_review"
        q.text, q.text_status, q.help, q.options = texts, status, helps, options
        await db.commit()
        return "translated"
