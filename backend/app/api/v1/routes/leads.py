"""No-login website endpoints: Book a demo (W03), Contact (W05) and ready checklists per trade (W18–W23)."""

from typing import Literal

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import client_ip, get_db
from app.schemas.checklists import PublicChecklistTemplates
from app.schemas.leads import ContactMessageIn, ContactMessageOut, DemoBookedOut, DemoRequestIn, DemoSlotsOut
from app.services import checklists, leads

router = APIRouter(prefix="/public", tags=["website"])


@router.get("/checklist-templates", response_model=PublicChecklistTemplates)
async def ready_checklists(
    response: Response,
    trade: str,
    locale: Literal["en", "hi", "gu", "es", "fr"] = "en",
    db: AsyncSession = Depends(get_db),
) -> PublicChecklistTemplates:
    """KaamNishaan's ready checklists for a trade, with every question, in the asked language."""
    response.headers["Cache-Control"] = "public, max-age=300"
    return await checklists.ready_templates(db, trade, locale)


@router.get("/demo-slots", response_model=DemoSlotsOut)
async def demo_slots(db: AsyncSession = Depends(get_db)) -> DemoSlotsOut:
    return await leads.demo_slots(db)


@router.post("/demo-requests", response_model=DemoBookedOut, status_code=status.HTTP_201_CREATED)
async def book_demo(
    body: DemoRequestIn, request: Request, db: AsyncSession = Depends(get_db)
) -> DemoBookedOut:
    return await leads.book_demo(db, body, client_ip(request))


@router.post("/contact", response_model=ContactMessageOut, status_code=status.HTTP_201_CREATED)
async def contact(
    body: ContactMessageIn, request: Request, db: AsyncSession = Depends(get_db)
) -> ContactMessageOut:
    return await leads.contact(db, body, client_ip(request))
