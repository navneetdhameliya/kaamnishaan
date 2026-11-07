"""Home screens and the offline sync feed."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.jobs import member
from app.core.deps import Principal, get_db
from app.schemas.work import Dashboard, MeStats, SyncChanges, Today
from app.services import home

router = APIRouter()


@router.get("/dashboard", response_model=Dashboard, tags=["home"])
async def dashboard(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> Dashboard:
    return await home.dashboard(db, p)


@router.get("/me/today", response_model=Today, tags=["home"])
async def today(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> Today:
    return await home.today(db, p)


@router.get("/me/stats", response_model=MeStats, tags=["home"])
async def me_stats(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> MeStats:
    return await home.stats(db, p)


@router.get("/sync/changes", response_model=SyncChanges, tags=["sync"])
async def sync_changes(
    since: str | None = None, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> SyncChanges:
    return await home.sync_changes(db, p, since)
