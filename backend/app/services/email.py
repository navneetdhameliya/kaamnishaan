"""Is email on, and for which kind of message (A33 Email settings).

Email is on when staff have connected an email service in the admin panel and switched it on, or (local
and tests) when KN_EMAIL_ENABLED is set, which only logs. Each kind of email can be switched off on its own:
account (email confirmation, password reset), reports (report and rating links), reminders (Day 2), team
(notices to the office).
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.services import platform


async def email_on(db: AsyncSession, group: str | None = None) -> bool:
    cfg = await platform.email_config(db)
    if cfg.enabled and cfg.ready:
        return group is None or cfg.groups.get(group, True)
    return get_settings().email_enabled
