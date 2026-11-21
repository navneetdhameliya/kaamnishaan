"""A30 Analytics. Days are counted in India time (the team's working day)."""

from datetime import date, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import now
from app.models import Company, Evidence, Industry, JobEvent, Report, VoiceNote
from app.schemas.admin_analytics import AdminAnalyticsOut, Bucket, Metric, Share
from app.services.checklists import pick

IST = ZoneInfo("Asia/Kolkata")
LANGS = ("hi", "gu", "en", "es", "fr")


async def _sent(db: AsyncSession, a, b) -> int:
    return int(await db.scalar(select(func.count()).where(Report.shared_at >= a, Report.shared_at < b)) or 0)


async def _review_minutes(db: AsyncSession, a, b) -> float | None:
    mins = func.extract("epoch", Report.approved_at - Report.submitted_at) / 60
    q = select(func.percentile_cont(0.5).within_group(mins)).where(
        Report.approved_at >= a, Report.approved_at < b, Report.submitted_at.is_not(None)
    )
    v = await db.scalar(q)
    return round(float(v), 1) if v is not None else None


async def _first_time(db: AsyncSession, a, b) -> float | None:
    sent_back = (
        select(JobEvent.id)
        .where(JobEvent.job_id == Report.job_id, JobEvent.type == "changes_requested")
        .exists()
    )
    row = (
        await db.execute(
            select(func.count(), func.count().filter(~sent_back)).where(
                Report.approved_at >= a, Report.approved_at < b
            )
        )
    ).one()
    total, clean = int(row[0]), int(row[1])
    return round(100 * clean / total, 1) if total else None


async def _active(db: AsyncSession, a, b) -> int:
    photos = select(Evidence.taken_by.label("u")).where(Evidence.taken_at >= a, Evidence.taken_at < b)
    notes = select(VoiceNote.recorded_by.label("u")).where(
        VoiceNote.recorded_at >= a, VoiceNote.recorded_at < b
    )
    both = photos.union(notes).subquery()
    return int(await db.scalar(select(func.count(func.distinct(both.c.u)))) or 0)


async def overview(db: AsyncSession, days: int, lang: str) -> AdminAnalyticsOut:
    end = now()
    start, before = end - timedelta(days=days), end - timedelta(days=2 * days)

    # reports sent, by day (up to 30 days) or by week (Monday first), in India time
    step = "day" if days <= 30 else "week"
    local = func.timezone("Asia/Kolkata", Report.shared_at)
    unit = func.date_trunc(step, local)
    rows = dict(
        (await db.execute(
            select(unit, func.count()).where(Report.shared_at >= start, Report.shared_at < end).group_by(unit)
        )).all()
    )  # fmt: skip
    counts = {k.date(): int(v) for k, v in rows.items()}
    first: date = start.astimezone(IST).date()
    if step == "week":
        first -= timedelta(days=first.weekday())
    last = end.astimezone(IST).date()
    buckets, d = [], first
    while d <= last:
        buckets.append(Bucket(start=d, count=counts.get(d, 0)))
        d += timedelta(days=1 if step == "day" else 7)

    spoken = func.lower(
        func.substr(func.coalesce(VoiceNote.detected_language, VoiceNote.language_hint), 1, 2)
    )
    voice = (
        await db.execute(
            select(spoken, func.count())
            .where(VoiceNote.recorded_at >= start, VoiceNote.recorded_at < end, VoiceNote.kind == "audio")
            .group_by(spoken)
        )
    ).all()
    by_lang: dict[str, int] = {}
    for code, n in voice:
        key = code if code in LANGS else "other"
        by_lang[key] = by_lang.get(key, 0) + int(n)

    ind = (
        await db.execute(
            select(Company.industry_slug, Industry.name, func.count())
            .select_from(Report)
            .join(Company, Company.id == Report.company_id)
            .outerjoin(Industry, Industry.slug == Company.industry_slug)
            .where(Report.shared_at >= start, Report.shared_at < end)
            .group_by(Company.industry_slug, Industry.name)
            .order_by(func.count().desc())
        )
    ).all()

    return AdminAnalyticsOut(
        days=days,
        reports_sent=Metric(value=await _sent(db, start, end), previous=await _sent(db, before, start)),
        review_minutes=Metric(
            value=await _review_minutes(db, start, end), previous=await _review_minutes(db, before, start)
        ),
        first_time=Metric(
            value=await _first_time(db, start, end), previous=await _first_time(db, before, start)
        ),
        active_technicians=Metric(
            value=await _active(db, start, end), previous=await _active(db, before, start)
        ),
        step=step,
        sent_by_period=buckets,
        voice_languages=[
            Share(key=k, count=v) for k, v in sorted(by_lang.items(), key=lambda x: (x[0] == "other", -x[1]))
        ],
        voice_total=sum(by_lang.values()),
        reports_by_industry=[
            Share(key=slug or "other", label=pick(name, lang) if name else None, count=int(n))
            for slug, name, n in ind
        ],
    )
