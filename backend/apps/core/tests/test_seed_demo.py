import pytest
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


CALLS: list[str] = []


def fake_step(stdout, options) -> None:
    CALLS.append("ran")
