import uuid

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, client_ip, get_db, get_principal
from app.schemas.identity import (
    EmailBody,
    EmailChange,
    EmailLogin,
    OtpSend,
    OtpSent,
    OtpVerify,
    PasswordReset,
    RefreshBody,
    Register,
    SessionOut,
    SignedInDevices,
    SignedOut,
    SwitchCompany,
    TokenBody,
)
from app.services import auth

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/otp/send", response_model=OtpSent, status_code=status.HTTP_202_ACCEPTED)
async def otp_send(body: OtpSend, request: Request, db: AsyncSession = Depends(get_db)) -> OtpSent:
    ch = await auth.send_otp(db, body.phone, body.purpose, client_ip(request))
    return OtpSent(challenge_id=ch.id, resend_after=auth.OTP_RESEND_AFTER_S, expires_at=ch.expires_at)


@router.post("/otp/verify", response_model=SessionOut)
async def otp_verify(body: OtpVerify, db: AsyncSession = Depends(get_db)) -> SessionOut:
    session, _ = await auth.verify_otp(db, body.challenge_id, body.code, body.device_id)
    return session


@router.post("/register", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def register(body: Register, db: AsyncSession = Depends(get_db)) -> SessionOut:
    return await auth.register_owner(
        db, name=body.name, email=body.email, password=body.password, phone=body.phone
    )


@router.post("/login", response_model=SessionOut)
async def login(body: EmailLogin, request: Request, db: AsyncSession = Depends(get_db)) -> SessionOut:
    return await auth.login_email(db, body.email, body.password, client_ip(request))


@router.post("/password/forgot", status_code=status.HTTP_202_ACCEPTED)
async def password_forgot(body: EmailBody, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.forgot_password(db, body.email)
    return Response(status_code=202)


@router.post("/password/reset", status_code=status.HTTP_204_NO_CONTENT)
async def password_reset(body: PasswordReset, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.reset_password(db, body.token, body.password)
    return Response(status_code=204)


@router.post("/email/send-verification", status_code=status.HTTP_202_ACCEPTED)
async def email_send_verification(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    await auth.send_verification(db, p.user)
    return Response(status_code=202)


@router.post("/email/verify", status_code=status.HTTP_204_NO_CONTENT)
async def email_verify(body: TokenBody, db: AsyncSession = Depends(get_db)) -> Response:
    await auth.verify_email(db, body.token)
    return Response(status_code=204)


@router.patch("/email", status_code=status.HTTP_202_ACCEPTED)
async def email_change(
    body: EmailChange, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    await auth.change_email(db, p.user, body.email)
    return Response(status_code=202)


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


@router.get("/sessions", response_model=SignedInDevices)
async def devices(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> SignedInDevices:
    """Me → Signed-in devices: where this account is signed in now (D-146)."""
    return await auth.devices(db, p.user, p.session_id)


@router.post("/sessions/sign-out-others", response_model=SignedOut)
async def sign_out_others(
    p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> SignedOut:
    """Sign out everywhere else: every device but this one has to sign in again."""
    out = await auth.sign_out_others(db, p.user, p.session_id)
    await db.commit()
    return out


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def sign_out_device(
    session_id: uuid.UUID, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> Response:
    """Signs one other device out."""
    await auth.sign_out_device(db, p.user, p.session_id, session_id)
    await db.commit()
    return Response(status_code=204)
