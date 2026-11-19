"""Website legal pages: Privacy policy (W06) and Terms (W07)."""

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.identity import Locale

LegalDoc = Literal["privacy", "terms"]


class LegalBlock(BaseModel):
    type: Literal["p", "list"]
    text: str | None = None
    items: list[str] = []


class LegalSection(BaseModel):
    id: str
    heading: str
    blocks: list[LegalBlock]


class LegalOut(BaseModel):
    doc: LegalDoc
    title: str
    intro: str
    updated_on: date
    read_minutes: int
    language: Locale
    complete: bool = Field(description="false (a draft) while the legal name, address or city is not set")
    sections: list[LegalSection]
