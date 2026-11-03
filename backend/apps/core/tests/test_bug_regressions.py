"""Regression tests for QA run 1 bugs in the core/settings layer: BUG-0001 (oversized body),
BUG-0005 (SMS backend in deployed environments), and the test-only idle-in-transaction
timeout on the shared database server."""

import importlib
import logging
import sys

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured, TooManyFieldsSent
from django.db import connection

from apps.notifications import sms

pytestmark = pytest.mark.django_db

CONSOLE = "apps.notifications.sms.ConsoleSmsBackend"
LOCMEM = "apps.notifications.sms.LocmemSmsBackend"
UNCONFIGURED = "apps.notifications.sms.UnconfiguredSmsBackend"


# --------------------------------------------------------------------------- BUG-0001


class TestOversizedBody:
    def test_body_over_the_limit_is_413_not_500(self, api_client, settings, caplog):
        """BUG-0001 (P0-TC-08b): a body over DATA_UPLOAD_MAX_MEMORY_SIZE is a client error."""
        settings.DATA_UPLOAD_MAX_MEMORY_SIZE = 1024
        body = {"phone": "+919999900099", "app": "customer", "pad": "x" * 4096}
        with caplog.at_level(logging.WARNING):
            response = api_client.post("/api/v1/auth/otp/verify/", body, format="json")
        assert response.status_code == 413
        assert response.json() == {
            "error": {
                "code": "PAYLOAD_TOO_LARGE",
                "message": "The request body is too large.",
                "details": {},
            }
        }
        assert not [r for r in caplog.records if r.levelno >= logging.ERROR]

    def test_other_suspicious_operations_are_400(self):
        from apps.core.exceptions import exception_handler

        response = exception_handler(TooManyFieldsSent("too many"), {})
        assert response.status_code == 400
        assert response.data["error"]["code"] == "VALIDATION_ERROR"

    def test_default_limit_applies_to_the_api(self, api_client):
        """The real default (2.5 MB), as QA reproduced it."""
        body = {"phone": "+919999900099", "app": "customer", "pad": "x" * 3_000_000}
        response = api_client.post("/api/v1/auth/otp/verify/", body, format="json")
        assert response.status_code == 413


# --------------------------------------------------------------------------- BUG-0005


def _sms_errors() -> set[str]:
    return {e.id for e in run_checks() if e.id == "accounts.E003"}


class TestSmsBackendInDeployedEnvironments:
    @pytest.mark.parametrize("backend", [CONSOLE, LOCMEM])
    def test_production_refuses_non_delivering_backends(self, settings, backend):
        """BUG-0005: production never logs OTPs through the console backend."""
        settings.APP_ENVIRONMENT = "production"
        settings.OTP_TEST_NUMBERS = {}
        settings.SMS_BACKEND = backend
        settings.SMS_CONSOLE_BACKEND_ALLOWED = True  # the staging opt-in never applies here
        assert _sms_errors() == {"accounts.E003"}

    def test_staging_needs_the_explicit_opt_in(self, settings):
        settings.APP_ENVIRONMENT = "staging"
        settings.SMS_BACKEND = CONSOLE
        settings.SMS_CONSOLE_BACKEND_ALLOWED = False
        assert _sms_errors() == {"accounts.E003"}
        settings.SMS_CONSOLE_BACKEND_ALLOWED = True
        assert _sms_errors() == set()

    @pytest.mark.parametrize("environment", ["local", "test"])
    def test_local_and_test_keep_the_console_backend(self, settings, environment):
        settings.APP_ENVIRONMENT = environment
        settings.SMS_BACKEND = CONSOLE
        assert _sms_errors() == set()

    def test_unconfigured_gateway_is_allowed_but_fails_loudly(self, settings, caplog):
        settings.APP_ENVIRONMENT = "production"
        settings.OTP_TEST_NUMBERS = {}
        settings.SMS_BACKEND = UNCONFIGURED
        assert _sms_errors() == set()
        with pytest.raises(ImproperlyConfigured) as caught:
            sms.send_sms("+919876543210", "<#> 123456 is your code", "1007")
        assert "123456" not in str(caught.value)
        assert "+919876543210" not in str(caught.value)

    def test_deployed_settings_default_to_the_unconfigured_backend(self, monkeypatch):
        """BUG-0005: no SMS_BACKEND in the environment never means the console backend."""
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
        monkeypatch.setenv("NUM_PROXIES", "1")
        monkeypatch.delenv("SMS_BACKEND", raising=False)
        monkeypatch.delenv("OTP_TEST_NUMBERS", raising=False)
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        for name in ("config.settings.production", "config.settings.deployed"):
            sys.modules.pop(name, None)
        try:
            production = importlib.import_module("config.settings.production")
        finally:
            for name in ("config.settings.production", "config.settings.deployed"):
                sys.modules.pop(name, None)
        assert production.SMS_BACKEND == UNCONFIGURED
        assert production.SMS_CONSOLE_BACKEND_ALLOWED is False
        assert production.SESSION_COOKIE_AGE == 8 * 3600
        assert production.STAFF_SESSION_MAX_AGE_SECONDS == 8 * 3600


# --------------------------------------------------------------------------- shared DB hygiene


def test_test_database_ends_idle_transactions():
    """Test settings only: an interrupted run can't leave lock-holding sessions behind."""
    with connection.cursor() as cursor:
        cursor.execute("SHOW idle_in_transaction_session_timeout")
        assert cursor.fetchone()[0] == "5min"


def test_application_settings_do_not_set_the_timeout():
    from config.settings import base

    assert "options" not in base.DATABASES["default"]["OPTIONS"]
