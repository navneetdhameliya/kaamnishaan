"""What a company's plan switches on (D-147).

Each plan's `features` (set in the plans table, shown on the pricing page) decides three things in the app:
the AI assistant, making your own checklists, the company's logo on the PDF, and managers approving
reports (D-148). A company on trial gets
them all, so it can try everything before choosing a plan."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import PlanLimit
from app.models import Company, Plan

GATED = ("ai_assistant", "custom_checklists", "branded_pdf", "manager_approvals")


def features(c: Company) -> list[str]:
    """The gated features this company has now."""
    if c.status == "trial":
        return list(GATED)
    plan = c.plan if c.plan is not None and c.plan.code == c.plan_code else None
    have = (plan.features if plan else None) or {}
    return [f for f in GATED if have.get(f) is True]


def has(c: Company, feature: str) -> bool:
    return feature in features(c)


async def require(db: AsyncSession, c: Company, feature: str) -> None:
    """402 plan_feature_needed, naming the first public plan that has it, for the app's Upgrade screen."""
    if has(c, feature):
        return
    plans = (await db.scalars(select(Plan).where(Plan.is_public.is_(True)).order_by(Plan.sort))).all()
    first = next((p.code for p in plans if (p.features or {}).get(feature) is True), None)
    raise PlanLimit(
        "plan_feature_needed",
        "Your plan doesn't include this. Upgrade to use it.",
        {"feature": feature, "plan": c.plan_code, "needs_plan": first},
    )
