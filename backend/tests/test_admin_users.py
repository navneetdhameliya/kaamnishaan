"""A08 Users list, A09 User details, and turning a person off / signing them out."""

from app.core.db import SessionLocal
from app.models import AuditLog, StaffUser
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin"


async def _people(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, "+919800000001")
    await client.post(
        "/api/v1/invites",
        json={"phone": "+919800000002", "name": "Arjun", "role": "technician"},
        headers=auth(owner),
    )
    await make_owner(client, email="mike@coolright.com", company="CoolRight HVAC")
    staff, _ = await _setup(client)
    return owner, tech, staff


async def test_list_tabs_search_and_company_filter(client):
    _, _, s = await _people(client)
    d = (await client.get(f"{A}/users", headers=auth(s))).json()
    assert d["total"] == 4 and d["counts"] == {
        "all": 4,
        "technician": 2,
        "manager": 0,
        "owner": 2,
        "invited": 1,
    }
    arjun = next(i for i in d["items"] if i["name"] == "Arjun")
    assert arjun["login"] == "invited" and arjun["language"] is None and arjun["invited_at"]
    ravi = next(i for i in d["items"] if i["phone"] == "+919800000001")
    assert ravi["login"] == "phone" and ravi["company"] == "BrightAir" and ravi["on_job"] is False
    owner = next(i for i in d["items"] if i["email"] == "owner@brightair.in")
    assert owner["login"] == "email"

    r = await client.get(f"{A}/users", params={"role": "technician"}, headers=auth(s))
    assert r.json()["total"] == 2 and r.json()["counts"]["all"] == 4
    r = await client.get(f"{A}/users", params={"q": "coolright"}, headers=auth(s))
    assert [i["email"] for i in r.json()["items"]] == ["mike@coolright.com"]
    r = await client.get(f"{A}/users", params={"company": ravi["company_id"]}, headers=auth(s))
    assert r.json()["total"] == 3 and r.json()["company"]["label"] == "BrightAir"
    r = await client.get(f"{A}/users", params={"status": "invited"}, headers=auth(s))
    assert [i["name"] for i in r.json()["items"]] == ["Arjun"]


async def test_details(client):
    _, tech, s = await _people(client)
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    uid = me.get("id") or me["user"]["id"]
    r = await client.get(f"{A}/users/{uid}", headers=auth(s))
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["login"] == "phone" and d["status"] == "active" and d["active_sessions"] >= 1
    assert [c["company"] for c in d["companies"]] == ["BrightAir"] and d["companies"][0][
        "role"
    ] == "technician"
    assert d["jobs_30d"] == 0 and d["activity"] == [] or all(a["action"] for a in d["activity"])
    assert (
        await client.get(f"{A}/users/00000000-0000-0000-0000-000000000000", headers=auth(s))
    ).status_code == 404


async def test_deactivate_blocks_the_app_and_reactivate_lets_back_in(client):
    _, tech, s = await _people(client)
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    uid = me.get("id") or me["user"]["id"]
    assert (
        await client.post(f"{A}/users/{uid}/deactivate", json={"reason": ""}, headers=auth(s))
    ).status_code == 422
    r = await client.post(f"{A}/users/{uid}/deactivate", json={"reason": "Left the company"}, headers=auth(s))
    assert r.status_code == 200 and r.json()["status"] == "disabled" and r.json()["active_sessions"] == 0
    # the app no longer works for them, and they can't renew
    assert (await client.get("/api/v1/me", headers=auth(tech))).status_code == 401
    assert (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tech["refresh_token"]})
    ).status_code == 401
    listed = (await client.get(f"{A}/users", params={"status": "disabled"}, headers=auth(s))).json()
    assert listed["total"] == 1 and listed["items"][0]["status"] == "disabled"
    again = await client.post(f"{A}/users/{uid}/deactivate", json={"reason": "Twice"}, headers=auth(s))
    assert again.status_code == 409
    r = await client.post(f"{A}/users/{uid}/reactivate", json={"reason": "Came back"}, headers=auth(s))
    assert r.json()["status"] == "active"
    async with SessionLocal() as db:
        rows = (
            await db.execute(AuditLog.__table__.select().where(AuditLog.action.like("staff.user_%")))
        ).all()
    assert [r.action for r in rows] == ["staff.user_disabled", "staff.user_enabled"]
    assert rows[0].data["reason"] == "Left the company" and rows[0].staff_id is not None


async def test_sign_out_everywhere_and_support_cannot_act(client):
    owner, _, s = await _people(client)
    me = (await client.get("/api/v1/me", headers=auth(owner))).json()
    uid = me.get("id") or me["user"]["id"]
    r = await client.post(f"{A}/users/{uid}/sign-out", json={"reason": "Lost phone"}, headers=auth(s))
    assert r.status_code == 200 and r.json()["active_sessions"] == 0 and r.json()["status"] == "active"
    assert (await client.get("/api/v1/me", headers=auth(owner))).status_code == 401
    async with SessionLocal() as db:
        staff = (await db.execute(StaffUser.__table__.select())).first()
        await db.execute(StaffUser.__table__.update().where(StaffUser.id == staff.id).values(role="support"))
        await db.commit()
    r = await client.post(f"{A}/users/{uid}/sign-out", json={"reason": "Again"}, headers=auth(s))
    assert r.status_code == 403
