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
    openai_api_key: SecretStr | None = None
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


@lru_cache
def get_settings() -> Settings:
    return Settings()
