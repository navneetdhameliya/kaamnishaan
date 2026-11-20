"""A19 AI configuration, A21 Prompt management, A22 Industries."""

from datetime import timedelta

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import (
    AIUsage,
    ChecklistQuestion,
    ChecklistTemplate,
    Company,
    Industry,
    PromptVersion,
    Report,
    StaffUser,
)
from app.providers.ai import AUDIO_PRICES, PRICES, get_ai
from app.schemas.admin_ai_config import (
    AdminAiConfigOut,
    AdminIndustriesOut,
    AdminIndustry,
    AdminIndustryIn,
    AdminPrompt,
    AdminPromptDraftIn,
    AdminPromptsOut,
    AdminPromptStats,
    AdminPromptVersion,
)
from app.services import audit, platform
from app.services.ai_config import PROMPT_TASKS, month_spend


# ---- A19 AI configuration ------------------------------------------------------------------------------
async def ai_config(db: AsyncSession, *, can_act: bool) -> AdminAiConfigOut:
    cfg = await platform.ai_config(db)
    texts, audio = sorted(PRICES), sorted(AUDIO_PRICES)
    return AdminAiConfigOut(
        config=cfg,
        text_models=texts if cfg.text_model in texts else [cfg.text_model, *texts],
        transcribe_models=audio if cfg.transcribe_model in audio else [cfg.transcribe_model, *audio],
        key_set=get_ai() is not None,
        month_spend_usd=round(await month_spend(db), 4),
        can_act=can_act,
    )


async def save_ai_config(
    db: AsyncSession, body: platform.AiConfig, *, staff_id, ip: str | None
) -> AdminAiConfigOut:
    if body.text_model not in PRICES or body.transcribe_model not in AUDIO_PRICES:
        raise AppError("unknown_model", "Pick a model from the list.", fields={"model": "unknown"})
    before = (await platform.ai_config(db)).model_dump()
    await platform.set_ai_config(db, body, staff_id=staff_id)
    changes = {
        k: {"from": before.get(k), "to": v} for k, v in body.model_dump().items() if before.get(k) != v
    }
    if changes:
        await audit.record(
            db, "ai_config.updated", staff_id=staff_id, target_type="platform", data=changes, ip=ip
        )
    return await ai_config(db, can_act=True)


# ---- A21 Prompts -----------------------------------------------------------------------------------
async def prompts(db: AsyncSession, *, can_act: bool) -> AdminPromptsOut:
    rows = (
        (await db.execute(select(PromptVersion).order_by(PromptVersion.task, PromptVersion.version.desc())))
        .scalars()
        .all()
    )
    staff_ids = {x for r in rows for x in (r.edited_by, r.published_by) if x}
    names = (
        dict(
            (await db.execute(select(StaffUser.id, StaffUser.name).where(StaffUser.id.in_(staff_ids)))).all()
        )
        if staff_ids
        else {}
    )
    since = now() - timedelta(days=30)
    stats = {
        task: (int(n), int(failed or 0), float(tok or 0), float(cost or 0))
        for task, n, failed, tok, cost in await db.execute(
            select(
                AIUsage.task,
                func.count(),
                func.sum(case((AIUsage.ok.is_(False), 1), else_=0)),
                func.avg(case((AIUsage.ok.is_(True), AIUsage.tokens_in + AIUsage.tokens_out))),
                func.avg(case((AIUsage.ok.is_(True), AIUsage.cost_usd))),
            )
            .where(AIUsage.at >= since)
            .group_by(AIUsage.task)
        )
    }
    per_version = {
        v: (int(n), int(flagged or 0))
        for v, n, flagged in await db.execute(
            select(
                Report.ai_prompt_version,
                func.count(),
                func.sum(case((Report.flags.op("@>")([{"kind": "unsupported_claim"}]), 1), else_=0)),
            )
            .where(Report.ai_prompt_version.is_not(None))
            .group_by(Report.ai_prompt_version)
        )
    }
    out = []
    for task in PROMPT_TASKS:
        mine = [r for r in rows if r.task == task]
        n, failed, tok, cost = stats.get(task, (0, 0, 0.0, 0.0))
        versions = []
        for r in mine:
            used = per_version.get(r.version) if task == "report_draft" else None
            versions.append(
                AdminPromptVersion(
                    version=r.version,
                    status=r.status,
                    system_prompt=r.system_prompt,
                    note=r.note,
                    edited_by=names.get(r.edited_by),
                    published_by=names.get(r.published_by),
                    published_at=r.published_at,
                    created_at=r.created_at,
                    updated_at=r.updated_at,
                    reports=used[0] if used else (0 if task == "report_draft" else None),
                    flagged=used[1] if used else (0 if task == "report_draft" else None),
                )
            )
        out.append(
            AdminPrompt(
                task=task,
                live=next((r.version for r in mine if r.live), None),
                draft=next((r.version for r in mine if r.status == "draft"), None),
                variables=["language"],
                versions=versions,
                stats=AdminPromptStats(
                    runs=n, failed=failed, avg_tokens=round(tok), avg_cost_usd=round(cost, 5)
                ),
            )
        )
    return AdminPromptsOut(prompts=out, can_act=can_act)


async def _versions(db: AsyncSession, task: str) -> list[PromptVersion]:
    if task not in PROMPT_TASKS:
        raise NotFound("not_found", "Prompt not found.")
    q = (
        select(PromptVersion)
        .where(PromptVersion.task == task)
        .order_by(PromptVersion.version)
        .with_for_update()
    )
    return list((await db.execute(q)).scalars())


async def save_draft(
    db: AsyncSession, task: str, body: AdminPromptDraftIn, *, staff_id, ip
) -> AdminPromptsOut:
    """Edits the draft, or starts one (the next version) when there is none."""
    rows = await _versions(db, task)
    draft = next((r for r in rows if r.status == "draft"), None)
    if draft is None:
        draft = PromptVersion(
            task=task, version=max((r.version for r in rows), default=0) + 1, status="draft"
        )
        db.add(draft)
    draft.system_prompt, draft.note, draft.edited_by = body.system_prompt, body.note, staff_id
    await db.flush()
    await audit.record(
        db,
        "prompt.draft_saved",
        staff_id=staff_id,
        target_type="prompt",
        data={"task": task, "version": draft.version},
        ip=ip,
    )
    return await prompts(db, can_act=True)


async def discard_draft(db: AsyncSession, task: str, *, staff_id, ip) -> AdminPromptsOut:
    rows = await _versions(db, task)
    draft = next((r for r in rows if r.status == "draft"), None)
    if draft:
        await db.delete(draft)
        await audit.record(
            db,
            "prompt.draft_discarded",
            staff_id=staff_id,
            target_type="prompt",
            data={"task": task, "version": draft.version},
            ip=ip,
        )
        await db.flush()
    return await prompts(db, can_act=True)


async def publish(db: AsyncSession, task: str, version: int, *, staff_id, ip) -> AdminPromptsOut:
    """Makes a version live: the draft, or an older one to go back to. The previous live one is retired."""
    rows = await _versions(db, task)
    target = next((r for r in rows if r.version == version), None)
    if not target:
        raise NotFound("not_found", "Version not found.")
    if target.live:
        return await prompts(db, can_act=True)
    old = next((r for r in rows if r.live), None)
    if old:
        old.live, old.status = False, "retired"
        await db.flush()  # one live version per task
    target.live, target.status, target.published_by, target.published_at = True, "live", staff_id, now()
    await db.flush()
    await audit.record(
        db,
        "prompt.published",
        staff_id=staff_id,
        target_type="prompt",
        data={"task": task, "version": version, "from": old.version if old else None},
        ip=ip,
    )
    return await prompts(db, can_act=True)


# ---- A22 Industries ---------------------------------------------------------------------------------
async def industries(db: AsyncSession, *, can_act: bool) -> AdminIndustriesOut:
    rows = (await db.execute(select(Industry).order_by(Industry.sort, Industry.slug))).scalars().all()
    companies = dict(
        (await db.execute(select(Company.industry_slug, func.count()).group_by(Company.industry_slug))).all()
    )
    ready = (
        await db.execute(
            select(ChecklistTemplate.trade, ChecklistTemplate.name, func.count(ChecklistQuestion.id))
            .outerjoin(
                ChecklistQuestion,
                (ChecklistQuestion.template_id == ChecklistTemplate.id)
                & ChecklistQuestion.deleted_at.is_(None),
            )
            .where(ChecklistTemplate.company_id.is_(None), ChecklistTemplate.status == "published")
            .group_by(ChecklistTemplate.id)
            .order_by(
                ChecklistTemplate.trade, ChecklistTemplate.usage_count.desc(), ChecklistTemplate.created_at
            )
        )
    ).all()
    by_trade: dict[str, list] = {}
    for trade, name, n in ready:
        by_trade.setdefault(trade, []).append((name, n))
    items = []
    for i in rows:
        lists = by_trade.get(i.slug, [])
        first = lists[0] if lists else None
        items.append(
            AdminIndustry(
                slug=i.slug,
                name=dict(i.name or {}),
                status=i.status,
                sort=i.sort,
                companies=companies.get(i.slug, 0),
                checklists=len(lists),
                default_checklist=(first[0].get("en") if first else None),
                default_questions=first[1] if first else None,
            )
        )
    return AdminIndustriesOut(items=items, can_act=can_act)


async def save_industry(
    db: AsyncSession, slug: str | None, body: AdminIndustryIn, *, staff_id, ip
) -> AdminIndustriesOut:
    if slug is None:  # new
        if not body.slug:
            raise AppError(
                "validation_error", "Give the industry a web address name.", fields={"slug": "required"}
            )
        if await db.get(Industry, body.slug):
            raise AppError(
                "industry_exists", "That industry already exists.", fields={"slug": "taken"}, status=409
            )
        ind = Industry(slug=body.slug, name=body.name, status=body.status, sort=body.sort)
        db.add(ind)
        action, before = "industry.created", {}
    else:
        ind = await db.get(Industry, slug, with_for_update=True)
        if not ind:
            raise NotFound("not_found", "Industry not found.")
        before = {"name": ind.name, "status": ind.status, "sort": ind.sort}
        ind.name, ind.status, ind.sort = body.name, body.status, body.sort
        action = "industry.updated"
    after = {"name": body.name, "status": body.status, "sort": body.sort}
    changes = {k: {"from": before.get(k), "to": v} for k, v in after.items() if before.get(k) != v}
    await db.flush()
    if changes:
        await audit.record(
            db, action, staff_id=staff_id, target_type="industry", data={"slug": ind.slug, **changes}, ip=ip
        )
    return await industries(db, can_act=True)
