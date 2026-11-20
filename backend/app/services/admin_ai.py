"""A20 AI usage and cost: what AI cost over the last 7, 30 or 90 days, and where it went.

Everything is counted from ai_usage (one row per AI call, see services/ai_usage.py). Costs are our
estimate from token and audio-minute prices in providers/ai.py, not OpenAI's bill.
"""

from datetime import timedelta

from sqlalchemy import Date, case, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import now
from app.models import AIUsage, Company
from app.schemas.admin_ai import AdminAiCompany, AdminAiDay, AdminAiModel, AdminAiUsageOut
from app.services.ai_usage import TASKS

TOP = 4
TASK_ORDER = {t: i for i, t in enumerate(TASKS)}


async def usage(db: AsyncSession, *, days: int) -> AdminAiUsageOut:
    s = get_settings()
    t = now()
    since = t - timedelta(days=days)
    in_range = AIUsage.at >= since

    # ---- totals -----------------------------------------------------------------------------------
    total = float(await db.scalar(select(func.sum(AIUsage.cost_usd)).where(in_range)) or 0)
    drafts_ok, drafts_all = (
        await db.execute(
            select(func.count().filter(AIUsage.ok), func.count()).where(
                in_range, AIUsage.task == "report_draft"
            )
        )
    ).one()
    seconds = float(
        await db.scalar(
            select(func.sum(AIUsage.audio_seconds)).where(
                in_range, AIUsage.task == "transcription", AIUsage.ok
            )
        )
        or 0
    )

    # ---- cost per day by task (every day shown, also days without calls) ----------------------------
    day = cast(func.timezone("UTC", AIUsage.at), Date)
    by_day: dict = {}
    for d, task, cost in (
        await db.execute(
            select(day, AIUsage.task, func.sum(AIUsage.cost_usd)).where(in_range).group_by(day, AIUsage.task)
        )
    ).all():
        by_day.setdefault(d, {})[task] = float(cost or 0)
    first = since.date()
    per_day = []
    for i in range(days + 1):
        d = first + timedelta(days=i)
        if d > t.date():
            break
        c = by_day.get(d, {})
        per_day.append(AdminAiDay(day=d, **{k: round(c.get(k, 0.0), 6) for k in TASKS}))

    # ---- cost by company ------------------------------------------------------------------------------
    rows = (
        await db.execute(
            select(Company.id, Company.name, func.sum(AIUsage.cost_usd).label("cost"))
            .join(Company, Company.id == AIUsage.company_id)
            .where(in_range)
            .group_by(Company.id, Company.name)
            .having(func.sum(AIUsage.cost_usd) > 0)
            .order_by(func.sum(AIUsage.cost_usd).desc(), Company.name)
        )
    ).all()
    top = [AdminAiCompany(id=r.id, name=r.name, cost_usd=round(float(r.cost), 4)) for r in rows[:TOP]]
    others = round(total - sum(c.cost_usd for c in top), 4)
    others_count = len(rows) - len(top)

    # ---- model usage ------------------------------------------------------------------------------------
    models = []
    for task, model, calls, ok_calls, cost, secs in (
        await db.execute(
            select(
                AIUsage.task,
                AIUsage.model,
                func.count(),
                func.count().filter(AIUsage.ok),
                func.sum(AIUsage.cost_usd),
                func.sum(case((AIUsage.ok, AIUsage.audio_seconds), else_=0)),
            )
            .where(in_range)
            .group_by(AIUsage.task, AIUsage.model)
        )
    ).all():
        per_minute = task == "transcription"
        if per_minute:
            avg = float(cost or 0) / (float(secs) / 60) if secs else None
        else:
            avg = float(cost or 0) / ok_calls if ok_calls else None
        models.append(
            AdminAiModel(
                task=task, model=model, calls=calls, per_minute=per_minute,
                avg_cost_usd=round(avg, 6) if avg is not None else None,
                error_rate=round((calls - ok_calls) / calls, 4) if calls else None,
            )
        )  # fmt: skip
    models.sort(key=lambda m: (TASK_ORDER.get(m.task, 9), -m.calls))

    return AdminAiUsageOut(
        days=days,
        configured=s.openai_api_key is not None,
        total_cost_usd=round(total, 4),
        budget_usd=s.ai_monthly_budget_usd or None,
        cost_per_report_usd=round(total / drafts_ok, 4) if drafts_ok else None,
        target_per_report_usd=s.ai_cost_per_report_target_usd or None,
        reports_drafted=drafts_ok,
        draft_success=round(drafts_ok / drafts_all, 4) if drafts_all else None,
        voice_minutes=round(seconds / 60, 1),
        per_day=per_day,
        companies=top,
        others_cost_usd=max(others, 0.0),
        others_count=others_count,
        models=models,
    )
