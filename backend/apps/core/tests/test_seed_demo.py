import importlib
import sys

import pytest
from django.core.exceptions import ImproperlyConfigured
from django.core.management import CommandError, call_command

from apps.core.management.commands import seed_demo


@pytest.mark.django_db
def test_seed_demo_runs_every_phase_step(capsys):
    call_command("seed_demo")
    call_command("seed_demo")
    out = capsys.readouterr().out
    assert out.count("seed_demo: done.") == 2
    for step in seed_demo.SEED_STEPS:
        assert step.rsplit(".", 1)[-1] in out


@pytest.mark.django_db
def test_seed_demo_without_steps(monkeypatch, capsys):
    monkeypatch.setattr(seed_demo, "SEED_STEPS", [])
    call_command("seed_demo")
    assert "nothing to seed yet" in capsys.readouterr().out


@pytest.mark.django_db
def test_seed_demo_runs_registered_steps(monkeypatch, capsys):
    calls = []
    monkeypatch.setattr(seed_demo, "SEED_STEPS", ["apps.core.tests.test_seed_demo.fake_step"])
    monkeypatch.setattr("apps.core.tests.test_seed_demo.CALLS", calls)
    call_command("seed_demo")
    assert calls == ["ran"]
    assert "fake_step" in capsys.readouterr().out


def test_seed_demo_is_refused_when_disabled(settings):
    settings.SEED_DEMO_ALLOWED = False
    with pytest.raises(CommandError, match="disabled"):
        call_command("seed_demo")


PRODUCTION_MODULES = ("config.settings.production", "config.settings.deployed")


def _import_fresh(name: str):
    for module in PRODUCTION_MODULES:
        sys.modules.pop(module, None)
    return importlib.import_module(name)


def test_production_settings_refuse_the_seed_demo_flag(monkeypatch):
    """Security audit m8: SEED_DEMO_ALLOWED=true stops production from starting (seed_demo and
    simulate_rider could otherwise create demo staff and fixed-OTP data there). Unset, it is
    False; staging keeps its own default (true)."""
    monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
    monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
    monkeypatch.setenv("NUM_PROXIES", "1")
    for name in ("OTP_TEST_NUMBERS", "LOADTEST_DATA_ALLOWED", "SENTRY_DSN"):
        monkeypatch.delenv(name, raising=False)
    try:
        for value in ("true", "1"):
            monkeypatch.setenv("SEED_DEMO_ALLOWED", value)
            with pytest.raises(ImproperlyConfigured, match="SEED_DEMO_ALLOWED"):
                _import_fresh("config.settings.production")
        monkeypatch.setenv("SEED_DEMO_ALLOWED", "false")
        assert _import_fresh("config.settings.production").SEED_DEMO_ALLOWED is False
        monkeypatch.delenv("SEED_DEMO_ALLOWED")
        assert _import_fresh("config.settings.production").SEED_DEMO_ALLOWED is False
        staging = ("config.settings.staging", *PRODUCTION_MODULES)
        for module in staging:
            sys.modules.pop(module, None)
        assert importlib.import_module("config.settings.staging").SEED_DEMO_ALLOWED is True
    finally:
        for module in ("config.settings.staging", *PRODUCTION_MODULES):
            sys.modules.pop(module, None)


CALLS: list[str] = []


def fake_step(stdout, options) -> None:
    CALLS.append("ran")
