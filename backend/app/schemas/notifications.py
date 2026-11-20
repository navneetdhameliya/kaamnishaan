import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.identity import ListMeta, _In
from app.schemas.work import PersonRef

NotificationKind = Literal[
    "job_assigned",
    "report_submitted",
    "changes_requested",
    "report_approved",
    "report_shared",
    "review_received",
    "low_rating",
    "support_reply",
    "announcement",
]


class NotificationOut(BaseModel):
    id: uuid.UUID
    kind: NotificationKind
    params: dict[str, str] = Field(
        description="Names for the sentence the app writes in its own language: "
        "customer, job, report, note, scheduled_at (ISO), technician"
    )
    actor: PersonRef | None = Field(default=None, description="Who did it (the manager, the technician)")
    job_id: uuid.UUID | None
    report_id: uuid.UUID | None
    cover_url: str | None = Field(default=None, description="The job's picture")
    read: bool
    created_at: datetime


class NotificationList(BaseModel):
    data: list[NotificationOut]
    meta: ListMeta = Field(description='counts: {"unread": n}')


class NotificationsRead(_In):
    ids: list[uuid.UUID] | None = Field(
        default=None, max_length=200, description="Leave out to mark all as read"
    )


class UnreadCount(BaseModel):
    unread: int
