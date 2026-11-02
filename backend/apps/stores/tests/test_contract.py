"""Phase 2 R1 contract: serviceability and notify-me routes, authentication behaviour, request
validation messages that match the documented examples, the `X-Store-Id` header rules, and the
additive `is_serviceable` on addresses. Serviceability itself (stores, service areas, ETA,
notify-me storage) is tested in R2 when the services exist."""

import pytest
from django.urls import reverse
from rest_framework.test import APIRequestFactory

from apps.accounts import examples as accounts_ex
from apps.stores import examples as ex
from apps.stores import views
from apps.stores.context import HEADER_INVALID, HEADER_REQUIRED, store_id_from_header
from apps.stores.serializers import NotifyMeSerializer, ServiceabilityQuerySerializer

SERVICEABILITY = "/api/v1/serviceability/"
NOTIFY_ME = "/api/v1/serviceability/notify-me/"


def test_routes():
    assert reverse("serviceability") == SERVICEABILITY
    assert reverse("serviceability-notify-me") == NOTIFY_ME


def test_serviceability_ignores_credentials():
    # A stale or garbage Bearer token must never block the location step.
    assert list(views.ServiceabilityView.authentication_classes) == []


@pytest.mark.django_db
class TestServiceabilityValidation:
    def test_missing_coordinates(self, api_client):
        response = api_client.get(SERVICEABILITY)
        assert response.status_code == 400
        assert response.json()["error"] == {
            "code": "VALIDATION_ERROR",
            "message": "Some fields are invalid.",
            "details": {"lat": ["This field is required."], "lng": ["This field is required."]},
        }

    def test_garbage_token_is_ignored(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
        assert api_client.get(SERVICEABILITY).status_code == 400  # not 401

    def test_out_of_range(self):
        serializer = ServiceabilityQuerySerializer(data={"lat": "91", "lng": "77.02"})
        assert not serializer.is_valid()
        assert serializer.errors == {"lat": ["Ensure this value is less than or equal to 90."]}

    def test_valid(self):
        serializer = ServiceabilityQuerySerializer(data={"lat": "28.4595", "lng": "77.0266"})
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data == {"lat": 28.4595, "lng": 77.0266}


@pytest.mark.django_db
class TestNotifyMe:
    """Public with optional authentication (06 §2.3: Public/Customer)."""

    def test_anonymous_invalid_body_is_a_validation_error(self, api_client):
        response = api_client.post(NOTIFY_ME, {"lng": 77.45, "phone": "12345"}, format="json")
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "lat": ["This field is required."],
            "phone": ["Enter a 10-digit Indian mobile number in the form +919876543210."],
        }

    def test_a_sent_token_is_checked(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
        response = api_client.post(NOTIFY_ME, ex.NOTIFY_ME_REQUEST, format="json")
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "TOKEN_INVALID"

    @pytest.mark.parametrize(
        "body", [ex.NOTIFY_ME_REQUEST, ex.NOTIFY_ME_ANONYMOUS_REQUEST, {"lat": 1, "lng": 2}]
    )
    def test_documented_requests_are_valid(self, body):
        serializer = NotifyMeSerializer(data=body)
        assert serializer.is_valid(), serializer.errors

    def test_phone_may_be_null(self):
        assert NotifyMeSerializer(data={**ex.NOTIFY_ME_REQUEST, "phone": None}).is_valid()


class TestStoreHeader:
    """`X-Store-Id` rules (apps.stores.context): format errors are 400 VALIDATION_ERROR."""

    factory = APIRequestFactory()

    def parse(self, **headers):
        from rest_framework.request import Request

        return store_id_from_header(Request(self.factory.get("/", headers=headers)))

    @pytest.mark.parametrize(("raw", "expected"), [("1", 1), (" 42 ", 42), ("007", 7)])
    def test_valid(self, raw, expected):
        assert self.parse(**{"X-Store-Id": raw}) == expected

    @pytest.mark.parametrize("raw", [None, "", "   "])
    def test_missing(self, raw):
        from rest_framework.exceptions import ValidationError

        headers = {} if raw is None else {"X-Store-Id": raw}
        with pytest.raises(ValidationError) as exc:
            self.parse(**headers)
        assert exc.value.detail == {"X-Store-Id": [HEADER_REQUIRED]}

    @pytest.mark.parametrize("raw", ["abc", "0", "-1", "1.5", "1e3", "\u0661", "9" * 19])
    def test_invalid(self, raw):
        from rest_framework.exceptions import ValidationError

        with pytest.raises(ValidationError) as exc:
            self.parse(**{"X-Store-Id": raw})
        assert exc.value.detail == {"X-Store-Id": [HEADER_INVALID]}


@pytest.mark.django_db
def test_addresses_carry_is_serviceable(make_auth_client, user):
    """03 §2.4: unserviceable addresses can be saved but are flagged (additive in Phase 2)."""
    client = make_auth_client(user)
    created = client.post("/api/v1/addresses/", accounts_ex.ADDRESS_CREATE_REQUEST, format="json")
    assert created.status_code == 201
    assert isinstance(created.json()["is_serviceable"], bool)
    listed = client.get("/api/v1/addresses/").json()["results"][0]
    assert isinstance(listed["is_serviceable"], bool)
