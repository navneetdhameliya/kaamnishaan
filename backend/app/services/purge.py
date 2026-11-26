"""D-154: a closed company's data is deleted for good 30 days after the owner closed it (the privacy
policy's promise, D-130). Run once a day by the scheduler (POST /cron/purge-closed-companies).

Deleted: every photo, voice note, PDF, logo and other file in storage, and every row that belongs to the
company (customers, sites, jobs, proof, reports, reviews, messages, checklists, team memberships, credits).
Kept: the company row itself (name, country, plan, dates) as the record that it existed and when it was
deleted, and the audit log and AI usage rows (they keep their company id). The people who were on the
team keep their own accounts."""

import logging
import uuid
from datetime import datetime, timedelta

from sqlalchemy import Table, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import Company
from app.models.base import Base
from app.providers.storage import get_storage
from app.services import audit

log = logging.getLogger("kn.purge")

AFTER = timedelta(days=30)
KEEP = {"companies", "audit_logs", "ai_usage"}
# the files a company's rows point to: (table, columns); checklist pictures via the company's templates
FILES = (
    ("evidence", ("file_key", "thumb_key", "web_key")),
    ("voice_notes", ("audio_key",)),
    ("reports", ("pdf_key",)),
    ("customers", ("photo_key",)),
    ("equipment", ("photo_key",)),
    ("uploads", ("key",)),
    ("checklist_answers", ("signature_key",)),
)


def _company_tables() -> list[Table]:
    """Tables with a company_id that goes with the company, children before their parents."""
    out = []
    for t in reversed(Base.metadata.sorted_tables):
        if t.name in KEEP or "company_id" not in t.c:
            continue
        if any(
            fk.column.table.name == "companies" and fk.ondelete == "CASCADE"
            for fk in t.c.company_id.foreign_keys
        ):
            out.append(t)
    return out


async def _file_keys(db: AsyncSession, company: Company) -> list[str]:
    tables = Base.metadata.tables
    keys: list[str] = [company.logo_key] if company.logo_key else []
    for name, cols in FILES:
        t = tables[name]
        for col in cols:
            c = t.c[col]
            keys += list(await db.scalars(select(c).where(t.c.company_id == company.id, c.is_not(None))))
    q, tpl = tables["checklist_questions"], tables["checklist_templates"]
    keys += list(
        await db.scalars(
            select(q.c.reference_image_key)
            .join(tpl, tpl.c.id == q.c.template_id)
            .where(tpl.c.company_id == company.id, q.c.reference_image_key.is_not(None))
        )
    )
    return list(dict.fromkeys(keys))


async def purge_company(db: AsyncSession, company: Company) -> int:
    """Deletes the company's files and rows; returns how many files were deleted."""
    keys = await _file_keys(db, company)
    storage = get_storage()
    for k in keys:
        try:
            await storage.delete(k)
        except Exception:  # a file already gone must not keep the rest of the data alive
            log.warning("purge: couldn't delete %s", k, exc_info=True)
    for t in _company_tables():
        await db.execute(delete(t).where(t.c.company_id == company.id))
    company.logo_key, company.settings, company.purged_at = None, {}, now()
    await audit.record(
        db, "company.purged", company_id=company.id, actor_id=None, actor_role="system",
        target_type="company", target_id=company.id, data={"files": len(keys)},
    )  # fmt: skip
    await db.flush()
    return len(keys)


async def purge_due(db: AsyncSession, t: datetime | None = None) -> list[uuid.UUID]:
    """Every closed company whose 30 days are up, one at a time (each commits on its own)."""
    t = t or now()
    due = (
        await db.scalars(
            select(Company.id).where(
                Company.status == "cancelled", Company.closed_at <= t - AFTER, Company.purged_at.is_(None)
            )
        )
    ).all()
    done = []
    for cid in due:
        company = await db.get(Company, cid, with_for_update=True)
        if company is None or company.purged_at is not None:
            continue
        files = await purge_company(db, company)
        await db.commit()
        log.info("purged company %s (%d files)", cid, files)
        done.append(cid)
    return done
