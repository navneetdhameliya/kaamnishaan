"""Website content kept in the database: blog posts (W25/W26, A26) and testimonials (W01, A27)."""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy import text as sql
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, IdMixin, TimestampMixin
from app.models.identity import str_enum


class BlogPost(IdMixin, TimestampMixin, Base):
    __tablename__ = "blog_posts"

    slug: Mapped[str] = mapped_column(String(120), unique=True)
    category: Mapped[str] = mapped_column(String(20))
    featured: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    # published + publish_at in the future = scheduled
    status: Mapped[str] = mapped_column(
        str_enum("draft", "published", name="blog_status"), default="draft", index=True
    )
    publish_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    # a website picture ("/img/x.webp") or an uploaded one ("site/blog/<id>.webp")
    cover: Mapped[str] = mapped_column(String(300))
    # {"en": {"title", "summary", "author", "blocks": [...]}, "hi": {...}}
    content: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_by: Mapped[uuid.UUID | None] = mapped_column()
    updated_by: Mapped[uuid.UUID | None] = mapped_column()


class Testimonial(IdMixin, TimestampMixin, Base):
    __tablename__ = "testimonials"

    quote: Mapped[dict] = mapped_column(JSONB, default=dict)  # {"en": "...", "hi": "..."}
    person_name: Mapped[str] = mapped_column(String(80))
    role: Mapped[str] = mapped_column(String(80))
    company_name: Mapped[str] = mapped_column(String(120))
    city: Mapped[str | None] = mapped_column(String(80))
    photo: Mapped[str | None] = mapped_column(String(300))  # "site/people/<id>.jpg"
    # shown on the website only when the customer agreed in writing (and staff switched it on)
    approved_in_writing: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    approval_note: Mapped[str | None] = mapped_column(String(200))
    on_website: Mapped[bool] = mapped_column(Boolean, default=False, server_default=sql("false"))
    created_by: Mapped[uuid.UUID | None] = mapped_column()
