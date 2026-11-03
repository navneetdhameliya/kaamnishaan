from httpx import ASGITransport, AsyncClient

from app.main import create_app


async def test_health_ok() -> None:
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://t") as c:
        r = await c.get("/v1/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["version"] == "0.1.0"


async def test_docs_hidden_in_production(monkeypatch) -> None:
    from app.core import config

    monkeypatch.setenv("KN_ENV", "production")
    config.get_settings.cache_clear()
    try:
        async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://t") as c:
            assert (await c.get("/docs")).status_code == 404
    finally:
        monkeypatch.delenv("KN_ENV")
        config.get_settings.cache_clear()
