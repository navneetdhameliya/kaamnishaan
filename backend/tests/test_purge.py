"""D-154: a closed company's data is deleted 30 days after the owner closed it; the company row stays."""

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.providers.storage import get_storage
from app.services import purge
from tests.conftest import auth, make_owner
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture


async def _one(sql: str, **kw):
    async with engine.begin() as c:
        return (await c.execute(text(sql), kw)).scalar()


async def test_closing_your_account_starts_the_30_days(client):
    owner = await make_owner(client, email="solo@x.in", company="Solo Co")
    r = await client.post("/api/v1/me/delete", json={"confirm": True}, headers=auth(owner))
    assert r.status_code == 204, r.text
    status, closed = (
        (await _one("select row(status, closed_at is not null)::text from companies where name = 'Solo Co'"))
        .strip("()")
        .split(",")
    )
    assert (status, closed) == ("cancelled", "t")


async def test_purge_deletes_files_and_rows_after_30_days_and_keeps_the_record(client, ready):
    await make_report(client, ready["tech"], ready["job"]["id"])
    company = (await client.get("/api/v1/me", headers=auth(ready["owner"]))).json()["company"]["id"]
    keys = [k for (k,) in (await _rows("select file_key from evidence where company_id = :c", c=company))]
    storage = get_storage()
    assert keys and all(storage.path(k).exists() for k in keys)

    async with engine.begin() as c:
        await c.execute(
            text(
                "update companies set status = 'cancelled', closed_at = now() - interval '29 days' where id = :c"
            ),
            {"c": company},
        )
    async with SessionLocal() as db:
        assert await purge.purge_due(db) == []  # not yet
    async with engine.begin() as c:
        await c.execute(
            text("update companies set closed_at = now() - interval '31 days' where id = :c"), {"c": company}
        )
    async with SessionLocal() as db:
        done = await purge.purge_due(db)
    assert [str(x) for x in done] == [company]

    assert not any(storage.path(k).exists() for k in keys)
    for table in ("jobs", "evidence", "reports", "customers", "memberships", "notifications"):
        assert await _one(f"select count(*) from {table} where company_id = :c", c=company) == 0, table  # noqa: S608
    assert await _one("select purged_at is not null from companies where id = :c", c=company)
    assert (
        await _one(
            "select count(*) from audit_logs where action = 'company.purged' and company_id = :c", c=company
        )
        == 1
    )
    # the technician keeps their own account, and a second run does nothing
    assert await _one("select count(*) from users where id = :u", u=ready["tech"]["user"]["id"]) == 1
    async with SessionLocal() as db:
        assert await purge.purge_due(db) == []


async def _rows(sql: str, **kw):
    async with engine.begin() as c:
        return (await c.execute(text(sql), kw)).all()
