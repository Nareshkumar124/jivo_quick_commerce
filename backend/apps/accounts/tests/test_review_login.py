"""Store-reviewer phone logins (D-15, owner-approved 2026-11-28): settings.STORE_REVIEW_LOGINS."""

import importlib
import logging
import sys

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.models import OTPRequest, User
from apps.accounts.services.otp import hash_code
from apps.accounts.tasks import send_otp_sms
from apps.accounts.tests.factories import UserFactory
from apps.notifications import sms

pytestmark = pytest.mark.django_db

REQUEST = "/api/v1/auth/otp/request/"
VERIFY = "/api/v1/auth/otp/verify/"
DELETE = "/api/v1/me/delete/"
REVIEWER = "+919999900001"
CODE = "482913"
OTHER = "+919876543210"


@pytest.fixture
def production_like(settings):
    """Production's OTP setup: no fixed-OTP test numbers, SMS backend unconfigured (any send
    would fail loudly), one reviewer login."""
    settings.APP_ENVIRONMENT = "production"
    settings.OTP_TEST_NUMBERS = {}
    settings.SMS_BACKEND = "apps.notifications.sms.UnconfiguredSmsBackend"
    settings.STORE_REVIEW_LOGINS = {REVIEWER: CODE}
    return settings


def request(client, phone=REVIEWER, app="customer", purpose=None):
    body = {"phone": phone, "app": app}
    if purpose:
        body["purpose"] = purpose
    return client.post(REQUEST, body, format="json")


def verify(client, code, phone=REVIEWER, app="customer"):
    return client.post(
        VERIFY,
        {"phone": phone, "otp": code, "app": app, "terms_version": "2026-11-01"},
        format="json",
    )


def test_off_by_default(settings):
    assert settings.STORE_REVIEW_LOGINS == {}


@pytest.mark.parametrize("app", ["customer", "rider"])
def test_reviewer_logs_in_without_sms(
    production_like, api_client, app, django_capture_on_commit_callbacks, caplog, monkeypatch
):
    caplog.set_level(logging.INFO, logger="apps.accounts.review_login")
    queued = []
    monkeypatch.setattr(send_otp_sms, "delay", lambda *args: queued.append(args))
    with django_capture_on_commit_callbacks(execute=True):
        assert request(api_client, app=app).status_code == 200
    assert queued == []  # no SMS task queued
    assert sms.outbox == []
    otp = OTPRequest.objects.get(phone=REVIEWER)
    assert otp.code_hash == hash_code(REVIEWER, app, "login", CODE)
    assert otp.sms_sent_at is None

    response = verify(api_client, CODE, app=app)
    assert response.status_code == 200, response.content
    assert AccessToken(response.json()["access"])["app"] == app
    assert User.objects.filter(phone=REVIEWER).exists()

    lines = [r.getMessage() for r in caplog.records]
    assert any("request" in line and f"app={app}" in line for line in lines)
    assert any("verify" in line and "outcome=ok" in line for line in lines)
    assert all(CODE not in line and REVIEWER not in line for line in lines)  # masked, no code


def test_wrong_code_fails_and_counts_attempts(production_like, api_client, caplog):
    caplog.set_level(logging.INFO, logger="apps.accounts.review_login")
    request(api_client)
    response = verify(api_client, "111111")
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "OTP_INVALID"
    assert OTPRequest.objects.get(phone=REVIEWER).attempts == 1
    assert any("outcome=failed" in r.getMessage() for r in caplog.records)


def test_unlisted_number_still_gets_an_sms_code(
    production_like, api_client, django_capture_on_commit_callbacks
):
    production_like.SMS_BACKEND = "apps.notifications.sms.LocmemSmsBackend"
    with django_capture_on_commit_callbacks(execute=True):
        request(api_client, phone=OTHER)
    assert sms.outbox[-1].to == OTHER
    response = verify(api_client, CODE, phone=OTHER)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "OTP_INVALID"


def test_send_rate_limits_still_apply(production_like, api_client):
    for _ in range(3):
        assert request(api_client).status_code == 200
    response = request(api_client)
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "OTP_RATE_LIMITED"


def test_verify_ip_limit_still_applies(production_like, api_client):
    production_like.OTP_VERIFY_LIMIT_PER_IP_PER_HOUR = 1
    request(api_client)
    verify(api_client, "111111")
    assert verify(api_client, CODE).status_code == 429


def test_delete_account_purpose(production_like, make_auth_client):
    reviewer = UserFactory(phone=REVIEWER)
    assert request(APIClient(), purpose="delete_account").status_code == 200
    assert sms.outbox == []
    response = make_auth_client(reviewer).post(DELETE, {"otp": CODE}, format="json")
    assert response.status_code == 200, response.content
    reviewer.refresh_from_db()
    assert reviewer.deleted_at is not None


class TestChecks:
    def ids(self):
        return {e.id for e in run_checks() if e.id == "accounts.E008"}

    def test_valid_entries_pass(self, settings):
        settings.STORE_REVIEW_LOGINS = {REVIEWER: CODE, "+919999900002": "615204"}
        assert self.ids() == set()

    @pytest.mark.parametrize(
        ("phone", "code"),
        [
            ("9999900001", CODE),  # no +91
            (REVIEWER, "48291"),  # 5 digits
            (REVIEWER, "48291a"),
            (REVIEWER, "123456"),
            (REVIEWER, "654321"),
            (REVIEWER, "012345"),
            (REVIEWER, "000000"),
            (REVIEWER, "999999"),
            ("+919000000001", CODE),  # also an OTP_TEST_NUMBERS entry (test settings)
        ],
    )
    def test_bad_entries_rejected(self, settings, phone, code):
        settings.STORE_REVIEW_LOGINS = {phone: code}
        assert self.ids() == {"accounts.E008"}


class TestProductionSettings:
    @pytest.fixture
    def deploy_env(self, monkeypatch):
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.com")
        monkeypatch.setenv("NUM_PROXIES", "1")
        monkeypatch.setenv("STORE_REVIEW_LOGINS", f"{REVIEWER}:{CODE}")
        monkeypatch.delenv("OTP_TEST_NUMBERS", raising=False)
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        base = sys.modules["config.settings.base"]
        yield monkeypatch
        for name in ("production", "deployed"):
            sys.modules.pop(f"config.settings.{name}", None)
        sys.modules["config.settings.base"] = base  # the module the running settings came from

    def _load(self):
        # base reads STORE_REVIEW_LOGINS from the environment, so it is re-imported too.
        for name in ("production", "deployed", "base"):
            sys.modules.pop(f"config.settings.{name}", None)
        return importlib.import_module("config.settings.production")

    def test_production_allows_review_logins(self, deploy_env):
        production = self._load()
        assert production.STORE_REVIEW_LOGINS == {REVIEWER: CODE}
        assert production.OTP_TEST_NUMBERS == {}

    def test_production_still_refuses_test_numbers(self, deploy_env):
        deploy_env.setenv("OTP_TEST_NUMBERS", "+919000000001:123456")
        with pytest.raises(ImproperlyConfigured, match="OTP_TEST_NUMBERS"):
            self._load()
