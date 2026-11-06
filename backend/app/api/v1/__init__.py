from fastapi import APIRouter

from app.api.v1.routes import auth, company, customers, health, home, jobs, me, public

router = APIRouter(prefix="/api/v1")
for r in (health, public, auth, me, home, company, customers, jobs):
    router.include_router(r.router)
