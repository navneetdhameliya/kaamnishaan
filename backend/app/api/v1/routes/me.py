from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db, get_principal
from app.core.security import now
from app.models import Device
from app.schemas.account import AccountDelete, DeletionCheck
from app.schemas.identity import DeviceRegister, ListMeta, MeOut, MeUpdate, MyCompanies, Preferences
from app.services import account
from app.services.companies import check_trade
from app.services.evidence import take_upload
from app.services.views import active_memberships, choices, me_out

router = APIRouter(tags=["me"])


@router.get("/me", response_model=MeOut)
async def get_me(p: Principal = Depends(get_principal)) -> MeOut:
    return me_out(p.user, p.company, p.membership)


@router.patch("/me", response_model=MeOut)
async def patch_me(
    body: MeUpdate, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    if body.name is not None:
        p.user.name = body.name
    if body.trade is not None:
        await check_trade(db, body.trade)
        p.user.trade = body.trade
    if body.avatar_upload_id is not None:
        up, _ = await take_upload(db, p, body.avatar_upload_id, "avatar")
        p.user.avatar_key = up.key
    elif body.remove_avatar:
        p.user.avatar_key = None
    await db.flush()
    return me_out(p.user, p.company, p.membership)


@router.patch("/me/preferences", response_model=MeOut)
async def patch_preferences(
    body: Preferences, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    if body.app_language is not None:
        p.user.app_language = body.app_language
    if body.theme is not None:
        p.user.theme = body.theme
    await db.flush()
    return me_out(p.user, p.company, p.membership)


@router.get("/me/companies", response_model=MyCompanies)
async def my_companies(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MyCompanies:
    rows = await active_memberships(db, p.user.id)
    items = choices(rows, p.company.id if p.company else None)
    return MyCompanies(data=items, meta=ListMeta(counts={"all": len(items)}))


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


@router.get("/me/deletion", response_model=DeletionCheck)
async def deletion_check(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> DeletionCheck:
    """What deleting your account would do: companies left or closed, and whether to pick an owner first."""
    return await account.check(db, p.user)


@router.post("/me/delete", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    body: AccountDelete, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    """Deletes your account now: your details are wiped and you are logged out everywhere. Your work stays
    with the company. An owner with a team gets 409 owner_has_team until they pick a new owner."""
    await account.delete(db, p.user, body.reason)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
