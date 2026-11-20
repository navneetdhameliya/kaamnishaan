"""A40 Usage and credits: how companies use follow-up credits, the credit rules and plan credits, and
adjusting one company's credits.

Payments aren't taken yet (D-97), so there is no top-up revenue or provider bill to show; the page shows
the credits and the messages and calls they paid for instead.
"""

import csv
import io
import uuid
from collections.abc import Iterable
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import Company, CreditEntry, CreditPack, CreditWallet, Plan, ReviewRequest
from app.schemas.admin_credits import (
    AdminCreditKpis,
    AdminCreditPack,
    AdminCreditRow,
    AdminCreditRules,
    AdminCreditRulesIn,
    AdminCreditsOut,
    AdminPlanCredits,
)
from app.schemas.identity import Money
from app.services import audit, credits, platform
from app.services.admin_companies import _csv_safe
from app.services.admin_dashboard import LIVE
from app.services.checklists import pick

LOW = 0.8  # "x% used" from 80 %
ORDER = {"out": 0, "low": 1, "ok": 2, "unlimited": 3}


def _row(c: Company, plan: Plan | None, w: CreditWallet | None, topups: int, lang: str) -> AdminCreditRow:
    """The company's credits now. A wallet from an earlier month counts as reset (it is, on next use)."""
    start, _ = credits.cycle(c)
    monthly = plan.monthly_credits if plan else 0
    fresh = w is None or w.period_start < start
    included = (monthly or 0) if fresh else w.plan_credits
    used = 0 if fresh else w.plan_used
    left = w.topup_credits if w else 0
    if plan is not None and monthly is None:
        status = "unlimited"
    elif max(included - used, 0) + left <= 0:
        status = "out"
    elif included and used / included >= LOW and left == 0:
        status = "low"
    else:
        status = "ok"
    return AdminCreditRow(
        company_id=c.id, company=c.name, plan=pick(plan.name, lang) if plan else c.plan_code,
        included=None if status == "unlimited" else included, used=used, topup_left=left, topups=topups,
        status=status,
    )  # fmt: skip


async def _rows(db: AsyncSession, q: str | None, lang: str) -> list[AdminCreditRow]:
    stmt = (
        select(Company, Plan, CreditWallet)
        .outerjoin(Plan, Plan.code == Company.plan_code)
        .outerjoin(CreditWallet, CreditWallet.company_id == Company.id)
        .where(Company.status.in_((*LIVE, "suspended")))
    )
    if q:
        stmt = stmt.where(Company.name.ilike(f"%{q.strip()}%"))
    found = (await db.execute(stmt)).all()
    topups = dict(
        (await db.execute(
            select(CreditEntry.company_id, func.count())
            .where(CreditEntry.kind.in_(("topup", "adjust")), CreditEntry.credits > 0)
            .group_by(CreditEntry.company_id)
        )).all()
    )  # fmt: skip
    rows = [_row(c, p, w, topups.get(c.id, 0), lang) for c, p, w in found]
    pct = lambda r: (r.used / r.included) if r.included else 0  # noqa: E731
    rows.sort(key=lambda r: (ORDER[r.status], -pct(r), r.company.lower()))
    return rows


async def overview(
    db: AsyncSession, *, q: str | None, page: int, page_size: int, lang: str, can_act: bool
) -> AdminCreditsOut:
    since = now() - timedelta(days=30)
    recent = CreditEntry.at >= since
    used, included, added, topups, sms, wa, calls = (
        await db.execute(
            select(
                func.coalesce(-func.sum(CreditEntry.credits).filter(CreditEntry.credits < 0), 0),
                func.coalesce(func.sum(CreditEntry.credits).filter(CreditEntry.kind == "grant"), 0),
                func.coalesce(
                    func.sum(CreditEntry.credits).filter(
                        CreditEntry.kind.in_(("topup", "adjust")), CreditEntry.credits > 0
                    ), 0,
                ),
                func.count().filter(CreditEntry.kind == "topup", CreditEntry.credits > 0),
                func.count().filter(CreditEntry.channel == "sms", CreditEntry.credits < 0),
                func.count().filter(CreditEntry.channel == "whatsapp", CreditEntry.credits < 0),
                func.count().filter(CreditEntry.channel == "ai_call", CreditEntry.credits < 0),
            ).where(recent)
        )
    ).one()  # fmt: skip
    rows = await _rows(db, q, lang)
    paused = int(
        await db.scalar(select(func.count()).where(ReviewRequest.status == "paused_no_credits")) or 0
    )
    plans = (await db.execute(select(Plan).order_by(Plan.sort))).scalars().all()
    per_plan = select(Company.plan_code, func.count()).where(Company.status.in_(LIVE))
    on_plan = dict((await db.execute(per_plan.group_by(Company.plan_code))).all())
    packs = (
        await db.execute(select(CreditPack).where(CreditPack.active.is_(True)).order_by(CreditPack.sort))
    ).scalars()
    c = await platform.credit_costs(db)
    start = (page - 1) * page_size
    return AdminCreditsOut(
        kpis=AdminCreditKpis(
            used_30d=int(used), included_30d=int(included), topup_credits_30d=int(added), topups_30d=topups,
            sms_30d=sms, whatsapp_30d=wa, calls_30d=calls,
            out_of_credits=sum(1 for r in rows if r.status == "out"), paused_requests=paused,
        ),
        rules=AdminCreditRules(sms=c.sms, whatsapp=c.whatsapp, ai_call=c.ai_call),
        plans=[
            AdminPlanCredits(code=p.code, name=pick(p.name, lang), monthly_credits=p.monthly_credits,
                             companies=on_plan.get(p.code, 0))
            for p in plans
        ],
        packs=[
            AdminCreditPack(
                credits=k.credits, prices=[Money(amount=v, currency=x) for x, v in k.prices.items()]
            )
            for k in packs
        ],
        items=rows[start : start + page_size], total=len(rows), page=page, page_size=page_size,
        can_act=can_act,
    )  # fmt: skip


async def save_rules(
    db: AsyncSession, body: AdminCreditRulesIn, *, staff_id: uuid.UUID, ip: str | None
) -> None:
    before = await platform.credit_costs(db)
    after = platform.CreditCosts(sms=body.sms, whatsapp=body.whatsapp, ai_call=body.ai_call)
    changed: dict = {k: v for k, v in after.model_dump().items() if getattr(before, k) != v}
    await platform.set_credit_costs(db, after, staff_id=staff_id)
    plans = {p.code: p for p in (await db.execute(select(Plan))).scalars()}
    bad = {f"plans.{code}": "unknown" for code in body.plans if code not in plans}
    for code, n in body.plans.items():
        if n is not None and not 0 <= n <= 1_000_000:
            bad[f"plans.{code}"] = "out_of_range"
    if bad:
        raise AppError("validation_error", "Some fields are not valid.", fields=bad, status=422)
    for code, n in body.plans.items():
        if plans[code].monthly_credits != n:
            changed[f"plan.{code}"] = n
            plans[code].monthly_credits = n  # each company gets it from its next month
    if changed:
        await audit.record(db, "staff.credit_rules_updated", staff_id=staff_id, target_type="platform",
                           data=changed, ip=ip)  # fmt: skip
    await db.flush()


async def adjust(
    db: AsyncSession, company_id: uuid.UUID, n: int, reason: str, *, staff_id: uuid.UUID, ip: str | None
) -> None:
    """Add (or take back) top-up credits for one company, e.g. a goodwill gift or a mistake."""
    if n == 0:
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"credits": "zero"}, status=422
        )
    company = await db.get(Company, company_id)
    if not company:
        raise NotFound("not_found", "Company not found.")
    w, _ = await credits.wallet(db, company, lock=True)
    if w.topup_credits + n < 0:
        raise AppError("not_enough", "The company has fewer extra credits than that.", status=409,
                       details={"topup_left": w.topup_credits})  # fmt: skip
    w.topup_credits += n
    db.add(CreditEntry(company_id=company.id, kind="adjust", credits=n))
    await audit.record(db, "staff.credits_adjusted", staff_id=staff_id, company_id=company.id,
                       target_type="company", target_id=company.id, data={"credits": n, "reason": reason},
                       ip=ip)  # fmt: skip
    await db.flush()


CSV_HEADER = (
    "Company",
    "Plan",
    "Included this month",
    "Used this month",
    "Extra credits left",
    "Top-ups",
    "Status",
)


async def credits_csv(db: AsyncSession, *, q: str | None, lang: str) -> Iterable[str]:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(CSV_HEADER)
    for r in await _rows(db, q, lang):
        w.writerow([_csv_safe(x) for x in (
            r.company, r.plan, "no limit" if r.included is None else r.included, r.used, r.topup_left,
            r.topups, r.status,
        )])  # fmt: skip
    return [buf.getvalue()]
