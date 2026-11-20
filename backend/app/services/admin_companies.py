"""A04 Companies list and A05 Company details for KaamNishaan staff. Read only (edit and suspend come
with A06/A07). Every figure is counted from the database."""

import csv
import io
import math
import statistics
import uuid
from collections.abc import Iterable
from datetime import timedelta

from sqlalchemy import Select, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, NotFound
from app.core.security import digest, normalize_phone, now, random_token
from app.models import AIUsage, Company, Industry, Invitation, Job, Membership, Plan, Report, User
from app.providers.messaging import SMS_TEMPLATES, send_sms
from app.schemas.admin_companies import (
    AdminCompanyCounts,
    AdminCompanyCreate,
    AdminCompanyDetail,
    AdminCompanyList,
    AdminCompanyRow,
    AdminCompanyUpdate,
    AdminOption,
    AdminPlanInfo,
    AdminTeamMember,
)
from app.schemas.identity import CompanySettings
from app.services import audit, platform
from app.services.checklists import pick
from app.services.companies import CURRENCY_BY_COUNTRY, check_trade
from app.services.credits import cycle
from app.services.team import INVITE_TTL

NEAR_LIMIT = 0.9
QUIET_AFTER = timedelta(days=14)
STATUSES = ("trial", "active", "past_due", "suspended", "cancelled")
SORTS = ("reports", "name", "newest", "technicians")
ROLE_ORDER = {"owner": 0, "manager": 1, "technician": 2}


def _owner():
    """The first owner of each company: (company_id, name, email, phone)."""
    first = (
        select(
            Membership.company_id,
            User.name,
            User.email,
            User.phone,
            func.row_number()
            .over(partition_by=Membership.company_id, order_by=Membership.created_at)
            .label("n"),
        )
        .join(User, User.id == Membership.user_id)
        .where(Membership.role == "owner", Membership.status == "active")
        .subquery()
    )
    return select(first).where(first.c.n == 1).subquery()


def _techs():
    return (
        select(func.count())
        .where(
            Membership.company_id == Company.id,
            Membership.role == "technician",
            Membership.status == "active",
        )
        .correlate(Company)
        .scalar_subquery()
    )


def _reports_30d(since):
    return (
        select(func.count())
        .where(Report.company_id == Company.id, Report.created_at >= since)
        .correlate(Company)
        .scalar_subquery()
    )


def _filtered(q: str | None, plan: str | None, industry: str | None, country: str | None, owner) -> Select:
    stmt = select(Company).outerjoin(owner, owner.c.company_id == Company.id)
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                Company.name.ilike(like),
                owner.c.name.ilike(like),
                owner.c.email.ilike(like),
                owner.c.phone.ilike(like),
            )
        )
    if plan:
        stmt = stmt.where(Company.plan_code == plan)
    if industry:
        stmt = stmt.where(Company.industry_slug == industry)
    if country:
        stmt = stmt.where(Company.country == country.upper())
    return stmt


async def _plans(db: AsyncSession) -> list[Plan]:
    return list((await db.execute(select(Plan).order_by(Plan.sort))).scalars())


async def _reports_in_cycle(db: AsyncSession, company: Company) -> int:
    start, _ = cycle(company, now())
    q = select(func.count()).where(Report.company_id == company.id, Report.created_at >= start)
    return int(await db.scalar(q) or 0)


def _badge(company: Company, used: int, plan: Plan | None) -> str:
    if company.status == "active" and plan and plan.report_limit_monthly:
        if used >= plan.report_limit_monthly * NEAR_LIMIT:
            return "near_limit"
    return company.status


def _days_left(company: Company) -> int | None:
    if company.status != "trial" or not company.trial_ends_at:
        return None
    return max(0, math.ceil((company.trial_ends_at - now()).total_seconds() / 86400))


async def _rows(
    db: AsyncSession,
    *,
    lang: str,
    q: str | None,
    status: str | None,
    plan: str | None,
    industry: str | None,
    country: str | None,
    sort: str,
    limit: int | None,
    offset: int = 0,
) -> tuple[list[AdminCompanyRow], int, dict[str, int]]:
    owner = _owner()
    base = _filtered(q, plan, industry, country, owner)
    found = base.subquery()
    counts = dict((await db.execute(select(found.c.status, func.count()).group_by(found.c.status))).all())
    if status:
        base = base.where(Company.status == status)
    total = int(await db.scalar(select(func.count()).select_from(base.subquery())) or 0)

    techs, reports = _techs().label("techs"), _reports_30d(now() - timedelta(days=30)).label("reports")
    order = {
        "reports": (reports.desc(), Company.name),
        "name": (func.lower(Company.name), Company.created_at),
        "newest": (Company.created_at.desc(),),
        "technicians": (techs.desc(), Company.name),
    }[sort]
    stmt = (
        base.add_columns(owner.c.name, owner.c.email, techs, reports, Industry.name)
        .outerjoin(Industry, Industry.slug == Company.industry_slug)
        .order_by(*order)
        .offset(offset)
    )
    if limit:
        stmt = stmt.limit(limit)
    plans = {p.code: p for p in await _plans(db)}
    out = []
    for c, owner_name, owner_email, n_techs, n_reports, industry_name in (await db.execute(stmt)).all():
        p = plans.get(c.plan_code)
        used = await _reports_in_cycle(db, c) if c.status == "active" and p and p.report_limit_monthly else 0
        out.append(
            AdminCompanyRow(
                id=c.id,
                name=c.name,
                owner_name=owner_name,
                owner_email=owner_email,
                country=c.country,
                industry=pick(industry_name, lang) if industry_name else None,
                plan_code=c.plan_code,
                plan=pick(p.name, lang) if p else c.plan_code,
                technicians=n_techs,
                technician_limit=p.technician_limit if p else None,
                reports_30d=n_reports,
                status=c.status,
                badge=_badge(c, used, p),
                trial_days_left=_days_left(c),
                created_at=c.created_at,
            )
        )
    return out, total, counts


async def companies(
    db: AsyncSession,
    *,
    lang: str,
    q: str | None,
    status: str | None,
    plan: str | None,
    industry: str | None,
    country: str | None,
    sort: str,
    page: int,
    page_size: int,
) -> AdminCompanyList:
    items, total, counts = await _rows(
        db,
        lang=lang,
        q=q,
        status=status,
        plan=plan,
        industry=industry,
        country=country,
        sort=sort,
        limit=page_size,
        offset=(page - 1) * page_size,
    )
    plans = await _plans(db)
    industries = (await db.execute(select(Industry).order_by(Industry.sort))).scalars().all()
    countries = (
        (await db.execute(select(Company.country).distinct().order_by(Company.country))).scalars().all()
    )
    return AdminCompanyList(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        counts=AdminCompanyCounts(all=sum(counts.values()), **{s: counts.get(s, 0) for s in STATUSES}),
        plans=[AdminOption(value=p.code, label=pick(p.name, lang)) for p in plans],
        industries=[AdminOption(value=i.slug, label=pick(i.name, lang)) for i in industries],
        countries=list(countries),
    )


CSV_HEADER = (
    "Company",
    "Owner",
    "Owner email",
    "Country",
    "Industry",
    "Plan",
    "Technicians",
    "Technician limit",
    "Reports (30 days)",
    "Status",
    "Trial days left",
    "Created",
)


def _csv_safe(v: object) -> str:
    """Text that a spreadsheet won't run as a formula (=, +, -, @ at the start)."""
    s = "" if v is None else str(v)
    return "'" + s if s[:1] in ("=", "+", "-", "@", "\t", "\r") else s


async def companies_csv(db: AsyncSession, **filters) -> Iterable[str]:
    rows, _, _ = await _rows(db, limit=None, **filters)
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(CSV_HEADER)
    for r in rows:
        w.writerow(
            [
                _csv_safe(x)
                for x in (
                    r.name,
                    r.owner_name,
                    r.owner_email,
                    r.country,
                    r.industry,
                    r.plan,
                    r.technicians,
                    r.technician_limit if r.technician_limit is not None else "",
                    r.reports_30d,
                    r.badge,
                    r.trial_days_left if r.trial_days_left is not None else "",
                    r.created_at.date().isoformat(),
                )
            ]
        )
    return ["﻿" + buf.getvalue()]  # BOM so Excel reads Hindi and Gujarati names


def _plan_info(p: Plan, lang: str) -> AdminPlanInfo:
    return AdminPlanInfo(
        code=p.code,
        name=pick(p.name, lang),
        prices=p.prices or {},
        technician_limit=p.technician_limit,
        report_limit_monthly=p.report_limit_monthly,
    )


async def company(db: AsyncSession, company_id: uuid.UUID, *, lang: str) -> AdminCompanyDetail:
    c = await db.get(Company, company_id)
    if not c:
        raise NotFound("company_not_found", "This company doesn't exist.")
    t = now()
    plans = await _plans(db)
    plan = next((p for p in plans if p.code == c.plan_code), None)
    if plan is None:
        raise NotFound("plan_not_found", "This company's plan doesn't exist.")
    industry = await db.get(Industry, c.industry_slug) if c.industry_slug else None
    start, end = cycle(c, t)

    members = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(Membership.company_id == c.id, Membership.status != "removed")
        )
    ).all()
    # invited people have no name yet: use the newest name on their invite
    invite_names: dict[uuid.UUID, str] = {}
    nameless = [m.id for m, u in members if not u.name]
    if nameless:
        for mid, name in (
            await db.execute(
                select(Invitation.membership_id, Invitation.name)
                .where(Invitation.membership_id.in_(nameless))
                .order_by(Invitation.created_at)
            )
        ).all():
            invite_names[mid] = name

    def name_of(m: Membership, u: User) -> str | None:
        return u.name or invite_names.get(m.id)

    members.sort(key=lambda mu: (ROLE_ORDER.get(mu[0].role, 9), (name_of(*mu) or "").lower()))
    owner_row = next(
        ((m, u) for m, u in members if m.role == "owner" and m.status == "active"), None
    ) or next(((m, u) for m, u in members if m.role == "owner"), None)
    owner = owner_row[1] if owner_row else None
    owner_name = name_of(*owner_row) if owner_row else None
    active = [(m, u) for m, u in members if m.status == "active"]
    techs = sum(1 for m, _ in active if m.role == "technician")
    seen = [u.last_seen_at for _, u in active if u.last_seen_at]
    last_active = max(seen) if seen else None

    jobs = int(
        await db.scalar(
            select(func.count()).where(
                Job.company_id == c.id, Job.created_at >= start, Job.deleted_at.is_(None)
            )
        )
        or 0
    )
    reports = int(
        await db.scalar(select(func.count()).where(Report.company_id == c.id, Report.created_at >= start))
        or 0
    )
    since = t - timedelta(days=30)
    waits = (
        await db.execute(
            select(Report.approved_at, Job.completed_at)
            .join(Job, Job.id == Report.job_id)
            .where(
                Report.company_id == c.id,
                Report.approved_at >= since,
                Job.completed_at.is_not(None),
                Report.approved_at >= Job.completed_at,
            )
        )
    ).all()
    median = round(statistics.median((a - b).total_seconds() / 60 for a, b in waits), 1) if waits else None
    cost = float(
        await db.scalar(
            select(func.sum(AIUsage.cost_usd)).where(AIUsage.company_id == c.id, AIUsage.at >= since)
        )
        or 0
    )
    drafted = int(
        await db.scalar(select(func.count()).where(Report.company_id == c.id, Report.created_at >= since))
        or 0
    )

    if c.status in ("past_due", "suspended"):
        health = "at_risk"
    elif not last_active or t - last_active > QUIET_AFTER:
        health = "quiet"
    else:
        health = "good"

    over_reports = plan.report_limit_monthly is not None and reports >= plan.report_limit_monthly
    over_seats = plan.technician_limit is not None and techs >= plan.technician_limit
    upgrade = None
    if over_reports or over_seats:
        bigger = [p for p in plans if p.is_public and p.sort > plan.sort and p.prices]
        upgrade = _plan_info(bigger[0], lang) if bigger else None

    return AdminCompanyDetail(
        id=c.id,
        name=c.name,
        industry_slug=c.industry_slug,
        status=c.status,
        suspended_at=c.suspended_at,
        suspend_reason=c.suspend_reason,
        badge=_badge(c, reports, plan),
        trial_ends_at=c.trial_ends_at,
        created_at=c.created_at,
        country=c.country,
        currency=c.currency,
        timezone=c.timezone,
        report_language=c.report_language,
        industry=pick(industry.name, lang) if industry else None,
        plan=_plan_info(plan, lang),
        owner_name=owner_name,
        owner_email=owner.email if owner else None,
        owner_phone=owner.phone if owner else None,
        owner_user_id=owner.id if owner else None,
        owner_pending=bool(owner_row and owner_row[0].status == "invited"),
        health=health,
        last_active_at=last_active,
        cycle_start=start,
        cycle_end=end,
        jobs_this_cycle=jobs,
        reports_this_cycle=reports,
        technicians=techs,
        members=len(active),
        approval_minutes_median=median,
        ai_cost_30d_usd=round(cost, 4),
        ai_cost_per_report_usd=round(cost / drafted, 4) if drafted else None,
        team=[
            AdminTeamMember(
                id=u.id,
                name=name_of(m, u),
                role=m.role,
                login="email" if u.email and u.password_hash else "phone",
                language=u.app_language,
                status=m.status,
                last_seen_at=u.last_seen_at,
            )
            for m, u in members[:5]
        ],
        upgrade_to=upgrade,
    )


# ---- A06 create, A07 edit, suspend --------------------------------------------------------------------
TIMEZONE_BY_COUNTRY = {
    "IN": "Asia/Kolkata", "US": "America/New_York", "GB": "Europe/London", "AE": "Asia/Dubai",
    "CA": "America/Toronto", "AU": "Australia/Sydney", "ES": "Europe/Madrid", "FR": "Europe/Paris",
    "MX": "America/Mexico_City",
}  # fmt: skip


def _fields(**errors: str) -> AppError:
    return AppError("validation_error", "Some fields need fixing.", fields=errors)


async def _plan_code(db: AsyncSession, code: str) -> Plan:
    p = await db.get(Plan, code)
    if not p:
        raise _fields(plan="unknown")
    return p


async def _owner_invite(
    db: AsyncSession, c: Company, m: Membership, *, phone: str, name: str, staff_id: uuid.UUID
) -> tuple[str, str]:
    """A join link for the owner (7 days). Older links for this owner stop working."""
    t = now()
    await db.execute(
        update(Invitation)
        .where(
            Invitation.membership_id == m.id,
            Invitation.accepted_at.is_(None),
            Invitation.revoked_at.is_(None),
        )
        .values(revoked_at=t)
    )
    token = random_token(24)
    db.add(
        Invitation(
            company_id=c.id, membership_id=m.id, phone=phone, name=name, role="owner",
            sms_language=c.report_language, token_hash=digest(token), expires_at=t + INVITE_TTL,
            invited_by=None, invited_by_staff=staff_id,
        )
    )  # fmt: skip
    await db.flush()
    link = f"{get_settings().web_url}/join/{token}"
    await send_sms(phone, "invite", inviter="KaamNishaan", company=c.name, link=link)
    return link, SMS_TEMPLATES["invite"].format(inviter="KaamNishaan", company=c.name, link=link)


async def create_company(
    db: AsyncSession, body: AdminCompanyCreate, *, staff_id: uuid.UUID, ip: str | None
) -> tuple[Company, str, str]:
    await check_trade(db, body.trade)
    plan = await _plan_code(db, body.plan)
    try:
        phone = normalize_phone(body.owner_phone, body.country)
    except AppError as e:
        raise _fields(owner_phone="invalid") from e
    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    if user and user.status == "disabled":
        raise _fields(owner_phone="disabled")
    email = str(body.owner_email).lower() if body.owner_email else None
    if email:
        other = (await db.execute(select(User).where(func.lower(User.email) == email))).scalar_one_or_none()
        if other and (not user or other.id != user.id):
            raise _fields(owner_email="taken")
    if not user:
        user = User(phone=phone, status="invited", email=email)
        db.add(user)
    elif email and not user.email:
        user.email = email
    t = now()
    trial_days = (await platform.trial(db)).days
    c = Company(
        name=body.name.strip(), industry_slug=body.trade, country=body.country,
        timezone=TIMEZONE_BY_COUNTRY.get(body.country, "UTC"),
        currency=CURRENCY_BY_COUNTRY.get(body.country, "USD"), report_language=body.report_language,
        plan_code=plan.code, status="trial", trial_ends_at=t + timedelta(days=trial_days),
        settings=CompanySettings().model_dump(), created_by=None,
    )  # fmt: skip
    db.add(c)
    await db.flush()
    m = Membership(company_id=c.id, user_id=user.id, role="owner", status="invited")
    db.add(m)
    await db.flush()
    link, sms = await _owner_invite(db, c, m, phone=phone, name=body.owner_name.strip(), staff_id=staff_id)
    await audit.record(
        db, "staff.company_created", staff_id=staff_id, company_id=c.id, target_type="company",
        target_id=c.id, data={"name": c.name, "plan": plan.code}, ip=ip,
    )  # fmt: skip
    return c, link, sms


async def resend_owner_invite(
    db: AsyncSession, company_id: uuid.UUID, *, staff_id: uuid.UUID, ip: str | None
) -> tuple[Company, str, str]:
    c = await _company(db, company_id)
    row = (
        await db.execute(
            select(Membership, User)
            .join(User, User.id == Membership.user_id)
            .where(Membership.company_id == c.id, Membership.role == "owner", Membership.status == "invited")
        )
    ).first()
    if not row or not row[1].phone:
        raise AppError("owner_joined", "The owner has already joined.", status=409)
    m, u = row
    name = await db.scalar(
        select(Invitation.name)
        .where(Invitation.membership_id == m.id)
        .order_by(Invitation.created_at.desc())
        .limit(1)
    )
    link, sms = await _owner_invite(db, c, m, phone=u.phone, name=name or u.name or "", staff_id=staff_id)
    await audit.record(
        db,
        "staff.owner_invited",
        staff_id=staff_id,
        company_id=c.id,
        target_type="company",
        target_id=c.id,
        ip=ip,
    )
    return c, link, sms


async def _company(db: AsyncSession, company_id: uuid.UUID) -> Company:
    c = await db.get(Company, company_id, with_for_update=True)
    if not c:
        raise NotFound("company_not_found", "This company doesn't exist.")
    return c


async def update_company(
    db: AsyncSession, company_id: uuid.UUID, body: AdminCompanyUpdate, *, staff_id: uuid.UUID, ip: str | None
) -> Company:
    c = await _company(db, company_id)
    before, after = {}, {}

    def change(field: str, value) -> None:
        if value is not None and value != getattr(c, field):
            before[field], after[field] = getattr(c, field), value
            setattr(c, field, value)

    if body.name is not None:
        change("name", body.name.strip())
    if body.trade is not None:
        await check_trade(db, body.trade)
        change("industry_slug", body.trade)
    if body.country is not None and body.country != c.country:
        change("country", body.country)
        change("currency", CURRENCY_BY_COUNTRY.get(body.country, "USD"))  # no payments yet (D-97)
    change("report_language", body.report_language)
    if body.plan is not None:
        change("plan_code", (await _plan_code(db, body.plan)).code)
    if body.trial_ends_at is not None:
        if c.status != "trial":
            raise _fields(trial_ends_at="not_in_trial")
        change("trial_ends_at", body.trial_ends_at)
    if after:
        await audit.record(
            db, "staff.company_updated", staff_id=staff_id, company_id=c.id, target_type="company",
            target_id=c.id, data={"before": _plain(before), "after": _plain(after)}, ip=ip,
        )  # fmt: skip
    await db.flush()
    return c


def _plain(d: dict) -> dict:
    return {k: (v.isoformat() if hasattr(v, "isoformat") else v) for k, v in d.items()}


async def suspend(
    db: AsyncSession, company_id: uuid.UUID, *, reason: str, staff_id: uuid.UUID, ip: str | None
) -> Company:
    """Nobody in the company can work until it is turned back on. Nothing is deleted; report links
    already sent to customers keep working."""
    c = await _company(db, company_id)
    if c.status == "suspended":
        raise AppError("already_suspended", "This company is already suspended.", status=409)
    c.suspended_from, c.status = c.status, "suspended"
    c.suspended_at, c.suspend_reason = now(), reason.strip()
    await audit.record(
        db, "staff.company_suspended", staff_id=staff_id, company_id=c.id, target_type="company",
        target_id=c.id, data={"reason": reason.strip(), "was": c.suspended_from}, ip=ip,
    )  # fmt: skip
    await db.flush()
    return c


async def reactivate(
    db: AsyncSession, company_id: uuid.UUID, *, reason: str, staff_id: uuid.UUID, ip: str | None
) -> Company:
    c = await _company(db, company_id)
    if c.status != "suspended":
        raise AppError("not_suspended", "This company is not suspended.", status=409)
    back = c.suspended_from or "active"
    if back == "trial" and c.trial_ends_at and c.trial_ends_at < now():
        back = "active"  # the trial ran out while paused; billing decides from here
    c.status, c.suspended_from, c.suspended_at, c.suspend_reason = back, None, None, None
    await audit.record(
        db, "staff.company_reactivated", staff_id=staff_id, company_id=c.id, target_type="company",
        target_id=c.id, data={"reason": reason.strip(), "now": back}, ip=ip,
    )  # fmt: skip
    await db.flush()
    return c
