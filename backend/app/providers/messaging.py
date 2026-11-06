"""SMS and email senders behind one small interface.

`console` providers (local/test) keep an in-memory outbox and log instead of sending.
MSG91 (SMS, DLT templates) and the email provider are added when the accounts exist.
"""

import logging
from dataclasses import dataclass, field

from app.core.config import get_settings

log = logging.getLogger("kn.messaging")


@dataclass
class Outbox:
    sms: list[dict] = field(default_factory=list)
    email: list[dict] = field(default_factory=list)

    def clear(self) -> None:
        self.sms.clear()
        self.email.clear()


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
