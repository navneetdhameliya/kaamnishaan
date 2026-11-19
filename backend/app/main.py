import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import router as v1
from app.api.v1.routes import dev, files
from app.core import errors
from app.core.config import get_settings


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    if get_settings().admin_email:
        from app.services.staff import bootstrap

        try:
            await bootstrap()  # first super admin's setup link goes to the log
        except Exception:  # never stop the API from starting
            logging.getLogger("kn.staff").exception("admin bootstrap failed")
    yield


def create_app() -> FastAPI:
    s = get_settings()
    app = FastAPI(
        lifespan=lifespan,
        title=s.api_name,
        version="0.1.0",
        docs_url=None if s.is_production else "/docs",
        redoc_url=None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=s.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    errors.install(app)
    app.include_router(v1)
    if s.storage_provider == "local":
        app.include_router(files.router, prefix="/api/v1")
    if s.outbox_enabled:  # local, tests, and a test server with KN_TEST_OUTBOX_KEY
        app.include_router(dev.router, prefix="/api/v1")
        logging.getLogger("kn").setLevel(logging.INFO)
    return app


app = create_app()
