"""M41 Plan and billing (owner) and Follow-up credits (owners and managers)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db
from app.schemas.billing import BillingOut, CreditsOut
from app.services import credits

from .jobs import member

router = APIRouter(tags=["billing"])


@router.get("/billing", response_model=BillingOut)
async def billing(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> BillingOut:
    """The plan, when this month ends, and how much of each limit is used."""
    return await credits.billing(db, p)


@router.get("/credits", response_model=CreditsOut)
async def follow_up_credits(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> CreditsOut:
    """Credits left this month, what used them, and the top-up packs."""
    return await credits.credits(db, p)
