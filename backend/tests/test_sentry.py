import sentry_sdk

from config.sentry import init_sentry


def test_noop_without_dsn(monkeypatch):
    monkeypatch.delenv("SENTRY_DSN", raising=False)
    assert init_sentry() is False


def test_environment_defaults_to_settings_module(monkeypatch):
    captured = {}
    monkeypatch.setattr(sentry_sdk, "init", lambda **kwargs: captured.update(kwargs))
    monkeypatch.setenv("SENTRY_DSN", "https://key@sentry.example/1")
    monkeypatch.setenv("DJANGO_SETTINGS_MODULE", "config.settings.staging")
    monkeypatch.delenv("SENTRY_ENVIRONMENT", raising=False)
    assert init_sentry() is True
    assert captured["environment"] == "staging"
    assert captured["send_default_pii"] is False
    assert captured["include_local_variables"] is False  # never the DB conninfo
    assert captured["traces_sample_rate"] == 0.0
