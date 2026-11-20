"""A13 Evidence review: every company's photos with the server's own checks, and staff flags."""

from datetime import timedelta

from sqlalchemy import select, update

from app.core.db import SessionLocal
from app.models import AuditLog, Evidence, Job, Site
from tests.conftest import auth
from tests.test_admin_auth import _setup
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture

A = "/api/v1/admin/evidence"


async def _shape(ready) -> tuple[str, str]:
    """Before photo: right place, GPS on. After photo: same file as before, no GPS, taken before the job."""
    async with SessionLocal() as db:
        j = await db.get(Job, ready["job"]["id"])
        rows = (await db.execute(select(Evidence).where(Evidence.job_id == j.id))).scalars().all()
        before = next(e for e in rows if e.stage == "before")
        after = next(e for e in rows if e.stage == "after")
        await db.execute(update(Site).where(Site.id == j.site_id).values(lat=23.0225, lng=72.5714))
        before.lat, before.lng, before.sha256 = 23.0226, 72.5714, "a" * 64
        after.lat, after.lng, after.sha256 = None, None, "a" * 64
        after.taken_at = j.created_at - timedelta(days=3)
        await db.commit()
        return str(before.id), str(after.id)


async def test_checks_filters_and_detail(client, ready):
    s, _ = await _setup(client)
    before, after = await _shape(ready)

    d = (await client.get(A, headers=auth(s))).json()
    assert d["total"] == 2 and d["needs_look"] == 2 and d["can_act"] is True
    by = {p["id"]: p for p in d["items"]}
    assert by[before]["checks"] == ["duplicate"] and by[before]["gps"] is True
    assert by[after]["checks"] == ["duplicate", "no_gps", "early"]
    assert by[after]["job"]["customer"] == ready["customer"]["name"]

    q = lambda **p: client.get(A, params=p, headers=auth(s))  # noqa: E731
    assert [p["id"] for p in (await q(flag="no_gps")).json()["items"]] == [after]
    assert (await q(flag="clean")).json()["total"] == 0
    assert (await q(stage="before")).json()["items"][0]["id"] == before
    assert (await q(job=ready["job"]["id"])).json()["total"] == 2

    # move the before photo 2 km away
    async with SessionLocal() as db:
        await db.execute(update(Evidence).where(Evidence.id == before).values(lat=23.0405))
        await db.commit()
    assert [p["id"] for p in (await q(flag="far")).json()["items"]] == [before]

    one = (await client.get(f"{A}/{before}", headers=auth(s))).json()
    assert 1900 <= one["distance_m"] <= 2100 and one["image_url"] and one["fingerprint"] == "a" * 64
    assert [t["id"] for t in one["twins"]] == [after] and one["taken_by"]


async def test_staff_flag(client, ready):
    s, _ = await _setup(client)
    before, _after = await _shape(ready)
    r = await client.put(f"{A}/{before}/flag", json={"note": "Looks like a stock photo"}, headers=auth(s))
    assert r.status_code == 200 and r.json()["staff_flag"]["note"] == "Looks like a stock photo"
    assert r.json()["staff_flag"]["by"]
    d = (await client.get(A, params={"flag": "staff"}, headers=auth(s))).json()
    assert [p["id"] for p in d["items"]] == [before]
    assert (await client.put(f"{A}/{before}/flag", json={"note": "x"}, headers=auth(s))).status_code == 422
    r = await client.delete(f"{A}/{before}/flag", headers=auth(s))
    assert r.json()["staff_flag"] is None
    async with SessionLocal() as db:
        acts = (
            (await db.execute(select(AuditLog.action).where(AuditLog.target_type == "evidence")))
            .scalars()
            .all()
        )
        assert sorted(acts) == ["evidence.flagged", "evidence.unflagged"]
    # the company never sees staff flags
    tech = ready["tech"]
    proof = (await client.get(f"/api/v1/jobs/{ready['job']['id']}/evidence", headers=auth(tech))).text
    assert "staff_flag" not in proof
