from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, client_ip, get_db, get_principal
from app.schemas.identity import (
    EmailBody,
    EmailLogin,
    OtpRequest,
    OtpRequested,
    OtpVerify,
    OwnerSignup,
    PasswordReset,
    RefreshBody,
    SessionOut,
    SwitchCompany,
    TokenBody,
)
from app.services import auth

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/otp/request", response_model=OtpRequested, status_code=status.HTTP_202_ACCEPTED)
async def otp_request(body: OtpRequest, request: Request, db: AsyncSession = Depends(get_db)) -> OtpRequested:
    ch = await auth.request_otp(db, body.phone, body.purpose, client_ip(request))
    return OtpRequested(challenge_id=ch.id, resend_after_s=auth.OTP_RESEND_AFTER_S)


@router.post("/otp/verify", response_model=SessionOut)
async def otp_verify(body: OtpVerify, db: AsyncSession = Depends(get_db)) -> SessionOut:
    session, _ = await auth.verify_otp(db, body.challenge_id, body.code, body.device_id)
    return session


@router.post("/login", response_model=SessionOut)
async def login(body: EmailLogin, db: AsyncSession = Depends(get_db)) -> SessionOut:
    return await auth.login_email(db, body.email, body.password)


@router.post("/signup", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def signup(body: OwnerSignup, db: AsyncSession = Depends(get_db)) -> SessionOut:
    return await auth.signup_owner(
        db, name=body.name, email=body.email, password=body.password, phone=body.phone
    )


@router.post("/email/verify", status_code=status.HTTP_204_NO_CONTENT)
async def email_verify(body: TokenBody, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.verify_email(db, body.token)
    return Response(status_code=204)


@router.post("/email/resend", status_code=status.HTTP_202_ACCEPTED)
async def email_resend(p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)) -> Response:
    await auth.resend_verification(db, p.user)
    return Response(status_code=202)


@router.post("/password/forgot", status_code=status.HTTP_202_ACCEPTED)
async def password_forgot(body: EmailBody, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.forgot_password(db, body.email)
    return Response(status_code=202)


@router.post("/password/reset", status_code=status.HTTP_204_NO_CONTENT)
async def password_reset(body: PasswordReset, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.reset_password(db, body.token, body.password)
    return Response(status_code=204)


@router.post("/refresh", response_model=SessionOut)
async def refresh(body: RefreshBody, db: AsyncSession = Depends(get_db)) -> SessionOut:
    return await auth.refresh(db, body.refresh_token)


@router.post("/switch-company", response_model=SessionOut)
async def switch_company(
    body: SwitchCompany, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> SessionOut:
    return await auth.switch_company(db, p.user, p.session_id, body.company_id)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)) -> Response:
    await auth.logout(db, p.session_id)
    return Response(status_code=204)
