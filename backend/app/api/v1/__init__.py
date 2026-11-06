from fastapi import APIRouter

from app.api.v1.routes import auth, company, content, health, me

router = APIRouter(prefix="/v1")
for r in (health, auth, me, company, content):
    router.include_router(r.router)
