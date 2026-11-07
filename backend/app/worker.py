"""ARQ background worker. Run with:  arq app.worker.WorkerSettings  (needs KN_REDIS_URL)."""

from arq.connections import RedisSettings

from app.core.config import get_settings
from app.tasks import REGISTRY


class WorkerSettings:
    functions = list(REGISTRY.values())
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url or "redis://localhost:6379")
    max_jobs = 10
    job_timeout = 300
