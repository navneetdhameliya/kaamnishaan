"""No-login blog for the website: W25 list, W26 article, newsletter sign-up."""

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import client_ip, get_db
from app.schemas.blog import BlogCategory, BlogListOut, BlogPostOut, NewsletterIn, NewsletterOut
from app.schemas.identity import Locale
from app.services import blog, leads

router = APIRouter(prefix="/public", tags=["website"])
CACHE = "public, max-age=300"


@router.get("/blog", response_model=BlogListOut)
async def blog_list(
    response: Response, locale: Locale = "en", category: BlogCategory | None = None
) -> BlogListOut:
    response.headers["Cache-Control"] = CACHE
    return blog.list_posts(locale, category)


@router.get("/blog/{slug}", response_model=BlogPostOut)
async def blog_post(slug: str, response: Response, locale: Locale = "en") -> BlogPostOut:
    response.headers["Cache-Control"] = CACHE
    return blog.get_post(slug, locale)


@router.post("/newsletter", response_model=NewsletterOut, status_code=status.HTTP_201_CREATED)
async def newsletter(
    body: NewsletterIn, request: Request, db: AsyncSession = Depends(get_db)
) -> NewsletterOut:
    return await leads.newsletter(db, body, client_ip(request))
