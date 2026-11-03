"""Regression tests for QA run 1 bugs in accounts (qa/bugs/BUG-0002, -0003, -0004, -0007), the
T-205 receiver semantics and the Address location sync (P2 code review #7)."""

import threading
from decimal import Decimal
from unittest import mock

import pytest
from django.contrib.gis.geos import Point
from django.db import connection
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts import examples as ex
from apps.accounts.models import Address, OTPRequest
from apps.accounts.services import addresses, auth
from apps.accounts.tests.factories import UserFactory
from apps.accounts.validators import indian_mobile_validator, otp_code_validator, pincode_validator
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.middleware import ClientInfo

pytestmark = pytest.mark.django_db

ADDRESSES = "/api/v1/addresses/"
REFRESH = "/api/v1/auth/token/refresh/"

# Digits from other scripts: Devanagari, full-width, Arabic-Indic, superscript.
DEVANAGARI_0, FULLWIDTH_1, ARABIC_9 = "\u0966", "\uff11", "\u0669"


def _error(response, status: int) -> dict:
    assert response.status_code == status, response.content
    return response.json()["error"]


# --------------------------------------------------------------------------- BUG-0002


class TestAsciiDigitsOnly:
    """BUG-0002: phone, OTP, PIN code and version inputs accept ASCII digits only."""

    @pytest.mark.parametrize(
        "phone",
        [
            f"+91999990{DEVANAGARI_0}098",
            f"+9199999{FULLWIDTH_1}0098",
            f"+919{ARABIC_9}99900098",
        ],
    )
    def test_otp_request_rejects_non_ascii_phone(self, api_client, phone):
        """BUG-0002: 400 VALIDATION_ERROR, and no OTPRequest row is stored."""
        response = api_client.post(
            "/api/v1/auth/otp/request/", {"phone": phone, "app": "customer"}, format="json"
        )
        assert _error(response, 400)["code"] == "VALIDATION_ERROR"
        assert not OTPRequest.objects.filter(phone=phone).exists()

    def test_otp_verify_rejects_full_width_code_without_spending_an_attempt(self, api_client):
        """BUG-0002: a full-width OTP is a validation error, not a wrong-code attempt."""
        response = api_client.post(
            "/api/v1/auth/otp/verify/",
            {
                "phone": "+919876543210",
                "otp": "\uff11\uff12\uff13\uff14\uff15\uff16",
                "app": "customer",
                "terms_version": "2026-01",
            },
            format="json",
        )
        error = _error(response, 400)
        assert error["code"] == "VALIDATION_ERROR"
        assert "otp" in error["details"]

    @pytest.mark.parametrize(
        ("field", "value"),
        [
            ("pincode", f"1{DEVANAGARI_0}2001"),
            ("pincode", "1\u0968\u0968\u0966\u0966\u0967"),
            ("receiver_phone", f"+9198123{FULLWIDTH_1}5678"),
        ],
    )
    def test_address_rejects_non_ascii_digits(self, auth_client, field, value):
        """BUG-0002: the address is not created."""
        response = auth_client.post(
            ADDRESSES, {**ex.ADDRESS_CREATE_REQUEST, field: value}, format="json"
        )
        assert field in _error(response, 400)["details"]
        assert not Address.objects.exists()

    def test_device_rejects_non_ascii_app_version(self, auth_client):
        response = auth_client.post(
            "/api/v1/me/devices/",
            {
                "fcm_token": "t" * 40,
                "app": "customer",
                "platform": "android",
                "app_version": "1.\u0664",
            },
            format="json",
        )
        assert "app_version" in _error(response, 400)["details"]

    @pytest.mark.parametrize(
        ("validator", "value"),
        [
            (indian_mobile_validator, f"+9198765{ARABIC_9}3210"),
            (otp_code_validator, "12345" + DEVANAGARI_0),
            (pincode_validator, "12200" + FULLWIDTH_1),
        ],
    )
    def test_validators_reject_other_scripts(self, validator, value):
        from django.core.exceptions import ValidationError

        with pytest.raises(ValidationError):
            validator(value)

    def test_model_phone_validator_and_client_version_header(self):
        from django.core.exceptions import ValidationError

        user = UserFactory.build(phone=f"+9198765{ARABIC_9}3210")
        with pytest.raises(ValidationError):
            user.full_clean(exclude=["password"])
        info = ClientInfo.from_headers({"X-App-Version": "1.\u0664.0", "X-App-Name": "customer"})
        assert info.app_version is None

    def test_published_patterns_are_ascii(self):
        """The OpenAPI patterns use [0-9], never \\d (Unicode-aware in Python)."""
        from apps.core.middleware import APP_VERSION_PATTERN

        for pattern in (
            indian_mobile_validator.regex.pattern,
            otp_code_validator.regex.pattern,
            pincode_validator.regex.pattern,
            APP_VERSION_PATTERN,
        ):
            assert "\\d" not in pattern


# --------------------------------------------------------------------------- BUG-0003


class TestRefreshTokenSingleUse:
    """BUG-0003: a refresh token is redeemed exactly once, whatever the timing."""

    def test_second_redemption_fails_even_if_the_fast_check_is_skipped(self, api_client):
        """BUG-0003: with simplejwt's pre-check bypassed (the window two concurrent requests
        share), the atomic redemption still lets only the first request through."""
        refresh = str(RefreshToken.for_user(UserFactory()))
        with mock.patch.object(RefreshToken, "check_blacklist", return_value=None):
            first = api_client.post(REFRESH, {"refresh": refresh}, format="json")
            second = api_client.post(REFRESH, {"refresh": refresh}, format="json")
        assert first.status_code == 200
        assert _error(second, 401) == {
            "code": "TOKEN_INVALID",
            "message": "Token is blacklisted",
            "details": {},
        }
        assert second["WWW-Authenticate"].startswith("Bearer")

    def test_rotation_keeps_the_app_claim_and_records_the_new_token(self):
        user = UserFactory()
        _, refresh = auth.issue_tokens(user, "rider")
        access, rotated = auth.rotate_refresh_token(refresh)
        new = RefreshToken(rotated)
        assert new["app"] == "rider"
        assert OutstandingToken.objects.filter(jti=new["jti"], user=user).exists()
        old_jti = RefreshToken(refresh, verify=False)["jti"]
        assert BlacklistedToken.objects.filter(token__jti=old_jti).exists()
        assert access

    def test_a_token_without_an_outstanding_row_is_still_single_use(self):
        """Defensive: a validly signed token whose row is missing gets one, then is used up."""
        refresh = RefreshToken.for_user(UserFactory())
        OutstandingToken.objects.filter(jti=refresh["jti"]).delete()
        auth.rotate_refresh_token(str(refresh))
        from rest_framework_simplejwt.exceptions import TokenError

        with pytest.raises(TokenError):
            auth.rotate_refresh_token(str(refresh))

    def test_unknown_or_blocked_user_cannot_refresh(self, api_client):
        user = UserFactory()
        refresh = str(RefreshToken.for_user(user))
        user.delete()
        response = api_client.post(REFRESH, {"refresh": refresh}, format="json")
        assert _error(response, 401)["code"] == "TOKEN_INVALID"


@pytest.mark.django_db(transaction=True)
def test_concurrent_refresh_with_one_token_succeeds_once():
    """BUG-0003 (P1-TC-24c): N parallel refreshes of one token: exactly one succeeds."""
    refresh = str(RefreshToken.for_user(UserFactory()))
    results: list[str] = []
    barrier = threading.Barrier(6)

    def redeem():
        try:
            barrier.wait()
            auth.rotate_refresh_token(refresh)
            results.append("ok")
        except Exception as exc:  # TokenError for the losers
            results.append(type(exc).__name__)
        finally:
            connection.close()

    threads = [threading.Thread(target=redeem) for _ in range(6)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=30)
    assert results.count("ok") == 1
    assert sorted(set(results) - {"ok"}) == ["TokenError"]


# --------------------------------------------------------------------------- BUG-0004


class TestAddressListInvalidPage:
    """BUG-0004: the invalid-page 404 is real and documented."""

    @pytest.mark.parametrize("page", ["0", "99", "abc"])
    def test_invalid_page_is_404(self, auth_client, page):
        assert _error(auth_client.get(ADDRESSES, {"page": page}), 404) == {
            "code": "NOT_FOUND",
            "message": "Invalid page.",
            "details": {},
        }

    def test_documented_in_the_schema(self):
        from drf_spectacular.generators import SchemaGenerator

        schema = SchemaGenerator().get_schema(request=None, public=True)
        responses = schema["paths"]["/api/v1/addresses/"]["get"]["responses"]
        assert "404" in responses
        examples = responses["404"]["content"]["application/json"]["examples"]
        assert any(e["value"]["error"]["message"] == "Invalid page." for e in examples.values())


# --------------------------------------------------------------------------- BUG-0007


def _address(user, **overrides) -> Address:
    return addresses.create_address(
        user, {**ex.ADDRESS_CREATE_REQUEST, "lat": 28.46, "lng": 77.08, **overrides}
    )


def _defaults(user) -> list[int]:
    return list(addresses.live_addresses(user).filter(is_default=True).values_list("pk", flat=True))


class TestDefaultAddressUnderConcurrency:
    """BUG-0007: decisions use the rows read under the user lock, not a stale object."""

    def test_set_default_with_a_stale_object_still_sets_it(self, user):
        """BUG-0007: request Y loaded A1 while it was the default; request Z then moved the
        default to A2; Y's set-default must leave A1 as the one default (never zero)."""
        a1, a2 = _address(user), _address(user)
        stale_a1 = Address.objects.get(pk=a1.pk)  # is_default=True in memory
        addresses.set_default(Address.objects.get(pk=a2.pk))  # request Z commits
        result = addresses.set_default(stale_a1)  # request Y
        assert result.is_default is True
        assert _defaults(user) == [a1.pk]

    def test_set_default_on_a_concurrently_deleted_address_is_404(self, user):
        a1, a2 = _address(user), _address(user)
        stale_a2 = Address.objects.get(pk=a2.pk)
        addresses.delete_address(Address.objects.get(pk=a2.pk))
        with pytest.raises(ApiError) as caught:
            addresses.set_default(stale_a2)
        assert caught.value.error_code == ErrorCode.NOT_FOUND
        assert _defaults(user) == [a1.pk]

    def test_delete_reads_was_default_under_the_lock(self, user):
        """BUG-0007: deleting an address loaded before it became the default still promotes
        a successor."""
        a1, a2 = _address(user), _address(user)
        stale_a2 = Address.objects.get(pk=a2.pk)  # is_default=False in memory
        addresses.set_default(Address.objects.get(pk=a2.pk))
        addresses.delete_address(stale_a2)
        assert _defaults(user) == [a1.pk]

    def test_deleting_twice_is_a_no_op(self, user):
        a1 = _address(user)
        addresses.delete_address(Address.objects.get(pk=a1.pk))
        addresses.delete_address(Address.objects.get(pk=a1.pk))
        assert not addresses.live_addresses(user).exists()

    def test_patch_never_writes_a_stale_default_or_resurrects(self, user):
        a1, a2 = _address(user), _address(user)
        stale_a1 = Address.objects.get(pk=a1.pk)  # is_default=True in memory
        addresses.set_default(Address.objects.get(pk=a2.pk))
        addresses.update_address(stale_a1, {"landmark": "Gate 2"})
        assert _defaults(user) == [a2.pk]
        stale = Address.objects.get(pk=a1.pk)
        addresses.delete_address(Address.objects.get(pk=a1.pk))
        with pytest.raises(ApiError):
            addresses.update_address(stale, {"landmark": "Gate 3"})
        assert Address.objects.get(pk=a1.pk).is_deleted


@pytest.mark.django_db(transaction=True)
def test_concurrent_set_default_always_leaves_one_default():
    """BUG-0007 (P1-TC-57): 10 concurrent set-default calls over 5 addresses end with exactly
    one default, the one set by the last committed call."""
    user = UserFactory()
    ids = [_address(user).pk for _ in range(5)]
    barrier = threading.Barrier(10)
    errors: list[Exception] = []

    def call(address_id):
        try:
            address = Address.objects.get(pk=address_id)  # loaded before the lock, like the view
            barrier.wait()
            addresses.set_default(address)
        except Exception as exc:
            errors.append(exc)
        finally:
            connection.close()

    threads = [threading.Thread(target=call, args=(pk,)) for pk in ids * 2]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=30)
    assert errors == []
    assert len(_defaults(user)) == 1


# --------------------------------------------------------------------------- T-205 and review #7


class TestReceiverSemantics:
    """T-205: "" resets receiver_name/receiver_phone to the user's own; null is rejected."""

    def test_null_is_a_validation_error(self, auth_client):
        address = auth_client.post(ADDRESSES, ex.ADDRESS_CREATE_REQUEST, format="json").json()
        response = auth_client.patch(
            f"{ADDRESSES}{address['id']}/", {"receiver_name": None}, format="json"
        )
        assert "receiver_name" in _error(response, 400)["details"]


class TestAddressLocationFollowsCoordinates:
    """Review #7: Address.save() keeps `location` in step with lat/lng for any writer."""

    def test_direct_writes_sync_the_point(self, user):
        address = _address(user)
        address.lat, address.lng = Decimal("28.500000"), Decimal("77.100000")
        address.save()
        address.refresh_from_db()
        assert (address.location.x, address.location.y) == (77.1, 28.5)

    def test_update_fields_with_coordinates_includes_location(self, user):
        address = _address(user)
        address.lat = Decimal("28.400000")
        address.save(update_fields=["lat", "updated_at"])
        address.refresh_from_db()
        assert address.location.y == pytest.approx(28.4)

    def test_saves_of_other_fields_leave_the_point_alone(self, user):
        address = _address(user)
        Address.objects.filter(pk=address.pk).update(location=Point(1, 1, srid=4326))
        address.landmark = "x"
        address.save(update_fields=["landmark", "updated_at"])
        address.refresh_from_db()
        assert (address.location.x, address.location.y) == (1, 1)
