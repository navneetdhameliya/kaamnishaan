"""Writes one ai_usage row per AI call (A20 AI usage and cost).

Every AI call goes through `record` (or `record_failure` when the call failed and the caller's own
transaction is about to be rolled back), so the admin page sees all of them: report drafts,
transcription, translation and assistant answers.
"""

import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.models import AIUsage
from app.providers.ai import audio_cost_usd, cost_usd

log = logging.getLogger(__name__)

TASKS = ("report_draft", "transcription", "translation", "assistant")


def record(
    db: AsyncSession,
    task: str,
    *,
    company_id: uuid.UUID | None,
    model: str = "",
    tokens_in: int = 0,
    tokens_out: int = 0,
    seconds: float = 0.0,
    related_id: uuid.UUID | None = None,
    ok: bool = True,
) -> float:
    """Adds the row to `db` (saved with the caller's commit) and returns its cost in USD."""
    s = get_settings()
    model = model or (s.openai_transcribe_model if task == "transcription" else s.openai_text_model)
    cost = 0.0
    if ok:
        cost = (
            audio_cost_usd(model, seconds)
            if task == "transcription"
            else cost_usd(model, tokens_in, tokens_out)
        )
    db.add(
        AIUsage(
            company_id=company_id, task=task, model=model, tokens_in=tokens_in, tokens_out=tokens_out,
            audio_seconds=seconds, cost_usd=cost, related_id=related_id, ok=ok,
        )
    )  # fmt: skip
    return cost


async def record_failure(
    task: str, *, company_id: uuid.UUID | None, related_id: uuid.UUID | None = None
) -> None:
    """Saves a failed call on its own, for callers whose transaction is rolled back after the error."""
    try:
        async with SessionLocal() as db:
            record(db, task, company_id=company_id, related_id=related_id, ok=False)
            await db.commit()
    except Exception:  # noqa: BLE001 - counting must never break the real work
        log.exception("could not record a failed AI call")
