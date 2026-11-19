"""A04 Companies list (search, filters, tabs, CSV) and A05 Company details."""

from sqlalchemy import update

from app.core.db import SessionLocal
from app.models import Company
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin"


async def _companies(client):
    a = await make_owner(client)
    await invite_and_join(client, a, "+919800000001")
    await make_owner(client, email="mike@coolright.com", company="CoolRight HVAC")
    await make_owner(
        client, email="ravi@sunpeak.in", company="=SunPeak Solar"
    )  # a name that looks like a formula
    async with SessionLocal() as db:
        await db.execute(
            update(Company).where(Company.name == "CoolRight HVAC").values(status="past_due", country="US")
        )
        await db.commit()
    staff, _ = await _setup(client)
    return staff


async def test_list_tabs_search_and_filters(client):
    s = await _companies(client)
    r = await client.get(f"{A}/companies", headers=auth(s))
    assert r.status_code == 200, r.text
    d = r.json()
    assert (
        d["total"] == 3
        and d["counts"]["all"] == 3
        and d["counts"]["past_due"] == 1
        and d["counts"]["trial"] == 2
    )
    bright = next(i for i in d["items"] if i["name"] == "BrightAir")
    assert bright["owner_email"] == "owner@brightair.in" and bright["technicians"] == 1
    assert bright["industry"] == "HVAC" and bright["badge"] == "trial" and bright["trial_days_left"] > 0
    assert d["countries"] == ["IN", "US"] and any(p["value"] == "professional" for p in d["plans"])

    # search by owner email, and by company name
    r = await client.get(f"{A}/companies", params={"q": "MIKE@cool"}, headers=auth(s))
    assert [i["name"] for i in r.json()["items"]] == ["CoolRight HVAC"]
    r = await client.get(f"{A}/companies", params={"status": "past_due"}, headers=auth(s))
    assert r.json()["total"] == 1
    r = await client.get(f"{A}/companies", params={"country": "IN", "sort": "name"}, headers=auth(s))
    names = [i["name"] for i in r.json()["items"]]
    # where "=" sorts depends on the database's language rules, so only the set is checked
    assert sorted(names) == ["=SunPeak Solar", "BrightAir"]
    # nothing matches: counts follow the search
    r = await client.get(
        f"{A}/companies", params={"q": "riverside plumbing", "plan": "business"}, headers=auth(s)
    )
    assert r.json()["total"] == 0 and r.json()["counts"]["all"] == 0
    # paging
    r = await client.get(f"{A}/companies", params={"page_size": 5, "page": 2}, headers=auth(s))
    assert r.json()["items"] == [] and r.json()["total"] == 3


async def test_csv_has_every_row_and_no_formulas(client):
    s = await _companies(client)
    r = await client.get(f"{A}/companies.csv", headers=auth(s))
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/csv")
    assert "attachment" in r.headers["content-disposition"]
    lines = r.text.lstrip("﻿").strip().splitlines()
    assert lines[0].startswith("Company,Owner") and len(lines) == 4
    assert any(line.startswith("'=SunPeak Solar") for line in lines)


async def test_company_details(client):
    s = await _companies(client)
    rows = (await client.get(f"{A}/companies", params={"q": "BrightAir"}, headers=auth(s))).json()["items"]
    r = await client.get(f"{A}/companies/{rows[0]['id']}", params={"locale": "hi"}, headers=auth(s))
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["name"] == "BrightAir" and d["owner_name"] == "Asha Patel" and d["members"] == 2
    assert d["technicians"] == 1 and [m["role"] for m in d["team"]] == ["owner", "technician"]
    assert d["team"][0]["login"] == "email" and d["team"][1]["login"] == "phone"
    assert d["health"] == "good" and d["reports_this_cycle"] == 0 and d["upgrade_to"] is None
    assert d["plan"]["code"] == "professional"
    bad = await client.get(f"{A}/companies/00000000-0000-0000-0000-000000000000", headers=auth(s))
    assert bad.status_code == 404


async def test_only_staff(client):
    owner = await make_owner(client)
    assert (await client.get(f"{A}/companies", headers=auth(owner))).status_code == 401
    assert (await client.get(f"{A}/companies.csv")).status_code == 401
