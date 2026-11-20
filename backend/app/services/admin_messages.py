"""A39 Message templates in the admin panel: read, edit, mark as checked, reset and test."""

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import normalize_phone
from app.providers import messaging
from app.schemas.admin_messages import (
    AdminTemplate,
    AdminTemplateIn,
    AdminTemplatesOut,
    AdminTemplateTest,
    AdminTemplateTestOut,
    AdminTemplateText,
)
from app.services import audit, messages
from app.services.sharing import email_on, make_token

RATING = ("report_review", "review_reminder", "day5_sms")  # their link opens on the rating


def sample(key: str) -> dict[str, str]:
    """What the preview and the test message are filled with; the link is as long as a real one."""
    link = f"{get_settings().web_url.rstrip('/')}/r/{make_token(uuid.UUID(int=42))}"
    return {
        "company": "BrightAir Services", "customer": "Anita Rao", "job": "AC service",
        "report_number": "R-1042", "expires": "20 Dec 2026",
        "link": f"{link}?rate=1" if key in RATING else link,
    }  # fmt: skip


def _entry(store: dict, key: str) -> AdminTemplate:
    t = messages.TEMPLATES[key]
    texts = []
    for ch in t["channels"]:
        for lang in messages.LANGS:
            c = messages.current(store, key, ch, lang)
            mine = messages.saved(store, key, ch, lang)
            texts.append(
                AdminTemplateText(
                    channel=ch, language=lang, text=c.get("text"), subject=c.get("subject"),
                    body=c.get("body"), edited=any(k in mine for k in ("text", "subject", "body")),
                    checked=messages.checked(store, key, ch, lang),
                )
            )  # fmt: skip
    return AdminTemplate(
        key=key, channels=list(t["channels"]), placeholders=list(t["vars"]), sample=sample(key),
        email_only=[v for v in messages.EMAIL_ONLY_VARS if v in t["vars"]], texts=texts,
    )  # fmt: skip


async def templates(db: AsyncSession, *, can_act: bool) -> AdminTemplatesOut:
    s = get_settings()
    store = await messages.load(db)
    return AdminTemplatesOut(
        templates=[_entry(store, k) for k in messages.TEMPLATES],
        stop={lang: messages.stop_line(lang) for lang in messages.LANGS},
        sms_live=s.sms_provider != "console", whatsapp_live=s.whatsapp_provider != "console",
        email_live=await email_on(db), can_act=can_act,
    )  # fmt: skip


def _parts(key: str, channel: str, body: AdminTemplateIn) -> dict[str, str]:
    if channel not in messages.TEMPLATES[key]["channels"]:
        raise AppError("not_found", "This template isn't sent on that channel.", status=404)
    parts = (
        {"subject": body.subject or "", "body": body.body or ""}
        if channel == "email"
        else {"text": body.text or ""}
    )
    errors = messages.problems(key, channel, parts)
    if errors:
        raise AppError("validation_error", "Some fields are not valid.", fields=errors, status=422)
    return {k: v.strip() for k, v in parts.items()}


async def save(
    db: AsyncSession, key: str, channel: str, lang: str, body: AdminTemplateIn, *, staff_id: uuid.UUID,
    ip: str | None,
) -> AdminTemplate:  # fmt: skip
    parts = _parts(key, channel, body)
    await messages.save(db, key, channel, lang, parts, staff_id=staff_id)
    await audit.record(db, "staff.template_updated", staff_id=staff_id, target_type="message_template",
                       data={"template": key, "channel": channel, "language": lang}, ip=ip)  # fmt: skip
    return _entry(await messages.load(db), key)


async def mark(
    db: AsyncSession, key: str, channel: str, lang: str, *, reset: bool, staff_id: uuid.UUID, ip: str | None
) -> AdminTemplate:
    if channel not in messages.TEMPLATES[key]["channels"]:
        raise AppError("not_found", "This template isn't sent on that channel.", status=404)
    await messages.save(db, key, channel, lang, {} if reset else None, staff_id=staff_id)
    action = "staff.template_reset" if reset else "staff.template_checked"
    await audit.record(db, action, staff_id=staff_id, target_type="message_template",
                       data={"template": key, "channel": channel, "language": lang}, ip=ip)  # fmt: skip
    return _entry(await messages.load(db), key)


async def test(db: AsyncSession, body: AdminTemplateTest, *, staff_id: uuid.UUID) -> AdminTemplateTestOut:
    """Sends the text being edited (or the saved one) with sample values to staff's own phone or email."""
    s = get_settings()
    has_draft = body.text or body.subject or body.body
    parts = _parts(body.template, body.channel, body) if has_draft else None
    store = await messages.load(db)
    if parts:
        store = {body.template: {body.channel: {body.language: parts}}}
    out = messages.render(store, body.template, body.channel, body.language, **sample(body.template))
    if body.channel == "email":
        to = body.to.strip().lower()
        if "@" not in to:
            raise AppError(
                "validation_error", "Some fields are not valid.", fields={"to": "invalid"}, status=422
            )
        live = await email_on(db)
        if live:
            await messaging.send_email_text(to, "template_test", f"[Test] {out['subject']}", out["body"])
    else:
        try:
            to = normalize_phone(body.to, "IN")
        except AppError:
            raise AppError("validation_error", "Some fields are not valid.", fields={"to": "invalid"},
                           status=422) from None  # fmt: skip
        live = (s.sms_provider if body.channel == "sms" else s.whatsapp_provider) != "console"
        if live:
            send = messaging.send_sms_text if body.channel == "sms" else messaging.send_whatsapp_text
            await send(to, "template_test", out["text"])
    return AdminTemplateTestOut(
        sent=live, to=to, text=out.get("text"), subject=out.get("subject"), body=out.get("body")
    )
