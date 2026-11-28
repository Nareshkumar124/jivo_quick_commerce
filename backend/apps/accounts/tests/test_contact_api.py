"""Add a phone / verify an email on a signed-in account, and what an email-only account may do
(2026-11-28). Test ids P8-EOTP-nn are listed in docs/plan/phase-8-hardening-and-launch.md §3."""

import importlib
import sys
from datetime import timedelta
from decimal import Decimal

import pytest
from django.core import mail
from django.core.exceptions import ImproperlyConfigured
from django.utils import timezone

from apps.accounts.models import OTPRequest, User
from apps.accounts.services import auth, contact
from apps.accounts.tasks import send_otp_email
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core.exceptions import ApiError
from apps.core.models import AuditLog
from apps.notifications import sms

pytestmark = pytest.mark.django_db

PHONE_OTP = "/api/v1/me/phone/otp/"
PHONE_VERIFY = "/api/v1/me/phone/verify/"
EMAIL_OTP = "/api/v1/me/email/otp/"
EMAIL_VERIFY = "/api/v1/me/email/verify/"
ME = "/api/v1/me/"
TEST_PHONE = "+919000000001"  # fixed OTP 123456
TEST_EMAIL = "customer2@example.com"  # fixed OTP 123456
EMAIL = "asha.verma@example.com"


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


@pytest.fixture
def email_user(db):
    """A customer who signed up with email: verified email, no phone."""
    return UserFactory(phone=None, email=EMAIL, email_verified_at=timezone.now())


@pytest.fixture
def email_client(email_user, make_auth_client):
    return make_auth_client(email_user)


# --------------------------------------------------------------------------- me fields


class TestMeFields:
    def test_email_only_account(self, email_client):
        """P8-EOTP-16: `has_phone` tells the app a phone is still needed."""
        body = email_client.get(ME).json()
        assert body["phone"] is None
        assert body["has_phone"] is False
        assert body["email_verified"] is True

    def test_phone_account(self, auth_client):
        body = auth_client.get(ME).json()
        assert body["has_phone"] is True
        assert body["email_verified"] is False

    def test_changing_the_email_unverifies_it(self, make_auth_client):
        user = UserFactory(email=EMAIL, email_verified_at=timezone.now())
        client = make_auth_client(user)
        body = client.patch(ME, {"email": "new@example.com"}, format="json").json()
        assert body["email"] == "new@example.com"
        assert body["email_verified"] is False
        user.refresh_from_db()
        assert user.email_verified_at is None

    def test_resending_the_same_email_keeps_it_verified(self, make_auth_client):
        user = UserFactory(email=EMAIL, email_verified_at=timezone.now())
        client = make_auth_client(user)
        body = client.patch(ME, {"email": "Asha.Verma@example.com"}, format="json").json()
        assert body["email_verified"] is True

    @pytest.mark.parametrize("new", ["new@example.com", None])
    def test_email_only_account_cannot_drop_its_login_email(self, email_client, new):
        """P8-EOTP-17: the email is the only way an email-only account signs in."""
        err = error(email_client.patch(ME, {"email": new}, format="json"), 400)
        assert err["code"] == "VALIDATION_ERROR"
        assert "email" in err["details"]


class TestUserModel:
    def test_any_email_change_clears_verification(self):
        user = UserFactory(email=EMAIL, email_verified_at=timezone.now())
        user = User.objects.get(pk=user.pk)
        user.email = "other@example.com"
        user.save(update_fields=["email"])
        user.refresh_from_db()
        assert user.email_verified_at is None

    def test_a_new_stamp_in_the_same_save_is_kept(self):
        user = User.objects.get(pk=UserFactory().pk)
        user.email = "proved@example.com"
        user.email_verified_at = timezone.now()
        user.save()
        user.refresh_from_db()
        assert user.email_verified_at is not None

    def test_removing_the_email_clears_verification(self):
        user = User.objects.get(pk=UserFactory(email=EMAIL, email_verified_at=timezone.now()).pk)
        user.email = ""
        user.save()
        user.refresh_from_db()
        assert user.email is None
        assert user.email_verified_at is None

    def test_email_is_unique_case_insensitively(self):
        from django.db import IntegrityError

        UserFactory(email=EMAIL)
        with pytest.raises(IntegrityError):
            UserFactory(email="ASHA.VERMA@example.com")


# --------------------------------------------------------------------------- add phone


class TestAddPhone:
    def test_add_phone_with_an_sms_code(
        self, email_client, email_user, django_capture_on_commit_callbacks
    ):
        """P8-EOTP-18: an email sign-up adds a phone proved by SMS OTP."""
        with django_capture_on_commit_callbacks(execute=True):
            response = email_client.post(PHONE_OTP, {"phone": "+919876543210"}, format="json")
        assert response.status_code == 200
        otp = OTPRequest.objects.get(phone="+919876543210")
        assert otp.purpose == "add_phone"
        assert otp.app == "customer"
        code = sms.outbox[-1].body.split()[1]
        response = email_client.post(
            PHONE_VERIFY, {"phone": "+919876543210", "otp": code}, format="json"
        )
        assert response.status_code == 200, response.content
        assert response.json()["phone"] == "+919876543210"
        assert response.json()["has_phone"] is True
        email_user.refresh_from_db()
        assert email_user.phone == "+919876543210"
        assert AuditLog.objects.filter(action="account.phone_added").exists()

    def test_wrong_code(self, email_client):
        email_client.post(PHONE_OTP, {"phone": TEST_PHONE}, format="json")
        err = error(email_client.post(PHONE_VERIFY, {"phone": TEST_PHONE, "otp": "000000"}), 400)
        assert err["code"] == "OTP_INVALID"

    def test_login_otp_cannot_add_a_phone(self, email_client, api_client):
        api_client.post("/api/v1/auth/otp/request/", {"phone": TEST_PHONE, "app": "customer"})
        err = error(email_client.post(PHONE_VERIFY, {"phone": TEST_PHONE, "otp": "123456"}), 400)
        assert err["code"] == "OTP_EXPIRED"

    def test_code_for_another_number_does_not_work(self, email_client):
        email_client.post(PHONE_OTP, {"phone": TEST_PHONE}, format="json")
        response = email_client.post(PHONE_VERIFY, {"phone": "+919000000002", "otp": "123456"})
        assert error(response, 400)["code"] == "OTP_EXPIRED"

    def test_number_of_another_account(self, email_client, email_user):
        """P8-EOTP-19: never merged; reported only after the code proves the number."""
        UserFactory(phone=TEST_PHONE)
        assert email_client.post(PHONE_OTP, {"phone": TEST_PHONE}).status_code == 200
        err = error(email_client.post(PHONE_VERIFY, {"phone": TEST_PHONE, "otp": "123456"}), 409)
        assert err["code"] == "PHONE_IN_USE"
        email_user.refresh_from_db()
        assert email_user.phone is None

    def test_account_with_a_phone_cannot_change_it(self, auth_client):
        err = error(auth_client.post(PHONE_OTP, {"phone": TEST_PHONE}), 400)
        assert err["details"] == {"phone": [contact.MSG_PHONE_ALREADY_SET]}
        err = error(auth_client.post(PHONE_VERIFY, {"phone": TEST_PHONE, "otp": "123456"}), 400)
        assert err["code"] == "VALIDATION_ERROR"

    def test_phone_set_meanwhile(self, email_user):
        contact.request_add_phone(email_user, phone=TEST_PHONE, app="customer", ip=None)
        User.objects.filter(pk=email_user.pk).update(phone="+919000000002")
        with pytest.raises(ApiError) as exc:
            contact.verify_add_phone(
                email_user, phone=TEST_PHONE, code="123456", app="customer", ip=None
            )
        assert exc.value.error_code == "VALIDATION_ERROR"

    def test_invalid_phone(self, email_client):
        assert error(email_client.post(PHONE_OTP, {"phone": "98765"}), 400)["code"] == (
            "VALIDATION_ERROR"
        )

    @pytest.mark.parametrize("url", [PHONE_OTP, PHONE_VERIFY, EMAIL_OTP, EMAIL_VERIFY])
    def test_needs_a_signed_in_user(self, api_client, url):
        assert error(api_client.post(url, {}), 401)["code"] == "AUTH_REQUIRED"

    def test_rider_token_records_the_rider_app(self, make_auth_client):
        user = UserFactory(phone=None, email=EMAIL, email_verified_at=timezone.now())
        client = make_auth_client(user, app="rider")
        client.post(PHONE_OTP, {"phone": TEST_PHONE}, format="json")
        assert OTPRequest.objects.get(phone=TEST_PHONE).app == "rider"

    def test_send_limits_apply(self, email_client):
        for _ in range(3):
            assert email_client.post(PHONE_OTP, {"phone": "+919876543210"}).status_code == 200
        assert error(email_client.post(PHONE_OTP, {"phone": "+919876543210"}), 429)["code"] == (
            "OTP_RATE_LIMITED"
        )


# --------------------------------------------------------------------------- verify email


class TestVerifyEmail:
    def test_verify_a_new_email(self, auth_client, user, django_capture_on_commit_callbacks):
        """P8-EOTP-20: a phone customer verifies an email, which then works for email login."""
        with django_capture_on_commit_callbacks(execute=True):
            response = auth_client.post(EMAIL_OTP, {"email": "Asha.Verma@Example.com"})
        assert response.status_code == 200
        assert OTPRequest.objects.get(email=EMAIL).purpose == "verify_email"
        code = mail.outbox[-1].body.split("code is ")[1][:6]
        assert "verify this email" in mail.outbox[-1].body
        response = auth_client.post(EMAIL_VERIFY, {"email": EMAIL, "otp": code})
        assert response.status_code == 200, response.content
        assert response.json()["email"] == EMAIL
        assert response.json()["email_verified"] is True
        user.refresh_from_db()
        assert user.email_verified_at is not None
        assert AuditLog.objects.filter(action="account.email_verified").exists()

    def test_verify_the_current_unverified_email(self, make_auth_client):
        user = UserFactory(email=TEST_EMAIL)
        client = make_auth_client(user)
        client.post(EMAIL_OTP, {"email": TEST_EMAIL})
        assert client.post(EMAIL_VERIFY, {"email": TEST_EMAIL, "otp": "123456"}).json()[
            "email_verified"
        ]

    def test_already_verified(self, email_client):
        err = error(email_client.post(EMAIL_OTP, {"email": EMAIL}), 400)
        assert err["details"] == {"email": [contact.MSG_EMAIL_ALREADY_VERIFIED]}

    def test_verified_on_another_account(self, auth_client, user):
        """P8-EOTP-21: EMAIL_IN_USE, only after the code is verified."""
        UserFactory(email=TEST_EMAIL, email_verified_at=timezone.now())
        assert auth_client.post(EMAIL_OTP, {"email": TEST_EMAIL}).status_code == 200
        err = error(auth_client.post(EMAIL_VERIFY, {"email": TEST_EMAIL, "otp": "123456"}), 409)
        assert err["code"] == "EMAIL_IN_USE"
        user.refresh_from_db()
        assert user.email is None

    def test_staff_email_is_in_use(self, auth_client):
        StaffUserFactory(email=TEST_EMAIL)
        auth_client.post(EMAIL_OTP, {"email": TEST_EMAIL})
        err = error(auth_client.post(EMAIL_VERIFY, {"email": TEST_EMAIL, "otp": "123456"}), 409)
        assert err["code"] == "EMAIL_IN_USE"

    def test_unverified_claim_elsewhere_is_released(self, auth_client, user):
        claimer = UserFactory(email=TEST_EMAIL)
        auth_client.post(EMAIL_OTP, {"email": TEST_EMAIL})
        response = auth_client.post(EMAIL_VERIFY, {"email": TEST_EMAIL, "otp": "123456"})
        assert response.status_code == 200
        claimer.refresh_from_db()
        assert claimer.email is None
        assert AuditLog.objects.filter(
            action="auth.unverified_email_released", object_id=str(claimer.pk)
        ).exists()

    def test_wrong_code(self, auth_client):
        auth_client.post(EMAIL_OTP, {"email": TEST_EMAIL})
        err = error(auth_client.post(EMAIL_VERIFY, {"email": TEST_EMAIL, "otp": "000000"}), 400)
        assert err["code"] == "OTP_INVALID"

    def test_another_users_code_is_not_mine(self, auth_client, make_auth_client):
        """IDOR: OTPs are bound to the address, and the address is proved by the code; the
        other user's pending verification does not let this user claim anything else."""
        other = make_auth_client(UserFactory())
        other.post(EMAIL_OTP, {"email": TEST_EMAIL})
        response = auth_client.post(EMAIL_VERIFY, {"email": "else@example.com", "otp": "123456"})
        assert error(response, 400)["code"] == "OTP_EXPIRED"

    def test_mark_email_verified_for_the_admin(self, staff_user):
        user = UserFactory(email=TEST_EMAIL)
        user = contact.mark_email_verified(user, actor=staff_user)
        assert user.email_verified_at is not None
        entry = AuditLog.objects.get(action="account.email_verified")
        assert entry.actor == staff_user
        assert entry.changes == {"via": "staff"}
        contact.mark_email_verified(user, actor=staff_user)  # idempotent
        assert AuditLog.objects.filter(action="account.email_verified").count() == 1

    def test_mark_email_verified_needs_an_email(self):
        with pytest.raises(ValueError, match="no email"):
            contact.mark_email_verified(UserFactory())


# --------------------------------------------------------------------------- orders, deletion


class TestEmailOnlyAccount:
    def test_order_needs_a_phone(self, email_user):
        """P8-EOTP-22: POST /orders/ refuses PHONE_REQUIRED before anything else."""
        from apps.orders import services as order_services

        with pytest.raises(ApiError) as exc:
            order_services.place_order(
                email_user,
                None,
                address_id=1,
                payment_method="COD",
                expected_grand_total=Decimal("100.00"),
                idempotency_key="k" * 16,
            )
        assert exc.value.error_code == "PHONE_REQUIRED"
        assert exc.value.status_code == 422

    def test_order_endpoint_answers_phone_required(self, email_client):
        from apps.stores.tests.factories import DarkStoreFactory

        store = DarkStoreFactory()
        response = email_client.post(
            "/api/v1/orders/",
            {"address_id": 1, "payment_method": "COD", "expected_grand_total": "100.00"},
            format="json",
            HTTP_X_STORE_ID=str(store.pk),
            HTTP_IDEMPOTENCY_KEY="0b3c6f1e-8a52-4d1b-9c37-5d2a7e9f1a20",
        )
        assert error(response, 422)["code"] == "PHONE_REQUIRED"

    def test_delete_account_with_an_email_code(self, email_client, email_user, api_client):
        """P8-EOTP-23: an account without a phone confirms deletion by email OTP."""
        User.objects.filter(pk=email_user.pk).update(email=TEST_EMAIL)
        api_client.post(
            "/api/v1/auth/email-otp/request/",
            {"email": TEST_EMAIL, "app": "customer", "purpose": "delete_account"},
        )
        response = email_client.post("/api/v1/me/delete/", {"otp": "123456"}, format="json")
        assert response.status_code == 200, response.content
        email_user.refresh_from_db()
        assert email_user.deleted_at is not None

    def test_anonymise_removes_email_otps(self, email_user):
        OTPRequest.objects.create(
            email=EMAIL,
            app="customer",
            code_hash="x" * 64,
            expires_at=timezone.now() + timedelta(minutes=5),
        )
        User.objects.filter(pk=email_user.pk).update(deleted_at=timezone.now() - timedelta(days=31))
        assert auth.anonymise_user(email_user.pk) is True
        assert not OTPRequest.objects.filter(email=EMAIL).exists()
        email_user.refresh_from_db()
        assert email_user.email is None


# --------------------------------------------------------------------------- task, settings


class TestSendOtpEmailTask:
    def _otp(self, **kwargs):
        defaults = {
            "email": EMAIL,
            "app": "customer",
            "code_hash": "x" * 64,
            "expires_at": timezone.now() + timedelta(minutes=5),
        }
        return OTPRequest.objects.create(**{**defaults, **kwargs})

    def test_sends_once(self):
        """P8-EOTP-24: idempotent; a retry never double-sends."""
        otp = self._otp()
        assert send_otp_email(otp.pk, "123456") == "sent"
        assert send_otp_email(otp.pk, "123456") == "skipped"
        assert len(mail.outbox) == 1

    @pytest.mark.parametrize(
        "kwargs",
        [
            {"verified_at": timezone.now()},
            {"expires_at": timezone.now() - timedelta(seconds=1)},
            {"email": "", "phone": "+919876543210"},
        ],
    )
    def test_skips_used_expired_or_phone_otps(self, kwargs):
        assert send_otp_email(self._otp(**kwargs).pk, "123456") == "skipped"
        assert mail.outbox == []

    def test_unknown_otp(self):
        assert send_otp_email(999_999_999, "123456") == "skipped"

    def test_smtp_failure_is_retried(self, monkeypatch):
        import smtplib

        from celery.exceptions import Retry

        def boom(*args, **kwargs):
            raise smtplib.SMTPServerDisconnected("down")

        monkeypatch.setattr("apps.accounts.tasks.send_mail", boom)
        otp = self._otp()
        with pytest.raises(Retry):
            send_otp_email.apply(args=(otp.pk, "123456"), throw=True)
        otp.refresh_from_db()
        assert otp.email_sent_at is None


class TestSettings:
    @pytest.fixture
    def deploy_env(self, monkeypatch):
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.com")
        monkeypatch.setenv("NUM_PROXIES", "1")
        monkeypatch.setenv("OTP_TEST_EMAILS", "reviewer@example.com:123456")
        monkeypatch.delenv("OTP_TEST_NUMBERS", raising=False)
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        yield
        for name in ("production", "staging", "deployed"):
            sys.modules.pop(f"config.settings.{name}", None)

    def _load(self, name):
        sys.modules.pop(f"config.settings.{name}", None)
        return importlib.import_module(f"config.settings.{name}")

    def test_production_refuses_test_emails(self, deploy_env):
        """P8-EOTP-25: fixed-OTP test emails never exist in production."""
        with pytest.raises(ImproperlyConfigured, match="OTP_TEST_EMAILS"):
            self._load("production")

    def test_staging_allows_them(self, deploy_env):
        assert self._load("staging").OTP_TEST_EMAILS == {"reviewer@example.com": "123456"}
