"""A11 Jobs and A12 Job details: every company's jobs, read-only."""

from datetime import timedelta

from sqlalchemy import select, update

from app.core.db import SessionLocal
from app.core.security import now
from app.models import AuditLog, Job, Site
from tests.conftest import auth
from tests.test_admin_auth import _setup
from tests.test_customers_jobs import new_job
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture

A = "/api/v1/admin/jobs"


async def test_list_filters_proof_and_export(client, ready):
    s, _ = await _setup(client)
    owner, c = ready["owner"], ready["customer"]
    other = await new_job(client, owner, c, title="Gas refill")  # unassigned, nothing done

    d = (await client.get(A, headers=auth(s))).json()
    assert d["total"] == 2 and d["counts"] == {"in_progress": 1, "unassigned": 1}
    row = next(r for r in d["items"] if r["id"] == ready["job"]["id"])
    assert row["status"] == "in_progress" and row["technician"] and row["customer"] == c["name"]
    assert row["proof"] == {"done": 2, "total": 4}  # before + after; no during, no voice note
    assert row["number"].startswith("J-") and d["companies"][0]["value"] == row["company"]["value"]

    assert (await client.get(A, params={"status": "unassigned"}, headers=auth(s))).json()["items"][0][
        "id"
    ] == (other["id"])
    assert (await client.get(A, params={"q": "gas"}, headers=auth(s))).json()["total"] == 1
    assert (await client.get(A, params={"q": other["number"]}, headers=auth(s))).json()["total"] == 1
    later = (now() + timedelta(days=2)).isoformat()
    assert (await client.get(A, params={"from": later}, headers=auth(s))).json()["total"] == 0

    r = await client.get(f"{A}.csv", params={"status": "in_progress"}, headers=auth(s))
    lines = r.text.strip().splitlines()
    assert r.status_code == 200 and len(lines) == 2 and lines[0].startswith("Job,Title") and "2/4" in lines[1]
    async with SessionLocal() as db:
        log = (await db.execute(select(AuditLog).where(AuditLog.action == "staff.export"))).scalars().one()
        assert log.data == {"status": "in_progress"}


async def test_details_place_proof_and_timeline(client, ready):
    s, _ = await _setup(client)
    jid = ready["job"]["id"]
    async with SessionLocal() as db:
        j = await db.get(Job, jid)
        await db.execute(update(Site).where(Site.id == j.site_id).values(lat=23.0225, lng=72.5714))
        j.start_lat, j.start_lng = 23.0234, 72.5714  # ~100 m away
        await db.commit()
    d = (await client.get(f"{A}/{jid}", headers=auth(s))).json()
    assert d["status"] == "in_progress" and d["customer"] == ready["customer"]["name"]
    assert d["photos"] == {"before": 1, "during": 0, "after": 1, "voice_notes": 0}
    assert d["proof"] == {"done": 2, "total": 4} and d["report"] is None
    assert 90 <= d["place"]["start_distance_m"] <= 110 and d["place"]["address"]
    types = [e["type"] for e in d["timeline"]]
    assert types[0] == "created" and "assigned" in types and "started" in types and types.count("photos") == 2
    assigned = next(e for e in d["timeline"] if e["type"] == "assigned")
    assert assigned["data"]["technician"] and assigned["actor"]
    assert (await client.get(f"{A}/00000000-0000-0000-0000-000000000000", headers=auth(s))).status_code == 404
    assert (await client.get(A)).status_code == 401
