"""Phase 3 R1 contract: order routes, authentication, the `Idempotency-Key` and `X-Store-Id`
headers, request validation messages that match the documented examples, and consistent money
and states in every example. Order behaviour (T1-T5, reservations, idempotency) is tested in R2.
"""

from datetime import datetime, timedelta
from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts.tests.factories import UserFactory
from apps.cart import examples as cart_ex
from apps.core.idempotency import KEY_INVALID, KEY_REQUIRED
from apps.orders import examples as ex
from apps.orders.choices import ACTIVE_STATUSES, TERMINAL_STATUSES, OrderStatus
from apps.orders.serializers import (
    OrderCancelSerializer,
    OrderCreateSerializer,
    OrderListQuerySerializer,
)

KEY = "3f6c2a1e-9b7d-4c58-a0e2-5d1f7b9c4e21"
PAYMENT_WINDOW = timedelta(minutes=15)


def test_routes():
    assert reverse("order-list") == "/api/v1/orders/"
    assert reverse("order-detail", args=[5012]) == "/api/v1/orders/5012/"
    assert reverse("order-retry-payment", args=[5012]) == "/api/v1/orders/5012/retry-payment/"
    assert reverse("order-cancel", args=[5012]) == "/api/v1/orders/5012/cancel/"


def test_active_and_terminal_statuses():
    """08 §1 "Terminal?" column."""
    assert TERMINAL_STATUSES == {"DELIVERED", "CANCELLED", "PAYMENT_FAILED", "RETURNED"}
    assert ACTIVE_STATUSES | TERMINAL_STATUSES == set(OrderStatus)
    assert OrderStatus.PAYMENT_PENDING in ACTIVE_STATUSES
    assert OrderStatus.DELIVERY_FAILED in ACTIVE_STATUSES


@pytest.mark.django_db
class TestAccess:
    @pytest.mark.parametrize(
        ("method", "path"),
        [
            ("get", "/api/v1/orders/"),
            ("get", "/api/v1/orders/5012/"),
            ("post", "/api/v1/orders/"),
            ("post", "/api/v1/orders/5012/retry-payment/"),
            ("post", "/api/v1/orders/5012/cancel/"),
        ],
    )
    def test_authentication_required(self, api_client, method, path):
        response = getattr(api_client, method)(path, headers={"Idempotency-Key": KEY})
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "AUTH_REQUIRED"


@pytest.mark.django_db
class TestCreate:
    PATH = "/api/v1/orders/"

    def test_idempotency_key_required(self, auth_client):
        response = auth_client.post(self.PATH, ex.ORDER_CREATE_ONLINE_REQUEST)
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"Idempotency-Key": [KEY_REQUIRED]}

    @pytest.mark.parametrize("key", ["short", "x" * 65, "has space key", "ключ-ключ-ключ"])
    def test_idempotency_key_format(self, auth_client, key):
        response = auth_client.post(
            self.PATH, ex.ORDER_CREATE_ONLINE_REQUEST, headers={"Idempotency-Key": key}
        )
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"Idempotency-Key": [KEY_INVALID]}

    def test_store_header_required(self, auth_client):
        response = auth_client.post(
            self.PATH, ex.ORDER_CREATE_ONLINE_REQUEST, headers={"Idempotency-Key": KEY}
        )
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"X-Store-Id": ["This header is required."]}

    def test_unknown_store(self, auth_client):
        response = auth_client.post(
            self.PATH,
            ex.ORDER_CREATE_ONLINE_REQUEST,
            headers={"Idempotency-Key": KEY, "X-Store-Id": "999999"},
        )
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "STORE_NOT_FOUND"

    @pytest.fixture
    def store_headers(self):
        from apps.stores.tests.factories import DarkStoreFactory

        return {"Idempotency-Key": KEY, "X-Store-Id": str(DarkStoreFactory().pk)}

    def test_body_validation(self, auth_client, store_headers):
        response = auth_client.post(
            self.PATH, {"address_id": 12, "payment_method": "ONLINE"}, headers=store_headers
        )
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "expected_grand_total": ["This field is required."]
        }

    @pytest.mark.parametrize("body", [ex.ORDER_CREATE_ONLINE_REQUEST, ex.ORDER_CREATE_COD_REQUEST])
    def test_valid_request_with_an_empty_cart(self, auth_client, store_headers, body):
        response = auth_client.post(self.PATH, body, headers=store_headers)
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"non_field_errors": ["Your cart is empty."]}


@pytest.mark.django_db
class TestOtherOperations:
    def test_list_status_validation(self, auth_client):
        response = auth_client.get("/api/v1/orders/?status=open")
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"status": ['"open" is not a valid choice.']}

    @pytest.mark.parametrize("query", ["", "?status=active", "?status=past"])
    def test_list_without_orders(self, auth_client, query):
        response = auth_client.get(f"/api/v1/orders/{query}")
        assert response.status_code == 200
        assert response.json() == {"count": 0, "next": None, "previous": None, "results": []}

    def test_retry_needs_an_idempotency_key(self, auth_client):
        response = auth_client.post("/api/v1/orders/5012/retry-payment/")
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"Idempotency-Key": [KEY_REQUIRED]}

    def test_retry_unknown_order(self, auth_client):
        response = auth_client.post(
            "/api/v1/orders/5012/retry-payment/", headers={"Idempotency-Key": KEY}
        )
        assert response.status_code == 404

    def test_cancel_reason_validation(self, auth_client):
        response = auth_client.post("/api/v1/orders/5012/cancel/", {"reason": "BORED"})
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"reason": ['"BORED" is not a valid choice.']}

    @pytest.mark.parametrize("body", [ex.ORDER_CANCEL_REQUEST, ex.ORDER_CANCEL_OTHER_REQUEST])
    def test_cancel_unknown_order(self, auth_client, body):
        assert auth_client.post("/api/v1/orders/5012/cancel/", body).status_code == 404


class TestSerializers:
    def test_create_requires_everything(self):
        serializer = OrderCreateSerializer(data={})
        assert not serializer.is_valid()
        assert set(serializer.errors) == {"address_id", "payment_method", "expected_grand_total"}

    @pytest.mark.parametrize("total", ["753", "753.00", "0.00"])
    def test_expected_total_formats(self, total):
        body = {**ex.ORDER_CREATE_ONLINE_REQUEST, "expected_grand_total": total}
        assert OrderCreateSerializer(data=body).is_valid()

    @pytest.mark.parametrize("total", ["753.001", "-1.00", "abc"])
    def test_bad_expected_totals(self, total):
        body = {**ex.ORDER_CREATE_ONLINE_REQUEST, "expected_grand_total": total}
        assert not OrderCreateSerializer(data=body).is_valid()

    def test_list_status_is_optional(self):
        assert OrderListQuerySerializer(data={}).is_valid()

    def test_cancel_note_is_optional_and_bounded(self):
        assert OrderCancelSerializer(data={"reason": "OTHER"}).is_valid()
        assert not OrderCancelSerializer(data={"reason": "OTHER", "note": "x" * 251}).is_valid()


# --------------------------------------------------------------------------- examples


def at(value: str) -> datetime:
    return datetime.fromisoformat(value)


ORDERS = [
    ex.ORDER_COD_PLACED,
    ex.ORDER_ONLINE_PENDING,
    ex.ORDER_ONLINE_PLACED,
    ex.ORDER_PAYMENT_CANCELLED,
]


@pytest.mark.parametrize("order", ORDERS, ids=lambda o: f"{o['id']}-{o['status']}")
class TestOrderExamples:
    def test_bill_is_the_cart_bill(self, order):
        """Placed from CART_READY: the order's bill is the same compute_bill() result."""
        assert order["bill"] == cart_ex.CART_READY["bill"]
        assert order["coupon_code"] == cart_ex.CART_READY["coupon"]["code"]
        assert order["instructions"] == cart_ex.CART_READY["instructions"]

    def test_lines(self, order):
        mrp = sum(Decimal(line["line_mrp_total"]) for line in order["items"])
        total = sum(Decimal(line["line_total"]) for line in order["items"])
        assert str(mrp) == order["bill"]["mrp_total"]
        assert str(total) == order["bill"]["item_total"]
        for line in order["items"]:
            assert Decimal(line["line_total"]) == Decimal(line["selling_price"]) * line["quantity"]
            assert Decimal(line["line_mrp_total"]) == Decimal(line["mrp"]) * line["quantity"]
        assert order["item_count"] == sum(line["quantity"] for line in order["items"])

    def test_state_fields(self, order):
        pending = order["status"] == "PAYMENT_PENDING"
        assert (order["payment_expires_at"] is not None) is pending
        assert order["can_retry_payment"] is pending
        assert (order["placed_at"] is None) is (order["status"] in {"PAYMENT_PENDING", "CANCELLED"})
        assert (order["eta_at"] is not None) is (order["status"] == "PLACED")
        assert order["can_cancel"] is (order["status"] == "PAYMENT_PENDING")  # Phase 3
        if pending:
            assert at(order["payment_expires_at"]) - at(order["created_at"]) == PAYMENT_WINDOW
            assert order["payment_status"] == "PENDING"
        if order["payment_method"] == "COD":
            assert order["payment_status"] == "COD_PENDING"


class TestCheckoutExamples:
    def test_amount_is_the_grand_total_in_paise(self):
        for placement in (ex.PLACEMENT_ONLINE, ex.PLACEMENT_ONLINE_FAKE, ex.PLACEMENT_RETRY):
            grand_total = Decimal(placement["order"]["bill"]["grand_total"])
            assert placement["razorpay"]["amount"] == int(grand_total * 100)
            assert placement["razorpay"]["currency"] == "INR"
            assert placement["razorpay"]["expires_at"] == placement["order"]["payment_expires_at"]

    def test_timeouts(self):
        expires = at(ex.ORDER_ONLINE_PENDING["payment_expires_at"])
        created = at(ex.ORDER_ONLINE_PENDING["created_at"])
        assert ex.RAZORPAY_CHECKOUT["timeout_seconds"] == (expires - created).total_seconds()
        retried_at = at("2026-11-03T06:36:00Z")
        assert ex.RAZORPAY_CHECKOUT_RETRY["timeout_seconds"] == (
            (expires - retried_at).total_seconds()
        )
        assert ex.RAZORPAY_CHECKOUT_RETRY["order_id"] != ex.RAZORPAY_CHECKOUT["order_id"]

    def test_razorpay_only_while_awaiting_payment(self):
        for placement in (
            ex.PLACEMENT_COD,
            ex.PLACEMENT_ONLINE,
            ex.PLACEMENT_RETRY,
            ex.PLACEMENT_REPLAY_PAID,
        ):
            awaiting = placement["order"]["status"] == "PAYMENT_PENDING"
            assert (placement["razorpay"] is not None) is awaiting

    def test_summaries_match_their_orders(self):
        for page in (ex.ORDERS_ACTIVE, ex.ORDERS_PAST):
            assert page["count"] == len(page["results"])
        active = {row["status"] for row in ex.ORDERS_ACTIVE["results"]}
        past = {row["status"] for row in ex.ORDERS_PAST["results"]}
        assert active <= ACTIVE_STATUSES
        assert past <= TERMINAL_STATUSES
        assert ex.ORDERS_ACTIVE["results"][0]["grand_total"] == "753.00"


@pytest.mark.django_db
class TestThrottles:
    """Code review of R1: order placement and payment calls are rate limited per user, and fail
    open when Redis is down (a lost limit is better than a lost order)."""

    def test_placement_is_limited_per_user(self, auth_client, make_auth_client, monkeypatch):
        from apps.core.throttling import OrderPlacementThrottle

        monkeypatch.setattr(OrderPlacementThrottle, "THROTTLE_RATES", {"orders_create": "2/hour"})
        for _ in range(2):
            assert auth_client.post("/api/v1/orders/", {}).status_code == 400  # no key
        response = auth_client.post("/api/v1/orders/", {})
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        assert "retry_after_seconds" in response.json()["error"]["details"]
        assert auth_client.get("/api/v1/orders/").status_code == 200  # reading is not limited
        other = make_auth_client(UserFactory())
        assert other.post("/api/v1/orders/", {}).status_code == 400  # per user

    def test_payment_calls_are_limited(self, auth_client, monkeypatch):
        from apps.core.throttling import PaymentThrottle

        monkeypatch.setattr(PaymentThrottle, "THROTTLE_RATES", {"payments": "1/hour"})
        assert auth_client.post("/api/v1/orders/5012/retry-payment/").status_code == 400
        assert auth_client.post("/api/v1/payments/razorpay/verify/", {}).status_code == 429

    def test_fails_open_when_redis_is_down(self, auth_client, monkeypatch):
        from apps.core.throttling import OrderPlacementThrottle

        class BrokenCache:
            def get(self, *args, **kwargs):
                raise ConnectionError("redis down")

        monkeypatch.setattr(OrderPlacementThrottle, "THROTTLE_RATES", {"orders_create": "1/hour"})
        monkeypatch.setattr(OrderPlacementThrottle, "cache", BrokenCache())
        for _ in range(3):
            assert auth_client.post("/api/v1/orders/", {}).status_code == 400


def test_pending_order_conflict_is_documented():
    """PM decision (Phase 3): one unpaid order at a time."""
    from drf_spectacular.generators import SchemaGenerator

    schema = SchemaGenerator().get_schema(request=None, public=True)
    responses = schema["paths"]["/api/v1/orders/"]["post"]["responses"]
    examples = responses["409"]["content"]["application/json"]["examples"]
    pending = next(
        example["value"]["error"]
        for example in examples.values()
        if example.get("summary") == "PAYMENT_PENDING_ORDER_EXISTS"
    )
    assert (pending["code"], pending["details"]) == (
        "INVALID_STATE_TRANSITION",
        {"pending_order_id": 5012},
    )
    for path, method in [
        ("/api/v1/orders/", "post"),
        ("/api/v1/orders/{id}/retry-payment/", "post"),
        ("/api/v1/payments/razorpay/verify/", "post"),
    ]:
        assert "429" in schema["paths"][path][method]["responses"], path
