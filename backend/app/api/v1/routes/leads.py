"""Website forms that need no login: Book a demo (W03) and Contact (W05)."""

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import client_ip, get_db
from app.schemas.leads import ContactIn, ContactOut, DemoIn, DemoOut, DemoSlotsOut
from app.services import leads

router = APIRouter(prefix="/public", tags=["website"])


@router.get("/demo-slots", response_model=DemoSlotsOut)
async def demo_slots(db: AsyncSession = Depends(get_db)) -> DemoSlotsOut:
    return await leads.demo_slots(db)


@router.post("/demo-requests", response_model=DemoOut, status_code=status.HTTP_201_CREATED)
async def book_demo(body: DemoIn, request: Request, db: AsyncSession = Depends(get_db)) -> DemoOut:
    return await leads.book_demo(db, body, client_ip(request))


@router.post("/contact", response_model=ContactOut, status_code=status.HTTP_201_CREATED)
async def contact(body: ContactIn, request: Request, db: AsyncSession = Depends(get_db)) -> ContactOut:
    return await leads.contact(db, body, client_ip(request))
