"""A19 AI configuration, A21 Prompt management, A22 Industries."""

import pytest
from sqlalchemy import select, text, update

from app.core.db import SessionLocal, engine
from app.models import AIUsage, AuditLog, StaffUser
from app.services.ai_config import masked
from tests.conftest import auth
from tests.test_admin_auth import _setup
from tests.test_reports import fake_ai, make_report, ready  # noqa: F401 - fixtures

A = "/api/v1/admin"


@pytest.fixture
async def seed_back():
    """Prompts and industries are seed data kept between tests: put them back afterwards."""
    async with engine.begin() as conn:
        prompts = (await conn.execute(text("SELECT * FROM prompt_versions"))).mappings().all()
        industries = (await conn.execute(text("SELECT * FROM industries"))).mappings().all()
    yield
    async with engine.begin() as conn:
        await conn.execute(text("DELETE FROM prompt_versions"))
        for p in prompts:
            await conn.execute(text(f"INSERT INTO prompt_versions ({', '.join(p)}) VALUES "
                                    f"({', '.join(':' + k for k in p)})"), dict(p))  # fmt: skip
        await conn.execute(text("UPDATE companies SET industry_slug = NULL WHERE industry_slug = 'plumbing'"))
        await conn.execute(text("DELETE FROM industries WHERE slug = 'plumbing'"))
        for i in industries:
            await conn.execute(
                text("UPDATE industries SET name = CAST(:name AS jsonb), status = :status, sort = :sort "
                     "WHERE slug = :slug"),
                {**i, "name": __import__("json").dumps(i["name"])},
            )  # fmt: skip


async def test_ai_config_budget_and_fallback(client, ready, fake_ai, seed_back):
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/ai-config", headers=auth(s))).json()
    assert d["can_act"] and d["key_set"] and "gpt-4o-mini" in d["text_models"] and d["month_spend_usd"] == 0
    cfg = d["config"]
    assert cfg["mask_contacts"] is True and cfg["fallback"] == "error" and cfg["max_tokens_report"] == 3000

    bad = await client.put(f"{A}/ai-config", json={**cfg, "text_model": "made-up"}, headers=auth(s))
    assert bad.json()["error"]["code"] == "unknown_model"

    # the AI fails: with the template fallback the report is still written
    out = (await client.put(f"{A}/ai-config", json={**cfg, "fallback": "template"}, headers=auth(s))).json()
    assert out["config"]["fallback"] == "template"
    fake_ai.fail = True
    _, task, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    assert task["status"] == "done" and rep["drafted_by"] == "template" and rep["status"] == "draft"
    fake_ai.fail = False

    # over the monthly budget: reports are written from the template and the AI isn't asked
    async with SessionLocal() as db:
        db.add(AIUsage(task="report_draft", model="gpt-4o-mini", cost_usd=5.0))
        await db.commit()
    await client.put(f"{A}/ai-config", json={**cfg, "monthly_budget_usd": 4}, headers=auth(s))
    calls = len(fake_ai.calls)
    _, task, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    assert rep["drafted_by"] == "template" and len(fake_ai.calls) == calls
    async with SessionLocal() as db:
        acts = (
            (await db.execute(select(AuditLog.action).where(AuditLog.target_type == "platform")))
            .scalars()
            .all()
        )
        assert acts.count("ai_config.updated") == 2


def test_contacts_are_hidden_before_sending():
    out = masked({"notes": ["Call Ravi on 98250 11111 or ravi@x.in", 12], "id": "photo:1"})
    assert "98250" not in out["notes"][0] and "ravi@x.in" not in out["notes"][0] and out["notes"][1] == 12
    assert out["id"] == "photo:1"
    assert masked({"a": "98250 11111"}, False) == {"a": "98250 11111"}


async def test_prompt_draft_publish_and_go_back(client, ready, fake_ai, seed_back):
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/prompts", headers=auth(s))).json()
    assert [p["task"] for p in d["prompts"]] == ["report_draft", "assistant", "translation"]
    rd = d["prompts"][0]
    assert rd["live"] == 1 and rd["draft"] is None and rd["variables"] == ["language"]
    assert (
        "{language}" in rd["versions"][0]["system_prompt"] and "{{" not in rd["versions"][0]["system_prompt"]
    )

    no_var = await client.put(
        f"{A}/prompts/report_draft/draft", json={"system_prompt": "x" * 60}, headers=auth(s)
    )
    assert no_var.status_code == 422
    new = rd["versions"][0]["system_prompt"] + "\nMARKER-V2"
    out = (await client.put(f"{A}/prompts/report_draft/draft", json={"system_prompt": new, "note": "shorter"},
                            headers=auth(s))).json()  # fmt: skip
    rd = out["prompts"][0]
    assert rd["draft"] == 2 and rd["live"] == 1 and rd["versions"][0]["edited_by"]

    # nothing changes until it's published
    await make_report(client, ready["tech"], ready["job"]["id"])
    assert "MARKER-V2" not in fake_ai.calls[-1] and "{language}" not in fake_ai.calls[-1]
    out = (await client.post(f"{A}/prompts/report_draft/versions/2/publish", headers=auth(s))).json()
    rd = out["prompts"][0]
    assert rd["live"] == 2 and rd["draft"] is None
    assert [v["status"] for v in rd["versions"]] == ["live", "retired"] and rd["versions"][0]["published_by"]
    _, _, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    assert "MARKER-V2" in fake_ai.calls[-1] and "English" in fake_ai.calls[-1]

    out = (await client.get(f"{A}/prompts", headers=auth(s))).json()
    v2 = out["prompts"][0]["versions"][0]
    assert v2["reports"] == 1 and v2["flagged"] == 1  # the fake AI writes one sentence with no proof
    assert out["prompts"][0]["stats"]["runs"] >= 2

    # go back to v1; start and throw away a draft
    out = (await client.post(f"{A}/prompts/report_draft/versions/1/publish", headers=auth(s))).json()
    assert out["prompts"][0]["live"] == 1
    await client.put(f"{A}/prompts/assistant/draft", json={"system_prompt": "Answer in {language}. " * 3},
                     headers=auth(s))  # fmt: skip
    out = (await client.delete(f"{A}/prompts/assistant/draft", headers=auth(s))).json()
    assert out["prompts"][1]["draft"] is None and [v["version"] for v in out["prompts"][1]["versions"]] == [1]
    assert (
        await client.post(f"{A}/prompts/report_draft/versions/9/publish", headers=auth(s))
    ).status_code == 404


async def test_industries(client, seed_back):
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/industries", headers=auth(s))).json()
    hvac = next(i for i in d["items"] if i["slug"] == "hvac")
    assert hvac["status"] == "live" and hvac["checklists"] == 4 and hvac["default_questions"] > 0

    body = {"slug": "plumbing", "name": {"en": "Plumbing", "hi": "प्लंबिंग"}, "status": "draft", "sort": 7}
    r = await client.post(f"{A}/industries", json=body, headers=auth(s))
    assert r.status_code == 201
    plumbing = next(i for i in r.json()["items"] if i["slug"] == "plumbing")
    assert (
        plumbing["companies"] == 0 and plumbing["checklists"] == 0 and plumbing["default_checklist"] is None
    )
    trades = lambda c: [t["key"] for t in c["trades"]]  # noqa: E731
    assert "plumbing" not in trades((await client.get("/api/v1/config")).json())

    await client.put(
        f"{A}/industries/plumbing", json={**body, "slug": None, "status": "live"}, headers=auth(s)
    )
    assert "plumbing" in trades((await client.get("/api/v1/config")).json())
    assert (await client.post(f"{A}/industries", json=body, headers=auth(s))).status_code == 409
    assert (
        await client.post(f"{A}/industries", json={**body, "slug": "Bad Slug"}, headers=auth(s))
    ).status_code == 422

    async with SessionLocal() as db:
        await db.execute(update(StaffUser).values(role="support"))
        await db.commit()
    assert (await client.get(f"{A}/industries", headers=auth(s))).json()["can_act"] is False
    assert (
        await client.put(f"{A}/industries/hvac", json={**body, "slug": None}, headers=auth(s))
    ).status_code == 403
    assert (await client.get(f"{A}/prompts", headers=auth(s))).json()["can_act"] is False
