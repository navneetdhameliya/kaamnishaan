"""Background tasks.

With KN_REDIS_URL set (staging, production) tasks go to the ARQ worker (`arq app.worker.WorkerSettings`).
Without it (your computer) they run inside the API process right after the response; in tests they run
straight away so results can be checked.

Always enqueue after the database commit, so the worker can see the new rows.
"""

import asyncio
import logging
from collections.abc import Awaitable, Callable

from app.core.config import get_settings

log = logging.getLogger("kn.tasks")
Task = Callable[..., Awaitable[object]]
REGISTRY: dict[str, Task] = {}
_pool = None
_running: set[asyncio.Task] = set()


def task(fn: Task) -> Task:
    REGISTRY[fn.__name__] = fn
    return fn


async def enqueue(name: str, **kwargs) -> None:
    s = get_settings()
    fn = REGISTRY[name]
    if s.env == "test":
        await fn({}, **kwargs)
        return
    if s.redis_url:
        global _pool
        if _pool is None:
            from arq import create_pool
            from arq.connections import RedisSettings

            _pool = await create_pool(RedisSettings.from_dsn(s.redis_url))
        await _pool.enqueue_job(name, **kwargs)
        return

    async def _run() -> None:
        try:
            await fn({}, **kwargs)
        except Exception:  # noqa: BLE001 - logged, never crashes the API
            log.exception("task %s failed", name)

    t = asyncio.create_task(_run())
    _running.add(t)
    t.add_done_callback(_running.discard)


# register task modules
from app.tasks import photos  # noqa: E402,F401
