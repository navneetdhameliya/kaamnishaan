"""A04 Companies list and A05 Company details for KaamNishaan staff. Read only (edit and suspend come
with A06/A07). Every figure is counted from the database."""

import csv
import io
import math
import statistics
import uuid
from collections.abc import Iterable
from datetime import timedelta

from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound
from app.core.security import now
from app.models import AIUsage, Company, Industry, Job, Membership, Plan, Report, User
from app.schemas.admin_companies import (
    AdminCompanyCounts,
    AdminCompanyDetail,
    AdminCompanyList,
    AdminCompanyRow,
    AdminOption,
    AdminPlanInfo,
    AdminTeamMember,
)
from app.services.checklists import pick
from app.services.credits import cycle

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
    members.sort(key=lambda mu: (ROLE_ORDER.get(mu[0].role, 9), (mu[1].name or "").lower()))
    owner = next((u for m, u in members if m.role == "owner"), None)
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
        status=c.status,
        badge=_badge(c, reports, plan),
        trial_ends_at=c.trial_ends_at,
        created_at=c.created_at,
        country=c.country,
        currency=c.currency,
        timezone=c.timezone,
        report_language=c.report_language,
        industry=pick(industry.name, lang) if industry else None,
        plan=_plan_info(plan, lang),
        owner_name=owner.name if owner else None,
        owner_email=owner.email if owner else None,
        owner_phone=owner.phone if owner else None,
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
                name=u.name,
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
