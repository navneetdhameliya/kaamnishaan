"""M36 Ask KaamNishaan AI: answers from the company's own jobs with the reports they used, the
monthly question limit, and who may ask."""

import pytest
from sqlalchemy import text

from app.core.db import engine
from app.providers.ai import Draft, set_ai_for_tests
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_reports import FakeAI, ready  # noqa: F401 - the `ready` fixture
from tests.test_sharing import approved


class FakeAssistant(FakeAI):
    """Drafts reports like the report tests; answers with the first report it sees and remembers what
    it was given."""

    def __init__(self):
        super().__init__()
        self.contexts: list[dict] = []

    async def answer(self, system_prompt, context, history, question):
        self.contexts.append({"prompt": system_prompt, "context": context, "history": history, "q": question})
        if self.fail:
            raise RuntimeError("AI is down")
        job = context["jobs"][0]
        report = job["report"]
        return Draft(
            data={
                "answer": f"{job['customer']}: {report['number'] if report else 'no report yet'}.",
                "report_ids": [report["report_id"]] if report else [],
                "job_ids": [job["job_id"], "not-a-real-id"],
            },
            model="gpt-4o-mini",
            tokens_in=900,
            tokens_out=40,
        )


@pytest.fixture
def fake_assistant():
    ai = FakeAssistant()
    set_ai_for_tests(ai)
    yield ai
    set_ai_for_tests(None)


async def test_answers_from_the_companys_jobs(client, ready, fake_assistant):
    owner = ready["owner"]
    await approved(client, ready)
    empty = (await client.get("/api/v1/assistant", headers=auth(owner))).json()
    assert empty["data"] == [] and empty["used"] == 0 and empty["limit"] == 1000 and empty["available"]
    r = await client.post(
        "/api/v1/assistant/ask",
        json={"text": "When did we last service Sharma Textiles?"},
        headers=auth(owner),
    )
    assert r.status_code == 200, r.text
    out = r.json()
    assert out["question"]["role"] == "user" and out["used"] == 1 and not out["paused"]
    a = out["answer"]
    assert a["text"] == f"{ready['customer']['name']}: R-1001."
    assert [x["number"] for x in a["reports"]] == ["R-1001"] and a["reports"][0]["cover_url"]
    assert len(a["jobs"]) == 1 and a["photo_count"] >= 2  # the made-up id is dropped
    ctx = fake_assistant.contexts[0]["context"]
    assert ctx["jobs"][0]["customer"] == ready["customer"]["name"] and ctx["jobs"][0]["report"]["summary"]
    assert "English" in fake_assistant.contexts[0]["prompt"]
    # the next question carries the conversation
    await client.post("/api/v1/assistant/ask", json={"text": "And before that?"}, headers=auth(owner))
    assert [m["role"] for m in fake_assistant.contexts[1]["history"]] == ["user", "assistant"]
    hist = (await client.get("/api/v1/assistant", headers=auth(owner))).json()
    assert [m["role"] for m in hist["data"]] == ["user", "assistant", "user", "assistant"] and hist[
        "used"
    ] == 2
    tiles = {
        t["key"]: t["used"]
        for t in (await client.get("/api/v1/billing", headers=auth(owner))).json()["usage"]
    }
    assert tiles["ai_questions"] == 2


async def test_open_jobs_list_the_missing_proof(client, ready, fake_assistant):
    r = await client.post(
        "/api/v1/assistant/ask", json={"text": "What is missing?"}, headers=auth(ready["owner"])
    )
    assert r.status_code == 200, r.text
    job = fake_assistant.contexts[0]["context"]["jobs"][0]
    # the ready job has its before and after photos, but no photo while working and no voice note
    assert job["report"] is None and set(job["missing_proof"]) == {"during", "voice"}
    assert set(r.json()["answer"]["jobs"][0]["missing"]) == {"during", "voice"}


async def test_the_monthly_limit_pauses_chat(client, ready, fake_assistant):
    owner = ready["owner"]
    async with engine.begin() as c:
        await c.execute(text("update plans set ai_questions_monthly = 1 where code = 'professional'"))
    try:
        assert (
            await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(owner))
        ).status_code == 200
        r = await client.post("/api/v1/assistant/ask", json={"text": "Again"}, headers=auth(owner))
        assert r.status_code == 402 and r.json()["error"]["code"] == "ai_limit_reached"
        assert r.json()["error"]["details"]["limit"] == 1
        assert (await client.get("/api/v1/assistant", headers=auth(owner))).json()["paused"] is True
    finally:
        async with engine.begin() as c:
            await c.execute(text("update plans set ai_questions_monthly = 1000 where code = 'professional'"))


async def test_failures_are_not_counted_and_only_the_office_may_ask(client, ready, fake_assistant):
    owner = ready["owner"]
    fake_assistant.fail = True
    r = await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(owner))
    assert r.status_code == 502 and r.json()["error"]["code"] == "assistant_failed"
    assert (await client.get("/api/v1/assistant", headers=auth(owner))).json()["used"] == 0
    assert (await client.get("/api/v1/assistant", headers=auth(ready["tech"]))).status_code == 403
    tech2 = await invite_and_join(client, owner, "+919898989898")
    assert (
        await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(tech2))
    ).status_code == 403
    # another company sees none of this
    other = await make_owner(client, email="x@other.in", company="Other Co")
    fake_assistant.fail = False
    await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(other))
    assert all(
        j["customer"] != ready["customer"]["name"] for j in fake_assistant.contexts[-1]["context"]["jobs"]
    )


async def test_without_an_ai_key_it_says_so(client, ready):
    r = await client.post("/api/v1/assistant/ask", json={"text": "Hi"}, headers=auth(ready["owner"]))
    assert r.status_code == 503 and r.json()["error"]["code"] == "assistant_unavailable"
    assert (await client.get("/api/v1/assistant", headers=auth(ready["owner"]))).json()["available"] is False
