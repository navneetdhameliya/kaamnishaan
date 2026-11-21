"""A30 Analytics, A34 Storage, A35 Localization and A36 My profile."""

from datetime import timedelta

from sqlalchemy import update

from app.core.db import SessionLocal
from app.core.security import now
from app.models import Report, StaffUser
from app.services.staff import device_name
from tests.conftest import auth, make_owner
from tests.test_admin_auth import PW, _code, _setup
from tests.test_reports import fake_ai, make_report, ready  # noqa: F401 - fixtures

A = "/api/v1/admin"


async def test_analytics_storage_and_localization(client, ready, fake_ai):
    _, _, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    t = now()
    async with SessionLocal() as db, db.begin():
        await db.execute(
            update(Report)
            .where(Report.id == rep["id"])
            .values(status="shared", submitted_at=t - timedelta(minutes=40), approved_at=t, shared_at=t)
        )
    s, _ = await _setup(client)
    r = await client.get(f"{A}/analytics?days=30", headers=auth(s))
    assert r.status_code == 200, r.text
    a = r.json()
    assert a["reports_sent"] == {"value": 1, "previous": 0} and a["step"] == "day"
    assert a["review_minutes"]["value"] == 40.0 and a["first_time"]["value"] == 100.0
    assert a["active_technicians"]["value"] == 1 and sum(b["count"] for b in a["sent_by_period"]) == 1
    assert len(a["sent_by_period"]) in (30, 31) and a["reports_by_industry"][0]["count"] == 1
    week = (await client.get(f"{A}/analytics?days=90", headers=auth(s))).json()
    assert week["step"] == "week" and 13 <= len(week["sent_by_period"]) <= 14

    st = (await client.get(f"{A}/storage", headers=auth(s))).json()
    photos = next(k for k in st["kinds"] if k["kind"] == "photos")
    assert photos["files"] == 2 and st["total_bytes"] >= photos["bytes"] > 0
    assert st["top_companies"][0]["name"] == "BrightAir" and st["link_minutes"] == 15

    loc = (await client.get(f"{A}/localization", headers=auth(s))).json()
    assert loc["report_language"] == "en" and loc["languages"][0]["app_checked"] == 100
    assert loc["languages"][1]["app_checked"] == 0
    r = await client.put(f"{A}/localization", json={"report_language": "hi"}, headers=auth(s))
    assert r.json()["report_language"] == "hi"
    other = await make_owner(client, email="second@brightair.in", company="CoolAir")
    assert other["user"]["company"]["report_language"] == "hi"


async def _fresh_code(secret: str) -> str:
    """Codes only work once per 30 s: forget the last one used, so the test needn't wait."""
    async with SessionLocal() as db, db.begin():
        await db.execute(update(StaffUser).values(totp_last_step=None))
    return _code(secret)


async def test_my_profile(client):
    s, secret = await _setup(client)
    r = await client.put(f"{A}/me", json={"name": "Navneet D", "lang": "gu"}, headers=auth(s))
    assert r.json()["name"] == "Navneet D" and r.json()["lang"] == "gu"
    assert (await client.get(f"{A}/me", headers=auth(s))).json()["lang"] == "gu"

    # a second device, then end it from here
    other = (await client.post(f"{A}/auth/login", json={"email": "navneet@artonest.com", "password": PW,
                                                          "code": await _fresh_code(secret)},
                               headers={"user-agent": "Mozilla/5.0 (iPad; CPU OS 17_0) Safari/604.1"})).json()  # fmt: skip
    devs = (await client.get(f"{A}/me/sessions", headers=auth(s))).json()["items"]
    assert len(devs) == 2 and devs[0]["current"] and devs[1]["device"] == "Safari on iPad"
    assert (await client.delete(f"{A}/me/sessions/{devs[0]['id']}", headers=auth(s))).status_code == 400
    r = await client.delete(f"{A}/me/sessions/{devs[1]['id']}", headers=auth(s))
    assert len(r.json()["items"]) == 1
    assert (await client.get(f"{A}/me", headers=auth(other))).status_code == 401

    bad = await client.post(f"{A}/me/password", json={"current_password": "nope", "new_password": "Better1234",
                                                      "code": "000000"}, headers=auth(s))  # fmt: skip
    assert bad.json()["error"]["code"] == "password_wrong"
    bad = await client.post(f"{A}/me/password", json={"current_password": PW, "new_password": "Better1234",
                                                      "code": "000000"}, headers=auth(s))  # fmt: skip
    assert bad.json()["error"]["code"] == "code_invalid"
    ok = await client.post(f"{A}/me/password", json={"current_password": PW, "new_password": "Better1234",
                                                     "code": await _fresh_code(secret)}, headers=auth(s))  # fmt: skip
    assert ok.status_code == 200, ok.text
    codes = await client.post(
        f"{A}/me/recovery-codes", json={"code": await _fresh_code(secret)}, headers=auth(s)
    )
    assert codes.status_code == 200 and len(codes.json()["recovery_codes"]) == 8


def test_device_names():
    mac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130.0 Safari/537.36"
    assert device_name(mac) == "Chrome on macOS" and device_name(None) == "Browser"
