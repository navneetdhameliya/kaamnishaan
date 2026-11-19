"""Website legal pages (W06/W07)."""

import json
import re

from app.core.config import get_settings


async def test_legal_pages_are_drafts_until_company_details_are_set(client, monkeypatch) -> None:
    settings = get_settings()
    for k in ("legal_name", "legal_address", "legal_city", "legal_email", "support_email"):
        monkeypatch.setattr(settings, k, None)
    r = await client.get("/api/v1/public/legal/privacy?locale=gu")
    assert r.status_code == 200 and r.headers["cache-control"] == "public, max-age=300"
    doc = r.json()
    assert doc["doc"] == "privacy" and doc["language"] == "gu" and doc["complete"] is False
    assert [s["id"] for s in doc["sections"]][:2] == ["who", "collect"]
    assert "[કંપનીનું કાનૂની નામ]" in doc["sections"][0]["blocks"][0]["text"]
    assert not re.search(r"\{[a-z]+\}", json.dumps(doc, ensure_ascii=False))


async def test_legal_pages_fill_in_company_details(client, monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "legal_name", "Nishaan Tech Pvt Ltd")
    monkeypatch.setattr(settings, "legal_address", "12 Ring Road, Ahmedabad")
    monkeypatch.setattr(settings, "legal_city", "Ahmedabad")
    monkeypatch.setattr(settings, "legal_email", None)
    monkeypatch.setattr(settings, "support_email", "help@example.com")
    doc = (await client.get("/api/v1/public/legal/terms?locale=en")).json()
    assert doc["complete"] is True and doc["title"] == "Terms and conditions" and doc["read_minutes"] >= 1
    text = str(doc["sections"])
    assert "Nishaan Tech Pvt Ltd" in text and "courts of Ahmedabad" in text and "help@example.com" in text
    assert (await client.get("/api/v1/public/legal/cookies")).status_code == 422
