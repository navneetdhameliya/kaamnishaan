from fastapi import APIRouter

from app.api.v1.routes import (
    auth,
    checklists,
    company,
    customers,
    evidence,
    health,
    home,
    jobs,
    me,
    public,
    reports,
    voice,
)

router = APIRouter(prefix="/api/v1")
for r in (health, public, auth, me, home, company, customers, jobs, evidence, checklists, voice, reports):
    router.include_router(r.router)
