"""M42 Messages: made where things happen, for the right people, never for the one who did it."""

from tests.conftest import auth
from tests.test_customers_jobs import new_job
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture


async def messages(client, who) -> dict:
    r = await client.get("/api/v1/notifications", headers=auth(who))
    assert r.status_code == 200, r.text
    return r.json()


async def test_a_job_given_to_a_technician_is_a_message_for_them(client, ready):
    owner, tech, c = ready["owner"], ready["tech"], ready["customer"]
    first = await messages(client, tech)
    assert [m["kind"] for m in first["data"]] == ["job_assigned"]  # the job in the fixture
    j = await new_job(client, owner, c, title="AC not cooling", scheduled_at="2026-11-20T06:00:00Z")
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/assign", json={"technician_id": tech["user"]["id"]}, headers=auth(owner)
    )
    assert r.status_code == 200
    got = await messages(client, tech)
    newest = got["data"][0]
    assert newest["kind"] == "job_assigned" and newest["job_id"] == j["id"] and newest["read"] is False
    assert newest["params"]["job"] == "AC not cooling" and newest["params"]["customer"] == c["name"]
    assert newest["params"]["scheduled_at"].startswith("2026-11-20T06:00")
    assert newest["actor"]["id"] == owner["user"]["id"]
    assert got["meta"]["counts"]["unread"] == 2
    # the owner who assigned it gets nothing
    assert (await messages(client, owner))["data"] == []


async def test_report_review_messages_go_both_ways(client, ready):
    owner, tech, job = ready["owner"], ready["tech"], ready["job"]
    _, _, rep = await make_report(client, tech, job["id"])
    url = f"/api/v1/reports/{rep['id']}"
    await client.post(f"{url}/submit", headers=auth(tech))
    to_review = (await messages(client, owner))["data"][0]
    assert to_review["kind"] == "report_submitted" and to_review["report_id"] == rep["id"]
    assert to_review["params"]["report"] == "R-1001" and to_review["params"]["technician"]
    assert to_review["cover_url"]  # the job's photo
    await client.post(
        f"{url}/request-changes",
        json={"reasons": ["missing_photos"], "note": "Please add an after photo."},
        headers=auth(owner),
    )
    changes = (await messages(client, tech))["data"][0]
    assert (
        changes["kind"] == "changes_requested" and changes["params"]["note"] == "Please add an after photo."
    )
    assert changes["actor"]["id"] == owner["user"]["id"]
    await client.post(f"{url}/submit", headers=auth(tech))
    await client.post(f"{url}/approve", headers=auth(owner))
    assert (await messages(client, tech))["data"][0]["kind"] == "report_approved"


async def test_reading_messages(client, ready):
    tech = ready["tech"]
    got = await messages(client, tech)
    one = got["data"][0]["id"]
    r = await client.post("/api/v1/notifications/read", json={"ids": [one]}, headers=auth(tech))
    assert r.status_code == 200 and r.json() == {"unread": 0}
    assert (await messages(client, tech))["data"][0]["read"] is True
    # someone else's message id changes nothing
    r = await client.post("/api/v1/notifications/read", json={}, headers=auth(ready["owner"]))
    assert r.json() == {"unread": 0}


async def test_not_sure_asks_the_office(client, ready):
    owner, tech, j = ready["owner"], ready["tech"], ready["job"]
    url = f"/api/v1/jobs/{j['id']}/ask-manager"
    body = {"question": "Is the condensate drain clear?", "note": "  Water is standing in the tray  "}
    assert (await client.post(url, json=body, headers=auth(tech))).status_code == 204
    got = (await messages(client, owner))["data"][0]
    assert got["kind"] == "tech_question" and got["job_id"] == j["id"]
    assert got["params"]["question"] == "Is the condensate drain clear?"
    assert got["params"]["note"] == "Water is standing in the tray"
    assert got["params"]["technician"] == tech["user"]["name"]
    assert (await messages(client, tech))["data"][0]["kind"] != "tech_question"  # not to themselves
    # only the technician on the job, and only while it is going on
    assert (await client.post(url, json=body, headers=auth(owner))).status_code == 403
    assert (await client.post(url, json={"question": ""}, headers=auth(tech))).status_code == 422


async def test_service_history_shows_earlier_jobs_on_the_machine(client):
    from tests.conftest import invite_and_join, make_owner
    from tests.test_customers_jobs import TECH, TECH2, new_customer

    owner = await make_owner(client)
    a = await invite_and_join(client, owner, TECH)
    b = await invite_and_join(client, owner, TECH2)
    c = await new_customer(client, owner)
    site = c["sites"][0]["id"]
    eq = (
        await client.post(
            f"/api/v1/customers/{c['id']}/sites/{site}/equipment",
            json={"type": "Split AC"},
            headers=auth(owner),
        )
    ).json()
    old = await new_job(
        client, owner, c, title="Gas top-up", equipment_id=eq["id"], assigned_to=b["user"]["id"]
    )
    assert (await client.post(f"/api/v1/jobs/{old['id']}/start", headers=auth(b))).status_code == 200
    await new_job(client, owner, c, title="Not started yet", equipment_id=eq["id"])
    now = await new_job(
        client, owner, c, title="AC not cooling", equipment_id=eq["id"], assigned_to=a["user"]["id"]
    )
    plain = await new_job(client, owner, c, title="No machine", assigned_to=a["user"]["id"])

    # technician A sees the machine's earlier work even though B did it; jobs not started are left out
    r = await client.get(f"/api/v1/jobs/{now['id']}/equipment-history", headers=auth(a))
    assert r.status_code == 200 and [x["title"] for x in r.json()["data"]] == ["Gas top-up"]
    assert r.json()["data"][0]["assignee"]["id"] == b["user"]["id"]
    assert (await client.get(f"/api/v1/jobs/{plain['id']}/equipment-history", headers=auth(a))).json()[
        "data"
    ] == []
    # someone who can't see the job can't see its history
    assert (
        await client.get(f"/api/v1/jobs/{old['id']}/equipment-history", headers=auth(a))
    ).status_code == 404
