"""D-130: deleting your own account, and handing a company to a new owner first."""

from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import AuditLog, Company, User
from tests.conftest import auth, invite_and_join, make_owner, phone_login

ME = "/api/v1/me"
PHONE = "+919876500001"


async def test_technician_deletes_account(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, PHONE)
    job = await client.post("/api/v1/jobs", headers=auth(owner), json={
        "customer": {"name": "Mehta Clinic", "address": "12 MG Road, Surat"},
        "title": "AC service", "assigned_to": tech["user"]["id"],
    })  # fmt: skip
    assert job.status_code == 201, job.text

    chk = (await client.get(f"{ME}/deletion", headers=auth(tech))).json()
    assert chk["can_delete"] and chk["open_jobs"] == 1
    assert chk["companies"][0]["role"] == "technician" and not chk["companies"][0]["closes"]

    bad = await client.post(f"{ME}/delete", json={"confirm": False}, headers=auth(tech))
    assert bad.status_code == 422
    r = await client.post(
        f"{ME}/delete", json={"confirm": True, "reason": "Changed jobs"}, headers=auth(tech)
    )
    assert r.status_code == 204
    assert (await client.get(ME, headers=auth(tech))).status_code == 401
    assert (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tech["refresh_token"]})
    ).status_code == 401

    async with SessionLocal() as db:
        u = await db.get(User, tech["user"]["id"])
        assert u.name == "Deleted user" and u.phone is None and u.deleted_at and u.status == "disabled"
        acts = {a for (a,) in (await db.execute(select(AuditLog.action))).all()}
        assert {"account.deleted", "team.left"} <= acts
    j = (await client.get(f"/api/v1/jobs/{job.json()['id']}", headers=auth(owner))).json()
    assert j["status"] == "unassigned" and j.get("assignee") is None
    team = (await client.get("/api/v1/team", headers=auth(owner))).json()["data"]
    assert [m["role"] for m in team] == ["owner"]

    # the same phone can start again as a new person
    again = await phone_login(client, PHONE)
    assert again["user"]["id"] != tech["user"]["id"] and again["invites"] == []


async def test_owner_must_hand_over_first(client):
    owner = await make_owner(client)
    mgr = await invite_and_join(client, owner, PHONE, role="manager")
    chk = (await client.get(f"{ME}/deletion", headers=auth(owner))).json()
    c = chk["companies"][0]
    assert not chk["can_delete"] and c["needs_new_owner"] and c["candidates"][0]["role"] == "manager"
    r = await client.post(f"{ME}/delete", json={"confirm": True}, headers=auth(owner))
    assert r.status_code == 409 and r.json()["error"]["code"] == "owner_has_team"

    # only the owner hands over, and only to someone in the team
    assert (
        await client.post("/api/v1/company/owner", json={"user_id": owner["user"]["id"]}, headers=auth(mgr))
    ).status_code == 403
    assert (
        await client.post("/api/v1/company/owner", json={"user_id": owner["user"]["id"]}, headers=auth(owner))
    ).status_code == 400
    r = await client.post("/api/v1/company/owner", json={"user_id": mgr["user"]["id"]}, headers=auth(owner))
    assert r.status_code == 200 and r.json()["role"] == "manager"
    assert (await client.get(ME, headers=auth(mgr))).json()["role"] == "owner"

    assert (await client.get(f"{ME}/deletion", headers=auth(owner))).json()["can_delete"]
    assert (await client.post(f"{ME}/delete", json={"confirm": True}, headers=auth(owner))).status_code == 204
    assert (await client.get("/api/v1/company", headers=auth(mgr))).json()["status"] != "cancelled"


async def test_only_member_closes_company(client):
    owner = await make_owner(client)
    chk = (await client.get(f"{ME}/deletion", headers=auth(owner))).json()
    assert chk["can_delete"] and chk["companies"][0]["closes"]
    assert (await client.post(f"{ME}/delete", json={"confirm": True}, headers=auth(owner))).status_code == 204
    async with SessionLocal() as db:
        c = (await db.execute(select(Company))).scalar_one()
        assert c.status == "cancelled"
    # the email is free again
    again = await make_owner(client)
    assert again["user"]["email"] == "owner@brightair.in"
