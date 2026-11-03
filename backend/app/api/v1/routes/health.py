from fastapi import APIRouter
from pydantic import BaseModel

from app.core.config import get_settings

router = APIRouter(tags=["system"])


class Health(BaseModel):
    status: str
    env: str
    version: str


@router.get("/health", response_model=Health)
async def health() -> Health:
    return Health(status="ok", env=get_settings().env, version="0.1.0")
