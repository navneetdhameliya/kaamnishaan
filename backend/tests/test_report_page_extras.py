"""D-149 on the customer's report page: "Edit your review", "Book next service" and good reviews."""

import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.services import reviews
from tests.conftest import auth
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture
from tests.test_review_office import asked, rate
from tests.test_sharing import shared_link


async def test_customer_can_change_their_review_for_a_week(client, ready):
    token = await asked(client, ready)
    await rate(client, token, rating=3, comment="Okay")
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()["review"]
    assert page["can_edit"] and (page["rating"], page["comment"]) == (3, "Okay")

    r = await client.put(
        f"/api/v1/public/reports/{token}/review",
        json={"rating": 5, "tags": ["on_time"], "comment": "Called back and fixed it"},
    )
    assert r.status_code == 200, r.text
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()["review"]
    assert (page["rating"], page["tags"], page["comment"]) == (5, ["on_time"], "Called back and fixed it")

    async with engine.begin() as c:
        await c.execute(text("update reviews set created_at = created_at - interval '8 days'"))
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()["review"]
    assert not page["can_edit"]
    late = await client.put(f"/api/v1/public/reports/{token}/review", json={"rating": 1})
    assert late.status_code == 409 and late.json()["error"]["code"] == "review_locked"


async def test_book_next_service_reaches_the_office(client, ready):
    _, token = await shared_link(client, ready)
    r = await client.post(
        f"/api/v1/public/reports/{token}/service-request",
        json={"when": "next_month", "note": "Before the summer, please", "contact": "98250 33333"},
    )
    assert r.status_code == 201, r.text
    items = (await client.get("/api/v1/notifications", headers=auth(ready["owner"]))).json()["data"]
    [n] = [n for n in items if n["kind"] == "service_request"]
    assert (n["params"]["when"], n["params"]["note"], n["params"]["contact"]) == (
        "next_month",
        "Before the summer, please",
        "98250 33333",
    )
    assert n["job_id"]
    bad = await client.post(f"/api/v1/public/reports/{token}/service-request", json={"when": "someday"})
    assert bad.status_code == 422


async def test_good_reviews_show_on_other_reports_when_switched_on(client, ready):
    owner = ready["owner"]
    token = await asked(client, ready)
    await rate(client, token, rating=5, comment="Spotless work", name="Anita Rao", public_allowed=True)
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["praise"] == []  # off by default
    await client.patch("/api/v1/review-settings", json={"show_public_reviews": True}, headers=auth(owner))
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["praise"] == []  # never the job's own review
    company = (await client.get("/api/v1/me", headers=auth(owner))).json()["company"]["id"]
    async with SessionLocal() as db:  # as seen from another job's report
        [p] = await reviews.public_praise(db, uuid.UUID(company), uuid.uuid4())
    assert (p.rating, p.comment, p.name) == (5, "Spotless work", "Anita")
