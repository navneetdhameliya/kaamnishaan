"""Report flow (API document: Reports, PDF and sharing; State machines → Report and Job).

POST /jobs/{id}/reports   evidence ready -> report generating (202 + task), job stays in progress
submit                    draft / changes_requested -> pending_review; evidence locks; job in_review
approve                   pending_review -> approved; job completed      (owner, manager)
request-changes           pending_review -> changes_requested; job changes_requested
"""

import math
import uuid
from datetime import timedelta

from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound, PlanLimit
from app.core.paging import check_version, decode_cursor, next_cursor
from app.core.security import now
from app.models import (
    BackgroundTask,
    ChangeRequest,
    Customer,
    Evidence,
    Job,
    JobEvent,
    Report,
    ReportVersion,
    User,
)
from app.providers.storage import get_storage
from app.schemas.identity import ListMeta
from app.schemas.reports import (
    ChangeRequestOut,
    EvidenceSummary,
    JobBrief,
    ReportFlag,
    ReportList,
    ReportListItem,
    ReportOut,
    ReportPatch,
    SentenceLink,
    TaskOut,
    TaskStep,
    VersionList,
    VersionOut,
)
from app.schemas.work import PersonRef
from app.services import audit, notifications
from app.services.evidence import covers, lock_job_evidence, photo_counts, proof, thumbs_for
from app.services.jobs import get_job, label

SECTIONS = ("summary", "work_done", "advice")
EDITABLE = ("draft", "changes_requested", "generation_failed")
DONE = ("approved", "shared", "acknowledged")


def rlabel(n: int) -> str:
    return f"R-{n}"


# ---- who may do what ---------------------------------------------------------------------------
def _is_author(p: Principal, job: Job) -> bool:
    return job.assigned_to == p.user.id


def actions(p: Principal, rep: Report, job: Job) -> list[str]:
    manager = "reports.approve" in p.permissions
    author = _is_author(p, job) or "reports.edit" in p.permissions
    a = []
    if rep.status in EDITABLE and author:
        a += ["edit", "regenerate", "redraft"]
    if rep.status == "pending_review" and manager:
        a.append("edit")
    if rep.status in ("draft", "changes_requested") and author:
        a.append("submit")
    if rep.status == "pending_review" and manager:
        a += ["approve", "request_changes"]
    if rep.status in DONE and "reports.share" in p.permissions:
        a.append("share")
    return list(dict.fromkeys(a))


def _visible(p: Principal):
    q = (
        select(Report, Job)
        .join(Job, Job.id == Report.job_id)
        .where(Report.company_id == p.company_id, Job.deleted_at.is_(None))
    )
    if "jobs.view_all" not in p.permissions:
        q = q.where(Job.assigned_to == p.user.id)
    return q


async def get_report(
    db: AsyncSession, p: Principal, report_id: uuid.UUID, lock: bool = False
) -> tuple[Report, Job]:
    q = _visible(p).where(Report.id == report_id)
    if lock:
        q = q.with_for_update(of=Report)
    row = (await db.execute(q)).first()
    if not row:
        raise NotFound("report_not_found", "Report not found.")
    return row[0], row[1]


# ---- tasks ------------------------------------------------------------------------------------
async def get_task(db: AsyncSession, p: Principal, task_id: uuid.UUID) -> TaskOut:
    bt = await db.get(BackgroundTask, task_id)
    if not bt or (bt.company_id and bt.company_id != (p.company.id if p.company else None)):
        raise NotFound("task_not_found", "Task not found.")
    return TaskOut(
        id=bt.id,
        type=bt.type,
        status=bt.status,
        steps=[TaskStep(**s) for s in bt.steps or []],
        target_type=bt.target_type,
        target_id=bt.target_id,
        error=bt.error,
        created_at=bt.created_at,
        finished_at=bt.finished_at,
    )


async def _new_task(db: AsyncSession, p: Principal, type_: str, rep: Report) -> BackgroundTask:
    from app.tasks.reports import _steps

    bt = BackgroundTask(
        company_id=p.company_id,
        user_id=p.user.id,
        type=type_,
        status="queued",
        steps=_steps(0),
        target_type="report",
        target_id=rep.id,
    )
    db.add(bt)
    await db.flush()
    rep.task_id = bt.id
    return bt


# ---- start / redraft ----------------------------------------------------------------------------
NEAR_LIMIT = 0.8  # the owner hears when 80% of the month's reports are used (D-143)


def limit_stage(made: int, limit: int) -> str | None:
    """'reached' with the month's last report, 'near' with the one that crosses 80%, else nothing."""
    if made == limit:
        return "reached"
    return "near" if made == math.ceil(limit * NEAR_LIMIT) else None


async def _check_report_limit(db: AsyncSession, p: Principal, company, job) -> None:
    """M41 "You used 60 of 60 reports": no new report past the plan's monthly number. Photos, checklists
    and notes are kept; the report can be made next month or after an upgrade.

    The owner gets a message in the app (D-143): at 80%, when the last report is made, and once a month
    when someone could not make a report because none were left."""
    from app.models import Notification, Plan
    from app.services.credits import cycle

    plan = await db.get(Plan, company.plan_code)
    if plan is None or plan.report_limit_monthly is None:
        return
    start, end = cycle(company)
    used = await db.scalar(
        select(func.count()).where(Report.company_id == company.id, Report.created_at >= start)
    )
    used, limit = used or 0, plan.report_limit_monthly
    about = {"used": used, "limit": limit, "plan": plan.code, "renews_at": end.isoformat()}
    if used >= limit:
        told = await db.scalar(
            select(func.count())
            .select_from(Notification)
            .where(
                Notification.company_id == company.id,
                Notification.kind == "plan_limit",
                Notification.params["stage"].astext == "blocked",
                Notification.created_at >= start,
            )
        )
        if not told:
            await notifications.notify(
                db,
                company_id=company.id,
                to=await notifications.owners(db, company.id),
                kind="plan_limit",
                actor_id=p.user.id,
                params={
                    **about,
                    **await notifications.job_params(db, job),
                    "stage": "blocked",
                    "technician": p.user.name,
                },
            )
            await db.commit()  # kept although the request fails below; nothing else was changed yet
        raise PlanLimit(
            "report_limit_reached",
            "This month's reports are used up. Nothing you captured is lost.",
            {
                "used": used,
                "limit": plan.report_limit_monthly,
                "plan": plan.code,
                "renews_at": end.isoformat(),
            },
        )
    made = used + 1  # this report
    stage = limit_stage(made, limit)
    if stage:
        await notifications.notify(
            db,
            company_id=company.id,
            to=await notifications.owners(db, company.id),
            kind="plan_limit",
            actor_id=None,
            params={**about, "used": made, "stage": stage},
        )


async def start(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> tuple[Report, BackgroundTask, bool]:
    """Returns (report, task, new_task). A report that is already being written returns its task."""
    job = await get_job(db, p, job_id, lock=True)
    if not (_is_author(p, job) or "reports.edit" in p.permissions):
        raise Forbidden("forbidden", "Only the technician on this job or a manager can make its report.")
    rep = (
        await db.execute(select(Report).where(Report.job_id == job.id).with_for_update())
    ).scalar_one_or_none()
    if rep and rep.status == "generating" and rep.task_id:
        return rep, await db.get(BackgroundTask, rep.task_id), False
    if rep and rep.status not in EDITABLE:
        raise Conflict(
            "report_already_submitted", "This report was already sent for review.", {"status": rep.status}
        )
    ready = await proof(db, p, job.id)
    if ready.blocked_by:
        raise Conflict("report_not_ready", "Some proof is still missing.", {"blocked_by": ready.blocked_by})
    company = p.company
    if not rep:
        await _check_report_limit(db, p, company, job)
        number = (
            await db.execute(
                text(
                    "INSERT INTO company_counters (company_id, key, value) VALUES (:c, 'report', 1001) "
                    "ON CONFLICT (company_id, key) DO UPDATE SET value = company_counters.value + 1 "
                    "RETURNING value"
                ),
                {"c": company.id},
            )
        ).scalar_one()
        rep = Report(
            company_id=company.id,
            job_id=job.id,
            number=number,
            status="generating",
            language=company.report_language or "en",
            created_by=p.user.id,
        )
        db.add(rep)
        await db.flush()
    else:
        rep.status = "generating"
    bt = await _new_task(db, p, "report_draft", rep)
    return rep, bt, True


async def regenerate_section(
    db: AsyncSession, p: Principal, report_id: uuid.UUID, section: str
) -> tuple[Report, BackgroundTask]:
    rep, job = await get_report(db, p, report_id, lock=True)
    if "regenerate" not in actions(p, rep, job):
        raise Conflict("report_locked", "This report can't be changed now.", {"status": rep.status})
    if section not in SECTIONS:
        raise NotFound("section_not_found", "Section not found.")
    bt = await _new_task(db, p, "section_regenerate", rep)
    return rep, bt


# ---- reading --------------------------------------------------------------------------------------
async def _people(db: AsyncSession, ids: set) -> dict:
    ids = {i for i in ids if i}
    if not ids:
        return {}
    return {u.id: u.name or "" for u in (await db.execute(select(User).where(User.id.in_(ids)))).scalars()}


async def _avatars(db: AsyncSession, ids: set) -> dict:
    ids = {i for i in ids if i}
    if not ids:
        return {}
    storage = get_storage()
    rows = await db.execute(
        select(User.id, User.avatar_key).where(User.id.in_(ids), User.avatar_key.is_not(None))
    )
    return {uid: storage.presign_get(key) for uid, key in rows.all()}


async def _brief(
    db: AsyncSession,
    job: Job,
    names: dict,
    *,
    avatars: dict | None = None,
    photos: dict | None = None,
    cover_urls: dict | None = None,
) -> JobBrief:
    customer = await db.get(Customer, job.customer_id)
    tech = (
        PersonRef(
            id=job.assigned_to,
            name=names.get(job.assigned_to, ""),
            avatar_url=(avatars or {}).get(job.assigned_to),
        )
        if job.assigned_to
        else None
    )
    return JobBrief(
        id=job.id,
        number=label(job.number),
        title=job.title,
        status=job.status,
        customer=customer.name,
        technician=tech,
        photos=(photos or {}).get(job.id, 0),
        cover_url=(cover_urls or {}).get(job.id),
    )


async def report_out(db: AsyncSession, p: Principal, rep: Report, job: Job) -> ReportOut:
    crs = list(
        (
            await db.execute(
                select(ChangeRequest)
                .where(ChangeRequest.report_id == rep.id)
                .order_by(ChangeRequest.created_at)
            )
        ).scalars()
    )
    names = await _people(
        db, {job.assigned_to, rep.submitted_by, rep.approved_by, *[c.requested_by for c in crs]}
    )
    photos = list(
        (
            await db.execute(
                select(Evidence)
                .where(Evidence.job_id == job.id, Evidence.deleted_at.is_(None))
                .order_by(Evidence.taken_at)
            )
        ).scalars()
    )
    storage = get_storage()
    counts = rep.source_counts or {}
    ev = EvidenceSummary(
        photos={s: sum(x.stage == s for x in photos) for s in ("before", "during", "after")},
        pairs=counts.get("pairs", 0),
        checks_passed=rep.checks_passed,
        checks_failed=rep.checks_failed,
        notes=counts.get("notes", 0),
        thumbs=[storage.presign_get(x.thumb_key) for x in photos if x.thumb_key][:6],
    )
    links = [SentenceLink(**x) for k in SECTIONS for x in (rep.evidence_links or {}).get(k, [])]
    person = lambda uid: PersonRef(id=uid, name=names.get(uid, "")) if uid else None  # noqa: E731
    return ReportOut(
        id=rep.id,
        number=rlabel(rep.number),
        status=rep.status,
        language=rep.language,
        job=await _brief(db, job, names),
        summary=rep.summary,
        work_done=rep.work_done,
        advice=rep.advice,
        section_sources=rep.section_sources or {},
        links=links,
        flags=[ReportFlag(**f) for f in rep.flags or []],
        evidence=ev,
        drafted_by=rep.drafted_by,
        task_id=rep.task_id,
        error=rep.error,
        version=rep.version,
        change_requests=[
            ChangeRequestOut(
                id=c.id,
                reasons=c.reasons,
                note=c.note,
                requested_by=person(c.requested_by),
                created_at=c.created_at,
                resolved_at=c.resolved_at,
            )
            for c in crs
        ],
        submitted_by=person(rep.submitted_by),
        submitted_at=rep.submitted_at,
        approved_by=person(rep.approved_by),
        approved_at=rep.approved_at,
        shared_at=rep.shared_at,
        acknowledged_at=rep.acknowledged_at,
        pdf_status=rep.pdf_status,
        actions=actions(p, rep, job),
        updated_at=rep.updated_at,
    )


async def list_reports(
    db: AsyncSession,
    p: Principal,
    *,
    statuses: list[str] | None,
    period: str,
    mine: bool,
    q: str | None,
    cursor: str | None,
    limit: int,
) -> ReportList:
    offset = decode_cursor(cursor)
    base = _visible(p)
    if mine:
        base = base.where(Job.assigned_to == p.user.id)
    if period != "all":
        base = base.where(Report.updated_at >= now() - timedelta(days={"week": 7, "month": 31}[period]))
    if q:
        like = f"%{q.strip()}%"
        num = q.strip().upper().removeprefix("R-").removeprefix("J-")
        names = select(Customer.id).where(Customer.company_id == p.company_id, Customer.name.ilike(like))
        conds = [Job.title.ilike(like), Job.customer_id.in_(names)]
        if num.isdigit():
            conds += [Report.number == int(num), Job.number == int(num)]
        base = base.where(or_(*conds))
    sub = base.with_only_columns(Report.status).subquery()
    counts = dict((await db.execute(select(sub.c.status, func.count()).group_by(sub.c.status))).all())
    counts["all"] = sum(counts.values())
    if statuses:
        base = base.where(Report.status.in_(statuses))
    order = (
        (Report.submitted_at.asc().nulls_last(),)
        if statuses == ["pending_review"]
        else (Report.updated_at.desc(),)
    )
    rows = (await db.execute(base.order_by(*order, Report.number).offset(offset).limit(limit + 1))).all()
    page = rows[:limit]
    names = await _people(db, {j.assigned_to for _, j in page})
    avatars = await _avatars(db, {j.assigned_to for _, j in page})
    page_jobs = [j for _, j in page]
    photos = await photo_counts(db, [j.id for j in page_jobs])
    cover_urls = await covers(db, page_jobs)
    thumbs = await thumbs_for(db, [j.id for j in page_jobs])
    notes = {}
    ids = [r.id for r, _ in page]
    if ids:
        for cr in (
            await db.execute(
                select(ChangeRequest)
                .where(ChangeRequest.report_id.in_(ids))
                .order_by(ChangeRequest.created_at)
            )
        ).scalars():
            notes[cr.report_id] = cr.note
    t = now()
    items = []
    for r, j in page:
        items.append(
            ReportListItem(
                id=r.id,
                number=rlabel(r.number),
                status=r.status,
                job=await _brief(db, j, names, avatars=avatars, photos=photos, cover_urls=cover_urls),
                drafted_by=r.drafted_by,
                flags=len(r.flags or []),
                submitted_at=r.submitted_at,
                waiting_minutes=int((t - r.submitted_at).total_seconds() // 60)
                if r.status == "pending_review" and r.submitted_at
                else None,
                approved_at=r.approved_at,
                change_note=notes.get(r.id) if r.status == "changes_requested" else None,
                updated_at=r.updated_at,
                thumbs=thumbs.get(j.id, []),
            )
        )
    return ReportList(
        data=items, meta=ListMeta(counts=counts, next_cursor=next_cursor(offset, limit, len(rows)))
    )


# ---- editing -----------------------------------------------------------------------------------------
def _version(rep: Report, source: str, event: str, user_id) -> ReportVersion:
    rep.version += 1
    return ReportVersion(
        report_id=rep.id,
        version=rep.version,
        source=source,
        event=event,
        edited_by=user_id,
        sections={k: getattr(rep, k) for k in SECTIONS},
    )


async def edit(
    db: AsyncSession, p: Principal, report_id: uuid.UUID, body: ReportPatch, if_match: str | None
) -> Report:
    rep, job = await get_report(db, p, report_id, lock=True)
    if "edit" not in actions(p, rep, job):
        if rep.status in DONE or rep.status == "pending_review":
            raise Conflict(
                "report_locked", "This report was sent and can't be changed now.", {"status": rep.status}
            )
        raise Forbidden("forbidden", "You can't change this report.")
    check_version(if_match, rep.version, await report_out(db, p, rep, job))
    changes = body.model_dump(exclude_unset=True)
    empty = [k for k in ("summary", "work_done") if k in changes and not (changes[k] or "").strip()]
    if empty:
        raise AppError("section_empty", "This part can't be empty.", fields={k: "empty" for k in empty})
    if not changes:
        return rep
    source = "manager" if "reports.approve" in p.permissions and not _is_author(p, job) else "technician"
    for k, v in changes.items():
        setattr(rep, k, (v or "").strip() or None)
        rep.section_sources = {**(rep.section_sources or {}), k: source}
    db.add(_version(rep, source, "edited", p.user.id))
    await db.flush()
    return rep


# ---- moving the report (and the job) -----------------------------------------------------------------
def _job_event(p: Principal, job: Job, type_: str, before: str, data: dict | None = None) -> JobEvent:
    return JobEvent(
        company_id=job.company_id,
        job_id=job.id,
        type=type_,
        from_status=before,
        to_status=job.status,
        actor_id=p.user.id,
        data=data or {},
    )


async def submit(db: AsyncSession, p: Principal, report_id: uuid.UUID) -> Report:
    rep, job = await get_report(db, p, report_id, lock=True)
    if "submit" not in actions(p, rep, job):
        if rep.status not in ("draft", "changes_requested"):
            raise Conflict("invalid_transition", "This report can't be sent now.", {"status": rep.status})
        raise Forbidden("forbidden", "Only the technician on this job or a manager can send it.")
    missing = [k for k in ("summary", "work_done") if not (getattr(rep, k) or "").strip()]
    if missing:
        raise AppError(
            "section_empty", "Fill in every part before sending.", fields={k: "empty" for k in missing}
        )
    if job.status not in ("in_progress", "changes_requested"):
        raise Conflict(
            "invalid_transition", "This job can't be sent for review now.", {"job_status": job.status}
        )
    t = now()
    rep.status, rep.submitted_at, rep.submitted_by = "pending_review", t, p.user.id
    before = job.status
    job.status = "in_review"
    job.version += 1
    await lock_job_evidence(db, job.id)
    for cr in (
        await db.execute(
            select(ChangeRequest).where(
                ChangeRequest.report_id == rep.id, ChangeRequest.resolved_at.is_(None)
            )
        )
    ).scalars():
        cr.resolved_at = t
    db.add(_version(rep, "technician" if _is_author(p, job) else "manager", "submitted", p.user.id))
    db.add(_job_event(p, job, "report_submitted", before, {"report": rlabel(rep.number)}))
    await notifications.notify(
        db, company_id=p.company_id, to=await notifications.reviewers(db, p.company_id),
        kind="report_submitted", actor_id=p.user.id, job=job, report_id=rep.id,
        params={
            **await notifications.job_params(db, job), "report": rlabel(rep.number), "technician": p.user.name
        },
    )  # fmt: skip
    await audit.record(
        db,
        "report.submitted",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="report",
        target_id=rep.id,
    )
    await db.flush()
    return rep


async def approve(db: AsyncSession, p: Principal, report_id: uuid.UUID) -> Report:
    p.require("reports.approve")
    rep, job = await get_report(db, p, report_id, lock=True)
    if rep.status != "pending_review":
        raise Conflict(
            "invalid_transition", "Only a report waiting for review can be approved.", {"status": rep.status}
        )
    t = now()
    rep.status, rep.approved_at, rep.approved_by = "approved", t, p.user.id
    before = job.status
    job.status, job.completed_at = "completed", t
    job.version += 1
    db.add(_version(rep, "manager", "approved", p.user.id))
    db.add(_job_event(p, job, "report_approved", before, {"report": rlabel(rep.number)}))
    await notifications.notify(
        db, company_id=p.company_id, to=[job.assigned_to], kind="report_approved", actor_id=p.user.id,
        job=job, report_id=rep.id,
        params={**await notifications.job_params(db, job), "report": rlabel(rep.number)},
    )  # fmt: skip
    from app.services import reviews

    await reviews.on_report_approved(db, p, rep, job)
    await audit.record(
        db,
        "report.approved",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="report",
        target_id=rep.id,
    )
    await db.flush()
    return rep


async def request_changes(
    db: AsyncSession, p: Principal, report_id: uuid.UUID, reasons: list[str], note: str | None
) -> Report:
    p.require("reports.approve")
    rep, job = await get_report(db, p, report_id, lock=True)
    if rep.status != "pending_review":
        raise Conflict(
            "invalid_transition", "Only a report waiting for review can be sent back.", {"status": rep.status}
        )
    if "other" in reasons and not (note or "").strip():
        raise AppError("validation_error", "Say what needs changing.", fields={"note": "required"})
    rep.status = "changes_requested"
    before = job.status
    job.status = "changes_requested"
    job.version += 1
    db.add(
        ChangeRequest(
            company_id=p.company_id,
            report_id=rep.id,
            reasons=list(dict.fromkeys(reasons)),
            note=note,
            requested_by=p.user.id,
        )
    )
    db.add(_job_event(p, job, "changes_requested", before, {"reasons": reasons, "note": note}))
    await notifications.notify(
        db, company_id=p.company_id, to=[job.assigned_to], kind="changes_requested", actor_id=p.user.id,
        job=job, report_id=rep.id,
        params={**await notifications.job_params(db, job), "report": rlabel(rep.number), "note": note},
    )  # fmt: skip
    await audit.record(
        db,
        "report.changes_requested",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="report",
        target_id=rep.id,
        data={"reasons": reasons},
    )
    await db.flush()
    return rep


async def versions(db: AsyncSession, p: Principal, report_id: uuid.UUID) -> VersionList:
    p.require("reports.approve")
    rep, _ = await get_report(db, p, report_id)
    rows = list(
        (
            await db.execute(
                select(ReportVersion).where(ReportVersion.report_id == rep.id).order_by(ReportVersion.version)
            )
        ).scalars()
    )
    names = await _people(db, {r.edited_by for r in rows})
    return VersionList(
        data=[
            VersionOut(
                version=r.version,
                event=r.event,
                source=r.source,
                sections=r.sections,
                created_at=r.created_at,
                edited_by=PersonRef(id=r.edited_by, name=names.get(r.edited_by, "")) if r.edited_by else None,
            )
            for r in rows
        ],
        meta=ListMeta(counts={"all": len(rows)}),
    )


async def reports_sent_by(db: AsyncSession, company_id: uuid.UUID, user_id: uuid.UUID) -> int:
    """Reports this person wrote that reached the customer (M37 "reports sent")."""
    return (
        await db.execute(
            select(func.count()).where(
                Report.company_id == company_id,
                Report.submitted_by == user_id,
                Report.shared_at.is_not(None),
            )
        )
    ).scalar_one()


async def shared_since(db: AsyncSession, company_id: uuid.UUID, since) -> list:
    """When each report first reached its customer, for the dashboard's week chart."""
    return list(
        (
            await db.execute(
                select(Report.shared_at).where(Report.company_id == company_id, Report.shared_at >= since)
            )
        ).scalars()
    )
