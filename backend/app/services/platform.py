"""Platform-wide settings kept in the database (platform_settings). Each group has defaults in code."""

import uuid

from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import PlatformSetting


class ReviewRules(BaseModel):
    """A37 "Review rules": checks run on every new customer review."""

    hide_contact: bool = True  # hide phone numbers and emails in the comment
    flag_abuse: bool = True  # hold reviews with abusive words (5 languages) for KaamNishaan to check
    block_repeats: bool = True  # hold a second review from the same phone number within a day


async def review_rules(db: AsyncSession) -> ReviewRules:
    row = await db.get(PlatformSetting, "review_rules")
    return ReviewRules(**(row.value if row else {}))


async def set_review_rules(db: AsyncSession, rules: ReviewRules, *, staff_id: uuid.UUID) -> ReviewRules:
    row = await db.get(PlatformSetting, "review_rules")
    if not row:
        row = PlatformSetting(key="review_rules")
        db.add(row)
    row.value, row.updated_by = rules.model_dump(), staff_id
    await db.flush()
    return rules
