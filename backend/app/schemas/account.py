"""Deleting your account (Me → Delete account) and handing a company to a new owner first."""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import Role


class OwnerCandidate(BaseModel):
    user_id: uuid.UUID
    name: str
    role: Role


class DeletionCompany(BaseModel):
    company_id: uuid.UUID
    name: str
    role: Role
    others: int = Field(description="Other active people in the company")
    closes: bool = Field(description="True when the company closes too (you are its only member)")
    needs_new_owner: bool = Field(description="You own it and others work there: pick a new owner first")
    candidates: list[OwnerCandidate] = Field(default_factory=list)


class DeletionCheck(BaseModel):
    can_delete: bool
    companies: list[DeletionCompany]
    open_jobs: int = Field(
        0, description="Jobs given to you that are not finished; they go back to the office"
    )


class AccountDelete(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    confirm: Literal[True]
    reason: str | None = Field(None, max_length=300, description="Optional: why they are leaving")


class OwnerChange(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID = Field(description="An active member of this company; you become a manager")
