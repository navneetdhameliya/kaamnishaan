"""A40 Usage and credits: numbers, rules, plan credits, one company's credits and adjusting them."""

import pytest
from sqlalchemy import select, text, update

from app.core.db import SessionLocal, engine
from app.models import Company, CreditWallet
from app.services import credits
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin"


async def _companies(client):
    await make_owner(client)  # BrightAir, professional: 1,500 a month
    await make_owner(client, email="mike@coolright.com", company="CoolRight HVAC")
    await make_owner(client, email="ravi@sunpeak.in", company="SunPeak Solar")
    async with SessionLocal() as db:
        await db.execute(
            update(Company).where(Company.name == "SunPeak Solar").values(plan_code="enterprise")
        )
        cool = (await db.execute(select(Company).where(Company.name == "CoolRight HVAC"))).scalar_one()
        await db.execute(update(Company).where(Company.id == cool.id).values(plan_code="free"))
        await db.flush()
        await db.refresh(cool)
        for _ in range(100):  # use all 100 free credits
            assert await credits.spend(db, cool, "sms", "reminder")
        assert not await credits.can_spend(db, cool, "sms")
        await db.commit()
        return cool.id


@pytest.fixture
async def plans_back():
    """Plans are seed data kept between tests: put the monthly credits back afterwards."""
    yield
    async with engine.begin() as conn:
        await conn.execute(text("UPDATE plans SET monthly_credits = 1500 WHERE code = 'professional'"))


async def test_overview_rules_and_adjust(client, plans_back):
    cool = await _companies(client)
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/credits", headers=auth(s))).json()
    assert d["rules"] == {"sms": 1, "whatsapp": 1, "ai_call": 10} and d["can_act"]
    assert {p["code"]: p["monthly_credits"] for p in d["plans"]}["enterprise"] is None
    rows = {r["company"]: r for r in d["items"]}
    assert [r["company"] for r in d["items"]][0] == "CoolRight HVAC"  # out of credits first
    assert rows["CoolRight HVAC"] | {"company_id": None} == {
        "company_id": None, "company": "CoolRight HVAC", "plan": "Free", "included": 100, "used": 100,
        "topup_left": 0, "topups": 0, "status": "out",
    }  # fmt: skip
    assert rows["BrightAir"]["included"] == 1500 and rows["BrightAir"]["status"] == "ok"
    assert rows["SunPeak Solar"]["status"] == "unlimited" and rows["SunPeak Solar"]["included"] is None
    k = d["kpis"]
    assert (
        k["used_30d"] == 100 and k["sms_30d"] == 100 and k["out_of_credits"] == 1 and k["included_30d"] >= 100
    )

    # give CoolRight 50 extra credits; taking back more than it has is refused
    url = f"{A}/companies/{cool}/credits"
    assert (
        await client.post(url, json={"credits": 50, "reason": "Goodwill"}, headers=auth(s))
    ).status_code == 204
    r = await client.post(url, json={"credits": -60, "reason": "Mistake"}, headers=auth(s))
    assert r.status_code == 409 and r.json()["error"]["code"] == "not_enough"
    assert (
        await client.post(url, json={"credits": 0, "reason": "Nothing"}, headers=auth(s))
    ).status_code == 422
    row = next(r for r in (await client.get(f"{A}/credits?q=cool", headers=auth(s))).json()["items"])
    assert (row["topup_left"], row["topups"], row["status"]) == (50, 1, "ok")

    # rules: an SMS now costs 2; professional gets 2,000 from its next month
    body = {"sms": 2, "whatsapp": 1, "ai_call": 10, "plans": {"professional": 2000}}
    assert (await client.put(f"{A}/credits/rules", json=body, headers=auth(s))).status_code == 204
    async with SessionLocal() as db:
        c = await db.get(Company, cool)
        assert await credits.spend(db, c, "sms", "reminder")
        w = await db.get(CreditWallet, cool)
        assert w.topup_credits == 48
        await db.commit()
    plans = (await client.get("/api/v1/plans?currency=INR")).json()
    assert plans["credit_rules"]["sms"] == 2
    assert next(p for p in plans["plans"] if p["code"] == "professional")["monthly_credits"] == 2000
    bad = await client.put(f"{A}/credits/rules", json={**body, "plans": {"gold": 5}}, headers=auth(s))
    assert bad.status_code == 422 and bad.json()["error"]["fields"] == {"plans.gold": "unknown"}
    assert (
        await client.put(f"{A}/credits/rules", json={**body, "sms": 0}, headers=auth(s))
    ).status_code == 422
    async with engine.begin() as conn:
        acts = (
            await conn.execute(
                text(
                    "SELECT action, data FROM audit_logs WHERE action LIKE 'staff.cred%' ORDER BY created_at"
                )
            )
        ).all()
    assert [a for a, _ in acts] == ["staff.credits_adjusted", "staff.credit_rules_updated"]
    assert acts[1][1] == {"sms": 2, "plan.professional": 2000}

    csv = await client.get(f"{A}/credits.csv", headers=auth(s))
    assert csv.status_code == 200 and csv.text.startswith("Company,Plan") and "CoolRight HVAC" in csv.text

    async with engine.begin() as conn:
        await conn.execute(text("UPDATE staff_users SET role = 'support'"))
    assert (await client.get(f"{A}/credits", headers=auth(s))).json()["can_act"] is False
    assert (await client.put(f"{A}/credits/rules", json=body, headers=auth(s))).status_code == 403
    assert (
        await client.post(url, json={"credits": 5, "reason": "Hi there"}, headers=auth(s))
    ).status_code == 403
