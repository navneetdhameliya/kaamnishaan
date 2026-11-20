"""Website blog (W25 list, W26 article, A26 Blog management) and the newsletter sign-up."""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.schemas.identity import Locale

BlogCategory = Literal[
    "hvac", "roofing", "solar", "maintenance", "pest", "cleaning", "reports", "tips", "voice"
]


class BlogBlock(BaseModel):
    """One piece of an article: a paragraph, heading, quote, checklist box or picture."""

    type: Literal["p", "h2", "quote", "list", "image"]
    text: str | None = None
    by: str | None = Field(default=None, description="who said the quote")
    title: str | None = Field(default=None, description="heading of a list box")
    items: list[str] = []
    src: str | None = Field(default=None, description="picture path on the website, e.g. /img/x.webp")
    caption: str | None = None


class BlogPostCard(BaseModel):
    slug: str
    category: BlogCategory
    title: str
    summary: str
    cover: str
    published_on: date
    read_minutes: int
    language: Locale = Field(description="language the words are in (English when the asked one is missing)")


class BlogListOut(BaseModel):
    categories: list[BlogCategory] = Field(description="categories that have posts, in display order")
    featured: BlogPostCard | None
    items: list[BlogPostCard]


class BlogPostOut(BlogPostCard):
    author: str
    featured: bool
    blocks: list[BlogBlock]
    related: list[BlogPostCard]


class NewsletterIn(BaseModel):
    email: EmailStr
    lang: Locale = "en"


class NewsletterOut(BaseModel):
    subscribed: bool = True


# ---- admin (A26 Blog management) ---------------------------------------------------------------------
BlogState = Literal["draft", "scheduled", "published"]


class BlogBlockIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    type: Literal["p", "h2", "quote", "list", "image"]
    text: str | None = Field(None, max_length=3000)
    by: str | None = Field(None, max_length=120)
    title: str | None = Field(None, max_length=160)
    items: list[str] = Field(default_factory=list, max_length=30)
    src: str | None = Field(
        None, max_length=300, description="/img/… on the website or an uploaded site/… key"
    )
    caption: str | None = Field(None, max_length=200)


class BlogContentIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    title: str = Field("", max_length=120)
    summary: str = Field("", max_length=300)
    author: str = Field("", max_length=80)
    blocks: list[BlogBlockIn] = Field(default_factory=list, max_length=80)


class BlogIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    slug: str = Field(min_length=3, max_length=120, pattern=r"^[a-z0-9]+(-[a-z0-9]+)*$")
    category: BlogCategory
    featured: bool = False
    cover: str = Field(min_length=1, max_length=300)
    content: dict[Locale, BlogContentIn]


class BlogPublishIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    at: datetime | None = Field(None, description="Empty = now; a later time schedules it")


class AdminBlogRow(BaseModel):
    id: uuid.UUID
    slug: str
    title: str
    category: BlogCategory
    cover_url: str
    author: str
    languages: list[str]
    state: BlogState
    publish_at: datetime | None
    read_minutes: int
    featured: bool
    updated_at: datetime


class AdminBlogList(BaseModel):
    items: list[AdminBlogRow]
    counts: dict[str, int] = Field(description="all, published, scheduled, draft")
    categories: list[BlogCategory]
    can_act: bool


class AdminBlogContent(BaseModel):
    title: str
    summary: str
    author: str
    blocks: list[BlogBlock]


class AdminBlogDetail(BaseModel):
    id: uuid.UUID
    slug: str
    category: BlogCategory
    featured: bool
    state: BlogState
    publish_at: datetime | None
    cover: str
    cover_url: str
    content: dict[str, AdminBlogContent]
    web_url: str = Field(description="The article on the website")
    site_url: str = Field(description="The website's address, for pictures saved as /img/…")
    updated_at: datetime
    updated_by: str | None
    can_act: bool


class MediaOut(BaseModel):
    key: str = Field(description="Save this in the post or testimonial")
    url: str = Field(description="Where the picture can be seen")
