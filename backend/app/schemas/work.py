"""Customers, sites, contacts, equipment, jobs, dashboard, Today and sync.

API document section: Customers and jobs.
"""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.schemas.identity import ListMeta

JobStatus = Literal[
    "unassigned", "assigned", "in_progress", "in_review", "changes_requested", "completed", "cancelled"
]


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class PersonRef(BaseModel):
    id: uuid.UUID
    name: str


# ---- customers ---------------------------------------------------------------------------
class ContactIn(_In):
    name: str = Field(min_length=1, max_length=160)
    title: str | None = Field(default=None, max_length=80)
    phone: str | None = None
    email: EmailStr | None = None
    is_primary: bool = False


class ContactPatch(_In):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    title: str | None = Field(default=None, max_length=80)
    phone: str | None = None
    email: EmailStr | None = None
    is_primary: bool | None = None


class ContactOut(BaseModel):
    id: uuid.UUID
    name: str
    title: str | None
    phone: str | None
    email: str | None
    is_primary: bool
    review_opted_out: bool


class EquipmentIn(_In):
    type: str = Field(min_length=1, max_length=80)
    brand: str | None = Field(default=None, max_length=80)
    model: str | None = Field(default=None, max_length=80)
    capacity: str | None = Field(default=None, max_length=40)
    location: str | None = Field(default=None, max_length=80)
    last_service_at: datetime | None = None


class EquipmentPatch(_In):
    type: str | None = Field(default=None, min_length=1, max_length=80)
    brand: str | None = Field(default=None, max_length=80)
    model: str | None = Field(default=None, max_length=80)
    capacity: str | None = Field(default=None, max_length=40)
    location: str | None = Field(default=None, max_length=80)
    last_service_at: datetime | None = None


class EquipmentOut(BaseModel):
    id: uuid.UUID
    type: str
    brand: str | None
    model: str | None
    capacity: str | None
    location: str | None
    last_service_at: datetime | None


class SiteIn(_In):
    label: str | None = Field(default=None, max_length=80)
    address_line1: str = Field(min_length=1, max_length=200)
    address_line2: str | None = Field(default=None, max_length=200)
    city: str | None = Field(default=None, max_length=80)
    state: str | None = Field(default=None, max_length=80)
    postcode: str | None = Field(default=None, max_length=16)
    country: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class SitePatch(_In):
    label: str | None = Field(default=None, max_length=80)
    address_line1: str | None = Field(default=None, min_length=1, max_length=200)
    address_line2: str | None = Field(default=None, max_length=200)
    city: str | None = Field(default=None, max_length=80)
    state: str | None = Field(default=None, max_length=80)
    postcode: str | None = Field(default=None, max_length=16)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class SiteOut(BaseModel):
    id: uuid.UUID
    label: str | None
    address_line1: str
    address_line2: str | None
    city: str | None
    state: str | None
    postcode: str | None
    country: str
    lat: float | None
    lng: float | None
    equipment: list[EquipmentOut] = []


class CustomerCreate(_In):
    name: str = Field(min_length=1, max_length=160)
    notes: str | None = Field(default=None, max_length=2000)
    site: SiteIn | None = None
    contact: ContactIn | None = None
    client_uuid: uuid.UUID | None = Field(
        default=None, description="Made on the device; a repeat returns the first result"
    )


class CustomerPatch(_In):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    notes: str | None = Field(default=None, max_length=2000)


class ContactBrief(BaseModel):
    name: str
    phone: str | None


class CustomerListItem(BaseModel):
    id: uuid.UUID
    name: str
    primary_contact: ContactBrief | None
    city: str | None
    job_count: int
    last_job_at: datetime | None


class CustomerList(BaseModel):
    data: list[CustomerListItem]
    meta: ListMeta


class CustomerOut(BaseModel):
    id: uuid.UUID
    name: str
    notes: str | None
    customer_since: datetime
    job_count: int
    contacts: list[ContactOut]
    sites: list[SiteOut]
    version: int
    updated_at: datetime


# ---- jobs ------------------------------------------------------------------------------------
class QuickCustomer(_In):
    """A technician's quick job can name a new customer on the spot."""

    name: str = Field(min_length=1, max_length=160)
    phone: str | None = None
    address: str | None = Field(default=None, max_length=200)


class JobCreate(_In):
    title: str = Field(min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=4000)
    customer_id: uuid.UUID | None = None
    customer: QuickCustomer | None = None
    site_id: uuid.UUID | None = None
    contact_id: uuid.UUID | None = None
    equipment_id: uuid.UUID | None = None
    scheduled_at: datetime | None = None
    duration_min: int | None = Field(default=None, ge=5, le=24 * 60)
    assigned_to: uuid.UUID | None = None
    client_uuid: uuid.UUID | None = None


class JobPatch(_In):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=4000)
    site_id: uuid.UUID | None = None
    contact_id: uuid.UUID | None = None
    equipment_id: uuid.UUID | None = None
    scheduled_at: datetime | None = None
    duration_min: int | None = Field(default=None, ge=5, le=24 * 60)


class AssignBody(_In):
    technician_id: uuid.UUID | None = Field(description="null takes the job back to Unassigned")


class StartBody(_In):
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class CancelBody(_In):
    reason: str = Field(min_length=1, max_length=300)


class CustomerRef(BaseModel):
    id: uuid.UUID
    name: str


class SiteBrief(BaseModel):
    id: uuid.UUID
    label: str | None
    address: str
    city: str | None
    lat: float | None
    lng: float | None


class JobListItem(BaseModel):
    id: uuid.UUID
    number: str = Field(examples=["J-2231"])
    title: str
    status: JobStatus
    scheduled_at: datetime | None
    duration_min: int | None
    customer: CustomerRef
    site: SiteBrief | None
    assignee: PersonRef | None
    is_quick_job: bool
    version: int
    updated_at: datetime


class JobList(BaseModel):
    data: list[JobListItem]
    meta: ListMeta


class JobOut(JobListItem):
    description: str | None
    contact: ContactOut | None
    equipment: EquipmentOut | None
    started_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    cancel_reason: str | None
    created_by: PersonRef | None
    created_at: datetime
    actions: list[str] = Field(
        description="What the signed-in person may do now: edit, assign, start, cancel, delete"
    )


class TimelineEvent(BaseModel):
    id: uuid.UUID
    type: str
    from_status: str | None
    to_status: str | None
    actor: PersonRef | None
    at: datetime
    data: dict


class Timeline(BaseModel):
    data: list[TimelineEvent]
    meta: ListMeta


class AssignableTechnician(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    status: Literal["active", "invited"]
    jobs_today: int
    capacity: int
    available: bool
    distance_km: float | None = None
    disabled_reason: Literal["invite_pending"] | None = None


class AssignableList(BaseModel):
    data: list[AssignableTechnician]
    meta: ListMeta


# ---- home screens ------------------------------------------------------------------------------
class DayCount(BaseModel):
    date: date
    completed: int
    reports_sent: int


class TeamNow(BaseModel):
    id: uuid.UUID
    name: str
    role: str
    status: Literal["on_job", "idle"]
    current_job: str | None = None


class Onboarding(BaseModel):
    company_created: bool = True
    team_invited: bool
    first_job_created: bool
    first_report_sent: bool


class Dashboard(BaseModel):
    date: date
    today: dict[str, int]
    to_review: int
    week: list[DayCount]
    team_now: list[TeamNow]
    onboarding: Onboarding


class TodayStats(BaseModel):
    jobs: int
    done: int
    photos: int


class Today(BaseModel):
    date: date
    name: str
    company: str | None
    stats: TodayStats
    current_job: JobListItem | None
    next_jobs: list[JobListItem]
    unread: int


class MeStats(BaseModel):
    jobs_done: int
    photos: int
    reports_sent: int
    team: int | None
    customers: int | None
    to_review: int | None


class SyncChanges(BaseModel):
    jobs: list[JobOut]
    removed_job_ids: list[uuid.UUID]
    cursor: str
    has_more: bool
