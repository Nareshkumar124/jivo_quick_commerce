"""Error envelope: every API error is {"error": {"code", "message", "details"}} (02 §5, 06 §6)."""

import logging

import pytest
from rest_framework_simplejwt.tokens import AccessToken

from apps.core.errors import ERROR_HTTP_STATUS, ErrorCode, error_payload
from apps.core.exceptions import ApiError

pytestmark = pytest.mark.urls("apps.core.tests.urls")


def assert_envelope(response, status: int, code: str) -> dict:
    assert response.status_code == status, response.content
    body = response.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code
    assert isinstance(body["error"]["message"], str)
    assert body["error"]["message"]
    assert isinstance(body["error"]["details"], dict)
    return body["error"]


class TestErrorCodes:
    def test_every_code_has_an_http_status(self):
        assert set(ERROR_HTTP_STATUS) == set(ErrorCode)

    @pytest.mark.parametrize(
        ("code", "status"),
        [
            # Spot checks against the 06 §6 table.
            (ErrorCode.VALIDATION_ERROR, 400),
            (ErrorCode.OTP_RATE_LIMITED, 429),
            (ErrorCode.TOKEN_INVALID, 401),
            (ErrorCode.APP_UPDATE_REQUIRED, 426),
            (ErrorCode.NOT_SERVICEABLE, 422),
            (ErrorCode.STOCK_UNAVAILABLE, 409),
            (ErrorCode.INVALID_STATE_TRANSITION, 409),
            (ErrorCode.DELIVERY_OTP_LOCKED, 423),
            (ErrorCode.MAINTENANCE, 503),
        ],
    )
    def test_documented_statuses(self, code, status):
        assert ERROR_HTTP_STATUS[code] == status

    def test_error_payload_defaults_message_to_label_and_details_to_empty(self):
        assert error_payload("NOT_FOUND") == {
            "error": {"code": "NOT_FOUND", "message": "Not found.", "details": {}}
        }

    def test_error_payload_rejects_unknown_codes(self):
        with pytest.raises(ValueError, match="NOPE"):
            error_payload("NOPE")

    def test_api_error_defaults(self):
        exc = ApiError(ErrorCode.PRICE_CHANGED)
        assert exc.status_code == 409
        assert exc.message == "The bill has changed. Refresh the cart."
        assert exc.details == {}


class TestExceptionHandler:
    def test_api_error_with_details(self, api_client):
        error = assert_envelope(api_client.get("/t/raise/api_error/"), 409, "STOCK_UNAVAILABLE")
        assert error["details"] == {"items": [{"variant_id": 7, "available": 0}]}

    def test_api_error_with_custom_message_and_status(self, api_client):
        error = assert_envelope(api_client.get("/t/raise/api_error_custom/"), 410, "NOT_FOUND")
        assert error["message"] == "Order not found."

    def test_serializer_validation_error_lists_fields(self, api_client):
        response = api_client.post("/t/echo/", {"name": "too long", "quantity": 0}, format="json")
        error = assert_envelope(response, 400, "VALIDATION_ERROR")
        assert set(error["details"]) == {"name", "quantity"}
        assert all(isinstance(messages, list) for messages in error["details"].values())

    def test_list_validation_error_goes_under_non_field_errors(self, api_client):
        error = assert_envelope(
            api_client.get("/t/raise/validation_list/"), 400, "VALIDATION_ERROR"
        )
        assert error["details"] == {"non_field_errors": ["First.", "Second."]}

    def test_valid_request_passes_through(self, api_client):
        response = api_client.post("/t/echo/", {"name": "ok", "quantity": 2}, format="json")
        assert response.status_code == 200
        assert response.json() == {"name": "ok", "quantity": 2}

    def test_malformed_json_is_a_validation_error(self, api_client):
        response = api_client.post("/t/echo/", data="{not json", content_type="application/json")
        assert_envelope(response, 400, "VALIDATION_ERROR")

    def test_unsupported_media_type(self, api_client):
        response = api_client.post("/t/echo/", data="name=x", content_type="text/plain")
        assert_envelope(response, 415, "UNSUPPORTED_MEDIA_TYPE")

    def test_method_not_allowed(self, api_client):
        assert_envelope(api_client.delete("/t/echo/"), 405, "METHOD_NOT_ALLOWED")

    def test_not_acceptable(self, api_client):
        assert_envelope(api_client.get("/t/raise/not_acceptable/"), 406, "NOT_ACCEPTABLE")

    def test_django_http404_hides_internal_message(self, api_client):
        error = assert_envelope(api_client.get("/t/raise/http404/"), 404, "NOT_FOUND")
        assert "internal detail" not in error["message"]

    def test_django_permission_denied(self, api_client):
        error = assert_envelope(
            api_client.get("/t/raise/django_permission/"), 403, "PERMISSION_DENIED"
        )
        assert "internal detail" not in error["message"]

    def test_structured_detail_on_other_errors_uses_the_default_message(self, api_client):
        error = assert_envelope(
            api_client.get("/t/raise/permission_dict/"), 403, "PERMISSION_DENIED"
        )
        assert error["message"] == "You do not have permission to do this."
        assert error["details"] == {}

    def test_django_validation_error_with_fields(self, api_client):
        error = assert_envelope(
            api_client.get("/t/raise/django_validation_dict/"), 400, "VALIDATION_ERROR"
        )
        assert error["details"] == {"phone": ["Bad phone."]}

    def test_django_validation_error_plain(self, api_client):
        error = assert_envelope(
            api_client.get("/t/raise/django_validation_plain/"), 400, "VALIDATION_ERROR"
        )
        assert error["details"] == {"non_field_errors": ["Plain problem."]}

    def test_throttled_sets_retry_after(self, api_client):
        response = api_client.get("/t/raise/throttled/")
        error = assert_envelope(response, 429, "RATE_LIMITED")
        assert error["details"] == {"retry_after_seconds": 13}
        assert response["Retry-After"] == "13"

    def test_unknown_api_exception_status_falls_back_to_server_error_code(self, api_client):
        assert_envelope(api_client.get("/t/raise/teapot/"), 418, "SERVER_ERROR")

    def test_api_exception_503_maps_to_service_unavailable(self, api_client):
        assert_envelope(api_client.get("/t/raise/unavailable/"), 503, "SERVICE_UNAVAILABLE")

    def test_unexpected_exception_is_logged_and_hidden(self, api_client, caplog):
        with caplog.at_level(logging.ERROR, logger="apps.core.exceptions"):
            response = api_client.get("/t/raise/unexpected/")
        error = assert_envelope(response, 500, "SERVER_ERROR")
        assert "secret internals" not in response.content.decode()
        assert error["message"] == "Something went wrong. Please try again."
        assert any(record.exc_info for record in caplog.records)


@pytest.mark.django_db
class TestAuthenticationErrors:
    """simplejwt + session authentication behind the default IsAuthenticated permission."""

    def test_missing_credentials_is_auth_required(self, api_client):
        response = api_client.get("/t/whoami/")
        assert_envelope(response, 401, "AUTH_REQUIRED")
        assert response["WWW-Authenticate"].startswith("Bearer")

    def test_garbage_token_is_token_invalid(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer not-a-jwt")
        error = assert_envelope(api_client.get("/t/whoami/"), 401, "TOKEN_INVALID")
        assert error["details"] == {}

    def test_valid_access_token_authenticates(self, api_client, user):
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
        response = api_client.get("/t/whoami/")
        assert response.status_code == 200
        assert response.json() == {"user_id": user.pk}

    def test_token_of_inactive_user_is_rejected(self, api_client, user):
        token = AccessToken.for_user(user)
        user.is_active = False
        user.save()
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        assert_envelope(api_client.get("/t/whoami/"), 401, "TOKEN_INVALID")

    def test_api_is_token_only_so_a_staff_session_is_not_enough(self, api_client, staff_user):
        api_client.force_login(staff_user)
        assert_envelope(api_client.get("/t/whoami/"), 401, "AUTH_REQUIRED")


class TestOtpThrottling:
    def test_otp_views_report_otp_rate_limited(self, api_client):
        from django.core.cache import cache

        cache.clear()  # test Redis DB only (config/settings/test.py)
        assert api_client.get("/t/otp-throttled/").status_code == 200
        response = api_client.get("/t/otp-throttled/")
        error = assert_envelope(response, 429, "OTP_RATE_LIMITED")
        wait = error["details"]["retry_after_seconds"]
        assert int(response["Retry-After"]) == wait > 0
        # Same message format as the documented example.
        assert error["message"] == (
            f"Too many OTP requests. Try again later. Expected available in {wait} seconds."
        )


class TestThrottling:
    def test_second_request_is_rate_limited(self, api_client):
        from django.core.cache import cache

        cache.clear()  # test Redis DB only (config/settings/test.py)
        assert api_client.get("/t/throttled/").status_code == 200
        response = api_client.get("/t/throttled/")
        error = assert_envelope(response, 429, "RATE_LIMITED")
        assert error["details"]["retry_after_seconds"] > 0
        assert int(response["Retry-After"]) > 0
