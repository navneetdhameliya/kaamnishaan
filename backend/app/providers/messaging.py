"""SMS, WhatsApp and email senders behind one small interface.

`console` providers (local/test) keep an in-memory outbox and log instead of sending.
MSG91 (SMS, DLT templates), WhatsApp Business and the email provider are added when the accounts exist.
"""

import logging
from collections import deque
from dataclasses import dataclass, field

from app.core.config import get_settings

log = logging.getLogger("kn.messaging")


OUTBOX_SIZE = 200  # a test server keeps only the latest messages in memory


def _box() -> deque:
    return deque(maxlen=OUTBOX_SIZE)


@dataclass
class Outbox:
    sms: deque = field(default_factory=_box)
    email: deque = field(default_factory=_box)
    whatsapp: deque = field(default_factory=_box)

    def clear(self) -> None:
        self.sms.clear()
        self.email.clear()
        self.whatsapp.clear()


outbox = Outbox()


# DLT needs a registered template per message type; ids come from settings later.
SMS_TEMPLATES = {
    "otp": "Your KaamNishaan code is {code}. It works for 10 minutes. Do not share it. -KaamNishaan",
    "invite": "{inviter} invited you to join {company} on KaamNishaan. Open: {link} -KaamNishaan",
}


async def send_sms(to: str, template: str, **params: str) -> None:
    body = SMS_TEMPLATES[template].format(**params)
    provider = get_settings().sms_provider
    if provider == "console":
        outbox.sms.append({"to": to, "template": template, "body": body, "params": params})
        log.warning("SMS (not really sent) to %s: %s", to, body)
        return
    raise NotImplementedError(f"SMS provider {provider} is added in a later step")


async def send_email(to: str, template: str, subject: str, **params: str) -> None:
    outbox.email.append({"to": to, "template": template, "subject": subject, "params": params})
    log.warning("Email (not really sent) to %s: %s %s", to, subject, params)


async def send_sms_text(to: str, template: str, body: str) -> str | None:
    """A message already written in the customer's language (report links). Returns the provider id."""
    provider = get_settings().sms_provider
    if provider == "console":
        outbox.sms.append({"to": to, "template": template, "body": body, "params": {}})
        log.warning("SMS (not really sent) to %s: %s", to, body)
        return None
    raise NotImplementedError(f"SMS provider {provider} is added in a later step")


async def send_whatsapp_text(to: str, template: str, body: str) -> str | None:
    provider = get_settings().whatsapp_provider
    if provider == "console":
        outbox.whatsapp.append({"to": to, "template": template, "body": body})
        log.warning("WhatsApp (not really sent) to %s: %s", to, body)
        return None
    raise NotImplementedError(f"WhatsApp provider {provider} is added when the account exists")


async def send_email_text(to: str, template: str, subject: str, body: str) -> str | None:
    outbox.email.append({"to": to, "template": template, "subject": subject, "body": body, "params": {}})
    log.warning("Email (not really sent) to %s: %s", to, subject)
    return None
