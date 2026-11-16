"""The customer's report page (W27). No login: the long random token in the link is the key.

Expired links answer 410 `link_expired` (the page offers "Send me a new link"); turned-off links
answer 410 `link_revoked`. Photos are EXIF-free copies, so no GPS reaches the customer.
"""

from typing import Literal

from fastapi import APIRouter, Depends
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.errors import Conflict
from app.schemas.sharing import (
    AcknowledgeIn,
    Acknowledgement,
    IssueIn,
    IssueOut,
    NewLinkOut,
    PublicReport,
)
from app.services import sharing
from app.tasks import enqueue

router = APIRouter(prefix="/public/reports", tags=["customer report page"])
Lang = Literal["en", "hi", "gu", "es", "fr"]


@router.get("/{token}", response_model=PublicReport)
async def report_page(
    token: str, lang: Lang | None = None, db: AsyncSession = Depends(get_db)
) -> PublicReport:
    """Company, report, before/after photos, checklist, work done, advice, approver and link expiry."""
    return await sharing.public_report(db, token, lang)


@router.get("/{token}/pdf", status_code=307, responses={409: {"description": "pdf_not_ready"}})
async def report_pdf(token: str, db: AsyncSession = Depends(get_db)) -> RedirectResponse:
    """Redirects to a 15-minute signed download of the PDF."""
    url, rep, start = await sharing.public_pdf(db, token)
    if url:
        return RedirectResponse(url, status_code=307)
    if start:
        await db.commit()
        await enqueue("build_report_pdf", report_id=str(rep.id))
    raise Conflict("pdf_not_ready", "The PDF is being made. Try again in a minute.", {"retry_after": 30})


@router.post("/{token}/acknowledge", response_model=Acknowledgement)
async def acknowledge(token: str, body: AcknowledgeIn, db: AsyncSession = Depends(get_db)) -> Acknowledgement:
    return await sharing.acknowledge(db, token, body.name, body.organisation)


@router.post("/{token}/request-link", response_model=NewLinkOut)
async def request_link(token: str, db: AsyncSession = Depends(get_db)) -> NewLinkOut:
    """ "Send me a new link" after expiry. It goes to the phone or email the report was sent to."""
    return await sharing.request_new_link(db, token)


@router.post("/{token}/issue", response_model=IssueOut, status_code=201)
async def report_problem(token: str, body: IssueIn, db: AsyncSession = Depends(get_db)) -> IssueOut:
    """ "Report a problem": the company's owner and managers get an email."""
    issue = await sharing.report_issue(db, token, body.message, body.contact)
    return IssueOut(id=issue.id, received_at=issue.created_at)
