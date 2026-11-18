"""W03 Book a demo and W05 Contact."""

from datetime import UTC, datetime

import pytest

from app.services import leads

# Wednesday 18 Nov 2026, 9:00 in India
NOW = datetime(2026, 11, 18, 3, 30, tzinfo=UTC)


@pytest.fixture(autouse=True)
def _clock(monkeypatch):
    monkeypatch.setattr(leads, "now", lambda: NOW)


def demo(starts_at: str, **kw):
    return {
        "name": "Ramesh Patel",
        "email": "ramesh@brightair.in",
        "phone": "+91 98765 43210",
        "company": "BrightAir Services",
        "team_size": "1-5",
        "trade": "hvac",
        "starts_at": starts_at,
        **kw,
    }


async def test_demo_slots_skip_weekends_and_the_next_two_hours(client):
    out = (await client.get("/api/v1/public/demo-slots")).json()
    assert out["timezone"] == "Asia/Kolkata" and out["minutes"] == 30
    assert out["team_sizes"] == ["1-5", "6-15", "16-50", "51+"]
    first = out["days"][0]
    assert first["date"] == "2026-11-18"
    # 10:00 is less than 2 hours away from 9:00, so today starts at 11:30
    assert first["slots"][0] == "2026-11-18T11:30:00+05:30"
    dates = [d["date"] for d in out["days"]]
    assert "2026-11-21" not in dates and "2026-11-22" not in dates  # Saturday, Sunday


async def test_book_a_demo_then_the_time_is_gone(client):
    r = await client.post("/api/v1/public/demo-requests", json=demo("2026-11-19T11:30:00+05:30"))
    assert r.status_code == 201, r.text
    out = r.json()
    assert out["ticket"].startswith("KN-") and out["ends_at"] == "2026-11-19T12:00:00+05:30"
    again = await client.post(
        "/api/v1/public/demo-requests", json=demo("2026-11-19T06:00:00Z", email="b@x.in")
    )
    assert again.status_code == 409 and again.json()["error"]["fields"] == {"starts_at": "taken"}
    days = (await client.get("/api/v1/public/demo-slots")).json()["days"]
    thu = next(d for d in days if d["date"] == "2026-11-19")
    assert "2026-11-19T11:30:00+05:30" not in thu["slots"]


async def test_demo_needs_a_real_time_and_trade(client):
    odd = await client.post("/api/v1/public/demo-requests", json=demo("2026-11-19T11:45:00+05:30"))
    assert odd.status_code == 400 and odd.json()["error"]["code"] == "slot_unavailable"
    sat = await client.post("/api/v1/public/demo-requests", json=demo("2026-11-21T10:00:00+05:30"))
    assert sat.json()["error"]["code"] == "slot_unavailable"
    trade = await client.post(
        "/api/v1/public/demo-requests", json=demo("2026-11-20T10:00:00+05:30", trade="plumbing")
    )
    assert trade.json()["error"]["fields"] == {"trade": "unknown"}


async def test_contact_message_gets_a_ticket(client):
    r = await client.post(
        "/api/v1/public/contact",
        json={
            "name": "Priya Shah",
            "email": "priya@sunpeak.solar",
            "topic": "sales",
            "message": "We are a solar installer with 8 technicians.",
        },
    )
    assert r.status_code == 201 and r.json()["topic"] == "sales" and r.json()["ticket"].startswith("KN-")
    short = await client.post(
        "/api/v1/public/contact",
        json={"name": "P", "email": "p@x.in", "topic": "sales", "message": "Need pricing"},
    )
    assert short.status_code == 422 and "message" in short.json()["error"]["fields"]


async def test_too_many_messages_from_one_address(client):
    body = {"name": "Spam", "email": "s@x.in", "topic": "other", "message": "x" * 30}
    for _ in range(leads.PER_HOUR):
        assert (await client.post("/api/v1/public/contact", json=body)).status_code == 201
    assert (await client.post("/api/v1/public/contact", json=body)).status_code == 429


async def test_config_has_contact_details(client):
    s = (await client.get("/api/v1/config")).json()["support"]
    assert s["office"] == "Ahmedabad, Gujarat, India" and s["email"] is None
    assert s["days"] == [1, 2, 3, 4, 5, 6] and s["topics"][0] == "sales"
    assert s["regions"][0] == {"country": "IN", "languages": ["hi", "gu", "en"]}


async def test_ready_checklists_for_a_trade_need_no_login(client) -> None:
    r = await client.get("/api/v1/public/checklist-templates?trade=hvac&locale=gu")
    assert r.status_code == 200
    assert r.headers["cache-control"] == "public, max-age=300"
    body = r.json()
    assert body["trade"] == "hvac" and body["language"] == "gu"
    cfg = (await client.get("/api/v1/config")).json()
    hvac = next(t for t in cfg["trades"] if t["key"] == "hvac")
    assert len(body["items"]) == hvac["checklists"] > 0
    t = body["items"][0]
    assert t["question_count"] == len(t["questions"]) > 0
    assert set(t["languages"]) == {"en", "hi", "gu", "es", "fr"}
    assert 0 < t["photo_questions"] <= t["question_count"]
    assert {"text", "type", "unit", "photo_rule", "required"} <= set(t["questions"][0])
    # a trade with no ready checklists yet is an empty list, not an error
    empty = (await client.get("/api/v1/public/checklist-templates?trade=cleaning")).json()
    assert empty["items"] == []
    assert (await client.get("/api/v1/public/checklist-templates?trade=hvac&locale=de")).status_code == 422
