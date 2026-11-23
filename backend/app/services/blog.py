"""The website blog (W25 list, W26 article) and its admin side (A26 Blog management).

Posts are rows in blog_posts with every language inside `content`. A post is on the website when it
is published and its publish time has come; a later time means it is scheduled.
"""

import math
import re
import uuid
from datetime import datetime
from typing import Any, get_args
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, NotFound
from app.core.security import now
from app.models import BlogPost, StaffUser
from app.schemas.blog import (
    AdminBlogContent,
    AdminBlogDetail,
    AdminBlogList,
    AdminBlogRow,
    BlogBlock,
    BlogCategory,
    BlogIn,
    BlogListOut,
    BlogPostCard,
    BlogPostOut,
)
from app.services import audit, media

ORDER: tuple[str, ...] = get_args(BlogCategory)
WORDS_PER_MINUTE = 200
LANGS = ("en", "hi", "gu", "es", "fr")
IST = ZoneInfo("Asia/Kolkata")


def _live():
    return (BlogPost.status == "published") & (BlogPost.publish_at <= func.now())


def _lang(p: BlogPost, lang: str) -> str:
    return lang if (p.content.get(lang) or {}).get("title") else "en"


def _minutes(c: dict[str, Any]) -> int:
    parts = [c.get("title", ""), c.get("summary", "")]
    for b in c.get("blocks", []):
        parts += [b.get("text") or "", b.get("title") or "", *b.get("items", [])]
    words = len(re.findall(r"\w+", " ".join(parts)))
    return max(1, math.ceil(words / WORDS_PER_MINUTE))


def _block(b: dict[str, Any]) -> BlogBlock:
    return BlogBlock(**{**b, "src": media.url(b.get("src"))})


def _card(p: BlogPost, lang: str) -> BlogPostCard:
    used = _lang(p, lang)
    c = p.content[used]
    return BlogPostCard(
        slug=p.slug,
        category=p.category,  # type: ignore[arg-type]
        title=c["title"],
        summary=c.get("summary", ""),
        cover=media.url(p.cover) or "",
        published_on=(p.publish_at or now()).astimezone(IST).date(),
        read_minutes=_minutes(c),
        language=used,  # type: ignore[arg-type]
    )


async def _published(db: AsyncSession) -> list[BlogPost]:
    q = select(BlogPost).where(_live()).order_by(BlogPost.publish_at.desc(), BlogPost.slug.desc())
    return list((await db.execute(q)).scalars())


async def list_posts(db: AsyncSession, lang: str, category: str | None) -> BlogListOut:
    posts = await _published(db)
    present = {p.category for p in posts}
    featured = next((p for p in posts if p.featured), None) if not category else None
    rows = [p for p in posts if (not category or p.category == category) and p is not featured]
    return BlogListOut(
        categories=[c for c in ORDER if c in present],  # type: ignore[misc]
        featured=_card(featured, lang) if featured else None,
        items=[_card(p, lang) for p in rows],
    )


async def get_post(db: AsyncSession, slug: str, lang: str) -> BlogPostOut:
    posts = await _published(db)
    p = next((x for x in posts if x.slug == slug), None)
    if not p:
        raise NotFound("post_not_found", "This article doesn't exist.")
    c = p.content[_lang(p, lang)]
    others = [x for x in posts if x is not p]
    related = [x for x in others if x.category == p.category]
    related += [x for x in others if x not in related]
    return BlogPostOut(
        **_card(p, lang).model_dump(),
        author=c.get("author") or p.content["en"].get("author") or "KaamNishaan",
        featured=p.featured,
        blocks=[_block(b) for b in c.get("blocks", [])],
        related=[_card(x, lang) for x in related[:3]],
    )


# ---- admin (A26) ---------------------------------------------------------------------------------------
def state(p: BlogPost, at: datetime | None = None) -> str:
    if p.status != "published" or not p.publish_at:
        return "draft"
    return "scheduled" if p.publish_at > (at or now()) else "published"


def _title(p: BlogPost) -> str:
    for lang in LANGS:
        if (p.content.get(lang) or {}).get("title"):
            return p.content[lang]["title"]
    return p.slug


def _row(p: BlogPost, t: datetime) -> AdminBlogRow:
    en = p.content.get("en") or {}
    return AdminBlogRow(
        id=p.id,
        slug=p.slug,
        title=_title(p),
        category=p.category,  # type: ignore[arg-type]
        cover_url=media.url(p.cover, absolute=True) or "",
        author=en.get("author") or "",
        languages=[lang for lang in LANGS if (p.content.get(lang) or {}).get("title")],
        state=state(p, t),  # type: ignore[arg-type]
        publish_at=p.publish_at,
        read_minutes=_minutes(en),
        featured=p.featured,
        updated_at=p.updated_at,
    )


async def admin_list(
    db: AsyncSession, *, q: str | None, state_filter: str | None, lang: str | None, can_act: bool
) -> AdminBlogList:
    t = now()
    posts = list((await db.execute(select(BlogPost).order_by(BlogPost.updated_at.desc()))).scalars())
    rows = [_row(p, t) for p in posts]
    if q:
        needle = q.lower()
        rows = [
            r
            for r, p in zip(rows, posts, strict=True)
            if needle in r.slug
            or any(needle in (c.get("title") or "").lower() for c in p.content.values())
            or needle in r.author.lower()
        ]
    if lang:
        rows = [r for r in rows if lang in r.languages]
    counts = {"all": len(rows), "published": 0, "scheduled": 0, "draft": 0}
    for r in rows:
        counts[r.state] += 1
    if state_filter:
        rows = [r for r in rows if r.state == state_filter]
    # what needs attention first: drafts, then scheduled, then the newest published
    rows.sort(
        key=lambda r: (
            {"draft": 0, "scheduled": 1, "published": 2}[r.state],
            -(r.publish_at or r.updated_at).timestamp(),
        )
    )
    return AdminBlogList(items=rows, counts=counts, categories=list(ORDER), can_act=can_act)  # type: ignore[arg-type]


async def _get(db: AsyncSession, post_id: uuid.UUID) -> BlogPost:
    p = await db.get(BlogPost, post_id)
    if not p:
        raise NotFound("not_found", "Post not found.")
    return p


async def detail(db: AsyncSession, post_id: uuid.UUID, *, can_act: bool) -> AdminBlogDetail:
    p = await _get(db, post_id)
    who = (
        await db.scalar(select(StaffUser.name).where(StaffUser.id == p.updated_by)) if p.updated_by else None
    )
    return AdminBlogDetail(
        id=p.id,
        slug=p.slug,
        category=p.category,  # type: ignore[arg-type]
        featured=p.featured,
        state=state(p),  # type: ignore[arg-type]
        publish_at=p.publish_at,
        cover=p.cover,
        cover_url=media.url(p.cover, absolute=True) or "",
        content={
            lang: AdminBlogContent(
                title=c.get("title", ""),
                summary=c.get("summary", ""),
                author=c.get("author", ""),
                blocks=[BlogBlock(**b) for b in c.get("blocks", [])],  # picture as saved (key or /img/…)
            )
            for lang, c in p.content.items()
        },
        web_url=f"{get_settings().web_url.rstrip('/')}/blog/{p.slug}",
        site_url=get_settings().web_url.rstrip("/"),
        updated_at=p.updated_at,
        updated_by=who,
        can_act=can_act,
    )


def _clean(body: BlogIn) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for lang, c in body.content.items():
        blocks = []
        for i, b in enumerate(c.blocks):
            d = b.model_dump(exclude_none=True)
            if not d.get("items"):
                d.pop("items", None)
            if b.type == "image":
                if not b.src:
                    raise AppError(
                        "validation_error", "Add a picture.", fields={f"{lang}.blocks.{i}": "picture"}
                    )
                d["src"] = media.check_picture(b.src, f"{lang}.blocks.{i}")
            elif b.type == "list":
                d["items"] = [x.strip() for x in b.items if x.strip()]
                if not d["items"]:
                    raise AppError(
                        "validation_error", "Add at least one line.", fields={f"{lang}.blocks.{i}": "items"}
                    )
            elif not b.text:
                raise AppError(
                    "validation_error", "Write something here.", fields={f"{lang}.blocks.{i}": "text"}
                )
            blocks.append(d)
        if c.title or c.summary or blocks:
            out[lang] = {"title": c.title, "summary": c.summary, "author": c.author, "blocks": blocks}
    if not (out.get("en") or {}).get("title"):
        raise AppError("validation_error", "English needs a title.", fields={"en.title": "required"})
    return out


def _ready(p: BlogPost) -> None:
    """A post goes on the website only with every language it has complete."""
    for lang, c in p.content.items():
        missing = [f for f in ("title", "summary") if not c.get(f)] + ([] if c.get("blocks") else ["blocks"])
        if missing:
            raise AppError(
                "post_incomplete",
                "Finish the {lang} version first: {missing}.",
                params={"lang": lang, "missing": ", ".join(missing)},
                fields={f"{lang}.{f}": "required" for f in missing},
            )


async def _apply(db: AsyncSession, p: BlogPost, body: BlogIn, staff_id, *, new: bool) -> None:
    q = select(BlogPost.id).where(BlogPost.slug == body.slug)
    if not new:
        q = q.where(BlogPost.id != p.id)
    if await db.scalar(q):
        raise AppError("slug_taken", "Another post already uses this web address.", fields={"slug": "taken"})
    if not new and state(p) == "published" and p.slug != body.slug:
        raise AppError(
            "slug_locked", "Unpublish the post before changing its web address.", fields={"slug": "locked"}
        )
    p.slug, p.category, p.cover = body.slug, body.category, media.check_picture(body.cover, "cover")
    p.content = _clean(body)
    p.updated_by = staff_id
    if body.featured and not p.featured:
        others = (await db.execute(select(BlogPost).where(BlogPost.featured.is_(True)))).scalars()
        for o in others:
            o.featured = False
    p.featured = body.featured
    if p.status == "published":
        _ready(p)


async def create(db: AsyncSession, body: BlogIn, *, staff_id, ip) -> AdminBlogDetail:
    p = BlogPost(id=uuid.uuid4(), status="draft", featured=False, content={}, created_by=staff_id)
    await _apply(db, p, body, staff_id, new=True)
    db.add(p)
    await db.flush()
    await audit.record(
        db,
        "blog.created",
        staff_id=staff_id,
        target_type="blog_post",
        target_id=p.id,
        data={"slug": p.slug},
        ip=ip,
    )
    return await detail(db, p.id, can_act=True)


async def update(db: AsyncSession, post_id: uuid.UUID, body: BlogIn, *, staff_id, ip) -> AdminBlogDetail:
    p = await _get(db, post_id)
    await _apply(db, p, body, staff_id, new=False)
    await audit.record(
        db,
        "blog.updated",
        staff_id=staff_id,
        target_type="blog_post",
        target_id=p.id,
        data={"slug": p.slug},
        ip=ip,
    )
    await db.flush()
    return await detail(db, p.id, can_act=True)


async def publish(
    db: AsyncSession, post_id: uuid.UUID, at: datetime | None, *, staff_id, ip
) -> AdminBlogDetail:
    p = await _get(db, post_id)
    _ready(p)
    t = now()
    p.status, p.publish_at, p.updated_by = "published", at if at and at > t else t, staff_id
    await audit.record(
        db,
        "blog.published",
        staff_id=staff_id,
        target_type="blog_post",
        target_id=p.id,
        data={"slug": p.slug, "at": p.publish_at.isoformat()},
        ip=ip,
    )
    await db.flush()
    return await detail(db, p.id, can_act=True)


async def unpublish(db: AsyncSession, post_id: uuid.UUID, *, staff_id, ip) -> AdminBlogDetail:
    p = await _get(db, post_id)
    p.status, p.updated_by = "draft", staff_id
    await audit.record(
        db,
        "blog.unpublished",
        staff_id=staff_id,
        target_type="blog_post",
        target_id=p.id,
        data={"slug": p.slug},
        ip=ip,
    )
    await db.flush()
    return await detail(db, p.id, can_act=True)


async def delete(db: AsyncSession, post_id: uuid.UUID, *, staff_id, ip) -> None:
    p = await _get(db, post_id)
    if state(p) == "published":
        raise AppError("post_live", "Unpublish the post before deleting it.")
    await audit.record(
        db,
        "blog.deleted",
        staff_id=staff_id,
        target_type="blog_post",
        target_id=p.id,
        data={"slug": p.slug, "title": _title(p)},
        ip=ip,
    )
    await db.delete(p)
    await db.flush()
