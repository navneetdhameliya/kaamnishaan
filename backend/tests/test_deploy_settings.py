"""Settings for the live test server (Render, staging) and the protected test outbox."""

import pytest
from pydantic import ValidationError

from app.api.v1.routes import dev
from app.core.config import Settings
from app.core.errors import Forbidden

R2 = {
    "storage_provider": "r2",
    "storage_endpoint": "https://acct.r2.cloudflarestorage.com",
    "storage_access_key": "a",
    "storage_secret_key": "b",
}
STRONG = "x" * 44


def staging(**kw) -> Settings:
    return Settings(env="staging", secret_key=STRONG, _env_file=None, **R2, **kw)


def test_render_database_url_gets_the_async_driver():
    s = staging(database_url="postgresql://u:p@dpg-x.singapore-postgres.render.com/kaamnishaan")
    assert s.database_url.startswith("postgresql+asyncpg://u:p@dpg-x")


def test_staging_needs_a_strong_secret_and_r2():
    with pytest.raises(ValidationError, match="KN_SECRET_KEY"):
        Settings(env="staging", secret_key="short", _env_file=None, **R2)
    with pytest.raises(ValidationError, match="r2"):
        Settings(env="staging", secret_key=STRONG, _env_file=None)
    with pytest.raises(ValidationError, match="R2 needs"):
        Settings(env="staging", secret_key=STRONG, storage_provider="r2", _env_file=None)


def test_outbox_only_with_a_key_and_never_in_production():
    assert not staging().outbox_enabled
    assert staging(test_outbox_key="k" * 32).outbox_enabled
    with pytest.raises(ValidationError, match="production"):
        Settings(env="production", secret_key=STRONG, test_outbox_key="k" * 32, _env_file=None, **R2)


def test_outbox_key_is_checked_on_the_test_server(monkeypatch):
    s = staging(test_outbox_key="right-key-" * 4)
    monkeypatch.setattr(dev, "get_settings", lambda: s)
    with pytest.raises(Forbidden):
        dev._key(x_outbox_key=None, key=None)
    with pytest.raises(Forbidden):
        dev._key(x_outbox_key="wrong", key=None)
    dev._key(x_outbox_key="right-key-" * 4, key=None)
    dev._key(x_outbox_key=None, key="right-key-" * 4)
