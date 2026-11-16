import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Header, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.jobs import member
from app.core.deps import Principal, get_db
from app.schemas.reports import (
    ChangesIn,
    ReportList,
    ReportOut,
    ReportPatch,
    ReportStarted,
    ReportStatus,
    SectionKey,
    TaskOut,
    VersionList,
)
from app.schemas.sharing import PdfOut, SendIn, ShareInfo, ShareLinkIn, ShareLinkOut
from app.services import reports as svc
from app.services import sharing
from app.tasks import enqueue

router = APIRouter(tags=["reports"])


async def _run(db: AsyncSession, rep, bt, section: str | None = None) -> None:
    await db.commit()  # the worker must see the report and the task
    await enqueue("draft_report", report_id=str(rep.id), task_id=str(bt.id), section=section)
    await db.refresh(rep)
    await db.refresh(bt)


@router.post("/jobs/{job_id}/reports", response_model=ReportStarted, status_code=202)
async def start_report(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportStarted:
    """Start the AI draft (M31 making). Poll GET /tasks/{task_id}; the report opens when it is done."""
    rep, bt, new = await svc.start(db, p, job_id)
    if new:
        await _run(db, rep, bt)
    return ReportStarted(task_id=bt.id, report_id=rep.id, status=rep.status)


@router.get("/tasks/{task_id}", response_model=TaskOut, tags=["tasks"])
async def get_task(
    task_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> TaskOut:
    return await svc.get_task(db, p, task_id)


@router.get("/reports", response_model=ReportList)
async def list_reports(
    status_: list[ReportStatus] | None = Query(default=None, alias="status"),
    period: Literal["week", "month", "all"] = "all",
    mine: bool = False,
    q: str | None = None,
    cursor: str | None = None,
    limit: int = Query(default=30, ge=1, le=100),
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ReportList:
    """M30: technicians see their own; owners and managers see all (review queue: ?status=pending_review)."""
    return await svc.list_reports(
        db, p, statuses=status_, period=period, mine=mine, q=q, cursor=cursor, limit=limit
    )


@router.get("/reports/{report_id}", response_model=ReportOut)
async def get_report(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportOut:
    rep, job = await svc.get_report(db, p, report_id)
    return await svc.report_out(db, p, rep, job)


@router.patch("/reports/{report_id}", response_model=ReportOut)
async def edit_report(
    report_id: uuid.UUID,
    body: ReportPatch,
    if_match: str | None = Header(default=None),
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ReportOut:
    rep = await svc.edit(db, p, report_id, body, if_match)
    rep, job = await svc.get_report(db, p, rep.id)
    return await svc.report_out(db, p, rep, job)


@router.post("/reports/{report_id}/sections/{key}/regenerate", response_model=ReportStarted, status_code=202)
async def regenerate(
    report_id: uuid.UUID, key: SectionKey, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportStarted:
    rep, bt = await svc.regenerate_section(db, p, report_id, key)
    await _run(db, rep, bt, section=key)
    return ReportStarted(task_id=bt.id, report_id=rep.id, status=rep.status)


async def _moved(db: AsyncSession, p: Principal, rep) -> ReportOut:
    rep, job = await svc.get_report(db, p, rep.id)
    return await svc.report_out(db, p, rep, job)


@router.post("/reports/{report_id}/submit", response_model=ReportOut)
async def submit(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportOut:
    """Send to the manager. Photos, checklist answers and voice notes lock."""
    return await _moved(db, p, await svc.submit(db, p, report_id))


@router.post("/reports/{report_id}/approve", response_model=ReportOut)
async def approve(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportOut:
    """Approve: the job is completed and the customer PDF starts building (GET /reports/{id}/pdf)."""
    rep = await svc.approve(db, p, report_id)
    sharing.needs_pdf(rep)
    await db.commit()
    await enqueue("build_report_pdf", report_id=str(rep.id))
    await db.refresh(rep)
    return await _moved(db, p, rep)


@router.post("/reports/{report_id}/request-changes", response_model=ReportOut)
async def request_changes(
    report_id: uuid.UUID, body: ChangesIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReportOut:
    return await _moved(db, p, await svc.request_changes(db, p, report_id, body.reasons, body.note))


@router.get("/reports/{report_id}/versions", response_model=VersionList)
async def versions(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> VersionList:
    return await svc.versions(db, p, report_id)


# ---- PDF and sharing (M34, M35) ------------------------------------------------------------------
@router.get("/reports/{report_id}/pdf", response_model=PdfOut, tags=["sharing"])
async def report_pdf(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> PdfOut:
    """PDF status and a 15-minute download link. Starts the build again if it failed."""
    rep, start = await sharing.get_pdf(db, p, report_id)
    if start:
        await db.commit()
        await enqueue("build_report_pdf", report_id=str(rep.id))
        await db.refresh(rep)
    return sharing.pdf_out(rep)


@router.get("/reports/{report_id}/share", response_model=ShareInfo, tags=["sharing"])
async def share_screen(
    report_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ShareInfo:
    """M35: the customer's contact, which channels can be used, the current link and the message text."""
    return await sharing.share_info(db, p, report_id)


@router.post(
    "/reports/{report_id}/share-links", response_model=ShareLinkOut, status_code=201, tags=["sharing"]
)
async def create_share_link(
    report_id: uuid.UUID,
    body: ShareLinkIn | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ShareLinkOut:
    """Create the 30-day link, or renew it for 30 more days. "copy" also marks the report shared."""
    return await sharing.create_link(db, p, report_id, (body or ShareLinkIn()).channel)


@router.delete("/share-links/{link_id}", status_code=204, tags=["sharing"])
async def revoke_share_link(
    link_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    """Turn the link off at once; the customer sees "link turned off". Owners and managers."""
    await sharing.revoke_link(db, p, link_id)
    return Response(status_code=204)


@router.post("/reports/{report_id}/send", response_model=ShareInfo, tags=["sharing"])
async def send_report(
    report_id: uuid.UUID, body: SendIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ShareInfo:
    """Send the report link by SMS, WhatsApp and/or email. Each message's result is in `sent`."""
    return await sharing.send(db, p, report_id, body)
