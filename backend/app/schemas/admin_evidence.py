"""Admin panel: A13 Evidence review. Every company's photos, with checks the server can run on its own."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.admin_companies import AdminOption

PhotoCheck = Literal["duplicate", "no_gps", "far", "early"]
PhotoFilter = Literal["needs_look", "staff", "duplicate", "no_gps", "far", "early", "clean"]


class AdminStaffFlag(BaseModel):
    note: str
    by: str | None
    at: datetime


class AdminPhotoJob(BaseModel):
    id: uuid.UUID
    number: str
    title: str
    customer: str


class AdminPhoto(BaseModel):
    id: uuid.UUID
    thumb_url: str | None = Field(description="Small copy; None while it is still being processed")
    stage: Literal["before", "during", "after"]
    job: AdminPhotoJob
    company: AdminOption
    taken_at: datetime
    gps: bool
    locked: bool
    checks: list[PhotoCheck] = Field(
        description="duplicate: the same file is on another photo; no_gps; far: over 500 m from the site; "
        "early: taken before the job existed"
    )
    staff_flag: AdminStaffFlag | None


class AdminPhotoList(BaseModel):
    items: list[AdminPhoto]
    total: int
    page: int
    page_size: int
    needs_look: int = Field(description="Photos with a check or a staff flag, across all companies")
    companies: list[AdminOption]
    can_act: bool


class AdminPhotoTwin(BaseModel):
    id: uuid.UUID
    job: AdminPhotoJob
    company: AdminOption
    taken_at: datetime


class AdminPhotoDetail(AdminPhoto):
    image_url: str = Field(description="Full-size copy (short-lived link)")
    taken_by: str | None
    distance_m: int | None = Field(description="From the site, when both places are known")
    width: int | None
    height: int | None
    size: int
    fingerprint: str | None = Field(description="SHA-256 of the original file")
    job_created_at: datetime
    twins: list[AdminPhotoTwin] = Field(description="Other photos with the same file")


class AdminPhotoFlagIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    note: str = Field(min_length=3, max_length=300)
