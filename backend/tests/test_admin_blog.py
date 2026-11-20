"""A26 Blog management, A27 Testimonials and the website pictures they use."""

from datetime import timedelta

import pytest
from sqlalchemy import delete, select, update

from app.core.db import SessionLocal
from app.core.security import now
from app.models import BlogPost, StaffUser
from tests.conftest import auth
from tests.test_admin_auth import _setup

A = "/api/v1/admin"
P = "/api/v1/public"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
COLS = ("id", "slug", "category", "featured", "status", "publish_at", "cover", "content", "created_at")


@pytest.fixture
async def posts_back():
    """Blog posts are seed data kept between tests: put them back afterwards."""
    async with SessionLocal() as db:
        saved = [{c: getattr(p, c) for c in COLS} for p in (await db.execute(select(BlogPost))).scalars()]
    yield
    async with SessionLocal() as db, db.begin():
        await db.execute(delete(BlogPost))
        db.add_all(BlogPost(**p) for p in saved)


def _post(**over):
    body = {
        "slug": "photo-tips-for-pest-control",
        "category": "pest",
        "featured": False,
        "cover": "/img/ind-pest-photo.webp",
        "content": {
            "en": {
                "title": "Photo tips for pest control",
                "summary": "Where to point the camera so every bait station counts.",
                "author": "KaamNishaan team",
                "blocks": [{"type": "p", "text": "Start at the door."}, {"type": "list", "title": "Take:",
                            "items": ["The station", " ", "The map"]}],
            },
            "hi": {"title": "पेस्ट कंट्रोल के फ़ोटो टिप्स", "summary": "", "author": "", "blocks": []},
        },
    }  # fmt: skip
    body.update(over)
    return body


async def test_blog_draft_schedule_publish(client, posts_back):
    s, _ = await _setup(client)
    lst = (await client.get(f"{A}/blog", headers=auth(s))).json()
    assert lst["counts"] == {"all": 7, "published": 7, "scheduled": 0, "draft": 0} and lst["can_act"]
    assert lst["items"][0]["languages"] == ["en", "hi", "gu", "es", "fr"]

    r = await client.post(f"{A}/blog", json=_post(), headers=auth(s))
    assert r.status_code == 201, r.text
    d = r.json()
    assert d["state"] == "draft" and d["content"]["en"]["blocks"][1]["items"] == ["The station", "The map"]
    dup = await client.post(f"{A}/blog", json=_post(), headers=auth(s))
    assert dup.json()["error"]["code"] == "slug_taken"
    assert (await client.get(f"{P}/blog/photo-tips-for-pest-control")).status_code == 404

    # Hindi is half written: publishing asks to finish it
    r = await client.post(f"{A}/blog/{d['id']}/publish", json={}, headers=auth(s))
    assert r.json()["error"]["code"] == "post_incomplete" and "hi" in r.json()["error"]["message"]
    body = _post()
    del body["content"]["hi"]
    await client.put(f"{A}/blog/{d['id']}", json=body, headers=auth(s))

    later = (now() + timedelta(days=2)).isoformat()
    r = await client.post(f"{A}/blog/{d['id']}/publish", json={"at": later}, headers=auth(s))
    assert r.json()["state"] == "scheduled"
    assert (await client.get(f"{P}/blog/photo-tips-for-pest-control")).status_code == 404
    r = await client.post(f"{A}/blog/{d['id']}/publish", json={}, headers=auth(s))
    assert r.json()["state"] == "published"
    one = (await client.get(f"{P}/blog/photo-tips-for-pest-control?locale=hi")).json()
    assert one["language"] == "en" and one["category"] == "pest"
    assert "pest" in (await client.get(f"{P}/blog")).json()["categories"]

    # live posts keep their address; featured moves to this one
    body["slug"] = "renamed"
    assert (await client.put(f"{A}/blog/{d['id']}", json=body, headers=auth(s))).json()["error"][
        "code"
    ] == "slug_locked"
    body["slug"], body["featured"] = "photo-tips-for-pest-control", True
    await client.put(f"{A}/blog/{d['id']}", json=body, headers=auth(s))
    assert (await client.get(f"{P}/blog")).json()["featured"]["slug"] == "photo-tips-for-pest-control"

    assert (await client.delete(f"{A}/blog/{d['id']}", headers=auth(s))).json()["error"][
        "code"
    ] == "post_live"
    await client.post(f"{A}/blog/{d['id']}/unpublish", headers=auth(s))
    assert (await client.delete(f"{A}/blog/{d['id']}", headers=auth(s))).status_code == 204
    assert (await client.get(f"{A}/blog?state=draft", headers=auth(s))).json()["items"] == []


async def test_pictures_and_testimonials(client):
    s, _ = await _setup(client)
    bad = await client.put(f"{A}/media?kind=people", content=b"hello", headers=auth(s))
    assert bad.status_code == 400
    up = await client.put(f"{A}/media?kind=people", content=PNG, headers=auth(s))
    assert up.status_code == 201 and up.json()["key"].startswith("site/people/")
    path = "/api/v1" + up.json()["url"].split("/api/v1", 1)[1]
    got = await client.get(path, follow_redirects=False)
    assert got.status_code == 302 and got.headers["cache-control"] == "public, max-age=600"
    assert (await client.get(f"{P}/media/evidence/x.jpg", follow_redirects=False)).status_code == 404

    t = {"quote": {"en": "Customers stopped asking.", "hi": "ग्राहक अब नहीं पूछते।"}, "person_name": "Suresh Shah",
         "role": "Owner", "company_name": "BrightAir", "city": "Surat", "photo": up.json()["key"]}  # fmt: skip
    r = await client.post(f"{A}/testimonials", json={**t, "on_website": True}, headers=auth(s))
    assert r.json()["error"]["code"] == "not_approved"
    r = await client.post(f"{A}/testimonials", json=t, headers=auth(s))
    item = r.json()["items"][0]
    assert r.status_code == 201 and item["photo_url"].endswith(up.json()["key"]) and not item["on_website"]
    assert (await client.get(f"{P}/testimonials")).json()["items"] == []

    ok = {**t, "approved_in_writing": True, "approval_note": "Email, 3 Nov", "on_website": True}
    await client.put(f"{A}/testimonials/{item['id']}", json=ok, headers=auth(s))
    pub = (await client.get(f"{P}/testimonials?locale=gu")).json()["items"]
    assert (
        pub[0]["quote"] == "Customers stopped asking."
        and pub[0]["language"] == "en"
        and pub[0]["city"] == "Surat"
    )
    assert (await client.get(f"{P}/testimonials?locale=hi")).json()["items"][0][
        "quote"
    ] == "ग्राहक अब नहीं पूछते।"

    async with SessionLocal() as db, db.begin():
        await db.execute(update(StaffUser).values(role="support"))
    assert (await client.get(f"{A}/testimonials", headers=auth(s))).json()["can_act"] is False
    assert (await client.delete(f"{A}/testimonials/{item['id']}", headers=auth(s))).status_code == 403
    assert (await client.put(f"{A}/media?kind=blog", content=PNG, headers=auth(s))).status_code == 403
