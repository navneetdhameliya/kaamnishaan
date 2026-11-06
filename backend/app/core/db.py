from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import get_settings

_s = get_settings()
# tests open a new event loop per test, so they must not share pooled connections
engine = (
    create_async_engine(_s.database_url, poolclass=NullPool)
    if _s.env == "test"
    else create_async_engine(_s.database_url, pool_pre_ping=True)
)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
