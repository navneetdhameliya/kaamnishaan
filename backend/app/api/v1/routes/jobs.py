import uuid
from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, Header, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal
from app.core.errors import Forbidden
from app.schemas.work import (
    AssignableList,
    AssignBody,
    CancelBody,
    JobCreate,
    JobList,
    JobOut,
    JobPatch,
    StartBody,
    Timeline,
)
from app.services import jobs as svc

router = APIRouter(prefix="/jobs", tags=["jobs"])
Status = Literal[
    "unassigned", "assigned", "in_progress", "in_review", "changes_requested", "completed", "cancelled"
]


async def member(p: Principal = Depends(get_principal)) -> Principal:
    if not p.company:
        raise Forbidden("no_company", "Choose a company first.")
    return p


@router.get("", response_model=JobList)
async def list_jobs(
    date_: date | None = Query(default=None, alias="date", description="Day in the company's time zone"),
    range_: Literal["day", "week", "month"] = Query(default="day", alias="range"),
    status_: list[Status] | None = Query(default=None, alias="status"),
    assignee: uuid.UUID | None = None,
    unassigned: bool = False,
    q: str | None = None,
    cursor: str | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> JobList:
    return await svc.list_jobs(
        db, p, day=date_, range_=range_, statuses=status_, assignee=assignee, unassigned=unassigned, q=q,
        customer_id=None, cursor=cursor, limit=limit,
    )  # fmt: skip


@router.post("", response_model=JobOut, status_code=status.HTTP_201_CREATED)
async def create_job(
    body: JobCreate, response: Response, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> JobOut:
    j, created = await svc.create_job(db, p, body)
    if not created:
        response.status_code = status.HTTP_200_OK
    return await svc.job_out(db, p, j)


@router.get("/{job_id}", response_model=JobOut)
async def get_job(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> JobOut:
    return await svc.job_out(db, p, await svc.get_job(db, p, job_id))


@router.patch("/{job_id}", response_model=JobOut)
async def patch_job(
    job_id: uuid.UUID,
    body: JobPatch,
    if_match: str | None = Header(default=None),
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> JobOut:
    return await svc.job_out(db, p, await svc.update_job(db, p, job_id, body, if_match))


@router.delete("/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_job(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    await svc.delete(db, p, job_id)
    return Response(status_code=204)


@router.get("/{job_id}/assignable-technicians", response_model=AssignableList)
async def assignable(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> AssignableList:
    return await svc.assignable(db, p, job_id)


@router.post("/{job_id}/assign", response_model=JobOut)
async def assign(
    job_id: uuid.UUID, body: AssignBody, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> JobOut:
    return await svc.job_out(db, p, await svc.assign(db, p, job_id, body.technician_id))


@router.post("/{job_id}/start", response_model=JobOut)
async def start(
    job_id: uuid.UUID,
    body: StartBody | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> JobOut:
    body = body or StartBody()
    return await svc.job_out(db, p, await svc.start(db, p, job_id, body.lat, body.lng))


@router.post("/{job_id}/cancel", response_model=JobOut)
async def cancel(
    job_id: uuid.UUID, body: CancelBody, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> JobOut:
    return await svc.job_out(db, p, await svc.cancel(db, p, job_id, body.reason))


@router.get("/{job_id}/timeline", response_model=Timeline)
async def timeline(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Timeline:
    return await svc.timeline(db, p, job_id)
