"""Settings come from environment variables only. Secrets are never committed."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator
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
    storage_bucket: str = "kaamnishaan-local"
    storage_endpoint: str | None = None  # Cloudflare R2 S3 endpoint
    storage_access_key: SecretStr | None = None
    storage_secret_key: SecretStr | None = None
    sms_provider: Literal["console", "msg91"] = "console"

    @field_validator("database_url")
    @classmethod
    def _asyncpg_driver(cls, v: str) -> str:
        # Render and most hosts hand out postgres:// or postgresql:// URLs.
        for prefix in ("postgres://", "postgresql://"):
            if v.startswith(prefix):
                return "postgresql+asyncpg://" + v[len(prefix) :]
        return v

    @property
    def is_production(self) -> bool:
        return self.env == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
