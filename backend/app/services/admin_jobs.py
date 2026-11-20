"""A11 Jobs and A12 Job details: every company's jobs, read-only, for support and monitoring."""

import csv
import io
import math
import uuid
from collections.abc import Iterable
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound
from app.models import (
    ChangeRequest,
    Company,
    Customer,
    CustomerContact,
    Evidence,
    Industry,
    Job,
    JobChecklist,
    JobEvent,
    Report,
    ShareLink,
    Site,
    User,
    VoiceNote,
)  # fmt: skip
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_jobs import (
    AdminJobChecklist,
    AdminJobDetail,
    AdminJobList,
    AdminJobPhotos,
    AdminJobPlace,
    AdminJobReport,
    AdminJobRow,
    AdminProof,
    AdminTimelineItem,
)  # fmt: skip
from app.services.admin_companies import _csv_safe
from app.services.checklists import pick
from app.services.jobs import label

WHEN = func.coalesce(Job.scheduled_at, Job.created_at)
CSV_HEADER = ["Job", "Title", "Customer", "Company", "Technician", "Status", "Proof", "When"]


def _filters(
    q: str | None, company_id: uuid.UUID | None, start: datetime | None, end: datetime | None
) -> list:
    where: list = [Job.deleted_at.is_(None)]
    if q:
        q = q.strip()
        like = f"%{q}%"
        conds = [
            Job.title.ilike(like),
            Customer.name.ilike(like),
            Job.assigned_to.in_(select(User.id).where(User.name.ilike(like))),
        ]
        num = q.upper().removeprefix("#").removeprefix("J-")
        if num.isdigit():
            conds.append(Job.number == int(num))
        where.append(or_(*conds))
    if company_id:
        where.append(Job.company_id == company_id)
    if start:
        where.append(WHEN >= start)
    if end:
        where.append(WHEN < end)
    return where


def _base(where: list):
    return (
        select(Job, Company.name, Customer.name, User.name)
        .join(Company, Company.id == Job.company_id)
        .join(Customer, Customer.id == Job.customer_id)
        .outerjoin(User, User.id == Job.assigned_to)
        .where(*where)
    )


async def _proofs(db: AsyncSession, ids: list[uuid.UUID]) -> dict[uuid.UUID, AdminProof]:
    """The app's proof steps (services/evidence.proof_progress), counted for many jobs at once."""
    if not ids:
        return {}
    stages: dict[uuid.UUID, set] = {}
    for jid, st in await db.execute(
        select(Evidence.job_id, Evidence.stage)
        .where(Evidence.job_id.in_(ids), Evidence.deleted_at.is_(None))
        .distinct()
    ):
        stages.setdefault(jid, set()).add(st)
    lists = {
        jid: (int(done), int(n))
        for jid, done, n in await db.execute(
            select(JobChecklist.job_id, func.count(JobChecklist.completed_at), func.count())
            .where(JobChecklist.job_id.in_(ids))
            .group_by(JobChecklist.job_id)
        )
    }
    notes = set(
        (
            await db.execute(
                select(VoiceNote.job_id).where(VoiceNote.job_id.in_(ids), VoiceNote.deleted_at.is_(None))
            )
        ).scalars()
    )
    out = {}
    for jid in ids:
        st = stages.get(jid, set())
        steps = [s in st for s in ("before", "during", "after")]
        done, n = lists.get(jid, (0, 0))
        if n:
            steps.append(done == n)
        steps.append(jid in notes)
        out[jid] = AdminProof(done=sum(steps), total=len(steps))
    return out


async def jobs(
    db: AsyncSession, *, q: str | None, status: str | None, company_id: uuid.UUID | None,
    start: datetime | None, end: datetime | None, page: int, page_size: int,
) -> AdminJobList:  # fmt: skip
    where = _filters(q, company_id, start, end)
    counts = dict(
        (await db.execute(
            select(Job.status, func.count()).select_from(Job).join(Customer, Customer.id == Job.customer_id)
            .where(*where).group_by(Job.status)
        )).all()
    )  # fmt: skip
    if status:
        where.append(Job.status == status)
    total = int(await db.scalar(select(func.count()).select_from(_base(where).subquery())) or 0)
    rows = (
        await db.execute(
            _base(where).order_by(WHEN.desc(), Job.id).offset((page - 1) * page_size).limit(page_size)
        )
    ).all()
    proofs = await _proofs(db, [j.id for j, *_ in rows])
    companies = (
        await db.execute(
            select(Company.id, Company.name)
            .where(Company.id.in_(select(Job.company_id).where(Job.deleted_at.is_(None))))
            .order_by(Company.name)
        )
    ).all()
    return AdminJobList(
        items=[
            AdminJobRow(
                id=j.id, number=label(j.number), title=j.title, customer=cust, technician=tech,
                company=AdminOption(value=str(j.company_id), label=co), status=j.status, proof=proofs[j.id],
                when=j.scheduled_at or j.created_at, is_quick_job=j.is_quick_job,
            )
            for j, co, cust, tech in rows
        ],
        total=total, page=page, page_size=page_size, counts={k: int(v) for k, v in counts.items()},
        companies=[AdminOption(value=str(i), label=n) for i, n in companies],
    )  # fmt: skip


async def jobs_csv(
    db: AsyncSession, *, q: str | None, status: str | None, company_id: uuid.UUID | None,
    start: datetime | None, end: datetime | None,
) -> Iterable[str]:  # fmt: skip
    where = _filters(q, company_id, start, end)
    if status:
        where.append(Job.status == status)
    rows = (await db.execute(_base(where).order_by(WHEN.desc(), Job.id).limit(50_000))).all()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(CSV_HEADER)
    for chunk in range(0, len(rows), 1000):
        part = rows[chunk : chunk + 1000]
        proofs = await _proofs(db, [j.id for j, *_ in part])
        for j, co, cust, tech in part:
            p = proofs[j.id]
            w.writerow([_csv_safe(x) for x in (
                label(j.number), j.title, cust, co, tech or "", j.status, f"{p.done}/{p.total}",
                (j.scheduled_at or j.created_at).isoformat(timespec="minutes"),
            )])  # fmt: skip
    return [buf.getvalue()]


def _distance_m(a_lat: float, a_lng: float, b_lat: float, b_lng: float) -> int:
    r = 6_371_000
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp, dl = p2 - p1, math.radians(b_lng - a_lng)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return round(2 * r * math.asin(math.sqrt(h)))


async def _names(db: AsyncSession, ids: set) -> dict:
    ids = {i for i in ids if i}
    if not ids:
        return {}
    return dict((await db.execute(select(User.id, User.name).where(User.id.in_(ids)))).all())


async def detail(db: AsyncSession, job_id: uuid.UUID, lang: str) -> AdminJobDetail:
    j = await db.get(Job, job_id)
    if not j or j.deleted_at:
        raise NotFound("not_found", "Job not found.")
    c = await db.get(Company, j.company_id)
    ind = await db.get(Industry, c.industry_slug) if c.industry_slug else None
    cust = await db.get(Customer, j.customer_id)
    contact = await db.get(CustomerContact, j.contact_id) if j.contact_id else None
    site = await db.get(Site, j.site_id) if j.site_id else None

    events = (
        (await db.execute(select(JobEvent).where(JobEvent.job_id == j.id).order_by(JobEvent.at)))
        .scalars()
        .all()
    )
    photos = (
        await db.execute(
            select(Evidence.stage, func.count(), func.min(Evidence.taken_at), func.max(Evidence.taken_at))
            .where(Evidence.job_id == j.id, Evidence.deleted_at.is_(None))
            .group_by(Evidence.stage)
        )
    ).all()
    voice = (
        await db.execute(
            select(func.count(), func.min(VoiceNote.created_at), func.max(VoiceNote.created_at)).where(
                VoiceNote.job_id == j.id, VoiceNote.deleted_at.is_(None)
            )
        )
    ).one()
    lists = (await db.execute(select(JobChecklist).where(JobChecklist.job_id == j.id))).scalars().all()
    report = (
        await db.execute(
            select(Report).where(Report.job_id == j.id).order_by(Report.created_at.desc()).limit(1)
        )
    ).scalar_one_or_none()
    changes = (
        (await db.execute(select(ChangeRequest).where(ChangeRequest.report_id == report.id))).scalars().all()
        if report
        else []
    )
    opens = (
        int(await db.scalar(select(func.coalesce(func.sum(ShareLink.open_count), 0)).where(
            ShareLink.report_id == report.id)) or 0)
        if report else 0
    )  # fmt: skip
    names = await _names(
        db,
        {j.assigned_to}
        | {e.actor_id for e in events}
        | {e.data.get("technician_id") for e in events if isinstance(e.data.get("technician_id"), str)}
        | ({report.submitted_by, report.approved_by} if report else set())
        | {cr.requested_by for cr in changes},
    )
    by_str = {str(k): v for k, v in names.items()}

    tl: list[AdminTimelineItem] = []
    for e in events:
        data = {}
        if e.type in ("assigned", "unassigned") and e.data.get("technician_id"):
            data["technician"] = by_str.get(str(e.data["technician_id"]))
        if e.type == "cancelled" and e.data.get("reason"):
            data["reason"] = e.data["reason"]
        if e.type == "created" and e.data.get("quick_job"):
            data["quick_job"] = True
        if e.type == "edited" and e.data.get("fields"):
            data["fields"] = e.data["fields"]
        tl.append(AdminTimelineItem(type=e.type, at=e.at, actor=names.get(e.actor_id), data=data))
    counts = {"before": 0, "during": 0, "after": 0}
    for stage, n, first, last in photos:
        counts[stage] = int(n)
        tl.append(AdminTimelineItem(type="photos", at=first, until=last if last != first else None,
                                    data={"stage": stage, "count": int(n)}))  # fmt: skip
    if voice[0]:
        last = voice[2] if voice[2] != voice[1] else None
        tl.append(AdminTimelineItem(type="voice", at=voice[1], until=last, data={"count": int(voice[0])}))
    if report:
        if report.submitted_at:
            tl.append(AdminTimelineItem(type="report_submitted", at=report.submitted_at,
                                        actor=names.get(report.submitted_by)))  # fmt: skip
        for cr in changes:
            who = names.get(cr.requested_by)
            tl.append(
                AdminTimelineItem(
                    type="changes_requested", at=cr.created_at, actor=who, data={"reasons": list(cr.reasons)}
                )
            )
        if report.approved_at:
            tl.append(
                AdminTimelineItem(type="approved", at=report.approved_at, actor=names.get(report.approved_by))
            )
        if report.shared_at:
            tl.append(AdminTimelineItem(type="shared", at=report.shared_at))
        if report.acknowledged_at:
            tl.append(AdminTimelineItem(type="acknowledged", at=report.acknowledged_at,
                                        actor=report.acknowledged_name))  # fmt: skip
    tl.sort(key=lambda x: x.at)

    dist = (
        _distance_m(site.lat, site.lng, j.start_lat, j.start_lng)
        if site and site.lat is not None and site.lng is not None and j.start_lat is not None
        and j.start_lng is not None
        else None
    )  # fmt: skip
    address = (
        ", ".join(filter(None, [site.address_line1, site.address_line2, site.city, site.state,
                                site.postcode]))
        if site else None
    )  # fmt: skip
    proof = (await _proofs(db, [j.id]))[j.id]
    return AdminJobDetail(
        id=j.id, number=label(j.number), title=j.title, description=j.description, status=j.status,
        is_quick_job=j.is_quick_job, company=AdminOption(value=str(c.id), label=c.name),
        industry=pick(ind.name, lang) if ind else None, customer=cust.name,
        contact=contact.name if contact else None, technician=names.get(j.assigned_to),
        scheduled_at=j.scheduled_at, duration_min=j.duration_min, created_at=j.created_at,
        completed_at=j.completed_at, cancel_reason=j.cancel_reason,
        place=AdminJobPlace(
            address=address, site_lat=site.lat if site else None, site_lng=site.lng if site else None,
            started_at=j.started_at, start_lat=j.start_lat, start_lng=j.start_lng, start_distance_m=dist,
        ),
        checklists=[
            AdminJobChecklist(name=pick(cl.name, lang), answered=cl.answered_count, total=cl.total,
                              done=cl.completed_at is not None)
            for cl in lists
        ],
        photos=AdminJobPhotos(**counts, voice_notes=int(voice[0])),
        proof=proof,
        report=AdminJobReport(
            id=report.id, number=f"R-{report.number}", status=report.status, submitted_at=report.submitted_at,
            approved_at=report.approved_at, shared_at=report.shared_at,
            acknowledged_at=report.acknowledged_at,
            change_requests=len(changes), open_count=opens,
        ) if report else None,
        timeline=tl,
    )  # fmt: skip
