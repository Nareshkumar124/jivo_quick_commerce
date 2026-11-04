"""Phase 3 R1 contract: payment verify (JWT) and the Razorpay webhook (signature only, exempt
from the 426/503 app guards). Payment behaviour (T3, T3a, idempotent events) is tested in R2."""

import json

import pytest
from django.urls import reverse

from apps.cms.models import AppConfig
from apps.payments import examples as ex
from apps.payments.gateways import FAKE_WEBHOOK_SECRET, razorpay_webhook_signature
from apps.payments.serializers import PaymentVerifySerializer

VERIFY = "/api/v1/payments/razorpay/verify/"
WEBHOOK = "/api/v1/payments/razorpay/webhook/"
EVENT_ID = "evt_Nq3vB2cD3eF4gH"


def test_routes():
    assert reverse("payments-razorpay-verify") == VERIFY
    assert reverse("payments-razorpay-webhook") == WEBHOOK


def signed(body: dict) -> tuple[bytes, dict]:
    raw = json.dumps(body, separators=(",", ":")).encode()
    return raw, {"X-Razorpay-Signature": razorpay_webhook_signature(FAKE_WEBHOOK_SECRET, raw)}


def post_raw(client, raw: bytes, headers: dict):
    return client.generic("POST", WEBHOOK, raw, content_type="application/json", headers=headers)


@pytest.mark.django_db
class TestVerify:
    def test_authentication_required(self, api_client):
        response = api_client.post(VERIFY, ex.VERIFY_REQUEST)
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "AUTH_REQUIRED"

    def test_malformed_signature_matches_the_example(self, auth_client):
        response = auth_client.post(VERIFY, {**ex.VERIFY_REQUEST, "razorpay_signature": "zz"})
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "razorpay_signature": ["This value does not match the required pattern."]
        }

    def test_non_ascii_signature_is_a_validation_error(self, auth_client):
        response = auth_client.post(VERIFY, {**ex.VERIFY_REQUEST, "razorpay_signature": "é" * 64})
        assert response.status_code == 400
        assert set(response.json()["error"]["details"]) == {"razorpay_signature"}

    def test_valid_request_for_an_unknown_order(self, auth_client):
        response = auth_client.post(VERIFY, ex.VERIFY_REQUEST)
        assert response.status_code == 404
        assert response.json()["error"]["message"] == "Order not found."

    @pytest.mark.parametrize(
        ("field", "value"),
        [
            ("razorpay_order_id", "pay_Nq3uVxY7kL9pQe"),
            ("razorpay_order_id", "order_short"),
            ("razorpay_payment_id", "order_Nq3vA1bC2dE3fG"),
            ("razorpay_signature", "A" * 64),
            ("order_id", 0),
        ],
    )
    def test_field_formats(self, field, value):
        serializer = PaymentVerifySerializer(data={**ex.VERIFY_REQUEST, field: value})
        assert not serializer.is_valid()
        assert set(serializer.errors) == {field}


@pytest.mark.django_db
class TestWebhook:
    def test_valid_signed_event_for_an_unknown_order_is_ignored(self, api_client):
        raw, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        response = post_raw(api_client, raw, {**headers, "X-Razorpay-Event-Id": EVENT_ID})
        assert response.status_code == 200
        assert response.json() == {"status": "ignored"}

    def test_no_jwt_needed_and_a_garbage_token_is_ignored(self, api_client):
        raw, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        api_client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
        response = post_raw(api_client, raw, {**headers, "X-Razorpay-Event-Id": EVENT_ID})
        assert response.status_code == 200  # not 401

    @pytest.mark.parametrize(
        "signature", [None, "", "0" * 64, razorpay_webhook_signature("wrong-secret", b"{}")]
    )
    def test_bad_signature(self, api_client, signature):
        raw, _ = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        headers = {"X-Razorpay-Event-Id": EVENT_ID}
        if signature is not None:
            headers["X-Razorpay-Signature"] = signature
        response = post_raw(api_client, raw, headers)
        assert response.status_code == 400
        assert response.json()["error"] == {
            "code": "PAYMENT_VERIFICATION_FAILED",
            "message": "The webhook signature is invalid.",
            "details": {},
        }

    @pytest.mark.parametrize("signature", ["é" * 64, "\u0663" * 64])
    def test_non_ascii_signature_is_400_not_500(self, api_client, signature):
        """Code review of R1: compare_digest on non-ASCII str raised TypeError (500)."""
        raw, _ = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        headers = {"X-Razorpay-Signature": signature, "X-Razorpay-Event-Id": EVENT_ID}
        response = post_raw(api_client, raw, headers)
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "PAYMENT_VERIFICATION_FAILED"

    def test_signature_covers_the_exact_bytes(self, api_client):
        """Re-serialising the same JSON differently breaks the signature (raw body HMAC)."""
        _, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        reformatted = json.dumps(ex.WEBHOOK_PAYMENT_CAPTURED, indent=2).encode()
        response = post_raw(api_client, reformatted, {**headers, "X-Razorpay-Event-Id": EVENT_ID})
        assert response.status_code == 400

    def test_event_id_required(self, api_client):
        raw, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        response = post_raw(api_client, raw, headers)
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "X-Razorpay-Event-Id": ["This header is required."]
        }

    def test_body_must_be_an_event(self, api_client):
        raw, headers = signed({"hello": "world"})
        response = post_raw(api_client, raw, {**headers, "X-Razorpay-Event-Id": EVENT_ID})
        assert response.status_code == 400
        assert set(response.json()["error"]["details"]) == {"event", "payload"}

    def test_exempt_from_maintenance(self, api_client, auth_client):
        """A payment event is never refused during maintenance; the app endpoints are."""
        AppConfig.objects.update_or_create(pk=1, defaults={"maintenance": True})
        raw, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        response = post_raw(api_client, raw, {**headers, "X-Razorpay-Event-Id": EVENT_ID})
        assert response.status_code == 200
        assert post_raw(api_client, raw, {"X-Razorpay-Event-Id": EVENT_ID}).status_code == 400
        verify = auth_client.post(VERIFY, ex.VERIFY_REQUEST)
        assert verify.json()["error"]["code"] == "MAINTENANCE"

    def test_exempt_from_force_update(self, api_client):
        from apps.cms.models import AppVersionPolicy

        AppVersionPolicy.objects.create(
            config=AppConfig.load(),
            app="customer",
            platform="android",
            min_supported_version="9.0.0",
            latest_version="9.0.0",
            store_url="https://play.google.com/store/apps/details?id=in.jivo.quick",
        )
        raw, headers = signed(ex.WEBHOOK_PAYMENT_CAPTURED)
        old_app = {"X-App-Name": "customer", "X-Platform": "android", "X-App-Version": "1.0.0"}
        response = post_raw(
            api_client, raw, {**headers, **old_app, "X-Razorpay-Event-Id": EVENT_ID}
        )
        assert response.status_code != 426
