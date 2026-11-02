"""Phase 1 R1 contract: routes, authentication requirements, real token refresh, and request
validation messages that match the documented examples. Behaviour (OTP, profile, addresses,
IDOR) is tested in R2 when the views are implemented."""

import pytest
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts import views
from apps.accounts.serializers import (
    AccountDeleteSerializer,
    AddressSerializer,
    DeviceSerializer,
    MeSerializer,
    OtpSendSerializer,
    OtpVerifySerializer,
)
from apps.accounts.tests.factories import UserFactory
from apps.cms.views import AppConfigView

PROTECTED = [
    ("post", "/api/v1/auth/logout/"),
    ("get", "/api/v1/me/"),
    ("patch", "/api/v1/me/"),
    ("post", "/api/v1/me/delete/"),
    ("post", "/api/v1/me/devices/"),
    ("get", "/api/v1/addresses/"),
    ("post", "/api/v1/addresses/"),
    ("get", "/api/v1/addresses/1/"),
    ("patch", "/api/v1/addresses/1/"),
    ("delete", "/api/v1/addresses/1/"),
    ("post", "/api/v1/addresses/1/set-default/"),
]


@pytest.mark.django_db
@pytest.mark.parametrize(("method", "path"), PROTECTED)
def test_protected_endpoints_require_a_token(api_client, method, path):
    response = getattr(api_client, method)(path, {}, format="json")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


@pytest.mark.parametrize(
    "view", [views.OtpRequestView, views.OtpVerifyView, views.TokenRefreshView, AppConfigView]
)
def test_public_auth_views_never_authenticate(view):
    # A stale or garbage Bearer token must not turn these into 401s.
    assert list(view.authentication_classes) == []


def test_address_detail_allows_only_documented_methods(api_client):
    assert "put" not in views.AddressDetailView.http_method_names
    assert "put" not in views.MeView.http_method_names


@pytest.mark.django_db
class TestTokenRefresh:
    """Real in R1: simplejwt with rotation and blacklist (02 §5, 09 §3.1)."""

    URL = "/api/v1/auth/token/refresh/"

    def test_rotates_and_revokes_the_old_refresh_token(self, api_client):
        old = str(RefreshToken.for_user(UserFactory()))
        response = api_client.post(self.URL, {"refresh": old}, format="json")
        assert response.status_code == 200
        body = response.json()
        assert set(body) == {"access", "refresh"}
        assert body["refresh"] != old

        reused = api_client.post(self.URL, {"refresh": old}, format="json")
        assert reused.status_code == 401
        assert reused.json()["error"] == {
            "code": "TOKEN_INVALID",
            "message": "Token is blacklisted",
            "details": {},
        }
        assert reused["WWW-Authenticate"].startswith("Bearer")

        again = api_client.post(self.URL, {"refresh": body["refresh"]}, format="json")
        assert again.status_code == 200

    def test_garbage_token(self, api_client):
        response = api_client.post(self.URL, {"refresh": "garbage"}, format="json")
        assert response.status_code == 401
        assert response.json()["error"]["message"] == "Token is invalid"

    def test_ignores_a_stale_access_token_header(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer expired-or-garbage")
        refresh = str(RefreshToken.for_user(UserFactory()))
        assert api_client.post(self.URL, {"refresh": refresh}, format="json").status_code == 200

    def test_inactive_user_cannot_refresh(self, api_client):
        user = UserFactory()
        refresh = str(RefreshToken.for_user(user))
        user.is_active = False
        user.save()
        response = api_client.post(self.URL, {"refresh": refresh}, format="json")
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "TOKEN_INVALID"

    def test_missing_token_is_a_validation_error(self, api_client):
        response = api_client.post(self.URL, {}, format="json")
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"refresh": ["This field is required."]}


class TestRequestValidationMatchesExamples:
    """The validation-error examples in the schema use the real messages."""

    def test_otp_send(self):
        serializer = OtpSendSerializer(data={"phone": "9876543210", "app": "customer"})
        assert not serializer.is_valid()
        assert serializer.errors["phone"] == [
            "Enter a 10-digit Indian mobile number in the form +919876543210."
        ]
        ok = OtpSendSerializer(data={"phone": "+919876543210", "app": "rider"})
        assert ok.is_valid(), ok.errors
        assert ok.validated_data["purpose"] == "login"

    @pytest.mark.parametrize("phone", ["+911234567890", "+9198765432100", "+14155550123"])
    def test_only_indian_mobiles(self, phone):
        assert not OtpSendSerializer(data={"phone": phone, "app": "customer"}).is_valid()

    def test_otp_verify(self):
        serializer = OtpVerifySerializer(
            data={"phone": "+919876543210", "otp": "12345", "app": "customer"}
        )
        assert not serializer.is_valid()
        assert serializer.errors["otp"] == ["Enter the 6-digit OTP."]
        assert AccountDeleteSerializer(data={"otp": "739204"}).is_valid()

    def test_me_patch(self):
        serializer = MeSerializer(data={"name": ""}, partial=True)
        assert not serializer.is_valid()
        assert serializer.errors["name"] == ["This field may not be blank."]
        assert MeSerializer(data={"email": None, "marketing_opt_in": True}, partial=True).is_valid()

    @pytest.mark.parametrize(
        ("email", "expected"),
        [("", None), ("   ", None), (None, None), (" a@jivo.in ", "a@jivo.in")],
    )
    def test_me_email_blank_means_none(self, email, expected):
        serializer = MeSerializer(data={"email": email}, partial=True)
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data["email"] == expected

    @pytest.mark.parametrize("email", ["not-an-email", 42, "a@" + "b" * 260 + ".in"])
    def test_me_email_invalid(self, email):
        serializer = MeSerializer(data={"email": email}, partial=True)
        assert not serializer.is_valid()
        assert serializer.errors["email"] == ["Enter a valid email address."]

    def test_device(self):
        data = {"fcm_token": "t", "app": "customer", "platform": "android", "app_version": "1.x"}
        serializer = DeviceSerializer(data=data)
        assert not serializer.is_valid()
        assert serializer.errors["app_version"] == [
            "This value does not match the required pattern."
        ]
        assert DeviceSerializer(data={**data, "app_version": "1.0.0+12"}).is_valid()

    def test_address(self):
        from apps.accounts import examples as ex

        missing = {k: v for k, v in ex.ADDRESS_CREATE_REQUEST.items() if k not in {"lat", "lng"}}
        serializer = AddressSerializer(data={**missing, "pincode": "012345"})
        assert not serializer.is_valid()
        assert serializer.errors == {
            "pincode": ["Enter a 6-digit PIN code."],
            "lat": ["This field is required."],
            "lng": ["This field is required."],
        }
        assert AddressSerializer(data=ex.ADDRESS_CREATE_REQUEST).is_valid()
        assert AddressSerializer(data={"landmark": "Gate 2"}, partial=True).is_valid()
