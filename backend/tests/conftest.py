"""Tests run against a real PostgreSQL database (KN_TEST_DATABASE_URL), migrated once per run
and emptied between tests. SMS and email go to the in-memory outbox, so tests read codes from there.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

TEST_DB = os.environ.get(
    "KN_TEST_DATABASE_URL", "postgresql+asyncpg://kaamnishaan:kaamnishaan@localhost:5432/kaamnishaan_test"
)
import tempfile  # noqa: E402

os.environ.update(
    KN_STORAGE_PROVIDER="local",
    KN_STORAGE_LOCAL_DIR=tempfile.mkdtemp(prefix="kn-test-files-"),
    KN_API_URL="http://t",
    KN_ENV="test",
    KN_DATABASE_URL=TEST_DB,
    KN_SECRET_KEY="test-secret-key-for-automated-tests-only-0123456789",
    KN_SMS_PROVIDER="console",
    KN_WEB_URL="http://web.test",
    KN_EMAIL_ENABLED="true",  # the tests check what each email says; test_no_email.py turns it off
)

from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.core.config import get_settings  # noqa: E402

get_settings.cache_clear()

from app.core.db import engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.providers.messaging import outbox  # noqa: E402

KEEP = {"alembic_version", "plans", "industries", "credit_packs", "prompt_versions"}  # seeded by migrations
# Seeded global checklists live in tables that also hold company rows, so they are copied aside once
# and put back after each wipe.
_seed_copied = False
SEEDED = (
    ("checklist_templates", "company_id IS NULL"),
    ("checklist_questions", "template_id IN (SELECT id FROM checklist_templates WHERE company_id IS NULL)"),
    ("shot_slots", "template_id IN (SELECT id FROM checklist_templates WHERE company_id IS NULL)"),
)


@pytest.fixture(scope="session", autouse=True)
def _migrate() -> None:
    backend = Path(__file__).resolve().parents[1]
    env = {**os.environ}
    # rebuild from empty every run, so seeded rows (plans, checklists) are always fresh
    subprocess.run([sys.executable, "-m", "alembic", "downgrade", "base"], cwd=backend, env=env, check=True)
    subprocess.run([sys.executable, "-m", "alembic", "upgrade", "head"], cwd=backend, env=env, check=True)


@pytest.fixture(autouse=True)
async def _clean_db():
    async with engine.begin() as conn:
        names = (
            await conn.execute(text("select tablename from pg_tables where schemaname = 'public'"))
        ).scalars()
        names = list(names)
        global _seed_copied
        for table, where in SEEDED:
            if not _seed_copied:  # fresh copy on every test run, in case the seed changed
                await conn.execute(text("CREATE SCHEMA IF NOT EXISTS test_seed"))
                await conn.execute(text(f"DROP TABLE IF EXISTS test_seed.{table}"))
                await conn.execute(
                    text(f"CREATE TABLE test_seed.{table} AS SELECT * FROM {table} WHERE {where}")
                )
        _seed_copied = True
        wipe = [n for n in names if n not in KEEP]
        if wipe:
            await conn.execute(text(f"TRUNCATE {', '.join(wipe)} RESTART IDENTITY CASCADE"))
        for table, _ in SEEDED:
            await conn.execute(text(f"INSERT INTO {table} SELECT * FROM test_seed.{table}"))
    outbox.clear()
    yield


@pytest.fixture(autouse=True)
def _no_resend_wait(monkeypatch):
    """Most tests log the same phone in more than once; the resend timer has its own test."""
    from app.services import auth as auth_service

    monkeypatch.setattr(auth_service, "OTP_RESEND_AFTER_S", 0)


@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://t") as c:
        yield c


# ---- helpers -----------------------------------------------------------------------------
def auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def last_sms(to: str) -> dict:
    return next(m for m in reversed(outbox.sms) if m["to"] == to)


def last_email(to: str) -> dict:
    return next(m for m in reversed(outbox.email) if m["to"] == to)


def token_from(link: str) -> str:
    return re.search(r"token=([^&\s]+)", link).group(1)


async def phone_login(client: AsyncClient, phone: str) -> dict:
    r = await client.post("/api/v1/auth/otp/send", json={"phone": phone})
    assert r.status_code == 202, r.text
    code = outbox.sms[-1]["params"]["code"]
    r = await client.post(
        "/api/v1/auth/otp/verify", json={"challenge_id": r.json()["challenge_id"], "code": code}
    )
    assert r.status_code == 200, r.text
    return r.json()


async def make_owner(
    client: AsyncClient, email: str = "owner@brightair.in", company: str = "BrightAir"
) -> dict:
    r = await client.post(
        "/api/v1/auth/register",
        json={"name": "Asha Patel", "email": email, "password": "Cool1234", "accept_terms": True},
    )
    assert r.status_code == 201, r.text
    s = r.json()
    r = await client.post(
        "/api/v1/companies", json={"name": company, "trade": "hvac", "country": "IN"}, headers=auth(s)
    )
    assert r.status_code == 201, r.text
    # the new company is now on the session; refresh to get a token that carries it
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": s["refresh_token"]})
    assert r.status_code == 200, r.text
    return r.json()


async def invite_and_join(client: AsyncClient, inviter: dict, phone: str, role: str = "technician") -> dict:
    r = await client.post(
        "/api/v1/invites", json={"phone": phone, "name": "Ravi Kumar", "role": role}, headers=auth(inviter)
    )
    assert r.status_code == 201, r.text
    s = await phone_login(client, phone)
    invite_id = s["invites"][0]["id"]
    r = await client.post(f"/api/v1/invites/{invite_id}/accept", headers=auth(s))
    assert r.status_code == 200, r.text
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": s["refresh_token"]})
    assert r.status_code == 200, r.text
    return r.json()
