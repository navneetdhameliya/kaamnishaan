"""A06 create a company (owner joins by phone), A07 edit, suspend and turn back on."""

from app.core.db import SessionLocal
from app.models import AuditLog, StaffUser
from tests.conftest import auth, invite_and_join, make_owner, phone_login
from tests.test_admin_auth import _setup

A = "/api/v1/admin/companies"
NEW = {
    "name": "CoolRight HVAC", "trade": "hvac", "country": "IN", "report_language": "gu",
    "owner_name": "Mike Turner", "owner_phone": "98765 00200", "owner_email": "mike@coolright.in",
    "plan": "business",
}  # fmt: skip


async def test_create_then_owner_joins_with_phone(client):
    s, _ = await _setup(client)
    r = await client.post(A, json=NEW, headers=auth(s))
    assert r.status_code == 201, r.text
    out = r.json()
    c = out["company"]
    assert c["status"] == "trial" and c["plan"]["code"] == "business" and c["report_language"] == "gu"
    assert c["owner_pending"] is True and c["owner_phone"] == "+919876500200" and c["currency"] == "INR"
    assert (
        c["timezone"] == "Asia/Kolkata"
        and "/join/" in out["invite_link"]
        and "KaamNishaan" in out["sms_text"]
    )

    # before joining, the owner is shown by the name on the invite
    d = (await client.get(f"{A}/{c['id']}", headers=auth(s))).json()
    assert d["owner_name"] == "Mike Turner" and d["team"][0]["name"] == "Mike Turner"

    session = await phone_login(client, "+919876500200")
    invite = session["invites"][0]
    assert invite["role"] == "owner" and invite["invited_by"]["name"] == "KaamNishaan"
    r = await client.post(f"/api/v1/invites/{invite['id']}/accept", headers=auth(session))
    assert r.status_code == 200, r.text
    d = (await client.get(f"{A}/{c['id']}", headers=auth(s))).json()
    assert (
        d["owner_pending"] is False
        and d["owner_name"] == "Mike Turner"
        and d["owner_email"] == "mike@coolright.in"
    )
    # once joined there is nothing to resend
    assert (await client.post(f"{A}/{c['id']}/owner-invite", headers=auth(s))).status_code == 409


async def test_create_checks_fields_and_resend_replaces_link(client):
    s, _ = await _setup(client)
    await make_owner(client, email="mike@coolright.in")
    r = await client.post(A, json={**NEW, "name": "", "owner_phone": "12"}, headers=auth(s))
    assert r.status_code == 422
    r = await client.post(A, json={**NEW, "owner_phone": "12345678901234"}, headers=auth(s))
    assert r.json()["error"]["fields"] == {"owner_phone": "invalid"}
    r = await client.post(A, json=NEW, headers=auth(s))
    assert r.json()["error"]["fields"] == {"owner_email": "taken"}
    r = await client.post(A, json={**NEW, "owner_email": None, "plan": "nope"}, headers=auth(s))
    assert r.json()["error"]["fields"] == {"plan": "unknown"}
    first = (await client.post(A, json={**NEW, "owner_email": None}, headers=auth(s))).json()
    again = (await client.post(f"{A}/{first['company']['id']}/owner-invite", headers=auth(s))).json()
    assert again["invite_link"] != first["invite_link"]
    session = await phone_login(client, "+919876500200")
    assert len(session["invites"]) == 1  # the old link stopped working


async def test_edit_company(client):
    s, _ = await _setup(client)
    cid = (await client.post(A, json=NEW, headers=auth(s))).json()["company"]["id"]
    r = await client.patch(
        f"{A}/{cid}",
        json={"name": "CoolRight Services", "country": "US", "report_language": "en", "plan": "starter"},
        headers=auth(s),
    )
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["name"] == "CoolRight Services" and d["country"] == "US" and d["currency"] == "USD"
    assert d["plan"]["code"] == "starter" and d["report_language"] == "en"
    r = await client.patch(f"{A}/{cid}", json={"trade": "nope"}, headers=auth(s))
    assert r.status_code in (400, 422)
    async with SessionLocal() as db:
        row = (
            await db.execute(AuditLog.__table__.select().where(AuditLog.action == "staff.company_updated"))
        ).first()
    assert row.data["before"]["name"] == "CoolRight HVAC" and row.data["after"]["currency"] == "USD"


async def test_suspend_blocks_the_app_and_reactivate_restores(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, "+919800000001")
    s, _ = await _setup(client)
    cid = (await client.get("/api/v1/me", headers=auth(owner))).json()["company"]["id"]
    assert (await client.post(f"{A}/{cid}/suspend", json={"reason": "x"}, headers=auth(s))).status_code == 422
    r = await client.post(f"{A}/{cid}/suspend", json={"reason": "Unpaid for 3 months"}, headers=auth(s))
    assert (
        r.status_code == 200
        and r.json()["status"] == "suspended"
        and r.json()["suspend_reason"] == "Unpaid for 3 months"
    )
    # the app still says who you are, but refuses work
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    assert me["company"]["status"] == "suspended"
    r = await client.get("/api/v1/jobs", headers=auth(owner))
    assert r.status_code == 403 and r.json()["error"]["code"] == "company_suspended"
    r = await client.get("/api/v1/me/today", headers=auth(tech))
    assert r.json()["error"]["code"] == "company_suspended"
    assert (
        await client.post(f"{A}/{cid}/suspend", json={"reason": "Again"}, headers=auth(s))
    ).status_code == 409
    listed = (await client.get(A, params={"status": "suspended"}, headers=auth(s))).json()
    assert listed["total"] == 1

    r = await client.post(f"{A}/{cid}/reactivate", json={"reason": "Paid"}, headers=auth(s))
    assert r.json()["status"] == "trial" and r.json()["suspended_at"] is None
    assert (await client.get("/api/v1/jobs", headers=auth(owner))).status_code == 200


async def test_support_cannot_change(client):
    s, _ = await _setup(client)
    async with SessionLocal() as db:
        await db.execute(StaffUser.__table__.update().values(role="support"))
        await db.commit()
    assert (await client.post(A, json=NEW, headers=auth(s))).status_code == 403
