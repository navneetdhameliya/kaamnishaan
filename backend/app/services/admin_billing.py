"""A16 Subscriptions, A17 Plans and pricing, A18 Payments.

No payments are taken yet (D-97): a subscription is a company's plan and status, monthly revenue is the plan
price of every active company, and the Payments page says online payments are not connected."""

import csv
import io
import uuid
from datetime import timedelta

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import Company, CreditPack, Plan
from app.schemas.admin_billing import (
    CURRENCIES,
    AdminPack,
    AdminPackIn,
    AdminPlan,
    AdminPlanIn,
    AdminPlansOut,
    AdminSubKpis,
    AdminSubList,
    AdminSubRow,
    AdminTrial,
)
from app.schemas.staff import AdminMoney
from app.services import audit, platform
from app.services.admin_companies import (
    _badge,
    _csv_safe,
    _days_left,
    _filtered,
    _owner,
    _reports_in_cycle,
    _techs,
)
from app.services.checklists import pick
from app.services.credits import cycle

LIVE = ("trial", "active", "past_due")
ORDER = case(
    {"past_due": 0, "trial": 1, "active": 2, "suspended": 3, "cancelled": 4}, value=Company.status, else_=5
)


# ---- A16 Subscriptions ------------------------------------------------------------------------------
async def _kpis(db: AsyncSession) -> AdminSubKpis:
    t = now()
    mrr: dict[str, int] = {}
    paying = on_free = 0
    for currency, prices in (
        await db.execute(
            select(Company.currency, Plan.prices)
            .join(Plan, Plan.code == Company.plan_code)
            .where(Company.status == "active")
        )
    ).all():
        amount = (prices or {}).get(currency)
        if amount:
            mrr[currency] = mrr.get(currency, 0) + int(amount)
            paying += 1
        elif amount == 0:
            on_free += 1
        else:
            paying += 1  # custom price (Enterprise)

    async def n(*where) -> int:
        return int(await db.scalar(select(func.count()).select_from(Company).where(*where)) or 0)

    return AdminSubKpis(
        mrr=[AdminMoney(currency=k, amount_minor=v) for k, v in sorted(mrr.items())],
        paying=paying,
        on_free=on_free,
        trials=await n(Company.status == "trial"),
        trials_ending_7d=await n(Company.status == "trial", Company.trial_ends_at < t + timedelta(days=7)),
        past_due=await n(Company.status == "past_due"),
        cancelled_30d=await n(Company.status == "cancelled", Company.updated_at >= t - timedelta(days=30)),
    )


async def _sub_rows(db: AsyncSession, stmt, lang: str) -> list[AdminSubRow]:
    plans = {p.code: p for p in (await db.execute(select(Plan))).scalars()}
    out = []
    for c, seats in (await db.execute(stmt)).all():
        p = plans.get(c.plan_code)
        used = await _reports_in_cycle(db, c) if c.status == "active" and p and p.report_limit_monthly else 0
        amount = (p.prices or {}).get(c.currency) if p else None
        renews = c.trial_ends_at if c.status == "trial" else cycle(c, now())[1] if c.status in LIVE else None
        out.append(
            AdminSubRow(
                id=c.id,
                name=c.name,
                plan_code=c.plan_code,
                plan=pick(p.name, lang) if p else c.plan_code,
                price=AdminMoney(currency=c.currency, amount_minor=int(amount))
                if amount is not None
                else None,
                status=c.status,
                badge=_badge(c, used, p),
                trial_days_left=_days_left(c),
                renews_at=renews,
                seats=seats,
                seat_limit=p.technician_limit if p else None,
            )
        )
    return out


def _subs_stmt(q: str | None, status: str | None, plan: str | None):
    stmt = _filtered(q, plan, None, None, _owner()).add_columns(_techs().label("seats"))
    if status:
        stmt = stmt.where(Company.status == status)
    return stmt


async def subscriptions(
    db: AsyncSession,
    *,
    lang: str,
    q: str | None,
    status: str | None,
    plan: str | None,
    page: int,
    page_size: int,
) -> AdminSubList:
    stmt = _subs_stmt(q, status, plan)
    total = int(await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0)
    rows = stmt.order_by(ORDER, Company.trial_ends_at, func.lower(Company.name), Company.id)
    rows = rows.offset((page - 1) * page_size).limit(page_size)
    return AdminSubList(
        kpis=await _kpis(db),
        items=await _sub_rows(db, rows, lang),
        total=total,
        page=page,
        page_size=page_size,
    )


async def subscriptions_csv(
    db: AsyncSession, *, lang: str, q: str | None, status: str | None, plan: str | None
):
    stmt = _subs_stmt(q, status, plan).order_by(ORDER, func.lower(Company.name), Company.id).limit(50_000)
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["Company", "Plan", "Price", "Currency", "Status", "Renews", "Seats", "Seat limit"])
    for r in await _sub_rows(db, stmt, lang):
        w.writerow(
            [
                _csv_safe(x)
                for x in (
                    r.name,
                    r.plan,
                    f"{r.price.amount_minor / 100:.2f}" if r.price else "custom",
                    r.price.currency if r.price else "",
                    r.badge,
                    r.renews_at.date().isoformat() if r.renews_at else "",
                    r.seats,
                    r.seat_limit if r.seat_limit is not None else "",
                )
            ]
        )
    return buf.getvalue()


# ---- A17 Plans and pricing ---------------------------------------------------------------------------
def _plan(p: Plan, counts: dict, trials: dict) -> AdminPlan:
    features = p.features or {}
    return AdminPlan(
        code=p.code,
        name=dict(p.name or {}),
        prices={k: int(v) for k, v in (p.prices or {}).items()},
        technician_limit=p.technician_limit,
        report_limit_monthly=p.report_limit_monthly,
        monthly_credits=p.monthly_credits,
        ai_questions_monthly=p.ai_questions_monthly,
        most_popular=p.most_popular,
        is_public=p.is_public,
        features=sorted(k for k, v in features.items() if v and not isinstance(v, str)),
        support=features.get("support") if isinstance(features.get("support"), str) else None,
        companies=counts.get(p.code, 0),
        trials=trials.get(p.code, 0),
    )


async def plans(db: AsyncSession, *, can_act: bool) -> AdminPlansOut:
    rows = (await db.execute(select(Plan).order_by(Plan.sort))).scalars().all()
    counts = dict(
        (
            await db.execute(
                select(Company.plan_code, func.count())
                .where(Company.status != "cancelled")
                .group_by(Company.plan_code)
            )
        ).all()
    )
    trials = dict(
        (
            await db.execute(
                select(Company.plan_code, func.count())
                .where(Company.status == "trial")
                .group_by(Company.plan_code)
            )
        ).all()
    )
    packs = (
        (await db.execute(select(CreditPack).order_by(CreditPack.sort, CreditPack.credits))).scalars().all()
    )
    tr = await platform.trial(db)
    return AdminPlansOut(
        plans=[_plan(p, counts, trials) for p in rows],
        packs=[
            AdminPack(id=k.id, credits=k.credits, prices=dict(k.prices or {}), active=k.active) for k in packs
        ],
        trial=AdminTrial(plan_code=tr.plan_code, days=tr.days),
        currencies=list(CURRENCIES),
        can_act=can_act,
        pricing_url=f"{get_settings().web_url}/pricing",
    )


def _diff(before: dict, after: dict) -> dict:
    return {k: {"from": before.get(k), "to": v} for k, v in after.items() if before.get(k) != v}


async def save_plan(
    db: AsyncSession, code: str, body: AdminPlanIn, *, staff_id: uuid.UUID, ip: str | None
) -> AdminPlansOut:
    p = await db.get(Plan, code, with_for_update=True)
    if not p:
        raise NotFound("not_found", "Plan not found.")
    tr = await platform.trial(db)
    if not body.is_public and code == tr.plan_code:
        raise AppError(
            "trial_plan",
            "New companies start on this plan's trial. Pick another trial plan first.",
            fields={"is_public": "trial_plan"},
            status=409,
        )
    if body.prices and (0 in body.prices.values()) and any(body.prices.values()):
        raise AppError(
            "free_mismatch", "A free plan is free in every currency.", fields={"prices": "mismatch"}
        )
    keys = (
        "name",
        "prices",
        "technician_limit",
        "report_limit_monthly",
        "monthly_credits",
        "ai_questions_monthly",
        "most_popular",
        "is_public",
    )
    before = {k: getattr(p, k) for k in keys}
    after = body.model_dump()
    for k in keys:
        setattr(p, k, after[k])
    if body.most_popular:  # only one plan is "Most popular"
        for other in (
            await db.execute(select(Plan).where(Plan.code != code, Plan.most_popular.is_(True)))
        ).scalars():
            other.most_popular = False
    changes = _diff(before, after)
    if changes:
        await audit.record(
            db, "plan.updated", staff_id=staff_id, target_type="plan", data={"plan": code, **changes}, ip=ip
        )
    await db.flush()
    return await plans(db, can_act=True)


async def save_pack(
    db: AsyncSession, pack_id: uuid.UUID, body: AdminPackIn, *, staff_id: uuid.UUID, ip: str | None
) -> AdminPlansOut:
    k = await db.get(CreditPack, pack_id, with_for_update=True)
    if not k:
        raise NotFound("not_found", "Credit pack not found.")
    changes = _diff({"prices": k.prices, "active": k.active}, body.model_dump())
    k.prices, k.active = body.prices, body.active
    if changes:
        await audit.record(
            db,
            "credit_pack.updated",
            staff_id=staff_id,
            target_type="credit_pack",
            target_id=k.id,
            data={"credits": k.credits, **changes},
            ip=ip,
        )
    await db.flush()
    return await plans(db, can_act=True)


async def save_trial(
    db: AsyncSession, body: AdminTrial, *, staff_id: uuid.UUID, ip: str | None
) -> AdminPlansOut:
    p = await db.get(Plan, body.plan_code)
    if not p or not p.is_public or not p.prices or not any(p.prices.values()):
        raise AppError(
            "bad_trial_plan",
            "The trial must be a paid plan shown on the website.",
            fields={"plan_code": "invalid"},
        )
    before = await platform.trial(db)
    changes = _diff(before.model_dump(), body.model_dump())
    await platform.set_trial(db, platform.TrialConfig(**body.model_dump()), staff_id=staff_id)
    if changes:
        await audit.record(
            db, "trial.updated", staff_id=staff_id, target_type="platform", data=changes, ip=ip
        )
    return await plans(db, can_act=True)
