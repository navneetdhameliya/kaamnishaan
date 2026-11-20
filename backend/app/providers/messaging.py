"""SMS, WhatsApp and email senders behind one small interface.

`console` providers (local/test) keep an in-memory outbox and log instead of sending.
Email goes out by SMTP once staff connect an email service in the admin panel (A33 Email settings);
MSG91 (SMS, DLT templates) and WhatsApp Business are added when the accounts exist.
"""

import asyncio
import logging
import smtplib
import ssl
from collections import deque
from dataclasses import dataclass, field
from email.message import EmailMessage
from email.utils import formataddr, make_msgid

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


EMAIL_BODIES = {
    "verify_email": "Hello {name},\n\nPlease confirm your email for KaamNishaan: {link}\n\n"
    "If you didn't sign up, you can ignore this email.",
    "reset_password": "Hello {name},\n\nReset your KaamNishaan password here: {link}\n"
    "The link works for 30 minutes.\n\nIf you didn't ask for this, you can ignore this email.",
}


@dataclass
class Smtp:
    host: str
    port: int
    security: str  # starttls or ssl
    username: str | None
    password: str | None
    from_name: str
    from_email: str


def unseal_password(sealed: str | None) -> str | None:
    from app.core.staff_security import unseal

    return unseal(sealed) if sealed else None


async def _smtp() -> Smtp | None:
    """The connected email service, or None (then emails are only logged)."""
    from app.core.db import SessionLocal
    from app.core.staff_security import unseal
    from app.services import platform

    async with SessionLocal() as db:
        cfg = await platform.email_config(db)
    if not (cfg.enabled and cfg.ready):
        return None
    return Smtp(
        host=cfg.host, port=cfg.port, security=cfg.security, username=cfg.username,
        password=unseal(cfg.password_sealed) if cfg.password_sealed else None,
        from_name=cfg.from_name, from_email=cfg.from_email,
    )  # fmt: skip


def _deliver_smtp(smtp: Smtp, to: str, subject: str, body: str) -> str:
    msg = EmailMessage()
    msg["From"] = formataddr((smtp.from_name, smtp.from_email))
    msg["To"] = to
    msg["Subject"] = subject
    msg["Message-ID"] = make_msgid(domain=smtp.from_email.split("@")[-1])
    msg.set_content(body)
    ctx = ssl.create_default_context()
    if smtp.security == "ssl":
        server = smtplib.SMTP_SSL(smtp.host, smtp.port, timeout=20, context=ctx)
    else:
        server = smtplib.SMTP(smtp.host, smtp.port, timeout=20)
    with server:
        if smtp.security == "starttls":
            server.starttls(context=ctx)
        if smtp.username:
            server.login(smtp.username, smtp.password or "")
        server.send_message(msg)
    return msg["Message-ID"]


async def send_smtp(smtp: Smtp, to: str, subject: str, body: str) -> str:
    return await asyncio.to_thread(_deliver_smtp, smtp, to, subject, body)


async def send_email(to: str, template: str, subject: str, **params: str) -> None:
    smtp = await _smtp()
    if smtp and template in EMAIL_BODIES:
        await send_smtp(smtp, to, subject, EMAIL_BODIES[template].format(**params))
        return
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
    smtp = await _smtp()
    if smtp:
        return await send_smtp(smtp, to, subject, body)
    outbox.email.append({"to": to, "template": template, "subject": subject, "body": body, "params": {}})
    log.warning("Email (not really sent) to %s: %s", to, subject)
    return None
