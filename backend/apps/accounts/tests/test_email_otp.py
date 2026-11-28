"""Email OTP sign-in and the per-app login method switch (2026-11-28).

Test ids P8-EOTP-nn are listed in docs/plan/phase-8-hardening-and-launch.md §3.
"""

import logging
from datetime import timedelta

import pytest
from django.core import mail
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts.choices import AppName, LoginMethodSetting, RiderStatus
from apps.accounts.models import OTPRequest, User
from apps.accounts.services.otp import email_target, hash_code
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.cms import services as cms_services
from apps.cms.models import AppConfig
from apps.core.models import AuditLog
from apps.notifications import sms

pytestmark = pytest.mark.django_db

METHODS = "/api/v1/auth/methods/"
REQUEST = "/api/v1/auth/email-otp/request/"
VERIFY = "/api/v1/auth/email-otp/verify/"
PHONE_REQUEST = "/api/v1/auth/otp/request/"
PHONE_VERIFY = "/api/v1/auth/otp/verify/"
EMAIL = "asha.verma@example.com"
TEST_EMAIL = "customer2@example.com"  # fixed OTP 123456 (settings.OTP_TEST_EMAILS)
TERMS = "2026-11-01"


def switch(app: str, setting: str) -> None:
    cms_services.set_login_methods(app, setting)


@pytest.fixture
def email_login():
    """Email sign-in on for both apps (the default is phone only)."""
    switch(AppName.CUSTOMER, LoginMethodSetting.BOTH)
    switch(AppName.RIDER, LoginMethodSetting.BOTH)


def request_email_otp(client, email=EMAIL, app="customer", purpose=None, capture=None):
    body = {"email": email, "app": app}
    if purpose:
        body["purpose"] = purpose
    if capture is None:
        return client.post(REQUEST, body, format="json")
    with capture(execute=True):
        return client.post(REQUEST, body, format="json")


def sent_code() -> str:
    """The OTP in the last email (locmem backend)."""
    body = mail.outbox[-1].body
    return body.split("code is ")[1][:6]


def verify(client, code, email=EMAIL, app="customer", terms=TERMS):
    return client.post(
        VERIFY, {"email": email, "otp": code, "app": app, "terms_version": terms}, format="json"
    )


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


def sign_in(client, capture, email=EMAIL, app="customer"):
    assert request_email_otp(client, email, app, capture=capture).status_code == 200
    return verify(client, sent_code(), email, app)


# --------------------------------------------------------------------------- the switch


class TestLoginMethods:
    def test_default_is_phone_only_for_both_apps(self, api_client):
        """P8-EOTP-01: the switch defaults to phone, so current behaviour is unchanged."""
        for app in ("customer", "rider"):
            response = api_client.get(METHODS, {"app": app})
            assert response.status_code == 200
            assert response.json() == {"app": app, "methods": ["phone"]}

    @pytest.mark.parametrize(
        ("setting", "methods"),
        [("phone", ["phone"]), ("email", ["email"]), ("both", ["phone", "email"])],
    )
    def test_each_setting(self, api_client, setting, methods):
        """P8-EOTP-02: phone / email / both, per app."""
        switch("rider", setting)
        assert api_client.get(METHODS, {"app": "rider"}).json()["methods"] == methods
        assert api_client.get(METHODS, {"app": "customer"}).json()["methods"] == ["phone"]

    def test_app_from_the_header(self, api_client):
        switch("customer", "email")
        response = api_client.get(METHODS, HTTP_X_APP_NAME="customer")
        assert response.json() == {"app": "customer", "methods": ["email"]}

    def test_query_wins_over_the_header(self, api_client):
        switch("rider", "both")
        response = api_client.get(METHODS, {"app": "rider"}, HTTP_X_APP_NAME="customer")
        assert response.json()["app"] == "rider"

    @pytest.mark.parametrize("params", [{}, {"app": "web"}])
    def test_no_valid_app_is_400(self, api_client, params):
        assert error(api_client.get(METHODS, params), 400)["code"] == "VALIDATION_ERROR"

    def test_public_even_with_a_garbage_token(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer nonsense")
        assert api_client.get(METHODS, {"app": "customer"}).status_code == 200

    def test_a_change_is_seen_at_once(self, api_client):
        """P8-EOTP-03: cached config is dropped on save (no redeploy, no stale minute)."""
        assert api_client.get(METHODS, {"app": "customer"}).json()["methods"] == ["phone"]
        switch("customer", "email")
        assert api_client.get(METHODS, {"app": "customer"}).json()["methods"] == ["email"]

    def test_set_login_methods_is_audited(self, staff_user):
        config = cms_services.set_login_methods(
            "customer", "both", actor=staff_user, ip="203.0.113.9"
        )
        assert config.customer_login_methods == "both"
        entry = AuditLog.objects.get(action="config.login_methods")
        assert entry.actor == staff_user
        assert entry.changes == {"app": "customer", "before": "phone", "after": "both"}
        assert entry.ip == "203.0.113.9"
        # Unchanged value: no second entry.
        cms_services.set_login_methods("customer", "both", actor=staff_user)
        assert AuditLog.objects.filter(action="config.login_methods").count() == 1

    @pytest.mark.parametrize(("app", "setting"), [("web", "phone"), ("customer", "sms")])
    def test_set_login_methods_refuses_unknown_values(self, app, setting):
        with pytest.raises(ValueError, match="is not a valid"):
            cms_services.set_login_methods(app, setting)

    def test_login_method_setting_reads_the_snapshot(self):
        AppConfig.objects.update_or_create(pk=1, defaults={"rider_login_methods": "email"})
        cms_services.invalidate_app_config()
        assert cms_services.login_method_setting("rider") == "email"


class TestPhoneLoginSwitchedOff:
    def test_phone_otp_request_is_refused(self, api_client):
        """P8-EOTP-04: a switched-off method answers LOGIN_METHOD_DISABLED with the others."""
        switch("customer", "email")
        response = api_client.post(
            PHONE_REQUEST, {"phone": "+919876543210", "app": "customer"}, format="json"
        )
        err = error(response, 403)
        assert err["code"] == "LOGIN_METHOD_DISABLED"
        assert err["details"] == {"app": "customer", "method": "phone", "methods": ["email"]}
        assert not OTPRequest.objects.exists()
        assert sms.outbox == []

    def test_phone_otp_verify_is_refused(self, api_client):
        api_client.post(PHONE_REQUEST, {"phone": "+919000000001", "app": "rider"}, format="json")
        switch("rider", "email")
        response = api_client.post(
            PHONE_VERIFY,
            {"phone": "+919000000001", "otp": "123456", "app": "rider", "terms_version": TERMS},
            format="json",
        )
        assert error(response, 403)["code"] == "LOGIN_METHOD_DISABLED"

    def test_delete_account_otp_still_works(self, api_client):
        """Deleting an account never depends on the switch."""
        UserFactory(phone="+919876543210")
        switch("customer", "email")
        response = api_client.post(
            PHONE_REQUEST,
            {"phone": "+919876543210", "app": "customer", "purpose": "delete_account"},
            format="json",
        )
        assert response.status_code == 200

    def test_the_other_app_is_not_affected(self, api_client):
        switch("rider", "email")
        response = api_client.post(
            PHONE_REQUEST, {"phone": "+919000000001", "app": "customer"}, format="json"
        )
        assert response.status_code == 200


# --------------------------------------------------------------------------- request


class TestEmailRequest:
    def test_refused_while_email_is_off(self, api_client):
        """P8-EOTP-05: email sign-in is off by default."""
        err = error(request_email_otp(api_client), 403)
        assert err["code"] == "LOGIN_METHOD_DISABLED"
        assert err["details"]["methods"] == ["phone"]
        assert mail.outbox == []

    def test_sends_a_hashed_otp_by_email(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-06: same OTP shape as SMS; the email carries the code, the row only a hash."""
        response = request_email_otp(api_client, capture=django_capture_on_commit_callbacks)
        assert response.status_code == 200
        assert response.json() == {
            "otp_length": 6,
            "expires_in_seconds": 300,
            "resend_after_seconds": 30,
        }
        otp = OTPRequest.objects.get(email=EMAIL)
        assert otp.phone == ""
        code = sent_code()
        assert code.isdigit()
        assert len(code) == 6
        assert otp.code_hash == hash_code(email_target(EMAIL), "customer", "login", code)
        assert otp.email_sent_at is not None
        message = mail.outbox[-1]
        assert message.to == [EMAIL]
        assert message.subject == "Your Jivo verification code"
        assert "5 minutes" in message.body
        assert sms.outbox == []

    def test_email_is_case_insensitive(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        request_email_otp(
            api_client, "  Asha.Verma@Example.COM ", capture=django_capture_on_commit_callbacks
        )
        assert OTPRequest.objects.get().email == EMAIL
        assert mail.outbox[-1].to == [EMAIL]

    def test_invalid_email_is_400(self, api_client, email_login):
        err = error(request_email_otp(api_client, "not-an-email"), 400)
        assert err["code"] == "VALIDATION_ERROR"
        assert "email" in err["details"]

    def test_the_code_is_never_logged(
        self, api_client, email_login, django_capture_on_commit_callbacks, caplog
    ):
        """P8-EOTP-07: no OTP (and no full email address) in the logs."""
        with caplog.at_level(logging.DEBUG):
            request_email_otp(api_client, capture=django_capture_on_commit_callbacks)
        code = sent_code()
        assert code not in caplog.text
        assert EMAIL not in caplog.text
        assert "a***@example.com" in caplog.text

    def test_test_emails_send_nothing(self, api_client, email_login):
        """P8-EOTP-08: fixed-OTP test emails (local/test settings only)."""
        assert request_email_otp(api_client, TEST_EMAIL).status_code == 200
        otp = OTPRequest.objects.get(email=TEST_EMAIL)
        assert otp.code_hash == hash_code(email_target(TEST_EMAIL), "customer", "login", "123456")
        assert mail.outbox == []

    def test_test_emails_skip_send_limits(self, api_client, email_login):
        for _ in range(5):
            assert request_email_otp(api_client, TEST_EMAIL).status_code == 200

    def test_a_new_otp_replaces_the_active_one(self, api_client, email_login):
        request_email_otp(api_client)
        request_email_otp(api_client)
        now = timezone.now()
        assert OTPRequest.objects.filter(email=EMAIL, expires_at__gt=now).count() == 1

    def test_three_per_email_per_ten_minutes(self, api_client, email_login):
        """P8-EOTP-09: the same send limits as phone, counted per email."""
        for _ in range(3):
            assert request_email_otp(api_client).status_code == 200
        response = request_email_otp(api_client)
        err = error(response, 429)
        assert err["code"] == "OTP_RATE_LIMITED"
        assert 0 < err["details"]["retry_after_seconds"] <= 600
        # Another address is not affected.
        assert request_email_otp(api_client, "other@example.com").status_code == 200

    def test_daily_limit(self, api_client, email_login, settings):
        settings.OTP_SEND_LIMIT_PER_10_MIN = 100
        settings.OTP_SEND_LIMIT_PER_DAY = 2
        request_email_otp(api_client)
        request_email_otp(api_client)
        assert error(request_email_otp(api_client), 429)["details"]["retry_after_seconds"] > 600

    def test_per_ip_limit_is_shared_with_phone(self, api_client, email_login, settings):
        settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR = 2
        api_client.post(PHONE_REQUEST, {"phone": "+919876500001", "app": "customer"})
        assert request_email_otp(api_client, "a@example.com").status_code == 200
        assert error(request_email_otp(api_client, "b@example.com"), 429)["code"] == (
            "OTP_RATE_LIMITED"
        )

    def test_delete_account_otp_only_for_a_verified_account(
        self, api_client, django_capture_on_commit_callbacks
    ):
        """Same answer either way; nothing is sent to an unknown address."""
        response = request_email_otp(
            api_client,
            purpose="delete_account",
            capture=django_capture_on_commit_callbacks,
        )
        assert response.status_code == 200
        assert mail.outbox == []
        UserFactory(phone=None, email=EMAIL, email_verified_at=timezone.now())
        request_email_otp(
            api_client, purpose="delete_account", capture=django_capture_on_commit_callbacks
        )
        assert len(mail.outbox) == 1
        assert "delete" in mail.outbox[-1].body

    def test_internal_purposes_are_not_requestable(self, api_client, email_login):
        response = request_email_otp(api_client, purpose="verify_email")
        assert error(response, 400)["details"].keys() == {"purpose"}


# --------------------------------------------------------------------------- verify


class TestEmailVerifyCustomer:
    def test_new_email_creates_a_customer_without_phone(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-10: a new email is a new customer, verified email, no phone."""
        response = sign_in(api_client, django_capture_on_commit_callbacks)
        assert response.status_code == 200, response.content
        body = response.json()
        assert body["is_new_user"] is True
        assert body["user"]["phone"] is None
        assert body["user"]["email"] == EMAIL
        assert body["user"]["has_phone"] is False
        assert body["user"]["email_verified"] is True
        assert body["user"]["is_profile_complete"] is False
        user = User.objects.get(email=EMAIL)
        assert user.email_verified_at is not None
        assert user.terms_version == TERMS
        assert not user.has_usable_password()

    def test_returning_customer_by_verified_email(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-11: one user table: the phone account with this verified email signs in."""
        user = UserFactory(email=EMAIL, email_verified_at=timezone.now())
        response = sign_in(
            api_client, django_capture_on_commit_callbacks, email="ASHA.verma@example.com"
        )
        body = response.json()
        assert body["is_new_user"] is False
        assert body["user"]["id"] == user.pk
        assert body["user"]["has_phone"] is True
        assert User.objects.count() == 1

    def test_unverified_claim_is_released(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-12: an email typed into another profile (never proved) does not sign anyone
        in to that account; the owner of the address gets their own account."""
        claimer = UserFactory(email=EMAIL)
        assert claimer.email_verified_at is None
        response = sign_in(api_client, django_capture_on_commit_callbacks)
        body = response.json()
        assert body["is_new_user"] is True
        assert body["user"]["id"] != claimer.pk
        claimer.refresh_from_db()
        assert claimer.email is None
        entry = AuditLog.objects.get(action="auth.unverified_email_released")
        assert entry.object_id == str(claimer.pk)
        assert entry.changes == {"reason": "email_otp"}

    def test_staff_cannot_use_email_codes(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        StaffUserFactory(email=EMAIL)
        err = error(sign_in(api_client, django_capture_on_commit_callbacks), 403)
        assert err["code"] == "PERMISSION_DENIED"
        assert User.objects.count() == 1

    def test_deactivated_account(self, api_client, email_login, django_capture_on_commit_callbacks):
        UserFactory(email=EMAIL, email_verified_at=timezone.now(), is_active=False)
        assert error(sign_in(api_client, django_capture_on_commit_callbacks), 403)["code"] == (
            "PERMISSION_DENIED"
        )

    def test_login_restores_an_account_in_deletion_grace(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        UserFactory(email=EMAIL, email_verified_at=timezone.now(), deleted_at=timezone.now())
        body = sign_in(api_client, django_capture_on_commit_callbacks).json()
        assert body["deletion_cancelled"] is True

    def test_wrong_code_counts_attempts_then_locks(self, api_client, email_login):
        """P8-EOTP-13: 5 attempts per OTP, like phone."""
        request_email_otp(api_client, TEST_EMAIL)
        for remaining in (4, 3, 2, 1, 0):
            err = error(verify(api_client, "000000", TEST_EMAIL), 400)
            assert err["code"] == "OTP_INVALID"
            assert err["details"] == {"attempts_remaining": remaining}
        assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_expired_after_five_minutes(self, api_client, email_login):
        request_email_otp(api_client, TEST_EMAIL)
        with freeze_time(timezone.now() + timedelta(minutes=5, seconds=1)):
            assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_single_use(self, api_client, email_login):
        request_email_otp(api_client, TEST_EMAIL)
        assert verify(api_client, "123456", TEST_EMAIL).status_code == 200
        assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_otp_of_the_other_app_is_not_accepted(self, api_client, email_login):
        request_email_otp(api_client, TEST_EMAIL, app="rider")
        assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_delete_account_otp_never_signs_in(self, api_client, email_login):
        UserFactory(phone=None, email=TEST_EMAIL, email_verified_at=timezone.now())
        request_email_otp(api_client, TEST_EMAIL, purpose="delete_account")
        assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_a_phone_otp_is_not_an_email_otp(self, api_client, email_login):
        api_client.post(PHONE_REQUEST, {"phone": "+919000000001", "app": "customer"})
        assert error(verify(api_client, "123456", TEST_EMAIL), 400)["code"] == "OTP_EXPIRED"

    def test_refused_when_email_is_switched_off(self, api_client, email_login):
        request_email_otp(api_client, TEST_EMAIL)
        switch("customer", "phone")
        assert error(verify(api_client, "123456", TEST_EMAIL), 403)["code"] == (
            "LOGIN_METHOD_DISABLED"
        )

    def test_invalid_body(self, api_client, email_login):
        response = api_client.post(VERIFY, {"email": "x", "otp": "12"}, format="json")
        details = error(response, 400)["details"]
        assert {"email", "otp", "app", "terms_version"} <= details.keys()

    def test_new_email_customer_gets_the_welcome_reward(
        self, api_client, email_login, django_capture_on_commit_callbacks
    ):
        from apps.promotions.choices import CouponSource
        from apps.promotions.models import Coupon

        sign_in(api_client, django_capture_on_commit_callbacks)
        user = User.objects.get(email=EMAIL)
        assert Coupon.objects.filter(owner=user, source=CouponSource.WELCOME).count() == 1


class TestEmailVerifyRider:
    @pytest.fixture
    def rider_user(self):
        from apps.delivery.tests.factories import active_rider

        rider = active_rider()
        rider.user.email = EMAIL
        rider.user.email_verified_at = timezone.now()
        rider.user.save()
        return rider.user

    def test_existing_rider_signs_in(
        self, api_client, email_login, rider_user, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-14: rider app, rider with a verified email on file."""
        body = sign_in(api_client, django_capture_on_commit_callbacks, app="rider").json()
        assert body["user"]["id"] == rider_user.pk
        assert body["rider_status"] == RiderStatus.ACTIVE
        assert body["is_new_user"] is False

    def test_unknown_email_never_creates_a_rider_account(self, api_client, email_login):
        """P8-EOTP-15: email never creates rider accounts (new riders register by phone)."""
        request_email_otp(api_client, TEST_EMAIL, app="rider")
        err = error(verify(api_client, "123456", TEST_EMAIL, app="rider"), 403)
        assert err["code"] == "EMAIL_NOT_REGISTERED"
        assert not User.objects.exists()

    def test_customer_without_rider_profile_is_refused(self, api_client, email_login):
        UserFactory(email=TEST_EMAIL, email_verified_at=timezone.now())
        request_email_otp(api_client, TEST_EMAIL, app="rider")
        err = error(verify(api_client, "123456", TEST_EMAIL, app="rider"), 403)
        assert err["code"] == "EMAIL_NOT_REGISTERED"

    def test_unverified_rider_email_is_refused(
        self, api_client, email_login, rider_user, django_capture_on_commit_callbacks
    ):
        User.objects.filter(pk=rider_user.pk).update(email_verified_at=None)
        err = error(sign_in(api_client, django_capture_on_commit_callbacks, app="rider"), 403)
        assert err["code"] == "EMAIL_NOT_REGISTERED"
        rider_user.refresh_from_db()
        assert rider_user.email == EMAIL  # nothing released in the rider app

    def test_staff_rider_email_is_refused(self, api_client, email_login):
        StaffUserFactory(email=TEST_EMAIL, email_verified_at=timezone.now())
        request_email_otp(api_client, TEST_EMAIL, app="rider")
        err = error(verify(api_client, "123456", TEST_EMAIL, app="rider"), 403)
        assert err["code"] == "PERMISSION_DENIED"

    def test_rider_token_has_the_rider_app_claim(
        self, api_client, email_login, rider_user, django_capture_on_commit_callbacks
    ):
        from rest_framework_simplejwt.tokens import AccessToken

        body = sign_in(api_client, django_capture_on_commit_callbacks, app="rider").json()
        assert AccessToken(body["access"])["app"] == "rider"
