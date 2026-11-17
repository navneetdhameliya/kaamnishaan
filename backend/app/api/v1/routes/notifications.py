from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal
from app.schemas.notifications import NotificationList, NotificationsRead, UnreadCount
from app.services import notifications as svc

router = APIRouter(tags=["notifications"])


@router.get("/notifications", response_model=NotificationList)
async def list_notifications(
    cursor: str | None = None,
    limit: int = Query(30, ge=1, le=100),
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> NotificationList:
    """M42 Messages, newest first; meta.counts.unread for the red dot."""
    return await svc.list_notifications(db, p, cursor, limit)


@router.post("/notifications/read", response_model=UnreadCount)
async def read_notifications(
    body: NotificationsRead, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> UnreadCount:
    """Marks the given messages (or all) as read."""
    return UnreadCount(unread=await svc.mark_read(db, p, body.ids))
