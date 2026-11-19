"""Settings come from environment variables only. Secrets are never committed."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="KN_", extra="ignore")

    env: Literal["local", "test", "staging", "production"] = "local"
    api_name: str = "KaamNishaan API"
    # postgresql+asyncpg://user:pass@host:5432/db
    database_url: str = "postgresql+asyncpg://kaamnishaan:kaamnishaan@localhost:5432/kaamnishaan"
    secret_key: SecretStr = SecretStr("change-me-locally-only")
    cors_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:5173", "http://localhost:5174"]
    )

    # India-first defaults
    default_country: str = "IN"
    default_timezone: str = "Asia/Kolkata"
    default_locale: str = "en-IN"
    supported_locales: list[str] = Field(default_factory=lambda: ["en", "hi", "gu", "es", "fr"])

    # Providers (filled in later steps; optional so the app boots without them)
    openai_api_key: SecretStr | None = None  # without it, transcription and auto-translate wait
    openai_transcribe_model: str = "whisper-1"
    openai_text_model: str = "gpt-4o-mini"
    # Files: "local" keeps them in a folder (your computer, tests); "r2" uses Cloudflare R2.
    storage_provider: Literal["local", "r2"] = "local"
    storage_local_dir: str = "var/uploads"
    storage_bucket: str = "kaamnishaan-local"
    storage_endpoint: str | None = None  # https://<account>.r2.cloudflarestorage.com
    storage_access_key: SecretStr | None = None
    storage_secret_key: SecretStr | None = None
    storage_signed_url_ttl_seconds: int = 900  # every file link in a response works ~15 minutes
    # Background work (thumbnails now; SMS, AI and PDFs later). Without Redis, tasks run in the API process.
    redis_url: str | None = None
    sms_provider: Literal["console", "msg91"] = "console"
    whatsapp_provider: Literal["console"] = "console"  # WhatsApp Business provider not chosen yet
    # Test servers only: with this key set, GET /api/v1/dev/outbox shows the login codes, invites and
    # emails that were "sent" (no SMS provider yet). Never allowed in production.
    test_outbox_key: SecretStr | None = None
    # No email service is chosen yet. While this is false: owners' emails count as confirmed at sign-up,
    # reports and reviews go by SMS / WhatsApp / link only, and email shows as "off" in the app. The
    # password-reset email still goes to the test outbox (/api/v1/dev/outbox). Turn on with the provider.
    email_enabled: bool = False
    # store pages for "Get the app" on the website; empty until the apps are published
    android_app_url: str | None = None
    ios_app_url: str | None = None
    # Contact page (W05). A card is hidden while its value is empty.
    support_email: str | None = None
    support_whatsapp: str | None = None  # digits with country code, e.g. 919876543210
    help_url: str | None = None
    office: str = "Ahmedabad, Gujarat, India"
    # Admin panel. Setup links for staff point at admin_url. With admin_email set, the API makes that
    # person the first super admin on start-up (only while there is no super admin yet) and, until they
    # finish setting up, writes a fresh setup link to the server log (Render → Logs) on every start,
    # because there is no email service yet.
    admin_url: str = "http://localhost:5174"
    admin_email: str | None = None
    admin_name: str = "Admin"
    # Privacy policy and Terms (W06/W07). Until name, address and city are set the pages say "draft".
    legal_name: str | None = None  # the registered company name
    legal_address: str | None = None  # registered address, one line
    legal_city: str | None = None  # city whose courts hear disputes, e.g. "Ahmedabad"
    legal_email: str | None = None  # privacy questions; falls back to support_email
    support_open: str = "09:00"
    support_close: str = "19:00"
    support_days: list[int] = [1, 2, 3, 4, 5, 6]  # ISO weekdays, Monday = 1
    # Book a demo (W03): 30-minute calls at these local times on weekdays, up to N days ahead
    demo_timezone: str = "Asia/Kolkata"
    demo_times: list[str] = ["10:00", "11:30", "14:00", "16:30"]
    demo_days_ahead: int = 14
    demo_minutes: int = 30
    # Any scheduler (e.g. a GitHub Actions schedule) calls POST /api/v1/cron/review-followups with this key
    # as X-Cron-Key so Day 2 review reminders go out on time. Without it the endpoint is closed.
    cron_key: SecretStr | None = None

    # Where links in SMS and email point (customer page, invites, email verification)
    web_url: str = "http://localhost:5173"
    # This API's own public address (used for local file links)
    api_url: str = "http://localhost:8000"
    trial_days: int = 14

    @field_validator("database_url")
    @classmethod
    def _asyncpg_driver(cls, v: str) -> str:
        # Render and most hosts hand out postgres:// or postgresql:// URLs.
        for prefix in ("postgres://", "postgresql://"):
            if v.startswith(prefix):
                return "postgresql+asyncpg://" + v[len(prefix) :]
        return v

    @model_validator(mode="after")
    def _real_secret_outside_local(self) -> "Settings":
        weak = (
            self.secret_key.get_secret_value() in ("", "change-me-locally-only")
            or len(self.secret_key.get_secret_value()) < 32
        )
        if self.env in ("staging", "production") and weak:
            raise ValueError(
                "KN_SECRET_KEY must be a strong random value (32+ characters) outside local/test"
            )
        if self.env == "production" and self.test_outbox_key:
            raise ValueError("KN_TEST_OUTBOX_KEY must not be set in production")
        if self.env in ("staging", "production") and self.storage_provider != "r2":
            raise ValueError("KN_STORAGE_PROVIDER must be r2 outside local/test")
        if self.storage_provider == "r2" and not (
            self.storage_endpoint and self.storage_access_key and self.storage_secret_key
        ):
            raise ValueError("R2 needs KN_STORAGE_ENDPOINT, KN_STORAGE_ACCESS_KEY and KN_STORAGE_SECRET_KEY")
        return self

    @property
    def is_production(self) -> bool:
        return self.env == "production"

    @property
    def outbox_enabled(self) -> bool:
        return self.env in ("local", "test") or (self.env == "staging" and self.test_outbox_key is not None)


@lru_cache
def get_settings() -> Settings:
    return Settings()
