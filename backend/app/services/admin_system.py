"""A34 Storage settings (what is stored and how files are protected) and A35 Localization settings."""

from sqlalchemy import func, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models import Company, Evidence, Report, TextOverride, VoiceNote
from app.schemas.admin_system import (
    AdminLocalizationOut,
    AdminStorageOut,
    LanguageRow,
    StorageCompany,
    StorageKind,
)
from app.services import audit, platform, texts

NATIVE = {"en": "English", "hi": "हिन्दी", "gu": "ગુજરાતી", "es": "Español", "fr": "Français"}


async def storage(db: AsyncSession) -> AdminStorageOut:
    s = get_settings()
    photos = (
        await db.execute(
            select(func.count(), func.coalesce(func.sum(Evidence.size), 0)).where(
                Evidence.deleted_at.is_(None)
            )
        )
    ).one()
    voice = (
        await db.execute(
            select(func.count(), func.coalesce(func.sum(VoiceNote.size), 0)).where(
                VoiceNote.audio_key.is_not(None)
            )
        )
    ).one()
    pdfs = (
        await db.execute(
            select(func.count(), func.coalesce(func.sum(Report.pdf_size), 0)).where(
                Report.pdf_key.is_not(None)
            )
        )
    ).one()
    kinds = [
        StorageKind(kind="photos", files=int(photos[0]), bytes=int(photos[1])),
        StorageKind(kind="voice", files=int(voice[0]), bytes=int(voice[1])),
        StorageKind(kind="pdfs", files=int(pdfs[0]), bytes=int(pdfs[1])),
    ]
    parts = union_all(
        select(Evidence.company_id.label("c"), Evidence.size.label("b")).where(Evidence.deleted_at.is_(None)),
        select(VoiceNote.company_id, func.coalesce(VoiceNote.size, 0)).where(
            VoiceNote.audio_key.is_not(None)
        ),
        select(Report.company_id, func.coalesce(Report.pdf_size, 0)).where(Report.pdf_key.is_not(None)),
    ).subquery()
    top = (
        await db.execute(
            select(Company.id, Company.name, func.sum(parts.c.b).label("b"))
            .join(parts, parts.c.c == Company.id)
            .group_by(Company.id, Company.name)
            .order_by(func.sum(parts.c.b).desc())
            .limit(10)
        )
    ).all()
    locked = await db.scalar(
        select(func.count()).where(Evidence.locked_at.is_not(None), Evidence.deleted_at.is_(None))
    )
    return AdminStorageOut(
        provider=s.storage_provider,
        bucket=s.storage_bucket,
        kinds=kinds,
        total_bytes=sum(k.bytes for k in kinds),
        top_companies=[StorageCompany(id=str(i), name=n, bytes=int(b or 0)) for i, n, b in top],
        link_minutes=s.storage_signed_url_ttl_seconds // 60,
        max_photo_mb=(await platform.config(db)).max_photo_mb,
        locked_evidence=int(locked or 0),
    )


async def localization(db: AsyncSession, *, can_act: bool) -> AdminLocalizationOut:
    keys = texts.text_keys()
    total = {a: sum(1 for k in keys if texts.area_of(k) == a) for a in ("app", "site")}
    rows = (
        await db.execute(
            select(TextOverride.key, TextOverride.lang).where(TextOverride.reviewed_at.is_not(None))
        )
    ).all()
    done: dict[tuple[str, str], int] = {}
    for key, lang in rows:
        if key in keys:
            a = texts.area_of(key)
            done[(a, lang)] = done.get((a, lang), 0) + 1

    def pct(area: str, lang: str) -> int:
        if lang == "en" or not total[area]:
            return 100
        return int(100 * done.get((area, lang), 0) / total[area])

    return AdminLocalizationOut(
        languages=[
            LanguageRow(code=c, native_name=n, app_checked=pct("app", c), site_checked=pct("site", c))  # type: ignore[arg-type]
            for c, n in NATIVE.items()
        ],
        report_language=(await platform.localization(db)).report_language,
        can_act=can_act,
    )


async def set_localization(
    db: AsyncSession, report_language: str, *, staff_id, ip, can_act: bool
) -> AdminLocalizationOut:
    before = (await platform.localization(db)).report_language
    if before != report_language:
        await platform.set_localization(
            db, platform.Localization(report_language=report_language), staff_id=staff_id
        )  # type: ignore[arg-type]
        await audit.record(
            db,
            "localization.updated",
            staff_id=staff_id,
            target_type="platform",
            data={"report_language": [before, report_language]},
            ip=ip,
        )
    return await localization(db, can_act=can_act)
