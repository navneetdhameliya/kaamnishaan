import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import router as v1
from app.api.v1.routes import dev, files
from app.core import errors
from app.core.config import get_settings


def create_app() -> FastAPI:
    s = get_settings()
    app = FastAPI(
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
    if s.env in ("local", "test"):
        app.include_router(dev.router, prefix="/api/v1")
        logging.getLogger("kn").setLevel(logging.INFO)
    return app


app = create_app()
