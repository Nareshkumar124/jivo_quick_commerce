"""Logout, Me, devices, account deletion and anonymisation (06 §2.1, 09 §3.1, 07 §4)."""

from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time
from rest_framework.test import APIClient

from apps.accounts.models import Address, Device, OTPRequest, User
from apps.accounts.services import auth as auth_service
from apps.accounts.services import profile as profile_service
from apps.accounts.tasks import anonymise_deleted_accounts, purge_old_otp_requests, send_otp_sms
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core.exceptions import ApiError

pytestmark = pytest.mark.django_db

REFRESH = "/api/v1/auth/token/refresh/"
LOGOUT = "/api/v1/auth/logout/"
ME = "/api/v1/me/"
DEVICES = "/api/v1/me/devices/"
DELETE = "/api/v1/me/delete/"
TEST_PHONE = "+919000000002"  # fixed OTP 123456


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


def device_body(fcm="fcm-token-1", app="customer"):
    return {"fcm_token": fcm, "app": app, "platform": "android", "app_version": "1.0.0+12"}


class TestLogout:
    def test_revokes_refresh_and_deactivates_device(self, user, make_auth_client):
        client = make_auth_client(user)
        client.post(DEVICES, device_body(), format="json")
        _, refresh = auth_service.issue_tokens(user, "customer")
        response = client.post(LOGOUT, {"refresh": refresh, "fcm_token": "fcm-token-1"})
        assert response.status_code == 204
        assert not Device.objects.get(fcm_token="fcm-token-1").is_active
        err = error(APIClient().post(REFRESH, {"refresh": refresh}, format="json"), 401)
        assert err["message"] == "Token is blacklisted"

    @pytest.mark.parametrize("refresh", ["garbage", "already-used"])
    def test_is_idempotent(self, user, make_auth_client, refresh):
        client = make_auth_client(user)
        if refresh == "already-used":
            _, refresh = auth_service.issue_tokens(user, "customer")
            client.post(LOGOUT, {"refresh": refresh}, format="json")
        assert client.post(LOGOUT, {"refresh": refresh}, format="json").status_code == 204

    def test_does_not_revoke_another_users_token(self, user, make_auth_client):
        _, other_refresh = auth_service.issue_tokens(UserFactory(), "customer")
        assert make_auth_client(user).post(LOGOUT, {"refresh": other_refresh}).status_code == 204
        assert APIClient().post(REFRESH, {"refresh": other_refresh}).status_code == 200

    def test_validation_and_auth(self, api_client, auth_client):
        assert error(auth_client.post(LOGOUT, {}, format="json"), 400)["details"] == {
            "refresh": ["This field is required."]
        }
        assert error(api_client.post(LOGOUT, {"refresh": "x"}), 401)["code"] == "AUTH_REQUIRED"


class TestMe:
    def test_get(self, auth_client, user):
        body = auth_client.get(ME).json()
        assert body == {
            "id": user.pk,
            "phone": user.phone,
            "name": user.name,
            "email": None,
            "marketing_opt_in": False,
            "is_profile_complete": True,
            "rider_status": "NONE",
            "created_at": body["created_at"],
        }

    def test_update(self, auth_client, user):
        response = auth_client.patch(
            ME,
            {
                "name": "Asha Verma",
                "email": " Asha@Example.COM ",
                "marketing_opt_in": True,
                "phone": "+919999999999",
            },
            format="json",
        )
        assert response.status_code == 200
        user.refresh_from_db()
        assert (user.name, user.email, user.marketing_opt_in) == (
            "Asha Verma",
            "asha@example.com",
            True,
        )
        assert user.phone != "+919999999999"  # read-only

    @pytest.mark.parametrize("cleared", [None, ""])
    def test_clear_email(self, auth_client, user, cleared):
        user.email = "old@example.com"
        user.save()
        assert auth_client.patch(ME, {"email": cleared}, format="json").json()["email"] is None

    def test_email_of_another_account_is_rejected_generically(self, auth_client):
        StaffUserFactory(email="ops.lead@jivo.in")
        err = error(auth_client.patch(ME, {"email": "OPS.LEAD@jivo.in"}, format="json"), 400)
        assert err["details"] == {"email": ["This email can't be used."]}

    def test_email_race_is_rejected_generically(self, user, monkeypatch):
        StaffUserFactory(email="taken@jivo.in")
        monkeypatch.setattr(
            "apps.accounts.services.profile.User.objects.filter",
            lambda **kw: User.objects.none(),
        )
        with pytest.raises(ApiError) as excinfo:
            profile_service.update_profile(user, {"email": "taken@jivo.in"})
        assert excinfo.value.details == {"email": ["This email can't be used."]}

    def test_blank_name_rejected(self, auth_client):
        err = error(auth_client.patch(ME, {"name": ""}, format="json"), 400)
        assert err["details"] == {"name": ["This field may not be blank."]}

    def test_requires_auth(self, api_client):
        assert error(api_client.get(ME), 401)["code"] == "AUTH_REQUIRED"

    def test_blocked_user_token_is_rejected(self, user, make_auth_client):
        client = make_auth_client(user)
        user.is_active = False
        user.save()
        assert error(client.get(ME), 401)["code"] == "TOKEN_INVALID"


class TestDevices:
    def test_register_and_move_between_users(self, user, make_auth_client):
        response = make_auth_client(user).post(DEVICES, device_body(), format="json")
        assert response.status_code == 200
        body = response.json()
        assert body["fcm_token"] == "fcm-token-1"
        assert body["is_active"] is True

        other = UserFactory()
        moved = make_auth_client(other).post(
            DEVICES, {**device_body(app="rider"), "app_version": "2.0.0"}, format="json"
        )
        assert moved.status_code == 200
        device = Device.objects.get(fcm_token="fcm-token-1")
        assert (device.user, device.app, device.app_version) == (other, "rider", "2.0.0")
        assert Device.objects.count() == 1

    def test_reactivates_after_logout(self, user, make_auth_client):
        client = make_auth_client(user)
        client.post(DEVICES, device_body(), format="json")
        Device.objects.update(is_active=False)
        assert client.post(DEVICES, device_body(), format="json").json()["is_active"] is True

    def test_concurrent_first_registration_retries(self, user, monkeypatch):
        from django.db import IntegrityError

        real = Device.objects.update_or_create
        calls = []

        def flaky(**kwargs):
            calls.append(1)
            if len(calls) == 1:
                raise IntegrityError("duplicate key")
            return real(**kwargs)

        monkeypatch.setattr(Device.objects, "update_or_create", flaky)
        device = profile_service.register_device(
            user, fcm_token="t", app="customer", platform="ios", app_version="1.0.0"
        )
        assert device.pk is not None
        assert len(calls) == 2

    def test_validation_and_auth(self, api_client, auth_client):
        err = error(auth_client.post(DEVICES, device_body() | {"app_version": "1.x"}), 400)
        assert err["details"] == {
            "app_version": ["This value does not match the required pattern."]
        }
        assert error(api_client.post(DEVICES, device_body()), 401)["code"] == "AUTH_REQUIRED"


class TestDeleteAccount:
    @pytest.fixture
    def customer(self):
        return UserFactory(phone=TEST_PHONE)

    def request_delete_otp(self, phone=TEST_PHONE, purpose="delete_account"):
        response = APIClient().post(
            "/api/v1/auth/otp/request/",
            {"phone": phone, "app": "customer", "purpose": purpose},
            format="json",
        )
        assert response.status_code == 200

    @freeze_time("2026-11-02T10:15:00Z")
    def test_deletes_with_a_delete_account_otp(self, customer, make_auth_client):
        client = make_auth_client(customer)
        client.post(DEVICES, device_body(), format="json")
        _, refresh = auth_service.issue_tokens(customer, "customer")
        self.request_delete_otp()
        response = client.post(DELETE, {"otp": "123456", "reason": "Not needed"})
        assert response.status_code == 200
        assert response.json() == {
            "deleted_at": "2026-11-02T10:15:00Z",
            "anonymise_after": "2026-12-02T10:15:00Z",
        }
        customer.refresh_from_db()
        assert customer.deletion_reason == "Not needed"
        assert not Device.objects.get(fcm_token="fcm-token-1").is_active
        assert error(APIClient().post(REFRESH, {"refresh": refresh}), 401)["code"] == (
            "TOKEN_INVALID"
        )
        assert error(client.get(ME), 401)["code"] == "TOKEN_INVALID"  # access tokens too

    def test_login_otp_cannot_delete(self, customer, make_auth_client):
        self.request_delete_otp(purpose="login")
        err = error(make_auth_client(customer).post(DELETE, {"otp": "123456"}), 400)
        assert err["code"] == "OTP_EXPIRED"

    def test_wrong_otp(self, customer, make_auth_client):
        self.request_delete_otp()
        err = error(make_auth_client(customer).post(DELETE, {"otp": "654321"}), 400)
        assert err["code"] == "OTP_INVALID"

    def test_otp_of_another_phone_does_not_work(self, customer, make_auth_client):
        UserFactory(phone="+919000000003")
        self.request_delete_otp(phone="+919000000003")
        err = error(make_auth_client(customer).post(DELETE, {"otp": "123456"}), 400)
        assert err["code"] == "OTP_EXPIRED"

    def test_staff_cannot_delete_from_the_app(self, make_auth_client):
        err = error(make_auth_client(StaffUserFactory()).post(DELETE, {"otp": "123456"}), 403)
        assert err["message"] == "Staff accounts are deleted by an administrator."

    def test_validation_and_auth(self, api_client, auth_client):
        assert error(auth_client.post(DELETE, {"otp": "12"}), 400)["details"] == {
            "otp": ["Enter the 6-digit OTP."]
        }
        assert error(api_client.post(DELETE, {"otp": "123456"}), 401)["code"] == "AUTH_REQUIRED"


class TestAnonymisation:
    def deleted_user(self, days_ago):
        user = UserFactory(marketing_opt_in=True)
        user.email = f"user{user.pk}@example.com"
        user.deleted_at = timezone.now() - timedelta(days=days_ago)
        user.save()
        Address.objects.create(
            user=user,
            label="home",
            receiver_name="A",
            receiver_phone=user.phone,
            house="1",
            building_street="S",
            city="C",
            state="S",
            pincode="122001",
            lat=1,
            lng=1,
            is_default=True,
        )
        Device.objects.create(
            user=user,
            app="customer",
            platform="android",
            fcm_token=f"t-{user.pk}",
            app_version="1.0.0",
            last_seen_at=timezone.now(),
        )
        OTPRequest.objects.create(
            phone=user.phone,
            app="customer",
            code_hash="x",
            expires_at=timezone.now(),
        )
        return user

    def test_anonymises_after_the_grace_period_once(self):
        due = self.deleted_user(days_ago=31)
        in_grace = self.deleted_user(days_ago=29)
        assert anonymise_deleted_accounts() == 1
        due.refresh_from_db()
        assert (due.phone, due.email, due.name, due.is_active) == (None, None, "", False)
        assert not due.marketing_opt_in
        assert due.anonymised_at is not None
        assert not Address.objects.filter(user=due).exists()
        assert not Device.objects.filter(user=due).exists()
        assert OTPRequest.objects.filter(phone=in_grace.phone).exists()
        assert OTPRequest.objects.count() == 1
        in_grace.refresh_from_db()
        assert in_grace.phone is not None
        assert anonymise_deleted_accounts() == 0  # idempotent

    def test_anonymise_user_is_a_noop_for_live_or_missing_accounts(self):
        assert auth_service.anonymise_user(UserFactory().pk) is False
        assert auth_service.anonymise_user(999_999) is False

    def test_phone_signs_up_as_a_new_user_after_anonymisation(self):
        user = self.deleted_user(days_ago=40)
        phone = user.phone
        anonymise_deleted_accounts()
        APIClient().post(
            "/api/v1/auth/otp/request/", {"phone": phone, "app": "customer"}, format="json"
        )
        assert User.objects.filter(phone=phone).count() == 0


class TestTasks:
    def test_send_otp_sms_is_idempotent(self, django_capture_on_commit_callbacks):
        from apps.notifications import sms

        with django_capture_on_commit_callbacks(execute=True):
            APIClient().post(
                "/api/v1/auth/otp/request/",
                {"phone": "+919876543210", "app": "customer"},
                format="json",
            )
        otp = OTPRequest.objects.get()
        assert send_otp_sms(otp.pk, "123456") == "skipped"  # already sent
        assert send_otp_sms(999_999, "123456") == "skipped"
        assert len(sms.outbox) == 1

    def test_send_otp_sms_skips_expired(self):
        otp = OTPRequest.objects.create(
            phone="+919876543210",
            app="customer",
            code_hash="x",
            expires_at=timezone.now() - timedelta(seconds=1),
        )
        assert send_otp_sms(otp.pk, "123456") == "skipped"

    def test_purge_old_otp_requests(self):
        with freeze_time("2026-09-01T00:00:00Z"):
            OTPRequest.objects.create(
                phone="+919876543210", app="customer", code_hash="x", expires_at=timezone.now()
            )
        with freeze_time("2026-11-02T00:00:00Z"):
            OTPRequest.objects.create(
                phone="+919876543210", app="customer", code_hash="y", expires_at=timezone.now()
            )
            assert purge_old_otp_requests() == 1
        assert OTPRequest.objects.count() == 1
