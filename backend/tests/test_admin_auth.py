"""A01 admin log in with password + authenticator code, setup links, recovery codes, A03 dashboard."""

import pytest

from app.core import staff_security
from app.core.db import SessionLocal
from app.core.staff_security import current_step, totp_code
from app.models import AuditLog, StaffUser
from app.services import staff
from tests.conftest import auth, make_owner, token_from

A = "/api/v1/admin"
PW = "Admin1234"


async def _invite(email="navneet@artonest.com", role="super_admin") -> str:
    async with SessionLocal() as db:
        _, link = await staff.invite(db, email=email, name="Navneet Dhameliya", role=role)
        await db.commit()
    return token_from(link)


def _code(secret: str, offset: int = 0) -> str:
    return totp_code(secret, current_step() + offset)


async def _setup(client, email="navneet@artonest.com") -> tuple[dict, str]:
    token = await _invite(email)
    info = (await client.get(f"{A}/auth/setup", params={"token": token})).json()
    r = await client.post(
        f"{A}/auth/setup", json={"token": token, "password": PW, "code": _code(info["secret"])}
    )
    assert r.status_code == 200, r.text
    return r.json(), info["secret"]


async def test_setup_link_then_log_in_with_a_fresh_code(client, monkeypatch):
    token = await _invite()
    r = await client.get(f"{A}/auth/setup", params={"token": token})
    assert r.status_code == 200 and r.headers["cache-control"] == "no-store"
    info = r.json()
    assert info["email"] == "navneet@artonest.com" and not info["is_reset"]
    assert info["otpauth_uri"].startswith(
        "otpauth://totp/KaamNishaan%20Admin%3Anavneet%40artonest.com?secret="
    )

    # weak password and wrong code are refused
    r = await client.post(f"{A}/auth/setup", json={"token": token, "password": "short", "code": "000000"})
    assert r.json()["error"]["code"] == "password_weak"
    r = await client.post(f"{A}/auth/setup", json={"token": token, "password": PW, "code": "000000"})
    assert r.json()["error"]["code"] == "code_invalid"

    r = await client.post(
        f"{A}/auth/setup", json={"token": token, "password": PW, "code": _code(info["secret"])}
    )
    assert r.status_code == 200, r.text
    out = r.json()
    assert len(out["recovery_codes"]) == 8 and out["staff"]["role"] == "super_admin"
    assert out["staff"]["recovery_codes_left"] == 8
    # the link works once
    assert (await client.get(f"{A}/auth/setup", params={"token": token})).status_code == 410
    # the secret is stored encrypted, never as is
    async with SessionLocal() as db:
        row = (await db.execute(StaffUser.__table__.select())).first()
        assert info["secret"] not in row.totp_secret and row.password_hash.startswith("$argon2")

    # the code used for setup can't log in again; the next one can
    body = {"email": "Navneet@Artonest.com", "password": PW, "code": _code(info["secret"])}
    assert (await client.post(f"{A}/auth/login", json=body)).status_code == 401
    monkeypatch.setattr(staff_security, "current_step", lambda: current_step() + 1)
    body["code"] = _code(info["secret"], 1)
    r = await client.post(f"{A}/auth/login", json=body)
    assert r.status_code == 200, r.text
    s = r.json()
    me = (await client.get(f"{A}/me", headers=auth(s))).json()
    assert me["name"] == "Navneet Dhameliya"


async def test_wrong_tries_say_nothing_about_which_part_then_lock(client):
    _, secret = await _setup(client)
    wrong = {"email": "navneet@artonest.com", "password": "Wrong1234", "code": _code(secret)}
    r = await client.post(f"{A}/auth/login", json=wrong)
    assert r.status_code == 401
    err = r.json()["error"]
    assert err["code"] == "login_invalid" and err["details"]["attempts_left"] == 4 and not err["fields"]
    # unknown email: the same answer
    r = await client.post(f"{A}/auth/login", json={**wrong, "email": "nobody@x.com"})
    assert r.json()["error"]["code"] == "login_invalid"
    for _ in range(3):
        await client.post(f"{A}/auth/login", json=wrong)
    r = await client.post(f"{A}/auth/login", json=wrong)
    assert r.status_code == 403 and r.json()["error"]["code"] == "account_locked"
    # even the right details wait for the lock to end
    right = {"email": "navneet@artonest.com", "password": PW, "code": _code(secret, 1)}
    assert (await client.post(f"{A}/auth/login", json=right)).json()["error"]["code"] == "account_locked"
    async with SessionLocal() as db:
        actions = [a.action for a in (await db.execute(AuditLog.__table__.select())).all()]
    assert actions.count("staff.login_failed") == 6 and "staff.setup_done" in actions


async def test_recovery_code_works_once(client):
    out, _ = await _setup(client)
    code = out["recovery_codes"][0]
    body = {"email": "navneet@artonest.com", "password": PW, "recovery_code": code.upper()}
    r = await client.post(f"{A}/auth/login", json=body)
    assert r.status_code == 200 and r.json()["staff"]["recovery_codes_left"] == 7
    assert (await client.post(f"{A}/auth/login", json=body)).status_code == 401


async def test_refresh_rotates_and_logout_ends_the_session(client):
    out, _ = await _setup(client)
    r = await client.post(f"{A}/auth/refresh", json={"refresh_token": out["refresh_token"]})
    assert r.status_code == 200
    new = r.json()
    # the old refresh token coming back ends the session
    r = await client.post(f"{A}/auth/refresh", json={"refresh_token": out["refresh_token"]})
    assert r.status_code == 401
    assert (await client.get(f"{A}/me", headers=auth(new))).status_code == 401


async def test_logout(client):
    out, _ = await _setup(client)
    assert (await client.post(f"{A}/auth/logout", headers=auth(out))).status_code == 204
    assert (await client.get(f"{A}/me", headers=auth(out))).json()["error"]["code"] == "session_ended"


async def test_reset_clears_everything_and_old_links_stop(client):
    out, _ = await _setup(client)
    old = await _invite()  # invite again = reset
    async with SessionLocal() as db:
        person = await staff.get_by_email(db, "navneet@artonest.com")
        link = await staff.issue_setup_link(db, person)
        await db.commit()
    assert (await client.get(f"{A}/auth/setup", params={"token": old})).status_code == 410
    info = (await client.get(f"{A}/auth/setup", params={"token": token_from(link)})).json()
    assert info["is_reset"] is True
    assert (await client.get(f"{A}/me", headers=auth(out))).status_code == 401


async def test_app_tokens_do_not_open_the_admin_panel(client):
    owner = await make_owner(client)
    r = await client.get(f"{A}/dashboard", headers=auth(owner))
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"
    assert (await client.get(f"{A}/dashboard")).status_code == 401


@pytest.mark.parametrize("days", [7, 30])
async def test_dashboard_counts_from_the_database(client, days):
    await make_owner(client)
    await make_owner(client, email="b@coolright.in", company="CoolRight")
    await client.post(
        "/api/v1/public/contact",
        json={
            "name": "Ramesh",
            "email": "r@x.in",
            "topic": "sales",
            "message": "Please call me about pricing for 12 techs.",
        },
    )
    out, _ = await _setup(client)
    r = await client.get(f"{A}/dashboard", params={"days": days, "locale": "hi"}, headers=auth(out))
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["days"] == days and len(d["reports_per_day"]) == days
    assert d["active_companies"] == {"value": 2, "previous": 0}
    assert d["monthly_revenue"] == []  # trials pay nothing
    mix = {p["code"]: p["companies"] for p in d["plan_mix"]}
    assert sum(mix.values()) == 2
    kinds = [a["kind"] for a in d["activity"]]
    assert "company_created" in kinds and "lead_contact" in kinds and "staff_joined" in kinds
    assert any(a["kind"] == "new_leads" and a["count"] == 1 for a in d["attention"])
    # the top bar's bell shows the same list (A04)
    bell = (await client.get(f"{A}/alerts", headers=auth(out))).json()
    assert bell == d["attention"]
    assert (await client.get(f"{A}/dashboard", params={"days": 5}, headers=auth(out))).status_code == 422


async def test_bootstrap_makes_the_first_super_admin_once(monkeypatch, caplog):
    from app.core.config import get_settings

    monkeypatch.setattr(get_settings(), "admin_email", "Founder@KaamNishaan.com")
    await staff.bootstrap()
    await staff.bootstrap()  # second start: same person, still one account, link logged again
    async with SessionLocal() as db:
        rows = (await db.execute(StaffUser.__table__.select())).all()
    assert len(rows) == 1 and rows[0].role == "super_admin" and rows[0].email == "founder@kaamnishaan.com"
    assert rows[0].setup_version == 1  # a restart doesn't break the link already in the log
    assert caplog.text.count("/setup?token=") == 2
