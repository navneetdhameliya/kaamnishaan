"""Passwords, tokens, one-time codes. Nothing secret is ever stored in plain text."""

import hashlib
import hmac
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
import phonenumbers
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.config import get_settings
from app.core.errors import AppError, Gone, Unauthorized

ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=60)
_ph = PasswordHasher()
_ALG = "HS256"


def now() -> datetime:
    return datetime.now(UTC)


def _key() -> str:
    return get_settings().secret_key.get_secret_value()


# ---- passwords -----------------------------------------------------------------
def hash_password(raw: str) -> str:
    return _ph.hash(raw)


def verify_password(raw: str, hashed: str | None) -> bool:
    if not hashed:
        return False
    try:
        return _ph.verify(hashed, raw)
    except (VerificationError, InvalidHashError):
        return False


# ---- hashing of short secrets (OTP codes, refresh secrets, link tokens) ----------
def digest(value: str) -> str:
    """Keyed hash so a leaked database can't be brute-forced offline."""
    return hmac.new(_key().encode(), value.encode(), hashlib.sha256).hexdigest()


def random_token(nbytes: int = 32) -> str:
    return secrets.token_urlsafe(nbytes)


def otp_code() -> str:
    return f"{secrets.randbelow(10_000):04d}"


# ---- phone numbers ----------------------------------------------------------------
def normalize_phone(raw: str, default_region: str = "IN") -> str:
    """Return E.164 (+919876543210) or raise invalid_phone."""
    try:
        num = phonenumbers.parse(raw, default_region)
    except phonenumbers.NumberParseException as e:
        raise AppError("invalid_phone", "This phone number doesn't look right.") from e
    if not phonenumbers.is_valid_number(num):
        raise AppError("invalid_phone", "This phone number doesn't look right.")
    return phonenumbers.format_number(num, phonenumbers.PhoneNumberFormat.E164)


# ---- JWT access tokens ------------------------------------------------------------
def create_access_token(
    *, user_id: uuid.UUID, session_id: uuid.UUID, company_id: uuid.UUID | None, role: str | None
) -> str:
    t = now()
    claims = {
        "sub": str(user_id),
        "sid": str(session_id),
        "cid": str(company_id) if company_id else None,
        "role": role,
        "typ": "access",
        "iat": int(t.timestamp()),
        "exp": int((t + ACCESS_TTL).timestamp()),
    }
    return jwt.encode(claims, _key(), algorithm=_ALG)


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        claims = jwt.decode(token, _key(), algorithms=[_ALG])
    except jwt.ExpiredSignatureError as e:
        raise Unauthorized("token_expired", "Please sign in again.") from e
    except jwt.InvalidTokenError as e:
        raise Unauthorized("invalid_token", "Please sign in again.") from e
    if claims.get("typ") != "access":
        raise Unauthorized("invalid_token", "Please sign in again.")
    return claims


# ---- signed one-purpose links (email verification, password reset) ------------------
def create_link_token(purpose: str, subject: str, ttl: timedelta, fingerprint: str = "") -> str:
    t = now()
    return jwt.encode(
        {"typ": purpose, "sub": subject, "fp": fingerprint, "exp": int((t + ttl).timestamp())}, _key(), _ALG
    )


def read_link_token(token: str, purpose: str) -> dict[str, Any]:
    try:
        claims = jwt.decode(token, _key(), algorithms=[_ALG])
    except jwt.ExpiredSignatureError as e:
        raise Gone("link_expired", "This link has expired.") from e
    except jwt.InvalidTokenError as e:
        raise Gone("link_invalid", "This link is not valid.") from e
    if claims.get("typ") != purpose:
        raise Gone("link_invalid", "This link is not valid.")
    return claims


def password_fingerprint(password_hash: str | None) -> str:
    """Changes whenever the password changes, so old reset links stop working."""
    return hashlib.sha256((password_hash or "").encode()).hexdigest()[:16]
