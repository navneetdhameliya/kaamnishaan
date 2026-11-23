"""Error messages in the user's language (D-137).

Every error the API sends is a fixed English sentence (see AppError); its translations live in
app/content/messages/{lang}.json, keyed by that sentence, and scripts/extract_messages.py --check keeps
them complete. The language comes from the request's Accept-Language header, which the app, the website
and the admin panel set to the language the person chose."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

LANGS = ("en", "hi", "gu", "es", "fr")
_DIR = Path(__file__).resolve().parents[1] / "content" / "messages"


@lru_cache(maxsize=8)
def catalog(lang: str) -> dict[str, str]:
    path = _DIR / f"{lang}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def pick_language(header: str | None) -> str:
    """The first of our languages in an Accept-Language header ("hi-IN,hi;q=0.9,en;q=0.8" → hi), by weight."""
    best, best_q = "en", -1.0
    for i, part in enumerate((header or "").split(",")):
        tag, _, rest = part.strip().partition(";")
        lang = tag.strip().lower().split("-")[0]
        if lang not in LANGS:
            continue
        q = 1.0
        if rest.strip().startswith("q="):
            try:
                q = float(rest.strip()[2:])
            except ValueError:
                q = 0.0
        q -= i * 1e-6  # the earlier one wins a tie
        if q > best_q:
            best, best_q = lang, q
    return best


def translate(template: str, lang: str, params: dict[str, Any] | None = None) -> str:
    """The sentence in [lang] (English when there is no translation), with its {placeholders} filled in."""
    text = template if lang == "en" else catalog(lang).get(template) or template
    if not params:
        return text
    try:
        return text.format(**params)
    except (KeyError, IndexError, ValueError):  # a translation lost a placeholder: English is still right
        return template.format(**params)
