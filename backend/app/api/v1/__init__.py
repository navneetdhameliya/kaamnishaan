from fastapi import APIRouter

from app.api.v1.routes import (
    auth,
    billing,
    checklists,
    company,
    customers,
    evidence,
    health,
    home,
    jobs,
    me,
    notifications,
    public,
    public_reports,
    reports,
    reviews,
    voice,
)

router = APIRouter(prefix="/api/v1")
for r in (
    health,
    public,
    public_reports,
    auth,
    me,
    home,
    company,
    customers,
    jobs,
    evidence,
    checklists,
    voice,
    reports,
    reviews,
    billing,
    notifications,
):
    router.include_router(r.router)
