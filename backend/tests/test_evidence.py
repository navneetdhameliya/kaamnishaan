import io
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from PIL import Image
from sqlalchemy import text

from app.core.db import SessionLocal
from app.services.evidence import lock_job_evidence
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_customers_jobs import new_customer, new_job

TECH = "+919812345678"
TECH2 = "+919898989898"


def jpeg(w: int = 1200, h: int = 900, color=(120, 160, 200)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (w, h), color).save(out, "JPEG", quality=85)
    return out.getvalue()


def now_iso(minutes: int = 0) -> str:
    return (datetime.now(UTC) + timedelta(minutes=minutes)).isoformat()


async def upload(client, who, data: bytes, kind="photo", content_type="image/jpeg") -> str:
    r = await client.post(
        "/api/v1/uploads",
        json={"kind": kind, "content_type": content_type, "size": len(data)},
        headers=auth(who),
    )
    assert r.status_code == 201, r.text
    u = r.json()
    put = await client.put(u["url"], content=data, headers=u["headers"])
    assert put.status_code == 200, put.text
    return u["upload_id"]


async def add_photo(client, who, job_id, stage="before", data=None, **extra):
    up = await upload(client, who, data or jpeg())
    r = await client.post(
        f"/api/v1/jobs/{job_id}/evidence",
        json={"upload_id": up, "stage": stage, "taken_at": now_iso(), **extra},
        headers=auth(who),
    )
    return r


@pytest.fixture
async def started(client):
    """Owner, technician, and a job the technician has started."""
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    r = await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    assert r.status_code == 200
    return {"owner": owner, "tech": tech, "job": j, "customer": c}


# ---- uploads ---------------------------------------------------------------------------------
async def test_upload_rules(client):
    owner = await make_owner(client)
    bad = await client.post(
        "/api/v1/uploads", json={"kind": "photo", "content_type": "application/pdf"}, headers=auth(owner)
    )
    assert bad.status_code == 400 and bad.json()["error"]["code"] == "file_type_not_allowed"
    big = await client.post(
        "/api/v1/uploads",
        json={"kind": "photo", "content_type": "image/jpeg", "size": 13 * 1024 * 1024},
        headers=auth(owner),
    )
    assert big.json()["error"] == {
        "code": "file_too_large", "message": "This file is too big.", "fields": {"size": "too_large"},
        "details": {"max_bytes": 12 * 1024 * 1024},
    }  # fmt: skip
    ok = (
        await client.post(
            "/api/v1/uploads", json={"kind": "photo", "content_type": "image/jpeg"}, headers=auth(owner)
        )
    ).json()
    assert (
        ok["method"] == "PUT"
        and ok["headers"] == {"Content-Type": "image/jpeg"}
        and ok["max_bytes"] == 12 * 1024 * 1024
    )
    # the signed upload link refuses a different file type and a tampered token
    wrong = await client.put(ok["url"], content=b"x", headers={"Content-Type": "image/png"})
    assert wrong.status_code == 400
    tampered = await client.put(ok["url"] + "x", content=b"x", headers=ok["headers"])
    assert tampered.status_code == 410


# ---- adding photos -----------------------------------------------------------------------------
async def test_photo_flow_with_thumbnail_and_signed_links(client, started):
    tech, job = started["tech"], started["job"]
    r = await add_photo(
        client,
        tech,
        job["id"],
        "before",
        data=jpeg(3000, 2000),
        lat=21.17,
        lng=72.83,
        shot_slot="outdoor_unit",
    )
    assert r.status_code == 201, r.text
    e = r.json()
    assert (e["stage"], e["shot_slot"], e["processing"]) == ("before", "outdoor_unit", "ready")
    assert (e["width"], e["height"]) == (3000, 2000)
    assert e["taken_by"]["name"] == "Ravi Kumar" and not e["locked"] and e["can_delete"]
    full = await client.get(e["url"])
    assert full.status_code == 200 and full.headers["content-type"] == "image/jpeg"
    thumb = Image.open(io.BytesIO((await client.get(e["thumb_url"])).content))
    assert max(thumb.size) == 480  # small copy for lists
    assert (await client.get(e["url"][:-3] + "abc")).status_code == 410  # links can't be guessed or edited

    lst = (await client.get(f"/api/v1/jobs/{job['id']}/evidence", headers=auth(tech))).json()
    assert lst["meta"]["counts"] == {"before": 1, "during": 0, "after": 0, "all": 1}
    today = (await client.get("/api/v1/me/today", headers=auth(tech))).json()
    assert today["stats"]["photos"] == 1


async def test_upload_can_only_be_used_once_and_retry_is_safe(client, started):
    tech, job = started["tech"], started["job"]
    up = await upload(client, tech, jpeg())
    key = str(uuid.uuid4())
    body = {"upload_id": up, "stage": "before", "taken_at": now_iso(), "client_uuid": key}
    a = await client.post(f"/api/v1/jobs/{job['id']}/evidence", json=body, headers=auth(tech))
    b = await client.post(f"/api/v1/jobs/{job['id']}/evidence", json=body, headers=auth(tech))
    assert a.status_code == 201 and b.status_code == 200 and a.json()["id"] == b.json()["id"]
    reuse = await client.post(
        f"/api/v1/jobs/{job['id']}/evidence", json={**body, "client_uuid": None}, headers=auth(tech)
    )
    assert reuse.status_code == 409 and reuse.json()["error"]["code"] == "upload_used"


async def test_confirm_needs_the_file_and_your_own_upload(client, started):
    tech, owner, job = started["tech"], started["owner"], started["job"]
    r = await client.post(
        "/api/v1/uploads", json={"kind": "photo", "content_type": "image/jpeg"}, headers=auth(tech)
    )
    body = {"upload_id": r.json()["upload_id"], "stage": "before", "taken_at": now_iso()}
    missing = await client.post(f"/api/v1/jobs/{job['id']}/evidence", json=body, headers=auth(tech))
    assert missing.json()["error"]["code"] == "upload_missing"
    owners_upload = await upload(client, owner, jpeg())
    other = await client.post(
        f"/api/v1/jobs/{job['id']}/evidence", json={**body, "upload_id": owners_upload}, headers=auth(tech)
    )
    assert other.status_code == 404 and other.json()["error"]["code"] == "upload_not_found"


async def test_not_an_image_is_marked_failed(client, started):
    r = await add_photo(client, started["tech"], started["job"]["id"], data=b"definitely not a jpeg")
    assert r.status_code == 201 and r.json()["processing"] == "failed" and r.json()["thumb_url"] is None


async def test_photos_need_a_started_job(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    r = await add_photo(client, tech, j["id"])
    assert r.status_code == 409 and r.json()["error"]["code"] == "job_not_started"
    proof = (await client.get(f"/api/v1/jobs/{j['id']}/proof", headers=auth(tech))).json()
    assert proof["blocked_by"] == "job_not_started" and not proof["can_make_report"]


async def test_photo_time_cannot_be_in_the_future(client, started):
    up = await upload(client, started["tech"], jpeg())
    r = await client.post(
        f"/api/v1/jobs/{started['job']['id']}/evidence",
        json={"upload_id": up, "stage": "after", "taken_at": now_iso(60)}, headers=auth(started["tech"]),
    )  # fmt: skip
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"taken_at": "future"}


async def test_other_technicians_cannot_see_or_add(client, started):
    other = await invite_and_join(client, started["owner"], TECH2)
    job = started["job"]
    r = await add_photo(client, other, job["id"])
    assert r.status_code == 404
    e = (await add_photo(client, started["tech"], job["id"])).json()
    assert (await client.get(f"/api/v1/evidence/{e['id']}", headers=auth(other))).status_code == 404
    assert (await client.get(f"/api/v1/jobs/{job['id']}/evidence", headers=auth(other))).status_code == 404
    # owners and managers can see and capture on any job
    assert (await add_photo(client, started["owner"], job["id"], "during")).status_code == 201


# ---- capture hub, pairs, delete, notes, lock ------------------------------------------------------
async def test_capture_hub_counts_and_unlock_rule(client, started):
    tech, job = started["tech"], started["job"]
    p0 = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert p0["blocked_by"] == "need_before_photo" and [s["key"] for s in p0["steps"]] == [
        "before", "during", "after", "checklist", "voice",
    ]  # fmt: skip
    await add_photo(client, tech, job["id"], "before")
    p1 = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert (
        p1["blocked_by"] == "need_after_photo"
        and p1["steps"][0]["count"] == 1
        and len(p1["steps"][0]["thumbs"]) == 1
    )
    await add_photo(client, tech, job["id"], "after")
    p2 = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert p2["can_make_report"] and p2["blocked_by"] is None


async def test_before_after_pairs(client, started):
    tech, job = started["tech"], started["job"]
    b = (await add_photo(client, tech, job["id"], "before")).json()
    a = (await add_photo(client, tech, job["id"], "after")).json()
    wrong = await client.post(
        f"/api/v1/jobs/{job['id']}/photo-pairs",
        json={"before_id": a["id"], "after_id": b["id"]},
        headers=auth(tech),
    )
    assert wrong.status_code == 400 and wrong.json()["error"]["fields"] == {"before_id": "not_before"}
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/photo-pairs",
        json={"before_id": b["id"], "after_id": a["id"], "subject": "Indoor coil"},
        headers=auth(tech),
    )
    assert r.status_code == 201 and r.json()["subject"] == "Indoor coil" and r.json()["use_in_report"]
    lst = (await client.get(f"/api/v1/jobs/{job['id']}/evidence", headers=auth(tech))).json()
    assert len(lst["pairs"]) == 1 and lst["pairs"][0]["before"]["id"] == b["id"]
    # removing a photo removes its pair too
    assert (await client.delete(f"/api/v1/evidence/{b['id']}", headers=auth(tech))).status_code == 204
    lst = (await client.get(f"/api/v1/jobs/{job['id']}/evidence", headers=auth(tech))).json()
    assert lst["pairs"] == [] and lst["meta"]["counts"]["before"] == 0


async def test_who_can_delete(client, started):
    tech, owner, job = started["tech"], started["owner"], started["job"]
    mine = (await add_photo(client, owner, job["id"], "during")).json()
    r = await client.delete(f"/api/v1/evidence/{mine['id']}", headers=auth(tech))
    assert r.status_code == 403  # a technician removes only their own photos
    theirs = (await add_photo(client, tech, job["id"], "during")).json()
    assert (await client.delete(f"/api/v1/evidence/{theirs['id']}", headers=auth(owner))).status_code == 204


async def test_lock_blocks_changes_but_allows_notes(client, started):
    tech, job = started["tech"], started["job"]
    e = (await add_photo(client, tech, job["id"], "before")).json()
    async with SessionLocal() as db:  # what "submit report" will do in Step 1e
        assert await lock_job_evidence(db, uuid.UUID(job["id"])) == 1
        await db.commit()
    d = (await client.get(f"/api/v1/evidence/{e['id']}", headers=auth(tech))).json()
    assert d["locked"] and not d["can_delete"]
    r = await client.delete(f"/api/v1/evidence/{e['id']}", headers=auth(tech))
    assert r.status_code == 409 and r.json()["error"]["code"] == "evidence_locked"
    n = await client.post(
        f"/api/v1/evidence/{e['id']}/notes", json={"text": "Gas pressure was low"}, headers=auth(tech)
    )
    assert n.status_code == 201 and n.json()["author"]["name"] == "Ravi Kumar"
    d = (await client.get(f"/api/v1/evidence/{e['id']}", headers=auth(tech))).json()
    assert [x["text"] for x in d["notes"]] == ["Gas pressure was low"] and d["notes_count"] == 1
    proof = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert proof["locked"] and proof["blocked_by"] == "evidence_locked"


async def test_database_refuses_to_change_locked_evidence(client, started):
    """Even a bug or a manual SQL edit can't alter a locked photo."""
    e = (await add_photo(client, started["tech"], started["job"]["id"], "before")).json()
    async with SessionLocal() as db:
        await lock_job_evidence(db, uuid.UUID(started["job"]["id"]))
        await db.commit()
    for sql in (
        "UPDATE evidence SET stage = 'after' WHERE id = :id",
        "UPDATE evidence SET taken_at = now() - interval '1 day' WHERE id = :id",
        "UPDATE evidence SET locked_at = NULL WHERE id = :id",
        "DELETE FROM evidence WHERE id = :id",
    ):
        async with SessionLocal() as db:
            with pytest.raises(Exception, match="evidence_locked"):
                await db.execute(text(sql), {"id": e["id"]})
                await db.commit()
    async with SessionLocal() as db:  # processing results may still be written
        await db.execute(text("UPDATE evidence SET processing = 'ready' WHERE id = :id"), {"id": e["id"]})
        await db.commit()


async def test_companies_never_see_each_others_photos(client, started):
    other_owner = await make_owner(client, "b@coolfix.in", "CoolFix")
    job = started["job"]
    e = (await add_photo(client, started["tech"], job["id"], "before")).json()
    assert (await client.get(f"/api/v1/evidence/{e['id']}", headers=auth(other_owner))).status_code == 404
    assert (
        await client.get(f"/api/v1/jobs/{job['id']}/evidence", headers=auth(other_owner))
    ).status_code == 404
    assert (await client.delete(f"/api/v1/evidence/{e['id']}", headers=auth(other_owner))).status_code == 404
    r = await client.post(f"/api/v1/evidence/{e['id']}/notes", json={"text": "x"}, headers=auth(other_owner))
    assert r.status_code == 404
    up = await upload(client, other_owner, jpeg())
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/evidence",
        json={"upload_id": up, "stage": "before", "taken_at": now_iso()},
        headers=auth(other_owner),
    )
    assert r.status_code == 404
