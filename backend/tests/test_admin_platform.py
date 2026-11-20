"""A32 Platform settings: each switch really changes what companies get."""

from sqlalchemy import text

from app.core.db import engine
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup
from tests.test_reports import (  # noqa: F401 - the `ready` fixture
    fake_ai,  # noqa: F401 - the fake AI fixture
    make_report,
    ready,
)

A = "/api/v1/admin/platform-settings"
BASE = {
    "support_email": None, "support_whatsapp": None, "default_country": None, "signups": True,
    "ai_drafting": True, "ai_assistant": True, "maintenance": False, "max_photo_mb": 12,
}  # fmt: skip


async def test_defaults_contacts_and_country(client):
    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    assert d["settings"] == BASE and d["can_act"] and d["server"]["default_country"] == "IN"
    assert any(c["value"] == "US" for c in d["countries"])
    body = {
        **BASE,
        "support_email": "Help@KaamNishaan.com",
        "support_whatsapp": "98250 33333",
        "default_country": "us",
    }
    r = await client.put(A, json=body, headers=auth(s))
    assert r.status_code == 200, r.text
    got = r.json()["settings"]
    assert (got["support_email"], got["support_whatsapp"], got["default_country"]) == (
        "help@kaamnishaan.com", "+919825033333", "US")  # fmt: skip
    cfg = (await client.get("/api/v1/config")).json()
    assert cfg["support"]["email"] == "help@kaamnishaan.com" and cfg["default_country"] == "US"
    bad = await client.put(
        A, json={**BASE, "support_whatsapp": "12", "default_country": "ZZ"}, headers=auth(s)
    )
    assert bad.status_code == 422 and bad.json()["error"]["fields"] == {
        "support_whatsapp": "invalid",
        "default_country": "unknown",
    }
    assert (await client.put(A, json={**BASE, "max_photo_mb": 50}, headers=auth(s))).status_code == 422


async def test_signups_maintenance_and_photo_size(client):
    owner = await make_owner(client)
    s, _ = await _setup(client)
    await client.put(A, json={**BASE, "signups": False, "max_photo_mb": 2}, headers=auth(s))
    assert (await client.get("/api/v1/config")).json()["features"]["signups"] is False
    r = await client.post("/api/v1/auth/register", json={"name": "New Owner", "email": "new@x.in",
                                                          "password": "Cool1234", "accept_terms": True})  # fmt: skip
    new = r.json()
    r = await client.post("/api/v1/companies", json={"name": "NewCo", "trade": "hvac", "country": "IN"},
                          headers=auth(new))  # fmt: skip
    assert r.status_code == 403 and r.json()["error"]["code"] == "signups_closed"
    big = await client.post("/api/v1/uploads", json={"kind": "photo", "content_type": "image/jpeg",
                                                     "size": 3 * 1024 * 1024}, headers=auth(owner))  # fmt: skip
    assert big.status_code == 400 and big.json()["error"]["code"] == "file_too_large"

    r = await client.put(A, json={**BASE, "maintenance": True}, headers=auth(s))
    assert r.status_code == 200 and (await client.get("/api/v1/config")).json()["maintenance"] is True
    login = await client.post(
        "/api/v1/auth/login", json={"email": "owner@brightair.in", "password": "Cool1234"}
    )
    assert login.status_code == 503 and login.json()["error"]["code"] == "maintenance"
    assert (await client.post("/api/v1/auth/otp/send", json={"phone": "+919825044444"})).status_code == 503
    assert (await client.get(A, headers=auth(s))).status_code == 200  # the admin panel still works
    await client.put(A, json=BASE, headers=auth(s))
    assert (
        await client.post("/api/v1/auth/login", json={"email": "owner@brightair.in", "password": "Cool1234"})
    ).status_code == 200
    async with engine.begin() as c:
        acts = (
            (
                await c.execute(
                    text(
                        "SELECT action FROM audit_logs WHERE action LIKE 'staff.%platform%' OR action LIKE 'staff.maintenance%' ORDER BY created_at"
                    )
                )
            )
            .scalars()
            .all()
        )
    assert acts == ["staff.platform_updated", "staff.maintenance_on", "staff.maintenance_off"]


async def test_ai_switches_and_only_super_admins(client, ready, fake_ai):
    s, _ = await _setup(client)
    await client.put(A, json={**BASE, "ai_drafting": False, "ai_assistant": False}, headers=auth(s))
    _, task, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    assert task["status"] == "done" and rep["drafted_by"] == "template" and fake_ai.calls == []
    r = await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(ready["owner"]))
    assert r.status_code == 503 and r.json()["error"]["code"] == "assistant_unavailable"
    features = (await client.get("/api/v1/config")).json()["features"]
    assert features["ai_drafting"] is False and features["ai_assistant"] is False
    async with engine.begin() as c:
        await c.execute(text("UPDATE staff_users SET role = 'admin'"))
    assert (await client.get(A, headers=auth(s))).json()["can_act"] is False
    assert (await client.put(A, json=BASE, headers=auth(s))).status_code == 403
