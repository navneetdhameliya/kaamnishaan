from sqlalchemy import update

from app.core.db import SessionLocal
from app.models import Company
from tests.conftest import auth, invite_and_join, last_sms, make_owner, phone_login

TECH = "+919812345678"
TECH2 = "+919898989898"
MANAGER = "+919811111111"


async def test_public_config_and_india_prices(client):
    cfg = (await client.get("/api/v1/config?locale=hi")).json()
    assert [lang["code"] for lang in cfg["languages"]] == ["en", "hi", "gu", "es", "fr"]
    assert cfg["countries"][0] == {"code": "IN", "name": "India", "dial_code": "+91", "flag": "🇮🇳"}
    assert {"key": "hvac", "name": "HVAC"} in cfg["trades"] or any(t["key"] == "hvac" for t in cfg["trades"])
    plans = (await client.get("/api/v1/plans")).json()
    prices = {p["code"]: p["price"] for p in plans["plans"]}
    assert prices["starter"] == {"amount": 49900, "currency": "INR"}
    assert prices["professional"] == {"amount": 129900, "currency": "INR"}
    assert prices["business"] == {"amount": 249900, "currency": "INR"}
    assert prices["enterprise"] is None  # contact us
    assert plans["trial_days"] == 14 and plans["credit_rules"]["ai_call"] == 10
    usd = (await client.get("/api/v1/plans?currency=USD")).json()
    assert {p["code"]: p["price"] for p in usd["plans"]}["starter"] == {"amount": 900, "currency": "USD"}


async def test_owner_creates_company_with_trial(client):
    owner = await make_owner(client)
    me = owner["user"]
    assert me["role"] == "owner"
    c = me["company"]
    assert (c["plan"], c["status"], c["currency"], c["trade"]) == ("professional", "trial", "INR", "hvac")
    assert "billing.manage" in me["permissions"] and "team.invite_manager" in me["permissions"]
    assert owner["needs"] == ["email_verification"]
    assert [x["active"] for x in owner["companies"]] == [True]


async def test_company_needs_a_known_trade(client):
    s = await phone_login(client, TECH)
    r = await client.post("/api/v1/companies", json={"name": "X", "trade": "plumbing"}, headers=auth(s))
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"trade": "unknown"}


async def test_no_company_yet(client):
    s = await phone_login(client, TECH)
    r = await client.get("/api/v1/company", headers=auth(s))
    assert r.status_code == 403


async def test_company_settings_owner_only_and_change_technician_permissions(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    assert "reports.share" not in tech["user"]["permissions"]
    assert "reviews.request" in tech["user"]["permissions"]
    r = await client.patch(
        "/api/v1/company/settings",
        json={"technicians_can_share": True, "report_language": "hi"},
        headers=auth(owner),
    )
    assert r.status_code == 200 and r.json()["report_language"] == "hi"
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    assert "reports.share" in me["permissions"]  # takes effect without signing in again
    denied = await client.patch(
        "/api/v1/company/settings", json={"technicians_can_share": False}, headers=auth(tech)
    )
    assert denied.status_code == 403
    assert (await client.get("/api/v1/team", headers=auth(tech))).status_code == 403


async def test_manager_reads_company_but_cannot_change_it(client):
    owner = await make_owner(client)
    mgr = await invite_and_join(client, owner, MANAGER, role="manager")
    assert (await client.get("/api/v1/company", headers=auth(mgr))).status_code == 200
    r = await client.patch("/api/v1/company", json={"name": "Mine now"}, headers=auth(mgr))
    assert r.status_code == 403 and r.json()["error"]["details"] == {"needs": "company.manage"}


async def test_invite_flow_sms_and_join(client):
    owner = await make_owner(client)
    r = await client.post(
        "/api/v1/invites",
        json={"phone": "98123 45678", "name": "Ravi Kumar", "role": "technician"},
        headers=auth(owner),
    )
    inv = r.json()
    assert r.status_code == 201 and inv["status"] == "pending" and inv["phone"] == TECH
    assert inv["link"].startswith("http://web.test/join/") and "BrightAir" in inv["sms_preview"]
    assert last_sms(TECH)["template"] == "invite"

    team = (await client.get("/api/v1/team", headers=auth(owner))).json()
    assert team["meta"]["counts"] == {"all": 2, "owner": 1, "manager": 0, "technician": 1, "invited": 1}
    ravi = next(m for m in team["data"] if m["role"] == "technician")
    assert (ravi["name"], ravi["status"], ravi["invite_id"]) == ("Ravi Kumar", "invited", inv["id"])

    s = await phone_login(client, TECH)
    assert s["needs"] == ["profile", "create_or_join_company"]
    assert s["invites"][0]["company"]["name"] == "BrightAir"
    assert s["invites"][0]["invited_by"]["name"] == "Asha Patel"
    mine = (await client.get("/api/v1/invites/mine", headers=auth(s))).json()
    assert mine["meta"]["counts"] == {"pending": 1, "expired": 0}
    joined = await client.post(f"/api/v1/invites/{inv['id']}/accept", headers=auth(s))
    assert joined.status_code == 200
    assert (joined.json()["role"], joined.json()["name"]) == ("technician", "Ravi Kumar")
    again = await client.post(f"/api/v1/invites/{inv['id']}/accept", headers=auth(s))
    assert again.status_code == 410

    team = (await client.get("/api/v1/team?role=technician", headers=auth(owner))).json()
    assert [(m["status"], m["invite_id"]) for m in team["data"]] == [("active", None)]


async def test_decline_revoke_and_resend(client):
    owner = await make_owner(client)
    r = await client.post(
        "/api/v1/invites", json={"phone": TECH, "name": "R", "role": "technician"}, headers=auth(owner)
    )
    inv_id = r.json()["id"]
    too_soon = await client.post(f"/api/v1/invites/{inv_id}/resend", headers=auth(owner))
    assert too_soon.status_code == 429
    s = await phone_login(client, TECH)
    assert (await client.post(f"/api/v1/invites/{inv_id}/decline", headers=auth(s))).status_code == 204
    team = (await client.get("/api/v1/team", headers=auth(owner))).json()
    assert team["meta"]["counts"]["technician"] == 0  # the seat is free again

    r = await client.post(
        "/api/v1/invites", json={"phone": TECH2, "name": "S", "role": "technician"}, headers=auth(owner)
    )
    inv2 = r.json()["id"]
    assert (await client.delete(f"/api/v1/invites/{inv2}", headers=auth(owner))).status_code == 204
    s2 = await phone_login(client, TECH2)
    assert s2["invites"] == []
    r = await client.post(f"/api/v1/invites/{inv2}/accept", headers=auth(s2))
    assert r.status_code == 410 and r.json()["error"]["code"] == "invite_revoked"


async def test_invite_for_someone_else_is_hidden(client):
    owner = await make_owner(client)
    r = await client.post(
        "/api/v1/invites", json={"phone": TECH, "name": "R", "role": "technician"}, headers=auth(owner)
    )
    stranger = await phone_login(client, TECH2)
    resp = await client.post(f"/api/v1/invites/{r.json()['id']}/accept", headers=auth(stranger))
    assert resp.status_code == 404


async def test_duplicate_invite_and_seat_limit(client):
    owner = await make_owner(client)
    body = {"phone": TECH, "name": "R", "role": "technician"}
    assert (await client.post("/api/v1/invites", json=body, headers=auth(owner))).status_code == 201
    dup = await client.post("/api/v1/invites", json=body, headers=auth(owner))
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "phone_in_team"
    assert dup.json()["error"]["details"]["existing_member"]["status"] == "invited"
    assert dup.json()["error"]["details"]["existing_member"]["name"] == "R"  # "Already in your team (R)"

    async with SessionLocal() as db:  # Free plan: 1 technician seat
        await db.execute(update(Company).values(plan_code="free"))
        await db.commit()
    full = await client.post("/api/v1/invites", json={**body, "phone": TECH2}, headers=auth(owner))
    assert full.status_code == 402
    assert full.json()["error"]["code"] == "seat_limit_reached"
    assert full.json()["error"]["details"] == {"limit": 1, "used": 1, "plan": "free"}


async def test_team_screen_shows_today_and_waiting_invites(client):
    """M40: jobs today, who is on a job, when the invite SMS went, and the SMS preview."""
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    await client.post(
        "/api/v1/invites", json={"phone": TECH2, "name": "Arjun", "role": "technician"}, headers=auth(owner)
    )
    c = (
        await client.post(
            "/api/v1/customers",
            json={"name": "Clinic", "site": {"address_line1": "4 Lake Road"}},
            headers=auth(owner),
        )
    ).json()
    from datetime import UTC, datetime, timedelta

    soon = (datetime.now(UTC) + timedelta(minutes=5)).isoformat()
    j = (
        await client.post(
            "/api/v1/jobs",
            json={
                "title": "AC",
                "customer_id": c["id"],
                "scheduled_at": soon,
                "assigned_to": tech["user"]["id"],
            },
            headers=auth(owner),
        )
    ).json()
    await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    team = (await client.get("/api/v1/team", headers=auth(owner))).json()["data"]
    by_role = {(m["role"], m["status"]): m for m in team}
    owner_row, active, waiting = (
        by_role[("owner", "active")],
        by_role[("technician", "active")],
        by_role[("technician", "invited")],
    )
    assert owner_row["live_status"] is None and owner_row["invited_at"] is None
    assert (active["live_status"], active["jobs_today"]) == ("on_job", 1)
    assert waiting["name"] == "Arjun" and waiting["invited_at"] and waiting["invite_id"]
    text = (await client.get("/api/v1/invites/preview", headers=auth(owner))).json()["text"]
    assert "invited you" in text and "/join/" in text


async def test_manager_limits(client):
    owner = await make_owner(client)
    mgr = await invite_and_join(client, owner, MANAGER, role="manager")
    r = await client.post(
        "/api/v1/invites", json={"phone": TECH2, "name": "M2", "role": "manager"}, headers=auth(mgr)
    )
    assert r.status_code == 403
    tech = await invite_and_join(client, mgr, TECH)  # managers can invite technicians
    tech_id = tech["user"]["id"]
    promote = await client.patch(f"/api/v1/team/{tech_id}", json={"role": "manager"}, headers=auth(mgr))
    assert promote.status_code == 403
    owner_id = owner["user"]["id"]
    assert (await client.delete(f"/api/v1/team/{owner_id}", headers=auth(mgr))).status_code == 403
    mgr_id = mgr["user"]["id"]
    assert (await client.delete(f"/api/v1/team/{mgr_id}", headers=auth(mgr))).status_code == 403  # self
    ok = await client.patch(f"/api/v1/team/{tech_id}", json={"role": "manager"}, headers=auth(owner))
    assert ok.status_code == 200 and ok.json()["role"] == "manager"


async def test_removed_member_loses_access_at_once(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    assert (await client.get("/api/v1/company", headers=auth(tech))).status_code == 403  # technicians: no
    assert (await client.get("/api/v1/me", headers=auth(tech))).json()["company"]["name"] == "BrightAir"
    assert (await client.delete(f"/api/v1/team/{tech['user']['id']}", headers=auth(owner))).status_code == 204
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    assert (me["company"], me["role"], me["permissions"]) == (None, None, [])
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": tech["refresh_token"]})
    assert r.json()["needs"] == ["create_or_join_company"] and r.json()["user"]["company"] is None


async def test_one_person_in_two_companies(client):
    a = await make_owner(client, "a@brightair.in", "BrightAir")
    b = await make_owner(client, "b@coolfix.in", "CoolFix")
    await invite_and_join(client, a, TECH)
    tech = await invite_and_join(client, b, TECH)
    assert tech["user"]["company"]["name"] == "CoolFix"
    names = {c["name"]: c["active"] for c in tech["companies"]}
    assert names == {"BrightAir": False, "CoolFix": True}
    a_id = next(c["company_id"] for c in tech["companies"] if c["name"] == "BrightAir")
    sw = await client.post("/api/v1/auth/switch-company", json={"company_id": a_id}, headers=auth(tech))
    assert sw.status_code == 200 and sw.json()["user"]["company"]["name"] == "BrightAir"
    mine = (await client.get("/api/v1/me/companies", headers=auth(sw.json()))).json()
    assert mine["meta"]["counts"]["all"] == 2
    # a fresh login on a new phone remembers the last company
    again = await phone_login(client, TECH)
    assert again["user"]["company"]["name"] == "BrightAir"


async def test_tenant_isolation(client):
    a = await make_owner(client, "a@brightair.in", "BrightAir")
    b = await make_owner(client, "b@coolfix.in", "CoolFix")
    b_tech = await invite_and_join(client, b, TECH)
    r = await client.post(
        "/api/v1/invites", json={"phone": TECH2, "name": "S", "role": "technician"}, headers=auth(b)
    )
    b_invite = r.json()["id"]
    b_tech_id = b_tech["user"]["id"]
    # company A can't see, change or remove company B's people or invites
    assert (await client.get(f"/api/v1/team/{b_tech_id}", headers=auth(a))).status_code == 404
    assert (
        await client.patch(f"/api/v1/team/{b_tech_id}", json={"role": "manager"}, headers=auth(a))
    ).status_code == 404
    assert (await client.delete(f"/api/v1/team/{b_tech_id}", headers=auth(a))).status_code == 404
    assert (await client.delete(f"/api/v1/invites/{b_invite}", headers=auth(a))).status_code == 404
    assert (await client.post(f"/api/v1/invites/{b_invite}/resend", headers=auth(a))).status_code == 404
    a_team = (await client.get("/api/v1/team", headers=auth(a))).json()
    assert [m["role"] for m in a_team["data"]] == ["owner"]
    b_id = b["user"]["company"]["id"]
    sw = await client.post("/api/v1/auth/switch-company", json={"company_id": b_id}, headers=auth(a))
    assert sw.status_code == 403 and sw.json()["error"]["code"] == "not_a_member"


async def test_audit_log_records_changes(client):
    from sqlalchemy import select

    from app.models import AuditLog

    owner = await make_owner(client)
    await client.patch("/api/v1/company", json={"name": "BrightAir Services"}, headers=auth(owner))
    async with SessionLocal() as db:
        row = (await db.execute(select(AuditLog).where(AuditLog.action == "company.updated"))).scalar_one()
    assert row.data == {"before": {"name": "BrightAir"}, "after": {"name": "BrightAir Services"}}
    assert row.actor_role == "owner"


async def test_plans_for_the_website(client):
    usd = (await client.get("/api/v1/plans?currency=USD")).json()
    by = {p["code"]: p for p in usd["plans"]}
    assert [p["code"] for p in usd["plans"]] == ["free", "starter", "professional", "business", "enterprise"]
    assert by["starter"]["annual_price"] == {"amount": 9000, "currency": "USD"}  # 2 months free
    assert by["free"]["annual_price"] is None and by["enterprise"]["annual_price"] is None
    assert "branded_pdf" not in by["free"]["features"] and "branded_pdf" in by["starter"]["features"]
    assert "manager_approvals" in by["professional"]["features"]
    assert "custom_checklists" in by["business"]["features"] and "sso_audit" not in by["business"]["features"]
    assert "sso_audit" in by["enterprise"]["features"]
    assert [by[c]["support"] for c in by] == ["email", "email", "email_chat", "priority", "dedicated"]
    assert by["professional"]["most_popular"] is True


async def test_config_counts_ready_checklists_per_trade(client):
    trades = {t["key"]: t for t in (await client.get("/api/v1/config")).json()["trades"]}
    assert trades["hvac"]["checklists"] > 0  # the seeded HVAC templates
    assert trades["roofing"]["checklists"] == 0
