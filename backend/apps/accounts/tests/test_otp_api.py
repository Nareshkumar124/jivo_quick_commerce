"""OTP request and verify (06 §2.1, 09 §3.1, D-15)."""

from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.models import OTPRequest, User
from apps.accounts.services.otp import hash_code
from apps.accounts.tests.factories import UserFactory
from apps.notifications import sms

pytestmark = pytest.mark.django_db

REQUEST = "/api/v1/auth/otp/request/"
VERIFY = "/api/v1/auth/otp/verify/"
PHONE = "+919876543210"
TEST_PHONE = "+919000000001"  # fixed OTP 123456 (settings.OTP_TEST_NUMBERS)
TERMS = "2026-11-01"


def request_otp(client, phone=PHONE, app="customer", purpose=None, capture=None):
    body = {"phone": phone, "app": app}
    if purpose:
        body["purpose"] = purpose
    if capture is None:
        return client.post(REQUEST, body, format="json")
    with capture(execute=True):
        return client.post(REQUEST, body, format="json")


def sent_code() -> str:
    """The OTP in the last SMS (locmem backend)."""
    return sms.outbox[-1].body.split()[1]


def verify(client, code, phone=PHONE, app="customer", terms=TERMS):
    return client.post(
        VERIFY, {"phone": phone, "otp": code, "app": app, "terms_version": terms}, format="json"
    )


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


class TestRequest:
    def test_sends_a_hashed_otp_by_sms(self, api_client, django_capture_on_commit_callbacks):
        response = request_otp(api_client, capture=django_capture_on_commit_callbacks)
        assert response.status_code == 200
        assert response.json() == {
            "otp_length": 6,
            "expires_in_seconds": 300,
            "resend_after_seconds": 30,
        }
        otp = OTPRequest.objects.get(phone=PHONE)
        code = sent_code()
        assert len(code) == 6
        assert code.isdigit()
        assert otp.code_hash == hash_code(PHONE, "customer", "login", code)
        assert code not in otp.code_hash
        assert otp.sms_sent_at is not None
        message = sms.outbox[-1]
        assert message.to == PHONE
        assert message.dlt_template_id == "1007000000000000001"
        assert message.body.startswith("<#> ")

    def test_appends_the_sms_retriever_hash_of_the_app(
        self, api_client, settings, django_capture_on_commit_callbacks
    ):
        settings.SMS_RETRIEVER_APP_HASHES = {"customer": "FA+9qCX9VSu", "rider": ""}
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        assert sms.outbox[-1].body.endswith("FA+9qCX9VSu")

    def test_records_ip_and_user_agent(self, api_client):
        api_client.post(
            REQUEST,
            {"phone": PHONE, "app": "rider"},
            format="json",
            headers={"User-Agent": "JivoRider/1.0"},
            REMOTE_ADDR="203.0.113.7",
        )
        otp = OTPRequest.objects.get(phone=PHONE)
        assert (otp.app, otp.ip, otp.user_agent) == ("rider", "203.0.113.7", "JivoRider/1.0")

    def test_fixed_otp_test_number_sends_no_sms(
        self, api_client, django_capture_on_commit_callbacks
    ):
        for _ in range(5):  # also exempt from the send limits
            assert (
                request_otp(
                    api_client, TEST_PHONE, capture=django_capture_on_commit_callbacks
                ).status_code
                == 200
            )
        assert sms.outbox == []
        assert verify(api_client, "123456", phone=TEST_PHONE).status_code == 200

    @pytest.mark.parametrize(
        ("body", "field"),
        [
            ({"phone": "9876543210", "app": "customer"}, "phone"),
            ({"phone": PHONE, "app": "admin"}, "app"),
            ({"phone": PHONE, "app": "customer", "purpose": "reset"}, "purpose"),
        ],
    )
    def test_validation(self, api_client, body, field):
        err = error(api_client.post(REQUEST, body, format="json"), 400)
        assert err["code"] == "VALIDATION_ERROR"
        assert field in err["details"]

    def test_stale_bearer_token_is_ignored(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer expired")
        assert request_otp(api_client).status_code == 200

    def test_new_otp_replaces_the_previous_one(
        self, api_client, django_capture_on_commit_callbacks
    ):
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        first = sent_code()
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        second = sent_code()
        if first != second:
            assert error(verify(api_client, first), 400)["code"] in {"OTP_EXPIRED", "OTP_INVALID"}
        assert verify(api_client, second).status_code == 200

    def test_delete_account_otp_for_unknown_phone_sends_nothing(
        self, api_client, django_capture_on_commit_callbacks
    ):
        response = request_otp(
            api_client, purpose="delete_account", capture=django_capture_on_commit_callbacks
        )
        assert response.status_code == 200
        assert response.json()["otp_length"] == 6
        assert not OTPRequest.objects.exists()
        assert sms.outbox == []


class TestSendLimits:
    def test_three_per_phone_per_ten_minutes(self, api_client):
        for _ in range(3):
            assert request_otp(api_client).status_code == 200
        response = request_otp(api_client)
        err = error(response, 429)
        assert err["code"] == "OTP_RATE_LIMITED"
        wait = err["details"]["retry_after_seconds"]
        assert 0 < wait <= 600
        assert response["Retry-After"] == str(wait)
        assert err["message"] == (
            f"Too many OTP requests. Try again later. Expected available in {wait} seconds."
        )

    def test_ten_per_phone_per_day(self, api_client, settings):
        settings.OTP_SEND_LIMIT_PER_10_MIN = 100
        settings.OTP_SEND_LIMIT_PER_DAY = 2
        assert request_otp(api_client).status_code == 200
        assert request_otp(api_client).status_code == 200
        err = error(request_otp(api_client), 429)
        assert err["details"]["retry_after_seconds"] > 600

    def test_per_ip(self, api_client, settings):
        settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR = 2
        assert request_otp(api_client, "+919876500001").status_code == 200
        assert request_otp(api_client, "+919876500002").status_code == 200
        assert error(request_otp(api_client, "+919876500003"), 429)["code"] == "OTP_RATE_LIMITED"

    def test_trusted_proxy_header_identifies_the_client(self, api_client, settings):
        settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR = 1
        settings.NUM_PROXIES = 1
        for i, client_ip in enumerate(["198.51.100.1", "198.51.100.2"]):
            response = api_client.post(
                REQUEST,
                {"phone": f"+91987650000{i}", "app": "customer"},
                format="json",
                HTTP_X_FORWARDED_FOR=client_ip,
            )
            assert response.status_code == 200
        assert OTPRequest.objects.filter(ip="198.51.100.2").exists()


class TestVerify:
    def login(self, client, capture, **kwargs):
        request_otp(client, capture=capture, **{k: v for k, v in kwargs.items() if k == "app"})
        return verify(client, sent_code(), **kwargs)

    def test_new_customer(self, api_client, django_capture_on_commit_callbacks):
        with freeze_time("2026-11-02T10:15:00Z"):
            response = self.login(api_client, django_capture_on_commit_callbacks)
            assert response.status_code == 200
            body = response.json()
            assert AccessToken(body["access"])["app"] == "customer"
            api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {body['access']}")
            me = api_client.get("/api/v1/me/").json()
        assert body["is_new_user"] is True
        assert body["rider_status"] == "NONE"
        assert body["deletion_cancelled"] is False
        assert body["user"]["phone"] == PHONE
        assert body["user"]["is_profile_complete"] is False
        user = User.objects.get(phone=PHONE)
        assert me["id"] == user.pk
        assert user.terms_version == TERMS
        assert user.terms_accepted_at.isoformat() == "2026-11-02T10:15:00+00:00"
        assert not user.has_usable_password()

    def test_returning_customer_and_terms_update(
        self, api_client, django_capture_on_commit_callbacks
    ):
        user = UserFactory(phone=PHONE, terms_version=TERMS)
        user.terms_accepted_at = timezone.now() - timedelta(days=10)
        user.save()
        accepted = user.terms_accepted_at
        response = self.login(api_client, django_capture_on_commit_callbacks)
        assert response.json()["is_new_user"] is False
        user.refresh_from_db()
        assert user.terms_accepted_at == accepted  # same version: unchanged

        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        verify(api_client, sent_code(), terms="2027-01-01")
        user.refresh_from_db()
        assert user.terms_version == "2027-01-01"
        assert user.terms_accepted_at > accepted

    def test_rider_app(self, api_client, django_capture_on_commit_callbacks):
        response = self.login(api_client, django_capture_on_commit_callbacks, app="rider")
        assert response.json()["rider_status"] == "NONE"
        assert AccessToken(response.json()["access"])["app"] == "rider"

    def test_wrong_code_counts_attempts_then_expires(
        self, api_client, django_capture_on_commit_callbacks
    ):
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        code = sent_code()
        wrong = "000000" if code != "000000" else "111111"
        for remaining in (4, 3, 2, 1, 0):
            err = error(verify(api_client, wrong), 400)
            assert err == {
                "code": "OTP_INVALID",
                "message": "The OTP is incorrect.",
                "details": {"attempts_remaining": remaining},
            }
        assert error(verify(api_client, code), 400)["code"] == "OTP_EXPIRED"

    def test_expires_after_five_minutes(self, api_client, django_capture_on_commit_callbacks):
        with freeze_time("2026-11-02T10:00:00Z"):
            request_otp(api_client, capture=django_capture_on_commit_callbacks)
        with freeze_time("2026-11-02T10:05:01Z"):
            assert error(verify(api_client, sent_code()), 400)["code"] == "OTP_EXPIRED"

    def test_an_otp_works_once(self, api_client, django_capture_on_commit_callbacks):
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        code = sent_code()
        assert verify(api_client, code).status_code == 200
        assert error(verify(api_client, code), 400)["code"] == "OTP_EXPIRED"

    def test_otp_is_bound_to_its_app(self, api_client, django_capture_on_commit_callbacks):
        request_otp(api_client, capture=django_capture_on_commit_callbacks)
        assert error(verify(api_client, sent_code(), app="rider"), 400)["code"] == "OTP_EXPIRED"

    def test_delete_account_otp_never_logs_in(self, api_client, django_capture_on_commit_callbacks):
        UserFactory(phone=PHONE)
        request_otp(
            api_client, purpose="delete_account", capture=django_capture_on_commit_callbacks
        )
        assert error(verify(api_client, sent_code()), 400)["code"] == "OTP_EXPIRED"

    def test_deactivated_account(self, api_client, django_capture_on_commit_callbacks):
        UserFactory(phone=PHONE, is_active=False)
        err = error(self.login(api_client, django_capture_on_commit_callbacks), 403)
        assert err == {
            "code": "PERMISSION_DENIED",
            "message": "This account is deactivated.",
            "details": {},
        }

    def test_login_during_grace_period_restores_the_account(
        self, api_client, django_capture_on_commit_callbacks
    ):
        user = UserFactory(phone=PHONE)
        user.deleted_at = timezone.now() - timedelta(days=3)
        user.deletion_reason = "Too many notifications"
        user.save()
        body = self.login(api_client, django_capture_on_commit_callbacks).json()
        assert body["deletion_cancelled"] is True
        assert body["is_new_user"] is False
        user.refresh_from_db()
        assert user.deleted_at is None
        assert user.deletion_reason == ""

    def test_validation(self, api_client):
        response = api_client.post(
            VERIFY, {"phone": PHONE, "otp": "12", "app": "customer"}, format="json"
        )
        err = error(response, 400)
        assert err["details"]["otp"] == ["Enter the 6-digit OTP."]
        assert err["details"]["terms_version"] == ["This field is required."]

    def test_per_ip_verify_limit(self, api_client, settings):
        settings.OTP_VERIFY_LIMIT_PER_IP_PER_HOUR = 1
        assert error(verify(api_client, "123456"), 400)["code"] == "OTP_EXPIRED"
        assert error(verify(api_client, "123456"), 429)["code"] == "OTP_RATE_LIMITED"
        # Fixed-OTP test numbers are exempt, so integration suites can log in repeatedly.
        for _ in range(3):
            request_otp(api_client, TEST_PHONE)
            assert verify(api_client, "123456", phone=TEST_PHONE).status_code == 200
