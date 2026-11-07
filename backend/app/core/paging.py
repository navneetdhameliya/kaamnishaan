"""Cursor paging for app lists (infinite scroll) and If-Match version checks for edits."""

import base64
import json

from app.core.errors import AppError, Conflict

MAX_LIMIT = 100


def encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(json.dumps({"o": offset}).encode()).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> int:
    if not cursor:
        return 0
    try:
        pad = "=" * (-len(cursor) % 4)
        return int(json.loads(base64.urlsafe_b64decode(cursor + pad))["o"])
    except (ValueError, KeyError, json.JSONDecodeError) as e:
        raise AppError(
            "validation_error", "This list position is not valid.", fields={"cursor": "invalid"}
        ) from e


def next_cursor(offset: int, limit: int, got: int) -> str | None:
    return encode_cursor(offset + limit) if got > limit else None


def check_version(if_match: str | None, current: int, server_copy) -> None:
    """If-Match is optional; when sent it must equal the current version."""
    if if_match is None:
        return
    try:
        sent = int(if_match.strip().strip('"').removeprefix("W/").strip('"'))
    except ValueError as e:
        raise AppError("validation_error", "If-Match must be a version number.") from e
    if sent != current:
        raise Conflict(
            "version_conflict",
            "Someone changed this while you were editing. Here is the latest copy.",
            {"version": current, "server": server_copy.model_dump(mode="json")},
        )
