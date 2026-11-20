"""A14 Reports and A15 Report details: every company's reports, read-only, for support and quality."""

import csv
import io
import uuid
from collections.abc import Iterable
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound
from app.models import ChangeRequest, Company, Customer, Evidence, Job, Report, ReportVersion, ShareLink, User
from app.providers.storage import get_storage
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_reports import (
    AdminReportChange,
    AdminReportDetail,
    AdminReportFlag,
    AdminReportJob,
    AdminReportLink,
    AdminReportList,
    AdminReportPhoto,
    AdminReportRow,
    AdminReportVersion,
)
from app.services.admin_companies import _csv_safe
from app.services.jobs import label
from app.services.reports import SECTIONS, rlabel

CSV_HEADER = [
    "Report",
    "Job",
    "Customer",
    "Company",
    "Technician",
    "Language",
    "Status",
    "AI check",
    "Created",
    "Sent",
]
ORDER = ("failed_check", "missing_evidence", "unsupported_claim")


def _filters(
    q: str | None,
    company_id: uuid.UUID | None,
    language: str | None,
    start: datetime | None,
    end: datetime | None,
) -> list:
    where: list = [Job.deleted_at.is_(None)]
    if q:
        q = q.strip()
        like = f"%{q}%"
        conds = [Job.title.ilike(like), Customer.name.ilike(like), Company.name.ilike(like)]
        num = q.upper().removeprefix("#")
        if num.startswith("R-") and num[2:].isdigit():
            conds.append(Report.number == int(num[2:]))
        elif num.startswith("J-") and num[2:].isdigit():
            conds.append(Job.number == int(num[2:]))
        elif num.isdigit():
            conds += [Report.number == int(num), Job.number == int(num)]
        where.append(or_(*conds))
    if company_id:
        where.append(Report.company_id == company_id)
    if language:
        where.append(Report.language == language)
    if start:
        where.append(Report.created_at >= start)
    if end:
        where.append(Report.created_at < end)
    return where


def _base(where: list):
    return (
        select(Report, Job, Company.name, Customer.name, User.name)
        .join(Job, Job.id == Report.job_id)
        .join(Company, Company.id == Report.company_id)
        .join(Customer, Customer.id == Job.customer_id)
        .outerjoin(User, User.id == Job.assigned_to)
        .where(*where)
    )


def check_of(rep: Report) -> tuple[str, int]:
    if rep.status in ("generating", "generation_failed"):
        return "not_checked", 0
    flags = rep.flags or []
    for kind in ORDER:
        n = sum(1 for f in flags if f.get("kind") == kind)
        if kind == "failed_check":
            n = max(n, rep.checks_failed or 0)
        if n:
            return kind, n
    return "passed", 0


def _job(j: Job, cust: str) -> AdminReportJob:
    return AdminReportJob(id=j.id, number=label(j.number), title=j.title, customer=cust)


async def reports(
    db: AsyncSession,
    *,
    q: str | None,
    status: str | None,
    company_id: uuid.UUID | None,
    language: str | None,
    start: datetime | None,
    end: datetime | None,
    page: int,
    page_size: int,
) -> AdminReportList:
    where = _filters(q, company_id, language, start, end)
    counts = dict(
        (
            await db.execute(
                select(Report.status, func.count())
                .select_from(Report)
                .join(Job, Job.id == Report.job_id)
                .join(Company, Company.id == Report.company_id)
                .join(Customer, Customer.id == Job.customer_id)
                .where(*where)
                .group_by(Report.status)
            )
        ).all()
    )
    if status:
        where.append(Report.status == status)
    total = int(await db.scalar(select(func.count()).select_from(_base(where).subquery())) or 0)
    rows = (
        await db.execute(
            _base(where)
            .order_by(Report.created_at.desc(), Report.id)
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()
    companies = (
        await db.execute(
            select(Company.id, Company.name)
            .where(Company.id.in_(select(Report.company_id)))
            .order_by(Company.name)
        )
    ).all()
    items = []
    for r, j, co, cust, tech in rows:
        check, n = check_of(r)
        items.append(
            AdminReportRow(
                id=r.id,
                number=rlabel(r.number),
                status=r.status,
                language=r.language,
                job=_job(j, cust),
                company=AdminOption(value=str(r.company_id), label=co),
                technician=tech,
                check=check,
                check_count=n,
                created_at=r.created_at,
                shared_at=r.shared_at,
            )
        )
    return AdminReportList(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        counts={k: int(v) for k, v in counts.items()},
        companies=[AdminOption(value=str(i), label=n) for i, n in companies],
    )


async def reports_csv(
    db: AsyncSession,
    *,
    q: str | None,
    status: str | None,
    company_id: uuid.UUID | None,
    language: str | None,
    start: datetime | None,
    end: datetime | None,
) -> Iterable[str]:
    where = _filters(q, company_id, language, start, end)
    if status:
        where.append(Report.status == status)
    rows = (await db.execute(_base(where).order_by(Report.created_at.desc(), Report.id).limit(50_000))).all()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(CSV_HEADER)
    for r, j, co, cust, tech in rows:
        check, n = check_of(r)
        w.writerow(
            [
                _csv_safe(x)
                for x in (
                    rlabel(r.number),
                    label(j.number),
                    cust,
                    co,
                    tech or "",
                    r.language,
                    r.status,
                    f"{check} ({n})" if n else check,
                    r.created_at.isoformat(timespec="minutes"),
                    r.shared_at.isoformat(timespec="minutes") if r.shared_at else "",
                )
            ]
        )
    return [buf.getvalue()]


def _mask(link: ShareLink) -> str | None:
    if link.phone:
        hidden = f"•••• {link.phone[-4:]}"
    elif link.email and "@" in link.email:
        name, domain = link.email.split("@", 1)
        hidden = f"{name[:1]}•••@{domain}"
    else:
        hidden = None
    return " · ".join(x for x in (link.recipient_name, hidden) if x) or None


async def detail(db: AsyncSession, report_id: uuid.UUID) -> AdminReportDetail:
    row = (await db.execute(_base([Report.id == report_id]))).first()
    if not row:
        raise NotFound("not_found", "Report not found.")
    r, j, co, cust, tech = row
    changes = (
        (
            await db.execute(
                select(ChangeRequest)
                .where(ChangeRequest.report_id == r.id)
                .order_by(ChangeRequest.created_at)
            )
        )
        .scalars()
        .all()
    )
    versions = (
        (
            await db.execute(
                select(ReportVersion).where(ReportVersion.report_id == r.id).order_by(ReportVersion.version)
            )
        )
        .scalars()
        .all()
    )
    links = (
        (
            await db.execute(
                select(ShareLink).where(ShareLink.report_id == r.id).order_by(ShareLink.created_at)
            )
        )
        .scalars()
        .all()
    )
    ids = {
        r.submitted_by,
        r.approved_by,
        *(c.requested_by for c in changes),
        *(v.edited_by for v in versions),
    }
    ids.discard(None)
    names = dict((await db.execute(select(User.id, User.name).where(User.id.in_(ids)))).all()) if ids else {}
    editors: list[str] = []
    for v in versions:
        n = names.get(v.edited_by)
        if (
            v.source in ("technician", "manager")
            and v.event in ("edited", "regenerated")
            and n
            and n not in editors
        ):
            editors.append(n)
    storage = get_storage()
    photos = (
        await db.execute(
            select(Evidence.stage, Evidence.thumb_key)
            .where(Evidence.job_id == j.id, Evidence.deleted_at.is_(None), Evidence.thumb_key.is_not(None))
            .order_by(Evidence.taken_at)
            .limit(8)
        )
    ).all()
    sentences = [x for k in SECTIONS for x in (r.evidence_links or {}).get(k, [])]
    return AdminReportDetail(
        id=r.id,
        number=rlabel(r.number),
        status=r.status,
        language=r.language,
        job=_job(j, cust),
        company=AdminOption(value=str(r.company_id), label=co),
        technician=tech,
        drafted_by=r.drafted_by,
        edited_by=editors,
        summary=r.summary,
        work_done=r.work_done,
        advice=r.advice,
        photos=[AdminReportPhoto(stage=s, url=storage.presign_get(k)) for s, k in photos],
        sentences=len(sentences),
        sentences_linked=sum(1 for x in sentences if x.get("refs")),
        checks_passed=r.checks_passed,
        checks_failed=r.checks_failed,
        flags=[AdminReportFlag(kind=f["kind"], text=f["text"]) for f in r.flags or [] if f.get("kind")],
        ai_prompt_version=r.ai_prompt_version,
        ai_tokens=r.ai_tokens,
        ai_cost_usd=round(r.ai_cost_usd or 0, 4),
        error=r.error,
        submitted_by=names.get(r.submitted_by),
        submitted_at=r.submitted_at,
        approved_by=names.get(r.approved_by),
        approved_at=r.approved_at,
        shared_at=r.shared_at,
        acknowledged_at=r.acknowledged_at,
        acknowledged_name=r.acknowledged_name,
        changes=[
            AdminReportChange(
                reasons=list(c.reasons),
                note=c.note,
                by=names.get(c.requested_by),
                at=c.created_at,
                resolved_at=c.resolved_at,
            )
            for c in changes
        ],
        links=[
            AdminReportLink(
                channel=x.channel,
                recipient=_mask(x),
                created_at=x.created_at,
                expires_at=x.expires_at,
                revoked=x.revoked_at is not None,
                opens=x.open_count,
                last_opened_at=x.last_opened_at,
            )
            for x in links
        ],
        versions=[
            AdminReportVersion(
                version=v.version, event=v.event, source=v.source, by=names.get(v.edited_by), at=v.created_at
            )
            for v in versions
        ],
        pdf_url=storage.presign_get(r.pdf_key, filename=f"{rlabel(r.number)}.pdf")
        if r.pdf_status == "ready" and r.pdf_key
        else None,
        created_at=r.created_at,
    )
