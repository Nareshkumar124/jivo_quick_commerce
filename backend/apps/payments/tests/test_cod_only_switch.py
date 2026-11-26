"""DL-85: the "cash on delivery only" switch (`ONLINE_PAYMENTS_ENABLED`).

Off: online checkout, payment retry, verify and the webhook without a secret answer 503
`SERVICE_UNAVAILABLE` (reason `ONLINE_PAYMENTS_DISABLED`) before any gateway call; the cart
reports ONLINE unavailable; COD works; `payments.E003` is not raised. On (default): unchanged.
"""

import json

import pytest
from django.core.checks import run_checks

from apps.accounts.tests.factories import UserFactory
from apps.core.exceptions import ApiError
from apps.inventory.models import StoreInventory
from apps.orders.models import Order
from apps.orders.tests.conftest import ORDERS, VERIFY, new_key, sign
from apps.payments import gateways
from apps.payments.gateways import FAKE_WEBHOOK_SECRET, razorpay_webhook_signature
from apps.payments.models import Payment, PaymentWebhookEvent
from apps.payments.switch import (
    MSG_ONLINE_DISABLED,
    REASON,
    ensure_online_payments_enabled,
    online_payments_enabled,
)

pytestmark = pytest.mark.django_db

WEBHOOK = "/api/v1/payments/razorpay/webhook/"
RAZORPAY = "apps.payments.gateways.RazorpayGateway"
FAKE = "apps.payments.gateways.FakeRazorpayGateway"


def assert_disabled(response):
    assert response.status_code == 503, response.content
    error = response.json()["error"]
    assert error["code"] == "SERVICE_UNAVAILABLE"
    assert error["details"] == {"reason": REASON}


def online_option(cart: dict) -> dict:
    return next(o for o in cart["payment_methods"] if o["method"] == "ONLINE")


def cod_option(cart: dict) -> dict:
    return next(o for o in cart["payment_methods"] if o["method"] == "COD")


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


@pytest.fixture
def cod_only(settings):
    settings.ONLINE_PAYMENTS_ENABLED = False
    return settings


@pytest.fixture
def no_gateway_calls(monkeypatch):
    """Any gateway load fails the test: COD-only must never reach Razorpay."""

    def boom():
        raise AssertionError("the payment gateway must not be used while online is off")

    for module in ("apps.orders.services", "apps.payments.services", "apps.payments.views"):
        monkeypatch.setattr(f"{module}.get_gateway", boom)
    monkeypatch.setattr(gateways, "get_gateway", boom)


def webhook(client, event: dict, event_id: str):
    raw = json.dumps(event).encode()
    return client.generic(
        "POST",
        WEBHOOK,
        raw,
        content_type="application/json",
        headers={
            "X-Razorpay-Signature": razorpay_webhook_signature(FAKE_WEBHOOK_SECRET, raw),
            "X-Razorpay-Event-Id": event_id,
        },
    )


def captured_event(gateway_order_id: str, amount: int) -> dict:
    return {
        "entity": "event",
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": "pay_SwitchPay00001",
                    "order_id": gateway_order_id,
                    "amount": amount,
                    "status": "captured",
                    "method": "upi",
                }
            }
        },
    }


# --------------------------------------------------------------------------- the switch


def test_default_is_on(settings):
    assert settings.ONLINE_PAYMENTS_ENABLED is True
    assert online_payments_enabled()
    ensure_online_payments_enabled()  # no error


def test_off_raises_the_documented_error(cod_only):
    assert not online_payments_enabled()
    with pytest.raises(ApiError) as caught:
        ensure_online_payments_enabled()
    assert caught.value.error_code == "SERVICE_UNAVAILABLE"
    assert caught.value.status_code == 503
    assert REASON == "ONLINE_PAYMENTS_DISABLED"


# --------------------------------------------------------------------------- the cart


def test_cart_offers_online_when_on(checkout, shop):
    cart = checkout.fill((shop.canola_1l, 2))
    assert online_option(cart) == {
        "method": "ONLINE",
        "is_available": True,
        "unavailable_reason": None,
        "message": None,
    }


def test_cart_reports_online_unavailable_when_off(checkout, shop, cod_only):
    cart = checkout.fill((shop.canola_1l, 2))
    assert online_option(cart) == {
        "method": "ONLINE",
        "is_available": False,
        "unavailable_reason": "ONLINE_DISABLED",
        "message": MSG_ONLINE_DISABLED,
    }
    assert cod_option(cart)["is_available"] is True


# --------------------------------------------------------------------------- POST /orders/


def test_online_order_refused_before_anything_is_held(checkout, shop, cod_only, no_gateway_calls):
    checkout.fill((shop.canola_1l, 2))
    before = reserved(shop, shop.canola_1l)
    response = checkout.client.post(
        ORDERS,
        {
            "address_id": checkout.address.pk,
            "payment_method": "ONLINE",
            "expected_grand_total": checkout.cart()["bill"]["grand_total"],
        },
        headers={**checkout.headers, "Idempotency-Key": new_key()},
    )
    assert_disabled(response)
    assert response.json()["error"]["message"] == MSG_ONLINE_DISABLED
    assert not Order.objects.exists()
    assert not Payment.objects.exists()
    assert reserved(shop, shop.canola_1l) == before


def test_cod_order_still_works_when_off(checkout, shop, cod_only, no_gateway_calls):
    checkout.fill((shop.canola_1l, 2))
    placed = checkout.place("COD")
    assert placed["order"]["status"] == "PLACED"
    assert placed["razorpay"] is None


def test_real_gateway_without_keys_cod_only(checkout, shop, settings):
    """The production case: Razorpay gateway, no keys, switch off. COD places, ONLINE is a
    clean 503 (never the 500 of the unconfigured gateway)."""
    settings.ONLINE_PAYMENTS_ENABLED = False
    settings.PAYMENT_GATEWAY = RAZORPAY
    for name in ("RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET"):
        setattr(settings, name, "")
    cart = checkout.fill((shop.canola_1l, 2))
    assert online_option(cart)["is_available"] is False
    response = checkout.client.post(
        ORDERS,
        {
            "address_id": checkout.address.pk,
            "payment_method": "ONLINE",
            "expected_grand_total": cart["bill"]["grand_total"],
        },
        headers={**checkout.headers, "Idempotency-Key": new_key()},
    )
    assert_disabled(response)
    assert checkout.place("COD")["order"]["status"] == "PLACED"
    assert_disabled(webhook(checkout.client, captured_event("order_X", 100), "evt_cod_only_1"))


# --------------------------------------------------------------------------- retry, verify


@pytest.fixture
def pending(checkout, shop):
    """An ONLINE order placed while the switch was on, still awaiting payment."""
    checkout.fill((shop.canola_1l, 2))
    return checkout.place("ONLINE")


def test_retry_payment_refused_when_off(checkout, pending, cod_only, no_gateway_calls):
    order_id = pending["order"]["id"]
    response = checkout.client.post(
        f"{ORDERS}{order_id}/retry-payment/", headers={"Idempotency-Key": new_key()}
    )
    assert_disabled(response)
    assert Payment.objects.filter(order_id=order_id).count() == 1


def test_retry_payment_idor_is_404_when_off(pending, cod_only, make_auth_client):
    other = make_auth_client(UserFactory())
    response = other.post(
        f"{ORDERS}{pending['order']['id']}/retry-payment/",
        headers={"Idempotency-Key": new_key()},
    )
    assert response.status_code == 404


def test_order_detail_offers_no_retry_when_off(checkout, pending, settings):
    url = f"{ORDERS}{pending['order']['id']}/"
    assert checkout.client.get(url).json()["can_retry_payment"] is True
    settings.ONLINE_PAYMENTS_ENABLED = False
    assert checkout.client.get(url).json()["can_retry_payment"] is False


def verify_body(pending: dict) -> dict:
    gateway_order_id = pending["razorpay"]["order_id"]
    return {
        "order_id": pending["order"]["id"],
        "razorpay_order_id": gateway_order_id,
        "razorpay_payment_id": "pay_TestPayment0001",
        "razorpay_signature": sign(gateway_order_id, "pay_TestPayment0001"),
    }


def test_verify_refused_when_off(checkout, pending, cod_only, no_gateway_calls):
    assert_disabled(checkout.client.post(VERIFY, verify_body(pending)))
    assert Order.objects.get().status == "PAYMENT_PENDING"


def test_verify_idor_is_404_when_off(pending, cod_only, make_auth_client):
    other = make_auth_client(UserFactory())
    assert other.post(VERIFY, verify_body(pending)).status_code == 404


def test_verify_still_works_when_on(checkout, pending):
    assert checkout.verify(pending)["status"] == "PLACED"


def test_verify_unauthenticated(api_client, cod_only):
    assert api_client.post(VERIFY, {}).status_code == 401


# --------------------------------------------------------------------------- webhook


def test_webhook_without_secret_answers_503_and_stores_nothing(api_client, cod_only, settings):
    settings.RAZORPAY_WEBHOOK_SECRET = ""
    assert_disabled(webhook(api_client, captured_event("order_X", 100), "evt_off_1"))
    assert not PaymentWebhookEvent.objects.exists()


def test_webhook_with_secret_still_applies_events_when_off(api_client, checkout, pending, settings):
    """A payment started before the switch went off is still confirmed by its signed event."""
    settings.ONLINE_PAYMENTS_ENABLED = False
    settings.RAZORPAY_WEBHOOK_SECRET = "configured"
    order = Order.objects.get()
    event = captured_event(pending["razorpay"]["order_id"], int(order.grand_total * 100))
    response = webhook(api_client, event, "evt_off_2")
    assert response.status_code == 200
    assert response.json() == {"status": "processed"}
    order.refresh_from_db()
    assert order.status == "PLACED"


# --------------------------------------------------------------------------- system checks


def deploy_errors(settings, *, online: bool, gateway: str = RAZORPAY) -> set[str]:
    settings.APP_ENVIRONMENT = "production"
    settings.OTP_TEST_NUMBERS = {}
    settings.PAYMENT_GATEWAY = gateway
    settings.ALLOWED_HOSTS = ["api.jivo.in"]
    settings.ONLINE_PAYMENTS_ENABLED = online
    for name in ("RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET"):
        setattr(settings, name, "")
    return {e.id for e in run_checks(include_deployment_checks=True)}


def test_e003_fires_when_on(settings):
    assert "payments.E003" in deploy_errors(settings, online=True)


def test_e003_skipped_when_off(settings):
    assert "payments.E003" not in deploy_errors(settings, online=False)


def test_fake_gateway_still_refused_when_off(settings):
    ids = deploy_errors(settings, online=False, gateway=FAKE)
    assert "payments.E001" in ids
