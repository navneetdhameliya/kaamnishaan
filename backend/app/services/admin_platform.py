"""A32 Platform settings: switches and values for every company, saved in platform_settings."""

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import normalize_phone
from app.providers.ai import get_ai
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_platform import AdminPlatformOut, AdminPlatformServer, AdminPlatformSettings
from app.services import audit, platform
from app.services.sharing import email_on


async def get(db: AsyncSession, *, can_act: bool) -> AdminPlatformOut:
    from app.api.v1.routes.public import COUNTRIES  # the same list the apps show

    s = get_settings()
    cfg = await platform.config(db)
    return AdminPlatformOut(
        settings=AdminPlatformSettings(**cfg.model_dump()),
        server=AdminPlatformServer(
            support_email=s.support_email, support_whatsapp=s.support_whatsapp,
            default_country=s.default_country, ai_key=get_ai() is not None, email_on=await email_on(db),
        ),
        countries=[AdminOption(value=c, label=n) for c, n, *_ in COUNTRIES],
        can_act=can_act,
    )  # fmt: skip


async def save(
    db: AsyncSession, body: AdminPlatformSettings, *, staff_id: uuid.UUID, ip: str | None
) -> AdminPlatformOut:
    from app.api.v1.routes.public import COUNTRIES

    data = body.model_dump()
    errors = {}
    if data["support_whatsapp"]:
        try:
            data["support_whatsapp"] = normalize_phone(data["support_whatsapp"], "IN")
        except AppError:
            errors["support_whatsapp"] = "invalid"
    if data["default_country"] and data["default_country"].upper() not in {c for c, *_ in COUNTRIES}:
        errors["default_country"] = "unknown"
    if errors:
        raise AppError("validation_error", "Some fields are not valid.", fields=errors, status=422)
    if data["default_country"]:
        data["default_country"] = data["default_country"].upper()
    data["support_email"] = str(data["support_email"]).lower() if data["support_email"] else None
    before = await platform.config(db)
    after = platform.PlatformConfig(**data)
    await platform.set_config(db, after, staff_id=staff_id)
    changed = {k: v for k, v in after.model_dump().items() if getattr(before, k) != v}
    if changed:
        m = changed.get("maintenance")
        action = {True: "staff.maintenance_on", False: "staff.maintenance_off"}.get(
            m, "staff.platform_updated"
        )
        await audit.record(db, action, staff_id=staff_id, target_type="platform", data=changed, ip=ip)
    return await get(db, can_act=True)
