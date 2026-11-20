"""Changing texts without a release: A24 Website content and A25 Localized content.

Built-in texts are in shared/i18n; `app/content/text_keys.json` (made by shared/i18n/build.mjs) lists
every key with its placeholders so a change can't break a sentence like "{n} reports". Website changes
(A24) are saved as drafts and go live on Publish; translation fixes (A25) go live when saved.
The app, website and admin panel fetch the live changes from GET /public/texts.
"""

import json
import re
import uuid
from datetime import timedelta
from functools import lru_cache
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, NotFound
from app.core.security import create_link_token, now, read_link_token
from app.models import StaffUser, TextOverride
from app.schemas.texts import (
    AdminPageField,
    AdminPageOut,
    AdminPageRow,
    AdminPageSection,
    AdminPagesOut,
    AdminTextChange,
    AdminTextRow,
    AdminTextsOut,
    FieldValue,
    PublicTextsOut,
)
from app.services import audit

LANGS = ("en", "hi", "gu", "es", "fr")
KEYS_FILE = Path(__file__).resolve().parent.parent / "content" / "text_keys.json"
PREVIEW_TTL = timedelta(hours=1)


@lru_cache(maxsize=1)
def text_keys() -> dict[str, str]:
    """key -> its placeholders, sorted and joined ("currency,n")."""
    return json.loads(KEYS_FILE.read_text(encoding="utf-8"))


def area_of(key: str) -> str:
    if key.startswith("admin."):
        return "admin"
    if key.startswith(("site.", "web.")):
        return "site"
    return "app"


def _placeholders(text: str) -> str:
    return ",".join(sorted(re.findall(r"\{(\w+)\}", text)))


def _check(key: str, lang: str, value: str | None, limit: int = 2000) -> str | None:
    if key not in text_keys():
        raise AppError("validation_error", "Unknown text.", fields={key: "unknown"})
    if lang not in LANGS:
        raise AppError("validation_error", "Unknown language.", fields={key: "language"})
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None  # empty = back to the built-in text
    if len(value) > limit:
        raise AppError(
            "validation_error", f"At most {limit} characters.", fields={f"{key}.{lang}": "too_long"}
        )
    if _placeholders(value) != text_keys()[key]:
        need = ", ".join("{" + p + "}" for p in text_keys()[key].split(",") if p) or "none"
        raise AppError(
            "validation_error",
            f"Keep the same {{…}} parts as the original ({need}).",
            fields={f"{key}.{lang}": "placeholders"},
        )
    return value


# ---- A24 pages ---------------------------------------------------------------------------------------
# (section, [(key, label, max length)]). Labels are translated in the admin panel (admin.wc.f.<label>).
def _hero(prefix: str, *, eyebrow: str | None = None) -> list[tuple[str, int]]:
    out = [(eyebrow, 60)] if eyebrow else []
    return out + [(f"{prefix}.title", 120), (f"{prefix}.body", 400)]


def _seo(page: str) -> tuple[str, list[tuple[str, int]]]:
    return ("seo", [(f"site.seo.{page}.title", 60), (f"site.seo.{page}.description", 160)])


def _faq(prefix: str) -> tuple[str, list[tuple[str, int]]]:
    rows = [(f"{prefix}.title", 120), (f"{prefix}.body", 300)]
    for i in range(1, 6):
        rows += [(f"{prefix}.q{i}", 160), (f"{prefix}.a{i}", 600)]
    return ("faq", rows)


INDUSTRIES = {"hvac": "hvac", "roofing": "roofing", "solar": "solar", "maintenance": "maintenance",
              "pest-control": "pest_control", "cleaning": "cleaning"}  # fmt: skip

PAGES: dict[str, dict[str, Any]] = {
    "home": {
        "path": "/",
        "sections": [
            (
                "hero",
                [
                    ("site.hero.pill", 80),
                    ("site.hero.title", 120),
                    ("site.hero.body", 400),
                    ("site.cta.trial", 30),
                    ("site.cta.demo", 30),
                ],
            ),
            ("problem", [("site.problem.title", 120), ("site.problem.body", 400)]),
            ("how", [("site.how.title", 120), ("site.how.body", 400)]),
            _faq("site.faq"),
            ("final", [("site.final.title", 120), ("site.final.body", 300)]),
            _seo("home"),
        ],  # fmt: skip
    },
    "pricing": {
        "path": "/pricing",
        "sections": [("hero", _hero("site.price")), _faq("site.pfaq"), _seo("pricing")],
    },
    "features": {
        "path": "/features",
        "sections": [("hero", _hero("site.fp.ov", eyebrow="site.fp.ov.pill")), _seo("features")],
    },
    **{
        f"industry_{key}": {
            "path": f"/industries/{slug}",
            "trade": key,
            "sections": [("hero", _hero(f"site.indp.{key}")), _seo(f"ind_{key}")],
        }
        for slug, key in INDUSTRIES.items()
    },
    "about": {
        "path": "/about",
        "sections": [
            ("hero", _hero("site.about", eyebrow="site.about.pill")),
            ("why", [("site.about.why_title", 120), ("site.about.why_body", 400)]),
            _seo("about"),
        ],
    },
    "contact": {
        "path": "/contact",
        "sections": [("hero", _hero("site.ct", eyebrow="site.ct.eyebrow")), _seo("contact")],
    },
    "demo": {"path": "/book-demo", "sections": [("hero", _hero("site.bd")), _seo("demo")]},
    "blog": {
        "path": "/blog",
        "sections": [("hero", _hero("site.blog", eyebrow="site.blog.eyebrow")), _seo("blog")],
    },
}


def _label(key: str) -> tuple[str, int | None]:
    """site.pfaq.q3 -> ("question", 3); site.hero.title -> ("headline", None)."""
    last = key.rsplit(".", 1)[1]
    if m := re.fullmatch(r"([qa])(\d)", last):
        return ("question" if m[1] == "q" else "answer", int(m[2]))
    if ".seo." in key:
        return ("seo_" + last, None)
    if key == "site.cta.trial":
        return ("primary_button", None)
    if key == "site.cta.demo":
        return ("secondary_button", None)
    if last in ("pill", "eyebrow"):
        return ("eyebrow", None)
    if last.endswith("title"):
        return ("headline", None)
    return ("subheadline", None)


def page_keys(page: str) -> dict[str, int]:
    return {k: limit for _, fields in PAGES[page]["sections"] for k, limit in fields}


async def _rows(db: AsyncSession, keys) -> dict[tuple[str, str], TextOverride]:
    rows = (await db.execute(select(TextOverride).where(TextOverride.key.in_(list(keys))))).scalars().all()
    return {(r.key, r.lang): r for r in rows}


async def pages(db: AsyncSession, *, can_act: bool) -> AdminPagesOut:
    allkeys = {k for p in PAGES for k in page_keys(p)}
    rows = await _rows(db, allkeys)
    out = []
    for page, spec in PAGES.items():
        mine = [r for (k, _), r in rows.items() if k in page_keys(page)]
        changed = [r for r in mine if r.has_draft or r.live is not None]
        out.append(
            AdminPageRow(
                page=page,
                path=spec["path"],
                trade=spec.get("trade"),
                drafts=sum(1 for r in mine if r.has_draft),
                changed=sum(1 for r in mine if r.live is not None),
                edited_at=max((r.updated_at for r in changed), default=None),
            )
        )
    return AdminPagesOut(pages=out, can_act=can_act, web_url=get_settings().web_url)


async def page(db: AsyncSession, page: str) -> AdminPageOut:
    if page not in PAGES:
        raise NotFound("not_found", "Page not found.")
    keys = page_keys(page)
    rows = await _rows(db, keys)
    who = {}
    ids = {r.updated_by for r in rows.values() if r.updated_by}
    if ids:
        who = dict(
            (await db.execute(select(StaffUser.id, StaffUser.name).where(StaffUser.id.in_(ids)))).all()
        )
    sections = []
    for name, fields in PAGES[page]["sections"]:
        out = []
        for key, limit in fields:
            label, n = _label(key)
            values = {}
            for lang in LANGS:
                r = rows.get((key, lang))
                values[lang] = FieldValue(
                    live=r.live if r else None,
                    draft=r.draft if r and r.has_draft else None,
                    has_draft=bool(r and r.has_draft),
                )
            out.append(
                AdminPageField(key=key, label=label, n=n, max=limit, multiline=limit > 160, values=values)
            )
        sections.append(AdminPageSection(key=name, fields=out))
    edited = max(rows.values(), key=lambda r: r.updated_at, default=None)
    return AdminPageOut(
        page=page,
        path=PAGES[page]["path"],
        trade=PAGES[page].get("trade"),
        sections=sections,
        drafts=sum(1 for r in rows.values() if r.has_draft),
        edited_at=edited.updated_at if edited else None,
        edited_by=who.get(edited.updated_by) if edited else None,
    )


async def _row(db: AsyncSession, key: str, lang: str) -> TextOverride:
    r = await db.get(TextOverride, (key, lang))
    if not r:
        r = TextOverride(key=key, lang=lang)
        db.add(r)
    return r


async def save_drafts(
    db: AsyncSession, page_name: str, values: dict[str, dict[str, str | None]], *, staff_id, ip
):
    if page_name not in PAGES:
        raise NotFound("not_found", "Page not found.")
    keys = page_keys(page_name)
    changed = 0
    for key, langs in values.items():
        if key not in keys:
            raise AppError("validation_error", "This text isn't on this page.", fields={key: "unknown"})
        for lang, raw in langs.items():
            value = _check(key, lang, raw, keys[key])
            r = await _row(db, key, lang)
            if value == r.live:
                if r.has_draft:  # back to what is live
                    r.has_draft, r.draft = False, None
                    changed += 1
                continue
            if r.has_draft and r.draft == value:
                continue
            r.has_draft, r.draft = True, value
            r.updated_by, r.updated_at = staff_id, now()
            changed += 1
    if changed:
        await audit.record(
            db,
            "website.draft_saved",
            staff_id=staff_id,
            target_type="website_page",
            data={"page": page_name, "texts": changed},
            ip=ip,
        )
    await db.flush()
    return await page(db, page_name)


async def publish(db: AsyncSession, page_name: str, *, staff_id, ip) -> AdminPageOut:
    if page_name not in PAGES:
        raise NotFound("not_found", "Page not found.")
    rows = await _rows(db, page_keys(page_name))
    t = now()
    done = 0
    for r in rows.values():
        if not r.has_draft:
            continue
        r.live, r.has_draft, r.draft = r.draft, False, None
        r.published_at, r.updated_at, r.updated_by = t, t, staff_id
        done += 1
    if not done:
        raise AppError("nothing_to_publish", "There are no changes to publish.")
    await audit.record(
        db,
        "website.published",
        staff_id=staff_id,
        target_type="website_page",
        data={"page": page_name, "texts": done},
        ip=ip,
    )
    await db.flush()
    return await page(db, page_name)


async def discard(db: AsyncSession, page_name: str, *, staff_id, ip) -> AdminPageOut:
    if page_name not in PAGES:
        raise NotFound("not_found", "Page not found.")
    rows = await _rows(db, page_keys(page_name))
    done = 0
    for r in rows.values():
        if r.has_draft:
            r.has_draft, r.draft = False, None
            done += 1
    if done:
        await audit.record(
            db,
            "website.discarded",
            staff_id=staff_id,
            target_type="website_page",
            data={"page": page_name, "texts": done},
            ip=ip,
        )
    await db.flush()
    return await page(db, page_name)


def preview_link(page_name: str, lang: str, staff_id: uuid.UUID) -> str:
    if page_name not in PAGES:
        raise NotFound("not_found", "Page not found.")
    token = create_link_token("site_preview", str(staff_id), PREVIEW_TTL)
    return f"{get_settings().web_url.rstrip('/')}{PAGES[page_name]['path']}?lang={lang}&preview={token}"


# ---- A25 translations --------------------------------------------------------------------------------
async def all_texts(db: AsyncSession, *, can_act: bool) -> AdminTextsOut:
    rows = (
        await db.execute(
            select(TextOverride, StaffUser.name)
            .outerjoin(StaffUser, StaffUser.id == TextOverride.reviewed_by)
            .where(
                (TextOverride.live.is_not(None))
                | (TextOverride.reviewed_at.is_not(None))
                | TextOverride.has_draft
            )
        )
    ).all()
    return AdminTextsOut(
        rows=[
            AdminTextRow(
                key=r.key,
                lang=r.lang,
                value=r.live,
                draft=r.draft if r.has_draft else None,
                has_draft=r.has_draft,
                reviewed_at=r.reviewed_at,
                reviewed_by=name,
                updated_at=r.updated_at,
            )
            for r, name in rows
        ],
        can_act=can_act,
    )


async def change_texts(db: AsyncSession, changes: list[AdminTextChange], *, staff_id, ip) -> AdminTextsOut:
    t = now()
    edited = reviewed = 0
    for c in changes:
        value = _check(c.key, c.lang, c.value) if c.set_value else None
        r = await _row(db, c.key, c.lang)
        if c.set_value and value != r.live:
            r.live, r.updated_by, r.updated_at = value, staff_id, t
            edited += 1
        if c.reviewed is not None and bool(r.reviewed_at) != c.reviewed:
            r.reviewed_at, r.reviewed_by = (t, staff_id) if c.reviewed else (None, None)
            reviewed += 1
    if edited or reviewed:
        await audit.record(
            db,
            "texts.updated",
            staff_id=staff_id,
            target_type="texts",
            data={"changed": edited, "reviewed": reviewed, "keys": sorted({c.key for c in changes})[:20]},
            ip=ip,
        )
    await db.flush()
    return await all_texts(db, can_act=True)


# ---- what the app, website and admin panel use ---------------------------------------------------------
async def public(db: AsyncSession, area: str, preview: str | None) -> PublicTextsOut:
    show_drafts = False
    if preview and area == "site":
        try:
            read_link_token(preview, "site_preview")
            show_drafts = True
        except Exception:  # noqa: BLE001 - an old or wrong link just shows the live site
            show_drafts = False
    rows = (
        (
            await db.execute(
                select(TextOverride).where((TextOverride.live.is_not(None)) | TextOverride.has_draft)
            )
        )
        .scalars()
        .all()
    )
    out: dict[str, dict[str, str]] = {}
    for r in rows:
        if area_of(r.key) != area or r.key not in text_keys():
            continue
        value = r.draft if show_drafts and r.has_draft else r.live
        if value is not None:
            out.setdefault(r.lang, {})[r.key] = value
    return PublicTextsOut(texts=out, preview=show_drafts)
