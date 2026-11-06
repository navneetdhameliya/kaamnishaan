import uuid

from fastapi import APIRouter, Depends, Header, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal, requires
from app.core.errors import Forbidden
from app.schemas.work import (
    ContactIn,
    ContactOut,
    ContactPatch,
    CustomerCreate,
    CustomerList,
    CustomerOut,
    CustomerPatch,
    EquipmentIn,
    EquipmentOut,
    EquipmentPatch,
    JobList,
    SiteIn,
    SiteOut,
    SitePatch,
)
from app.services import customers as svc
from app.services import jobs as jobs_svc

router = APIRouter(prefix="/customers", tags=["customers"])
manage = requires("customers.manage")


@router.get("", response_model=CustomerList)
async def list_customers(
    q: str | None = None,
    cursor: str | None = None,
    limit: int = Query(default=30, ge=1, le=100),
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> CustomerList:
    return await svc.list_customers(db, p, q, cursor, limit)


@router.post("", response_model=CustomerOut, status_code=status.HTTP_201_CREATED)
async def create_customer(
    body: CustomerCreate,
    response: Response,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> CustomerOut:
    c, created = await svc.create_customer(db, p, body)
    if not created:
        response.status_code = status.HTTP_200_OK
    return await svc.customer_detail(db, c)


@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(
    customer_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> CustomerOut:
    if not p.company:
        raise Forbidden("no_company", "Choose a company first.")
    await svc.can_read(db, p, customer_id)
    return await svc.customer_detail(db, await svc.get_customer(db, p.company_id, customer_id))


@router.patch("/{customer_id}", response_model=CustomerOut)
async def patch_customer(
    customer_id: uuid.UUID,
    body: CustomerPatch,
    if_match: str | None = Header(default=None),
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> CustomerOut:
    return await svc.customer_detail(db, await svc.update_customer(db, p, customer_id, body, if_match))


@router.get("/{customer_id}/jobs", response_model=JobList)
async def customer_jobs(
    customer_id: uuid.UUID,
    cursor: str | None = None,
    limit: int = Query(default=30, ge=1, le=100),
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> JobList:
    await svc.get_customer(db, p.company_id, customer_id)
    return await jobs_svc.list_jobs(
        db, p, day=None, range_="day", statuses=None, assignee=None, unassigned=False, q=None,
        customer_id=customer_id, cursor=cursor, limit=limit,
    )  # fmt: skip


# ---- contacts ------------------------------------------------------------------------------------
@router.post("/{customer_id}/contacts", response_model=ContactOut, status_code=status.HTTP_201_CREATED)
async def add_contact(
    customer_id: uuid.UUID,
    body: ContactIn,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> ContactOut:
    return svc.contact_out(await svc.add_contact(db, p, customer_id, body))


@router.patch("/{customer_id}/contacts/{contact_id}", response_model=ContactOut)
async def patch_contact(
    customer_id: uuid.UUID,
    contact_id: uuid.UUID,
    body: ContactPatch,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> ContactOut:
    return svc.contact_out(await svc.update_contact(db, p, customer_id, contact_id, body))


@router.delete("/{customer_id}/contacts/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(
    customer_id: uuid.UUID,
    contact_id: uuid.UUID,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> Response:
    await svc.delete_contact(db, p, customer_id, contact_id)
    return Response(status_code=204)


# ---- sites and equipment ---------------------------------------------------------------------------
@router.post("/{customer_id}/sites", response_model=SiteOut, status_code=status.HTTP_201_CREATED)
async def add_site(
    customer_id: uuid.UUID, body: SiteIn, p: Principal = Depends(manage), db: AsyncSession = Depends(get_db)
) -> SiteOut:
    return svc.site_out(await svc.add_site(db, p, customer_id, body))


@router.patch("/{customer_id}/sites/{site_id}", response_model=SiteOut)
async def patch_site(
    customer_id: uuid.UUID,
    site_id: uuid.UUID,
    body: SitePatch,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> SiteOut:
    return svc.site_out(await svc.update_site(db, p, customer_id, site_id, body))


@router.post(
    "/{customer_id}/sites/{site_id}/equipment",
    response_model=EquipmentOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_equipment(
    customer_id: uuid.UUID,
    site_id: uuid.UUID,
    body: EquipmentIn,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> EquipmentOut:
    return svc.equipment_out(await svc.add_equipment(db, p, customer_id, site_id, body))


@router.patch("/{customer_id}/sites/{site_id}/equipment/{equipment_id}", response_model=EquipmentOut)
async def patch_equipment(
    customer_id: uuid.UUID,
    site_id: uuid.UUID,
    equipment_id: uuid.UUID,
    body: EquipmentPatch,
    p: Principal = Depends(manage),
    db: AsyncSession = Depends(get_db),
) -> EquipmentOut:
    return svc.equipment_out(await svc.update_equipment(db, p, customer_id, site_id, equipment_id, body))
