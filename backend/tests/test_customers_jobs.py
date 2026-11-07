import uuid
from datetime import UTC, datetime, timedelta

from tests.conftest import auth, invite_and_join, make_owner

TECH = "+919812345678"
TECH2 = "+919898989898"
MANAGER = "+919811111111"


def at(hours_from_now: float = 1) -> str:
    return (datetime.now(UTC) + timedelta(hours=hours_from_now)).isoformat()


async def new_customer(client, who, name="Sharma Textiles", **extra):
    body = {
        "name": name,
        "site": {"label": "Main office", "address_line1": "12 Ring Road", "city": "Surat"},
        "contact": {"name": "Mr Sharma", "phone": "98250 11111", "email": "Sharma@x.in"},
        **extra,
    }
    r = await client.post("/api/v1/customers", json=body, headers=auth(who))
    assert r.status_code in (200, 201), r.text
    return r.json()


async def new_job(client, who, customer, **extra):
    body = {
        "title": "AC not cooling",
        "customer_id": customer["id"],
        "site_id": customer["sites"][0]["id"],
        **extra,
    }
    r = await client.post("/api/v1/jobs", json=body, headers=auth(who))
    assert r.status_code in (200, 201), r.text
    return r.json()


# ---- customers -------------------------------------------------------------------------------
async def test_customer_with_first_site_and_contact(client):
    owner = await make_owner(client)
    c = await new_customer(client, owner)
    assert c["contacts"][0]["phone"] == "+919825011111" and c["contacts"][0]["is_primary"]
    assert c["contacts"][0]["email"] == "sharma@x.in"
    assert c["sites"][0]["country"] == "IN" and c["job_count"] == 0 and c["version"] == 1

    site_id = c["sites"][0]["id"]
    r = await client.post(
        f"/api/v1/customers/{c['id']}/sites/{site_id}/equipment",
        json={"type": "Split AC", "brand": "Voltas", "capacity": "1.5 ton", "location": "Cabin 2"},
        headers=auth(owner),
    )
    assert r.status_code == 201
    r = await client.post(
        f"/api/v1/customers/{c['id']}/contacts",
        json={"name": "Accounts", "is_primary": True},
        headers=auth(owner),
    )
    assert r.status_code == 201
    detail = (await client.get(f"/api/v1/customers/{c['id']}", headers=auth(owner))).json()
    assert [x["name"] for x in detail["contacts"]] == ["Accounts", "Mr Sharma"]  # only one primary
    assert [x["is_primary"] for x in detail["contacts"]] == [True, False]
    assert detail["sites"][0]["equipment"][0]["capacity"] == "1.5 ton"
    assert detail["version"] == 3  # each change bumps the version


async def test_customer_search_and_paging(client):
    owner = await make_owner(client)
    for n in ("Apex Hotel", "Blue Mall", "City Hospital"):
        await new_customer(client, owner, name=n)
    page1 = (await client.get("/api/v1/customers?limit=2", headers=auth(owner))).json()
    assert [c["name"] for c in page1["data"]] == ["Apex Hotel", "Blue Mall"]
    assert page1["meta"]["counts"] == {"all": 3} and page1["meta"]["next_cursor"]
    page2 = (
        await client.get(
            f"/api/v1/customers?limit=2&cursor={page1['meta']['next_cursor']}", headers=auth(owner)
        )
    ).json()
    assert [c["name"] for c in page2["data"]] == ["City Hospital"] and page2["meta"]["next_cursor"] is None
    by_phone = (await client.get("/api/v1/customers?q=9825011111", headers=auth(owner))).json()
    assert by_phone["meta"]["counts"]["all"] == 3
    by_name = (await client.get("/api/v1/customers?q=mall", headers=auth(owner))).json()
    assert [c["name"] for c in by_name["data"]] == ["Blue Mall"]
    assert by_name["data"][0]["primary_contact"] == {"name": "Mr Sharma", "phone": "+919825011111"}
    assert by_name["data"][0]["city"] == "Surat"


async def test_same_client_uuid_returns_first_customer(client):
    owner = await make_owner(client)
    key = str(uuid.uuid4())
    a = await new_customer(client, owner, client_uuid=key)
    r = await client.post(
        "/api/v1/customers", json={"name": "Again", "client_uuid": key}, headers=auth(owner)
    )
    assert r.status_code == 200 and r.json()["id"] == a["id"] and r.json()["name"] == "Sharma Textiles"


async def test_stale_edit_gets_conflict_with_server_copy(client):
    owner = await make_owner(client)
    c = await new_customer(client, owner)
    ok = await client.patch(
        f"/api/v1/customers/{c['id']}",
        json={"notes": "Gate code 4411"},
        headers={**auth(owner), "If-Match": "1"},
    )
    assert ok.status_code == 200 and ok.json()["version"] == 2
    stale = await client.patch(
        f"/api/v1/customers/{c['id']}", json={"name": "Old idea"}, headers={**auth(owner), "If-Match": "1"}
    )
    assert stale.status_code == 409 and stale.json()["error"]["code"] == "version_conflict"
    assert stale.json()["error"]["details"]["server"]["notes"] == "Gate code 4411"


async def test_technician_reads_only_customers_of_their_jobs(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    mine = await new_customer(client, owner, name="Mine")
    other = await new_customer(client, owner, name="Other")
    await new_job(client, owner, mine, assigned_to=tech["user"]["id"])
    assert (await client.get("/api/v1/customers", headers=auth(tech))).status_code == 403
    assert (await client.get(f"/api/v1/customers/{mine['id']}", headers=auth(tech))).status_code == 200
    assert (await client.get(f"/api/v1/customers/{other['id']}", headers=auth(tech))).status_code == 404
    r = await client.patch(f"/api/v1/customers/{mine['id']}", json={"name": "X"}, headers=auth(tech))
    assert r.status_code == 403


# ---- jobs ------------------------------------------------------------------------------------
async def test_job_lifecycle_and_timeline(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, scheduled_at=at(1))
    assert (j["number"], j["status"], j["assignee"]) == ("J-1001", "unassigned", None)
    assert j["site"]["address"] == "12 Ring Road" and j["customer"]["name"] == "Sharma Textiles"
    assert set(j["actions"]) == {"edit", "assign", "cancel", "delete"}
    assert (await new_job(client, owner, c))["number"] == "J-1002"

    r = await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": tech["user"]["id"]}, headers=auth(owner)
    )
    assert (
        r.status_code == 200
        and r.json()["status"] == "assigned"
        and r.json()["assignee"]["name"] == "Ravi Kumar"
    )

    tj = (await client.get(f"/api/v1/jobs/{j['id']}", headers=auth(tech))).json()
    assert tj["actions"] == ["start"]
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/start", json={"lat": 21.17, "lng": 72.83}, headers=auth(tech)
    )
    assert r.status_code == 200 and r.json()["status"] == "in_progress" and r.json()["started_at"]
    again = await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    assert again.status_code == 200  # a retry from the offline queue is safe

    late = await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": None}, headers=auth(owner)
    )
    assert late.status_code == 409 and late.json()["error"]["code"] == "job_already_started"
    gone = await client.delete(f"/api/v1/jobs/{j['id']}", headers=auth(owner))
    assert gone.status_code == 409  # started jobs are cancelled, not deleted
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/cancel", json={"reason": "Customer not home"}, headers=auth(owner)
    )
    assert r.json()["status"] == "cancelled" and r.json()["cancel_reason"] == "Customer not home"
    edit = await client.patch(f"/api/v1/jobs/{j['id']}", json={"title": "x"}, headers=auth(owner))
    assert edit.status_code == 409 and edit.json()["error"]["code"] == "job_closed"

    tl = (await client.get(f"/api/v1/jobs/{j['id']}/timeline", headers=auth(owner))).json()
    assert [(e["type"], e["to_status"]) for e in tl["data"]] == [
        ("created", "unassigned"), ("assigned", "assigned"), ("started", "in_progress"), ("cancelled", "cancelled"),
    ]  # fmt: skip
    assert tl["data"][2]["actor"]["name"] == "Ravi Kumar" and tl["data"][2]["data"] == {
        "lat": 21.17,
        "lng": 72.83,
    }


async def test_only_the_assigned_person_starts_a_job(client):
    owner = await make_owner(client)
    t1 = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=t1["user"]["id"])
    r = await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(owner))
    assert r.status_code == 403 and r.json()["error"]["code"] == "job_not_assigned_to_you"


async def test_cannot_assign_invited_or_non_technicians(client):
    owner = await make_owner(client)
    r = await client.post(
        "/api/v1/invites", json={"phone": TECH2, "name": "New", "role": "technician"}, headers=auth(owner)
    )
    pending_id = r.json()["user_id"]
    mgr = await invite_and_join(client, owner, MANAGER, role="manager")
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c)
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": pending_id}, headers=auth(owner)
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "invite_pending"
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": mgr["user"]["id"]}, headers=auth(owner)
    )
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"technician_id": "unknown"}
    lst = (await client.get(f"/api/v1/jobs/{j['id']}/assignable-technicians", headers=auth(owner))).json()
    assert [(t["status"], t["disabled_reason"]) for t in lst["data"]] == [("invited", "invite_pending")]


async def test_assignable_technicians_show_load(client):
    owner = await make_owner(client)
    t1 = await invite_and_join(client, owner, TECH)
    await invite_and_join(client, owner, TECH2)
    c = await new_customer(client, owner)
    for _ in range(2):
        await new_job(client, owner, c, assigned_to=t1["user"]["id"], scheduled_at=at(1))
    j = await new_job(client, owner, c, scheduled_at=at(2))
    lst = (await client.get(f"/api/v1/jobs/{j['id']}/assignable-technicians", headers=auth(owner))).json()
    assert [t["jobs_today"] for t in lst["data"]] == [0, 2]  # least busy first
    assert all(t["capacity"] == 6 and t["available"] for t in lst["data"])


async def test_job_list_filters_and_tab_counts(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    a = await new_job(
        client, owner, c, title="Gas refill", scheduled_at=at(1), assigned_to=tech["user"]["id"]
    )
    await new_job(client, owner, c, title="Duct clean", scheduled_at=at(2))
    await new_job(client, owner, c, title="Next week", scheduled_at=at(24 * 8))
    await client.post(f"/api/v1/jobs/{a['id']}/start", headers=auth(tech))

    all_ = (await client.get("/api/v1/jobs", headers=auth(owner))).json()
    assert all_["meta"]["counts"]["all"] == 3 and all_["meta"]["counts"]["in_progress"] == 1
    only = (await client.get("/api/v1/jobs?status=unassigned", headers=auth(owner))).json()
    assert [j["title"] for j in only["data"]] == ["Duct clean", "Next week"]
    assert only["meta"]["counts"]["all"] == 3  # tab counts ignore the status filter
    un = (await client.get("/api/v1/jobs?unassigned=true", headers=auth(owner))).json()
    assert un["meta"]["counts"]["all"] == 2
    by_num = (await client.get(f"/api/v1/jobs?q={a['number']}", headers=auth(owner))).json()
    assert [j["id"] for j in by_num["data"]] == [a["id"]]
    by_cust = (await client.get("/api/v1/jobs?q=sharma", headers=auth(owner))).json()
    assert len(by_cust["data"]) == 3
    week = (
        await client.get(f"/api/v1/jobs?date={datetime.now(UTC).date()}&range=week", headers=auth(owner))
    ).json()
    assert "Next week" not in [j["title"] for j in week["data"]]

    mine = (await client.get("/api/v1/jobs", headers=auth(tech))).json()
    assert [j["title"] for j in mine["data"]] == ["Gas refill"] and mine["meta"]["counts"]["all"] == 1
    cj = (await client.get(f"/api/v1/customers/{c['id']}/jobs", headers=auth(owner))).json()
    assert cj["meta"]["counts"]["all"] == 3


async def test_technician_quick_job(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    r = await client.post(
        "/api/v1/jobs",
        json={
            "title": "Walk-in repair",
            "customer": {"name": "Raju Tea Stall", "phone": "9825022222", "address": "Station Rd"},
        },
        headers=auth(tech),
    )
    j = r.json()
    assert r.status_code == 201 and j["is_quick_job"] and j["status"] == "assigned"
    assert j["assignee"]["id"] == tech["user"]["id"] and j["site"]["address"] == "Station Rd"
    assert set(j["actions"]) == {"edit", "start"}
    # a technician can't make a job for someone else, or touch another person's job
    other = await invite_and_join(client, owner, TECH2)
    r = await client.post(
        "/api/v1/jobs", json={"title": "x", "customer": {"name": "Y"}, "assigned_to": other["user"]["id"]},
        headers=auth(tech),
    )  # fmt: skip
    assert r.json()["assignee"]["id"] == tech["user"]["id"]
    assert (await client.get(f"/api/v1/jobs/{j['id']}", headers=auth(other))).status_code == 404
    assert (
        await client.post(f"/api/v1/jobs/{j['id']}/cancel", json={"reason": "x"}, headers=auth(tech))
    ).status_code == 403


async def test_job_links_must_belong_to_the_customer(client):
    owner = await make_owner(client)
    a = await new_customer(client, owner, name="A")
    b = await new_customer(client, owner, name="B")
    r = await client.post(
        "/api/v1/jobs",
        json={"title": "x", "customer_id": a["id"], "site_id": b["sites"][0]["id"]},
        headers=auth(owner),
    )
    assert r.status_code == 404 and r.json()["error"]["code"] == "site_not_found"
    r = await client.post(
        "/api/v1/jobs",
        json={"title": "x", "customer_id": a["id"], "contact_id": b["contacts"][0]["id"]},
        headers=auth(owner),
    )
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"contact_id": "unknown"}
    r = await client.post("/api/v1/jobs", json={"title": "x"}, headers=auth(owner))
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"customer_id": "required"}


async def test_offline_retry_makes_one_job(client):
    owner = await make_owner(client)
    c = await new_customer(client, owner)
    key = str(uuid.uuid4())
    a = await new_job(client, owner, c, client_uuid=key)
    b = await new_job(client, owner, c, client_uuid=key, title="Different text")
    assert a["id"] == b["id"] and b["title"] == "AC not cooling"
    assert (await client.get("/api/v1/jobs", headers=auth(owner))).json()["meta"]["counts"]["all"] == 1


async def test_job_edit_with_version(client):
    owner = await make_owner(client)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c)
    r = await client.patch(
        f"/api/v1/jobs/{j['id']}", json={"description": "Noise from outdoor unit"},
        headers={**auth(owner), "If-Match": str(j["version"])},
    )  # fmt: skip
    assert r.status_code == 200 and r.json()["version"] == j["version"] + 1
    stale = await client.patch(
        f"/api/v1/jobs/{j['id']}", json={"title": "x"}, headers={**auth(owner), "If-Match": str(j["version"])}
    )
    assert stale.status_code == 409 and stale.json()["error"]["details"]["server"]["description"]


async def test_delete_unstarted_job(client):
    owner = await make_owner(client)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c)
    assert (await client.delete(f"/api/v1/jobs/{j['id']}", headers=auth(owner))).status_code == 204
    assert (await client.get(f"/api/v1/jobs/{j['id']}", headers=auth(owner))).status_code == 404


# ---- home screens and sync -----------------------------------------------------------------------
async def test_dashboard_today_and_stats(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    first = await new_job(
        client, owner, c, title="First", scheduled_at=at(0.1), assigned_to=tech["user"]["id"]
    )
    await new_job(client, owner, c, title="Second", scheduled_at=at(0.2), assigned_to=tech["user"]["id"])
    await new_job(client, owner, c, title="Nobody yet", scheduled_at=at(0.3))
    await client.post(f"/api/v1/jobs/{first['id']}/start", headers=auth(tech))

    d = (await client.get("/api/v1/dashboard", headers=auth(owner))).json()
    assert d["today"] == {"unassigned": 1, "assigned": 1, "in_progress": 1, "done": 0}
    assert len(d["week"]) == 7 and d["onboarding"]["team_invited"] and d["onboarding"]["first_job_created"]
    assert [(t["name"], t["status"], t["current_job"]) for t in d["team_now"]] == [
        ("Ravi Kumar", "on_job", first["number"])
    ]
    assert (await client.get("/api/v1/dashboard", headers=auth(tech))).status_code == 403

    t = (await client.get("/api/v1/me/today", headers=auth(tech))).json()
    assert t["name"] == "Ravi Kumar" and t["company"] == "BrightAir"
    assert t["stats"] == {"jobs": 2, "done": 0, "photos": 0}
    assert t["current_job"]["title"] == "First" and [j["title"] for j in t["next_jobs"]] == ["Second"]

    s_owner = (await client.get("/api/v1/me/stats", headers=auth(owner))).json()
    assert (s_owner["team"], s_owner["customers"], s_owner["to_review"]) == (2, 1, 0)
    s_tech = (await client.get("/api/v1/me/stats", headers=auth(tech))).json()
    assert (s_tech["team"], s_tech["customers"], s_tech["to_review"]) == (None, None, None)


async def test_sync_feed(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    first = (await client.get("/api/v1/sync/changes", headers=auth(tech))).json()
    assert [x["id"] for x in first["jobs"]] == [j["id"]] and first["cursor"] and not first["has_more"]

    # the job moves to someone else: it leaves this phone
    other = await invite_and_join(client, owner, TECH2)
    await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": other["user"]["id"]}, headers=auth(owner)
    )
    nxt = (
        await client.get("/api/v1/sync/changes", params={"since": first["cursor"]}, headers=auth(tech))
    ).json()
    assert nxt["jobs"] == [] and nxt["removed_job_ids"] == [j["id"]]

    owner_feed = (await client.get("/api/v1/sync/changes", headers=auth(owner))).json()
    assert [x["assignee"]["name"] for x in owner_feed["jobs"]] == [
        "Ravi Kumar"
    ]  # second invite also "Ravi Kumar"
    bad = await client.get("/api/v1/sync/changes?since=yesterday", headers=auth(owner))
    assert bad.status_code == 400


# ---- isolation ---------------------------------------------------------------------------------
async def test_companies_never_see_each_others_customers_or_jobs(client):
    a = await make_owner(client, "a@brightair.in", "BrightAir")
    b = await make_owner(client, "b@coolfix.in", "CoolFix")
    bc = await new_customer(client, b, name="CoolFix client")
    bj = await new_job(client, b, bc)
    assert (await client.get(f"/api/v1/customers/{bc['id']}", headers=auth(a))).status_code == 404
    assert (
        await client.patch(f"/api/v1/customers/{bc['id']}", json={"name": "x"}, headers=auth(a))
    ).status_code == 404
    assert (
        await client.post(f"/api/v1/customers/{bc['id']}/contacts", json={"name": "x"}, headers=auth(a))
    ).status_code == 404
    assert (await client.get(f"/api/v1/jobs/{bj['id']}", headers=auth(a))).status_code == 404
    assert (
        await client.post(f"/api/v1/jobs/{bj['id']}/cancel", json={"reason": "x"}, headers=auth(a))
    ).status_code == 404
    assert (await client.get(f"/api/v1/jobs/{bj['id']}/timeline", headers=auth(a))).status_code == 404
    r = await client.post("/api/v1/jobs", json={"title": "x", "customer_id": bc["id"]}, headers=auth(a))
    assert r.status_code == 404
    assert (await client.get("/api/v1/customers", headers=auth(a))).json()["meta"]["counts"]["all"] == 0
    assert (await client.get("/api/v1/jobs", headers=auth(a))).json()["meta"]["counts"]["all"] == 0
    # each company numbers its own jobs
    aj = await new_job(client, a, await new_customer(client, a))
    assert aj["number"] == bj["number"] == "J-1001"
