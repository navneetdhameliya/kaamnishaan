"""Website blog (W25 list, W26 article) and the newsletter sign-up."""

from datetime import date
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

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
