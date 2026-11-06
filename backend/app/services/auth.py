"""Sign in by phone code (technicians, managers) or email + password (owners, web), sessions, refresh."""

import hmac
import uuid
from datetime import timedelta

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, Conflict, Forbidden, Gone, RateLimited, Unauthorized
from app.core.security import (
    ACCESS_TTL,
    REFRESH_TTL,
    create_access_token,
    create_link_token,
    digest,
    hash_password,
    normalize_phone,
    now,
    otp_code,
    password_fingerprint,
    random_token,
    read_link_token,
    verify_password,
)
from app.models import AuthSession, Company, Membership, OtpChallenge, User
from app.providers.messaging import send_email, send_sms
from app.schemas.identity import SessionOut
from app.services import audit
from app.services.views import active_memberships, choices, me_out

OTP_TTL = timedelta(minutes=5)
OTP_MAX_ATTEMPTS = 5
OTP_RESEND_AFTER_S = 45
OTP_PER_PHONE_HOUR = 5
OTP_PER_IP_HOUR = 20
EMAIL_VERIFY_TTL = timedelta(days=3)
RESET_TTL = timedelta(minutes=30)
EMAILS_PER_HOUR = 3


# ---- phone codes ----------------------------------------------------------------------
async def request_otp(db: AsyncSession, raw_phone: str, purpose: str, ip: str | None) -> OtpChallenge:
    phone = normalize_phone(raw_phone, get_settings().default_country)
    t = now()
    last = (
        await db.execute(
            select(OtpChallenge)
            .where(OtpChallenge.phone == phone)
            .order_by(OtpChallenge.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if last and (t - last.created_at).total_seconds() < OTP_RESEND_AFTER_S:
        wait = OTP_RESEND_AFTER_S - int((t - last.created_at).total_seconds())
        raise RateLimited(
            "otp_too_soon", "Please wait before asking for a new code.", {"retry_after_s": wait}
        )
    hour = t - timedelta(hours=1)
    per_phone = (
        await db.execute(
            select(func.count()).where(OtpChallenge.phone == phone, OtpChallenge.created_at > hour)
        )
    ).scalar_one()
    per_ip = 0
    if ip:
        per_ip = (
            await db.execute(
                select(func.count()).where(OtpChallenge.ip == ip, OtpChallenge.created_at > hour)
            )
        ).scalar_one()
    if per_phone >= OTP_PER_PHONE_HOUR or per_ip >= OTP_PER_IP_HOUR:
        raise RateLimited(
            "otp_limit", "Too many codes asked for. Try again in an hour.", {"retry_after_s": 3600}
        )

    code = otp_code()
    ch = OtpChallenge(phone=phone, code_hash=digest(code), purpose=purpose, expires_at=t + OTP_TTL, ip=ip)
    db.add(ch)
    await db.flush()
    await send_sms(phone, "otp", code=code)
    return ch


async def verify_otp(
    db: AsyncSession, challenge_id: uuid.UUID, code: str, device_id: str | None
) -> tuple[SessionOut, bool]:
    """Returns the session and whether a new account was made."""
    ch = await db.get(OtpChallenge, challenge_id, with_for_update=True)
    if not ch or ch.consumed_at:
        raise AppError("otp_invalid", "This code is not valid. Ask for a new one.")
    if ch.expires_at < now():
        raise AppError("otp_expired", "This code has expired. Ask for a new one.")
    if ch.attempts >= OTP_MAX_ATTEMPTS:
        raise AppError("otp_locked", "Too many wrong tries. Ask for a new code.")
    ch.attempts += 1
    if not hmac.compare_digest(ch.code_hash, digest(code)):
        left = OTP_MAX_ATTEMPTS - ch.attempts
        # commit the failed attempt even though we answer with an error
        await db.commit()
        raise AppError("otp_wrong", "That code is not right.", {"attempts_left": left})
    ch.consumed_at = now()

    user = (await db.execute(select(User).where(User.phone == ch.phone))).scalar_one_or_none()
    created = False
    if not user:
        user = User(phone=ch.phone, status="active")
        db.add(user)
        await db.flush()
        created = True
    elif user.status == "disabled":
        raise Unauthorized("account_disabled", "This account is turned off.")
    session = await start_session(db, user, device_id=device_id)
    return session, created


# ---- email + password -------------------------------------------------------------------
async def login_email(db: AsyncSession, email: str, password: str) -> SessionOut:
    user = (
        await db.execute(select(User).where(func.lower(User.email) == email.lower()))
    ).scalar_one_or_none()
    # same answer for unknown email and wrong password
    if not user or not verify_password(password, user.password_hash):
        raise Unauthorized("wrong_credentials", "Email or password is not right.")
    if user.status == "disabled":
        raise Unauthorized("account_disabled", "This account is turned off.")
    return await start_session(db, user)


async def signup_owner(
    db: AsyncSession, *, name: str, email: str, password: str, phone: str | None
) -> SessionOut:
    email = email.lower()
    if (await db.execute(select(User.id).where(func.lower(User.email) == email))).first():
        raise Conflict("email_taken", "An account with this email already exists. Sign in instead.")
    e164 = None
    if phone:
        e164 = normalize_phone(phone, get_settings().default_country)
        if (await db.execute(select(User.id).where(User.phone == e164))).first():
            raise Conflict("phone_taken", "This phone number already has an account. Sign in with it.")
    user = User(name=name, email=email, phone=e164, password_hash=hash_password(password), status="active")
    db.add(user)
    await db.flush()
    await _send_verification(db, user)
    return await start_session(db, user)


async def _send_verification(db: AsyncSession, user: User) -> None:
    if await audit.count_recent(db, "email.verify_sent", user.id, timedelta(hours=1)) >= EMAILS_PER_HOUR:
        raise RateLimited("email_limit", "We've sent a few emails already. Try again later.")
    token = create_link_token("email_verify", str(user.id), EMAIL_VERIFY_TTL, fingerprint=user.email or "")
    link = f"{get_settings().web_url}/verify-email?token={token}"
    await send_email(user.email, "verify_email", "Confirm your email", name=user.name or "", link=link)
    await audit.record(db, "email.verify_sent", actor_id=user.id, target_type="user", target_id=user.id)


async def resend_verification(db: AsyncSession, user: User) -> None:
    if not user.email:
        raise AppError("no_email", "Add an email first.")
    if user.email_verified_at:
        return
    await _send_verification(db, user)


async def verify_email(db: AsyncSession, token: str) -> None:
    claims = read_link_token(token, "email_verify")
    user = await db.get(User, uuid.UUID(claims["sub"]))
    if not user or (user.email or "") != claims.get("fp"):
        raise Gone("link_invalid", "This link is not valid.")
    if not user.email_verified_at:
        user.email_verified_at = now()


async def forgot_password(db: AsyncSession, email: str) -> None:
    """Always looks the same to the caller, whether or not the email exists."""
    user = (
        await db.execute(select(User).where(func.lower(User.email) == email.lower()))
    ).scalar_one_or_none()
    if not user or user.status == "disabled":
        return
    if await audit.count_recent(db, "password.reset_sent", user.id, timedelta(hours=1)) >= EMAILS_PER_HOUR:
        return
    token = create_link_token(
        "password_reset", str(user.id), RESET_TTL, fingerprint=password_fingerprint(user.password_hash)
    )
    link = f"{get_settings().web_url}/reset-password?token={token}"
    await send_email(user.email, "reset_password", "Reset your password", name=user.name or "", link=link)
    await audit.record(db, "password.reset_sent", actor_id=user.id, target_type="user", target_id=user.id)


async def reset_password(db: AsyncSession, token: str, password: str) -> None:
    claims = read_link_token(token, "password_reset")
    user = await db.get(User, uuid.UUID(claims["sub"]))
    if not user or password_fingerprint(user.password_hash) != claims.get("fp"):
        raise Gone("link_invalid", "This link was already used or is not valid.")
    user.password_hash = hash_password(password)
    # sign out everywhere
    await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=now())
    )
    await audit.record(db, "password.reset", actor_id=user.id, target_type="user", target_id=user.id)


# ---- sessions ------------------------------------------------------------------------------
def _refresh_value(session_id: uuid.UUID, secret: str) -> str:
    return f"{session_id}.{secret}"


async def _pick_company(
    db: AsyncSession, user: User, rows: list[tuple[Membership, Company]]
) -> uuid.UUID | None:
    if len(rows) == 1:
        return rows[0][1].id
    if not rows:
        return None
    # several companies: reuse the one from the most recent session, if still a member
    last = (
        await db.execute(
            select(AuthSession.active_company_id)
            .where(AuthSession.user_id == user.id, AuthSession.active_company_id.is_not(None))
            .order_by(AuthSession.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    ids = {c.id for _, c in rows}
    return last if last in ids else None


async def start_session(
    db: AsyncSession, user: User, *, device_id: str | None = None, company_id: uuid.UUID | None = None
) -> SessionOut:
    rows = await active_memberships(db, user.id)
    active = company_id if company_id else await _pick_company(db, user, rows)
    secret = random_token()
    sess = AuthSession(
        user_id=user.id,
        active_company_id=active,
        refresh_token_hash=digest(secret),
        device_id=device_id,
        expires_at=now() + REFRESH_TTL,
        last_used_at=now(),
    )
    db.add(sess)
    user.last_seen_at = now()
    await db.flush()
    return _session_out(user, sess, rows, secret)


def _session_out(user: User, sess: AuthSession, rows, secret: str) -> SessionOut:
    current = next(((m, c) for m, c in rows if c.id == sess.active_company_id), None)
    m, c = current if current else (None, None)
    needs = []
    if not user.name:
        needs.append("profile")
    if not rows:
        needs.append("create_or_join_company")
    elif not current:
        needs.append("choose_company")
    if user.email and not user.email_verified_at and user.password_hash:
        needs.append("email_verification")
    return SessionOut(
        access_token=create_access_token(
            user_id=user.id, session_id=sess.id, company_id=c.id if c else None, role=m.role if m else None
        ),
        refresh_token=_refresh_value(sess.id, secret),
        expires_in=int(ACCESS_TTL.total_seconds()),
        user=me_out(user, c, m),
        needs=needs,
        companies=choices(rows, sess.active_company_id),
    )


async def _rotate(db: AsyncSession, user: User, sess: AuthSession) -> SessionOut:
    rows = await active_memberships(db, user.id)
    if sess.active_company_id and sess.active_company_id not in {c.id for _, c in rows}:
        sess.active_company_id = None  # removed from that company meanwhile
    if not sess.active_company_id:
        sess.active_company_id = await _pick_company(db, user, rows)
    secret = random_token()
    sess.refresh_token_hash = digest(secret)
    sess.last_used_at = now()
    user.last_seen_at = now()
    await db.flush()
    return _session_out(user, sess, rows, secret)


async def refresh(db: AsyncSession, refresh_token: str) -> SessionOut:
    try:
        sid, secret = refresh_token.split(".", 1)
        session_id = uuid.UUID(sid)
    except ValueError as e:
        raise Unauthorized("invalid_token", "Please sign in again.") from e
    sess = await db.get(AuthSession, session_id, with_for_update=True)
    if not sess or sess.revoked_at or sess.expires_at < now():
        raise Unauthorized("session_ended", "Please sign in again.")
    if not hmac.compare_digest(sess.refresh_token_hash, digest(secret)):
        # an old refresh token was replayed: someone may have copied it, so end this session
        sess.revoked_at = now()
        await audit.record(
            db, "session.reuse_detected", actor_id=sess.user_id, target_type="session", target_id=sess.id
        )
        await db.commit()
        raise Unauthorized("session_ended", "Please sign in again.")
    user = await db.get(User, sess.user_id)
    if not user or user.status == "disabled":
        raise Unauthorized("account_disabled", "This account is turned off.")
    return await _rotate(db, user, sess)


async def switch_company(
    db: AsyncSession, user: User, session_id: uuid.UUID, company_id: uuid.UUID
) -> SessionOut:
    member = (
        await db.execute(
            select(Membership.id).where(
                Membership.user_id == user.id,
                Membership.company_id == company_id,
                Membership.status == "active",
            )
        )
    ).first()
    if not member:
        raise Forbidden("not_a_member", "You are not part of this company.")
    sess = await db.get(AuthSession, session_id, with_for_update=True)
    sess.active_company_id = company_id
    return await _rotate(db, user, sess)


async def logout(db: AsyncSession, session_id: uuid.UUID) -> None:
    sess = await db.get(AuthSession, session_id)
    if sess and not sess.revoked_at:
        sess.revoked_at = now()
