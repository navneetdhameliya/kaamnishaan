"""Testing only: read the SMS, WhatsApp messages and emails the console providers "sent".

Mounted when KN_ENV is local or test, and on a test server (staging) only when KN_TEST_OUTBOX_KEY is
set; there the key must be sent as the X-Outbox-Key header or ?key=. Never on production.
"""

import hmac

from fastapi import APIRouter, Depends, Header, Query

from app.core.config import get_settings
from app.core.errors import Forbidden
from app.providers.messaging import outbox


def _key(x_outbox_key: str | None = Header(default=None), key: str | None = Query(default=None)) -> None:
    s = get_settings()
    if s.env in ("local", "test"):
        return
    given = x_outbox_key or key or ""
    if not s.test_outbox_key or not hmac.compare_digest(given, s.test_outbox_key.get_secret_value()):
        raise Forbidden("forbidden", "The test outbox key is missing or wrong.")


router = APIRouter(prefix="/dev", tags=["dev (test servers only)"], dependencies=[Depends(_key)])


@router.get("/outbox")
async def read_outbox(limit: int = 10) -> dict:
    """Latest SMS (login codes, invites, report links), WhatsApp and emails, newest first."""
    return {
        "sms": list(reversed(outbox.sms))[:limit],
        "whatsapp": list(reversed(outbox.whatsapp))[:limit],
        "email": list(reversed(outbox.email))[:limit],
    }
