"""Testimonials: quotes from customers on the website's Home (W01), managed in A27."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.identity import Locale


class PublicTestimonial(BaseModel):
    id: uuid.UUID
    quote: str
    language: Locale = Field(description="Language of the quote (English when the asked one is missing)")
    name: str
    role: str
    company: str
    city: str | None
    photo_url: str | None


class PublicTestimonials(BaseModel):
    items: list[PublicTestimonial]


class AdminTestimonial(BaseModel):
    id: uuid.UUID
    quote: dict[str, str]
    person_name: str
    role: str
    company_name: str
    city: str | None
    photo: str | None
    photo_url: str | None
    approved_in_writing: bool
    approval_note: str | None
    on_website: bool
    updated_at: datetime


class AdminTestimonials(BaseModel):
    items: list[AdminTestimonial]
    can_act: bool


class TestimonialIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    quote: dict[Locale, str] = Field(description="English is needed; other languages are optional")
    person_name: str = Field(min_length=1, max_length=80)
    role: str = Field(min_length=1, max_length=80)
    company_name: str = Field(min_length=1, max_length=120)
    city: str | None = Field(None, max_length=80)
    photo: str | None = Field(None, max_length=300, description="An uploaded site/people/… key")
    approved_in_writing: bool = False
    approval_note: str | None = Field(None, max_length=200, description="How and when they agreed")
    on_website: bool = False
