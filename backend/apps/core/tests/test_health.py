"""/health/live and /health/ready (09 §2). Ready checks the real database and Redis."""

import logging

import pytest
from django.db import OperationalError, connection

from apps.core import views


def test_live_returns_ok_without_dependencies(api_client):
    response = api_client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert "no-cache" in response["Cache-Control"]


@pytest.mark.django_db
def test_ready_checks_real_database_and_redis(api_client):
    response = api_client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "checks": {"database": "ok", "redis": "ok"}}
    assert "no-cache" in response["Cache-Control"]


@pytest.mark.django_db
def test_probes_ignore_credentials(api_client):
    api_client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
    assert api_client.get("/health/live").status_code == 200
    assert api_client.get("/health/ready").status_code == 200


@pytest.mark.django_db
def test_ready_returns_503_envelope_when_redis_is_down(api_client, settings, caplog):
    settings.REDIS_URL = "redis://localhost:1/0"  # nothing listens on port 1
    with caplog.at_level(logging.ERROR, logger="apps.core.views"):
        response = api_client.get("/health/ready")
    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "SERVICE_UNAVAILABLE",
            "message": "Service is not ready.",
            "details": {"checks": {"database": "ok", "redis": "error"}},
        }
    }
    assert "Readiness check failed: redis" in caplog.text


def test_ready_returns_503_when_database_is_down(api_client, monkeypatch):
    monkeypatch.setattr(views, "check_database", lambda: False)
    response = api_client.get("/health/ready")
    assert response.status_code == 503
    assert response.json()["error"]["details"] == {"checks": {"database": "error", "redis": "ok"}}


@pytest.mark.django_db
def test_check_database_logs_and_hides_driver_errors(monkeypatch, caplog):
    def broken_cursor(*args, **kwargs):
        raise OperationalError("connection to server at 'db.internal' failed")

    monkeypatch.setattr(connection, "cursor", broken_cursor)
    with caplog.at_level(logging.ERROR, logger="apps.core.views"):
        assert views.check_database() is False
    assert "Readiness check failed: database" in caplog.text


def test_live_rejects_other_methods(api_client):
    response = api_client.post("/health/live")
    assert response.status_code == 405
    assert response.json()["error"]["code"] == "METHOD_NOT_ALLOWED"
