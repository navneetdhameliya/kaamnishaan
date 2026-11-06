import uuid

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal
from app.core.security import now
from app.models import Device
from app.schemas.identity import DeviceRegister, MeOut, MeUpdate, MyCompanies
from app.services import team
from app.services.views import active_memberships, choices, me_out

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=MeOut)
async def get_me(p: Principal = Depends(get_principal)) -> MeOut:
    return me_out(p.user, p.company, p.membership)


@router.patch("", response_model=MeOut)
async def patch_me(
    body: MeUpdate, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    if body.name is not None:
        p.user.name = body.name
    if body.app_language is not None:
        p.user.app_language = body.app_language
    await db.flush()
    return me_out(p.user, p.company, p.membership)


@router.get("/companies", response_model=MyCompanies)
async def my_companies(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MyCompanies:
    rows = await active_memberships(db, p.user.id)
    return MyCompanies(
        items=choices(rows, p.company.id if p.company else None),
        invitations=await team.pending_for(db, p.user),
    )


@router.post("/invitations/{invitation_id}/accept", response_model=MeOut)
async def accept_by_id(
    invitation_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    m, c = await team.accept(db, p.user, p.session_id, invitation_id=invitation_id)
    return me_out(p.user, c, m)


@router.post("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def register_device(
    body: DeviceRegister, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    d = (
        await db.execute(
            select(Device).where(Device.user_id == p.user.id, Device.push_token == body.push_token)
        )
    ).scalar_one_or_none()
    if not d:
        d = Device(user_id=p.user.id, push_token=body.push_token, platform=body.platform)
        db.add(d)
    d.platform, d.app_version, d.last_seen_at = body.platform, body.app_version, now()
    return Response(status_code=204)
