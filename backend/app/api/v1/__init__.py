from fastapi import APIRouter

from app.api.v1.routes import auth, company, health, me, public

router = APIRouter(prefix="/api/v1")
for r in (health, public, auth, me, company):
    router.include_router(r.router)
