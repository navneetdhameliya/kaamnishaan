"""A31 Audit logs: readable actors and targets, filters, CSV."""

from tests.conftest import auth, invite_and_join, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin"


async def _activity(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, "+919800000001")
    await client.post(
        f"{A}/auth/login", json={"email": "ghost@x.com", "password": "Wrong1234", "code": "000000"}
    )
    staff, _ = await _setup(client)
    me = (await client.get("/api/v1/me", headers=auth(tech))).json()
    uid = me.get("id") or me["user"]["id"]
    await client.post(f"{A}/users/{uid}/deactivate", json={"reason": "Left"}, headers=auth(staff))
    return staff


async def test_list_actors_targets_and_groups(client):
    s = await _activity(client)
    r = await client.get(f"{A}/audit-logs", headers=auth(s))
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    actions = [i["action"] for i in items]
    assert "company.created" in actions and "team.joined" in actions and "staff.user_disabled" in actions
    off = next(i for i in items if i["action"] == "staff.user_disabled")
    assert off["actor"] == {
        "kind": "staff",
        "id": off["actor"]["id"],
        "name": "Navneet Dhameliya",
        "role": "super_admin",
    }
    assert off["target"] == "Ravi Kumar" and off["group"] == "admin" and off["data"]["reason"] == "Left"
    ghost = next(i for i in items if i["action"] == "staff.login_failed")
    assert (
        ghost["actor"]["kind"] == "unknown"
        and ghost["target"] == "ghost@x.com"
        and ghost["group"] == "security"
    )
    made = next(i for i in items if i["action"] == "company.created")
    assert made["actor"]["kind"] == "user" and made["company"] == "BrightAir" and made["group"] == "company"
    # newest first
    assert items[0]["at"] >= items[-1]["at"]


async def test_filters_and_search(client):
    s = await _activity(client)
    staff_only = (await client.get(f"{A}/audit-logs", params={"actor": "staff"}, headers=auth(s))).json()[
        "items"
    ]
    assert staff_only and all(i["actor"]["kind"] == "staff" for i in staff_only)
    sec = (await client.get(f"{A}/audit-logs", params={"group": "security"}, headers=auth(s))).json()["items"]
    assert sec and all(i["group"] == "security" for i in sec)
    found = (await client.get(f"{A}/audit-logs", params={"q": "ghost@x"}, headers=auth(s))).json()
    assert found["total"] == 1
    allrows = (await client.get(f"{A}/audit-logs", headers=auth(s))).json()["items"]
    cid = next(i["company_id"] for i in allrows if i["company_id"])
    one = (await client.get(f"{A}/audit-logs", params={"company": cid}, headers=auth(s))).json()
    assert one["company"]["label"] == "BrightAir" and all(i["company_id"] == cid for i in one["items"])
    assert (await client.get(f"{A}/audit-logs", params={"days": 3}, headers=auth(s))).status_code == 422
    for d in (1, 30, 90, 365):
        assert (await client.get(f"{A}/audit-logs", params={"days": d}, headers=auth(s))).status_code == 200


async def test_csv_is_audited_and_staff_only(client):
    s = await _activity(client)
    r = await client.get(f"{A}/audit-logs.csv", params={"group": "admin"}, headers=auth(s))
    assert r.status_code == 200 and r.text.lstrip("﻿").startswith("Time (UTC),Actor")
    after = (await client.get(f"{A}/audit-logs", params={"q": "audit_logs"}, headers=auth(s))).json()["items"]
    assert after and after[0]["action"] == "staff.export"
    owner = await make_owner(client, email="x@y.in", company="Y")
    assert (await client.get(f"{A}/audit-logs", headers=auth(owner))).status_code == 401
