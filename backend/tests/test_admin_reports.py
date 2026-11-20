"""A14 Reports and A15 Report details: every company's reports, read-only."""

from types import SimpleNamespace

from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import AuditLog
from app.services.admin_reports import _mask
from tests.conftest import auth
from tests.test_admin_auth import _setup
from tests.test_reports import fake_ai, make_report, ready  # noqa: F401 - fixtures

A = "/api/v1/admin/reports"


async def test_list_check_detail_and_export(client, ready, fake_ai):
    s, _ = await _setup(client)
    _started, _task, rep = await make_report(client, ready["tech"], ready["job"]["id"])

    d = (await client.get(A, headers=auth(s))).json()
    assert d["total"] == 1 and d["counts"] == {"draft": 1}
    row = d["items"][0]
    assert row["number"] == rep["number"] and row["status"] == "draft" and row["language"] == "en"
    assert row["check"] == "unsupported_claim" and row["check_count"] == 1  # the fake AI invents one sentence
    assert row["job"]["customer"] == ready["customer"]["name"] and row["technician"]

    q = lambda **p: client.get(A, params=p, headers=auth(s))  # noqa: E731
    assert (await q(language="hi")).json()["total"] == 0
    assert (await q(status="approved")).json()["total"] == 0
    assert (await q(q=rep["number"])).json()["total"] == 1
    assert (await q(q=ready["job"]["number"])).json()["total"] == 1

    one = (await client.get(f"{A}/{rep['id']}", headers=auth(s))).json()
    assert (
        one["drafted_by"] == "ai"
        and one["work_done"]
        and one["sentences"] == 2
        and one["sentences_linked"] == 1
    )
    assert one["flags"] == [{"kind": "unsupported_claim", "text": "Checked the gas pressure."}]
    assert len(one["photos"]) == 2 and one["versions"][0]["event"] == "drafted" and one["pdf_url"] is None
    job = (await client.get(f"/api/v1/admin/jobs/{ready['job']['id']}", headers=auth(s))).json()
    assert job["report"]["id"] == rep["id"]

    r = await client.get(f"{A}.csv", headers=auth(s))
    assert r.status_code == 200 and r.text.startswith("Report,Job") and "unsupported_claim (1)" in r.text
    async with SessionLocal() as db:
        assert (await db.execute(select(AuditLog).where(AuditLog.target_type == "reports"))).scalars().one()
    assert (await client.get(f"{A}/00000000-0000-0000-0000-000000000000", headers=auth(s))).status_code == 404


def test_recipient_is_partly_hidden():
    link = SimpleNamespace(recipient_name="Dr. Anita Rao", phone="+919825011111", email=None)
    assert _mask(link) == "Dr. Anita Rao · •••• 1111"
    assert (
        _mask(SimpleNamespace(recipient_name=None, phone=None, email="anita@clinic.in")) == "a•••@clinic.in"
    )
