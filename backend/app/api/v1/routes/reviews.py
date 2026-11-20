"""Customer reviews: ask (M31, M15), cancel while waiting, My reviews (M44), one review, and the office
side: all reviews with replies and follow-ups (M45), where each request stands, settings (M46) and the
reminder sender."""

import hmac
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Header, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import Principal, get_db
from app.core.errors import Forbidden
from app.schemas.reviews import (
    FollowupIn,
    FollowupOut,
    JobReview,
    MyReviews,
    ReplyIn,
    ReplyOut,
    RequestsPage,
    ReviewOut,
    ReviewSettingsIn,
    ReviewSettingsOut,
    ReviewsPage,
    SuggestionOut,
)
from app.services import ai_calls, review_office, reviews
from app.services.jobs import get_job

from .jobs import member

router = APIRouter(tags=["reviews"])


@router.post("/jobs/{job_id}/review-request", response_model=JobReview, status_code=201)
async def ask(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> JobReview:
    """Ask the customer for a review: sent with the approved report, or now if already approved."""
    return await reviews.request_review(db, p, await get_job(db, p, job_id, lock=True))


@router.delete("/review-requests/{request_id}", status_code=204)
async def cancel(
    request_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    """Cancel a request that is still waiting for approval."""
    await reviews.cancel(db, p, request_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me/reviews", response_model=MyReviews)
async def mine(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> MyReviews:
    return await reviews.my_reviews(db, p)


@router.get("/reviews", response_model=ReviewsPage)
async def company_reviews(
    filter: Literal["all", "needs_reply", "low"] = "all",
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ReviewsPage:
    """M45 Reviews: the average, the star breakdown, the counts for each chip and the reviews."""
    return await review_office.reviews_page(db, p, filter)


@router.get("/review-requests", response_model=RequestsPage)
async def requests(
    status: Literal["waiting", "rated", "opted_out"] = "waiting",
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> RequestsPage:
    """M45 Review requests: where each ask stands and what happens next."""
    return await review_office.requests_page(db, p, status)


@router.get("/review-settings", response_model=ReviewSettingsOut)
async def get_settings_(
    p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReviewSettingsOut:
    return await review_office.get_settings(db, p)


@router.patch("/review-settings", response_model=ReviewSettingsOut)
async def patch_settings(
    body: ReviewSettingsIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReviewSettingsOut:
    """M46 Review settings and follow-ups. Send only what changed."""
    return await review_office.update_settings(db, p, body)


@router.post("/reviews/{review_id}/reply", response_model=ReplyOut)
async def reply(
    review_id: uuid.UUID, body: ReplyIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReplyOut:
    """M45 Send reply: shown on the customer's report page and to the technician. Sending again edits it."""
    return await review_office.reply(db, p, review_id, body.text)


@router.post("/reviews/{review_id}/reply-suggestion", response_model=SuggestionOut)
async def suggestion(
    review_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> SuggestionOut:
    """M45 "Suggest a reply": a short reply to start from, in the app language."""
    return await review_office.suggest(db, p, review_id, p.user.app_language)


@router.patch("/reviews/{review_id}/follow-up", response_model=FollowupOut)
async def follow_up(
    review_id: uuid.UUID, body: FollowupIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> FollowupOut:
    """M45 Low rating: the private note and "Mark as resolved"."""
    return await review_office.followup(db, p, review_id, body)


def _cron(x_cron_key: str | None = Header(default=None)) -> None:
    key = get_settings().cron_key
    if not key or not hmac.compare_digest(x_cron_key or "", key.get_secret_value()):
        raise Forbidden("forbidden", "The cron key is missing or wrong.")


@router.post("/cron/review-followups", dependencies=[Depends(_cron)])
async def run_followups(db: AsyncSession = Depends(get_db)) -> dict:
    """Send every Day 2 review reminder, run every Day 5 AI call and send every announcement that is due
    (all companies). For a scheduler, with X-Cron-Key."""
    from app.services import admin_support

    reminders = await review_office.send_due(db)
    calls = await ai_calls.call_due(db)
    # A29 scheduled announcements ride on the same scheduler
    return {
        "reminders_sent": reminders,
        "calls_handled": calls,
        "announcements_sent": await admin_support.send_due(db),
    }


@router.get("/reviews/{review_id}", response_model=ReviewOut)
async def one(
    review_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReviewOut:
    return await reviews.get_review(db, p, review_id)
