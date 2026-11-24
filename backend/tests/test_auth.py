from datetime import timedelta

from sqlalchemy import update

from app.core.db import SessionLocal
from app.core.security import now
from app.models import OtpChallenge
from tests.conftest import auth, last_email, last_sms, phone_login, token_from

PHONE = "+919876543210"


# ---- phone codes --------------------------------------------------------------------------
async def test_new_phone_gets_an_account_and_onboarding_steps(client):
    s = await phone_login(client, "98765 43210")  # local format is normalised to +91
    assert s["user"]["phone"] == PHONE
    assert s["user"]["role"] is None and s["user"]["company"] is None
    assert s["needs"] == ["profile", "create_or_join_company"]
    assert s["expires_in"] == 900


async def test_otp_send_returns_timers_and_blocks_quick_resend(client, monkeypatch):
    from app.services import auth as auth_service

    monkeypatch.setattr(auth_service, "OTP_RESEND_AFTER_S", 45)
    r = await client.post("/api/v1/auth/otp/send", json={"phone": PHONE})
    body = r.json()
    assert r.status_code == 202 and body["resend_after"] == 45 and body["expires_at"]
    r = await client.post("/api/v1/auth/otp/send", json={"phone": PHONE})
    assert r.status_code == 429
    assert r.json()["error"]["code"] == "rate_limited"
    assert 0 < r.json()["error"]["details"]["resend_after"] <= 45


async def test_wrong_code_three_times_locks_the_code(client):
    r = await client.post("/api/v1/auth/otp/send", json={"phone": PHONE})
    cid = r.json()["challenge_id"]
    good = last_sms(PHONE)["params"]["code"]
    bad = "0000" if good != "0000" else "1111"
    r1 = await client.post("/api/v1/auth/otp/verify", json={"challenge_id": cid, "code": bad})
    r2 = await client.post("/api/v1/auth/otp/verify", json={"challenge_id": cid, "code": bad})
    r3 = await client.post("/api/v1/auth/otp/verify", json={"challenge_id": cid, "code": bad})
    assert [r.json()["error"]["code"] for r in (r1, r2, r3)] == ["otp_invalid", "otp_invalid", "otp_too_many"]
    assert r1.json()["error"]["details"]["attempts_left"] == 2
    r4 = await client.post("/api/v1/auth/otp/verify", json={"challenge_id": cid, "code": good})
    assert r4.json()["error"]["code"] == "otp_too_many"


async def test_expired_code(client):
    r = await client.post("/api/v1/auth/otp/send", json={"phone": PHONE})
    cid = r.json()["challenge_id"]
    async with SessionLocal() as db:
        await db.execute(update(OtpChallenge).values(expires_at=now() - timedelta(seconds=1)))
        await db.commit()
    r = await client.post(
        "/api/v1/auth/otp/verify", json={"challenge_id": cid, "code": last_sms(PHONE)["params"]["code"]}
    )
    assert r.status_code == 400 and r.json()["error"]["code"] == "otp_expired"


async def test_code_cannot_be_used_twice(client):
    r = await client.post("/api/v1/auth/otp/send", json={"phone": PHONE})
    payload = {"challenge_id": r.json()["challenge_id"], "code": last_sms(PHONE)["params"]["code"]}
    assert (await client.post("/api/v1/auth/otp/verify", json=payload)).status_code == 200
    again = await client.post("/api/v1/auth/otp/verify", json=payload)
    assert again.json()["error"]["code"] == "otp_expired"


async def test_bad_phone_number(client):
    r = await client.post("/api/v1/auth/otp/send", json={"phone": "12345"})
    assert r.json()["error"]["code"] in ("invalid_phone", "validation_error")


# ---- owner sign-up and email login ------------------------------------------------------------
async def _register(client, email="asha@brightair.in", password="Cool1234"):
    return await client.post(
        "/api/v1/auth/register",
        json={"name": "Asha", "email": email, "password": password, "accept_terms": True},
    )


async def test_register_rules(client):
    weak = await _register(client, password="abcdefgh")
    assert weak.status_code == 400 and weak.json()["error"]["code"] == "password_weak"
    assert weak.json()["error"]["fields"] == {"password": "password_weak"}
    ok = await _register(client)
    assert ok.status_code == 201
    assert ok.json()["needs"] == ["create_or_join_company", "email_verification"]
    dup = await _register(client, email="ASHA@brightair.in")
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "email_taken"


async def test_register_needs_terms(client):
    r = await client.post(
        "/api/v1/auth/register", json={"name": "A", "email": "a@b.in", "password": "Cool1234"}
    )
    assert r.status_code == 422 and "accept_terms" in r.json()["error"]["fields"]


async def test_email_verification_link(client):
    s = (await _register(client)).json()
    link = last_email("asha@brightair.in")["params"]["link"]
    assert (
        await client.post("/api/v1/auth/email/verify", json={"token": token_from(link)})
    ).status_code == 204
    me = (await client.get("/api/v1/me", headers=auth(s))).json()
    assert me["email_verified"] is True


async def test_change_email_before_confirming(client):
    s = (await _register(client)).json()
    r = await client.patch("/api/v1/auth/email", json={"email": "new@brightair.in"}, headers=auth(s))
    assert r.status_code == 202
    old_link = last_email("asha@brightair.in")["params"]["link"]
    gone = await client.post("/api/v1/auth/email/verify", json={"token": token_from(old_link)})
    assert gone.status_code == 410  # link for the old address no longer works
    new_link = last_email("new@brightair.in")["params"]["link"]
    assert (
        await client.post("/api/v1/auth/email/verify", json={"token": token_from(new_link)})
    ).status_code == 204


async def test_login_wrong_password_then_lockout(client):
    await _register(client)
    for left in (4, 3, 2, 1):
        r = await client.post(
            "/api/v1/auth/login", json={"email": "asha@brightair.in", "password": "nope1234"}
        )
        assert r.status_code == 401
        assert r.json()["error"] == {
            "code": "login_invalid",
            "message": "Email or password is not right.",
            "fields": {},
            "details": {"attempts_left": left},
        }
    r = await client.post("/api/v1/auth/login", json={"email": "asha@brightair.in", "password": "nope1234"})
    assert r.json()["error"]["code"] == "account_locked" and r.json()["error"]["details"]["locked_until"]
    # even the right password waits out the lock
    r = await client.post("/api/v1/auth/login", json={"email": "asha@brightair.in", "password": "Cool1234"})
    assert r.json()["error"]["code"] == "account_locked"


async def test_unknown_email_looks_like_wrong_password(client):
    r = await client.post("/api/v1/auth/login", json={"email": "nobody@x.in", "password": "Cool1234"})
    assert r.status_code == 401 and r.json()["error"]["code"] == "login_invalid"


async def test_password_reset_signs_out_everywhere(client):
    s = (await _register(client)).json()
    assert (
        await client.post("/api/v1/auth/password/forgot", json={"email": "asha@brightair.in"})
    ).status_code == 202
    # unknown emails get the same answer and no email
    assert (await client.post("/api/v1/auth/password/forgot", json={"email": "x@y.in"})).status_code == 202
    token = token_from(last_email("asha@brightair.in")["params"]["link"])
    r = await client.post("/api/v1/auth/password/reset", json={"token": token, "password": "Newpass99"})
    assert r.status_code == 204
    assert (await client.get("/api/v1/me", headers=auth(s))).json()["error"]["code"] == "session_ended"
    again = await client.post("/api/v1/auth/password/reset", json={"token": token, "password": "Other999"})
    assert again.status_code == 410  # one use only
    ok = await client.post("/api/v1/auth/login", json={"email": "asha@brightair.in", "password": "Newpass99"})
    assert ok.status_code == 200


# ---- sessions --------------------------------------------------------------------------------
async def test_refresh_rotates_and_detects_reuse(client):
    s = await phone_login(client, PHONE)
    r1 = await client.post("/api/v1/auth/refresh", json={"refresh_token": s["refresh_token"]})
    assert r1.status_code == 200 and r1.json()["refresh_token"] != s["refresh_token"]
    # replaying the old token ends the session, so the new one stops working too
    replay = await client.post("/api/v1/auth/refresh", json={"refresh_token": s["refresh_token"]})
    assert replay.status_code == 401
    r2 = await client.post("/api/v1/auth/refresh", json={"refresh_token": r1.json()["refresh_token"]})
    assert r2.status_code == 401


async def test_logout(client):
    s = await phone_login(client, PHONE)
    assert (await client.post("/api/v1/auth/logout", headers=auth(s))).status_code == 204
    r = await client.get("/api/v1/me", headers=auth(s))
    assert r.status_code == 401 and r.json()["error"]["code"] == "session_ended"


async def test_requests_without_or_with_bad_token(client):
    assert (await client.get("/api/v1/me")).json()["error"]["code"] == "not_signed_in"
    r = await client.get("/api/v1/me", headers={"Authorization": "Bearer nonsense"})
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"


async def test_profile_and_preferences(client):
    s = await phone_login(client, PHONE)
    r = await client.patch("/api/v1/me", json={"name": "Ravi"}, headers=auth(s))
    assert r.json()["name"] == "Ravi"
    r = await client.patch(
        "/api/v1/me/preferences", json={"app_language": "gu", "theme": "dark"}, headers=auth(s)
    )
    assert (r.json()["app_language"], r.json()["theme"]) == ("gu", "dark")
    bad = await client.patch("/api/v1/me/preferences", json={"app_language": "de"}, headers=auth(s))
    assert bad.status_code == 422
    dev = {"push_token": "fcm-token-123456", "platform": "ipados", "app_version": "1.0.0"}
    assert (await client.post("/api/v1/devices", json=dev, headers=auth(s))).status_code == 204
    assert (await client.post("/api/v1/devices", json=dev, headers=auth(s))).status_code == 204  # upsert


async def test_signed_in_devices_and_sign_out_everywhere_else(client):
    """D-146: Me → Signed-in devices lists where the account is signed in; one or all others can be signed out."""
    phone = (await _register(client)).json()
    login = {"email": "asha@brightair.in", "password": "Cool1234"}
    tablet = (await client.post("/api/v1/auth/login", json=login)).json()
    laptop = (await client.post("/api/v1/auth/login", json=login)).json()
    android = {**auth(phone), "X-Platform": "android", "X-App-Version": "1.4.0"}
    r = (await client.get("/api/v1/auth/sessions", headers=android)).json()["data"]
    assert len(r) == 3 and r[0]["current"] and (r[0]["platform"], r[0]["app_version"]) == ("android", "1.4.0")
    assert not any(d["current"] for d in r[1:])

    # signing out this device is Log out's job
    me = r[0]["id"]
    assert (await client.delete(f"/api/v1/auth/sessions/{me}", headers=auth(phone))).status_code == 409
    # sign out the tablet only
    tablet_id = next(
        d["id"]
        for d in (await client.get("/api/v1/auth/sessions", headers=auth(tablet))).json()["data"]
        if d["current"]
    )
    assert (await client.delete(f"/api/v1/auth/sessions/{tablet_id}", headers=auth(phone))).status_code == 204
    assert (await client.get("/api/v1/me", headers=auth(tablet))).status_code == 401
    gone = await client.delete(f"/api/v1/auth/sessions/{tablet_id}", headers=auth(phone))
    assert gone.status_code == 404 and gone.json()["error"]["code"] == "device_not_found"

    # everywhere else: the laptop is out, this phone stays in
    out = await client.post("/api/v1/auth/sessions/sign-out-others", headers=auth(phone))
    assert out.json() == {"signed_out": 1}
    assert (await client.get("/api/v1/me", headers=auth(laptop))).status_code == 401
    assert (await client.get("/api/v1/me", headers=auth(phone))).status_code == 200
    assert len((await client.get("/api/v1/auth/sessions", headers=auth(phone))).json()["data"]) == 1
