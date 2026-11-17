from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

from app.schemas.identity import Locale, _In

TeamSize = Literal["1-5", "6-15", "16-50", "51+"]
Topic = Literal["sales", "support", "billing", "partnership", "other"]


class DemoDay(BaseModel):
    date: date
    slots: list[datetime] = Field(description="free start times, in the demo time zone")


class DemoSlotsOut(BaseModel):
    timezone: str
    minutes: int
    days: list[DemoDay]
    team_sizes: list[TeamSize]


class DemoRequestIn(_In):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    phone: str = Field(min_length=6, max_length=20)
    company: str = Field(min_length=1, max_length=120)
    team_size: TeamSize
    trade: str
    starts_at: datetime
    lang: Locale = "en"


class DemoBookedOut(BaseModel):
    ticket: str
    starts_at: datetime
    ends_at: datetime
    timezone: str


class ContactMessageIn(_In):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    topic: Topic
    message: str = Field(min_length=20, max_length=1000)
    lang: Locale = "en"


class ContactMessageOut(BaseModel):
    ticket: str
    topic: Topic


class SupportRegion(BaseModel):
    country: str
    languages: list[Locale]


class SupportOut(BaseModel):
    email: str | None
    whatsapp: str | None = Field(description="digits with country code, for https://wa.me/<digits>")
    help_url: str | None
    office: str
    open: str = Field(description="HH:MM in timezone")
    close: str
    days: list[int] = Field(description="ISO weekdays, Monday = 1")
    timezone: str
    regions: list[SupportRegion]
    topics: list[Topic]
    demo_minutes: int
