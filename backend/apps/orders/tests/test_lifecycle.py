"""After placement (08 T3-T5, T3a): payment confirmation by verify or webhook, late and duplicate
captures (refunded), retry-payment, cancellation of an unpaid order, the payment-window expiry,
the order reads (IDOR, query counts) and `transition()` itself."""

import json
from datetime import timedelta
from decimal import Decimal

import pytest
from django.db import connection, transaction
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.core.exceptions import ApiError
from apps.inventory.models import ReservationStatus, StockReservation, StoreInventory
from apps.orders import services
from apps.orders.choices import OrderStatus
from apps.orders.models import Order, OrderStatusHistory
from apps.orders.tests.conftest import ORDERS, Checkout, new_key
from apps.orders.tests.factories import OrderFactory
from apps.payments.gateways import (
    FAKE_WEBHOOK_SECRET,
    FakeRazorpayGateway,
    GatewayPayment,
    PaymentGatewayError,
    razorpay_webhook_signature,
)
from apps.payments.models import Payment, PaymentWebhookEvent, Refund
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus

pytestmark = pytest.mark.django_db

WEBHOOK = "/api/v1/payments/razorpay/webhook/"


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


@pytest.fixture
def pending(checkout, shop):
    """An online order for 2 x canola 1 L (₹558) awaiting payment."""
    checkout.fill((shop.canola_1l, 2))
    return checkout.place("ONLINE")


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


def captured_event(
    gateway_order_id, payment_id="pay_WebhookPay0001", amount=55800, kind="payment.captured"
):
    return {
        "entity": "event",
        "event": kind,
        "payload": {
            "payment": {
                "entity": {
                    "id": payment_id,
                    "order_id": gateway_order_id,
                    "amount": amount,
                    "status": "captured" if kind == "payment.captured" else "failed",
                    "method": "upi",
                    "error_code": "BAD_REQUEST_ERROR" if kind == "payment.failed" else None,
                    "error_description": "Insufficient balance"
                    if kind == "payment.failed"
                    else None,
                }
            }
        },
    }


class TestVerify:
    def test_t3_places_the_order(self, checkout, shop, pending, django_capture_on_commit_callbacks):
        checkout.client.post(
            "/api/v1/cart/items/",
            {"variant_id": shop.chia.pk, "quantity": 1},
            headers=checkout.headers,
        )
        with django_capture_on_commit_callbacks(execute=True):
            order = checkout.verify(pending, "pay_VerifyPaymnt01")
        assert (order["status"], order["payment_status"]) == ("PLACED", "PAID")
        assert order["placed_at"]
        assert order["eta_at"]
        assert order["payment_expires_at"] is None
        assert order["can_retry_payment"] is False
        payment = Payment.objects.get(order_id=order["id"])
        assert (payment.status, payment.gateway_payment_id) == ("CAPTURED", "pay_VerifyPaymnt01")
        assert StockReservation.objects.get(order_id=order["id"]).expires_at is None
        assert reserved(shop, shop.canola_1l) == 2  # still reserved until pickup (T9)
        # Only the ordered line left the cart; the chia added meanwhile stays.
        assert [i["variant"]["id"] for i in checkout.cart()["items"]] == [shop.chia.pk]
        history = list(
            OrderStatusHistory.objects.filter(order_id=order["id"]).values_list(
                "to_status", flat=True
            )
        )
        assert history == ["PAYMENT_PENDING", "PLACED"]

    def test_a_second_verify_returns_the_placed_order(self, checkout, pending):
        first = checkout.verify(pending, "pay_VerifyPaymnt01")
        again = checkout.verify(pending, "pay_VerifyPaymnt01")
        assert again["status"] == first["status"] == "PLACED"
        assert OrderStatusHistory.objects.filter(order_id=first["id"]).count() == 2

    def test_bad_signature(self, checkout, pending):
        body = checkout.verify(pending, sig="0" * 64, status=400)
        assert body["error"]["code"] == "PAYMENT_VERIFICATION_FAILED"
        assert Order.objects.get().status == "PAYMENT_PENDING"

    def test_gateway_order_of_another_order(self, checkout, pending):
        pending = {
            **pending,
            "razorpay": {**pending["razorpay"], "order_id": "order_SomeoneElses01"},
        }
        assert (
            checkout.verify(pending, status=400)["error"]["code"] == "PAYMENT_VERIFICATION_FAILED"
        )

    def test_another_users_order_is_404(self, pending, shop, make_auth_client):
        other = make_auth_client(UserFactory())
        stranger = Checkout(other, shop, None)
        body = stranger.verify(pending, status=404)
        assert body["error"]["code"] == "NOT_FOUND"
        assert Order.objects.get().status == "PAYMENT_PENDING"

    def test_coupon_hold_becomes_used(self, checkout, shop):
        Coupon.objects.create(
            code="JIVO50", title="Flat", discount_type="FLAT", value=50, min_order_value=0
        )
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        placement = checkout.place("ONLINE")
        checkout.verify(placement)
        redemption = CouponRedemption.objects.get(order_id=placement["order"]["id"])
        assert redemption.status == RedemptionStatus.APPLIED
        assert checkout.cart()["coupon"] is None


class TestWebhook:
    def test_capture_places_the_order_once(self, checkout, pending, api_client):
        gateway_order = pending["razorpay"]["order_id"]
        response = webhook(api_client, captured_event(gateway_order), "evt_0001")
        assert response.json() == {"status": "processed"}
        assert Order.objects.get().status == "PLACED"
        assert webhook(api_client, captured_event(gateway_order), "evt_0001").json() == {
            "status": "duplicate"
        }
        # verify after the webhook: no-op, still 200 PLACED
        assert checkout.verify(pending, "pay_WebhookPay0001")["status"] == "PLACED"
        assert OrderStatusHistory.objects.filter(to_status="PLACED").count() == 1
        payment = Payment.objects.get()
        assert (payment.method, payment.status) == ("upi", "CAPTURED")
        assert PaymentWebhookEvent.objects.get(event_id="evt_0001").processed_at is not None

    def test_amount_mismatch_is_refunded_and_not_placed(
        self, checkout, pending, api_client, django_capture_on_commit_callbacks
    ):
        event = captured_event(pending["razorpay"]["order_id"], "pay_WrongAmount01", amount=100)
        with django_capture_on_commit_callbacks(execute=True):
            assert webhook(api_client, event, "evt_0002").json() == {"status": "processed"}
        order = Order.objects.get()
        assert (order.status, order.payment_status) == ("PAYMENT_PENDING", "PENDING")
        refund = Refund.objects.get()
        assert (refund.reason, refund.amount, refund.status) == (
            "amount_mismatch",
            Decimal("1.00"),
            "PROCESSED",
        )
        # The customer can still pay correctly, or cancel (the refunded capture does not block).
        response = checkout.client.post(
            f"{ORDERS}{order.pk}/cancel/", {"reason": "PAYMENT_PROBLEM"}
        )
        assert response.status_code == 200

    def test_payment_failed_never_overwrites_a_capture(self, checkout, pending, api_client):
        """Code review Minor 4: a late `payment.failed` for an attempt already captured."""
        checkout.verify(pending, "pay_CapturedFirst1")
        event = captured_event(pending["razorpay"]["order_id"], kind="payment.failed")
        assert webhook(api_client, event, "evt_failed_late").json() == {"status": "ignored"}
        assert Payment.objects.get().status == "CAPTURED"
        assert Order.objects.get().status == "PLACED"

    @pytest.mark.parametrize(
        ("payment_id", "order_id"),
        [
            ("pay_" + "A" * 61, None),  # 65 chars: would overflow gateway_payment_id (64)
            (
                "pay_" + "B" * 53,
                None,
            ),  # 57: too long for the refund key `capture:<id>`
            ("pay_Short", None),  # too short for a Razorpay id
            (
                "pay_WebhookPay0001",
                "order_" + "C" * 59,
            ),  # 65: too long for gateway_order_id
        ],
    )
    def test_bug_0009_oversized_ids_are_ignored_not_a_500(
        self, checkout, pending, api_client, payment_id, order_id
    ):
        """BUG-0009: every id is checked against the verify endpoint's Razorpay id patterns
        (`pay_`/`order_` + 10-40 characters, so at most 46 and always within the stored fields and
        the refund key). One that does not match is stored as malformed and answered `ignored`,
        never a 500."""
        order = Order.objects.get()
        services.cancel_order(order.user, order.pk, reason="OTHER")  # a capture now needs a refund
        event = captured_event(order_id or pending["razorpay"]["order_id"], payment_id)
        response = webhook(api_client, event, "evt_bug_0009")
        assert (response.status_code, response.json()) == (200, {"status": "ignored"})
        stored = PaymentWebhookEvent.objects.get(event_id="evt_bug_0009")
        assert stored.error == "malformed: ValueError"
        assert Refund.objects.count() == 0
        failed = captured_event("order_" + "D" * 59, kind="payment.failed")
        assert webhook(api_client, failed, "evt_bug_0009b").json() == {"status": "ignored"}

    def test_payment_failed_keeps_the_window_open(self, checkout, pending, api_client):
        event = captured_event(pending["razorpay"]["order_id"], kind="payment.failed")
        assert webhook(api_client, event, "evt_0003").json() == {"status": "processed"}
        payment = Payment.objects.get()
        assert (payment.status, payment.error_code) == ("FAILED", "BAD_REQUEST_ERROR")
        assert Order.objects.get().status == "PAYMENT_PENDING"
        retried = checkout.client.post(
            f"{ORDERS}{pending['order']['id']}/retry-payment/",
            headers={"Idempotency-Key": new_key()},
        )
        assert retried.status_code == 200
        assert webhook(api_client, event, "evt_0004").json() == {"status": "ignored"}

    @pytest.mark.parametrize(
        "event",
        [
            {"event": "order.paid", "payload": {}},
            {"event": "payment.captured", "payload": {"payment": {}}},  # malformed
            {
                "event": "payment.captured",
                "payload": {
                    "payment": {
                        "entity": {"id": "pay_x", "order_id": "order_Unknown0001", "amount": 1}
                    }
                },
            },
            {
                "event": "refund.processed",
                "payload": {"refund": {"entity": {"id": "rfnd_Unknown001"}}},
            },
        ],
    )
    def test_ignored_events(self, api_client, event):
        assert webhook(api_client, event, "evt_ignored").json() == {"status": "ignored"}
        assert PaymentWebhookEvent.objects.get().processed_at is not None


class TestLateAndDuplicateCaptures:
    """08 T3a and DL-45: a capture that cannot become a sale is refunded in full, automatically."""

    def test_capture_after_cancel_is_refunded(
        self, checkout, pending, api_client, django_capture_on_commit_callbacks
    ):
        order_id = pending["order"]["id"]
        checkout.client.post(f"{ORDERS}{order_id}/cancel/", {"reason": "CHANGE_PAYMENT_METHOD"})
        with django_capture_on_commit_callbacks(execute=True):
            body = checkout.verify(pending, "pay_LateCapture01", status=409)
        assert body["error"]["details"] == {"status": "CANCELLED"}
        refund = Refund.objects.get()
        assert (refund.reason, refund.amount, refund.status) == (
            "late_capture",
            Decimal("558.00"),
            "PROCESSED",
        )
        assert refund.gateway_refund_id.startswith("rfnd_")
        order = Order.objects.get()
        assert (order.status, order.payment_status, order.amount_refunded) == (
            "CANCELLED",
            "REFUNDED",
            Decimal("558.00"),
        )
        # The webhook for the same capture is a no-op
        event = captured_event(pending["razorpay"]["order_id"], payment_id="pay_LateCapture01")
        with django_capture_on_commit_callbacks(execute=True):
            assert webhook(api_client, event, "evt_late").json() == {"status": "processed"}
        assert Refund.objects.count() == 1

    def test_second_capture_on_a_paid_order_is_refunded(
        self, checkout, pending, django_capture_on_commit_callbacks
    ):
        order_id = pending["order"]["id"]
        retried = checkout.client.post(
            f"{ORDERS}{order_id}/retry-payment/", headers={"Idempotency-Key": new_key()}
        ).json()
        checkout.verify(pending, "pay_FirstCapture1")
        with django_capture_on_commit_callbacks(execute=True):
            again = checkout.verify(retried, "pay_SecondCaptur1")
        assert again["status"] == "PLACED"
        refund = Refund.objects.get()
        assert (refund.reason, refund.payment.gateway_payment_id) == (
            "duplicate_capture",
            "pay_SecondCaptur1",
        )
        order = Order.objects.get()
        assert (order.payment_status, order.amount_refunded) == ("PAID", Decimal("0.00"))

    def test_second_capture_on_the_same_gateway_order(
        self, checkout, pending, django_capture_on_commit_callbacks
    ):
        """Two captures on one gateway order: the second gets its own Payment row, refunded."""
        checkout.verify(pending, "pay_FirstCapture2")
        with django_capture_on_commit_callbacks(execute=True):
            result = services.capture_payment(
                pending["order"]["id"],
                gateway_order_id=pending["razorpay"]["order_id"],
                payment_id="pay_SameOrderTwo1",
            )
        assert result.outcome == "duplicate"
        extra = Payment.objects.get(gateway_payment_id="pay_SameOrderTwo1")
        assert (extra.gateway_order_id, extra.status) == ("", "CAPTURED")
        assert extra.raw["gateway_order_id"] == pending["razorpay"]["order_id"]
        assert Refund.objects.get().reason == "duplicate_capture"

    def test_refund_webhook_settles_a_pending_refund(
        self, checkout, pending, api_client, monkeypatch, django_capture_on_commit_callbacks
    ):
        from apps.payments.gateways import GatewayRefund

        monkeypatch.setattr(
            FakeRazorpayGateway,
            "refund",
            lambda self, **kw: GatewayRefund(
                "rfnd_Pending00001", kw["payment_id"], kw["amount_paise"], "pending"
            ),
        )
        order_id = pending["order"]["id"]
        checkout.client.post(f"{ORDERS}{order_id}/cancel/", {"reason": "OTHER"})
        with django_capture_on_commit_callbacks(execute=True):
            checkout.verify(pending, "pay_LateCapture02", status=409)
        assert Refund.objects.get().status == "PENDING"
        assert Order.objects.get().payment_status == "REFUND_PENDING"
        event = {
            "event": "refund.processed",
            "payload": {"refund": {"entity": {"id": "rfnd_Pending00001"}}},
        }
        assert webhook(api_client, event, "evt_rfnd").json() == {"status": "processed"}
        assert (Refund.objects.get().status, Order.objects.get().payment_status) == (
            "PROCESSED",
            "REFUNDED",
        )


class TestRetryPayment:
    def url(self, placement):
        return f"{ORDERS}{placement['order']['id']}/retry-payment/"

    def test_new_checkout_same_window(self, checkout, pending):
        key = new_key()
        body = checkout.client.post(self.url(pending), headers={"Idempotency-Key": key}).json()
        assert body["razorpay"]["order_id"] != pending["razorpay"]["order_id"]
        assert body["razorpay"]["expires_at"] == pending["razorpay"]["expires_at"]
        again = checkout.client.post(self.url(pending), headers={"Idempotency-Key": key}).json()
        assert again["razorpay"]["order_id"] == body["razorpay"]["order_id"]
        assert Payment.objects.count() == 2

    def test_refused_once_paid(self, checkout, pending):
        """Customer app review: never a second payment on a paid order."""
        checkout.verify(pending)
        response = checkout.client.post(self.url(pending), headers={"Idempotency-Key": new_key()})
        assert response.status_code == 409
        assert response.json()["error"] == {
            "code": "INVALID_STATE_TRANSITION",
            "message": "This order is already paid.",
            "details": {"status": "PLACED"},
        }

    def test_refused_after_the_window_by_server_time(self, checkout, pending):
        Order.objects.update(payment_expires_at=timezone.now() - timedelta(seconds=1))
        response = checkout.client.post(self.url(pending), headers={"Idempotency-Key": new_key()})
        assert response.status_code == 409
        assert (
            response.json()["error"]["message"]
            == "The payment window has ended. Place the order again."
        )
        assert response.json()["error"]["details"] == {"status": "PAYMENT_PENDING"}

    def test_refused_for_cod_and_failed(self, checkout, shop, user):
        checkout.fill((shop.canola_1l, 2))
        cod = checkout.place("COD")
        response = checkout.client.post(self.url(cod), headers={"Idempotency-Key": new_key()})
        assert response.json()["error"]["message"] == "This order is no longer awaiting payment."
        failed = OrderFactory(
            user=user,
            status="PAYMENT_FAILED",
            payment_method="ONLINE",
            payment_status="FAILED",
            placed_at=None,
        )
        response = checkout.client.post(
            f"{ORDERS}{failed.pk}/retry-payment/", headers={"Idempotency-Key": new_key()}
        )
        assert (
            response.json()["error"]["message"]
            == "The payment window has ended. Place the order again."
        )

    def test_another_users_order_is_404(self, pending, make_auth_client):
        other = make_auth_client(UserFactory())
        response = other.post(self.url(pending), headers={"Idempotency-Key": new_key()})
        assert response.status_code == 404

    def test_gateway_down(self, checkout, pending, monkeypatch):
        def down(self, **kwargs):
            raise PaymentGatewayError("timeout")

        monkeypatch.setattr(FakeRazorpayGateway, "create_order", down)
        response = checkout.client.post(self.url(pending), headers={"Idempotency-Key": new_key()})
        assert response.status_code == 503


class TestCancel:
    def test_t5_releases_stock_and_coupon(self, checkout, shop):
        Coupon.objects.create(
            code="JIVO50", title="Flat", discount_type="FLAT", value=50, min_order_value=0
        )
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        placement = checkout.place("ONLINE")
        order_id = placement["order"]["id"]
        assert reserved(shop, shop.canola_1l) == 2
        response = checkout.client.post(
            f"{ORDERS}{order_id}/cancel/", {"reason": "CHANGE_PAYMENT_METHOD"}
        )
        assert response.status_code == 200
        body = response.json()
        assert (body["status"], body["payment_status"], body["can_cancel"]) == (
            "CANCELLED",
            "FAILED",
            False,
        )
        assert reserved(shop, shop.canola_1l) == 0
        assert StockReservation.objects.get(order_id=order_id).status == ReservationStatus.RELEASED
        assert CouponRedemption.objects.get(order_id=order_id).status == RedemptionStatus.RELEASED
        assert Payment.objects.get(order_id=order_id).status == "FAILED"
        order = Order.objects.get(pk=order_id)
        assert (order.cancel_reason, order.cancelled_by_type) == (
            "CHANGE_PAYMENT_METHOD",
            "customer",
        )
        # The cart is kept, so the customer can pay another way.
        assert checkout.cart()["items"]
        assert checkout.place("COD")["order"]["status"] == "PLACED"

    def test_placed_orders_too_from_phase_4(self, checkout, shop):
        """08 §7 / T11 (Phase 4): a PLACED order is cancellable; a second cancel is a 409."""
        checkout.fill((shop.canola_1l, 2))
        cod = checkout.place("COD")
        url = f"{ORDERS}{cod['order']['id']}/cancel/"
        assert checkout.client.post(url, {"reason": "OTHER"}).status_code == 200
        response = checkout.client.post(url, {"reason": "OTHER"})
        assert response.status_code == 409
        assert response.json()["error"]["details"] == {"status": "CANCELLED"}

    def test_another_users_order_is_404(self, pending, make_auth_client):
        other = make_auth_client(UserFactory())
        assert (
            other.post(f"{ORDERS}{pending['order']['id']}/cancel/", {"reason": "OTHER"}).status_code
            == 404
        )
        assert Order.objects.get().status == "PAYMENT_PENDING"


class TestExpiry:
    def expire(self):
        Order.objects.update(payment_expires_at=timezone.now() - timedelta(seconds=1))
        return services.expire_unpaid_orders()

    def test_t4_fails_and_releases(self, shop, pending):
        assert self.expire() == {"failed": 1}
        order = Order.objects.get()
        assert (order.status, order.payment_status) == ("PAYMENT_FAILED", "FAILED")
        assert order.payment_failed_at is not None
        assert reserved(shop, shop.canola_1l) == 0
        assert services.expire_unpaid_orders() == {}  # idempotent

    def test_not_due_yet(self, pending):
        assert services.expire_unpaid_orders() == {}
        assert services.expire_order(pending["order"]["id"]) == "skipped"

    def test_a_capture_found_at_the_gateway_places_the_order(self, pending, monkeypatch):
        """08 §4 rule 3: a missed webhook is caught before failing the order."""
        monkeypatch.setattr(
            FakeRazorpayGateway,
            "fetch_order_payments",
            lambda self, gateway_order_id: [
                GatewayPayment("pay_MissedHook001", gateway_order_id, 55800, "captured", "card")
            ],
        )
        assert self.expire() == {"placed": 1}
        assert Order.objects.get().status == "PLACED"

    def test_a_wrong_amount_capture_never_blocks_expiry(
        self, shop, pending, monkeypatch, django_capture_on_commit_callbacks
    ):
        """Advisor (R2b): a capture of the wrong amount is refunded and the order still fails,
        so its stock is released instead of being held forever."""
        monkeypatch.setattr(
            FakeRazorpayGateway,
            "fetch_order_payments",
            lambda self, gateway_order_id: [
                GatewayPayment("pay_WrongAmount02", gateway_order_id, 100, "captured", "upi")
            ],
        )
        with django_capture_on_commit_callbacks(execute=True):
            assert self.expire() == {"failed": 1}
        assert Order.objects.get().status == "PAYMENT_FAILED"
        assert reserved(shop, shop.canola_1l) == 0
        assert Refund.objects.get().reason == "amount_mismatch"
        with django_capture_on_commit_callbacks(execute=True):
            Order.objects.update(status="PAYMENT_PENDING", payment_expires_at=timezone.now())
            assert services.expire_unpaid_orders() == {"failed": 1}  # already recorded: no-op
        assert Refund.objects.count() == 1

    def test_gateway_down_postpones(self, pending, monkeypatch):
        def down(self, gateway_order_id):
            raise PaymentGatewayError("timeout")

        monkeypatch.setattr(FakeRazorpayGateway, "fetch_order_payments", down)
        assert self.expire() == {"error": 1}
        assert Order.objects.get().status == "PAYMENT_PENDING"

    def test_fake_gateway_reports_known_captures(self, checkout, pending):
        checkout.verify(pending, "pay_KnownCapture01")
        found = FakeRazorpayGateway().fetch_order_payments(pending["razorpay"]["order_id"])
        assert [(p.id, p.status, p.amount_paise) for p in found] == [
            ("pay_KnownCapture01", "captured", 55800)
        ]

    def test_beat_task(self, pending):
        from apps.orders.tasks import expire_unpaid_orders

        Order.objects.update(payment_expires_at=timezone.now() - timedelta(seconds=1))
        assert expire_unpaid_orders.delay().get() == {"failed": 1}


class TestReads:
    def test_detail_and_idor(self, checkout, pending, make_auth_client):
        order_id = pending["order"]["id"]
        response = checkout.client.get(f"{ORDERS}{order_id}/")
        assert response.status_code == 200
        assert response.json() == pending["order"] | {"can_retry_payment": True}
        other = make_auth_client(UserFactory())
        response = other.get(f"{ORDERS}{order_id}/")
        assert response.status_code == 404
        assert response.json()["error"]["message"] == "Order not found."

    def test_list_filters_and_order(self, checkout, shop, user):
        old = OrderFactory(user=user, status="CANCELLED", placed_at=None)
        checkout.fill((shop.canola_1l, 2))
        active = checkout.place("COD")["order"]["id"]
        OrderFactory(user=UserFactory())  # someone else's: never listed
        assert [o["id"] for o in checkout.client.get(ORDERS).json()["results"]] == [active, old.pk]
        assert [
            o["id"] for o in checkout.client.get(f"{ORDERS}?status=active").json()["results"]
        ] == [active]
        past = checkout.client.get(f"{ORDERS}?status=past").json()
        assert [o["id"] for o in past["results"]] == [old.pk]
        row = checkout.client.get(f"{ORDERS}?status=active").json()["results"][0]
        assert (row["grand_total"], row["item_count"], len(row["images"])) == ("558.00", 2, 0)

    def test_list_query_count_is_constant(self, checkout, shop, user):
        """Rule 15: the order list never queries per order."""

        def count():
            with CaptureQueriesContext(connection) as queries:
                assert checkout.client.get(ORDERS).status_code == 200
            return len(queries)

        checkout.fill((shop.canola_1l, 1), (shop.chia, 1))
        checkout.place("COD")
        one = count()
        for _ in range(4):
            OrderFactory(user=user, status="DELIVERED")
        assert count() == one
        assert one <= 8

    def test_pending_order_shows_up_for_recovery(self, checkout, pending):
        rows = checkout.client.get(f"{ORDERS}?status=active").json()["results"]
        assert rows[0]["status"] == "PAYMENT_PENDING"
        assert rows[0]["can_retry_payment"] is True


class TestTransition:
    def test_table_and_history(self, user):
        order = OrderFactory(
            user=user,
            status="PAYMENT_PENDING",
            payment_method="ONLINE",
            payment_status="PENDING",
            placed_at=None,
        )
        with transaction.atomic():
            services.transition(
                order,
                OrderStatus.PAYMENT_FAILED,
                actor_type="system",
                note="x",
                payment_status="FAILED",
            )
        order.refresh_from_db()
        assert (order.status, order.payment_status) == ("PAYMENT_FAILED", "FAILED")
        assert order.payment_failed_at is not None
        history = OrderStatusHistory.objects.get(order=order)
        assert (history.from_status, history.to_status, history.actor_type) == (
            "PAYMENT_PENDING",
            "PAYMENT_FAILED",
            "system",
        )

    @pytest.mark.parametrize(
        ("from_status", "to_status"),
        [
            ("PLACED", "PAYMENT_FAILED"),
            ("PAYMENT_FAILED", "PLACED"),  # T3a: never revived
            ("CANCELLED", "PLACED"),
            ("PLACED", "PACKED"),  # Phase 4: T6/T7 first
            ("PAYMENT_PENDING", "DELIVERED"),
        ],
    )
    def test_anything_not_listed_is_refused(self, user, from_status, to_status):
        order = OrderFactory(user=user, status=from_status)
        with transaction.atomic(), pytest.raises(ApiError) as caught:
            services.transition(order, to_status, actor_type="system")
        assert (caught.value.status_code, caught.value.error_code) == (
            409,
            "INVALID_STATE_TRANSITION",
        )
        assert caught.value.details == {"status": from_status}

    def test_history_is_append_only(self, user):
        from django.core.exceptions import ValidationError

        order = OrderFactory(user=user, status="PAYMENT_PENDING", placed_at=None)
        with transaction.atomic():
            services.transition(order, OrderStatus.CANCELLED, actor_type="customer")
        history = OrderStatusHistory.objects.get()
        with pytest.raises(ValidationError):
            history.save()
        with pytest.raises(ValidationError):
            OrderStatusHistory.objects.all().delete()


def test_order_numbers(user):
    from datetime import UTC, datetime

    assert (
        services.order_number(123, datetime(2026, 11, 2, 19, 0, tzinfo=UTC)) == "JV-261103-000123"
    )


def test_event_task_logs(caplog):
    from apps.orders.tasks import order_event

    assert order_event("payment.late_capture", 5) == "payment.late_capture"
    assert "Ops alert" in caplog.text
    assert order_event("order.placed", 5) == "order.placed"
