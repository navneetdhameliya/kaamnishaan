"""A03 admin dashboard: the platform at a glance, for the last 7, 30 or 90 days.

Every number is counted from the database; nothing is estimated except monthly revenue, which is the
plan price of each paying company (no payments are taken yet, D-97)."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import Date, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import AIUsage, AuditLog, Company, Industry, Lead, Membership, Plan, Report, StaffUser
from app.schemas.staff import (
    ActivityRow,
    AttentionRow,
    DashboardOut,
    DayCount,
    Money,
    PlanMixRow,
    Stat,
    TopCompany,
)
from app.services.checklists import pick
from app.services.credits import cycle

LIVE = ("trial", "active", "past_due")  # companies that can use the app
NEAR_LIMIT = 0.9  # "near report limit" from 90 % of the plan's monthly reports
TRIAL_SOON = timedelta(days=7)


async def _count(db: AsyncSession, q) -> int:
    return int(await db.scalar(q) or 0)


async def dashboard(db: AsyncSession, *, days: int, lang: str) -> DashboardOut:
    t = now()
    since = t - timedelta(days=days)
    before = since - timedelta(days=days)

    # ---- the five tiles -------------------------------------------------------------------------
    companies_now = await _count(db, select(func.count()).where(Company.status.in_(LIVE)))
    companies_new = await _count(
        db, select(func.count()).where(Company.status.in_(LIVE), Company.created_at >= since)
    )
    tech = (Membership.role == "technician") & (Membership.status == "active")
    techs_now = await _count(db, select(func.count()).select_from(Membership).where(tech))
    techs_new = await _count(
        db, select(func.count()).select_from(Membership).where(tech, Membership.created_at >= since)
    )

    async def sent(a: datetime, b: datetime) -> int:
        return await _count(db, select(func.count()).where(Report.shared_at >= a, Report.shared_at < b))

    async def ai_cost(a: datetime, b: datetime) -> float:
        return float(
            await db.scalar(select(func.sum(AIUsage.cost_usd)).where(AIUsage.at >= a, AIUsage.at < b)) or 0
        )

    sent_now, sent_before = await sent(since, t), await sent(before, since)
    cost_now, cost_before = await ai_cost(since, t), await ai_cost(before, since)
    drafted = await _count(db, select(func.count()).where(Report.created_at >= since))

    # monthly revenue: plan price of every paying company, per currency
    revenue: dict[str, int] = {}
    rows = await db.execute(
        select(Company.currency, Plan.prices)
        .join(Plan, Plan.code == Company.plan_code)
        .where(Company.status == "active")
    )
    for currency, prices in rows.all():
        amount = (prices or {}).get(currency)
        if amount:
            revenue[currency] = revenue.get(currency, 0) + int(amount)

    # ---- reports per day (approved vs AI drafts) --------------------------------------------------
    approved_day = cast(func.timezone("UTC", Report.approved_at), Date)
    created_day = cast(func.timezone("UTC", Report.created_at), Date)
    approved = dict(
        (await db.execute(
            select(approved_day, func.count()).where(Report.approved_at >= since).group_by(approved_day)
        )).all()
    )  # fmt: skip
    drafts = dict(
        (await db.execute(
            select(created_day, func.count())
            .where(Report.created_at >= since, Report.drafted_by == "ai")
            .group_by(created_day)
        )).all()
    )  # fmt: skip
    first = since.astimezone(UTC).date() + timedelta(days=1)
    per_day = [
        DayCount(day=d, approved=approved.get(d, 0), ai_drafts=drafts.get(d, 0))
        for d in (first + timedelta(days=i) for i in range(days))
    ]

    # ---- plan mix -------------------------------------------------------------------------------
    counts = dict(
        (await db.execute(
            select(Company.plan_code, func.count())
            .where(Company.status.in_(LIVE))
            .group_by(Company.plan_code)
        )).all()
    )  # fmt: skip
    plans = (await db.execute(select(Plan).order_by(Plan.sort))).scalars().all()
    mix = [
        PlanMixRow(
            code=p.code, name=pick(p.name, lang), prices=p.prices or {}, companies=counts.get(p.code, 0)
        )
        for p in plans
        if p.is_public or counts.get(p.code)
    ]
    plan_names = {p.code: pick(p.name, lang) for p in plans}

    # ---- top companies by reports in the period ---------------------------------------------------
    n = func.count(Report.id).label("n")
    top_rows = (
        await db.execute(
            select(Company, Industry, n)
            .join(Report, Report.company_id == Company.id)
            .outerjoin(Industry, Industry.slug == Company.industry_slug)
            .where(Report.created_at >= since)
            .group_by(Company.id, Industry.slug)
            .order_by(n.desc(), Company.name)
            .limit(5)
        )
    ).all()
    top = [
        TopCompany(
            id=c.id,
            name=c.name,
            trade=pick(i.name, lang) if i else None,
            plan=plan_names.get(c.plan_code, c.plan_code),
            reports=count,
        )
        for c, i, count in top_rows
    ]

    # ---- needs attention ------------------------------------------------------------------------
    attention: list[AttentionRow] = []
    limits = {p.code: p.report_limit_monthly for p in plans if p.report_limit_monthly}
    near: list[tuple[float, Company, int, int]] = []
    if limits:
        for c in (
            await db.execute(select(Company).where(Company.status.in_(LIVE), Company.plan_code.in_(limits)))
        ).scalars():
            start, _ = cycle(c, t)
            used = await _count(
                db, select(func.count()).where(Report.company_id == c.id, Report.created_at >= start)
            )
            limit = limits[c.plan_code]
            if used >= limit * NEAR_LIMIT:
                near.append((used / limit, c, used, limit))
    if near:
        near.sort(key=lambda x: (-x[0], x[1].name))
        _, c, used, limit = near[0]
        attention.append(
            AttentionRow(kind="near_limit", count=len(near), example=c.name, used=used, limit=limit)
        )
    past_due = (
        (await db.execute(select(Company.name).where(Company.status == "past_due").order_by(Company.name)))
        .scalars()
        .all()
    )
    if past_due:
        attention.append(AttentionRow(kind="past_due", count=len(past_due), example=past_due[0]))
    ending = (
        (
            await db.execute(
                select(Company.name)
                .where(
                    Company.status == "trial",
                    Company.trial_ends_at >= t,
                    Company.trial_ends_at < t + TRIAL_SOON,
                )
                .order_by(Company.trial_ends_at)
            )
        )
        .scalars()
        .all()
    )
    if ending:
        attention.append(AttentionRow(kind="trial_ending", count=len(ending), example=ending[0]))
    new_leads = (
        await db.execute(
            select(Lead.name, Lead.company)
            .where(Lead.status == "new", Lead.kind.in_(("demo", "contact")))
            .order_by(Lead.created_at.desc())
        )
    ).all()
    if new_leads:
        name, company = new_leads[0]
        attention.append(AttentionRow(kind="new_leads", count=len(new_leads), example=company or name))

    # ---- recent activity --------------------------------------------------------------------------
    events: list[ActivityRow] = []
    for name, at in (
        await db.execute(
            select(Company.name, Company.created_at).order_by(Company.created_at.desc()).limit(6)
        )
    ).all():
        events.append(ActivityRow(kind="company_created", title=name, at=at))
    for kind, name, company, number, at in (
        await db.execute(
            select(Lead.kind, Lead.name, Lead.company, Lead.number, Lead.created_at)
            .order_by(Lead.created_at.desc())
            .limit(6)
        )
    ).all():
        title = name if kind == "newsletter" else f"{company or name} · KN-{number}"
        if kind in ("demo", "contact", "newsletter"):
            events.append(ActivityRow(kind=f"lead_{kind}", title=title, at=at))
    # each person once, when they first set up (a later reset is not "joining" again)
    joined = func.min(AuditLog.created_at).label("at")
    for name, at in (
        await db.execute(
            select(StaffUser.name, joined)
            .join(StaffUser, StaffUser.id == AuditLog.staff_id)
            .where(AuditLog.action == "staff.setup_done")
            .group_by(StaffUser.id)
            .order_by(joined.desc())
            .limit(3)
        )
    ).all():
        events.append(ActivityRow(kind="staff_joined", title=name, at=at))
    events.sort(key=lambda e: e.at, reverse=True)

    return DashboardOut(
        days=days,
        since=since,
        active_companies=Stat(value=companies_now, previous=companies_now - companies_new),
        technicians=Stat(value=techs_now, previous=techs_now - techs_new),
        reports_sent=Stat(value=sent_now, previous=sent_before),
        ai_cost_usd=Stat(value=round(cost_now, 4), previous=round(cost_before, 4)),
        ai_cost_per_report_usd=round(cost_now / drafted, 4) if drafted else None,
        monthly_revenue=[Money(currency=k, amount_minor=v) for k, v in sorted(revenue.items())],
        reports_per_day=per_day,
        plan_mix=mix,
        top_companies=top,
        attention=attention,
        activity=events[:6],
    )
