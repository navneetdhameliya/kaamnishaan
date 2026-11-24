"""Request dependencies: database session and the signed-in principal."""

import uuid
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass, field

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.core.errors import Forbidden, Unauthorized
from app.core.permissions import permissions_for
from app.core.security import decode_access_token, now
from app.core.staff_security import decode_staff_token
from app.models import AuthSession, Company, Membership, StaffSession, StaffUser, User

# Shows the "Authorize" button on /docs; we raise our own error shape when the token is missing.
bearer = HTTPBearer(
    auto_error=False, description="Access token from /auth/otp/verify, /auth/login or /auth/refresh"
)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


@dataclass
class Principal:
    user: User
    session_id: uuid.UUID
    company: Company | None = None
    membership: Membership | None = None
    permissions: set[str] = field(default_factory=set)

    @property
    def role(self) -> str | None:
        return self.membership.role if self.membership else None

    @property
    def suspended(self) -> bool:
        return bool(self.company and self.company.status == "suspended")

    def _check_suspended(self) -> None:
        # A07: a company paused by KaamNishaan can't do any work; /me still shows it so the app can explain
        if self.suspended:
            raise Forbidden(
                "company_suspended",
                "This company is paused by KaamNishaan. Your data is kept. Contact support to restart it.",
                {"company": self.company.name},
            )

    @property
    def company_id(self) -> uuid.UUID:
        if not self.company:
            raise Forbidden("no_company", "Choose a company first.")
        self._check_suspended()
        return self.company.id

    def require(self, permission: str) -> None:
        self._check_suspended()
        if permission not in self.permissions:
            raise Forbidden("forbidden", "You don't have permission to do this.", {"needs": permission})


PLATFORMS = {"android", "ios", "ipados", "macos", "web"}


def _note_device(request: Request, sess: AuthSession) -> None:
    """Signed-in devices show the platform and app version the app sends (D-146); written when they change."""
    platform = (request.headers.get("x-platform") or "").lower()
    version = (request.headers.get("x-app-version") or "")[:32] or None
    if platform in PLATFORMS and sess.platform != platform:
        sess.platform = platform
    if version and sess.app_version != version:
        sess.app_version = version


async def get_principal(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> Principal:
    if not creds or creds.scheme.lower() != "bearer":
        raise Unauthorized("not_signed_in", "Please sign in.")
    claims = decode_access_token(creds.credentials)
    sess = await db.get(AuthSession, uuid.UUID(claims["sid"]))
    if not sess or sess.revoked_at or sess.expires_at < now():
        raise Unauthorized("session_ended", "Please sign in again.")
    user = await db.get(User, uuid.UUID(claims["sub"]))
    if not user or user.status == "disabled":
        raise Unauthorized("account_disabled", "This account is turned off.")
    _note_device(request, sess)
    p = Principal(user=user, session_id=sess.id)
    if claims.get("cid"):
        # role comes from the database, not the token, so changes apply immediately
        row = (
            await db.execute(
                select(Membership, Company)
                .join(Company, Company.id == Membership.company_id)
                .where(
                    Membership.user_id == user.id,
                    Membership.company_id == uuid.UUID(claims["cid"]),
                    Membership.status == "active",
                )
            )
        ).first()
        if row:
            p.membership, p.company = row
            p.permissions = permissions_for(p.membership.role, p.company.settings)
    request.state.principal = p
    return p


def requires(permission: str) -> Callable:
    async def _dep(p: Principal = Depends(get_principal)) -> Principal:
        p.require(permission)
        return p

    return _dep


def client_ip(request: Request) -> str | None:
    fwd = request.headers.get("x-forwarded-for")
    return fwd.split(",")[0].strip() if fwd else (request.client.host if request.client else None)


# ---- admin panel (staff) ----------------------------------------------------------------------------
@dataclass
class Staff:
    staff: StaffUser
    session_id: uuid.UUID

    def require_super(self) -> None:
        if self.staff.role != "super_admin":
            raise Forbidden("forbidden", "Only a super admin can do this.")


async def get_staff(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> Staff:
    if not creds or creds.scheme.lower() != "bearer":
        raise Unauthorized("not_signed_in", "Please log in.")
    claims = decode_staff_token(creds.credentials)
    sess = await db.get(StaffSession, uuid.UUID(claims["sid"]))
    if not sess or sess.revoked_at or sess.expires_at < now():
        raise Unauthorized("session_ended", "Please log in again.")
    staff = await db.get(StaffUser, uuid.UUID(claims["sub"]))
    if not staff or staff.status != "active":
        raise Unauthorized("account_disabled", "This account is turned off.")
    return Staff(staff=staff, session_id=sess.id)
