"""A24 Website content and A25 Localized content: texts changed without a release."""

from urllib.parse import parse_qs, urlparse

from sqlalchemy import update

from app.core.db import SessionLocal
from app.models import StaffUser
from app.services import texts
from tests.conftest import auth
from tests.test_admin_auth import _setup

A = "/api/v1/admin"
P = "/api/v1/public/texts"


def test_every_page_text_exists():
    keys = texts.text_keys()
    for page in texts.PAGES:
        for key in texts.page_keys(page):
            assert key in keys, key
            assert texts.area_of(key) == "site"
    assert texts.text_keys()["site.final.body"] == "n"


async def test_website_drafts_preview_and_publish(client):
    s, _ = await _setup(client)
    pages = (await client.get(f"{A}/website-content", headers=auth(s))).json()
    assert pages["can_act"] and {p["page"] for p in pages["pages"]} >= {"home", "pricing", "industry_hvac"}
    home = (await client.get(f"{A}/website-content/home", headers=auth(s))).json()
    hero = home["sections"][0]
    assert hero["key"] == "hero" and [f["label"] for f in hero["fields"]][:3] == [
        "eyebrow",
        "headline",
        "subheadline",
    ]
    assert home["sections"][-1]["fields"][0]["key"] == "site.seo.home.title"

    # a draft doesn't reach the website until Publish; a placeholder can't be dropped
    r = await client.put(f"{A}/website-content/home", headers=auth(s),
                         json={"values": {"site.final.body": {"en": "Free trial. No card."}}})  # fmt: skip
    assert r.status_code == 400 and "{n}" in r.json()["error"]["message"]
    r = await client.put(f"{A}/website-content/home", headers=auth(s),
                         json={"values": {"site.hero.title": {"en": "Proof for every job.", "hi": "हर काम का सबूत।"}}})  # fmt: skip
    assert r.status_code == 200 and r.json()["drafts"] == 2
    r = await client.put(f"{A}/website-content/home", headers=auth(s),
                         json={"values": {"site.ct.title": {"en": "Hi"}}})  # fmt: skip
    assert r.status_code == 400  # not on this page
    assert (await client.get(P, params={"area": "site"})).json()["texts"] == {}

    link = (
        await client.post(f"{A}/website-content/home/preview", json={"lang": "hi"}, headers=auth(s))
    ).json()["url"]
    q = parse_qs(urlparse(link).query)
    assert q["lang"] == ["hi"]
    pv = await client.get(P, params={"area": "site", "preview": q["preview"][0]})
    assert pv.json() == {
        "texts": {
            "en": {"site.hero.title": "Proof for every job."},
            "hi": {"site.hero.title": "हर काम का सबूत।"},
        },
        "preview": True,
    }
    assert pv.headers["cache-control"] == "no-store"
    assert (await client.get(P, params={"area": "site", "preview": "nope"})).json()["preview"] is False

    r = await client.post(f"{A}/website-content/home/publish", headers=auth(s))
    assert r.status_code == 200 and r.json()["drafts"] == 0
    live = await client.get(P, params={"area": "site"})
    assert live.json()["texts"]["en"] == {"site.hero.title": "Proof for every job."}
    assert live.headers["cache-control"] == "public, max-age=60"
    assert (await client.get(P, params={"area": "app"})).json()["texts"] == {}
    assert (await client.post(f"{A}/website-content/home/publish", headers=auth(s))).status_code == 400

    # back to the built-in text: empty value, then publish
    await client.put(
        f"{A}/website-content/home", headers=auth(s), json={"values": {"site.hero.title": {"en": ""}}}
    )
    row = next(
        p
        for p in (await client.get(f"{A}/website-content", headers=auth(s))).json()["pages"]
        if p["page"] == "home"
    )
    assert row["drafts"] == 1 and row["changed"] == 2
    await client.post(f"{A}/website-content/home/discard", headers=auth(s))
    await client.put(
        f"{A}/website-content/home", headers=auth(s), json={"values": {"site.hero.title": {"en": None}}}
    )
    await client.post(f"{A}/website-content/home/publish", headers=auth(s))
    assert (await client.get(P, params={"area": "site"})).json()["texts"] == {
        "hi": {"site.hero.title": "हर काम का सबूत।"}
    }


async def test_translation_fixes_and_reviews(client):
    s, _ = await _setup(client)
    r = await client.put(f"{A}/texts", headers=auth(s), json={"changes": [
        {"key": "today.jobs", "lang": "hi", "set_value": True, "value": "आज का काम", "reviewed": True},
        {"key": "today.jobs", "lang": "gu", "reviewed": True},
        {"key": "admin.nav.jobs", "lang": "fr", "set_value": True, "value": "Interventions"},
    ]})  # fmt: skip
    assert r.status_code == 200, r.text
    rows = {(x["key"], x["lang"]): x for x in r.json()["rows"]}
    assert rows[("today.jobs", "hi")]["value"] == "आज का काम" and rows[("today.jobs", "hi")]["reviewed_by"]
    assert rows[("today.jobs", "gu")]["value"] is None and rows[("today.jobs", "gu")]["reviewed_at"]
    assert (await client.get(P, params={"area": "app"})).json()["texts"] == {
        "hi": {"today.jobs": "आज का काम"}
    }
    assert (await client.get(P, params={"area": "admin"})).json()["texts"] == {
        "fr": {"admin.nav.jobs": "Interventions"}
    }

    bad = await client.put(f"{A}/texts", headers=auth(s), json={"changes": [
        {"key": "no.such.key", "lang": "hi", "set_value": True, "value": "x"}]})  # fmt: skip
    assert bad.status_code == 400

    # support staff can look, not change
    async with SessionLocal() as db, db.begin():
        await db.execute(update(StaffUser).values(role="support"))
    assert (await client.get(f"{A}/texts", headers=auth(s))).json()["can_act"] is False
    r = await client.put(
        f"{A}/texts",
        headers=auth(s),
        json={"changes": [{"key": "today.jobs", "lang": "hi", "reviewed": False}]},
    )
    assert r.status_code == 403
    r = await client.put(f"{A}/website-content/home", headers=auth(s), json={"values": {}})
    assert r.status_code == 403
