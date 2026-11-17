"""Follow-up credits and the plan's monthly limits.

A company's month starts on the day it signed up (in its own time zone) and repeats every month. At
the start of each month it gets its plan's credits again; unused ones don't carry over. Bought top-ups
stay until used and are spent after the month's credits. SMS and WhatsApp reminders cost 1 credit, an
AI review call 10, email nothing. A plan without a credit number (Enterprise) has no limit.
"""

import uuid
from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import Forbidden
from app.core.security import now
from app.models import (
    Company,
    CreditEntry,
    CreditPack,
    CreditWallet,
    Membership,
    Plan,
    Report,
    ReviewRequest,
    ReviewRequestEvent,
)
from app.schemas.billing import BillingOut, CreditsOut, CreditUse, PlanStatus, UsageTile
from app.schemas.identity import CreditPackOut, CreditRules, Money, PlanOut

RULES = CreditRules()
COST = {"sms": RULES.sms, "whatsapp": RULES.whatsapp, "email": RULES.email, "ai_call": RULES.ai_call}


def _add_months(t: datetime, n: int) -> datetime:
    y, m = divmod(t.month - 1 + n, 12)
    year, month = t.year + y, m + 1
    for day in (t.day, 30, 29, 28):
        try:
            return t.replace(year=year, month=month, day=day)
        except ValueError:
            continue
    raise ValueError(t)


def cycle(company: Company, at: datetime | None = None) -> tuple[datetime, datetime]:
    """This month's start and end for the company."""
    zone = ZoneInfo(company.timezone or "UTC")
    anchor = company.created_at.astimezone(zone).replace(hour=0, minute=0, second=0, microsecond=0)
    t = (at or now()).astimezone(zone)
    months = (t.year - anchor.year) * 12 + t.month - anchor.month
    start = _add_months(anchor, months)
    if start > t:
        months -= 1
        start = _add_months(anchor, months)
    return start.astimezone(UTC), _add_months(anchor, months + 1).astimezone(UTC)


async def wallet(db: AsyncSession, company: Company, lock: bool = False) -> tuple[CreditWallet, Plan]:
    """The company's wallet, with this month's credits given when a new month has started."""
    plan = await db.get(Plan, company.plan_code)
    start, _ = cycle(company)
    w = await db.get(CreditWallet, company.id, with_for_update=lock)
    new = w is None
    if w is None:
        w = CreditWallet(
            company_id=company.id, period_start=start, plan_credits=0, plan_used=0, topup_credits=0
        )
        db.add(w)
    if new or w.period_start < start:
        w.period_start, w.plan_used = start, 0
        w.plan_credits = (plan.monthly_credits if plan else 0) or 0
        if w.plan_credits:
            db.add(CreditEntry(company_id=company.id, kind="grant", credits=w.plan_credits, at=start))
        await db.flush()
    return w, plan


def unlimited(plan: Plan | None) -> bool:
    return plan is not None and plan.monthly_credits is None


def balance(w: CreditWallet) -> int:
    return max(w.plan_credits - w.plan_used, 0) + w.topup_credits


async def can_spend(db: AsyncSession, company: Company, channel: str) -> bool:
    cost = COST.get(channel, 0)
    if cost == 0:
        return True
    w, plan = await wallet(db, company, lock=True)
    return unlimited(plan) or balance(w) >= cost


async def spend(
    db: AsyncSession, company: Company, channel: str, kind: str, request_id: uuid.UUID | None = None
) -> bool:
    """Take the credits for one message or call. False (and nothing taken) when there aren't enough."""
    cost = COST.get(channel, 0)
    if cost == 0:
        return True
    w, plan = await wallet(db, company, lock=True)
    if not unlimited(plan):
        if balance(w) < cost:
            return False
        from_plan = min(cost, max(w.plan_credits - w.plan_used, 0))
        w.plan_used += from_plan
        w.topup_credits -= cost - from_plan
    db.add(
        CreditEntry(
            company_id=company.id, kind=kind, channel=channel, credits=-cost, review_request_id=request_id
        )
    )
    return True


# ---- what the screens show ---------------------------------------------------------------------
def _t(names: dict, locale: str) -> str:
    return names.get(locale) or names.get("en") or next(iter(names.values()), "")


def plan_out(p: Plan, currency: str, locale: str) -> PlanOut:
    return PlanOut(
        code=p.code,
        name=_t(p.name, locale),
        price=Money(amount=p.prices[currency], currency=currency) if currency in (p.prices or {}) else None,
        technician_limit=p.technician_limit,
        report_limit_monthly=p.report_limit_monthly,
        ai_questions_monthly=p.ai_questions_monthly,
        monthly_credits=p.monthly_credits,
        most_popular=p.most_popular,
        features=sorted(k for k, v in (p.features or {}).items() if v),
    )


def _currency(company: Company) -> str:
    return company.currency if company.currency in ("INR", "USD") else "USD"


async def billing(db: AsyncSession, p: Principal) -> BillingOut:
    """M41 Plan and billing (owner only)."""
    from app.services.assistant import questions_used

    if p.role != "owner":
        raise Forbidden("owner_only", "Only the owner can see the plan and billing.")
    company = p.company
    w, plan = await wallet(db, company)
    start, _ = cycle(company)
    b = await _usage(db, company, p.user.app_language)
    return BillingOut(
        plan=b["plan"],
        status=company.status,
        trial_ends_at=company.trial_ends_at,
        period_start=start,
        renews_at=b["end"],
        company=company.name,
        usage=[
            b["technicians"],
            b["reports"],
            UsageTile(
                key="ai_questions",
                used=await questions_used(db, company.id, start),
                limit=plan.ai_questions_monthly,
            ),
            UsageTile(key="credits", used=w.plan_used, limit=None if unlimited(plan) else w.plan_credits),
        ],
        upgrade=b["upgrade"],
        payments_ready=False,
    )


async def _usage(db: AsyncSession, company: Company, lang: str) -> dict:
    plan = await db.get(Plan, company.plan_code)
    start, end = cycle(company)
    techs = await db.scalar(
        select(func.count()).where(
            Membership.company_id == company.id,
            Membership.role == "technician",
            Membership.status.in_(("active", "invited")),
        )
    )
    reports = await db.scalar(
        select(func.count()).where(Report.company_id == company.id, Report.created_at >= start)
    )
    nxt = (
        await db.execute(
            select(Plan).where(Plan.is_public.is_(True), Plan.sort > plan.sort).order_by(Plan.sort).limit(1)
        )
    ).scalar_one_or_none()
    cur = _currency(company)
    return {
        "plan": plan_out(plan, cur, lang),
        "upgrade": plan_out(nxt, cur, lang) if nxt and cur in (nxt.prices or {}) else None,
        "end": end,
        "technicians": UsageTile(key="technicians", used=techs or 0, limit=plan.technician_limit),
        "reports": UsageTile(key="reports", used=reports or 0, limit=plan.report_limit_monthly),
    }


async def credits(db: AsyncSession, p: Principal) -> CreditsOut:
    """M41 Follow-up credits (owners and managers)."""
    if "jobs.view_all" not in p.permissions:
        raise Forbidden("forbidden", "Only owners and managers can see this.")
    company = p.company
    w, plan = await wallet(db, company)
    start, end = cycle(company)
    spent = {
        kind: (-(total or 0), n)
        for kind, total, n in (
            await db.execute(
                select(CreditEntry.kind, func.sum(CreditEntry.credits), func.count())
                .where(
                    CreditEntry.company_id == company.id,
                    CreditEntry.credits < 0,
                    CreditEntry.at >= start,
                )
                .group_by(CreditEntry.kind)
            )
        ).all()
    }
    emails = await db.scalar(
        select(func.count())
        .select_from(ReviewRequestEvent)
        .join(ReviewRequest, ReviewRequest.id == ReviewRequestEvent.request_id)
        .where(
            ReviewRequest.company_id == company.id,
            ReviewRequestEvent.step == "reminder",
            ReviewRequestEvent.channel == "email",
            ReviewRequestEvent.status == "sent",
            ReviewRequestEvent.at >= start,
        )
    )
    cur = _currency(company)
    packs = (
        await db.execute(select(CreditPack).where(CreditPack.active.is_(True)).order_by(CreditPack.sort))
    ).scalars()
    no_limit = unlimited(plan)
    return CreditsOut(
        balance=None if no_limit else balance(w),
        plan_credits=None if no_limit else w.plan_credits,
        plan_used=w.plan_used,
        topup_credits=w.topup_credits,
        plan=_t(plan.name, p.user.app_language),
        renews_at=end,
        uses=[
            CreditUse(
                kind="reminders",
                credits=spent.get("reminder", (0, 0))[0],
                count=spent.get("reminder", (0, 0))[1],
            ),
            CreditUse(
                kind="ai_calls",
                credits=spent.get("ai_call", (0, 0))[0],
                count=spent.get("ai_call", (0, 0))[1],
            ),
            CreditUse(kind="emails", credits=0, count=emails or 0),
        ],
        packs=[
            CreditPackOut(id=c.id, credits=c.credits, price=Money(amount=c.prices[cur], currency=cur))
            for c in packs
            if cur in c.prices and (c.plan_code is None or c.plan_code == plan.code)
        ],
        rules=RULES,
        payments_ready=False,
    )


async def plan_status(db: AsyncSession, p: Principal) -> PlanStatus:
    """M41 Plan limit reached: anyone in the company may see it (technicians see it when a report can't
    be made); only the owner is offered the upgrade."""
    b = await _usage(db, p.company, p.user.app_language)
    return PlanStatus(
        plan=b["plan"],
        upgrade=b["upgrade"],
        renews_at=b["end"],
        reports=b["reports"],
        technicians=b["technicians"],
        can_upgrade=p.role == "owner",
    )
