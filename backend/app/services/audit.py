import uuid
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import AuditLog


async def record(
    db: AsyncSession,
    action: str,
    *,
    company_id: uuid.UUID | None = None,
    actor_id: uuid.UUID | None = None,
    actor_role: str | None = None,
    target_type: str | None = None,
    target_id: object = None,
    data: dict | None = None,
    ip: str | None = None,
) -> None:
    db.add(
        AuditLog(
            company_id=company_id,
            actor_id=actor_id,
            actor_role=actor_role,
            action=action,
            target_type=target_type,
            target_id=str(target_id) if target_id is not None else None,
            data=data or {},
            ip=ip,
        )
    )


async def count_recent(db: AsyncSession, action: str, target_id: object, within: timedelta) -> int:
    """Used as a simple, restart-safe rate limit for emails."""
    q = select(func.count()).where(
        AuditLog.action == action,
        AuditLog.target_id == str(target_id),
        AuditLog.created_at > now() - within,
    )
    return (await db.execute(q)).scalar_one()
