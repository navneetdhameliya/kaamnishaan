"""Error messages in the user's language (D-137)."""

import importlib.util
from pathlib import Path

from httpx import ASGITransport, AsyncClient

from app.core.errors import AppError
from app.core.messages import catalog, pick_language, translate
from app.main import create_app


def test_every_message_has_all_four_translations() -> None:
    path = Path(__file__).resolve().parents[1] / "scripts" / "extract_messages.py"
    spec = importlib.util.spec_from_file_location("extract_messages", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    found, dynamic = mod.messages()
    assert dynamic == [], "build messages with params, not f-strings, so they can be translated"
    for lang in ("hi", "gu", "es", "fr"):
        missing = [m for m in found if not catalog(lang).get(m)]
        assert missing == [], f"{lang} is missing translations: run scripts/extract_messages.py"


def test_picking_the_language() -> None:
    assert pick_language(None) == "en"
    assert pick_language("hi") == "hi"
    assert pick_language("gu-IN,gu;q=0.9,en;q=0.8") == "gu"
    assert pick_language("de-DE,fr;q=0.7,en;q=0.9") == "en"  # by weight, among ours
    assert pick_language("de,ja") == "en"
    assert pick_language("ES-mx") == "es"


def test_placeholders_are_filled_in_after_translating() -> None:
    assert translate("At most {limit} characters.", "fr", {"limit": 300}) == "Au maximum 300 caractères."
    assert translate("At most {limit} characters.", "en", {"limit": 300}) == "At most 300 characters."
    assert translate("A sentence nobody translated.", "hi") == "A sentence nobody translated."
    e = AppError("validation_error", "At most {limit} characters.", params={"limit": 9})
    assert (e.message, e.template) == ("At most 9 characters.", "At most {limit} characters.")


async def test_errors_come_back_in_the_asked_language() -> None:
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://t") as c:
        en = await c.get("/api/v1/me")
        hi = await c.get("/api/v1/me", headers={"Accept-Language": "hi-IN,hi;q=0.9"})
        missing = await c.get("/api/v1/no-such-page", headers={"Accept-Language": "gu"})
    assert en.status_code == hi.status_code == 401
    assert hi.json()["error"]["code"] == en.json()["error"]["code"]
    assert hi.json()["error"]["message"] == catalog("hi")[en.json()["error"]["message"]]
    assert hi.headers["content-language"] == "hi"
    assert missing.status_code == 404
    assert missing.json()["error"]["message"] == "મળ્યું નહીં."
