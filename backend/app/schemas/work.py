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
    avatar_url: str | None = None


class ProofCount(BaseModel):
    """M12 "Proof 2 of 5 steps": before, during, after photos, checklists (if any), voice note."""

    done: int
    total: int


class ContactRef(BaseModel):
    name: str
    phone: str | None


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
    site: "SiteBrief | None" = Field(default=None, description="First address, for a new job")
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
    address: str | None = Field(default=None, max_length=200, description="Typed address; a new site if new")
    contact_id: uuid.UUID | None = None
    equipment_id: uuid.UUID | None = None
    scheduled_at: datetime | None = None
    duration_min: int | None = Field(default=None, ge=5, le=24 * 60)
    assigned_to: uuid.UUID | None = None
    checklist_template_ids: list[uuid.UUID] = Field(default_factory=list, max_length=10)
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


class AskManagerBody(_In):
    """A technician isn't sure how to answer ("Not sure? Ask your manager", M24)."""

    question: str = Field(
        min_length=1, max_length=300, description="The checklist question, as shown to them"
    )
    note: str | None = Field(default=None, max_length=500, description="What they want to ask, if anything")


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
    cover_url: str | None = Field(
        default=None, description="Latest photo of this job, else of the same site from an earlier visit"
    )
    proof: ProofCount | None = Field(default=None, description="Only on Today's current job")


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
    review: "JobReview | None" = Field(
        default=None, description="Customer review card (M15); none before a report"
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
    avatar_url: str | None = None


class AssignableList(BaseModel):
    data: list[AssignableTechnician]
    meta: ListMeta


# ---- home screens ------------------------------------------------------------------------------
class DayCount(BaseModel):
    date: date
    completed: int
    reports_sent: int


class TeamNow(BaseModel):
    id: uuid.UUID = Field(description="User id, or the invite id when status is invited")
    name: str
    role: str
    status: Literal["on_job", "idle", "invited"]
    current_job: str | None = None
    avatar_url: str | None = None


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
    reports_week: int = Field(description="Reports sent in the last 7 days (today included)")
    reports_last_week: int = Field(description="Reports sent in the 7 days before that")
    team_now: list[TeamNow]
    onboarding: Onboarding
    unread: int = Field(default=0, description="Messages not read yet (the bell's dot)")


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
    next_jobs: list[JobListItem] = Field(
        description="Today's other jobs: coming ones by time, then done ones"
    )
    unread: int
    manager: ContactRef | None = Field(default=None, description='Empty Today: "Call Priya, your manager"')


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


CustomerListItem.model_rebuild()


from app.schemas.reviews import JobReview  # noqa: E402 - reviews uses PersonRef from here

JobOut.model_rebuild()
