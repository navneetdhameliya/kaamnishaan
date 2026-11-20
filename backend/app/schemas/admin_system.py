"""A34 Storage settings and A35 Localization settings."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import Locale


class StorageKind(BaseModel):
    kind: Literal["photos", "voice", "pdfs"]
    files: int
    bytes: int


class StorageCompany(BaseModel):
    id: str
    name: str
    bytes: int


class AdminStorageOut(BaseModel):
    provider: Literal["local", "r2"] = Field(
        description="r2 = Cloudflare R2; local = files on the server (testing)"
    )
    bucket: str
    kinds: list[StorageKind] = Field(
        description="Originals only; small copies and thumbnails are not counted"
    )
    total_bytes: int
    top_companies: list[StorageCompany]
    link_minutes: int = Field(description="How long a file link works")
    max_photo_mb: int = Field(description="Changed in Platform settings (A32)")
    locked_evidence: int = Field(description="Photos locked because their report was sent for approval")


class LanguageRow(BaseModel):
    code: Locale
    native_name: str
    app_checked: int = Field(description="% of app texts a person checked (A25); English is the source = 100")
    site_checked: int
    reports: bool = True
    voice: bool = True


class AdminLocalizationOut(BaseModel):
    languages: list[LanguageRow]
    report_language: Locale = Field(description="Report language a new company starts with")
    can_act: bool


class AdminLocalizationIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    report_language: Locale
