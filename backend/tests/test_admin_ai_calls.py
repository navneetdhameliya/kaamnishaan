"""A38 AI review calls: the Day 5 step with no voice provider (SMS instead), calling hours, a provider
that works or fails, and the admin page (numbers, settings, script, log)."""

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import select, text, update

from app.core.db import SessionLocal, engine
from app.models import AiCall, ReviewRequest
from app.providers.messaging import outbox
from app.providers.voice import CallResult, VoiceProvider, set_voice_for_tests
from app.services import ai_calls
from tests.conftest import auth
from tests.test_admin_auth import _setup
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture
from tests.test_review_office import asked

A = "/api/v1/admin/ai-calls"
IST = ZoneInfo("Asia/Kolkata")


class FakeVoice(VoiceProvider):
    name = "fake"

    def __init__(self, result: CallResult | None = None, fail: bool = False):
        self.result, self.fail, self.calls = result, fail, []

    async def call(self, req):
        self.calls.append(req)
        if self.fail:
            raise ConnectionError("provider down")
        return self.result


@pytest.fixture
def voice():
    v = FakeVoice()
    set_voice_for_tests(v)
    yield v
    set_voice_for_tests(None)


def at_ist(hour: int) -> datetime:
    """Tomorrow at [hour] in India: after every planned call, inside or outside the calling hours."""
    d = datetime.now(IST).date() + timedelta(days=1)
    return datetime(d.year, d.month, d.day, hour, 0, tzinfo=IST).astimezone(UTC)


async def due(client, s) -> None:
    """A review request whose Day 5 call is due."""
    await asked(client, s)
    async with SessionLocal() as db:
        await db.execute(update(ReviewRequest).values(ai_call_at=datetime.now(UTC) - timedelta(minutes=1)))
        await db.commit()


async def run(hour: int) -> int:
    async with SessionLocal() as db:
        n = await ai_calls.call_due(db, at=at_ist(hour))
        await db.commit()
        return n


async def state():
    async with SessionLocal() as db:
        req = (await db.execute(select(ReviewRequest))).scalar_one()
        calls = (await db.execute(select(AiCall))).scalars().all()
        return req, calls


async def test_without_a_provider_the_link_goes_by_sms(client, ready):
    await due(client, ready)
    outbox.clear()
    assert await run(21) == 0  # 9 pm: outside calling hours, it waits for 10 am
    req, calls = await state()
    assert calls == [] and req.ai_call_at.astimezone(IST).hour == 10 and req.ai_call_at > at_ist(21)
    assert await run(21) == 0  # still waiting: planned for the next morning
    async with SessionLocal() as db:
        n = await ai_calls.call_due(db, at=req.ai_call_at + timedelta(minutes=5))
        await db.commit()
    assert n == 1
    req, [call] = await state()
    assert call.outcome == "no_provider_sms" and call.contact_name == "Mr Sharma" and call.language == "en"
    assert req.status == "ai_call_done" and req.ai_call_at is None
    assert outbox.sms and "?rate=1" in outbox.sms[-1]["body"]

    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    assert d["provider"] == {"connected": False, "name": None, "down_since": None, "waiting": 0}
    assert d["kpis"]["calls"] == 0 and d["kpis"]["sms_instead"] == 1 and d["kpis"]["answered"] is None
    assert d["calls"][0]["outcome"] == "no_provider_sms" and d["calls"][0]["company"]["label"] == "BrightAir"
    assert (
        d["script"]["version"] == 1
        and len(d["script"]["steps"]) == 9
        and "I'm an AI" in d["script"]["opening"]
    )
    r = await client.post(f"{A}/test", json={"phone": "98250 22222"}, headers=auth(s))
    assert r.status_code == 409 and r.json()["error"]["code"] == "no_voice_provider"


async def test_rated_on_the_call(client, ready, voice):
    owner = ready["owner"]
    voice.result = CallResult(outcome="rated", rating=2, comment="Came late", wants_call_back=True, seconds=160,
                              cost_usd=0.39, transcript="...", provider_call_id="c1")  # fmt: skip
    await due(client, ready)
    assert await run(12) == 1
    req, [call] = await state()
    sent = voice.calls[0]
    assert sent.to == "+919825011111" and sent.opening.startswith("Hi, this is BrightAir's virtual assistant")
    greeting = sent.steps[0]["text"]
    assert ready["job"]["title"] in greeting and "{job}" not in greeting and "{date}" not in greeting
    assert call.outcome == "rated" and call.rating == 2 and call.seconds == 160 and call.transcript == "..."
    assert req.status == "rated"
    page = (await client.get("/api/v1/reviews", headers=auth(owner))).json()
    assert (
        page["count"] == 1 and page["data"][0]["source"] == "ai_call" and page["data"][0]["wants_call_back"]
    )
    s, _ = await _setup(client)
    k = (await client.get(A, headers=auth(s))).json()["kpis"]
    assert (k["calls"], k["answered"], k["rated"], k["opted_out"], k["cost_per_call_usd"]) == (
        1,
        1.0,
        1.0,
        0.0,
        0.39,
    )
    async with engine.begin() as c:
        spent = (
            await c.execute(text("SELECT count(*) FROM credit_entries WHERE kind = 'ai_call'"))
        ).scalar_one()
    assert spent == 1


async def test_provider_down_then_back(client, ready, voice):
    voice.fail = True
    await due(client, ready)
    outbox.clear()
    assert await run(12) == 1
    req, [call] = await state()
    assert call.outcome == "failed_sms" and "provider down" in call.error and outbox.sms
    s, _ = await _setup(client)
    p = (await client.get(A, headers=auth(s))).json()["provider"]
    assert p["connected"] and p["name"] == "fake" and p["down_since"]
    # it works again: the banner goes
    voice.fail, voice.result = False, CallResult(outcome="opted_out", seconds=20)
    async with SessionLocal() as db:
        await db.execute(update(ReviewRequest).values(status="reminded", ai_call_at=at_ist(11)))
        await db.commit()
    assert (await client.post(f"{A}/retry", headers=auth(s))).json() == {"handled": 0}  # not due yet
    assert await run(12) == 1
    req, calls = await state()
    assert req.status == "opted_out" and req.opt_out_source == "call"
    assert (await client.get(A, headers=auth(s))).json()["provider"]["down_since"] is None
    r = await client.post(f"{A}/test", json={"phone": "98250 22222"}, headers=auth(s))
    assert (
        r.status_code == 200 and r.json()["outcome"] == "opted_out" and voice.calls[-1].to == "+919825022222"
    )


async def test_settings_and_script(client, ready):
    s, _ = await _setup(client)
    body = {"voice": "bright", "language": "en", "hours": "9-20", "attempts": "two_calls", "record": False}
    r = await client.put(f"{A}/settings", json=body, headers=auth(s))
    assert r.status_code == 200 and r.json() == {**body, "skip_dnd": True, "only_if_no_rating": True}
    bad = await client.put(
        f"{A}/settings", json={**body, "skip_dnd": False, "hours": "0-24"}, headers=auth(s)
    )
    assert bad.status_code == 422
    r = await client.put(f"{A}/script/ask_rating", json={"text": "Ask for a rating from 1 to 5, 5 is best."},
                         headers=auth(s))  # fmt: skip
    assert r.status_code == 200 and r.json()["version"] == 2
    assert next(x for x in r.json()["steps"] if x["key"] == "ask_rating")["text"].startswith(
        "Ask for a rating"
    )
    r = await client.put(
        f"{A}/script/greeting", json={"text": "Hello there, quick question."}, headers=auth(s)
    )
    assert r.status_code == 422 and r.json()["error"]["fields"] == {"text": "needs_job"}
    assert (
        await client.put(f"{A}/script/nope", json={"text": "Some text here"}, headers=auth(s))
    ).status_code == 404
    d = (await client.get(A, headers=auth(s))).json()
    assert d["settings"]["hours"] == "9-20" and d["script"]["version"] == 2 and d["can_act"]
    async with engine.begin() as c:
        acts = (
            (
                await c.execute(
                    text(
                        "SELECT action FROM audit_logs WHERE action LIKE 'staff.ai_call%' ORDER BY created_at"
                    )
                )
            )
            .scalars()
            .all()
        )
        await c.execute(text("UPDATE staff_users SET role = 'support'"))
    assert acts == ["staff.ai_call_settings_updated", "staff.ai_call_script_updated"]
    assert (await client.get(A, headers=auth(s))).json()["can_act"] is False
    assert (await client.put(f"{A}/settings", json=body, headers=auth(s))).status_code == 403
