"""Applies the A19 AI configuration and A21 live prompts to every AI call.

`ai_for()` gives the AI provider set up with the chosen models, or None when there is no key or (for
budgeted work: report drafts and the assistant) this month's AI spend has reached the monthly budget.
Voice transcription and translations keep working over budget: technicians depend on them."""

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import AIUsage, PromptVersion
from app.providers.ai import AIProvider, get_ai
from app.services import platform
from app.services.moderation import hide_contact

# A21: prompt tasks. Each prompt must keep its {language} placeholder.
PROMPT_TASKS = ("report_draft", "assistant", "translation")


def month_start(at: datetime | None = None) -> datetime:
    t = at or now()
    return t.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


async def month_spend(db: AsyncSession) -> float:
    return float(await db.scalar(select(func.sum(AIUsage.cost_usd)).where(AIUsage.at >= month_start())) or 0)


async def over_budget(db: AsyncSession) -> bool:
    budget = (await platform.ai_config(db)).monthly_budget_usd
    return bool(budget) and await month_spend(db) >= budget


async def live_prompt(db: AsyncSession, task: str) -> PromptVersion | None:
    return (
        await db.execute(
            select(PromptVersion).where(PromptVersion.task == task, PromptVersion.live.is_(True))
        )
    ).scalar_one_or_none()


async def ai_for(db: AsyncSession, *, budgeted: bool) -> AIProvider | None:
    ai = get_ai()
    if ai is None:
        return None
    cfg = await platform.ai_config(db)
    if budgeted and cfg.monthly_budget_usd and await month_spend(db) >= cfg.monthly_budget_usd:
        return None
    if hasattr(ai, "text_model"):
        ai.text_model, ai.transcribe_model = cfg.text_model, cfg.transcribe_model
        ai.max_tokens = cfg.max_tokens_report
        tr = await live_prompt(db, "translation")
        ai.translate_prompt = tr.system_prompt if tr else None
    return ai


def masked(value, on: bool = True):
    """Phone numbers and emails inside every text of the evidence, hidden before it goes to the AI."""
    if not on:
        return value
    if isinstance(value, str):
        return hide_contact(value)[0]
    if isinstance(value, list):
        return [masked(v) for v in value]
    if isinstance(value, dict):
        return {k: masked(v) for k, v in value.items()}
    return value
