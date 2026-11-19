"""Privacy policy and Terms live in app/content/legal/<doc>.json, all languages inside.

{company}, {address}, {city}, {email} and {country} are filled from settings (KN_LEGAL_*). A value not set yet
shows the file's own "missing" word for it (e.g. "[company name]") and the page is marked as a draft.
"""

import json
import math
import re
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.core.config import get_settings
from app.schemas.legal import LegalOut

DIR = Path(__file__).resolve().parent.parent / "content" / "legal"


@lru_cache(maxsize=4)
def _doc(name: str) -> dict[str, Any]:
    return json.loads((DIR / f"{name}.json").read_text(encoding="utf-8"))


def get(doc: str, lang: str) -> LegalOut:
    d = _doc(doc)
    used = lang if lang in d["content"] else "en"
    c = d["content"][used]
    missing = c.get("missing", {})
    settings = get_settings()
    values = {
        "company": settings.legal_name,
        "address": settings.legal_address,
        "city": settings.legal_city,
        "email": settings.legal_email or settings.support_email,
        "country": c.get("country", "India"),
    }
    complete = all(values[k] for k in ("company", "address", "city", "email"))

    def fill(text: str) -> str:
        return re.sub(r"\{(\w+)\}", lambda m: values.get(m[1]) or missing.get(m[1], m[0]), text)

    sections = [
        {
            "id": s["id"],
            "heading": fill(s["heading"]),
            "blocks": [
                {
                    "type": b["type"],
                    "text": fill(b["text"]) if b.get("text") else None,
                    "items": [fill(x) for x in b.get("items", [])],
                }
                for b in s["blocks"]
            ],
        }
        for s in c["sections"]
    ]
    words = len(
        re.findall(r"\w+", " ".join([c["intro"], *(json.dumps(s, ensure_ascii=False) for s in sections)]))
    )
    return LegalOut(
        doc=doc,  # type: ignore[arg-type]
        title=c["title"],
        intro=fill(c["intro"]),
        updated_on=date.fromisoformat(d["updated"]),
        read_minutes=max(1, math.ceil(words / 200)),
        language=used,  # type: ignore[arg-type]
        complete=complete,
        sections=sections,  # type: ignore[arg-type]
    )
