"""Website leads in the admin panel: tabs, search, details, status and note, newsletter CSV."""

import pytest

from app.core.db import SessionLocal
from app.models import AuditLog
from app.services import leads as public_leads
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup
from tests.test_leads import NOW, demo

A = "/api/v1/admin"


@pytest.fixture(autouse=True)
def _clock(monkeypatch):
    monkeypatch.setattr(public_leads, "now", lambda: NOW)


async def _leads(client):
    r = await client.post("/api/v1/public/demo-requests", json=demo("2026-11-19T11:30:00+05:30"))
    assert r.status_code == 201, r.text
    msg = "Can your app work offline on rooftops with no signal at all?"
    r = await client.post(
        "/api/v1/public/contact",
        json={"name": "Meera Shah", "email": "meera@shahfix.in", "topic": "sales", "message": msg},
    )
    assert r.status_code == 201, r.text
    await client.post("/api/v1/public/newsletter", json={"email": "=cmd@x.in"})
    await client.post("/api/v1/public/newsletter", json={"email": "anita@x.in", "lang": "hi"})
    staff, _ = await _setup(client)
    return staff


async def test_tabs_and_search(client):
    s = await _leads(client)
    d = (await client.get(f"{A}/leads", headers=auth(s))).json()
    assert d["counts"] == {"new": 2, "demo": 1, "contact": 1, "newsletter": 2, "done": 0}
    assert {i["kind"] for i in d["items"]} == {"demo", "contact"}
    contact = next(i for i in d["items"] if i["kind"] == "contact")
    assert contact["preview"].startswith("Can your app") and contact["topic"] == "sales"
    demo_row = (await client.get(f"{A}/leads", params={"tab": "demo"}, headers=auth(s))).json()["items"][0]
    assert demo_row["starts_at"].startswith("2026-11-19T06:00")
    r = await client.get(f"{A}/leads", params={"tab": "contact", "q": "rooftops"}, headers=auth(s))
    assert r.json()["total"] == 1
    r = await client.get(
        f"{A}/leads", params={"tab": "demo", "q": f"KN-{demo_row['number']}"}, headers=auth(s)
    )
    assert r.json()["total"] == 1


async def test_details_status_note_and_signed_up_match(client):
    s = await _leads(client)
    await make_owner(client, email="ramesh@brightair.in", company="BrightAir Services")
    row = (await client.get(f"{A}/leads", params={"tab": "demo"}, headers=auth(s))).json()["items"][0]
    d = (await client.get(f"{A}/leads/{row['id']}", params={"locale": "gu"}, headers=auth(s))).json()
    assert d["phone"] == "+91 98765 43210" and d["team_size"] == "1-5" and d["trade"]
    assert d["company_name"] == "BrightAir Services" and d["note"] is None and d["handled_by"] is None

    r = await client.patch(
        f"{A}/leads/{row['id']}",
        json={"status": "contacted", "note": "Called, demo confirmed"},
        headers=auth(s),
    )
    assert r.status_code == 200, r.text
    d = r.json()
    assert (
        d["status"] == "contacted"
        and d["note"] == "Called, demo confirmed"
        and d["handled_by"] == "Navneet Dhameliya"
    )
    counts = (await client.get(f"{A}/leads", headers=auth(s))).json()["counts"]
    assert counts["new"] == 1 and counts["done"] == 1
    assert (
        await client.patch(f"{A}/leads/{row['id']}", json={"status": "lost"}, headers=auth(s))
    ).status_code == 422
    async with SessionLocal() as db:
        logs = (
            await db.execute(AuditLog.__table__.select().where(AuditLog.action == "staff.lead_updated"))
        ).all()
    assert len(logs) == 1 and logs[0].data == {"status": {"from": "new", "to": "contacted"}, "note": True}


async def test_newsletter_csv(client):
    s = await _leads(client)
    r = await client.get(f"{A}/leads/newsletter.csv", headers=auth(s))
    assert r.status_code == 200 and "attachment" in r.headers["content-disposition"]
    lines = r.text.lstrip("﻿").strip().splitlines()
    assert lines[0] == "Email,Language,Signed up" and len(lines) == 3
    assert lines[1].startswith("'=cmd@x.in") and lines[2].startswith("anita@x.in,hi,")
    owner = await make_owner(client)
    assert (await client.get(f"{A}/leads", headers=auth(owner))).status_code == 401
