"""Follow-up credits and Plan and billing (M41): the monthly grant, reminders using credits, pausing
when they run out and going again after a top-up, and who may see what."""

from datetime import UTC, datetime
from types import SimpleNamespace

from sqlalchemy import text

from app.core.db import engine
from app.providers.messaging import outbox
from app.services.credits import cycle
from tests.conftest import auth, invite_and_join
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture
from tests.test_review_office import asked


def test_a_month_starts_on_the_signup_day():
    c = SimpleNamespace(timezone="Asia/Kolkata", created_at=datetime(2026, 1, 30, 20, 0, tzinfo=UTC))
    # 31 Jan 01:30 in India; February has no 31st, so that month ends on 28 Feb
    start, end = cycle(c, datetime(2026, 2, 10, tzinfo=UTC))
    assert start == datetime(2026, 1, 30, 18, 30, tzinfo=UTC) and end == datetime(
        2026, 2, 27, 18, 30, tzinfo=UTC
    )
    start, _ = cycle(c, datetime(2026, 3, 5, tzinfo=UTC))
    assert start == datetime(2026, 2, 27, 18, 30, tzinfo=UTC)


async def _due(client, owner) -> dict:
    async with engine.begin() as c:
        await c.execute(text("update review_requests set reminder_at = now() - interval '1 minute'"))
    outbox.clear()
    return (await client.get("/api/v1/review-requests", headers=auth(owner))).json()


async def test_billing_for_the_owner(client, ready):
    owner = ready["owner"]
    r = await client.get("/api/v1/billing", headers=auth(owner))
    assert r.status_code == 200, r.text
    b = r.json()
    assert (
        b["plan"]["code"] == "professional" and b["status"] == "trial" and b["renews_at"] > b["period_start"]
    )
    tiles = {t["key"]: (t["used"], t["limit"]) for t in b["usage"]}
    assert (
        tiles["technicians"] == (1, 10)
        and tiles["credits"] == (0, 1500)
        and tiles["ai_questions"] == (0, 1000)
    )
    assert b["upgrade"]["code"] == "business" and b["payments_ready"] is False
    assert (await client.get("/api/v1/billing", headers=auth(ready["tech"]))).status_code == 403


async def test_reminders_use_credits_and_pause_without_them(client, ready):
    owner = ready["owner"]
    await asked(client, ready)
    c = (await client.get("/api/v1/credits", headers=auth(owner))).json()
    assert (c["balance"], c["plan_credits"], c["topup_credits"]) == (1500, 1500, 0)
    assert [p["credits"] for p in c["packs"]] == [500, 2000] and c["packs"][0]["price"]["currency"] == "INR"
    page = await _due(client, owner)
    assert page["data"][0]["status"] == "reminded"
    c = (await client.get("/api/v1/credits", headers=auth(owner))).json()
    uses = {u["kind"]: (u["credits"], u["count"]) for u in c["uses"]}
    assert c["balance"] == 1499 and uses == {"reminders": (1, 1), "ai_calls": (0, 0), "emails": (0, 1)}

    # every credit used, SMS only: the reminder waits
    await client.patch("/api/v1/review-settings", json={"reminder_channels": ["sms"]}, headers=auth(owner))
    async with engine.begin() as conn:
        await conn.execute(text("update review_requests set status = 'link_sent'"))
        await conn.execute(text("update credit_wallets set plan_used = plan_credits"))
    page = await _due(client, owner)
    assert page["data"][0]["status"] == "paused_no_credits" and len(outbox.sms) == 0
    assert page["counts"]["waiting"] == 1
    # a top-up arrives: it goes on the next check
    async with engine.begin() as conn:
        await conn.execute(text("update credit_wallets set topup_credits = 5"))
    page = await _due(client, owner)
    assert page["data"][0]["status"] == "reminded" and len(outbox.sms) == 1
    c = (await client.get("/api/v1/credits", headers=auth(owner))).json()
    assert (c["balance"], c["topup_credits"]) == (4, 4)


async def test_technicians_cannot_see_credits(client, ready):
    tech = await invite_and_join(client, ready["owner"], "+919898989898")
    assert (await client.get("/api/v1/credits", headers=auth(tech))).status_code == 403


async def test_no_new_report_past_the_plans_monthly_number(client, ready):
    tech, owner = ready["tech"], ready["owner"]
    async with engine.begin() as c:
        await c.execute(text("update plans set report_limit_monthly = 0 where code = 'professional'"))
    try:
        r = await client.post(f"/api/v1/jobs/{ready['job']['id']}/reports", headers=auth(tech))
        assert r.status_code == 402, r.text
        err = r.json()["error"]
        assert err["code"] == "report_limit_reached" and err["details"]["limit"] == 0
        s = (await client.get("/api/v1/plan", headers=auth(tech))).json()
        assert s["reports"] == {"key": "reports", "used": 0, "limit": 0} and s["can_upgrade"] is False
        assert s["plan"]["code"] == "professional" and s["upgrade"]["code"] == "business"
        assert (await client.get("/api/v1/plan", headers=auth(owner))).json()["can_upgrade"] is True
        # the job's photos are still there
        proof = (await client.get(f"/api/v1/jobs/{ready['job']['id']}/proof", headers=auth(tech))).json()
        assert proof
    finally:
        async with engine.begin() as c:
            await c.execute(text("update plans set report_limit_monthly = 300 where code = 'professional'"))
