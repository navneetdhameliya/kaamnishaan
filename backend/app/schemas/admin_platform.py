"""Admin panel: A32 Platform settings."""

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.schemas.admin_companies import AdminOption


class AdminPlatformSettings(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    support_email: EmailStr | None = Field(None, description="Empty = the server setting")
    support_whatsapp: str | None = Field(None, max_length=20, description="Empty = the server setting")
    default_country: str | None = Field(None, min_length=2, max_length=2)
    signups: bool
    ai_drafting: bool
    ai_assistant: bool
    maintenance: bool
    max_photo_mb: int = Field(ge=2, le=25)


class AdminPlatformServer(BaseModel):
    """What the server is set to (Render), used when a field above is empty."""

    support_email: str | None
    support_whatsapp: str | None
    default_country: str
    ai_key: bool = Field(description="An OpenAI key is set; without it AI switches have no effect")
    email_on: bool


class AdminPlatformOut(BaseModel):
    settings: AdminPlatformSettings
    server: AdminPlatformServer
    countries: list[AdminOption]
    can_act: bool
