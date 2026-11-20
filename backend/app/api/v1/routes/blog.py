"""No-login website content: W25 blog list, W26 article, W01 testimonials, newsletter sign-up, and the
pictures staff uploaded for them."""

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import client_ip, get_db
from app.core.errors import NotFound
from app.providers.storage import get_storage
from app.schemas.blog import BlogCategory, BlogListOut, BlogPostOut, NewsletterIn, NewsletterOut
from app.schemas.identity import Locale
from app.schemas.testimonials import PublicTestimonials
from app.services import blog, leads, media, testimonials

router = APIRouter(prefix="/public", tags=["website"])
CACHE = "public, max-age=300"


@router.get("/blog", response_model=BlogListOut)
async def blog_list(
    response: Response,
    locale: Locale = "en",
    category: BlogCategory | None = None,
    db: AsyncSession = Depends(get_db),
) -> BlogListOut:
    response.headers["Cache-Control"] = CACHE
    return await blog.list_posts(db, locale, category)


@router.get("/blog/{slug}", response_model=BlogPostOut)
async def blog_post(
    slug: str, response: Response, locale: Locale = "en", db: AsyncSession = Depends(get_db)
) -> BlogPostOut:
    response.headers["Cache-Control"] = CACHE
    return await blog.get_post(db, slug, locale)


@router.get("/testimonials", response_model=PublicTestimonials)
async def public_testimonials(
    response: Response, locale: Locale = "en", db: AsyncSession = Depends(get_db)
) -> PublicTestimonials:
    """Quotes customers approved in writing, for the website's Home (W01). Empty = hide the section."""
    response.headers["Cache-Control"] = CACHE
    return await testimonials.public(db, locale)


@router.get("/media/{key:path}", status_code=status.HTTP_302_FOUND, response_class=RedirectResponse)
async def public_media(key: str) -> RedirectResponse:
    """A picture staff uploaded for the website (blog, testimonials); redirects to the file."""
    if not media.is_key(key):
        raise NotFound("not_found", "Picture not found.")
    return RedirectResponse(
        get_storage().presign_get(key), status_code=302, headers={"Cache-Control": "public, max-age=600"}
    )


@router.post("/newsletter", response_model=NewsletterOut, status_code=status.HTTP_201_CREATED)
async def newsletter(
    body: NewsletterIn, request: Request, db: AsyncSession = Depends(get_db)
) -> NewsletterOut:
    return await leads.newsletter(db, body, client_ip(request))
