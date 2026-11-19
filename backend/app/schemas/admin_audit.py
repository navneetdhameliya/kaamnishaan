"""Admin panel A31 Audit logs."""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from app.schemas.admin_companies import AdminOption

AuditGroup = Literal["security", "admin", "company", "team", "jobs", "reports", "other"]


class AdminAuditActor(BaseModel):
    kind: Literal["staff", "user", "system", "unknown"] = Field(
        description="unknown: a failed staff log in with an email that has no account"
    )
    id: uuid.UUID | None
    name: str | None
    role: str | None = Field(
        description="Staff role, or the app role at the time (owner, manager, technician)"
    )


class AdminAuditRow(BaseModel):
    id: uuid.UUID
    at: datetime
    actor: AdminAuditActor
    action: str
    group: AuditGroup
    target_type: str | None
    target_id: str | None
    target: str | None = Field(description="Readable: a name, KN-20004, J-2231, R-1042 …")
    change: str | None = Field(description="e.g. new → contacted, when the entry has one")
    company_id: uuid.UUID | None
    company: str | None
    ip: str | None
    data: dict[str, Any]


class AdminAuditList(BaseModel):
    items: list[AdminAuditRow]
    total: int
    page: int
    page_size: int
    company: AdminOption | None


__all__ = ["AdminAuditActor", "AdminAuditList", "AdminAuditRow", "AuditGroup"]
