"""Jobs and their timeline (M12–M17, A11, A12).

Status machine (API document, State machines → Job). This step covers the first part; reports
(Step 1e) add the in_review / changes_requested / completed moves.

    —                  create without technician   -> unassigned   owner, manager
    — / unassigned     assign                      -> assigned     owner, manager (technician: own quick job)
    assigned           assign to someone else      -> assigned     owner, manager
    assigned           unassign                    -> unassigned   owner, manager
    assigned           start (time, location)      -> in_progress  the assigned person
    before completed   cancel (reason)             -> cancelled    owner, manager
"""

import uuid
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, or_, select, text, true
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.core.paging import check_version, decode_cursor, next_cursor
from app.core.security import normalize_phone, now
from app.models import Customer, CustomerContact, Equipment, Job, JobEvent, Membership, Site, User
from app.schemas.identity import ListMeta
from app.schemas.work import (
    AssignableList,
    AssignableTechnician,
    CustomerRef,
    JobCreate,
    JobList,
    JobListItem,
    JobOut,
    JobPatch,
    PersonRef,
    SiteBrief,
    Timeline,
    TimelineEvent,
)
from app.services import audit, notifications
from app.services.customers import can_read, contact_out, equipment_out, get_site

OPEN = ("unassigned", "assigned", "in_progress", "in_review", "changes_requested")
CLOSED = ("completed", "cancelled")


def label(number: int) -> str:
    return f"J-{number}"


# ---- time helpers -------------------------------------------------------------------------------
def tz(p: Principal) -> ZoneInfo:
    try:
        return ZoneInfo(p.company.timezone)
    except Exception:  # noqa: BLE001 - bad stored zone falls back to India
        return ZoneInfo("Asia/Kolkata")


def day_bounds_for(company) -> tuple[datetime, datetime]:
    """Today in a company's time zone, for lists that only have the company (M40 team)."""
    try:
        zone = ZoneInfo(company.timezone)
    except Exception:  # noqa: BLE001 - bad stored zone falls back to India
        zone = ZoneInfo("Asia/Kolkata")
    start = datetime.combine(now().astimezone(zone).date(), time.min, tzinfo=zone)
    return start, start + timedelta(days=1)


def local_today(p: Principal) -> date:
    return now().astimezone(tz(p)).date()


def day_bounds(p: Principal, d: date, days: int = 1) -> tuple[datetime, datetime]:
    start = datetime.combine(d, time.min, tzinfo=tz(p))
    return start, start + timedelta(days=days)


# ---- shapes -----------------------------------------------------------------------------------
async def items(db: AsyncSession, jobs: list[Job]) -> list[JobListItem]:
    if not jobs:
        return []
    cust = {
        c.id: c
        for c in (
            await db.execute(select(Customer).where(Customer.id.in_({j.customer_id for j in jobs})))
        ).scalars()
    }
    site_ids = {j.site_id for j in jobs if j.site_id}
    sites = (
        {s.id: s for s in (await db.execute(select(Site).where(Site.id.in_(site_ids)))).scalars()}
        if site_ids
        else {}
    )
    user_ids = {j.assigned_to for j in jobs if j.assigned_to}
    users = (
        {u.id: u for u in (await db.execute(select(User).where(User.id.in_(user_ids)))).scalars()}
        if user_ids
        else {}
    )
    from app.providers.storage import get_storage
    from app.services.evidence import covers

    cover_urls = await covers(db, jobs)
    storage = get_storage()
    out = []
    for j in jobs:
        s = sites.get(j.site_id)
        u = users.get(j.assigned_to)
        out.append(
            JobListItem(
                id=j.id, number=label(j.number), title=j.title, status=j.status, scheduled_at=j.scheduled_at,
                duration_min=j.duration_min,
                customer=CustomerRef(id=j.customer_id, name=cust[j.customer_id].name),
                site=SiteBrief(
                    id=s.id, label=s.label, city=s.city, lat=s.lat, lng=s.lng,
                    address=", ".join(filter(None, [s.address_line1, s.address_line2])),
                ) if s else None,
                assignee=PersonRef(
                    id=u.id, name=u.name or "",
                    avatar_url=storage.presign_get(u.avatar_key) if u.avatar_key else None,
                ) if u else None,
                is_quick_job=j.is_quick_job, version=j.version, updated_at=j.updated_at,
                cover_url=cover_urls.get(j.id),
            )
        )  # fmt: skip
    return out


def actions(p: Principal, j: Job) -> list[str]:
    a = []
    manager = "jobs.assign" in p.permissions
    own_quick = j.is_quick_job and j.assigned_to == p.user.id
    if j.status not in CLOSED and (manager or own_quick):
        a.append("edit")
    if manager and j.status in ("unassigned", "assigned"):
        a.append("assign")
    if j.status == "assigned" and j.assigned_to == p.user.id:
        a.append("start")
    if manager and j.status not in CLOSED:
        a.append("cancel")
    if manager and j.status in ("unassigned", "assigned", "cancelled") and not j.started_at:
        a.append("delete")
    return a


async def job_out(db: AsyncSession, p: Principal, j: Job) -> JobOut:
    base = (await items(db, [j]))[0]
    contact = await db.get(CustomerContact, j.contact_id) if j.contact_id else None
    equipment = await db.get(Equipment, j.equipment_id) if j.equipment_id else None
    creator = await db.get(User, j.created_by) if j.created_by else None
    return JobOut(
        **base.model_dump(),
        description=j.description,
        contact=contact_out(contact) if contact and not contact.deleted_at else None,
        equipment=equipment_out(equipment) if equipment and not equipment.deleted_at else None,
        started_at=j.started_at, completed_at=j.completed_at, cancelled_at=j.cancelled_at,
        cancel_reason=j.cancel_reason,
        created_by=PersonRef(id=creator.id, name=creator.name or "") if creator else None,
        created_at=j.created_at,
        actions=actions(p, j),
    )  # fmt: skip


# ---- reading --------------------------------------------------------------------------------
def visible(p: Principal):
    """Owners and managers see every job; technicians see jobs assigned to them."""
    q = select(Job).where(Job.company_id == p.company_id, Job.deleted_at.is_(None))
    if "jobs.view_all" not in p.permissions:
        q = q.where(Job.assigned_to == p.user.id)
    return q


async def get_job(db: AsyncSession, p: Principal, job_id: uuid.UUID, lock: bool = False) -> Job:
    q = visible(p).where(Job.id == job_id)
    if lock:
        q = q.with_for_update()
    j = (await db.execute(q)).scalar_one_or_none()
    if not j:
        raise NotFound("job_not_found", "Job not found.")
    return j


async def list_jobs(
    db: AsyncSession, p: Principal, *, day: date | None, range_: str, statuses: list[str] | None,
    assignee: uuid.UUID | None, unassigned: bool, q: str | None, customer_id: uuid.UUID | None,
    cursor: str | None, limit: int,
) -> JobList:  # fmt: skip
    offset = decode_cursor(cursor)
    base = visible(p)
    if day:
        days = {"day": 1, "week": 7, "month": 31}[range_]
        start, end = day_bounds(p, day, days)
        base = base.where(Job.scheduled_at >= start, Job.scheduled_at < end)
    if assignee:
        base = base.where(Job.assigned_to == assignee)
    if unassigned:
        base = base.where(Job.assigned_to.is_(None))
    if customer_id:
        base = base.where(Job.customer_id == customer_id)
    if q:
        like = f"%{q.strip()}%"
        num = q.strip().upper().removeprefix("J-").removeprefix("#J-")
        names = select(Customer.id).where(Customer.company_id == p.company_id, Customer.name.ilike(like))
        conds = [Job.title.ilike(like), Job.customer_id.in_(names)]
        if num.isdigit():
            conds.append(Job.number == int(num))
        base = base.where(or_(*conds))
    # tab counts use every filter except the status itself ("one call, not one per tab")
    sub = base.subquery()
    counts = {
        s: 0
        for s in (
            "unassigned",
            "assigned",
            "in_progress",
            "in_review",
            "changes_requested",
            "completed",
            "cancelled",
        )
    }
    for status, n in (await db.execute(select(sub.c.status, func.count()).group_by(sub.c.status))).all():
        counts[status] = n
    counts["all"] = sum(counts.values())
    counts["open"] = sum(counts[s] for s in OPEN)
    if statuses:
        base = base.where(Job.status.in_(statuses))
    rows = (
        (
            await db.execute(
                base.order_by(Job.scheduled_at.asc().nulls_last(), Job.number).offset(offset).limit(limit + 1)
            )
        )
        .scalars()
        .all()
    )
    return JobList(
        data=await items(db, list(rows[:limit])),
        meta=ListMeta(counts=counts, next_cursor=next_cursor(offset, limit, len(rows))),
    )


async def timeline(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> Timeline:
    j = await get_job(db, p, job_id)
    rows = (
        await db.execute(
            select(JobEvent, User.name)
            .outerjoin(User, User.id == JobEvent.actor_id)
            .where(JobEvent.job_id == j.id)
            .order_by(JobEvent.at, JobEvent.id)
        )
    ).all()
    data = [
        TimelineEvent(
            id=e.id,
            type=e.type,
            from_status=e.from_status,
            to_status=e.to_status,
            at=e.at,
            data=e.data,
            actor=PersonRef(id=e.actor_id, name=name or "") if e.actor_id else None,
        )  # fmt: skip
        for e, name in rows
    ]
    return Timeline(data=data, meta=ListMeta(counts={"all": len(data)}))


# ---- writing ---------------------------------------------------------------------------------
async def _next_number(db: AsyncSession, company_id: uuid.UUID) -> int:
    return (
        await db.execute(
            text(
                "INSERT INTO company_counters (company_id, key, value) VALUES (:c, 'job', 1001) "
                "ON CONFLICT (company_id, key) DO UPDATE SET value = company_counters.value + 1 "
                "RETURNING value"
            ),
            {"c": company_id},
        )
    ).scalar_one()


def _event(p: Principal, j: Job, type_: str, before: str | None, data: dict | None = None) -> JobEvent:
    return JobEvent(
        company_id=j.company_id, job_id=j.id, type=type_, from_status=before, to_status=j.status,
        actor_id=p.user.id, data=data or {},
    )  # fmt: skip


async def _technician(db: AsyncSession, p: Principal, user_id: uuid.UUID) -> Membership:
    m = (
        await db.execute(
            select(Membership).where(Membership.company_id == p.company_id, Membership.user_id == user_id)
        )
    ).scalar_one_or_none()
    if not m or m.role != "technician" or m.status == "removed":
        raise AppError(
            "validation_error", "Pick a technician from your team.", fields={"technician_id": "unknown"}
        )
    if m.status == "invited":
        raise Conflict(
            "invite_pending", "This technician hasn't joined yet. Assign the job once they accept."
        )
    return m


async def _check_links(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, site_id, contact_id, equipment_id
) -> None:
    if site_id:
        await get_site(db, p.company_id, site_id, customer_id)
    if contact_id:
        c = await db.get(CustomerContact, contact_id)
        if not c or c.customer_id != customer_id or c.company_id != p.company_id or c.deleted_at:
            raise AppError(
                "validation_error", "That contact is not for this customer.", fields={"contact_id": "unknown"}
            )
    if equipment_id:
        e = await db.get(Equipment, equipment_id)
        s = await db.get(Site, e.site_id) if e else None
        if not e or not s or s.customer_id != customer_id or e.company_id != p.company_id or e.deleted_at:
            raise AppError(
                "validation_error",
                "That equipment is not at this customer.",
                fields={"equipment_id": "unknown"},
            )


async def _site_for(db: AsyncSession, p: Principal, customer_id: uuid.UUID, address: str) -> uuid.UUID:
    """The customer's site with this address, or a new one (M16 lets the manager type it)."""
    typed = " ".join(address.split())
    for s in (
        await db.execute(select(Site).where(Site.customer_id == customer_id, Site.deleted_at.is_(None)))
    ).scalars():
        if ", ".join(filter(None, [s.address_line1, s.address_line2])).lower() == typed.lower():
            return s.id
    site = Site(
        company_id=p.company_id, customer_id=customer_id, address_line1=typed, country=p.company.country
    )
    db.add(site)
    await db.flush()
    return site.id


async def create_job(db: AsyncSession, p: Principal, body: JobCreate) -> tuple[Job, bool]:
    manager = "jobs.create" in p.permissions
    if not manager and "jobs.create_quick" not in p.permissions:
        raise Forbidden("forbidden", "You don't have permission to do this.", {"needs": "jobs.create"})
    if body.client_uuid:
        existing = (
            await db.execute(
                select(Job).where(Job.company_id == p.company_id, Job.client_uuid == body.client_uuid)
            )
        ).scalar_one_or_none()
        if existing:
            return existing, False
    if (body.customer_id is None) == (body.customer is None):
        raise AppError(
            "validation_error", "Pick a customer or add a new one.", fields={"customer_id": "required"}
        )
    if body.customer_id:
        if manager:
            from app.services.customers import get_customer

            await get_customer(db, p.company_id, body.customer_id)
        else:
            await can_read(db, p, body.customer_id)
        customer_id = body.customer_id
    else:
        c = Customer(company_id=p.company_id, name=body.customer.name, created_by=p.user.id)
        db.add(c)
        await db.flush()
        if body.customer.phone:
            phone = normalize_phone(body.customer.phone, p.company.country)
            db.add(
                CustomerContact(
                    company_id=p.company_id, customer_id=c.id, name=c.name, phone=phone, is_primary=True
                )
            )
        if body.customer.address:
            db.add(
                Site(
                    company_id=p.company_id,
                    customer_id=c.id,
                    address_line1=body.customer.address,
                    country=p.company.country,
                )
            )
        await db.flush()
        if body.customer.address and not body.site_id:
            body.site_id = (await db.execute(select(Site.id).where(Site.customer_id == c.id))).scalar_one()
        customer_id = c.id
    if body.customer_id and body.address and not body.site_id:
        body.site_id = await _site_for(db, p, customer_id, body.address)
    await _check_links(db, p, customer_id, body.site_id, body.contact_id, body.equipment_id)

    assignee = body.assigned_to
    if not manager:
        assignee = p.user.id  # a technician's quick job is theirs
    elif assignee:
        await _technician(db, p, assignee)
    j = Job(
        company_id=p.company_id, number=await _next_number(db, p.company_id), customer_id=customer_id,
        site_id=body.site_id, contact_id=body.contact_id, equipment_id=body.equipment_id, title=body.title,
        description=body.description, scheduled_at=body.scheduled_at or (None if manager else now()),
        duration_min=body.duration_min, status="assigned" if assignee else "unassigned", assigned_to=assignee,
        is_quick_job=not manager, created_by=p.user.id, client_uuid=body.client_uuid,
    )  # fmt: skip
    db.add(j)
    await db.flush()
    db.add(_event(p, j, "created", None, {"quick_job": j.is_quick_job}))
    if assignee:
        db.add(_event(p, j, "assigned", "unassigned", {"technician_id": str(assignee)}))
        await notifications.notify(
            db, company_id=p.company_id, to=[assignee], kind="job_assigned", actor_id=p.user.id,
            job=j, params=await notifications.job_params(db, j),
        )  # fmt: skip
    await audit.record(
        db, "job.created", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="job", target_id=j.id, data={"number": label(j.number)},
    )  # fmt: skip
    await db.flush()
    return j, True


async def update_job(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, body: JobPatch, if_match: str | None
) -> Job:
    j = await get_job(db, p, job_id, lock=True)
    if "edit" not in actions(p, j):
        if j.status in CLOSED:
            raise Conflict("job_closed", "This job is finished and can't be changed.")
        raise Forbidden("forbidden", "You don't have permission to do this.", {"needs": "jobs.create"})
    check_version(if_match, j.version, await job_out(db, p, j))
    changes = body.model_dump(exclude_unset=True)
    await _check_links(
        db, p, j.customer_id, changes.get("site_id"), changes.get("contact_id"), changes.get("equipment_id")
    )
    before = {k: getattr(j, k) for k in changes}
    for k, v in changes.items():
        setattr(j, k, v)
    if changes:
        j.version += 1
        fields = sorted(changes)
        db.add(_event(p, j, "edited", j.status, {"fields": fields}))
        await audit.record(
            db, "job.updated", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
            target_type="job", target_id=j.id,
            data={"before": {k: str(v) if v is not None else None for k, v in before.items()},
                  "after": {k: str(v) if v is not None else None for k, v in changes.items()}},
        )  # fmt: skip
    await db.flush()
    return j


async def assign(db: AsyncSession, p: Principal, job_id: uuid.UUID, technician_id: uuid.UUID | None) -> Job:
    p.require("jobs.assign")
    j = await get_job(db, p, job_id, lock=True)
    if j.status not in ("unassigned", "assigned"):
        raise Conflict("job_already_started", "This job has started; it can't be reassigned.")
    if technician_id:
        await _technician(db, p, technician_id)
    previous, before = j.assigned_to, j.status
    if previous == technician_id:
        return j
    j.assigned_to = technician_id
    j.status = "assigned" if technician_id else "unassigned"
    j.version += 1
    data = {
        "technician_id": str(technician_id) if technician_id else None,
        "previous": str(previous) if previous else None,
    }
    db.add(_event(p, j, "assigned" if technician_id else "unassigned", before, data))
    if technician_id:
        await notifications.notify(
            db, company_id=p.company_id, to=[technician_id], kind="job_assigned", actor_id=p.user.id,
            job=j, params=await notifications.job_params(db, j),
        )  # fmt: skip
    await audit.record(
        db, "job.assigned", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="job", target_id=j.id, data=data,
    )  # fmt: skip
    await db.flush()
    return j


async def start(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, lat: float | None, lng: float | None
) -> Job:
    j = await get_job(db, p, job_id, lock=True)
    if j.assigned_to != p.user.id:
        raise Forbidden("job_not_assigned_to_you", "This job is assigned to someone else.")
    if j.status == "in_progress":
        return j  # pressed twice, or a retry from the offline queue
    if j.status != "assigned":
        raise Conflict("invalid_transition", "This job can't be started now.", {"status": j.status})
    j.status, j.started_at, j.start_lat, j.start_lng = "in_progress", now(), lat, lng
    j.version += 1
    db.add(_event(p, j, "started", "assigned", {"lat": lat, "lng": lng} if lat is not None else {}))
    await db.flush()
    return j


async def cancel(db: AsyncSession, p: Principal, job_id: uuid.UUID, reason: str) -> Job:
    p.require("jobs.assign")
    j = await get_job(db, p, job_id, lock=True)
    if j.status in CLOSED:
        raise Conflict("job_closed", "This job is already finished.")
    before = j.status
    j.status, j.cancelled_at, j.cancel_reason = "cancelled", now(), reason
    j.version += 1
    db.add(_event(p, j, "cancelled", before, {"reason": reason}))
    await audit.record(
        db, "job.cancelled", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="job", target_id=j.id, data={"before": before, "reason": reason},
    )  # fmt: skip
    await db.flush()
    return j


async def delete(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> None:
    p.require("jobs.assign")
    j = await get_job(db, p, job_id, lock=True)
    if "delete" not in actions(p, j):
        raise Conflict("job_has_work", "This job has started. Cancel it instead of deleting.")
    j.deleted_at = now()
    j.version += 1
    await audit.record(
        db, "job.deleted", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="job", target_id=j.id, data={"number": label(j.number)},
    )  # fmt: skip


async def assignable(
    db: AsyncSession, p: Principal, job_id: uuid.UUID | None = None, at: datetime | None = None
) -> AssignableList:
    """Technicians to pick on M17, with their jobs that day. Before a job exists (M16), `at` gives the day."""
    p.require("jobs.assign")
    j = await get_job(db, p, job_id) if job_id else None
    when = j.scheduled_at if j else at
    day = when.astimezone(tz(p)).date() if when else local_today(p)
    start_, end_ = day_bounds(p, day)
    other = Job.id != j.id if j else true()
    jobs_today = (
        select(Job.assigned_to, func.count().label("n"))
        .where(
            Job.company_id == p.company_id, Job.deleted_at.is_(None), Job.status != "cancelled",
            Job.scheduled_at >= start_, Job.scheduled_at < end_, other,
        )
        .group_by(Job.assigned_to)
        .subquery()
    )  # fmt: skip
    rows = (
        await db.execute(
            select(Membership, User, func.coalesce(jobs_today.c.n, 0))
            .join(User, User.id == Membership.user_id)
            .outerjoin(jobs_today, jobs_today.c.assigned_to == Membership.user_id)
            .where(
                Membership.company_id == p.company_id,
                Membership.role == "technician",
                Membership.status.in_(("active", "invited")),
            )
        )
    ).all()
    from app.providers.storage import get_storage

    storage = get_storage()
    out = []
    for m, u, n in rows:
        # invited people are shown but disabled (M17); a full day is a hint, not a block
        reason = "invite_pending" if m.status == "invited" else None
        out.append(
            AssignableTechnician(
                id=u.id,
                name=u.name or "",
                phone=u.phone,
                status=m.status,
                jobs_today=n,
                capacity=m.daily_job_capacity,
                available=reason is None and n < m.daily_job_capacity,
                disabled_reason=reason,
                avatar_url=storage.presign_get(u.avatar_key) if u.avatar_key else None,
            )  # fmt: skip
        )
    out.sort(key=lambda t: (t.status != "active", not t.available, t.jobs_today, t.name.lower()))
    return AssignableList(
        data=out, meta=ListMeta(counts={"all": len(out), "available": sum(t.available for t in out)})
    )
