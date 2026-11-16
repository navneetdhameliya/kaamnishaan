"""Local testing only: read the SMS, WhatsApp messages and emails the console providers "sent".

Mounted only when KN_ENV is local or test, never on staging or production.
"""

from fastapi import APIRouter

from app.providers.messaging import outbox

router = APIRouter(prefix="/dev", tags=["dev (local only)"])


@router.get("/outbox")
async def read_outbox(limit: int = 10) -> dict:
    """Latest SMS (login codes, invites, report links), WhatsApp and emails, newest first."""
    return {
        "sms": list(reversed(outbox.sms))[:limit],
        "whatsapp": list(reversed(outbox.whatsapp))[:limit],
        "email": list(reversed(outbox.email))[:limit],
    }
