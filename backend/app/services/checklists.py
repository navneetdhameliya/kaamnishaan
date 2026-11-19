"""Checklist templates and job checklists (API document: Evidence, checklists and voice).

- Global templates (company_id null) are made by KaamNishaan; companies use them as they are or copy
  them to edit (M26). Company templates are edited by owners and managers.
- Attaching a template to a job copies its questions into the job checklist (a snapshot), so editing
  the template later never changes a running job.
- Answers are saved one question at a time (M25). The photo rule is enforced: "photo_required" until a
  photo of this job is attached. Questions with a "show if" condition only count when shown.
- Answers lock with the job's evidence when the report is submitted.
"""

import re
import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.core.security import now
from app.models import (
    ChecklistAnswer,
    ChecklistQuestion,
    ChecklistTemplate,
    Evidence,
    Industry,
    Job,
    JobChecklist,
    ManagerQuestion,
    ShotSlot,
    User,
)
from app.providers.storage import get_storage
from app.schemas.checklists import (
    AnswerIn,
    AnswerOut,
    JobChecklistItem,
    JobChecklistList,
    ManagerQuestionIn,
    ManagerQuestionList,
    ManagerQuestionOut,
    OptionOut,
    PublicChecklistQuestion,
    PublicChecklistTemplate,
    PublicChecklistTemplates,
    QuestionIn,
    QuestionOut,
    QuestionPatch,
    SubmissionOut,
    TemplateCreate,
    TemplateList,
    TemplateListItem,
    TemplateOut,
    TemplatePatch,
    TemplateQuestionOut,
)
from app.schemas.identity import ListMeta
from app.schemas.work import PersonRef
from app.services import audit
from app.services.evidence import CAPTURE_STATUSES, take_upload
from app.services.evidence import _out as evidence_out
from app.services.jobs import actions as job_actions
from app.services.jobs import get_job

LANGS = ("en", "hi", "gu", "es", "fr")


def pick(texts: dict | None, lang: str, source: str = "en") -> str:
    texts = texts or {}
    return texts.get(lang) or texts.get(source) or texts.get("en") or next(iter(texts.values()), "")


def _status_for(statuses: dict | None, texts: dict | None, lang: str) -> str:
    if not (texts or {}).get(lang):
        return "missing"
    return (statuses or {}).get(lang, "ready")


def _slug(label: str, taken: set[str]) -> str:
    base = re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")[:30] or "option"
    key, n = base, 2
    while key in taken:
        key, n = f"{base}_{n}", n + 1
    return key


# ---- templates --------------------------------------------------------------------------------
def _visible_templates(p: Principal):
    return select(ChecklistTemplate).where(
        or_(
            (ChecklistTemplate.company_id.is_(None)) & (ChecklistTemplate.status == "published"),
            ChecklistTemplate.company_id == p.company_id,
        ),
        ChecklistTemplate.status != "archived",
    )


async def get_template(db: AsyncSession, p: Principal, template_id: uuid.UUID) -> ChecklistTemplate:
    t = (
        await db.execute(_visible_templates(p).where(ChecklistTemplate.id == template_id))
    ).scalar_one_or_none()
    if not t:
        raise NotFound("template_not_found", "Checklist not found.")
    return t


async def questions(db: AsyncSession, template_id: uuid.UUID) -> list[ChecklistQuestion]:
    return list(
        (
            await db.execute(
                select(ChecklistQuestion)
                .where(ChecklistQuestion.template_id == template_id, ChecklistQuestion.deleted_at.is_(None))
                .order_by(ChecklistQuestion.position)
                .execution_options(populate_existing=True)  # pick up background translations
            )
        ).scalars()
    )


def _lang(p: Principal, lang: str | None) -> str:
    return lang if lang in LANGS else (p.user.app_language or "en")


async def list_templates(db: AsyncSession, p: Principal, trade: str | None, lang: str | None) -> TemplateList:
    p.require("checklists.manage")
    lg = _lang(p, lang)
    q = _visible_templates(p)
    if trade:
        q = q.where(ChecklistTemplate.trade == trade)
    rows = list(
        (
            await db.execute(q.order_by(ChecklistTemplate.company_id.is_(None), ChecklistTemplate.created_at))
        ).scalars()
    )
    counts = dict(
        (
            await db.execute(
                select(ChecklistQuestion.template_id, func.count())
                .where(
                    ChecklistQuestion.template_id.in_([t.id for t in rows] or [uuid.uuid4()]),
                    ChecklistQuestion.deleted_at.is_(None),
                )
                .group_by(ChecklistQuestion.template_id)
            )
        ).all()
    )
    items = [
        TemplateListItem(
            id=t.id,
            name=pick(t.name, lg, t.source_language),
            trade=t.trade,
            minutes=t.minutes,
            scope="global" if t.company_id is None else "company",
            status=t.status,
            version=t.version,
            question_count=counts.get(t.id, 0),
            usage_count=t.usage_count,
            needs_translation=0,
        )
        for t in rows
    ]
    return TemplateList(
        data=items,
        meta=ListMeta(
            counts={
                "all": len(items),
                "global": sum(i.scope == "global" for i in items),
                "company": sum(i.scope == "company" for i in items),
            }
        ),
    )


def _question_out(q: ChecklistQuestion, lg: str, source: str) -> TemplateQuestionOut:
    storage = get_storage()
    return TemplateQuestionOut(
        id=q.id,
        position=q.position,
        type=q.type,
        text=pick(q.text, lg, source),
        text_all=q.text,
        text_status={x: _status_for(q.text_status, q.text, x) for x in LANGS},
        help=pick(q.help, lg, source) or None,
        options=[OptionOut(key=o["key"], label=pick(o["label"], lg, source)) for o in q.options or []],
        unit=q.unit,
        min_value=q.min_value,
        max_value=q.max_value,
        photo_rule=q.photo_rule,
        required=q.required,
        condition=q.condition,
        reference_image_url=storage.presign_get(q.reference_image_key) if q.reference_image_key else None,
    )


async def template_out(db: AsyncSession, p: Principal, t: ChecklistTemplate, lang: str | None) -> TemplateOut:
    lg = _lang(p, lang)
    qs = await questions(db, t.id)
    outs = [_question_out(q, lg, t.source_language) for q in qs]
    missing = sum(1 for o in outs for x in LANGS if o.text_status[x] != "ready")
    return TemplateOut(
        id=t.id,
        name=pick(t.name, lg, t.source_language),
        trade=t.trade,
        minutes=t.minutes,
        scope="global" if t.company_id is None else "company",
        status=t.status,
        version=t.version,
        question_count=len(qs),
        usage_count=t.usage_count,
        needs_translation=missing,
        language=lg,
        questions=outs,
        editable=t.company_id == p.company_id and "checklists.manage" in p.permissions,
    )


async def _editable(db: AsyncSession, p: Principal, template_id: uuid.UUID) -> ChecklistTemplate:
    p.require("checklists.manage")
    t = await get_template(db, p, template_id)
    if t.company_id is None:
        raise Forbidden(
            "global_template_read_only", "This is a KaamNishaan checklist. Make a copy to change it."
        )
    return t


async def check_trade(db: AsyncSession, trade: str | None) -> None:
    if trade and not await db.get(Industry, trade):
        raise AppError("validation_error", "Pick a trade from the list.", fields={"trade": "unknown"})


async def create_template(db: AsyncSession, p: Principal, body: TemplateCreate) -> ChecklistTemplate:
    p.require("checklists.manage")
    await check_trade(db, body.trade)
    lg = body.language or p.user.app_language or "en"
    t = ChecklistTemplate(
        company_id=p.company_id,
        trade=body.trade or p.company.industry_slug,
        name={lg: body.name},
        source_language=lg,
        minutes=body.minutes,
        status="draft",
        created_by=p.user.id,
    )
    db.add(t)
    await db.flush()
    await audit.record(
        db,
        "checklist.created",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="checklist_template",
        target_id=t.id,
        data={"name": body.name},
    )
    return t


async def update_template(
    db: AsyncSession, p: Principal, template_id: uuid.UUID, body: TemplatePatch
) -> ChecklistTemplate:
    t = await _editable(db, p, template_id)
    if body.name is not None:
        t.name = {**t.name, t.source_language: body.name}
    if body.trade is not None:
        await check_trade(db, body.trade)
        t.trade = body.trade
    if body.minutes is not None:
        t.minutes = body.minutes
    if body.status is not None:
        if body.status == "published" and not await questions(db, t.id):
            raise AppError(
                "validation_error", "Add at least one question first.", fields={"status": "no_questions"}
            )
        t.status = body.status
    await db.flush()
    return t


async def copy_template(db: AsyncSession, p: Principal, template_id: uuid.UUID) -> ChecklistTemplate:
    p.require("checklists.manage")
    src = await get_template(db, p, template_id)
    t = ChecklistTemplate(
        company_id=p.company_id,
        trade=src.trade,
        name=dict(src.name),
        source_language=src.source_language,
        minutes=src.minutes,
        status="published",
        copied_from=src.id,
        created_by=p.user.id,
    )
    db.add(t)
    await db.flush()
    mapping: dict[str, str] = {}
    old = await questions(db, src.id)
    for q in old:
        mapping[str(q.id)] = str(uuid.uuid4())
    for q in old:
        cond = dict(q.condition) if q.condition else None
        if cond:
            cond["question_id"] = mapping.get(cond["question_id"], cond["question_id"])
        db.add(
            ChecklistQuestion(
                id=uuid.UUID(mapping[str(q.id)]),
                template_id=t.id,
                position=q.position,
                type=q.type,
                text=dict(q.text),
                help=dict(q.help or {}),
                text_status=dict(q.text_status or {}),
                options=list(q.options or []),
                unit=q.unit,
                min_value=q.min_value,
                max_value=q.max_value,
                photo_rule=q.photo_rule,
                reference_image_key=q.reference_image_key,
                required=q.required,
                condition=cond,
            )
        )
    for sh in (await db.execute(select(ShotSlot).where(ShotSlot.template_id == src.id))).scalars():
        db.add(
            ShotSlot(
                template_id=t.id, stage=sh.stage, key=sh.key, prompt=dict(sh.prompt), position=sh.position
            )
        )
    await db.flush()
    return t


def _validate_question(
    q_type: str,
    photo_rule: str,
    options: list,
    min_v,
    max_v,
    condition,
    others: dict[str, ChecklistQuestion],
    position: int,
) -> None:
    if q_type == "choice" and len(options) < 2:
        raise AppError(
            "validation_error", "A choice question needs at least 2 options.", fields={"options": "too_few"}
        )
    if q_type != "choice" and options:
        raise AppError(
            "validation_error", "Only choice questions have options.", fields={"options": "not_allowed"}
        )
    if min_v is not None and max_v is not None and min_v >= max_v:
        raise AppError(
            "validation_error", "The lowest value must be below the highest.", fields={"min_value": "range"}
        )
    if photo_rule == "if_no" and q_type != "yes_no":
        raise AppError(
            "validation_error", "'Photo if No' needs a Yes/No question.", fields={"photo_rule": "type"}
        )
    if photo_rule == "if_fail" and q_type != "pass_fail":
        raise AppError(
            "validation_error", "'Photo if Fail' needs a Pass/Fail question.", fields={"photo_rule": "type"}
        )
    if photo_rule == "always" and q_type in ("photo", "signature"):
        raise AppError(
            "validation_error", "This question type already takes a picture.", fields={"photo_rule": "type"}
        )
    if condition:
        dep = others.get(str(condition["question_id"]))
        if not dep or dep.position >= position:
            raise AppError(
                "validation_error",
                "'Show if' must point to an earlier question.",
                fields={"condition": "unknown"},
            )
        allowed = {
            "yes_no": {"yes", "no"},
            "pass_fail": {"pass", "fail"},
            "choice": {o["key"] for o in dep.options or []},
        }.get(dep.type)
        if allowed is None:
            raise AppError(
                "validation_error",
                "'Show if' works with Yes/No, Pass/Fail or choice questions.",
                fields={"condition": "type"},
            )
        if str(condition["equals"]).lower() not in allowed:
            raise AppError(
                "validation_error", "That answer isn't one of the choices.", fields={"condition": "value"}
            )


async def _renumber(
    db: AsyncSession, template_id: uuid.UUID, moving: ChecklistQuestion | None, to: int | None
) -> None:
    qs = [q for q in await questions(db, template_id) if moving is None or q.id != moving.id]
    if moving is not None:
        idx = max(0, min(len(qs), (to or len(qs) + 1) - 1))
        qs.insert(idx, moving)
    for i, q in enumerate(qs, start=1):
        q.position = i


async def _bump(t: ChecklistTemplate) -> None:
    t.version += 1
    t.updated_at = now()


async def add_question(
    db: AsyncSession, p: Principal, template_id: uuid.UUID, body: QuestionIn
) -> ChecklistQuestion:
    t = await _editable(db, p, template_id)
    ref = None
    if body.reference_upload_id:
        up, _ = await take_upload(db, p, body.reference_upload_id, "photo")
        ref = up.key
    return await add_question_to(db, t, body, ref)


async def add_question_to(
    db: AsyncSession, t: ChecklistTemplate, body: QuestionIn, reference_key: str | None = None
) -> ChecklistQuestion:
    """Adds a question to any template (a company's, or KaamNishaan's from the admin panel)."""
    existing = await questions(db, t.id)
    position = min(body.position or len(existing) + 1, len(existing) + 1)
    src = t.source_language
    taken: set[str] = set()
    options = []
    for o in body.options:
        key = o.key or _slug(o.label, taken)
        taken.add(key)
        options.append({"key": key, "label": {src: o.label}})
    cond = (
        {"question_id": str(body.condition.question_id), "equals": str(body.condition.equals).lower()}
        if body.condition
        else None
    )
    _validate_question(
        body.type,
        body.photo_rule,
        options,
        body.min_value,
        body.max_value,
        cond,
        {str(q.id): q for q in existing},
        position,
    )
    q = ChecklistQuestion(
        template_id=t.id,
        position=position,
        type=body.type,
        text={src: body.text},
        help={src: body.help} if body.help else {},
        text_status={src: "ready"},
        options=options,
        unit=body.unit,
        min_value=body.min_value,
        max_value=body.max_value,
        photo_rule=body.photo_rule,
        required=body.required,
        condition=cond,
        reference_image_key=reference_key,
    )
    db.add(q)
    await db.flush()
    await _renumber(db, t.id, q, position)
    await _bump(t)
    await db.flush()
    return q


async def template_question(
    db: AsyncSession, t: ChecklistTemplate, question_id: uuid.UUID
) -> ChecklistQuestion:
    q = await db.get(ChecklistQuestion, question_id)
    if not q or q.template_id != t.id or q.deleted_at:
        raise NotFound("question_not_found", "Question not found.")
    return q


async def update_question(
    db: AsyncSession, p: Principal, template_id: uuid.UUID, question_id: uuid.UUID, body: QuestionPatch
) -> tuple[ChecklistQuestion, bool]:
    """Returns the question and whether its words changed (so translations must be redone)."""
    t = await _editable(db, p, template_id)
    q = await template_question(db, t, question_id)
    ref = None
    if body.reference_upload_id:
        up, _ = await take_upload(db, p, body.reference_upload_id, "photo")
        ref = up.key
    return await update_question_in(db, t, q, body, ref)


async def update_question_in(
    db: AsyncSession,
    t: ChecklistTemplate,
    q: ChecklistQuestion,
    body: QuestionPatch,
    reference_key: str | None = None,
) -> tuple[ChecklistQuestion, bool]:
    src = t.source_language
    words_changed = False
    if body.text is not None and body.text != q.text.get(src):
        q.text = {src: body.text}
        q.text_status = {src: "ready"}
        words_changed = True
    if body.help is not None:
        q.help = {src: body.help}
        words_changed = True
    if body.options is not None:
        taken: set[str] = set()
        opts = []
        for o in body.options:
            key = o.key or _slug(o.label, taken)
            taken.add(key)
            opts.append({"key": key, "label": {src: o.label}})
        q.options = opts
        words_changed = True
    for field in ("unit", "min_value", "max_value", "photo_rule", "required"):
        v = getattr(body, field)
        if v is not None:
            setattr(q, field, v)
    if body.clear_condition:
        q.condition = None
    elif body.condition:
        q.condition = {
            "question_id": str(body.condition.question_id),
            "equals": str(body.condition.equals).lower(),
        }
    if reference_key:
        q.reference_image_key = reference_key
    if body.translations:
        for lg, txt in body.translations.items():
            q.text = {**q.text, lg: txt}
            q.text_status = {**(q.text_status or {}), lg: "ready"}
    if body.position is not None:
        await _renumber(db, t.id, q, body.position)
    others = {str(x.id): x for x in await questions(db, t.id) if x.id != q.id}
    _validate_question(
        q.type, q.photo_rule, q.options or [], q.min_value, q.max_value, q.condition, others, q.position
    )
    await _bump(t)
    await db.flush()
    return q, words_changed


async def delete_question(
    db: AsyncSession, p: Principal, template_id: uuid.UUID, question_id: uuid.UUID
) -> None:
    t = await _editable(db, p, template_id)
    await delete_question_in(db, t, await template_question(db, t, question_id))


async def delete_question_in(db: AsyncSession, t: ChecklistTemplate, q: ChecklistQuestion) -> None:
    q.deleted_at = now()
    for other in await questions(db, t.id):  # questions that depended on it are always shown now
        if other.condition and other.condition.get("question_id") == str(q.id):
            other.condition = None
    await _renumber(db, t.id, None, None)
    await _bump(t)


# ---- job checklists ---------------------------------------------------------------------------
def _snapshot(q: ChecklistQuestion) -> dict:
    return {
        "id": str(q.id),
        "position": q.position,
        "type": q.type,
        "text": q.text,
        "text_status": q.text_status or {},
        "help": q.help or {},
        "options": q.options or [],
        "unit": q.unit,
        "min_value": q.min_value,
        "max_value": q.max_value,
        "photo_rule": q.photo_rule,
        "required": q.required,
        "condition": q.condition,
        "reference_image_key": q.reference_image_key,
    }


async def attach(db: AsyncSession, p: Principal, job: Job, template_id: uuid.UUID) -> JobChecklist:
    if "edit" not in job_actions(p, job) or job.status not in ("unassigned", "assigned", *CAPTURE_STATUSES):
        raise Forbidden("forbidden", "You can't add a checklist to this job.")
    t = await get_template(db, p, template_id)
    if t.status != "published":
        raise AppError(
            "validation_error", "Publish this checklist before using it.", fields={"template_id": "draft"}
        )
    exists = (
        await db.execute(
            select(JobChecklist.id).where(JobChecklist.job_id == job.id, JobChecklist.template_id == t.id)
        )
    ).first()
    if exists:
        raise Conflict("checklist_already_added", "This checklist is already on the job.")
    qs = await questions(db, t.id)
    snap = [_snapshot(q) for q in qs]
    jc = JobChecklist(
        company_id=p.company_id,
        job_id=job.id,
        template_id=t.id,
        template_version=t.version,
        name=t.name,
        minutes=t.minutes,
        questions=snap,
        total=_progress(snap, {})[1],
        added_by=p.user.id,
    )
    db.add(jc)
    t.usage_count += 1
    await db.flush()
    return jc


async def detach(db: AsyncSession, p: Principal, job_id: uuid.UUID, checklist_id: uuid.UUID) -> None:
    job = await get_job(db, p, job_id)
    jc = await _job_checklist(db, p, checklist_id)
    if jc.job_id != job.id:
        raise NotFound("checklist_not_found", "Checklist not found.")
    if "edit" not in job_actions(p, job):
        raise Forbidden("forbidden", "You can't change this job.")
    has_answers = (
        await db.execute(select(ChecklistAnswer.id).where(ChecklistAnswer.job_checklist_id == jc.id))
    ).first()
    if has_answers:
        raise Conflict("checklist_started", "Answers were already given. It can't be removed now.")
    await db.delete(jc)


async def _job_checklist(db: AsyncSession, p: Principal, checklist_id: uuid.UUID) -> JobChecklist:
    jc = (
        await db.execute(
            select(JobChecklist).where(
                JobChecklist.id == checklist_id, JobChecklist.company_id == p.company_id
            )
        )
    ).scalar_one_or_none()
    if not jc:
        raise NotFound("checklist_not_found", "Checklist not found.")
    await get_job(db, p, jc.job_id)  # visibility: technicians only their own jobs
    return jc


def _status(jc_answered: int, total: int, completed) -> str:
    return "done" if completed else ("in_progress" if jc_answered else "not_started")


async def list_for_job(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, lang: str | None
) -> JobChecklistList:
    job = await get_job(db, p, job_id)
    lg = _lang(p, lang)
    rows = (
        (
            await db.execute(
                select(JobChecklist).where(JobChecklist.job_id == job.id).order_by(JobChecklist.created_at)
            )
        )
        .scalars()
        .all()
    )
    items = [
        JobChecklistItem(
            id=jc.id,
            template_id=jc.template_id,
            name=pick(jc.name, lg),
            minutes=jc.minutes,
            answered=jc.answered_count,
            total=jc.total,
            status=_status(jc.answered_count, jc.total, jc.completed_at),
            completed_at=jc.completed_at,
        )
        for jc in rows
    ]
    done = sum(i.status == "done" for i in items)
    return JobChecklistList(data=items, meta=ListMeta(counts={"all": len(items), "done": done}))


def _visible(q: dict, by_id: dict[str, dict], answers: dict[str, ChecklistAnswer]) -> bool:
    cond = q.get("condition")
    if not cond:
        return True
    dep = by_id.get(cond["question_id"])
    if not dep or not _visible(dep, by_id, answers):
        return False
    a = answers.get(cond["question_id"])
    return a is not None and str(a.value.get("v")).lower() == str(cond["equals"]).lower()


def _needs_photo(q: dict, value) -> bool:
    rule = q.get("photo_rule", "none")
    return (
        q["type"] == "photo"
        or rule == "always"
        or (rule == "if_no" and str(value).lower() == "no")
        or (rule == "if_fail" and str(value).lower() == "fail")
    )


def _complete(q: dict, a: ChecklistAnswer | None) -> bool:
    if a is None:
        return False
    if _needs_photo(q, a.value.get("v")) and not a.photo_id:
        return False
    return not (q["type"] == "signature" and not a.signature_key)


def _progress(questions: list[dict], answers: dict[str, ChecklistAnswer]) -> tuple[int, int, bool]:
    """(answered, total, all required done) over the questions currently shown."""
    by_id = {q["id"]: q for q in questions}
    shown = [q for q in questions if _visible(q, by_id, answers)]
    answered = sum(1 for q in shown if _complete(q, answers.get(q["id"])))
    required_done = all(_complete(q, answers.get(q["id"])) for q in shown if q.get("required", True))
    return answered, len(shown), required_done


async def _answers(db: AsyncSession, jc: JobChecklist) -> dict[str, ChecklistAnswer]:
    rows = (
        await db.execute(select(ChecklistAnswer).where(ChecklistAnswer.job_checklist_id == jc.id))
    ).scalars()
    return {str(a.question_id): a for a in rows}


async def submission(
    db: AsyncSession, p: Principal, checklist_id: uuid.UUID, lang: str | None
) -> SubmissionOut:
    jc = await _job_checklist(db, p, checklist_id)
    lg = _lang(p, lang)
    answers = await _answers(db, jc)
    photos = {}
    photo_ids = [a.photo_id for a in answers.values() if a.photo_id]
    if photo_ids:
        rows = (await db.execute(select(Evidence).where(Evidence.id.in_(photo_ids)))).scalars().all()
        photos = {o.id: o for o in await evidence_out(db, list(rows))}
    users = {}
    if answers:
        users = {
            u.id: u
            for u in (
                await db.execute(select(User).where(User.id.in_({a.answered_by for a in answers.values()})))
            ).scalars()
        }
    storage = get_storage()
    by_id = {q["id"]: q for q in jc.questions}
    out = []
    for q in jc.questions:
        a = answers.get(q["id"])
        visible = _visible(q, by_id, answers)
        out.append(
            QuestionOut(
                id=uuid.UUID(q["id"]),
                position=q["position"],
                type=q["type"],
                text=pick(q["text"], lg),
                translation_status=_status_for(q.get("text_status"), q["text"], lg),
                help=pick(q.get("help"), lg) or None,
                options=[OptionOut(key=o["key"], label=pick(o["label"], lg)) for o in q.get("options", [])],
                unit=q.get("unit"),
                min_value=q.get("min_value"),
                max_value=q.get("max_value"),
                photo_rule=q.get("photo_rule", "none"),
                required=q.get("required", True),
                condition=q.get("condition"),
                visible=visible,
                photo_needed=visible
                and a is not None
                and _needs_photo(q, a.value.get("v"))
                and not a.photo_id,
                reference_image_url=storage.presign_get(q["reference_image_key"])
                if q.get("reference_image_key")
                else None,
                answer=AnswerOut(
                    value=a.value.get("v"),
                    photo=photos.get(a.photo_id),
                    answered_at=a.answered_at,
                    signature_url=storage.presign_get(a.signature_key) if a.signature_key else None,
                    answered_by=PersonRef(id=a.answered_by, name=users[a.answered_by].name or ""),
                    locked=a.locked_at is not None,
                )
                if a
                else None,
            )
        )
    locked = any(a.locked_at for a in answers.values())
    return SubmissionOut(
        id=jc.id,
        job_id=jc.job_id,
        name=pick(jc.name, lg),
        language=lg,
        answered=jc.answered_count,
        total=jc.total,
        status=_status(jc.answered_count, jc.total, jc.completed_at),
        locked=locked,
        questions=out,
    )


def _clean_value(q: dict, value):
    t = q["type"]
    if t == "yes_no":
        v = {"true": "yes", "false": "no"}.get(str(value).lower(), str(value).lower())
        if v not in ("yes", "no"):
            raise AppError("validation_error", "Answer Yes or No.", fields={"value": "yes_no"})
        return v
    if t == "pass_fail":
        v = str(value).lower()
        if v not in ("pass", "fail"):
            raise AppError("validation_error", "Answer Pass or Fail.", fields={"value": "pass_fail"})
        return v
    if t == "number":
        try:
            v = float(value)
        except (TypeError, ValueError) as e:
            raise AppError("validation_error", "Type a number.", fields={"value": "number"}) from e
        lo, hi = q.get("min_value"), q.get("max_value")
        if (lo is not None and v < lo) or (hi is not None and v > hi):
            raise AppError(
                "validation_error",
                "This number looks wrong. Please check it.",
                {"min_value": lo, "max_value": hi},
                fields={"value": "out_of_range"},
            )
        return v
    if t == "text":
        v = str(value or "").strip()
        if not v:
            raise AppError("validation_error", "Please write an answer.", fields={"value": "required"})
        return v[:1000]
    if t == "choice":
        keys = {o["key"] for o in q.get("options", [])}
        if str(value) not in keys:
            raise AppError("validation_error", "Pick one of the choices.", fields={"value": "choice"})
        return str(value)
    return None  # photo, signature: the attachment is the answer


async def answer(
    db: AsyncSession, p: Principal, checklist_id: uuid.UUID, question_id: uuid.UUID, body: AnswerIn
) -> JobChecklist:
    p.require("evidence.capture")
    jc = await _job_checklist(db, p, checklist_id)
    job = await get_job(db, p, jc.job_id, lock=True)
    answers = await _answers(db, jc)
    current = answers.get(str(question_id))
    if current and current.locked_at:
        raise Conflict("evidence_locked", "The report was sent, so answers are locked.")
    if body.client_uuid and current and current.client_uuid == body.client_uuid:
        return jc  # a retry of the same answer
    if job.status not in CAPTURE_STATUSES:
        if job.status in ("in_review", "completed"):
            raise Conflict("evidence_locked", "The report was sent, so answers are locked.")
        raise Conflict("job_not_started", "Start the job before answering.", {"status": job.status})
    by_id = {q["id"]: q for q in jc.questions}
    q = by_id.get(str(question_id))
    if not q:
        raise NotFound("question_not_found", "Question not found.")
    if not _visible(q, by_id, answers):
        raise AppError("question_hidden", "This question is not shown for the earlier answers.")
    value = _clean_value(q, body.value)
    if body.photo_id:
        ev = (
            await db.execute(
                select(Evidence).where(
                    Evidence.id == body.photo_id, Evidence.job_id == job.id, Evidence.deleted_at.is_(None)
                )
            )
        ).scalar_one_or_none()
        if not ev:
            raise AppError(
                "validation_error", "Use a photo taken on this job.", fields={"photo_id": "unknown"}
            )
    photo_id = body.photo_id or (current.photo_id if current else None)
    if _needs_photo(q, value) and not photo_id:
        raise AppError(
            "photo_required",
            "Take a photo to answer this question.",
            {"question_id": str(question_id)},
            fields={"photo_id": "required"},
        )
    signature_key = current.signature_key if current else None
    if q["type"] == "signature":
        if body.signature_upload_id:
            up, _ = await take_upload(db, p, body.signature_upload_id, "signature")
            signature_key = up.key
        if not signature_key:
            raise AppError(
                "validation_error", "Add the signature.", fields={"signature_upload_id": "required"}
            )
    t = now()
    if current:
        current.value, current.photo_id, current.signature_key = {"v": value}, photo_id, signature_key
        current.answered_by, current.answered_at, current.client_uuid = p.user.id, t, body.client_uuid
    else:
        current = ChecklistAnswer(
            company_id=p.company_id,
            job_checklist_id=jc.id,
            question_id=question_id,
            client_uuid=body.client_uuid,
            value={"v": value},
            photo_id=photo_id,
            signature_key=signature_key,
            answered_by=p.user.id,
            answered_at=t,
        )
        db.add(current)
    answers[str(question_id)] = current
    answered, total, done = _progress(jc.questions, answers)
    jc.answered_count, jc.total = answered, total
    jc.started_at = jc.started_at or t
    jc.completed_at = (jc.completed_at or t) if done else None
    await db.flush()
    return jc


async def checklist_progress(db: AsyncSession, job_id: uuid.UUID) -> tuple[int, int]:
    """(done checklists, all checklists) for the capture hub."""
    rows = (
        (await db.execute(select(JobChecklist.completed_at).where(JobChecklist.job_id == job_id)))
        .scalars()
        .all()
    )
    return sum(1 for r in rows if r), len(rows)


async def shot_prompts(db: AsyncSession, job_id: uuid.UUID) -> list[tuple[str, str, dict]]:
    """(stage, key, prompt) for the job's checklists, for the camera (M20)."""
    rows = (
        await db.execute(
            select(ShotSlot)
            .join(JobChecklist, JobChecklist.template_id == ShotSlot.template_id)
            .where(JobChecklist.job_id == job_id)
            .order_by(ShotSlot.stage, ShotSlot.position)
        )
    ).scalars()
    seen, out = set(), []
    for sh in rows:
        if sh.key not in seen:
            seen.add(sh.key)
            out.append((sh.stage, sh.key, sh.prompt))
    return out


# ---- manager questions ------------------------------------------------------------------------
async def _mq_out(db: AsyncSession, rows: list[ManagerQuestion]) -> list[ManagerQuestionOut]:
    if not rows:
        return []
    uids = {r.asked_by for r in rows} | {r.answered_by for r in rows if r.answered_by}
    users = {u.id: u for u in (await db.execute(select(User).where(User.id.in_(uids)))).scalars()}
    pids = [r.photo_id for r in rows if r.photo_id]
    photos = {}
    if pids:
        photos = {
            o.id: o
            for o in await evidence_out(
                db, list((await db.execute(select(Evidence).where(Evidence.id.in_(pids)))).scalars())
            )
        }
    return [
        ManagerQuestionOut(
            id=r.id,
            job_id=r.job_id,
            job_checklist_id=r.job_checklist_id,
            question_id=r.question_id,
            photo=photos.get(r.photo_id),
            text=r.text,
            asked_at=r.created_at,
            asked_by=PersonRef(id=r.asked_by, name=users[r.asked_by].name or ""),
            answer=r.answer,
            answered_by=PersonRef(id=r.answered_by, name=users[r.answered_by].name or "")
            if r.answered_by
            else None,
            answered_at=r.answered_at,
        )
        for r in rows
    ]


async def ask_manager(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, body: ManagerQuestionIn
) -> ManagerQuestionOut:
    p.require("evidence.capture")
    job = await get_job(db, p, job_id)
    if body.job_checklist_id:
        jc = await _job_checklist(db, p, body.job_checklist_id)
        if jc.job_id != job.id:
            raise AppError(
                "validation_error",
                "That checklist is not on this job.",
                fields={"job_checklist_id": "unknown"},
            )
    if body.photo_id:
        ev = await db.get(Evidence, body.photo_id)
        if not ev or ev.job_id != job.id or ev.deleted_at:
            raise AppError(
                "validation_error", "Use a photo taken on this job.", fields={"photo_id": "unknown"}
            )
    mq = ManagerQuestion(
        company_id=p.company_id,
        job_id=job.id,
        job_checklist_id=body.job_checklist_id,
        question_id=body.question_id,
        photo_id=body.photo_id,
        text=body.text,
        asked_by=p.user.id,
    )
    db.add(mq)
    await db.flush()
    return (await _mq_out(db, [mq]))[0]


async def list_manager_questions(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> ManagerQuestionList:
    job = await get_job(db, p, job_id)
    rows = list(
        (
            await db.execute(
                select(ManagerQuestion)
                .where(ManagerQuestion.job_id == job.id)
                .order_by(ManagerQuestion.created_at)
            )
        ).scalars()
    )
    open_ = sum(1 for r in rows if r.answer is None)
    return ManagerQuestionList(
        data=await _mq_out(db, rows),
        meta=ListMeta(counts={"all": len(rows), "open": open_, "answered": len(rows) - open_}),
    )


async def answer_manager_question(
    db: AsyncSession, p: Principal, question_id: uuid.UUID, text: str
) -> ManagerQuestionOut:
    p.require("jobs.view_all")
    mq = (
        await db.execute(
            select(ManagerQuestion).where(
                ManagerQuestion.id == question_id, ManagerQuestion.company_id == p.company_id
            )
        )
    ).scalar_one_or_none()
    if not mq:
        raise NotFound("manager_question_not_found", "Question not found.")
    mq.answer, mq.answered_by, mq.answered_at = text, p.user.id, now()
    await db.flush()
    return (await _mq_out(db, [mq]))[0]


async def lock_answers(db: AsyncSession, job_id: uuid.UUID) -> int:
    from sqlalchemy import update

    ids = select(JobChecklist.id).where(JobChecklist.job_id == job_id)
    r = await db.execute(
        update(ChecklistAnswer)
        .where(ChecklistAnswer.job_checklist_id.in_(ids), ChecklistAnswer.locked_at.is_(None))
        .values(locked_at=now())
    )
    return r.rowcount or 0


async def ready_templates(db: AsyncSession, trade: str, lang: str) -> PublicChecklistTemplates:
    """KaamNishaan's own published checklists for one trade, for the website's industry pages (no login)."""
    rows = list(
        (
            await db.execute(
                select(ChecklistTemplate)
                .where(
                    ChecklistTemplate.company_id.is_(None),
                    ChecklistTemplate.status == "published",
                    ChecklistTemplate.trade == trade,
                )
                .order_by(ChecklistTemplate.usage_count.desc(), ChecklistTemplate.created_at)
            )
        ).scalars()
    )
    items = []
    for t in rows:
        qs = await questions(db, t.id)
        items.append(
            PublicChecklistTemplate(
                key=t.key,
                name=pick(t.name, lang, t.source_language),
                minutes=t.minutes,
                question_count=len(qs),
                photo_questions=sum(1 for q in qs if q.type == "photo" or q.photo_rule != "none"),
                languages=[x for x in LANGS if qs and all((q.text or {}).get(x) for q in qs)],
                questions=[
                    PublicChecklistQuestion(
                        text=pick(q.text, lang, t.source_language),
                        type=q.type,
                        unit=q.unit,
                        photo_rule=q.photo_rule,
                        required=q.required,
                    )
                    for q in qs
                ],
            )
        )
    return PublicChecklistTemplates(trade=trade, language=lang, items=items)
