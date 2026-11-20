"""A16 Subscriptions, A17 Plans and pricing, A18 Payments."""

import json
from datetime import timedelta

import pytest
from sqlalchemy import select, text, update

from app.core.db import SessionLocal, engine
from app.core.security import now
from app.models import AuditLog, Company
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin"


@pytest.fixture
async def plans_back():
    """Plans and packs are seed data kept between tests: put them back afterwards."""
    async with engine.begin() as conn:
        plans = (
            await conn.execute(
                text(
                    "SELECT code, name, prices, technician_limit, report_limit_monthly, "
                    "monthly_credits, ai_questions_monthly, most_popular, is_public FROM plans"
                )
            )
        ).all()
        packs = (await conn.execute(text("SELECT id, prices, active FROM credit_packs"))).all()
    yield
    async with engine.begin() as conn:
        for p in plans:
            await conn.execute(
                text(
                    "UPDATE plans SET name = CAST(:n AS jsonb), prices = CAST(:pr AS jsonb), technician_limit = :t, "
                    "report_limit_monthly = :r, monthly_credits = :c, ai_questions_monthly = :q, most_popular = :m, "
                    "is_public = :pub WHERE code = :code"
                ),
                {
                    "n": json.dumps(p[1]),
                    "pr": json.dumps(p[2]),
                    "t": p[3],
                    "r": p[4],
                    "c": p[5],
                    "q": p[6],
                    "m": p[7],
                    "pub": p[8],
                    "code": p[0],
                },
            )
        for k in packs:
            await conn.execute(
                text("UPDATE credit_packs SET prices = CAST(:pr AS jsonb), active = :a WHERE id = :id"),
                {"pr": json.dumps(k[1]), "a": k[2], "id": k[0]},
            )


async def test_subscriptions(client):
    s, _ = await _setup(client)
    await make_owner(client)  # BrightAir, on a Professional trial
    await make_owner(client, "owner@cool.in", "CoolRight")
    async with SessionLocal() as db:
        cool = (await db.execute(select(Company).where(Company.name == "CoolRight"))).scalar_one()
        cool.status, cool.trial_ends_at = "active", None
        bright = (await db.execute(select(Company).where(Company.name == "BrightAir"))).scalar_one()
        bright.trial_ends_at = now() + timedelta(days=3)
        await db.commit()

    d = (await client.get(f"{A}/subscriptions", headers=auth(s))).json()
    assert d["kpis"]["mrr"] == [{"currency": "INR", "amount_minor": 129900}]
    assert d["kpis"]["paying"] == 1 and d["kpis"]["trials"] == 1 and d["kpis"]["trials_ending_7d"] == 1
    assert [r["name"] for r in d["items"]] == ["BrightAir", "CoolRight"]  # trials before active
    bright, cool = d["items"]
    assert bright["status"] == "trial" and bright["trial_days_left"] == 3 and bright["renews_at"]
    assert cool["price"] == {"currency": "INR", "amount_minor": 129900} and cool["seats"] == 0
    assert cool["seat_limit"] == 10 and cool["renews_at"]
    assert (await client.get(f"{A}/subscriptions", params={"status": "active"}, headers=auth(s))).json()[
        "total"
    ] == 1
    r = await client.get(f"{A}/subscriptions.csv", headers=auth(s))
    assert r.text.startswith("Company,Plan") and "1299.00,INR" in r.text


async def test_plans_edit_trial_and_packs(client, plans_back):
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/plans", headers=auth(s))).json()
    assert [p["code"] for p in d["plans"]][:2] == ["free", "starter"] and d["can_act"]
    assert d["trial"] == {"plan_code": "professional", "days": 14} and d["pricing_url"].endswith("/pricing")
    starter = next(p for p in d["plans"] if p["code"] == "starter")

    body = {
        "name": {"en": "Starter", "hi": "स्टार्टर"},
        "prices": {"INR": 59900, "USD": 1000},
        "technician_limit": 4,
        "report_limit_monthly": 80,
        "monthly_credits": 400,
        "ai_questions_monthly": 200,
        "most_popular": True,
        "is_public": True,
    }
    out = (await client.put(f"{A}/plans/starter", json=body, headers=auth(s))).json()
    by = {p["code"]: p for p in out["plans"]}
    assert by["starter"]["prices"] == {"INR": 59900, "USD": 1000} and by["starter"]["technician_limit"] == 4
    assert by["starter"]["most_popular"] and not by["professional"]["most_popular"]  # only one
    site = (await client.get("/api/v1/plans", params={"currency": "INR"})).json()
    assert next(p for p in site["plans"] if p["code"] == "starter")["price"]["amount"] == 59900

    bad = await client.put(
        f"{A}/plans/starter", json={**body, "prices": {"INR": 0, "USD": 900}}, headers=auth(s)
    )
    assert bad.json()["error"]["code"] == "free_mismatch"
    bad = await client.put(f"{A}/plans/starter", json={**body, "prices": {"INR": 100}}, headers=auth(s))
    assert bad.status_code == 422
    hide = await client.put(f"{A}/plans/professional", json={**body, "name": {"en": "Professional"},
                                                             "is_public": False}, headers=auth(s))  # fmt: skip
    assert hide.json()["error"]["code"] == "trial_plan"

    # the trial: plan and length, used for the next sign-up
    assert (
        await client.put(f"{A}/trial", json={"plan_code": "free", "days": 14}, headers=auth(s))
    ).status_code == 400
    out = (await client.put(f"{A}/trial", json={"plan_code": "starter", "days": 7}, headers=auth(s))).json()
    assert out["trial"] == {"plan_code": "starter", "days": 7}
    assert (await client.get("/api/v1/plans", params={"currency": "INR"})).json()["trial_days"] == 7
    await make_owner(client)
    async with SessionLocal() as db:
        c = (await db.execute(select(Company))).scalar_one()
        assert c.plan_code == "starter" and 6 <= (c.trial_ends_at - now()).days <= 7
    await client.put(f"{A}/trial", json={"plan_code": "professional", "days": 14}, headers=auth(s))

    pack = d["packs"][0]
    out = (await client.put(f"{A}/credit-packs/{pack['id']}", json={"prices": {"INR": 89900, "USD": 1100},
                                                                     "active": False}, headers=auth(s))).json()  # fmt: skip
    assert out["packs"][0] == {**pack, "prices": {"INR": 89900, "USD": 1100}, "active": False}
    async with SessionLocal() as db:
        acts = (
            (await db.execute(select(AuditLog.action).where(AuditLog.staff_id.is_not(None)))).scalars().all()
        )
        assert {"plan.updated", "trial.updated", "credit_pack.updated"} <= set(acts)
    assert starter["companies"] == 0


async def test_only_super_admins_change_pricing(client, plans_back):
    s, _ = await _setup(client)
    async with SessionLocal() as db:
        from app.models import StaffUser

        await db.execute(update(StaffUser).values(role="admin"))
        await db.commit()
    d = (await client.get(f"{A}/plans", headers=auth(s))).json()
    assert d["can_act"] is False
    r = await client.put(f"{A}/trial", json={"plan_code": "starter", "days": 7}, headers=auth(s))
    assert r.status_code == 403
    p = (await client.get(f"{A}/payments", headers=auth(s))).json()
    assert p == {"connected": False, "provider": "razorpay", "items": []}
