"""A37 Reviews and ratings: review rules hold reviews, staff publish, hide or put them back; list, filters,
CSV and the rules themselves."""

import uuid

from sqlalchemy import select, text

from app.core.db import SessionLocal, engine
from app.models import CustomerContact, Review
from app.services import moderation, reviews
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture
from tests.test_review_office import asked, kinds, rate

A = "/api/v1/admin"


def test_hiding_contact_details_and_spotting_abuse():
    for text_ in (
        "Call 98250 11111 now",
        "ring +91-98250-11111",
        "mail me at ravi.k@gmail.com",
        "(022) 2345 6789",
    ):
        hidden, found = moderation.hide_contact(text_)
        assert found and "•••" in hidden and "@" not in hidden, text_
    for fine in ("Came 2 hours late", "Job J-2231 on 12.11.2026", "on 12-11-2026", "Rs 1500 paid"):
        assert moderation.hide_contact(fine) == (fine, False), fine
    assert moderation.is_abusive("The technician was an IDIOT.")
    assert moderation.is_abusive("बिल्कुल बेवकूफ आदमी")
    assert moderation.is_abusive("un técnico estúpido")
    assert moderation.is_abusive("quel connard")
    assert not moderation.is_abusive("He cheated on the bill")  # a complaint, not an insult
    assert not moderation.is_abusive("बहुत अच्छा काम")


async def test_held_review_waits_for_staff_then_reaches_the_company(client, ready):
    owner, tech = ready["owner"], ready["tech"]
    await rate(client, await asked(client, ready), rating=1, comment="Rude. Call me on 98250 11111.")
    # the company doesn't see it yet and nobody was told
    page = (await client.get("/api/v1/reviews", headers=auth(owner))).json()
    assert page["count"] == 0 and page["data"] == []
    assert "low_rating" not in await kinds(client, owner) and "review_received" not in await kinds(
        client, tech
    )
    card = (await client.get(f"/api/v1/jobs/{ready['job']['id']}", headers=auth(tech))).json()["review"]
    assert card["status"] == "rated" and card["review"] is None

    s, _ = await _setup(client)
    lst = (await client.get(f"{A}/reviews", headers=auth(s))).json()
    assert lst["kpis"]["flagged"] == 1 and lst["kpis"]["reviews_30d"] == 1 and lst["kpis"]["low_30d"] == 1
    row = lst["items"][0]
    assert row["status"] == "flagged" and row["flag_reason"] == "personal_data"
    assert row["comment"] == "Rude. Call me on •••." and row["company"]["label"] == "BrightAir"
    d = (await client.get(f"{A}/reviews/{row['id']}", headers=auth(s))).json()
    assert (
        d["comment_original"] == "Rude. Call me on 98250 11111."
        and d["can_act"]
        and d["job_number"] == "J-1001"
    )

    r = await client.post(f"{A}/reviews/{row['id']}/publish", headers=auth(s))
    assert r.status_code == 200 and r.json()["status"] == "published" and r.json()["moderated_by"]
    page = (await client.get("/api/v1/reviews", headers=auth(owner))).json()
    assert page["count"] == 1 and page["data"][0]["comment"] == "Rude. Call me on •••."
    assert "low_rating" in await kinds(client, owner)  # told now, like any new review
    again = await client.post(f"{A}/reviews/{row['id']}/publish", headers=auth(s))
    assert again.status_code == 409 and again.json()["error"]["code"] == "not_flagged"

    # a second review from the same phone within a day would be held as spam
    async with SessionLocal() as db:
        contact = (
            await db.execute(select(CustomerContact).where(CustomerContact.phone == "+919825011111"))
        ).scalar_one()
        review = (await db.execute(select(Review))).scalar_one()
        _, _, reason = await reviews._checked(db, "Great job", review.company_id, contact)
        assert reason == "spam"
    async with engine.begin() as c:
        actions = (
            (await c.execute(text("SELECT action FROM audit_logs WHERE action LIKE 'staff.review%'")))
            .scalars()
            .all()
        )
    assert actions == ["staff.review_published"]


async def test_abuse_is_held_then_hidden_and_put_back(client, ready):
    owner = ready["owner"]
    await rate(client, await asked(client, ready), rating=1, comment="What an idiot")
    s, _ = await _setup(client)
    row = (await client.get(f"{A}/reviews?status=flagged", headers=auth(s))).json()["items"][0]
    assert row["flag_reason"] == "abuse" and row["comment"] == "What an idiot"
    short = await client.post(f"{A}/reviews/{row['id']}/hide", json={"reason": "x"}, headers=auth(s))
    assert short.status_code == 422
    r = await client.post(
        f"{A}/reviews/{row['id']}/hide", json={"reason": "Insults the technician"}, headers=auth(s)
    )
    assert (
        r.status_code == 200
        and r.json()["status"] == "hidden"
        and r.json()["moderation_note"] == "Insults the technician"
    )
    lst = (await client.get(f"{A}/reviews", headers=auth(s))).json()
    assert lst["kpis"]["flagged"] == 0 and lst["kpis"]["reviews_30d"] == 0  # hidden ones don't count
    assert (await client.get("/api/v1/reviews", headers=auth(owner))).json()["count"] == 0
    assert (await client.get(f"/api/v1/reviews/{row['id']}", headers=auth(owner))).status_code == 404
    r = await client.post(f"{A}/reviews/{row['id']}/restore", headers=auth(s))
    assert r.status_code == 200 and r.json()["status"] == "published"
    assert (await client.get("/api/v1/reviews", headers=auth(owner))).json()["count"] == 1


async def test_rules_can_be_turned_off_and_support_only_looks(client, ready):
    s, _ = await _setup(client)
    assert (await client.get(f"{A}/review-rules", headers=auth(s))).json() == {
        "hide_contact": True, "flag_abuse": True, "block_repeats": True,
    }  # fmt: skip
    off = {"hide_contact": False, "flag_abuse": False, "block_repeats": True}
    r = await client.put(f"{A}/review-rules", json=off, headers=auth(s))
    assert r.status_code == 200 and r.json() == off
    await rate(client, await asked(client, ready), rating=5, comment="Idiot-proof work! Call 98250 11111")
    lst = (await client.get(f"{A}/reviews", headers=auth(s))).json()
    row = lst["items"][0]
    assert row["status"] == "published" and row["comment"] == "Idiot-proof work! Call 98250 11111"
    async with engine.begin() as c:
        data = (
            await c.execute(text("SELECT data FROM audit_logs WHERE action = 'staff.review_rules_updated'"))
        ).scalar_one()
    assert data == {"hide_contact": False, "flag_abuse": False}

    # filters and export
    assert (await client.get(f"{A}/reviews?rating=low", headers=auth(s))).json()["total"] == 0
    assert (await client.get(f"{A}/reviews?rating=5&q=bright", headers=auth(s))).json()["total"] == 1
    other = str(uuid.uuid4())
    assert (await client.get(f"{A}/reviews?company={other}", headers=auth(s))).json()["total"] == 0
    assert lst["companies"][0]["label"] == "BrightAir"
    csv = await client.get(f"{A}/reviews.csv?rating=5", headers=auth(s))
    assert csv.status_code == 200 and csv.text.startswith("Date,Company") and "BrightAir" in csv.text

    # support staff can look but not act
    async with engine.begin() as c:
        await c.execute(text("UPDATE staff_users SET role = 'support'"))
    d = (await client.get(f"{A}/reviews/{row['id']}", headers=auth(s))).json()
    assert d["can_act"] is False
    assert (
        await client.post(f"{A}/reviews/{row['id']}/hide", json={"reason": "spam"}, headers=auth(s))
    ).status_code == 403
    assert (await client.put(f"{A}/review-rules", json=off, headers=auth(s))).status_code == 403
    owner = await make_owner(client, email="x@x.in", company="X")
    assert (await client.get(f"{A}/reviews", headers=auth(owner))).status_code == 401
