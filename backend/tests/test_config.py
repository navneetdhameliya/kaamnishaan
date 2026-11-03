from app.core.config import Settings


def test_render_postgres_url_uses_asyncpg() -> None:
    s = Settings(database_url="postgres://u:p@host:5432/db")
    assert s.database_url == "postgresql+asyncpg://u:p@host:5432/db"


def test_india_defaults() -> None:
    s = Settings()
    assert (s.default_country, s.default_timezone) == ("IN", "Asia/Kolkata")
    assert s.supported_locales == ["en", "hi", "gu", "es", "fr"]
