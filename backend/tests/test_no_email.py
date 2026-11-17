"""While no email service is chosen (D-96): owners' emails count as confirmed, and reports and review
requests go by SMS / WhatsApp / link only."""

import pytest

from app.core.config import get_settings
from app.providers.messaging import outbox
from tests.conftest import auth
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture
from tests.test_sharing import approved


@pytest.fixture
def no_email(monkeypatch):
    monkeypatch.setenv("KN_EMAIL_ENABLED", "false")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


async def test_sign_up_needs_no_email_link(client, no_email):
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "name": "Suresh Rao",
            "email": "suresh@brightair.in",
            "password": "Strong-pass-123",
            "accept_terms": True,
        },
    )
    assert r.status_code in (200, 201), r.text
    assert r.json()["user"]["email_verified"] is True
    assert not any(e.get("template") == "verify_email" for e in outbox.email)
    cfg = (await client.get("/api/v1/config")).json()
    assert cfg["features"]["email"] is False


async def test_reports_and_reviews_skip_email(client, ready, no_email):
    owner = ready["owner"]
    rep = await approved(client, ready)
    info = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(owner))).json()
    email = next(c for c in info["channels"] if c["key"] == "email")
    assert email["available"] is False and email["reason"] == "email_off"
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send", json={"channels": ["email"]}, headers=auth(owner)
    )
    assert r.status_code == 400 and r.json()["error"]["code"] == "email_off"
    outbox.clear()
    r = await client.post(f"/api/v1/jobs/{ready['job']['id']}/review-request", headers=auth(owner))
    assert r.status_code == 201 and r.json()["channels"] == ["sms"]
    assert len(outbox.sms) == 1 and len(outbox.email) == 0
