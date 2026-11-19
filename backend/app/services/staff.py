"""Staff accounts for the admin panel: log in with password + authenticator code (A01), setup links
(first time, or after a reset), sessions. There is no email service yet (D-96), so setup links are
printed by `scripts/staff.py` or written to the server log on start-up (KN_ADMIN_EMAIL)."""

import logging
import uuid

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.core.errors import AppError, Forbidden, Gone, NotFound, RateLimited, Unauthorized
from app.core.security import (
    create_link_token,
    digest,
    hash_password,
    now,
    random_token,
    read_link_token,
    verify_password,
)
from app.core.staff_security import (
    SETUP_LINK_TTL,
    STAFF_ACCESS_TTL,
    STAFF_SESSION_TTL,
    create_staff_token,
    match_totp,
    new_recovery_codes,
    new_totp_secret,
    otpauth_uri,
    recovery_digest,
    seal,
    unseal,
)
from app.models import LoginAttempt, StaffSession, StaffUser
from app.schemas.staff import StaffOut, StaffSessionOut, StaffSetupInfo, StaffSetupOut
from app.services import audit
from app.services.auth import LOGIN_LOCK, LOGIN_MAX_FAILS, _lock_state, check_password

log = logging.getLogger("kn.staff")
SETUP_PURPOSE = "staff_setup"
SETUP_MAX_FAILS = 10
# checked when the email is unknown, so a wrong email takes as long as a wrong password
_DUMMY_HASH = hash_password("not-a-real-password-1")


def staff_out(s: StaffUser) -> StaffOut:
    return StaffOut(
        id=s.id, name=s.name, email=s.email, role=s.role, recovery_codes_left=len(s.recovery_codes or [])
    )


# ---- setup links ------------------------------------------------------------------------------------
async def issue_setup_link(db: AsyncSession, staff: StaffUser, *, by: uuid.UUID | None = None) -> str:
    """Start (or restart) setting up: clears the password, the authenticator and the recovery codes,
    ends every session, and makes older setup links stop working."""
    reset = staff.password_hash is not None
    staff.status = "invited"
    staff.password_hash = None
    staff.totp_secret = seal(new_totp_secret())
    staff.totp_last_step = None
    staff.recovery_codes = []
    staff.setup_version = (staff.setup_version or 0) + 1
    await db.execute(
        update(StaffSession)
        .where(StaffSession.staff_id == staff.id, StaffSession.revoked_at.is_(None))
        .values(revoked_at=now())
    )
    await audit.record(
        db, "staff.reset" if reset else "staff.invited", staff_id=by, target_type="staff", target_id=staff.id
    )
    await db.flush()
    return setup_link(staff)


def setup_link(staff: StaffUser) -> str:
    """A link for the current setup (does not reset anything; earlier links keep working)."""
    token = create_link_token(
        SETUP_PURPOSE, str(staff.id), SETUP_LINK_TTL, fingerprint=str(staff.setup_version)
    )
    return f"{get_settings().admin_url.rstrip('/')}/setup?token={token}"


async def invite(db: AsyncSession, *, email: str, name: str, role: str = "admin") -> tuple[StaffUser, str]:
    email = email.strip().lower()
    staff = (await db.execute(select(StaffUser).where(StaffUser.email == email))).scalar_one_or_none()
    if staff is None:
        staff = StaffUser(email=email, name=name.strip(), role=role, status="invited")
        db.add(staff)
        await db.flush()
    link = await issue_setup_link(db, staff)
    return staff, link


async def _setup_staff(db: AsyncSession, token: str) -> StaffUser:
    claims = read_link_token(token, SETUP_PURPOSE)
    staff = await db.get(StaffUser, uuid.UUID(claims["sub"]))
    if not staff or claims.get("fp") != str(staff.setup_version) or staff.status != "invited":
        raise Gone("link_invalid", "This link is not valid. Ask a super admin for a new one.")
    return staff


async def setup_info(db: AsyncSession, token: str) -> StaffSetupInfo:
    staff = await _setup_staff(db, token)
    secret = unseal(staff.totp_secret or "")
    if not secret:
        raise Gone("link_invalid", "This link is not valid. Ask a super admin for a new one.")
    reset = (staff.setup_version or 0) > 1 or staff.last_login_at is not None
    return StaffSetupInfo(
        email=staff.email,
        name=staff.name,
        is_reset=reset,
        secret=secret,
        otpauth_uri=otpauth_uri(secret, staff.email),
    )


async def finish_setup(
    db: AsyncSession, *, token: str, password: str, code: str, ip: str | None, agent: str | None
) -> StaffSetupOut:
    staff = await _setup_staff(db, token)
    ident = f"staff-setup:{staff.id}"
    fails, locked_until = await _lock_state(db, ident)
    if locked_until or fails >= SETUP_MAX_FAILS:
        raise RateLimited("too_many_tries", "Too many wrong codes. Try again in 15 minutes.")
    check_password(password)
    step = match_totp(unseal(staff.totp_secret or "") or "", code, None)
    if step is None:
        db.add(LoginAttempt(identifier=ident, success=False, ip=ip))
        await db.commit()
        raise AppError(
            "code_invalid",
            "This code is wrong or expired. Open your app for a new one.",
            fields={"code": "code_invalid"},
        )
    codes = new_recovery_codes()
    staff.password_hash = hash_password(password)
    staff.totp_last_step = step
    staff.recovery_codes = [recovery_digest(c) for c in codes]
    staff.status = "active"
    db.add(LoginAttempt(identifier=ident, success=True, ip=ip))
    await audit.record(
        db, "staff.setup_done", staff_id=staff.id, target_type="staff", target_id=staff.id, ip=ip
    )
    out = await _start(db, staff, ip=ip, agent=agent)
    return StaffSetupOut(**out.model_dump(), recovery_codes=codes)


# ---- log in, refresh, log out -----------------------------------------------------------------------
async def _start(db: AsyncSession, staff: StaffUser, *, ip: str | None, agent: str | None) -> StaffSessionOut:
    secret = random_token()
    sess = StaffSession(
        staff_id=staff.id,
        refresh_token_hash=digest(secret),
        expires_at=now() + STAFF_SESSION_TTL,
        last_used_at=now(),
        ip=ip,
        user_agent=(agent or "")[:255] or None,
    )
    db.add(sess)
    staff.last_login_at = now()
    await db.flush()
    return _session_out(staff, sess, secret)


def _session_out(staff: StaffUser, sess: StaffSession, secret: str) -> StaffSessionOut:
    return StaffSessionOut(
        access_token=create_staff_token(staff_id=staff.id, session_id=sess.id),
        refresh_token=f"{sess.id}.{secret}",
        expires_in=int(STAFF_ACCESS_TTL.total_seconds()),
        session_ends_at=sess.expires_at,
        staff=staff_out(staff),
    )


def _second_factor_ok(staff: StaffUser, code: str | None, recovery: str | None) -> str | None:
    """'totp' or 'recovery' when the second step is right (and records its use), else None."""
    if code:
        step = match_totp(unseal(staff.totp_secret or "") or "", code, staff.totp_last_step)
        if step is not None:
            staff.totp_last_step = step
            return "totp"
    if recovery:
        d = recovery_digest(recovery)
        left = list(staff.recovery_codes or [])
        if d in left:
            left.remove(d)
            staff.recovery_codes = left
            return "recovery"
    return None


async def login(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    code: str | None,
    recovery_code: str | None,
    ip: str | None,
    agent: str | None,
) -> StaffSessionOut:
    email = email.strip().lower()
    ident = f"staff:{email}"
    fails, locked_until = await _lock_state(db, ident)
    if locked_until:
        raise Forbidden(
            "account_locked",
            "Too many wrong tries. Try again in 15 minutes.",
            {"locked_until": locked_until.isoformat()},
        )
    staff = (await db.execute(select(StaffUser).where(StaffUser.email == email))).scalar_one_or_none()
    password_ok = verify_password(password, staff.password_hash if staff else _DUMMY_HASH)
    usable = staff is not None and staff.status == "active" and password_ok
    how = _second_factor_ok(staff, code, recovery_code) if usable else None
    if not how:
        # one answer for every failure: which part was wrong is never told (A01 errors)
        db.add(LoginAttempt(identifier=ident, success=False, ip=ip))
        await audit.record(
            db,
            "staff.login_failed",
            staff_id=staff.id if staff else None,
            target_type="staff",
            target_id=staff.id if staff else None,
            data={"email": email},
            ip=ip,
        )
        await db.commit()
        left = LOGIN_MAX_FAILS - fails - 1
        if left <= 0:
            raise Forbidden(
                "account_locked",
                "Too many wrong tries. Try again in 15 minutes.",
                {"locked_until": (now() + LOGIN_LOCK).isoformat()},
            )
        raise Unauthorized("login_invalid", "Email, password or code is wrong.", {"attempts_left": left})
    db.add(LoginAttempt(identifier=ident, success=True, ip=ip))
    await audit.record(
        db,
        "staff.login",
        staff_id=staff.id,
        target_type="staff",
        target_id=staff.id,
        data={"with": how},
        ip=ip,
    )
    return await _start(db, staff, ip=ip, agent=agent)


async def refresh(db: AsyncSession, token: str) -> StaffSessionOut:
    sid, _, secret = token.partition(".")
    try:
        sess = await db.get(StaffSession, uuid.UUID(sid), with_for_update=True)
    except ValueError:
        sess = None
    if not sess or sess.revoked_at or sess.expires_at < now():
        raise Unauthorized("session_ended", "Please log in again.")
    if digest(secret) != sess.refresh_token_hash:
        # an old refresh token came back: someone may have copied it, so end the session
        sess.revoked_at = now()
        await audit.record(
            db, "staff.session_reuse", staff_id=sess.staff_id, target_type="staff_session", target_id=sess.id
        )
        await db.commit()
        raise Unauthorized("session_ended", "Please log in again.")
    staff = await db.get(StaffUser, sess.staff_id)
    if not staff or staff.status != "active":
        raise Unauthorized("account_disabled", "This account is turned off.")
    new = random_token()
    sess.refresh_token_hash = digest(new)
    sess.last_used_at = now()
    return _session_out(staff, sess, new)


async def logout(db: AsyncSession, session_id: uuid.UUID) -> None:
    sess = await db.get(StaffSession, session_id)
    if sess and not sess.revoked_at:
        sess.revoked_at = now()
        await audit.record(
            db, "staff.logout", staff_id=sess.staff_id, target_type="staff", target_id=sess.staff_id
        )


async def get_by_email(db: AsyncSession, email: str) -> StaffUser:
    staff = (
        await db.execute(select(StaffUser).where(StaffUser.email == email.strip().lower()))
    ).scalar_one_or_none()
    if not staff:
        raise NotFound("staff_not_found", "No staff account has this email.")
    return staff


# ---- first super admin --------------------------------------------------------------------------------
async def bootstrap() -> None:
    """On start-up: KN_ADMIN_EMAIL becomes the first super admin while there is none, and until that
    person has finished setting up, a setup link is written to the log on every start."""
    s = get_settings()
    if not s.admin_email:
        return
    async with SessionLocal() as db:
        email = s.admin_email.strip().lower()
        staff = (await db.execute(select(StaffUser).where(StaffUser.email == email))).scalar_one_or_none()
        if staff is None:
            supers = await db.scalar(select(func.count()).where(StaffUser.role == "super_admin"))
            if supers:
                return
            staff, link = await invite(db, email=email, name=s.admin_name, role="super_admin")
        elif staff.status == "invited" and staff.role == "super_admin":
            link = setup_link(staff)  # the API sleeps and restarts; earlier links keep working
        else:
            return
        await db.commit()
    log.warning("Admin panel setup link for %s (works for 72 hours, once): %s", email, link)
