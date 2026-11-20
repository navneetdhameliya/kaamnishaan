"""M47 Help: anyone in a company opens a help request (also when the company is paused) and talks with
KaamNishaan support. People only see their own requests; staff notes stay in the admin panel."""

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, NotFound, RateLimited
from app.core.security import now
from app.models import Job, SupportMessage, SupportTicket, User
from app.schemas.support import TicketCreate, TicketList, TicketMessageOut, TicketOut

PER_DAY = 10


def tlabel(n: int) -> str:
    return f"T-{n}"


def _company(p: Principal) -> uuid.UUID:
    # not p.company_id: a paused company can still ask for help
    if not p.company:
        raise AppError("no_company", "Choose a company first.", status=403)
    return p.company.id


def _out(t: SupportTicket, messages: list[TicketMessageOut] | None = None) -> TicketOut:
    return TicketOut(
        id=t.id, number=tlabel(t.number), subject=t.subject, category=t.category, status=t.status,
        job_id=t.job_id, created_at=t.created_at, last_message_at=t.last_message_at, last_from=t.last_from,
        messages=messages or [],
    )  # fmt: skip


async def _mine(db: AsyncSession, p: Principal, ticket_id: uuid.UUID, lock: bool = False) -> SupportTicket:
    q = select(SupportTicket).where(
        SupportTicket.id == ticket_id,
        SupportTicket.user_id == p.user.id,
        SupportTicket.company_id == _company(p),
    )
    t = (await db.execute(q.with_for_update() if lock else q)).scalar_one_or_none()
    if not t:
        raise NotFound("not_found", "Help request not found.")
    return t


async def list_tickets(db: AsyncSession, p: Principal) -> TicketList:
    rows = (
        await db.execute(
            select(SupportTicket)
            .where(SupportTicket.user_id == p.user.id, SupportTicket.company_id == _company(p))
            .order_by(SupportTicket.last_message_at.desc())
            .limit(100)
        )
    ).scalars()
    return TicketList(data=[_out(t) for t in rows])


async def create(db: AsyncSession, p: Principal, body: TicketCreate) -> TicketOut:
    company_id = _company(p)
    recent = await db.scalar(
        select(func.count()).where(
            SupportTicket.user_id == p.user.id,
            # real time, not the clock tests can move
            SupportTicket.created_at > datetime.now(UTC) - timedelta(days=1),
        )
    )
    if (recent or 0) >= PER_DAY:
        raise RateLimited(
            "rate_limited", "You've sent a lot of help requests today. Please try again tomorrow."
        )
    if body.job_id:
        ok = await db.scalar(select(Job.id).where(Job.id == body.job_id, Job.company_id == company_id))
        if not ok:
            raise AppError(
                "validation_error", "That job isn't in your company.", fields={"job_id": "unknown"}
            )
    t = SupportTicket(
        company_id=company_id, user_id=p.user.id, job_id=body.job_id, subject=body.subject,
        category=body.category, lang=p.user.app_language or "en", app_version=body.app_version,
        last_message_at=now(), last_from="user",
    )  # fmt: skip
    db.add(t)
    await db.flush()
    db.add(SupportMessage(ticket_id=t.id, user_id=p.user.id, body=body.body, created_at=t.last_message_at))
    await db.flush()
    return await get(db, p, t.id)


async def get(db: AsyncSession, p: Principal, ticket_id: uuid.UUID) -> TicketOut:
    t = await _mine(db, p, ticket_id)
    rows = (
        await db.execute(
            select(SupportMessage, User.name)
            .outerjoin(User, User.id == SupportMessage.user_id)
            .where(SupportMessage.ticket_id == t.id, SupportMessage.internal.is_(False))
            .order_by(SupportMessage.created_at, SupportMessage.id)
        )
    ).all()
    msgs = [
        TicketMessageOut(
            id=m.id,
            from_support=m.staff_id is not None,
            author=None if m.staff_id else name,
            body=m.body,
            created_at=m.created_at,
        )  # fmt: skip
        for m, name in rows
    ]
    return _out(t, msgs)


async def reply(db: AsyncSession, p: Principal, ticket_id: uuid.UUID, text: str) -> TicketOut:
    """Writing again opens the request again, also after it was solved."""
    t = await _mine(db, p, ticket_id, lock=True)
    at = now()
    db.add(SupportMessage(ticket_id=t.id, user_id=p.user.id, body=text, created_at=at))
    t.status, t.solved_at, t.last_message_at, t.last_from = "open", None, at, "user"
    await db.flush()
    return await get(db, p, t.id)


async def solve(db: AsyncSession, p: Principal, ticket_id: uuid.UUID) -> TicketOut:
    t = await _mine(db, p, ticket_id, lock=True)
    if t.status != "solved":
        t.status, t.solved_at = "solved", now()
        await db.flush()
    return await get(db, p, t.id)
