"""Blog posts live as JSON files in app/content/blog (one per post, all languages inside).

Adding a post = adding a file; there is no admin editor yet (D-104). Files are read once and kept in memory.
"""

import json
import math
import re
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any, get_args

from app.core.errors import NotFound
from app.schemas.blog import BlogBlock, BlogCategory, BlogListOut, BlogPostCard, BlogPostOut

DIR = Path(__file__).resolve().parent.parent / "content" / "blog"
ORDER: tuple[str, ...] = get_args(BlogCategory)
WORDS_PER_MINUTE = 200


@lru_cache(maxsize=1)
def _posts() -> tuple[dict[str, Any], ...]:
    posts = []
    for f in sorted(DIR.glob("*.json")):
        p = json.loads(f.read_text(encoding="utf-8"))
        if p.get("draft"):
            continue
        p["published_on"] = date.fromisoformat(p["published"])
        posts.append(p)
    posts.sort(key=lambda p: (p["published_on"], p["slug"]), reverse=True)
    return tuple(posts)


def _lang(p: dict[str, Any], lang: str) -> str:
    return lang if lang in p["content"] else "en"


def _minutes(c: dict[str, Any]) -> int:
    parts = [c["title"], c["summary"]]
    for b in c["blocks"]:
        parts += [b.get("text") or "", b.get("title") or "", *b.get("items", [])]
    words = len(re.findall(r"\w+", " ".join(parts)))
    return max(1, math.ceil(words / WORDS_PER_MINUTE))


def _card(p: dict[str, Any], lang: str) -> BlogPostCard:
    used = _lang(p, lang)
    c = p["content"][used]
    return BlogPostCard(
        slug=p["slug"],
        category=p["category"],
        title=c["title"],
        summary=c["summary"],
        cover=p["cover"],
        published_on=p["published_on"],
        read_minutes=_minutes(c),
        language=used,  # type: ignore[arg-type]
    )


def list_posts(lang: str, category: str | None) -> BlogListOut:
    posts = _posts()
    present = {p["category"] for p in posts}
    featured = next((p for p in posts if p.get("featured")), None) if not category else None
    rows = [p for p in posts if (not category or p["category"] == category) and p is not featured]
    return BlogListOut(
        categories=[c for c in ORDER if c in present],  # type: ignore[misc]
        featured=_card(featured, lang) if featured else None,
        items=[_card(p, lang) for p in rows],
    )


def get_post(slug: str, lang: str) -> BlogPostOut:
    posts = _posts()
    p = next((x for x in posts if x["slug"] == slug), None)
    if not p:
        raise NotFound("post_not_found", "This article doesn't exist.")
    used = _lang(p, lang)
    c = p["content"][used]
    others = [x for x in posts if x is not p]
    related = [x for x in others if x["category"] == p["category"]]
    related += [x for x in others if x not in related]
    return BlogPostOut(
        **_card(p, lang).model_dump(),
        author=c.get("author") or p["content"]["en"].get("author", "KaamNishaan"),
        featured=bool(p.get("featured")),
        blocks=[BlogBlock(**b) for b in c["blocks"]],
        related=[_card(x, lang) for x in related[:3]],
    )
