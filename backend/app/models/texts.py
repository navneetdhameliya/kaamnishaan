"""Text changes made in the admin panel (A24 Website content, A25 Localized content).

The built-in texts live in shared/i18n and ship with the app, website and admin panel. A row here
changes one text in one language without a new release: `live` is what people see (null = the
built-in text), `draft` is a website change waiting for Publish (A24). `reviewed_at` marks that a
person checked this language's text (A25).
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy import text as sql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class TextOverride(Base):
    __tablename__ = "text_overrides"

    key: Mapped[str] = mapped_column(String(160), primary_key=True)
    lang: Mapped[str] = mapped_column(String(2), primary_key=True)
    live: Mapped[str | None] = mapped_column(Text)
    # A24: a change saved but not published yet; draft=None with has_draft means "back to built-in".
    has_draft: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    draft: Mapped[str | None] = mapped_column(Text)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column()
    updated_by: Mapped[uuid.UUID | None] = mapped_column()
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=sql("now()"))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
