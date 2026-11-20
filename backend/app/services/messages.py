"""A39 Message templates: the texts customers get with the report and rating links, editable by
KaamNishaan staff in the admin panel.

Defaults live in report_labels.LABELS (5 languages). Staff changes are saved in platform_settings
("message_templates") over the defaults; a language can also just be marked as checked. Placeholders are
written {{company}}; only the ones listed for a template can be used. SMS and WhatsApp always end with the
STOP line, added here so it can't be removed by mistake.
"""

import re
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.services import platform
from app.services.report_labels import LABELS

LANGS = ("en", "hi", "gu", "es", "fr")
KEY = "message_templates"

# template -> channels it is sent on, the placeholders it may use, and its default texts (LABELS keys)
TEMPLATES: dict[str, dict] = {
    "report_review": {
        "channels": ("sms", "whatsapp", "email"),
        "vars": ("company", "customer", "job", "report_number", "link", "expires"),
        "sms": "review_sms", "subject": "email_subject", "body": ("email_body", "review_email"),
    },
    "review_reminder": {
        "channels": ("sms", "whatsapp", "email"),
        "vars": ("company", "customer", "job", "report_number", "link"),
        "sms": "review_reminder", "subject": "email_subject", "body": ("review_reminder",),
    },
    "day5_sms": {
        "channels": ("sms",),
        "vars": ("company", "customer", "job", "report_number", "link"),
        "sms": "day5_sms",
    },
    "report_link": {
        "channels": ("sms", "whatsapp", "email"),
        "vars": ("company", "customer", "job", "report_number", "link", "expires"),
        "sms": "sms", "subject": "email_subject", "body": ("email_body",),
    },
}  # fmt: skip
EMAIL_ONLY_VARS = ("expires",)  # the link's end date is only in emails
PLACEHOLDER = re.compile(r"\{\{\s*(\w+)\s*\}\}")
RENAME = {"name": "customer", "number": "report_number"}


def _double(text: str) -> str:
    """LABELS use {company}; templates show {{company}} (and the clearer names in RENAME)."""
    return re.sub(r"\{(\w+)\}", lambda m: "{{" + RENAME.get(m.group(1), m.group(1)) + "}}", text)


def default(template: str, channel: str, lang: str) -> dict[str, str]:
    t = TEMPLATES[template]
    labels = LABELS.get(lang, LABELS["en"])
    if channel == "email":
        body = "\n\n".join(labels.get(k) or LABELS["en"][k] for k in t["body"])
        return {"subject": _double(labels["email_subject"]), "body": _double(body)}
    return {"text": _double(labels.get(t["sms"]) or LABELS["en"][t["sms"]])}


def stop_line(lang: str) -> str:
    return LABELS.get(lang, LABELS["en"])["stop"]


async def load(db: AsyncSession) -> dict:
    return await platform._get(db, KEY)


def saved(store: dict, template: str, channel: str, lang: str) -> dict:
    return store.get(template, {}).get(channel, {}).get(lang, {})


def current(store: dict, template: str, channel: str, lang: str) -> dict[str, str]:
    """The text in use: staff's version when there is one, else the default."""
    d = default(template, channel, lang)
    s = saved(store, template, channel, lang)
    return {k: s.get(k, v) for k, v in d.items()}


def fill(text: str, **values: object) -> str:
    out = PLACEHOLDER.sub(lambda m: str(values.get(m.group(1), "")), text)
    return re.sub(r"[ \t]+([,.])", r"\1", out).strip()  # "Hello ," when the name is missing


def render(store: dict, template: str, channel: str, lang: str, **values: object) -> dict[str, str]:
    """Ready to send: {"text"} for SMS and WhatsApp (with the STOP line), {"subject", "body"} for email."""
    c = current(store, template, channel, lang)
    if channel == "email":
        return {"subject": fill(c["subject"], **values), "body": fill(c["body"], **values)}
    return {"text": f"{fill(c['text'], **values)} {stop_line(lang)}"}


def problems(template: str, channel: str, parts: dict[str, str]) -> dict[str, str]:
    """Field errors for a staff edit: unknown placeholders, a missing {{link}}, too long."""
    allowed = set(TEMPLATES[template]["vars"])
    if channel != "email":
        allowed -= set(EMAIL_ONLY_VARS)
    limits = {"text": 600, "subject": 150, "body": 3000}
    errors: dict[str, str] = {}
    for field, value in parts.items():
        if not value.strip():
            errors[field] = "required"
        elif len(value) > limits[field]:
            errors[field] = "too_long"
        elif {m.group(1) for m in PLACEHOLDER.finditer(value)} - allowed:
            errors[field] = "unknown_placeholder"
        elif field == "text" and re.search(r"\bSTOP\b", value):
            errors[field] = "stop_added_automatically"
    main = "body" if channel == "email" else "text"
    if main not in errors and "{{link}}" not in re.sub(
        r"\{\{\s*link\s*\}\}", "{{link}}", parts.get(main, "")
    ):
        errors[main] = "needs_link"
    return errors


async def save(
    db: AsyncSession, template: str, channel: str, lang: str, parts: dict[str, str] | None, *,
    staff_id: uuid.UUID,
) -> None:  # fmt: skip
    """parts=None marks the current text as checked; {} goes back to the default (not checked)."""
    store = await load(db)
    slot = store.setdefault(template, {}).setdefault(channel, {})
    if parts is None:
        slot[lang] = {**slot.get(lang, {}), "checked": True}
    elif parts == {}:
        slot.pop(lang, None)
    else:
        slot[lang] = {**parts, "checked": True}
    await platform._put(db, KEY, store, staff_id)


def checked(store: dict, template: str, channel: str, lang: str) -> bool:
    """English defaults are checked; other languages need a native speaker's look (or staff's edit)."""
    s = saved(store, template, channel, lang)
    return bool(s.get("checked")) or (lang == "en" and not s)
