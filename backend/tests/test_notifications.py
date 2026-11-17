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
