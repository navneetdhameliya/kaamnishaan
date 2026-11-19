"""Website leads for KaamNishaan staff: a list with tabs, the details, and status / note changes."""

import csv
import io
import uuid

from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound
from app.core.security import now
from app.models import Company, Industry, Lead, Membership, StaffUser, User
from app.schemas.admin_leads import (
    AdminLeadCounts,
    AdminLeadDetail,
    AdminLeadList,
    AdminLeadRow,
    AdminLeadUpdate,
)
from app.services import audit
from app.services.checklists import pick

TABS = ("new", "demo", "contact", "newsletter", "done")
OPEN = ("new",)
CLOSED = ("contacted", "done", "spam")


def _tab(stmt: Select, tab: str) -> Select:
    if tab == "new":
        return stmt.where(Lead.kind.in_(("demo", "contact")), Lead.status == "new")
    if tab == "done":
        return stmt.where(Lead.kind.in_(("demo", "contact")), Lead.status.in_(CLOSED))
    return stmt.where(Lead.kind == tab)


def _search(stmt: Select, q: str | None) -> Select:
    if not q or not q.strip():
        return stmt
    raw = q.strip()
    like = f"%{raw}%"
    conds = [
        Lead.name.ilike(like),
        Lead.email.ilike(like),
        Lead.company.ilike(like),
        Lead.message.ilike(like),
    ]
    digits = raw.upper().removeprefix("KN-")
    if digits.isdigit():
        conds.append(Lead.number == int(digits))
    return stmt.where(or_(*conds))


def _row(x: Lead) -> AdminLeadRow:
    text = (x.message or "").strip().replace("\n", " ")
    return AdminLeadRow(
        id=x.id,
        number=x.number,
        kind=x.kind,
        status=x.status if x.status in ("new", "contacted", "done", "spam") else "new",
        name=x.name,
        email=x.email,
        company=x.company,
        topic=x.topic,
        starts_at=x.starts_at,
        preview=(text[:117] + "…") if len(text) > 120 else (text or None),
        created_at=x.created_at,
    )


async def leads(db: AsyncSession, *, tab: str, q: str | None, page: int, page_size: int) -> AdminLeadList:
    counts = {}
    for t in TABS:
        counts[t] = int(
            await db.scalar(select(func.count()).select_from(_tab(select(Lead.id), t).subquery())) or 0
        )
    stmt = _search(_tab(select(Lead), tab), q)
    total = int(
        await db.scalar(select(func.count()).select_from(stmt.with_only_columns(Lead.id).subquery())) or 0
    )
    # upcoming demos first by their time; everything else newest first
    order = (
        (Lead.starts_at.asc().nulls_last(), Lead.created_at.desc())
        if tab == "demo"
        else (Lead.created_at.desc(),)
    )
    rows = (await db.execute(stmt.order_by(*order).offset((page - 1) * page_size).limit(page_size))).scalars()
    return AdminLeadList(
        items=[_row(x) for x in rows],
        total=total,
        page=page,
        page_size=page_size,
        counts=AdminLeadCounts(**counts),
    )


async def _lead(db: AsyncSession, lead_id: uuid.UUID) -> Lead:
    x = await db.get(Lead, lead_id)
    if not x:
        raise NotFound("lead_not_found", "This lead doesn't exist.")
    return x


async def lead(db: AsyncSession, lead_id: uuid.UUID, *, lang: str) -> AdminLeadDetail:
    x = await _lead(db, lead_id)
    trade = await db.get(Industry, x.trade) if x.trade else None
    staff = await db.get(StaffUser, x.handled_by) if x.handled_by else None
    # did this person already sign up? (an owner with the same email)
    match = (
        await db.execute(
            select(Company.id, Company.name)
            .join(Membership, Membership.company_id == Company.id)
            .join(User, User.id == Membership.user_id)
            .where(func.lower(User.email) == x.email.lower(), Membership.role == "owner")
            .limit(1)
        )
    ).first()
    return AdminLeadDetail(
        **_row(x).model_dump(),
        phone=x.phone,
        team_size=x.team_size,
        trade=pick(trade.name, lang) if trade else x.trade,
        message=x.message,
        lang=x.lang,
        note=x.note,
        handled_by=staff.name if staff else None,
        handled_at=x.handled_at,
        company_id=match[0] if match else None,
        company_name=match[1] if match else None,
    )


async def update(
    db: AsyncSession,
    lead_id: uuid.UUID,
    body: AdminLeadUpdate,
    *,
    staff_id: uuid.UUID,
    ip: str | None,
    lang: str,
) -> AdminLeadDetail:
    x = await _lead(db, lead_id)
    changed: dict = {}
    if body.status is not None and body.status != x.status:
        changed["status"] = {"from": x.status, "to": body.status}
        x.status = body.status
    if body.note is not None and (body.note.strip() or None) != x.note:
        x.note = body.note.strip() or None
        changed["note"] = True  # the text itself stays out of the audit log
    if changed:
        x.handled_by, x.handled_at = staff_id, now()
        await audit.record(
            db,
            "staff.lead_updated",
            staff_id=staff_id,
            target_type="lead",
            target_id=x.id,
            data=changed,
            ip=ip,
        )
        await db.flush()
    return await lead(db, x.id, lang=lang)


def _csv_safe(v: object) -> str:
    s = "" if v is None else str(v)
    return "'" + s if s[:1] in ("=", "+", "-", "@", "\t", "\r") else s


async def newsletter_csv(db: AsyncSession) -> str:
    rows = (
        await db.execute(select(Lead).where(Lead.kind == "newsletter").order_by(Lead.created_at))
    ).scalars()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(("Email", "Language", "Signed up"))
    for x in rows:
        w.writerow([_csv_safe(x.email), x.lang, x.created_at.date().isoformat()])
    return "﻿" + buf.getvalue()
