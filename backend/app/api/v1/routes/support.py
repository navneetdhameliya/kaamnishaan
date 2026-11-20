import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal
from app.schemas.support import TicketCreate, TicketList, TicketOut, TicketReply
from app.services import support as svc

router = APIRouter(tags=["support"])


@router.get("/support/tickets", response_model=TicketList)
async def my_tickets(p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)) -> TicketList:
    """M47 Help: this person's help requests in this company, latest activity first."""
    return await svc.list_tickets(db, p)


@router.post("/support/tickets", response_model=TicketOut, status_code=201)
async def new_ticket(
    body: TicketCreate, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> TicketOut:
    """Open a help request (also while the company is paused). Ten a day at most."""
    return await svc.create(db, p, body)


@router.get("/support/tickets/{ticket_id}", response_model=TicketOut)
async def ticket(
    ticket_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> TicketOut:
    """The request and every message, oldest first. Staff-only notes are never included."""
    return await svc.get(db, p, ticket_id)


@router.post("/support/tickets/{ticket_id}/messages", response_model=TicketOut)
async def reply(
    ticket_id: uuid.UUID, body: TicketReply, p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> TicketOut:  # fmt: skip
    """Write again; a solved request opens again."""
    return await svc.reply(db, p, ticket_id, body.body)


@router.post("/support/tickets/{ticket_id}/solve", response_model=TicketOut)
async def solve(
    ticket_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> TicketOut:
    """The person says it's sorted."""
    return await svc.solve(db, p, ticket_id)
