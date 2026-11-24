"""Platform-wide settings kept in the database (platform_settings). Each group has defaults in code."""

import uuid
from typing import Literal

from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models import PlatformSetting


class ReviewRules(BaseModel):
    """A37 "Review rules": checks run on every new customer review."""

    hide_contact: bool = True  # hide phone numbers and emails in the comment
    flag_abuse: bool = True  # hold reviews with abusive words (5 languages) for KaamNishaan to check
    block_repeats: bool = True  # hold a second review from the same phone number within a day


async def review_rules(db: AsyncSession) -> ReviewRules:
    row = await db.get(PlatformSetting, "review_rules")
    return ReviewRules(**(row.value if row else {}))


async def set_review_rules(db: AsyncSession, rules: ReviewRules, *, staff_id: uuid.UUID) -> ReviewRules:
    row = await db.get(PlatformSetting, "review_rules")
    if not row:
        row = PlatformSetting(key="review_rules")
        db.add(row)
    row.value, row.updated_by = rules.model_dump(), staff_id
    await db.flush()
    return rules


# ---- A38 AI review calls -------------------------------------------------------------------------------
OPENING = "Hi, this is {company}'s virtual assistant. I'm an AI and this call is recorded."
HOURS = ("10-19", "9-20", "11-18")  # calling hours, the company's local time


class AiCallSettings(BaseModel):
    voice: Literal["warm", "bright", "formal"] = "warm"
    language: Literal["report", "en"] = "report"  # the report's language, or always English
    hours: Literal["10-19", "9-20", "11-18"] = "10-19"
    attempts: Literal["call_voicemail", "two_calls", "call_only"] = "call_voicemail"
    record: bool = True
    # always on (legal and kindness rules), shown locked in the admin panel
    skip_dnd: Literal[True] = True
    only_if_no_rating: Literal[True] = True


SCRIPT_STEPS = (
    ("greeting", "Say the opening line word for word. Ask if it's a good time for one minute about the {job} "
                 "job on {date}."),
    ("bad_time", "If it's not a good time, offer to call back later today or to send the rating link by SMS. "
                 "Do what they choose."),
    ("dont_call", "If they say not to call, apologise, confirm they won't be called again, and end the "
                  "call."),
    ("ask_rating", "Ask them to rate the job from 1 to 5, where 5 is excellent."),
    ("good", "For 3 to 5: ask what went well, then ask if the company may show the review publicly."),
    ("bad", "For 1 or 2: ask what went wrong, then ask if they'd like a call from the manager."),
    ("confirm", "Read the rating and their words back, save them, and say a thank-you SMS is on its way."),
    ("no_answer", "If nobody answers, leave a short voicemail and send the rating link by SMS."),
    ("wrong_person", "If it's the wrong person, apologise, end the call and mark the contact as wrong."),
)  # fmt: skip


class ScriptStep(BaseModel):
    key: str
    text: str


class AiCallScript(BaseModel):
    version: int = 1
    steps: list[ScriptStep] = [ScriptStep(key=k, text=t) for k, t in SCRIPT_STEPS]


async def _get(db: AsyncSession, key: str) -> dict:
    row = await db.get(PlatformSetting, key)
    return dict(row.value) if row else {}


async def _put(db: AsyncSession, key: str, value: dict, staff_id: uuid.UUID | None) -> None:
    row = await db.get(PlatformSetting, key)
    if not row:
        row = PlatformSetting(key=key)
        db.add(row)
    row.value, row.updated_by = value, staff_id
    await db.flush()


async def ai_call_settings(db: AsyncSession) -> AiCallSettings:
    return AiCallSettings(**await _get(db, "ai_calls"))


async def set_ai_call_settings(db: AsyncSession, s: AiCallSettings, *, staff_id: uuid.UUID) -> AiCallSettings:
    await _put(db, "ai_calls", s.model_dump(), staff_id)
    return s


async def ai_call_script(db: AsyncSession) -> AiCallScript:
    saved = AiCallScript(**await _get(db, "ai_call_script"))
    texts = {s.key: s.text for s in saved.steps}
    # steps added in code later appear with their default text
    return AiCallScript(
        version=saved.version, steps=[ScriptStep(key=k, text=texts.get(k, t)) for k, t in SCRIPT_STEPS]
    )


async def set_script_step(db: AsyncSession, key: str, text: str, *, staff_id: uuid.UUID) -> AiCallScript:
    script = await ai_call_script(db)
    steps = [ScriptStep(key=s.key, text=text if s.key == key else s.text) for s in script.steps]
    out = AiCallScript(version=script.version + 1, steps=steps)
    await _put(db, "ai_call_script", out.model_dump(), staff_id)
    return out


# ---- the voice provider's health (A38 "provider not responding" banner) ---------------------------------
async def voice_status(db: AsyncSession) -> dict:
    """{"down_since": iso or None}: set by the first failed call, cleared by the next one that works."""
    return await _get(db, "voice_status")


async def set_voice_down(db: AsyncSession, since: str | None) -> None:
    await _put(db, "voice_status", {"down_since": since}, None)


# ---- A40 credit rules ------------------------------------------------------------------------------------
class CreditCosts(BaseModel):
    """Credits one message or call uses. Email is always free."""

    sms: int = 1
    whatsapp: int = 1
    ai_call: int = 10


async def credit_costs(db: AsyncSession) -> CreditCosts:
    return CreditCosts(**await _get(db, "credit_rules"))


async def set_credit_costs(db: AsyncSession, c: CreditCosts, *, staff_id: uuid.UUID) -> CreditCosts:
    await _put(db, "credit_rules", c.model_dump(), staff_id)
    return c


# ---- A32 Platform settings -----------------------------------------------------------------------------
class PlatformConfig(BaseModel):
    """Switches and values for every company. Empty contact fields fall back to the server settings."""

    support_email: str | None = None
    support_whatsapp: str | None = None
    default_country: str | None = None
    signups: bool = True  # owners can start a company (and its trial) themselves
    ai_drafting: bool = True  # AI writes report drafts; off = the plain template
    ai_assistant: bool = True  # the AI assistant in the apps
    maintenance: bool = False  # blocks new logins and sign-ups; the apps show a notice
    max_photo_mb: int = 12


async def config(db: AsyncSession) -> PlatformConfig:
    return PlatformConfig(**await _get(db, "platform"))


async def set_config(db: AsyncSession, c: PlatformConfig, *, staff_id: uuid.UUID) -> PlatformConfig:
    await _put(db, "platform", c.model_dump(), staff_id)
    return c


async def check_open(db: AsyncSession) -> None:
    """Maintenance mode: no new logins or sign-ups (KaamNishaan staff can still use the admin panel)."""
    if (await config(db)).maintenance:
        from app.core.errors import AppError

        raise AppError(
            "maintenance", "KaamNishaan is down for a short update. Please try again soon.", status=503
        )


# ---- A33 Email settings -------------------------------------------------------------------------------
EMAIL_GROUPS = ("account", "reports", "reminders", "team")


class EmailConfig(BaseModel):
    """The email service (any SMTP provider). Off until staff fill it in and switch it on (D-96)."""

    enabled: bool = False
    from_name: str = "KaamNishaan"
    from_email: str | None = None
    host: str | None = None
    port: int = 587
    security: Literal["starttls", "ssl"] = "starttls"
    username: str | None = None
    password_sealed: str | None = None  # encrypted with the server's secret, never sent back
    groups: dict[str, bool] = {g: True for g in EMAIL_GROUPS}

    @property
    def ready(self) -> bool:
        return bool(self.host and self.from_email and self.port)


async def email_config(db: AsyncSession) -> EmailConfig:
    return EmailConfig(**await _get(db, "email"))


async def set_email_config(db: AsyncSession, c: EmailConfig, *, staff_id: uuid.UUID) -> EmailConfig:
    await _put(db, "email", c.model_dump(), staff_id)
    return c


# ---- free trial (A17) -----------------------------------------------------------------------------
class TrialConfig(BaseModel):
    """New companies start on this plan for this many days. No card is asked for (no payments yet)."""

    plan_code: str = "professional"
    days: int = Field(default_factory=lambda: get_settings().trial_days, ge=3, le=60)


async def trial(db: AsyncSession) -> TrialConfig:
    return TrialConfig(**await _get(db, "trial"))


async def set_trial(db: AsyncSession, c: TrialConfig, *, staff_id: uuid.UUID) -> TrialConfig:
    await _put(db, "trial", c.model_dump(), staff_id)
    return c


# ---- A19 AI configuration ------------------------------------------------------------------------------
class AiConfig(BaseModel):
    """Which models are used and the limits around them. The API key itself stays on the server (Render)."""

    text_model: str = Field(default_factory=lambda: get_settings().openai_text_model)
    transcribe_model: str = Field(default_factory=lambda: get_settings().openai_transcribe_model)
    fallback: Literal["template", "error"] = "error"  # when the AI fails while writing a report
    monthly_budget_usd: float = Field(default_factory=lambda: get_settings().ai_monthly_budget_usd, ge=0)
    max_tokens_report: int = Field(3000, ge=500, le=16000)
    mask_contacts: bool = True  # phone numbers and emails in notes are hidden before sending


async def ai_config(db: AsyncSession) -> AiConfig:
    return AiConfig(**await _get(db, "ai_config"))


async def set_ai_config(db: AsyncSession, c: AiConfig, *, staff_id: uuid.UUID) -> AiConfig:
    await _put(db, "ai_config", c.model_dump(), staff_id)
    return c


# ---- A29 automatic messages ----------------------------------------------------------------------------
IN_APP_KINDS = (
    "job_assigned", "report_submitted", "changes_requested", "report_approved", "report_shared",
    "review_received", "low_rating", "support_reply", "tech_question", "plan_limit",
    "customer_issue",
)  # fmt: skip


class NotificationRules(BaseModel):
    """Which in-app messages are made, for every company. Off = not made at all."""

    on: dict[str, bool] = Field(default_factory=lambda: dict.fromkeys(IN_APP_KINDS, True))

    def allows(self, kind: str) -> bool:
        return self.on.get(kind, True)


async def notification_rules(db: AsyncSession) -> NotificationRules:
    saved = NotificationRules(**await _get(db, "notification_rules"))
    return NotificationRules(on={k: saved.on.get(k, True) for k in IN_APP_KINDS})


async def set_notification_rules(db: AsyncSession, r: NotificationRules, *, staff_id: uuid.UUID) -> None:
    await _put(db, "notification_rules", r.model_dump(), staff_id)


# ---- A35 Localization ------------------------------------------------------------------------------------
class Localization(BaseModel):
    # the language customer reports start in for a new company; owners change it in Company settings
    report_language: Literal["en", "hi", "gu", "es", "fr"] = "en"


async def localization(db: AsyncSession) -> Localization:
    return Localization(**await _get(db, "localization"))


async def set_localization(db: AsyncSession, c: Localization, *, staff_id: uuid.UUID) -> Localization:
    await _put(db, "localization", c.model_dump(), staff_id)
    return c
