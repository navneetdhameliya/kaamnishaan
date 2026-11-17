"""M36 Ask KaamNishaan AI: owners and managers ask about their company's jobs in plain words.

The answer comes only from the company's own jobs and reports, which are sent to the AI with the
question; the AI also says which reports and jobs it used, so the app can show them. Each question
counts toward the plan's monthly AI questions; at the limit, chat pauses until the next month.
"""

import logging
import re
import uuid
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Forbidden, PlanLimit
from app.core.security import now
from app.models import AssistantMessage, Customer, Evidence, Job, Plan, Report, Site, User
from app.providers.ai import LANGUAGE_NAMES, get_ai
from app.schemas.assistant import AskOut, AssistantMessageOut, AssistantOut, SourceJob, SourceReport
from app.services import credits
from app.services.evidence import photo_counts, thumbs_for
from app.services.jobs import CLOSED
from app.services.jobs import label as jlabel
from app.services.reports import rlabel

log = logging.getLogger("kn.assistant")

PROMPT = """You help the office of a small HVAC service company with questions about their own jobs.
The second message is JSON with today's date and the company's jobs (customer, address, date, status,
technician, photos, proof steps still missing, and the report with its summary and work done).

Rules:
- Answer only from that JSON. If it isn't there, say you couldn't find it in the company's jobs.
- Answer in {language}, in 1 to 3 short, plain sentences. No lists, no markdown.
- Write dates like "12 August". Use people's first names.
- Reply as JSON: {{"answer": "...", "report_ids": [...], "job_ids": [...]}} with the ids (at most 3 each)
  of the reports and jobs your answer is about. Use report_ids for finished work, job_ids for open jobs."""

STEPS = ("before", "during", "after")
HISTORY = 6
FAILED = "The assistant couldn't answer. Please try again."
RECENT_JOBS = 40
MATCHED_JOBS = 20


def _office(p: Principal) -> None:
    if "jobs.view_all" not in p.permissions:
        raise Forbidden("forbidden", "Only owners and managers can use the assistant.")


async def _usage(db: AsyncSession, p: Principal) -> tuple[int, int | None, datetime]:
    start, end = credits.cycle(p.company)
    used = await db.scalar(
        select(func.count()).where(
            AssistantMessage.company_id == p.company_id,
            AssistantMessage.role == "user",
            AssistantMessage.at >= start,
        )
    )
    plan = await db.get(Plan, p.company.plan_code)
    return used or 0, plan.ai_questions_monthly if plan else 0, end


async def questions_used(db: AsyncSession, company_id: uuid.UUID, since: datetime) -> int:
    return (
        await db.scalar(
            select(func.count()).where(
                AssistantMessage.company_id == company_id,
                AssistantMessage.role == "user",
                AssistantMessage.at >= since,
            )
        )
    ) or 0


# ---- the jobs the AI may read --------------------------------------------------------------------
async def _missing(db: AsyncSession, jobs: list[Job]) -> dict[uuid.UUID, list[str]]:
    from app.services.checklists import checklist_progress
    from app.services.voice import count_for_job

    open_jobs = [j for j in jobs if j.status not in CLOSED][:15]
    if not open_jobs:
        return {}
    stages: dict[uuid.UUID, set[str]] = {}
    for job_id, stage in (
        await db.execute(
            select(Evidence.job_id, Evidence.stage)
            .where(Evidence.job_id.in_([j.id for j in open_jobs]), Evidence.deleted_at.is_(None))
            .distinct()
        )
    ).all():
        stages.setdefault(job_id, set()).add(stage)
    out = {}
    for j in open_jobs:
        miss = [s for s in STEPS if s not in stages.get(j.id, set())]
        done, total = await checklist_progress(db, j.id)
        if total and done < total:
            miss.append("checklists")
        if not await count_for_job(db, j.id):
            miss.append("voice")
        out[j.id] = miss
    return out


async def _jobs(db: AsyncSession, p: Principal, question: str) -> list[Job]:
    recent = list(
        (
            await db.execute(
                select(Job)
                .where(Job.company_id == p.company_id)
                .order_by(func.coalesce(Job.scheduled_at, Job.created_at).desc())
                .limit(RECENT_JOBS)
            )
        ).scalars()
    )
    words = [w for w in re.findall(r"\w+", question.lower()) if len(w) >= 3]
    matched: list[Job] = []
    if words:
        like = [Customer.name.ilike(f"%{w}%") for w in words] + [Job.title.ilike(f"%{w}%") for w in words]
        matched = list(
            (
                await db.execute(
                    select(Job)
                    .join(Customer, Customer.id == Job.customer_id)
                    .where(Job.company_id == p.company_id, or_(*like))
                    .order_by(func.coalesce(Job.scheduled_at, Job.created_at).desc())
                    .limit(MATCHED_JOBS)
                )
            ).scalars()
        )
    seen, out = set(), []
    for j in matched + recent:
        if j.id not in seen:
            seen.add(j.id)
            out.append(j)
    return out


async def _context(db: AsyncSession, p: Principal, jobs: list[Job]) -> dict:
    zone = ZoneInfo(p.company.timezone or "UTC")
    ids = [j.id for j in jobs]
    customers = dict(
        (
            await db.execute(
                select(Customer.id, Customer.name).where(Customer.id.in_({j.customer_id for j in jobs}))
            )
        ).all()
    )
    sites = {
        s.id: ", ".join(x for x in (s.address_line1, s.city) if x)
        for s in (
            await db.execute(select(Site).where(Site.id.in_({j.site_id for j in jobs if j.site_id})))
        ).scalars()
    }
    people = dict(
        (
            await db.execute(
                select(User.id, User.name).where(User.id.in_({j.assigned_to for j in jobs if j.assigned_to}))
            )
        ).all()
    )
    reports: dict[uuid.UUID, Report] = {}
    for r in (
        await db.execute(select(Report).where(Report.job_id.in_(ids)).order_by(Report.created_at))
    ).scalars():
        reports[r.job_id] = r  # the newest per job
    photos = await photo_counts(db, ids)
    missing = await _missing(db, jobs)

    def day(t: datetime | None) -> str | None:
        return t.astimezone(zone).strftime("%Y-%m-%d %H:%M") if t else None

    return {
        "today": now().astimezone(zone).strftime("%Y-%m-%d"),
        "jobs": [
            {
                "job_id": str(j.id),
                "number": jlabel(j.number),
                "title": j.title,
                "customer": customers.get(j.customer_id),
                "address": sites.get(j.site_id),
                "scheduled": day(j.scheduled_at),
                "completed": day(j.completed_at),
                "status": j.status,
                "technician": people.get(j.assigned_to),
                "photos": photos.get(j.id, 0),
                "missing_proof": missing.get(j.id),
                "report": {
                    "report_id": str(r.id),
                    "number": rlabel(r.number),
                    "status": r.status,
                    "date": day(r.created_at),
                    "summary": r.summary,
                    "work_done": r.work_done,
                }
                if (r := reports.get(j.id))
                else None,
            }
            for j in jobs
        ],
    }


# ---- messages ------------------------------------------------------------------------------------
async def _out(db: AsyncSession, p: Principal, msgs: list[AssistantMessage]) -> list[AssistantMessageOut]:
    report_ids = {uuid.UUID(x) for m in msgs for x in (m.sources or {}).get("reports", [])}
    job_ids = {uuid.UUID(x) for m in msgs for x in (m.sources or {}).get("jobs", [])}
    reports = {
        r.id: (r, j, name)
        for r, j, name in (
            await db.execute(
                select(Report, Job, Customer.name)
                .join(Job, Job.id == Report.job_id)
                .join(Customer, Customer.id == Job.customer_id)
                .where(Report.id.in_(report_ids), Report.company_id == p.company_id)
            )
        ).all()
    }
    jobs = {
        j.id: (j, name)
        for j, name in (
            await db.execute(
                select(Job, Customer.name)
                .join(Customer, Customer.id == Job.customer_id)
                .where(Job.id.in_(job_ids), Job.company_id == p.company_id)
            )
        ).all()
    }
    all_jobs = {j.id for _, j, _ in reports.values()} | set(jobs)
    thumbs = await thumbs_for(db, list(all_jobs), each=3)
    counts = await photo_counts(db, list(all_jobs))
    missing = await _missing(db, [j for j, _ in jobs.values()])
    out = []
    for m in msgs:
        src = m.sources or {}
        rs = [reports[uuid.UUID(x)] for x in src.get("reports", []) if uuid.UUID(x) in reports]
        js = [jobs[uuid.UUID(x)] for x in src.get("jobs", []) if uuid.UUID(x) in jobs]
        used = {j.id for _, j, _ in rs} | {j.id for j, _ in js}
        out.append(
            AssistantMessageOut(
                id=m.id,
                role=m.role,
                text=m.text,
                at=m.at,
                reports=[
                    SourceReport(
                        id=r.id,
                        number=rlabel(r.number),
                        job_id=j.id,
                        customer=name,
                        status=r.status,
                        at=r.created_at,
                        cover_url=(thumbs.get(j.id) or [None])[0],
                    )
                    for r, j, name in rs
                ],  # fmt: skip
                jobs=[
                    SourceJob(
                        id=j.id,
                        title=j.title,
                        customer=name,
                        status=j.status,
                        photos=thumbs.get(j.id, []),
                        missing=missing.get(j.id, []),
                    )
                    for j, name in js
                ],  # fmt: skip
                photo_count=sum(counts.get(x, 0) for x in used),
            )
        )
    return out


async def state(db: AsyncSession, p: Principal) -> AssistantOut:
    _office(p)
    used, limit, renews = await _usage(db, p)
    msgs = list(
        reversed(
            (
                await db.execute(
                    select(AssistantMessage)
                    .where(AssistantMessage.company_id == p.company_id, AssistantMessage.user_id == p.user.id)
                    .order_by(AssistantMessage.at.desc())
                    .limit(30)
                )
            )
            .scalars()
            .all()
        )
    )
    return AssistantOut(
        data=await _out(db, p, msgs),
        used=used,
        limit=limit,
        paused=limit is not None and used >= limit,
        renews_at=renews,
        available=get_ai() is not None,
    )


async def ask(db: AsyncSession, p: Principal, text: str) -> AskOut:
    _office(p)
    used, limit, renews = await _usage(db, p)
    if limit is not None and used >= limit:
        raise PlanLimit(
            "ai_limit_reached",
            "This month's AI questions are used up.",
            {"used": used, "limit": limit, "renews_at": renews.isoformat()},
        )
    ai = get_ai()
    if ai is None:
        raise AppError("assistant_unavailable", "The assistant isn't switched on yet.", status=503)
    history = list(
        reversed(
            (
                await db.execute(
                    select(AssistantMessage)
                    .where(AssistantMessage.company_id == p.company_id, AssistantMessage.user_id == p.user.id)
                    .order_by(AssistantMessage.at.desc())
                    .limit(HISTORY)
                )
            )
            .scalars()
            .all()
        )
    )
    jobs = await _jobs(db, p, text)
    context = await _context(db, p, jobs)
    lang = p.user.app_language or "en"
    try:
        result = await ai.answer(
            PROMPT.format(language=LANGUAGE_NAMES.get(lang, "English")),
            context,
            [{"role": m.role, "content": m.text} for m in history],
            text,
        )
        answer = str(result.data.get("answer") or "").strip()
    except Exception:  # noqa: BLE001 - any AI failure: nothing is counted, the person can ask again
        log.exception("assistant answer failed")
        raise AppError(
            "assistant_failed", "The assistant couldn't answer. Please try again.", status=502
        ) from None
    if not answer:
        raise AppError("assistant_failed", "The assistant couldn't answer. Please try again.", status=502)
    known_reports = {j["report"]["report_id"] for j in context["jobs"] if j["report"]}
    known_jobs = {j["job_id"] for j in context["jobs"]}
    sources = {
        "reports": [x for x in map(str, result.data.get("report_ids") or []) if x in known_reports][:3],
        "jobs": [x for x in map(str, result.data.get("job_ids") or []) if x in known_jobs][:3],
    }
    t = now()
    q = AssistantMessage(company_id=p.company_id, user_id=p.user.id, role="user", text=text, at=t)
    a = AssistantMessage(
        company_id=p.company_id,
        user_id=p.user.id,
        role="assistant",
        text=answer,
        sources=sources,
        at=t + timedelta(microseconds=1),  # always just after its question
    )
    db.add_all([q, a])
    await db.flush()
    qo, ao = await _out(db, p, [q, a])
    used += 1
    return AskOut(question=qo, answer=ao, used=used, limit=limit, paused=limit is not None and used >= limit)
