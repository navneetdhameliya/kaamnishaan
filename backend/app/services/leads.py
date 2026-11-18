"""W03 Book a demo and W05 Contact: free demo times, bookings and messages (no account needed)."""

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, Conflict, RateLimited
from app.core.security import now
from app.models import Industry, Lead
from app.schemas.blog import NewsletterIn, NewsletterOut
from app.schemas.leads import (
    ContactMessageIn,
    ContactMessageOut,
    DemoBookedOut,
    DemoDay,
    DemoRequestIn,
    DemoSlotsOut,
    SupportOut,
    SupportRegion,
)

TEAM_SIZES = ["1-5", "6-15", "16-50", "51+"]
TOPICS = ["sales", "support", "billing", "partnership", "other"]
# "Teams we support" on W05
REGIONS = [("IN", ["hi", "gu", "en"]), ("US", ["en", "es"]), ("MX", ["es"]), ("ES", ["es"]), ("FR", ["fr"])]
PER_HOUR = 5  # messages or bookings from one address


def ticket(lead: Lead) -> str:
    return f"KN-{lead.number}"


def support() -> SupportOut:
    s = get_settings()
    return SupportOut(
        email=s.support_email,
        whatsapp=s.support_whatsapp,
        help_url=s.help_url,
        office=s.office,
        open=s.support_open,
        close=s.support_close,
        days=s.support_days,
        timezone=s.demo_timezone,
        regions=[SupportRegion(country=c, languages=ls) for c, ls in REGIONS],  # type: ignore[arg-type]
        topics=TOPICS,  # type: ignore[arg-type]
        demo_minutes=s.demo_minutes,
    )


def _all_slots(t: datetime) -> list[datetime]:
    """Every demo start on weekdays from 2 hours from now, up to demo_days_ahead days."""
    s = get_settings()
    tz = ZoneInfo(s.demo_timezone)
    start = t.astimezone(tz)
    earliest = t + timedelta(hours=2)
    out: list[datetime] = []
    for d in range(s.demo_days_ahead + 1):
        day = (start + timedelta(days=d)).date()
        if day.isoweekday() > 5:
            continue
        for hm in s.demo_times:
            h, m = (int(x) for x in hm.split(":"))
            at = datetime(day.year, day.month, day.day, h, m, tzinfo=tz)
            if at >= earliest:
                out.append(at)
    return out


async def _taken(db: AsyncSession) -> set[datetime]:
    rows = await db.execute(select(Lead.starts_at).where(Lead.kind == "demo", Lead.starts_at > now()))
    return {r.astimezone(UTC) for (r,) in rows if r}


async def demo_slots(db: AsyncSession) -> DemoSlotsOut:
    s = get_settings()
    taken = await _taken(db)
    days: dict = {}
    for at in _all_slots(now()):
        if at.astimezone(UTC) in taken:
            continue
        days.setdefault(at.date(), []).append(at)
    return DemoSlotsOut(
        timezone=s.demo_timezone,
        minutes=s.demo_minutes,
        days=[DemoDay(date=d, slots=sl) for d, sl in days.items()],
        team_sizes=TEAM_SIZES,  # type: ignore[arg-type]
    )


async def _limit(db: AsyncSession, ip: str | None) -> None:
    if not ip:
        return
    recent = await db.scalar(
        select(func.count())
        .select_from(Lead)
        # real time, not the clock tests can move
        .where(Lead.ip == ip, Lead.created_at > datetime.now(UTC) - timedelta(hours=1))
    )
    if (recent or 0) >= PER_HOUR:
        raise RateLimited("rate_limited", "Too many requests. Try again later.")


async def book_demo(db: AsyncSession, body: DemoRequestIn, ip: str | None) -> DemoBookedOut:
    s = get_settings()
    await _limit(db, ip)
    if not await db.get(Industry, body.trade):
        raise AppError("unknown_trade", "Choose your trade.", fields={"trade": "unknown"})
    at = body.starts_at.astimezone(UTC)
    if at not in {x.astimezone(UTC) for x in _all_slots(now())}:
        raise AppError(
            "slot_unavailable",
            "That time can't be booked. Pick another.",
            fields={"starts_at": "unavailable"},
        )
    if at in await _taken(db):
        raise Conflict(
            "slot_taken", "Someone just booked that time. Pick another.", fields={"starts_at": "taken"}
        )
    lead = Lead(
        kind="demo",
        name=body.name.strip(),
        email=body.email.lower(),
        phone=body.phone.strip(),
        company=body.company.strip(),
        team_size=body.team_size,
        trade=body.trade,
        starts_at=at,
        lang=body.lang,
        ip=ip,
    )
    db.add(lead)
    await db.flush()
    tz = ZoneInfo(s.demo_timezone)
    return DemoBookedOut(
        ticket=ticket(lead),
        starts_at=at.astimezone(tz),
        ends_at=(at + timedelta(minutes=s.demo_minutes)).astimezone(tz),
        timezone=s.demo_timezone,
    )


async def contact(db: AsyncSession, body: ContactMessageIn, ip: str | None) -> ContactMessageOut:
    await _limit(db, ip)
    lead = Lead(
        kind="contact",
        name=body.name.strip(),
        email=body.email.lower(),
        topic=body.topic,
        message=body.message.strip(),
        lang=body.lang,
        ip=ip,
    )
    db.add(lead)
    await db.flush()
    return ContactMessageOut(ticket=ticket(lead), topic=body.topic)


async def newsletter(db: AsyncSession, body: NewsletterIn, ip: str | None) -> NewsletterOut:
    """Blog newsletter (W25). Saving the same email twice is fine and stores it once."""
    email = body.email.lower()
    if await db.scalar(select(Lead.id).where(Lead.kind == "newsletter", Lead.email == email)):
        return NewsletterOut()
    await _limit(db, ip)
    db.add(Lead(kind="newsletter", name="", email=email, lang=body.lang, ip=ip))
    await db.flush()
    return NewsletterOut()
