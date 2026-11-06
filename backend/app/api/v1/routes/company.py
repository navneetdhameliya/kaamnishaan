import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, client_ip, get_db, get_principal, requires
from app.core.errors import Forbidden
from app.schemas.identity import (
    CompanyCreate,
    CompanyOut,
    CompanyUpdate,
    InvitationCreate,
    InvitationPreview,
    MemberList,
    MemberOut,
    MemberPatch,
    MeOut,
)
from app.services import companies, team
from app.services.views import company_out, me_out

router = APIRouter(tags=["company"])


def _need_company(p: Principal) -> Principal:
    if not p.company:
        raise Forbidden("no_company", "Choose a company first.")
    return p


@router.post("/companies", response_model=CompanyOut, status_code=status.HTTP_201_CREATED)
async def create_company(
    body: CompanyCreate,
    request: Request,
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> CompanyOut:
    c, _ = await companies.create_company(db, p.user, p.session_id, body, client_ip(request))
    return company_out(c)


@router.get("/company", response_model=CompanyOut)
async def get_company(p: Principal = Depends(get_principal)) -> CompanyOut:
    return company_out(_need_company(p).company)


@router.patch("/company", response_model=CompanyOut)
async def patch_company(
    body: CompanyUpdate,
    p: Principal = Depends(requires("company.manage")),
    db: AsyncSession = Depends(get_db),
) -> CompanyOut:
    return company_out(await companies.update_company(db, p.company, body, p.user, p.role))


# ---- team ----------------------------------------------------------------------------------
@router.get("/team", response_model=MemberList)
async def list_team(
    role: Literal["owner", "manager", "technician"] | None = None,
    p: Principal = Depends(requires("team.manage")),
    db: AsyncSession = Depends(get_db),
) -> MemberList:
    return MemberList(items=await team.list_members(db, p.company.id, role))


@router.post("/team/invitations", response_model=MemberOut, status_code=status.HTTP_201_CREATED)
async def invite(
    body: InvitationCreate,
    request: Request,
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> MemberOut:
    return await team.invite(db, _need_company(p), body, client_ip(request))


@router.post("/team/invitations/{id}/resend", status_code=status.HTTP_202_ACCEPTED)
async def resend(
    id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    await team.resend(db, _need_company(p), id)
    return Response(status_code=202)


@router.patch("/team/members/{id}", response_model=MemberOut)
async def patch_member(
    id: uuid.UUID,
    body: MemberPatch,
    p: Principal = Depends(get_principal),
    db: AsyncSession = Depends(get_db),
) -> MemberOut:
    return await team.patch_member(db, _need_company(p), id, body)


# ---- invitation links (opened from the SMS) -------------------------------------------------------
@router.get("/invitations/{token}", response_model=InvitationPreview, tags=["invitations"])
async def preview_invitation(token: str, db: AsyncSession = Depends(get_db)) -> InvitationPreview:
    return await team.preview(db, token)


@router.post("/invitations/{token}/accept", response_model=MeOut, tags=["invitations"])
async def accept_invitation(
    token: str, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> MeOut:
    m, c = await team.accept(db, p.user, p.session_id, token=token)
    return me_out(p.user, c, m)
