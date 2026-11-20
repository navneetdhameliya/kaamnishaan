"""A10 Roles and permissions: the role table comes from the live rules; super admins manage staff accounts."""

from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import AuditLog, StaffSession
from tests.conftest import auth, token_from
from tests.test_admin_auth import PW, _code, _setup
from tests.test_admin_auth import A as ADMIN

A = f"{ADMIN}/roles"
S = f"{ADMIN}/staff"


async def _join(client, link: str) -> dict:
    token = token_from(link)
    info = (await client.get(f"{ADMIN}/auth/setup", params={"token": token})).json()
    r = await client.post(
        f"{ADMIN}/auth/setup", json={"token": token, "password": PW, "code": _code(info["secret"])}
    )
    assert r.status_code == 200, r.text
    return r.json()


async def test_table_follows_the_rules_the_server_enforces(client):
    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    rows = {r["key"]: r["cells"] for r in d["matrix"]}
    assert list(rows["jobs"]) == ["super_admin", "owner", "manager", "technician", "customer"]
    assert rows["platform"]["super_admin"]["value"] == "yes" and rows["platform"]["owner"]["value"] == "no"
    assert rows["company"]["owner"]["value"] == "yes" and rows["company"]["manager"]["value"] == "no"
    assert rows["users"]["manager"] == {"value": "partial", "note": "technicians"}
    assert rows["jobs"]["technician"] == {"value": "partial", "note": "quick_job"}
    assert rows["capture"]["technician"]["value"] == "yes"
    assert rows["approve"]["technician"]["value"] == "no" and rows["approve"]["manager"]["value"] == "yes"
    assert rows["share"]["technician"] == {"value": "partial", "note": "if_allowed"}
    assert rows["view_report"]["customer"] == {"value": "partial", "note": "secure_link"}
    assert rows["audit"]["owner"] == {"value": "partial", "note": "own_company"}
    assert rows["audit"]["manager"]["value"] == "no"
    assert [r["key"] for r in d["staff_matrix"]] == ["look", "change", "platform"]
    assert d["can_act"] is True and d["staff"][0]["me"] is True and d["staff"][0]["status"] == "active"


async def test_invite_change_role_turn_off_and_new_link(client):
    s, _ = await _setup(client)
    r = await client.post(S, json={"name": "Asha Patel", "email": "Asha@Example.com", "role": "support"},
                          headers=auth(s))  # fmt: skip
    assert r.status_code == 201, r.text
    asha = r.json()["staff"]
    assert asha["email"] == "asha@example.com" and asha["status"] == "invited"
    assert (await client.post(S, json={"name": "Asha", "email": "asha@example.com", "role": "admin"},
                              headers=auth(s))).json()["error"]["code"] == "staff_exists"  # fmt: skip

    a = await _join(client, r.json()["setup_link"])
    # support can look but not manage staff
    d = (await client.get(A, headers=auth(a))).json()
    assert d["can_act"] is False
    no = await client.patch(f"{S}/{d['staff'][0]['id']}", json={"role": "support"}, headers=auth(a))
    assert no.status_code == 403

    r = await client.patch(f"{S}/{asha['id']}", json={"role": "admin"}, headers=auth(s))
    assert r.json()["role"] == "admin"
    r = await client.patch(f"{S}/{asha['id']}", json={"active": False}, headers=auth(s))
    assert r.json()["status"] == "disabled"
    async with SessionLocal() as db:
        left = (
            (await db.execute(select(StaffSession).where(StaffSession.revoked_at.is_(None)))).scalars().all()
        )
        assert all(str(x.staff_id) != asha["id"] for x in left)  # signed out at once
        acts = (await db.execute(select(AuditLog.action))).scalars().all()
        assert {"staff.role_changed", "staff.disabled"} <= set(acts)
    assert (await client.get(A, headers=auth(a))).status_code == 401
    assert (await client.post(f"{S}/{asha['id']}/setup-link", headers=auth(s))).json()["error"]["code"] == (
        "staff_disabled"
    )

    r = await client.patch(f"{S}/{asha['id']}", json={"active": True}, headers=auth(s))
    assert r.json()["status"] == "active"
    r = await client.post(f"{S}/{asha['id']}/setup-link", headers=auth(s))
    assert (
        r.status_code == 200
        and "token=" in r.json()["setup_link"]
        and r.json()["staff"]["status"] == "invited"
    )


async def test_safeguards(client):
    s, _ = await _setup(client)
    me = (await client.get(A, headers=auth(s))).json()["staff"][0]["id"]
    r = await client.patch(f"{S}/{me}", json={"role": "admin"}, headers=auth(s))
    assert r.status_code == 409 and r.json()["error"]["code"] == "not_yourself"
    assert (await client.post(f"{S}/{me}/setup-link", headers=auth(s))).status_code == 409

    # demoting another super admin works; then they lose staff management
    r = await client.post(S, json={"name": "Ravi Shah", "email": "ravi@example.com", "role": "super_admin"},
                          headers=auth(s))  # fmt: skip
    ravi = await _join(client, r.json()["setup_link"])
    ravi_id = r.json()["staff"]["id"]
    assert (await client.patch(f"{S}/{ravi_id}", json={"role": "admin"}, headers=auth(s))).status_code == 200
    r = await client.patch(f"{S}/{me}", json={"active": False}, headers=auth(ravi))
    assert r.status_code == 403  # ravi is an admin now
    r = await client.post(S, json={"name": "x", "email": "bad", "role": "owner"}, headers=auth(s))
    assert r.status_code == 422
