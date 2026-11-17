"""The office side of reviews (M45, M46): all reviews with the chips, replies, the low-rating follow-up,
where each request stands, the settings, the Day 2 reminder and "Ask for a review" on send."""

from sqlalchemy import text

from app.core.config import get_settings
from app.core.db import engine
from app.providers.messaging import outbox
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture
from tests.test_sharing import approved, token_of

TECH2 = "+919898989898"


async def asked(client, s) -> str:
    """Approve, ask for a review and return the customer's link token."""
    await approved(client, s)
    outbox.clear()
    r = await client.post(f"/api/v1/jobs/{s['job']['id']}/review-request", headers=auth(s["owner"]))
    assert r.status_code == 201, r.text
    return token_of(outbox.sms[-1]["body"].split(" ")[-6].split("?")[0])


async def rate(client, token, **body) -> None:
    r = await client.post(f"/api/v1/public/reports/{token}/review", json=body)
    assert r.status_code == 201, r.text


async def kinds(client, who) -> list[str]:
    r = await client.get("/api/v1/notifications", headers=auth(who))
    assert r.status_code == 200, r.text
    return [n["kind"] for n in r.json()["data"]]


async def test_reviews_page_counts_reply_and_suggestion(client, ready):
    owner, tech = ready["owner"], ready["tech"]
    await rate(client, await asked(client, ready), rating=5, technician_rating=5, tags=["on_time"])
    page = (await client.get("/api/v1/reviews", headers=auth(owner))).json()
    assert (page["average"], page["count"], page["breakdown"]) == (5.0, 1, [0, 0, 0, 0, 1])
    assert page["counts"] == {"all": 1, "needs_reply": 1, "low": 0}
    item = page["data"][0]
    assert item["needs_reply"] and not item["low"] and item["followup"] is None
    assert item["technician"]["name"] == tech["user"]["name"] and item["tags"] == ["on_time"]
    assert "review_received" in await kinds(client, tech)
    tip = await client.post(f"/api/v1/reviews/{item['id']}/reply-suggestion", headers=auth(owner))
    assert tip.status_code == 200 and tip.json()["text"].startswith("Thank you, Mr Sharma!")
    r = await client.post(
        f"/api/v1/reviews/{item['id']}/reply", json={"text": "Thanks!"}, headers=auth(owner)
    )
    assert r.status_code == 200 and r.json()["text"] == "Thanks!"
    r = await client.post(
        f"/api/v1/reviews/{item['id']}/reply", json={"text": "Thank you!"}, headers=auth(owner)
    )
    assert r.json()["text"] == "Thank you!"  # sending again edits the one reply
    page = (await client.get("/api/v1/reviews?filter=needs_reply", headers=auth(owner))).json()
    assert page["counts"]["needs_reply"] == 0 and page["data"] == []
    one = (await client.get(f"/api/v1/reviews/{item['id']}", headers=auth(tech))).json()
    assert one["reply"]["text"] == "Thank you!" and one["reply"]["author"]["name"] == owner["user"]["name"]
    # the technician can't see the office list or reply
    assert (await client.get("/api/v1/reviews", headers=auth(tech))).status_code == 403
    r = await client.post(f"/api/v1/reviews/{item['id']}/reply", json={"text": "Hi"}, headers=auth(tech))
    assert r.status_code == 403


async def test_low_rating_alerts_and_follow_up(client, ready):
    owner = ready["owner"]
    await rate(
        client,
        await asked(client, ready),
        rating=2,
        tags=["late"],
        comment="Came late.",
        wants_call_back=True,
    )
    assert "low_rating" in await kinds(client, owner)
    page = (await client.get("/api/v1/reviews?filter=low", headers=auth(owner))).json()
    assert page["counts"]["low"] == 1
    item = page["data"][0]
    assert item["low"] and item["wants_call_back"] and item["followup"]["status"] == "open"
    tip = (await client.post(f"/api/v1/reviews/{item['id']}/reply-suggestion", headers=auth(owner))).json()
    assert "sorry" in tip["text"]
    url = f"/api/v1/reviews/{item['id']}/follow-up"
    r = await client.patch(url, json={"private_note": "Called, revisit Friday."}, headers=auth(owner))
    assert r.status_code == 200 and r.json()["status"] == "open"
    r = await client.patch(url, json={"status": "resolved"}, headers=auth(owner))
    done = r.json()
    assert (
        done["status"] == "resolved"
        and done["resolved_at"]
        and done["private_note"] == "Called, revisit Friday."
    )


async def test_requests_settings_and_the_day_2_reminder(client, ready):
    owner = ready["owner"]
    await asked(client, ready)
    page = (await client.get("/api/v1/review-requests", headers=auth(owner))).json()
    assert page["counts"] == {"waiting": 1, "rated": 0, "opted_out": 0}
    item = page["data"][0]
    assert item["status"] == "link_sent" and item["next_step"] == "reminder" and item["customer"]
    # nothing is due yet
    r = await client.post("/api/v1/cron/review-followups", headers={"X-Cron-Key": "nope"})
    assert r.status_code == 403  # no key configured: closed
    async with engine.begin() as c:
        await c.execute(text("update review_requests set reminder_at = now() - interval '1 minute'"))
    outbox.clear()
    page = (await client.get("/api/v1/review-requests", headers=auth(owner))).json()  # opening sends it
    assert page["data"][0]["status"] == "reminded" and page["data"][0]["next_step"] == "ai_call"
    assert "It takes one tap" in outbox.sms[-1]["body"] and "?rate=1" in outbox.sms[-1]["body"]
    assert "It takes one tap" in outbox.email[-1]["body"]
    # settings
    s = (await client.get("/api/v1/review-settings", headers=auth(owner))).json()
    assert s["ask_on_share"] and s["reminder_enabled"] and s["reminder_channels"] == ["sms", "email"]
    assert s["can_edit"] and s["low_rating_threshold"] == 2
    r = await client.patch(
        "/api/v1/review-settings",
        json={"reminder_enabled": False, "google_review_url": "g.page/r/abc", "techs_see_reviews": False},
        headers=auth(owner),
    )
    assert r.status_code == 200, r.text
    s = r.json()
    assert not s["reminder_enabled"] and s["google_review_url"] == "https://g.page/r/abc"
    assert not s["techs_see_reviews"]
    assert (await client.get("/api/v1/me/reviews", headers=auth(ready["tech"]))).status_code == 403
    tech = await invite_and_join(client, owner, TECH2)
    assert (await client.get("/api/v1/review-settings", headers=auth(tech))).status_code == 403


async def test_cron_with_the_key(client, ready, monkeypatch):
    monkeypatch.setenv("KN_CRON_KEY", "k" * 32)
    get_settings.cache_clear()
    try:
        await asked(client, ready)
        async with engine.begin() as c:
            await c.execute(text("update review_requests set reminder_at = now() - interval '1 minute'"))
        r = await client.post("/api/v1/cron/review-followups", headers={"X-Cron-Key": "k" * 32})
        assert r.status_code == 200 and r.json() == {"reminders_sent": 1}
        r = await client.post("/api/v1/cron/review-followups", headers={"X-Cron-Key": "k" * 32})
        assert r.json() == {"reminders_sent": 0}  # once only
    finally:
        monkeypatch.delenv("KN_CRON_KEY")
        get_settings.cache_clear()


async def test_ask_for_a_review_with_the_send(client, ready):
    owner, job_id = ready["owner"], ready["job"]["id"]
    rep = await approved(client, ready)
    info = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(owner))).json()
    assert info["review_ask"] == "on"
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send",
        json={"channels": ["sms"], "ask_for_review": False},
        headers=auth(owner),
    )
    assert r.status_code == 200 and r.json()["review_ask"] == "on"  # not asked: still the default
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(owner)
    )
    assert r.json()["review_ask"] == "asked"
    card = (await client.get(f"/api/v1/jobs/{job_id}", headers=auth(owner))).json()["review"]
    assert card["status"] == "link_sent" and card["channels"] == ["sms"] and card["reminder_at"]


async def test_other_companies_cannot_reply(client, ready):
    await rate(client, await asked(client, ready), rating=4)
    item = (await client.get("/api/v1/reviews", headers=auth(ready["owner"]))).json()["data"][0]
    stranger = await make_owner(client, email="x@other.in", company="Other Co")
    r = await client.post(f"/api/v1/reviews/{item['id']}/reply", json={"text": "Hi"}, headers=auth(stranger))
    assert r.status_code == 404
    assert (await client.get("/api/v1/reviews", headers=auth(stranger))).json()["count"] == 0
