"""A33 Email settings: connect an SMTP service, choose which emails go out, test it."""

import smtplib

import pytest
from sqlalchemy import text

from app.core.db import engine
from app.providers import messaging
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin/email-settings"
GROUPS = {"account": True, "reports": True, "reminders": True, "team": True}
BODY = {
    "enabled": True, "from_name": "KaamNishaan", "from_email": "no-reply@kaamnishaan.com",
    "host": "smtp.example.com", "port": 587, "security": "starttls", "username": "apikey",
    "password": "s3cret-key", "groups": GROUPS,
}  # fmt: skip


@pytest.fixture
def sent(monkeypatch):
    """Catches emails at the SMTP step (no real server here)."""
    box: list = []

    async def fake(smtp, to, subject, body):
        box.append({"smtp": smtp, "to": to, "subject": subject, "body": body})
        return "<id@kaamnishaan.com>"

    monkeypatch.setattr(messaging, "send_smtp", fake)
    return box


async def test_save_password_stays_secret_and_emails_go_by_smtp(client, sent):
    await make_owner(client)
    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    assert d["live"] is False and d["settings"]["enabled"] is False and d["settings"]["password_set"] is False
    r = await client.put(A, json={**BODY, "host": None, "from_email": None}, headers=auth(s))
    assert r.status_code == 422 and r.json()["error"]["fields"] == {
        "host": "required",
        "from_email": "required",
    }

    r = await client.put(A, json=BODY, headers=auth(s))
    assert r.status_code == 200, r.text
    assert (
        r.json()["live"] and r.json()["settings"]["password_set"] and "password" not in r.json()["settings"]
    )
    async with engine.begin() as c:
        raw = (
            await c.execute(text("SELECT value::text FROM platform_settings WHERE key = 'email'"))
        ).scalar_one()
        audit = (
            await c.execute(text("SELECT data FROM audit_logs WHERE action = 'staff.email_settings_updated'"))
        ).scalar_one()
    assert "s3cret-key" not in raw and audit["password"] == "changed" and "s3cret-key" not in str(audit)
    # saving again without a password keeps the saved one
    r = await client.put(A, json={**BODY, "password": None, "port": 465, "security": "ssl"}, headers=auth(s))
    assert r.json()["settings"]["password_set"] and r.json()["settings"]["port"] == 465

    assert (await client.get("/api/v1/config")).json()["features"]["email"] is True
    await client.post("/api/v1/auth/password/forgot", json={"email": "owner@brightair.in"})
    mail = sent[-1]
    assert mail["to"] == "owner@brightair.in" and mail["subject"] == "Reset your password"
    assert "/reset-password?token=" in mail["body"] and mail["smtp"].password == "s3cret-key"
    assert mail["smtp"].security == "ssl" and mail["smtp"].from_email == "no-reply@kaamnishaan.com"

    # switch account emails off: no reset email
    await client.put(
        A, json={**BODY, "password": None, "groups": {**GROUPS, "account": False}}, headers=auth(s)
    )
    n = len(sent)
    await client.post("/api/v1/auth/password/forgot", json={"email": "owner@brightair.in"})
    assert len(sent) == n


async def test_test_email_and_who_may_change(client, sent, monkeypatch):
    s, _ = await _setup(client)
    r = await client.post(f"{A}/test", json={"to": "me@kaamnishaan.com"}, headers=auth(s))
    assert r.status_code == 409 and r.json()["error"]["code"] == "email_not_set"
    await client.put(A, json=BODY, headers=auth(s))
    r = await client.post(f"{A}/test", json={"to": "me@kaamnishaan.com"}, headers=auth(s))
    assert r.status_code == 200 and sent[-1]["subject"] == "KaamNishaan test email"

    async def broken(*_):
        raise smtplib.SMTPAuthenticationError(535, b"Bad username or password")

    monkeypatch.setattr(messaging, "send_smtp", broken)
    r = await client.post(f"{A}/test", json={"to": "me@kaamnishaan.com"}, headers=auth(s))
    assert r.status_code == 502 and r.json()["error"]["code"] == "smtp_failed"
    assert "SMTPAuthenticationError" in r.json()["error"]["message"]

    async with engine.begin() as c:
        await c.execute(text("UPDATE staff_users SET role = 'admin'"))
    assert (await client.get(A, headers=auth(s))).json()["can_act"] is False
    assert (await client.put(A, json=BODY, headers=auth(s))).status_code == 403
    assert (await client.post(f"{A}/test", json={"to": "me@x.com"}, headers=auth(s))).status_code == 403


def test_the_smtp_message(monkeypatch):
    calls = []

    class FakeSMTP:
        def __init__(self, host, port, timeout):
            calls.append(("connect", host, port))

        def __enter__(self):
            return self

        def __exit__(self, *_):
            return False

        def starttls(self, context):
            calls.append(("starttls",))

        def login(self, user, pw):
            calls.append(("login", user, pw))

        def send_message(self, msg):
            calls.append(("send", msg["From"], msg["To"], msg["Subject"], msg.get_content().strip()))

    monkeypatch.setattr(smtplib, "SMTP", FakeSMTP)
    smtp = messaging.Smtp(host="smtp.example.com", port=587, security="starttls", username="apikey",
                          password="pw", from_name="KaamNishaan", from_email="no-reply@kaamnishaan.com")  # fmt: skip
    messaging._deliver_smtp(smtp, "a@b.com", "Hello", "Body text")
    assert calls == [
        ("connect", "smtp.example.com", 587), ("starttls",), ("login", "apikey", "pw"),
        ("send", "KaamNishaan <no-reply@kaamnishaan.com>", "a@b.com", "Hello", "Body text"),
    ]  # fmt: skip
