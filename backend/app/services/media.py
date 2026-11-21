"""Pictures staff upload for the website (blog covers and pictures, testimonial photos).

They live in storage under site/…; the website shows them through GET /public/media/{key}, which
redirects to a short-lived signed link, so the address saved in a post never expires.
"""

import uuid

from app.core.config import get_settings
from app.core.errors import AppError
from app.providers.storage import get_storage

MAX_BYTES = 3 * 1024 * 1024
KINDS = ("blog", "people", "reference")
TYPES = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _sniff(data: bytes) -> str | None:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


async def upload(kind: str, data: bytes) -> str:
    if kind not in KINDS:
        raise AppError("validation_error", "Unknown picture kind.", fields={"kind": "unknown"})
    if not data:
        raise AppError("validation_error", "The file is empty.", fields={"file": "empty"})
    if len(data) > MAX_BYTES:
        raise AppError("file_too_large", "Pictures can be at most 3 MB.", fields={"file": "too_large"})
    ctype = _sniff(data)
    if not ctype:
        raise AppError("validation_error", "Use a JPG, PNG or WebP picture.", fields={"file": "type"})
    key = f"site/{kind}/{uuid.uuid4()}.{TYPES[ctype]}"
    await get_storage().write(key, data, ctype)
    return key


def is_key(value: str) -> bool:
    return value.startswith("site/") and ".." not in value


def url(value: str | None, *, absolute: bool = False) -> str | None:
    """A website picture stays as it is ("/img/x.webp", or with the website's address for the admin
    panel); an uploaded one goes through the API."""
    if not value:
        return None
    if is_key(value):
        return f"{get_settings().api_url.rstrip('/')}/api/v1/public/media/{value}"
    return f"{get_settings().web_url.rstrip('/')}{value}" if absolute else value


def check_picture(value: str, field: str) -> str:
    if (value.startswith("/img/") and ".." not in value) or is_key(value):
        return value
    raise AppError(
        "validation_error", "Pick a picture from the website or upload one.", fields={field: "picture"}
    )
