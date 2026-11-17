"""Customer reviews: ask (M31, M15), cancel while waiting, My reviews (M44) and one review."""

import uuid

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db
from app.schemas.reviews import JobReview, MyReviews, ReviewOut
from app.services import reviews
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


@router.get("/reviews/{review_id}", response_model=ReviewOut)
async def one(
    review_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ReviewOut:
    return await reviews.get_review(db, p, review_id)
