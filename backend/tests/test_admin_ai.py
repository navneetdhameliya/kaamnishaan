"""A20 AI usage and cost: totals, cost per day, by company and by model, from ai_usage rows."""

from datetime import timedelta

from app.core.db import SessionLocal
from app.core.security import now
from app.models import AIUsage, Company
from app.providers.ai import audio_cost_usd, cost_usd
from app.services import ai_usage
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin/ai-usage"


async def _seed(client):
    await make_owner(client)
    await make_owner(client, email="mike@coolright.com", company="CoolRight HVAC")
    for i in range(5):
        await make_owner(client, email=f"o{i}@small.in", company=f"Small {i}")
    async with SessionLocal() as db:
        ids = {c.name: c.id for c in (await db.execute(Company.__table__.select())).all()}
        t = now()

        def row(task, company, cost, *, ok=True, days_ago=0, seconds=0.0, model="gpt-4o-mini"):
            db.add(
                AIUsage(
                    company_id=ids.get(company), task=task, model=model, cost_usd=cost, ok=ok,
                    audio_seconds=seconds, at=t - timedelta(days=days_ago),
                )
            )  # fmt: skip

        for _ in range(3):
            row("report_draft", "BrightAir", 0.10, days_ago=1)
        row("report_draft", "BrightAir", 0.0, ok=False, days_ago=1)  # a failed draft
        row("transcription", "CoolRight HVAC", 0.012, seconds=120, model="whisper-1", days_ago=2)
        row("assistant", "CoolRight HVAC", 0.02)
        for i in range(5):
            row("translation", f"Small {i}", 0.001 * (i + 1))
        row("translation", None, 0.004)  # a global checklist: no company
        row("report_draft", "BrightAir", 5.0, days_ago=40)  # outside 30 days
        await db.commit()


async def test_totals_chart_companies_and_models(client):
    await _seed(client)
    s, _ = await _setup(client)
    r = await client.get(f"{A}?days=30", headers=auth(s))
    assert r.status_code == 200, r.text
    d = r.json()
    total = 0.3 + 0.012 + 0.02 + 0.015 + 0.004
    assert abs(d["total_cost_usd"] - total) < 1e-6 and d["configured"] is False
    assert d["reports_drafted"] == 3 and d["draft_success"] == 0.75
    assert abs(d["cost_per_report_usd"] - round(total / 3, 4)) < 1e-6 and d["target_per_report_usd"] == 0.25
    assert d["voice_minutes"] == 2.0 and d["budget_usd"] is None

    # one bar per day, oldest first, ending today
    assert len(d["per_day"]) == 31 and d["per_day"][-1]["day"] == now().date().isoformat()
    assert abs(sum(x["report_draft"] for x in d["per_day"]) - 0.3) < 1e-6
    assert abs(d["per_day"][-1]["translation"] - 0.019) < 1e-6

    # the four most expensive companies, then everyone else (incl. calls without a company)
    assert [c["name"] for c in d["companies"]] == ["BrightAir", "CoolRight HVAC", "Small 4", "Small 3"]
    assert d["others_count"] == 3 and abs(d["others_cost_usd"] - (0.001 + 0.002 + 0.003 + 0.004)) < 1e-6

    m = {(x["task"], x["model"]): x for x in d["models"]}
    assert [x["task"] for x in d["models"]][0] == "report_draft"
    draft = m[("report_draft", "gpt-4o-mini")]
    assert draft["calls"] == 4 and draft["error_rate"] == 0.25 and abs(draft["avg_cost_usd"] - 0.1) < 1e-6
    whisper = m[("transcription", "whisper-1")]
    assert (
        whisper["per_minute"] and abs(whisper["avg_cost_usd"] - 0.006) < 1e-6 and whisper["error_rate"] == 0
    )

    week = (await client.get(f"{A}?days=7", headers=auth(s))).json()
    assert len(week["per_day"]) == 8 and week["reports_drafted"] == 3
    bad = await client.get(f"{A}?days=45", headers=auth(s))
    assert bad.status_code == 422 and bad.json()["error"]["fields"] == {"days": "choose_7_30_90"}


async def test_empty_and_needs_staff(client):
    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    assert d["total_cost_usd"] == 0 and d["cost_per_report_usd"] is None and d["draft_success"] is None
    assert d["companies"] == [] and d["models"] == [] and d["others_count"] == 0
    owner = await make_owner(client, email="x@x.in", company="X")
    assert (await client.get(A, headers=auth(owner))).status_code == 401


async def test_prices():
    assert audio_cost_usd("whisper-1", 120) == 0.012
    # OpenAI answers with dated names; they are priced like the base model
    assert cost_usd("gpt-4o-mini-2024-07-18", 1_000_000, 0) == 0.15
    assert cost_usd("unknown-model", 1000, 1000) == 0
    async with SessionLocal() as db:
        assert ai_usage.record(db, "assistant", company_id=None, tokens_in=1_000_000) == 0.15
        assert ai_usage.record(db, "assistant", company_id=None, tokens_in=1_000_000, ok=False) == 0
        await db.rollback()
