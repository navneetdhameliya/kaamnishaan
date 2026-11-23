"""A33 Email settings: connect any SMTP email service, choose which emails go out, send a test."""

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.staff_security import seal
from app.providers import messaging
from app.schemas.admin_email import AdminEmailGroups, AdminEmailIn, AdminEmailOut, AdminEmailSettings
from app.services import audit, platform


def _out(cfg: platform.EmailConfig, can_act: bool) -> AdminEmailOut:
    return AdminEmailOut(
        settings=AdminEmailSettings(
            enabled=cfg.enabled, from_name=cfg.from_name, from_email=cfg.from_email, host=cfg.host,
            port=cfg.port, security=cfg.security, username=cfg.username,
            password_set=bool(cfg.password_sealed),
            groups=AdminEmailGroups(**{g: cfg.groups.get(g, True) for g in platform.EMAIL_GROUPS}),
        ),
        live=cfg.enabled and cfg.ready, can_act=can_act,
    )  # fmt: skip


async def get(db: AsyncSession, *, can_act: bool) -> AdminEmailOut:
    return _out(await platform.email_config(db), can_act)


async def save(db: AsyncSession, body: AdminEmailIn, *, staff_id: uuid.UUID, ip: str | None) -> AdminEmailOut:
    if body.enabled:
        missing = {f: "required" for f in ("host", "from_email") if not getattr(body, f)}
        if missing:
            raise AppError("validation_error", "Some fields are not valid.", fields=missing, status=422)
    before = await platform.email_config(db)
    sealed = before.password_sealed
    if body.password is not None:
        sealed = seal(body.password) if body.password else None
    after = platform.EmailConfig(
        enabled=body.enabled, from_name=body.from_name,
        from_email=str(body.from_email).lower() if body.from_email else None,
        host=body.host or None, port=body.port, security=body.security, username=body.username or None,
        password_sealed=sealed, groups=body.groups.model_dump(),
    )  # fmt: skip
    await platform.set_email_config(db, after, staff_id=staff_id)
    changed = {
        k: v for k, v in after.model_dump(exclude={"password_sealed"}).items() if getattr(before, k) != v
    }
    if sealed != before.password_sealed:
        changed["password"] = "changed" if sealed else "removed"  # never the password itself
    if changed:
        await audit.record(db, "staff.email_settings_updated", staff_id=staff_id, target_type="platform",
                           data=changed, ip=ip)  # fmt: skip
    return _out(after, True)


async def test(db: AsyncSession, to: str, *, staff_id: uuid.UUID, ip: str | None) -> str:
    """Sends a short email with the saved settings, so staff see at once whether they work."""
    cfg = await platform.email_config(db)
    if not cfg.ready:
        raise AppError("email_not_set", "Fill in and save the email service first.", status=409)
    smtp = messaging.Smtp(
        host=cfg.host, port=cfg.port, security=cfg.security, username=cfg.username,
        password=messaging.unseal_password(cfg.password_sealed), from_name=cfg.from_name,
        from_email=cfg.from_email,
    )  # fmt: skip
    try:
        await messaging.send_smtp(
            smtp, to, "KaamNishaan test email",
            "This is a test from the KaamNishaan admin panel. Your email settings work.",
        )  # fmt: skip
    except Exception as e:  # noqa: BLE001 - any SMTP or network problem is shown to staff
        raise AppError(
            "smtp_failed",
            "The test email was not sent: {reason}",
            status=502,
            params={"reason": f"{type(e).__name__}: {e}"[:300]},
        ) from None
    await audit.record(
        db, "staff.email_test", staff_id=staff_id, target_type="platform", data={"to": to}, ip=ip
    )
    return to
