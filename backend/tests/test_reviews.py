"""Customer reviews: ask before approval (queued) and after, cancel, the rating on the report page,
"don't ask me again", My reviews (M44) and who may see what."""

from app.providers.messaging import outbox
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture
from tests.test_sharing import approved, token_of

TECH2 = "+919898989898"


async def job(client, who, job_id) -> dict:
    r = await client.get(f"/api/v1/jobs/{job_id}", headers=auth(who))
    assert r.status_code == 200, r.text
    return r.json()


async def submitted(client, s) -> dict:
    _, _, rep = await make_report(client, s["tech"], s["job"]["id"])
    r = await client.post(f"/api/v1/reports/{rep['id']}/submit", headers=auth(s["tech"]))
    assert r.status_code == 200, r.text
    return rep


async def test_no_card_before_a_report(client, ready):
    assert (await job(client, ready["tech"], ready["job"]["id"]))["review"] is None
    r = await client.post(f"/api/v1/jobs/{ready['job']['id']}/review-request", headers=auth(ready["tech"]))
    assert r.status_code == 409 and r.json()["error"]["code"] == "no_report"


async def test_asked_before_approval_waits_then_goes_with_the_report(client, ready):
    tech, owner, job_id = ready["tech"], ready["owner"], ready["job"]["id"]
    rep = await submitted(client, ready)
    card = (await job(client, tech, job_id))["review"]
    assert card["status"] == "not_requested" and card["can_request"] and card["contact_name"] == "Mr Sharma"
    r = await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(tech))
    assert r.status_code == 201, r.text
    queued = r.json()
    assert queued["status"] == "queued" and queued["requested_by_me"] and queued["can_cancel"]
    again = await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(owner))
    assert again.status_code == 409 and again.json()["error"]["code"] == "already_requested"
    outbox.clear()
    r = await client.post(f"/api/v1/reports/{rep['id']}/approve", headers=auth(owner))
    assert r.status_code == 200 and r.json()["status"] == "shared"  # the link went with the report
    sms = outbox.sms[-1]
    assert sms["to"] == "+919825011111" and "Please rate the job" in sms["body"] and "?rate=1" in sms["body"]
    assert "How did we do?" in outbox.email[-1]["body"]
    card = (await job(client, tech, job_id))["review"]
    assert card["status"] == "link_sent" and card["channels"] == ["sms", "email"] and not card["can_cancel"]
    assert (
        card["sent_at"] and card["reminder_at"] > card["sent_at"] and card["ai_call_at"] > card["reminder_at"]
    )


async def test_cancel_while_waiting(client, ready):
    tech, job_id = ready["tech"], ready["job"]["id"]
    await submitted(client, ready)
    req = (await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(tech))).json()
    assert (
        await client.delete(f"/api/v1/review-requests/{req['request_id']}", headers=auth(tech))
    ).status_code == 204
    assert (await job(client, tech, job_id))["review"]["status"] == "not_requested"


async def test_customer_rates_on_the_report_page_and_the_technician_sees_it(client, ready):
    tech, owner, job_id = ready["tech"], ready["owner"], ready["job"]["id"]
    await approved(client, ready)
    outbox.clear()
    r = await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(owner))
    assert r.json()["status"] == "link_sent"  # already approved: sent at once
    url = outbox.sms[-1]["body"].split(" ")[-6]  # "... here: <link> Reply STOP to opt out."
    token = token_of(url.split("?")[0])
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["review"]["can_rate"] and page["review"]["technician"] == tech["user"]["name"].split(" ")[0]
    assert "on_time" in page["review"]["positive_tags"] and "late" in page["review"]["negative_tags"]
    bad = await client.post(f"/api/v1/public/reports/{token}/review", json={"rating": 5, "tags": ["great"]})
    assert bad.status_code == 422
    rated = await client.post(
        f"/api/v1/public/reports/{token}/review",
        json={
            "rating": 4,
            "technician_rating": 5,
            "tags": ["on_time", "clean_work"],
            "comment": "Quick and tidy.",
        },
    )
    assert rated.status_code == 201, rated.text
    twice = await client.post(f"/api/v1/public/reports/{token}/review", json={"rating": 1})
    assert twice.status_code == 409 and twice.json()["error"]["code"] == "already_rated"
    card = (await job(client, tech, job_id))["review"]
    assert card["status"] == "rated" and card["review"]["technician_rating"] == 5
    assert card["review"]["comment"] == "Quick and tidy." and card["review"]["source"] == "link"
    mine = (await client.get("/api/v1/me/reviews", headers=auth(tech))).json()
    assert (mine["average"], mine["count"], mine["share_4_plus"]) == (5.0, 1, 100)
    assert mine["tags"] == [{"key": "clean_work", "count": 1}, {"key": "on_time", "count": 1}] or mine[
        "tags"
    ] == [
        {"key": "on_time", "count": 1},
        {"key": "clean_work", "count": 1},
    ]
    item = mine["data"][0]
    assert item["customer"] == ready["customer"]["name"] and item["reviewer_name"] == "Mr Sharma"
    assert item["cover_url"] and item["reply"] is None
    one = (await client.get(f"/api/v1/reviews/{item['id']}", headers=auth(tech))).json()
    assert one["report_number"] == "R-1001" and one["before_url"] and one["after_url"]
    assert one["tags"] == ["on_time", "clean_work"]
    # another technician can't open it; the owner can
    other = await invite_and_join(client, owner, TECH2)
    assert (await client.get(f"/api/v1/reviews/{item['id']}", headers=auth(other))).status_code == 404
    assert (await client.get(f"/api/v1/reviews/{item['id']}", headers=auth(owner))).status_code == 200
    assert (await client.get("/api/v1/me/reviews", headers=auth(other))).json()["count"] == 0


async def test_dont_ask_me_again(client, ready):
    owner, job_id = ready["owner"], ready["job"]["id"]
    await approved(client, ready)
    outbox.clear()
    await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(owner))
    token = token_of(outbox.sms[-1]["body"].split(" ")[-6].split("?")[0])
    assert (await client.post(f"/api/v1/public/reports/{token}/review/stop")).status_code == 204
    card = (await job(client, owner, job_id))["review"]
    assert card["status"] == "opted_out" and card["opted_out_at"] and card["opt_out_source"] == "link"


async def test_only_the_jobs_technician_or_a_manager_may_ask(client, ready):
    owner, job_id = ready["owner"], ready["job"]["id"]
    await submitted(client, ready)
    other = await invite_and_join(client, owner, TECH2)
    r = await client.post(f"/api/v1/jobs/{job_id}/review-request", headers=auth(other))
    assert r.status_code == 404  # they can't even see the job


async def test_other_companies_cannot_touch_reviews(client, ready):
    await submitted(client, ready)
    req = (
        await client.post(f"/api/v1/jobs/{ready['job']['id']}/review-request", headers=auth(ready["tech"]))
    ).json()
    stranger = await make_owner(client, email="x@other.in", company="Other Co")
    r = await client.delete(f"/api/v1/review-requests/{req['request_id']}", headers=auth(stranger))
    assert r.status_code == 404
