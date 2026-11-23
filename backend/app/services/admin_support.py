"""A28 Support tickets (staff side) and A29 Notifications: automatic messages and announcements."""

import csv
import io
import uuid
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import (
    Announcement,
    Company,
    Job,
    Membership,
    Plan,
    StaffUser,
    SupportMessage,
    SupportTicket,
    User,
)
from app.schemas.support import (
    LANGS,
    AdminAnnouncementIn,
    AdminAnnouncementOut,
    AdminNotificationsOut,
    AdminRule,
    AdminTicketDetail,
    AdminTicketList,
    AdminTicketMessage,
    AdminTicketRow,
)
from app.services import audit, notifications, platform
from app.services.admin_companies import _csv_safe
from app.services.checklists import pick
from app.services.jobs import label as jlabel
from app.services.support import tlabel

TABS = {"open": ("open",), "waiting": ("waiting",), "solved": ("solved",)}
ORDER_HIGH = func.coalesce((SupportTicket.priority == "high") & (SupportTicket.status != "solved"), False)


# ---- A28 tickets -------------------------------------------------------------------------------------
def _filters(q: str | None) -> list:
    if not q or not q.strip():
        return []
    q = q.strip()
    like = f"%{q}%"
    conds = [SupportTicket.subject.ilike(like), Company.name.ilike(like), User.name.ilike(like)]
    num = q.upper().removeprefix("#").removeprefix("T-")
    if num.isdigit():
        conds.append(SupportTicket.number == int(num))
    return [or_(*conds)]


def _base(where: list):
    return (
        select(SupportTicket, Company.name, User.name)
        .outerjoin(Company, Company.id == SupportTicket.company_id)
        .outerjoin(User, User.id == SupportTicket.user_id)
        .where(*where)
    )


def _row(t: SupportTicket, company: str | None, person: str | None) -> dict:
    return dict(
        id=t.id,
        number=tlabel(t.number),
        subject=t.subject,
        category=t.category,
        status=t.status,
        priority=t.priority,
        company=company,
        company_id=t.company_id,
        person=person,
        created_at=t.created_at,
        last_message_at=t.last_message_at,
        last_from=t.last_from,
    )


async def tickets(db: AsyncSession, *, tab: str, q: str | None, page: int, page_size: int) -> AdminTicketList:
    where = _filters(q)
    counts = dict(
        (
            await db.execute(
                select(SupportTicket.status, func.count())
                .select_from(SupportTicket)
                .outerjoin(Company, Company.id == SupportTicket.company_id)
                .outerjoin(User, User.id == SupportTicket.user_id)
                .where(*where)
                .group_by(SupportTicket.status)
            )
        ).all()
    )
    high = await db.scalar(
        select(func.count()).where(SupportTicket.priority == "high", SupportTicket.status != "solved")
    )
    if tab in TABS:
        where.append(SupportTicket.status.in_(TABS[tab]))
    total = int(await db.scalar(select(func.count()).select_from(_base(where).subquery())) or 0)
    # high first, then the ones waiting on us longest
    order = (ORDER_HIGH.desc(), (SupportTicket.status == "solved"), SupportTicket.last_message_at.asc())
    if tab == "solved" or tab == "all":
        order = (SupportTicket.last_message_at.desc(),)
    rows = (
        await db.execute(_base(where).order_by(*order).offset((page - 1) * page_size).limit(page_size))
    ).all()
    return AdminTicketList(
        items=[AdminTicketRow(**_row(t, c, u)) for t, c, u in rows],
        total=total,
        page=page,
        page_size=page_size,
        counts={**{s: int(counts.get(s, 0)) for s in ("open", "waiting", "solved")}, "high": int(high or 0)},
    )


async def ticket(db: AsyncSession, ticket_id: uuid.UUID, lang: str) -> AdminTicketDetail:
    row = (await db.execute(_base([SupportTicket.id == ticket_id]))).first()
    if not row:
        raise NotFound("not_found", "Ticket not found.")
    t, company, person = row
    c = await db.get(Company, t.company_id) if t.company_id else None
    plan = await db.get(Plan, c.plan_code) if c else None
    user = await db.get(User, t.user_id) if t.user_id else None
    role = (
        await db.scalar(
            select(Membership.role).where(
                Membership.user_id == t.user_id, Membership.company_id == t.company_id
            )
        )
        if user and c
        else None
    )
    job = await db.get(Job, t.job_id) if t.job_id else None
    msgs = (
        await db.execute(
            select(SupportMessage, User.name, StaffUser.name)
            .outerjoin(User, User.id == SupportMessage.user_id)
            .outerjoin(StaffUser, StaffUser.id == SupportMessage.staff_id)
            .where(SupportMessage.ticket_id == t.id)
            .order_by(SupportMessage.created_at, SupportMessage.id)
        )
    ).all()
    return AdminTicketDetail(
        **_row(t, company, person),
        plan=pick(plan.name, lang) if plan else None,
        company_status=c.status if c else None,
        person_role=role,
        person_phone=user.phone if user else None,
        lang=t.lang,
        app_version=t.app_version,
        job_id=t.job_id,
        job_number=jlabel(job.number) if job else None,
        messages=[
            AdminTicketMessage(
                id=m.id,
                from_support=m.staff_id is not None,
                internal=m.internal,
                author=staff if m.staff_id else uname,
                body=m.body,
                created_at=m.created_at,
            )
            for m, uname, staff in msgs
        ],
    )


async def staff_reply(
    db: AsyncSession,
    ticket_id: uuid.UUID,
    text: str,
    *,
    internal: bool,
    solve: bool,
    staff_id: uuid.UUID,
    ip: str | None,
    lang: str,
) -> AdminTicketDetail:
    """A reply goes to the person (and their Messages); an internal note stays with staff."""
    t = await db.get(SupportTicket, ticket_id, with_for_update=True)
    if not t:
        raise NotFound("not_found", "Ticket not found.")
    at = now()
    db.add(SupportMessage(ticket_id=t.id, staff_id=staff_id, body=text, internal=internal, created_at=at))
    if not internal:
        t.last_message_at, t.last_from = at, "staff"
        t.status, t.solved_at = ("solved", at) if solve else ("waiting", None)
        if t.user_id and t.company_id:
            await notifications.notify(
                db,
                company_id=t.company_id,
                to=[t.user_id],
                kind="support_reply",
                actor_id=None,
                params={"ticket": tlabel(t.number), "subject": t.subject, "ticket_id": str(t.id)},
            )
    await audit.record(
        db,
        "support.note" if internal else "support.replied",
        staff_id=staff_id,
        target_type="support_ticket",
        target_id=t.id,
        data={"ticket": tlabel(t.number)},
        ip=ip,
    )
    await db.flush()
    return await ticket(db, t.id, lang)


async def change(
    db: AsyncSession,
    ticket_id: uuid.UUID,
    *,
    status: str | None,
    priority: str | None,
    staff_id: uuid.UUID,
    ip: str | None,
    lang: str,
) -> AdminTicketDetail:
    t = await db.get(SupportTicket, ticket_id, with_for_update=True)
    if not t:
        raise NotFound("not_found", "Ticket not found.")
    changes = {}
    if status and status != t.status:
        changes["status"] = {"from": t.status, "to": status}
        t.status, t.solved_at = status, now() if status == "solved" else None
    if priority and priority != t.priority:
        changes["priority"] = {"from": t.priority, "to": priority}
        t.priority = priority
    if changes:
        await audit.record(
            db,
            "support.updated",
            staff_id=staff_id,
            target_type="support_ticket",
            target_id=t.id,
            data={"ticket": tlabel(t.number), **changes},
            ip=ip,
        )
        await db.flush()
    return await ticket(db, t.id, lang)


async def tickets_csv(db: AsyncSession, *, tab: str, q: str | None) -> str:
    where = _filters(q)
    if tab in TABS:
        where.append(SupportTicket.status.in_(TABS[tab]))
    rows = (await db.execute(_base(where).order_by(SupportTicket.created_at.desc()).limit(50_000))).all()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(
        ["Ticket", "Subject", "Category", "Status", "Priority", "Company", "Person", "Opened", "Last message"]
    )
    for t, company, person in rows:
        w.writerow(
            [
                _csv_safe(x)
                for x in (
                    tlabel(t.number),
                    t.subject,
                    t.category,
                    t.status,
                    t.priority,
                    company or "",
                    person or "",
                    t.created_at.isoformat(timespec="minutes"),
                    t.last_message_at.isoformat(timespec="minutes"),
                )
            ]
        )
    return buf.getvalue()


# ---- A29 notifications -------------------------------------------------------------------------------
# who each in-app message goes to (shown on the page)
RULE_TO = {
    "job_assigned": "technician",
    "report_submitted": "office",
    "changes_requested": "technician",
    "report_approved": "technician",
    "report_shared": "technician",
    "review_received": "technician",
    "low_rating": "office",
    "tech_question": "office",
    "support_reply": "person",
}
EMAIL_ONLY = ("plan_limit", "trial_ending", "weekly_summary")  # need the email service (D-96)
ROLES = {"everyone": None, "owners_managers": ("owner", "manager"), "owners": ("owner",), "company": None}


def _members(audience: str, company_id: uuid.UUID | None):
    q = (
        select(Membership.user_id, Membership.company_id)
        .join(Company, Company.id == Membership.company_id)
        .where(Membership.status == "active", Company.status.in_(("trial", "active", "past_due")))
    )
    if ROLES.get(audience):
        q = q.where(Membership.role.in_(ROLES[audience]))
    if audience == "company":
        q = q.where(Membership.company_id == company_id)
    return q


async def overview(db: AsyncSession, *, can_act: bool) -> AdminNotificationsOut:
    rules = await platform.notification_rules(db)
    out_rules = [
        AdminRule(kind=k, on=rules.allows(k), to=RULE_TO[k], channel="in_app", available=True)
        for k in platform.IN_APP_KINDS
    ] + [AdminRule(kind=k, on=False, to="owner", channel="email", available=False) for k in EMAIL_ONLY]
    rows = (
        await db.execute(
            select(Announcement, Company.name, StaffUser.name)
            .outerjoin(Company, Company.id == Announcement.company_id)
            .outerjoin(StaffUser, StaffUser.id == Announcement.created_by)
            .order_by(Announcement.send_at.desc())
            .limit(30)
        )
    ).all()
    sizes = {}
    for a in ("everyone", "owners_managers", "owners"):
        sizes[a] = int(await db.scalar(select(func.count()).select_from(_members(a, None).subquery())) or 0)
    return AdminNotificationsOut(
        rules=out_rules,
        announcements=[
            AdminAnnouncementOut(
                id=a.id,
                audience=a.audience,
                company=c,
                title=a.title,
                body=a.body,
                send_at=a.send_at,
                sent_at=a.sent_at,
                cancelled_at=a.cancelled_at,
                recipients=a.recipients,
                by=by,
            )
            for a, c, by in rows
        ],
        audience_sizes=sizes,
        can_act=can_act,
    )


async def save_rules(db: AsyncSession, on: dict[str, bool], *, staff_id, ip) -> AdminNotificationsOut:
    unknown = set(on) - set(platform.IN_APP_KINDS)
    if unknown:
        raise AppError("validation_error", "Unknown message.", fields={k: "unknown" for k in unknown})
    before = await platform.notification_rules(db)
    after = platform.NotificationRules(on={**before.on, **on})
    await platform.set_notification_rules(db, after, staff_id=staff_id)
    changes = {k: v for k, v in on.items() if before.on.get(k) != v}
    if changes:
        await audit.record(
            db, "notifications.rules", staff_id=staff_id, target_type="platform", data=changes, ip=ip
        )
    return await overview(db, can_act=True)


async def _send(db: AsyncSession, a: Announcement) -> int:
    params = {f"title_{k}": v for k, v in a.title.items()} | {f"body_{k}": v for k, v in a.body.items()}
    n = 0
    for user_id, company_id in (await db.execute(_members(a.audience, a.company_id))).all():
        await notifications.notify(
            db, company_id=company_id, to=[user_id], kind="announcement", actor_id=None, params=params
        )
        n += 1
    a.sent_at, a.recipients = now(), n
    return n


async def announce(db: AsyncSession, body: AdminAnnouncementIn, *, staff_id, ip) -> AdminNotificationsOut:
    if body.audience == "company":
        if not body.company_id or not await db.get(Company, body.company_id):
            raise AppError("validation_error", "Pick the company.", fields={"company_id": "required"})
    t = now()
    send_at = body.send_at if body.send_at and body.send_at > t else t
    a = Announcement(
        audience=body.audience,
        company_id=body.company_id if body.audience == "company" else None,
        title=body.title,
        body=body.body,
        send_at=send_at,
        created_by=staff_id,
    )
    db.add(a)
    await db.flush()
    if send_at <= t:
        await _send(db, a)
    await audit.record(
        db,
        "announcement.created",
        staff_id=staff_id,
        target_type="announcement",
        target_id=a.id,
        data={
            "audience": a.audience,
            "title": a.title.get("en"),
            "send_at": send_at.isoformat(),
            "recipients": a.recipients,
        },
        ip=ip,
    )
    await db.flush()
    return await overview(db, can_act=True)


async def cancel(db: AsyncSession, announcement_id: uuid.UUID, *, staff_id, ip) -> AdminNotificationsOut:
    a = await db.get(Announcement, announcement_id, with_for_update=True)
    if not a:
        raise NotFound("not_found", "Announcement not found.")
    if a.sent_at:
        raise AppError("already_sent", "It has already been sent.", status=409)
    if not a.cancelled_at:
        a.cancelled_at = now()
        await audit.record(
            db, "announcement.cancelled", staff_id=staff_id, target_type="announcement", target_id=a.id, ip=ip
        )
        await db.flush()
    return await overview(db, can_act=True)


async def send_due(db: AsyncSession, at: datetime | None = None) -> int:
    """Called by the scheduler: sends announcements whose time has come."""
    due = (
        (
            await db.execute(
                select(Announcement)
                .where(
                    Announcement.sent_at.is_(None),
                    Announcement.cancelled_at.is_(None),
                    Announcement.send_at <= (at or now()),
                )
                .with_for_update(skip_locked=True)
            )
        )
        .scalars()
        .all()
    )
    for a in due:
        await _send(db, a)
    await db.flush()
    return len(due)


__all__ = ["LANGS"]
