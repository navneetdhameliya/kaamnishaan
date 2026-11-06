"""Request dependencies: database session and the signed-in principal."""

import uuid
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass, field

from fastapi import Depends, Header, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.core.errors import Forbidden, Unauthorized
from app.core.permissions import permissions_for
from app.core.security import decode_access_token, now
from app.models import AuthSession, Company, Membership, User


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
    def company_id(self) -> uuid.UUID:
        if not self.company:
            raise Forbidden("no_company", "Choose a company first.")
        return self.company.id

    def require(self, permission: str) -> None:
        if permission not in self.permissions:
            raise Forbidden("forbidden", "You don't have permission to do this.", {"needs": permission})


async def get_principal(
    request: Request, authorization: str | None = Header(default=None), db: AsyncSession = Depends(get_db)
) -> Principal:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise Unauthorized("not_signed_in", "Please sign in.")
    claims = decode_access_token(authorization.split(" ", 1)[1])
    sess = await db.get(AuthSession, uuid.UUID(claims["sid"]))
    if not sess or sess.revoked_at or sess.expires_at < now():
        raise Unauthorized("session_ended", "Please sign in again.")
    user = await db.get(User, uuid.UUID(claims["sub"]))
    if not user or user.status == "disabled":
        raise Unauthorized("account_disabled", "This account is turned off.")
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
