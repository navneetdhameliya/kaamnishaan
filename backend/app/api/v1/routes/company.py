import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, client_ip, get_db, get_principal, requires
from app.core.errors import Forbidden
from app.schemas.account import OwnerChange
from app.schemas.identity import (
    CompanyCreate,
    CompanyOut,
    CompanySettingsUpdate,
    CompanyUpdate,
    InviteCreate,
    InviteOut,
    InvitePreview,
    ListMeta,
    MemberList,
    MemberOut,
    MemberPatch,
    MeOut,
    MyInviteList,
)
from app.services import account, companies, team
from app.services.views import company_out, me_out

router = APIRouter()


def _need_company(p: Principal) -> Principal:
    if not p.company:
        raise Forbidden("no_company", "Choose a company first.")
    return p


# ---- company ---------------------------------------------------------------------------------
@router.post("/companies", response_model=CompanyOut, status_code=status.HTTP_201_CREATED, tags=["company"])
async def create_company(
    body: CompanyCreate,
    request: Request,
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> CompanyOut:
    c, _ = await companies.create_company(db, p.user, p.session_id, body, client_ip(request))
    return company_out(c)


@router.get("/company", response_model=CompanyOut, tags=["company"])
async def get_company(p: Principal = Depends(requires("company.view"))) -> CompanyOut:
    return company_out(p.company)


@router.patch("/company", response_model=CompanyOut, tags=["company"])
async def patch_company(
    body: CompanyUpdate,
    p: Principal = Depends(requires("company.manage")),
    db: AsyncSession = Depends(get_db),
) -> CompanyOut:
    return company_out(await companies.update_company(db, p.company, body, p.user, p.role))


@router.patch("/company/settings", response_model=CompanyOut, tags=["company"])
async def patch_company_settings(
    body: CompanySettingsUpdate,
    p: Principal = Depends(requires("company.manage")),
    db: AsyncSession = Depends(get_db),
) -> CompanyOut:
    return company_out(await companies.update_settings(db, p.company, body, p.user, p.role))


# ---- team ------------------------------------------------------------------------------------
@router.get("/team", response_model=MemberList, tags=["team"])
async def list_team(
    role: Literal["owner", "manager", "technician"] | None = None,
    q: str | None = None,
    p: Principal = Depends(requires("team.view")),
    db: AsyncSession = Depends(get_db),
) -> MemberList:
    return await team.list_members(db, p.company_id, role, q)


@router.get("/team/{user_id}", response_model=MemberOut, tags=["team"])
async def get_member(
    user_id: uuid.UUID, p: Principal = Depends(requires("team.view")), db: AsyncSession = Depends(get_db)
) -> MemberOut:
    return await team.get_member(db, p, user_id)


@router.patch("/team/{user_id}", response_model=MemberOut, tags=["team"])
async def patch_member(
    user_id: uuid.UUID,
    body: MemberPatch,
    p: Principal = Depends(requires("team.invite_technician")),
    db: AsyncSession = Depends(get_db),
) -> MemberOut:
    return await team.change_role(db, p, user_id, body.role)


@router.delete("/team/{user_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["team"])
async def remove_member(
    user_id: uuid.UUID,
    p: Principal = Depends(requires("team.invite_technician")),
    db: AsyncSession = Depends(get_db),
) -> Response:
    await team.remove(db, p, user_id)
    return Response(status_code=204)


# ---- invites -----------------------------------------------------------------------------------
@router.post("/company/owner", response_model=MeOut, tags=["team"])
async def change_owner(
    body: OwnerChange, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    """The owner hands the company to an active member, who becomes owner; you become a manager."""
    await account.change_owner(db, p, body.user_id)
    return me_out(p.user, p.company, p.membership)


@router.post("/invites", response_model=InviteOut, status_code=status.HTTP_201_CREATED, tags=["invites"])
async def create_invite(
    body: InviteCreate,
    request: Request,
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> InviteOut:
    return await team.invite(db, _need_company(p), body, client_ip(request))


@router.get("/invites/preview", response_model=InvitePreview, tags=["invites"])
async def invite_preview(p: Principal = Depends(get_principal)) -> InvitePreview:
    """The SMS text M40 shows while the form is filled."""
    return team.preview(_need_company(p))


@router.get("/invites/mine", response_model=MyInviteList, tags=["invites"])
async def my_invites(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MyInviteList:
    items = await team.my_invites(db, p.user)
    pending = sum(i.status == "pending" for i in items)
    return MyInviteList(
        data=items, meta=ListMeta(counts={"pending": pending, "expired": len(items) - pending})
    )


@router.post("/invites/{invite_id}/resend", response_model=InviteOut, tags=["invites"])
async def resend_invite(
    invite_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> InviteOut:
    return await team.resend(db, _need_company(p), invite_id)


@router.delete("/invites/{invite_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["invites"])
async def revoke_invite(
    invite_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    await team.revoke(db, _need_company(p), invite_id)
    return Response(status_code=204)


@router.post("/invites/{invite_id}/accept", response_model=MeOut, tags=["invites"])
async def accept_invite(
    invite_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    m, c = await team.accept(db, p.user, p.session_id, invite_id)
    return me_out(p.user, c, m)


@router.post("/invites/{invite_id}/decline", status_code=status.HTTP_204_NO_CONTENT, tags=["invites"])
async def decline_invite(
    invite_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    await team.decline(db, p.user, invite_id)
    return Response(status_code=204)
