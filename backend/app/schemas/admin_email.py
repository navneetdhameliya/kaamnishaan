"""Admin panel: A33 Email settings."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AdminEmailGroups(BaseModel):
    model_config = ConfigDict(extra="forbid")
    account: bool = Field(description="Email confirmation and password reset")
    reports: bool = Field(description="Report and rating links to customers")
    reminders: bool = Field(description="Day 2 review reminders")
    team: bool = Field(description="Notices to owners and managers")


class AdminEmailSettings(BaseModel):
    enabled: bool
    from_name: str
    from_email: str | None
    host: str | None
    port: int
    security: Literal["starttls", "ssl"]
    username: str | None
    password_set: bool
    groups: AdminEmailGroups


class AdminEmailOut(BaseModel):
    settings: AdminEmailSettings
    live: bool = Field(description="Emails really go out now")
    can_act: bool


class AdminEmailIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    enabled: bool
    from_name: str = Field(min_length=1, max_length=80)
    from_email: EmailStr | None = None
    host: str | None = Field(None, max_length=200)
    port: int = Field(587, ge=1, le=65535)
    security: Literal["starttls", "ssl"] = "starttls"
    username: str | None = Field(None, max_length=200)
    password: str | None = Field(
        None, max_length=500, description="None = keep the saved one; '' = remove it"
    )
    groups: AdminEmailGroups


class AdminEmailTest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    to: EmailStr


class AdminEmailTestOut(BaseModel):
    to: str
