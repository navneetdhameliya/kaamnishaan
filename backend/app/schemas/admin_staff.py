"""Admin panel: A10 Roles and permissions (the role table, and KaamNishaan staff accounts)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

StaffRole = Literal["super_admin", "admin", "support"]
Cell = Literal["yes", "no", "partial"]


class AdminRoleCell(BaseModel):
    value: Cell
    note: str | None = Field(
        description="For partial: technicians, quick_job, if_allowed, secure_link, own_company"
    )


class AdminRoleRow(BaseModel):
    key: str
    cells: dict[str, AdminRoleCell] = Field(description="super_admin, owner, manager, technician, customer")


class AdminStaffRow(BaseModel):
    id: uuid.UUID
    name: str
    email: str
    role: StaffRole
    status: Literal["invited", "active", "disabled"]
    last_login_at: datetime | None
    created_at: datetime
    me: bool


class AdminRolesOut(BaseModel):
    matrix: list[AdminRoleRow]
    staff_matrix: list[AdminRoleRow] = Field(description="What each admin panel role can do")
    staff: list[AdminStaffRow]
    can_act: bool


class AdminStaffInvite(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    role: StaffRole


class AdminStaffUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: StaffRole | None = None
    active: bool | None = None


class AdminStaffLink(BaseModel):
    staff: AdminStaffRow
    setup_link: str = Field(description="Shown once; works for 72 hours")
