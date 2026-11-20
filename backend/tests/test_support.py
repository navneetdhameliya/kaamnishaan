"""M47 Help (app) and A28 Support tickets / A29 Notifications (admin panel)."""

from datetime import timedelta

from sqlalchemy import select, update

from app.core.db import SessionLocal
from app.core.security import now
from app.models import AuditLog, Company, Notification, StaffUser
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_admin_auth import _setup

S = "/api/v1/support/tickets"
A = "/api/v1/admin"
TECH = "+919812345678"


async def _ticket(client, who, **extra):
    body = {
        "category": "problem",
        "subject": "Report stuck",
        "body": "It has been loading for 10 minutes.",
        **extra,
    }
    r = await client.post(S, json=body, headers=auth(who))
    assert r.status_code == 201, r.text
    return r.json()


async def test_help_request_both_sides(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    t = await _ticket(client, tech)
    assert t["number"].startswith("T-") and t["status"] == "open" and len(t["messages"]) == 1
    assert t["messages"][0]["from_support"] is False and t["messages"][0]["author"]
    assert (await client.get(S, headers=auth(owner))).json()["data"] == []  # only your own
    assert (await client.get(f"{S}/{t['id']}", headers=auth(owner))).status_code == 404

    s, _ = await _setup(client)
    d = (await client.get(f"{A}/support", headers=auth(s))).json()
    assert d["counts"] == {"open": 1, "waiting": 0, "solved": 0, "high": 0} and d["items"][0]["person"]
    one = (await client.get(f"{A}/support/{t['id']}", headers=auth(s))).json()
    assert one["company"] == "BrightAir" and one["person_role"] == "technician" and one["plan"]

    # a staff note stays with staff; a reply goes to the person and their Messages
    await client.post(f"{A}/support/{t['id']}/messages", json={"body": "Checked the AI log.", "internal": True},
                      headers=auth(s))  # fmt: skip
    r = await client.post(f"{A}/support/{t['id']}/messages", json={"body": "Re-ran it. Please refresh."},
                          headers=auth(s))  # fmt: skip
    assert r.json()["status"] == "waiting" and [m["internal"] for m in r.json()["messages"]] == [
        False,
        True,
        False,
    ]
    mine = (await client.get(f"{S}/{t['id']}", headers=auth(tech))).json()
    assert [m["from_support"] for m in mine["messages"]] == [False, True]  # the note isn't shown
    assert (
        mine["messages"][1]["author"] is None and mine["status"] == "waiting" and mine["last_from"] == "staff"
    )
    msgs = (await client.get("/api/v1/notifications", headers=auth(tech))).json()["data"]
    assert msgs[0]["kind"] == "support_reply" and msgs[0]["params"]["ticket_id"] == t["id"]

    # writing again opens it; the person can mark it solved
    r = await client.post(f"{S}/{t['id']}/messages", json={"body": "Works now, thanks!"}, headers=auth(tech))
    assert r.json()["status"] == "open"
    assert (await client.post(f"{S}/{t['id']}/solve", headers=auth(tech))).json()["status"] == "solved"
    r = await client.patch(
        f"{A}/support/{t['id']}", json={"priority": "high", "status": "open"}, headers=auth(s)
    )
    assert r.json()["priority"] == "high" and r.json()["status"] == "open"
    assert (await client.get(f"{A}/support", params={"q": t["number"]}, headers=auth(s))).json()["total"] == 1
    csv = (await client.get(f"{A}/support.csv", headers=auth(s))).text
    assert csv.startswith("Ticket,Subject") and "Report stuck" in csv
    async with SessionLocal() as db:
        acts = set(
            (await db.execute(select(AuditLog.action).where(AuditLog.staff_id.is_not(None)))).scalars()
        )
        assert {"support.note", "support.replied", "support.updated", "staff.export"} <= acts


async def test_paused_company_can_still_ask_and_limits(client):
    owner = await make_owner(client)
    async with SessionLocal() as db:
        await db.execute(update(Company).values(status="suspended"))
        await db.commit()
    assert (await client.get("/api/v1/jobs", headers=auth(owner))).status_code == 403
    t = await _ticket(client, owner, category="billing")
    assert t["category"] == "billing"
    bad = await client.post(
        S, json={"category": "problem", "subject": "x", "body": "short"}, headers=auth(owner)
    )
    assert bad.status_code == 422
    other = "00000000-0000-0000-0000-000000000000"
    r = await client.post(S, json={"category": "problem", "subject": "Job issue", "body": "Something is wrong here.",
                                   "job_id": other}, headers=auth(owner))  # fmt: skip
    assert r.status_code == 400


async def test_rules_and_announcements(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    s, _ = await _setup(client)
    d = (await client.get(f"{A}/notifications", headers=auth(s))).json()
    rules = {r["kind"]: r for r in d["rules"]}
    assert rules["job_assigned"]["on"] and rules["weekly_summary"] == {
        "kind": "weekly_summary", "on": False, "to": "owner", "channel": "email", "available": False
    }  # fmt: skip
    assert d["audience_sizes"] == {"everyone": 2, "owners_managers": 1, "owners": 1}

    # switched off for everyone: the message isn't made
    await client.put(f"{A}/notifications/rules", json={"on": {"job_assigned": False}}, headers=auth(s))
    from tests.test_customers_jobs import new_customer, new_job

    c = await new_customer(client, owner)
    await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    async with SessionLocal() as db:
        assert not (await db.execute(select(Notification).where(Notification.kind == "job_assigned"))).first()
    assert (
        await client.put(f"{A}/notifications/rules", json={"on": {"made_up": True}}, headers=auth(s))
    ).status_code == 400

    # an announcement now goes to owners and managers, in every language given
    body = {"audience": "owners_managers", "title": {"en": "New: AI assistant", "hi": "नया: AI असिस्टेंट"},
            "body": {"en": "Ask about your jobs from the app."}}  # fmt: skip
    out = (await client.post(f"{A}/announcements", json=body, headers=auth(s))).json()
    a = out["announcements"][0]
    assert a["recipients"] == 1 and a["sent_at"] and a["by"]
    msgs = (await client.get("/api/v1/notifications", headers=auth(owner))).json()["data"]
    assert msgs[0]["kind"] == "announcement" and msgs[0]["params"]["title_hi"] == "नया: AI असिस्टेंट"
    assert (await client.get("/api/v1/notifications", headers=auth(tech))).json()["data"] == []

    # a scheduled one waits for the scheduler; one can be cancelled
    later = (now() + timedelta(hours=2)).isoformat()
    out = (await client.post(f"{A}/announcements", json={**body, "audience": "everyone", "send_at": later},
                             headers=auth(s))).json()  # fmt: skip
    sched = out["announcements"][0]
    assert sched["sent_at"] is None and sched["recipients"] == 0
    out = (await client.post(f"{A}/announcements", json={**body, "send_at": later}, headers=auth(s))).json()
    gone = out["announcements"][0]["id"]
    await client.delete(f"{A}/announcements/{gone}", headers=auth(s))
    from app.services import admin_support

    async with SessionLocal() as db:
        assert await admin_support.send_due(db, now() + timedelta(hours=3)) == 1
        await db.commit()
    assert len((await client.get("/api/v1/notifications", headers=auth(tech))).json()["data"]) == 1
    assert (
        await client.post(f"{A}/announcements", json={**body, "title": {"hi": "x"}}, headers=auth(s))
    ).status_code == 422
    assert (
        await client.post(f"{A}/announcements", json={**body, "audience": "company"}, headers=auth(s))
    ).status_code == 400

    async with SessionLocal() as db:
        await db.execute(update(StaffUser).values(role="support"))
        await db.commit()
    assert (await client.get(f"{A}/notifications", headers=auth(s))).json()["can_act"] is False
    assert (await client.post(f"{A}/announcements", json=body, headers=auth(s))).status_code == 403
