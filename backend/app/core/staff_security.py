"""Admin panel security: authenticator codes (TOTP, RFC 6238), recovery codes, staff tokens.

The authenticator secret has to be read back to check codes, so it is stored encrypted with a key made
from KN_SECRET_KEY (never in plain text). Changing KN_SECRET_KEY means every staff member sets up again.
"""

import base64
import hashlib
import hmac
import secrets
import struct
import uuid
from datetime import timedelta
from typing import Any
from urllib.parse import quote

import jwt
from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_settings
from app.core.errors import Unauthorized
from app.core.security import digest, now

STAFF_ACCESS_TTL = timedelta(minutes=15)
STAFF_SESSION_TTL = timedelta(hours=12)  # a staff login lasts one working day at most
SETUP_LINK_TTL = timedelta(hours=72)
TOTP_PERIOD = 30
RECOVERY_CODES = 8
_ISSUER = "KaamNishaan Admin"
_ALG = "HS256"


def _key() -> str:
    return get_settings().secret_key.get_secret_value()


# ---- encrypting the authenticator secret ------------------------------------------------------------
def _fernet() -> Fernet:
    raw = hashlib.sha256(b"kn-staff-totp:" + _key().encode()).digest()
    return Fernet(base64.urlsafe_b64encode(raw))


def seal(value: str) -> str:
    return _fernet().encrypt(value.encode()).decode()


def unseal(value: str) -> str | None:
    try:
        return _fernet().decrypt(value.encode()).decode()
    except InvalidToken:
        return None


# ---- authenticator codes ----------------------------------------------------------------------------
def new_totp_secret() -> str:
    """160-bit base32 secret, what Google Authenticator, Microsoft Authenticator and 1Password expect."""
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def totp_code(secret: str, step: int) -> str:
    key = base64.b32decode(secret + "=" * (-len(secret) % 8))
    mac = hmac.new(key, struct.pack(">Q", step), hashlib.sha1).digest()
    offset = mac[-1] & 0x0F
    number = struct.unpack(">I", mac[offset : offset + 4])[0] & 0x7FFFFFFF
    return f"{number % 1_000_000:06d}"


def current_step() -> int:
    return int(now().timestamp()) // TOTP_PERIOD


def match_totp(secret: str, code: str, last_step: int | None) -> int | None:
    """The time step the code belongs to (one step either side for clock drift), or None.
    A step at or before the last one used is refused, so a seen code can't be used again."""
    code = code.strip().replace(" ", "")
    if len(code) != 6 or not code.isdigit():
        return None
    step = current_step()
    for s in (step - 1, step, step + 1):
        if (last_step is None or s > last_step) and hmac.compare_digest(totp_code(secret, s), code):
            return s
    return None


def otpauth_uri(secret: str, email: str) -> str:
    """What the setup page turns into a QR code."""
    label = quote(f"{_ISSUER}:{email}")
    return f"otpauth://totp/{label}?secret={secret}&issuer={quote(_ISSUER)}&digits=6&period={TOTP_PERIOD}"


# ---- recovery codes (for a lost phone) --------------------------------------------------------------
def new_recovery_codes() -> list[str]:
    """Eight one-time codes like 7f3a-91c0, shown once; only their keyed hashes are stored."""
    return [f"{secrets.token_hex(2)}-{secrets.token_hex(2)}" for _ in range(RECOVERY_CODES)]


def recovery_digest(code: str) -> str:
    return digest("staff-recovery:" + code.strip().lower().replace(" ", ""))


# ---- tokens -----------------------------------------------------------------------------------------
def create_staff_token(*, staff_id: uuid.UUID, session_id: uuid.UUID) -> str:
    t = now()
    claims = {
        "sub": str(staff_id),
        "sid": str(session_id),
        "typ": "staff",
        "iat": int(t.timestamp()),
        "exp": int((t + STAFF_ACCESS_TTL).timestamp()),
    }
    return jwt.encode(claims, _key(), algorithm=_ALG)


def decode_staff_token(token: str) -> dict[str, Any]:
    try:
        claims = jwt.decode(token, _key(), algorithms=[_ALG])
    except jwt.ExpiredSignatureError as e:
        raise Unauthorized("token_expired", "Please log in again.") from e
    except jwt.InvalidTokenError as e:
        raise Unauthorized("invalid_token", "Please log in again.") from e
    if claims.get("typ") != "staff":  # an app user's token never opens the admin panel
        raise Unauthorized("invalid_token", "Please log in again.")
    return claims
