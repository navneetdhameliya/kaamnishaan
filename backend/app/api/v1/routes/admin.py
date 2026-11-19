"""Admin panel API (A01 log in, setup, A03 dashboard). Only staff tokens work here; an app user's
token is refused. Every log in, failed log in and setup is written to the audit log (A31)."""

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Staff, client_ip, get_db, get_staff
from app.core.errors import AppError
from app.schemas.identity import Locale
from app.schemas.staff import (
    DashboardOut,
    StaffLoginIn,
    StaffOut,
    StaffRefreshIn,
    StaffSessionOut,
    StaffSetupIn,
    StaffSetupInfo,
    StaffSetupOut,
)
from app.services import admin_dashboard, staff

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/auth/login", response_model=StaffSessionOut)
async def login(body: StaffLoginIn, request: Request, db: AsyncSession = Depends(get_db)) -> StaffSessionOut:
    """Email, password and the 6-digit code from the authenticator app (or one recovery code).
    Five wrong tries lock the email for 15 minutes; the error never says which part was wrong."""
    return await staff.login(
        db,
        email=body.email,
        password=body.password,
        code=body.code,
        recovery_code=body.recovery_code,
        ip=client_ip(request),
        agent=request.headers.get("user-agent"),
    )


@router.post("/auth/refresh", response_model=StaffSessionOut)
async def refresh(body: StaffRefreshIn, db: AsyncSession = Depends(get_db)) -> StaffSessionOut:
    """New tokens; the old refresh token stops working. A staff session ends 12 hours after log in."""
    return await staff.refresh(db, body.refresh_token)


@router.post("/auth/logout", status_code=204)
async def logout(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> Response:
    await staff.logout(db, me.session_id)
    return Response(status_code=204)


@router.get("/auth/setup", response_model=StaffSetupInfo)
async def setup_info(token: str, response: Response, db: AsyncSession = Depends(get_db)) -> StaffSetupInfo:
    """What the setup page needs: the authenticator secret (and QR text) for this link."""
    response.headers["Cache-Control"] = "no-store"
    return await staff.setup_info(db, token)


@router.post("/auth/setup", response_model=StaffSetupOut)
async def setup(body: StaffSetupIn, request: Request, db: AsyncSession = Depends(get_db)) -> StaffSetupOut:
    """Choose a password and confirm the first code. Returns 8 recovery codes, shown only once."""
    return await staff.finish_setup(
        db,
        token=body.token,
        password=body.password,
        code=body.code,
        ip=client_ip(request),
        agent=request.headers.get("user-agent"),
    )


@router.get("/me", response_model=StaffOut)
async def me(s: Staff = Depends(get_staff)) -> StaffOut:
    return staff.staff_out(s.staff)


@router.get("/dashboard", response_model=DashboardOut)
async def dashboard(
    days: int = Query(30, description="7, 30 or 90"),
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> DashboardOut:
    if days not in (7, 30, 90):
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"days": "choose_7_30_90"}, status=422
        )
    return await admin_dashboard.dashboard(db, days=days, lang=locale)
