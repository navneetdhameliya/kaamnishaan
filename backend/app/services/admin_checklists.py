"""A23: KaamNishaan's own checklist templates (company_id is empty). Companies see the published ones
in the app and on the website's industry pages; editing here never changes a job that already has the
checklist (jobs keep a copy, D-34). Question rules are the same as in the app."""

import uuid

from sqlalchemy import func, select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.models import ChecklistQuestion, ChecklistTemplate, Industry, JobChecklist
from app.providers.ai import get_ai
from app.schemas.admin_checklists import (
    AdminChecklistCounts,
    AdminChecklistCreate,
    AdminChecklistDetail,
    AdminChecklistList,
    AdminChecklistOption,
    AdminChecklistPatch,
    AdminChecklistQuestion,
    AdminChecklistRow,
)
from app.schemas.admin_companies import AdminOption
from app.services import audit
from app.services.checklists import check_trade, pick, questions

LANGS = ("en", "hi", "gu", "es", "fr")


def languages(t: ChecklistTemplate, qs: list[ChecklistQuestion]) -> dict[str, str]:
    """ready: every question has it, checked; review: all there, some only machine-translated; missing."""
    out = {}
    for lg in LANGS:
        if lg == t.source_language:
            out[lg] = "ready"
            continue
        if not qs or any(not (q.text or {}).get(lg) for q in qs):
            out[lg] = "missing"
        elif any((q.text_status or {}).get(lg) != "ready" for q in qs):
            out[lg] = "review"
        else:
            out[lg] = "ready"
    return out


async def _used_by(db: AsyncSession, ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    if not ids:
        return {}
    pairs = union(
        select(JobChecklist.template_id.label("tid"), JobChecklist.company_id.label("cid")).where(
            JobChecklist.template_id.in_(ids)
        ),
        select(ChecklistTemplate.copied_from.label("tid"), ChecklistTemplate.company_id.label("cid")).where(
            ChecklistTemplate.copied_from.in_(ids), ChecklistTemplate.company_id.is_not(None)
        ),
    ).subquery()
    rows = await db.execute(select(pairs.c.tid, func.count(func.distinct(pairs.c.cid))).group_by(pairs.c.tid))
    return dict(rows.all())


async def _trades(db: AsyncSession, lang: str) -> list[AdminOption]:
    rows = (await db.execute(select(Industry).order_by(Industry.sort))).scalars()
    return [AdminOption(value=i.slug, label=pick(i.name, lang)) for i in rows]


async def templates(
    db: AsyncSession, *, tab: str, q: str | None, trade: str | None, lang_state: str | None, lang: str
) -> AdminChecklistList:
    rows = list(
        (
            await db.execute(
                select(ChecklistTemplate).where(
                    ChecklistTemplate.company_id.is_(None), ChecklistTemplate.status != "archived"
                )
            )
        ).scalars()
    )
    trades = await _trades(db, lang)
    trade_names = {o.value: o.label for o in trades}
    used = await _used_by(db, [t.id for t in rows])
    items = []
    for t in rows:
        qs = await questions(db, t.id)
        items.append(
            AdminChecklistRow(
                id=t.id,
                name=pick(t.name, lang, t.source_language),
                trade=t.trade,
                trade_name=trade_names.get(t.trade or ""),
                status=t.status,
                question_count=len(qs),
                photo_questions=sum(1 for x in qs if x.type == "photo" or x.photo_rule != "none"),
                languages=languages(t, qs),
                used_by=used.get(t.id, 0),
                updated_at=t.updated_at,
            )
        )
    untranslated = [i for i in items if any(v != "ready" for v in i.languages.values())]
    counts = AdminChecklistCounts(
        all=len(items),
        needs_translation=len(untranslated),
        drafts=sum(1 for i in items if i.status == "draft"),
    )
    if tab == "needs_translation":
        items = untranslated
    elif tab == "drafts":
        items = [i for i in items if i.status == "draft"]
    if trade:
        items = [i for i in items if i.trade == trade]
    if lang_state:
        items = [i for i in items if lang_state in i.languages.values()]
    if q and q.strip():
        needle = q.strip().lower()
        items = [i for i in items if needle in i.name.lower() or needle in (i.trade_name or "").lower()]
    order = {s: n for n, s in enumerate(trade_names)}
    if tab == "by_trade":
        items.sort(key=lambda i: (order.get(i.trade or "", 999), i.name.lower()))
    else:
        items.sort(key=lambda i: (-i.used_by, i.name.lower()))
    return AdminChecklistList(items=items, total=len(items), counts=counts, trades=trades)


async def global_template(db: AsyncSession, template_id: uuid.UUID) -> ChecklistTemplate:
    t = await db.get(ChecklistTemplate, template_id)
    if not t or t.company_id is not None:
        raise NotFound("template_not_found", "This checklist doesn't exist.")
    return t


async def detail(db: AsyncSession, template_id: uuid.UUID, *, lang: str) -> AdminChecklistDetail:
    t = await global_template(db, template_id)
    qs = await questions(db, t.id)
    trades = await _trades(db, lang)
    return AdminChecklistDetail(
        id=t.id,
        key=t.key,
        name=dict(t.name or {}),
        source_language=t.source_language,
        trade=t.trade,
        trade_name=next((o.label for o in trades if o.value == t.trade), None),
        minutes=t.minutes,
        status=t.status,
        version=t.version,
        used_by=(await _used_by(db, [t.id])).get(t.id, 0),
        updated_at=t.updated_at,
        languages=languages(t, qs),
        questions=[
            AdminChecklistQuestion(
                id=x.id,
                position=x.position,
                type=x.type,
                text=dict(x.text or {}),
                help=dict(x.help or {}),
                text_status=dict(x.text_status or {}),
                options=[AdminChecklistOption(key=o["key"], label=dict(o["label"])) for o in x.options or []],
                unit=x.unit,
                min_value=x.min_value,
                max_value=x.max_value,
                photo_rule=x.photo_rule,
                required=x.required,
                condition=x.condition,
            )
            for x in qs
        ],
        ai_available=get_ai() is not None,
        trades=trades,
    )


async def create(db: AsyncSession, body: AdminChecklistCreate, *, staff_id: uuid.UUID) -> ChecklistTemplate:
    await check_trade(db, body.trade)
    t = ChecklistTemplate(
        company_id=None, trade=body.trade, name={"en": body.name.strip()}, source_language="en",
        minutes=body.minutes, status="draft",
    )  # fmt: skip
    db.add(t)
    await db.flush()
    await audit.record(
        db, "staff.checklist_created", staff_id=staff_id, target_type="checklist_template", target_id=t.id,
        data={"name": body.name.strip()},
    )  # fmt: skip
    return t


async def _log(db: AsyncSession, t: ChecklistTemplate, staff_id: uuid.UUID, data: dict) -> None:
    await audit.record(
        db,
        "staff.checklist_updated",
        staff_id=staff_id,
        target_type="checklist_template",
        target_id=t.id,
        data=data,
    )


async def update(
    db: AsyncSession, t: ChecklistTemplate, body: AdminChecklistPatch, *, staff_id: uuid.UUID
) -> None:
    changed: dict = {}
    if body.name is not None and body.name.strip() != t.name.get(t.source_language):
        t.name = {**t.name, t.source_language: body.name.strip()}
        changed["name"] = True
    if body.names:
        t.name = {
            **t.name,
            **{k: v.strip() for k, v in body.names.items() if k != t.source_language and v.strip()},
        }
        changed["names"] = sorted(body.names)
    if body.trade is not None and body.trade != t.trade:
        await check_trade(db, body.trade)
        changed["trade"] = {"from": t.trade, "to": body.trade}
        t.trade = body.trade
    if body.minutes is not None:
        t.minutes = body.minutes
    if body.status is not None and body.status != t.status:
        if body.status == "published" and not await questions(db, t.id):
            raise AppError(
                "validation_error", "Add at least one question first.", fields={"status": "no_questions"}
            )
        changed["status"] = {"from": t.status, "to": body.status}
        t.status = body.status
    if changed:
        t.version += 1
        await _log(db, t, staff_id, changed)
    await db.flush()


async def approve(db: AsyncSession, t: ChecklistTemplate, language: str, *, staff_id: uuid.UUID) -> int:
    """Mark every machine translation in one language as checked."""
    n = 0
    for q in await questions(db, t.id):
        if (q.text or {}).get(language) and (q.text_status or {}).get(language) == "needs_review":
            q.text_status = {**q.text_status, language: "ready"}
            n += 1
    if n:
        await _log(db, t, staff_id, {"approved": language, "questions": n})
    await db.flush()
    return n


async def untranslated(db: AsyncSession, t: ChecklistTemplate) -> list[uuid.UUID]:
    out = []
    for q in await questions(db, t.id):
        if any(not (q.text or {}).get(lg) for lg in LANGS if lg != t.source_language):
            out.append(q.id)
    return out
