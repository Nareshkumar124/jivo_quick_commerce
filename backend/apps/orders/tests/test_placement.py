"""`POST /orders/` (08 T1/T2): the bill snapshot, stock reservations (08 §6.1), coupon use,
idempotency (DL-44), one unpaid order at a time, and every guard."""

import re
from datetime import timedelta
from decimal import Decimal

import jsonschema
import pytest
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.cart.models import CartItem
from apps.cart.tests.conftest import OUTSIDE, make_address
from apps.inventory.models import ReservationStatus, StockReservation, StoreInventory
from apps.orders.models import Order, OrderStatusHistory
from apps.orders.tests.conftest import ORDERS, new_key
from apps.payments.gateways import FAKE_KEY_ID, FakeRazorpayGateway, PaymentGatewayError
from apps.payments.models import Payment
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.stores.models import PricingConfig
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db


@pytest.fixture(scope="module")
def components():
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


def conforms(body, name, components):
    jsonschema.validate(body, to_json_schema({"$ref": f"#/components/schemas/{name}"}, components))


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


def coupon(code="JIVO50", **kwargs) -> Coupon:
    defaults = {
        "title": "Flat ₹50 off",
        "discount_type": "FLAT",
        "value": Decimal("50.00"),
        "min_order_value": Decimal("299.00"),
    }
    return Coupon.objects.create(code=code, **{**defaults, **kwargs})


class TestCashOnDelivery:
    def test_t2_places_the_order_at_once(self, checkout, shop, user, components):
        coupon()
        checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        cart = checkout.cart()
        body = checkout.place("COD")
        conforms(body, "OrderPlacement", components)
        order = body["order"]
        assert body["razorpay"] is None
        assert (order["status"], order["payment_method"], order["payment_status"]) == (
            "PLACED",
            "COD",
            "COD_PENDING",
        )
        assert order["bill"] == cart["bill"]  # the same compute_bill() result
        assert order["coupon_code"] == "JIVO50"
        assert re.fullmatch(rf"JV-\d{{6}}-{order['id']:06d}", order["order_number"])
        assert order["placed_at"]
        assert order["eta_at"]
        assert order["payment_expires_at"] is None
        assert order["can_cancel"] is False  # Phase 3: only unpaid orders can be cancelled
        assert [(i["variant_id"], i["quantity"]) for i in order["items"]] == [
            (shop.canola_1l.pk, 2),
            (shop.chia.pk, 1),
        ]
        assert order["address"]["receiver_phone"] == checkout.address.receiver_phone
        # Stock reserved (no expiry), coupon used, ordered lines gone from the cart
        assert (reserved(shop, shop.canola_1l), reserved(shop, shop.chia)) == (2, 1)
        reservations = StockReservation.objects.filter(order_id=order["id"])
        assert {r.status for r in reservations} == {ReservationStatus.ACTIVE}
        assert {r.expires_at for r in reservations} == {None}
        assert CouponRedemption.objects.get(order_id=order["id"]).status == RedemptionStatus.APPLIED
        after = checkout.cart()
        assert after["items"] == []
        assert after["coupon"] is None
        history = OrderStatusHistory.objects.get(order_id=order["id"])
        assert (history.from_status, history.to_status, history.actor) == ("", "PLACED", user)

    def test_cod_above_the_limit(self, checkout, shop):
        checkout.fill((shop.canola_5l, 2))  # ₹2,598
        body = checkout.place("COD", status=422)
        assert body["error"]["code"] == "COD_NOT_AVAILABLE"
        assert body["error"]["details"] == {
            "reason": "ABOVE_LIMIT",
            "cod_max_order_value": "2000.00",
        }
        assert not Order.objects.exists()

    def test_cod_blocked_customer_and_disabled_store(self, checkout, shop, user):
        checkout.fill((shop.chia, 1))
        user.cod_blocked = True
        user.save(update_fields=["cod_blocked"])
        assert checkout.place("COD", status=422)["error"]["details"] == {"reason": "NOT_ALLOWED"}
        user.cod_blocked = False
        user.save(update_fields=["cod_blocked"])
        PricingConfig.objects.create(store=shop.store_model, cod_enabled=False)
        assert checkout.place("COD", status=422)["error"]["details"] == {"reason": "COD_DISABLED"}


class TestOnline:
    def test_t1_awaits_payment(self, checkout, shop, user, components):
        coupon()
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        body = checkout.place("ONLINE")
        conforms(body, "OrderPlacement", components)
        order, razorpay = body["order"], body["razorpay"]
        assert (order["status"], order["payment_status"]) == ("PAYMENT_PENDING", "PENDING")
        assert order["placed_at"] is None
        assert order["eta_at"] is None
        assert order["can_cancel"] is True
        assert order["can_retry_payment"] is True
        assert razorpay["key_id"] == FAKE_KEY_ID
        assert razorpay["amount"] == 50800  # ₹558 - ₹50
        assert razorpay["expires_at"] == order["payment_expires_at"]
        assert 890 <= razorpay["timeout_seconds"] <= 900
        assert razorpay["prefill"] == {"name": user.name, "contact": user.phone, "email": ""}
        payment = Payment.objects.get(order_id=order["id"])
        assert (payment.status, payment.gateway_order_id, payment.amount) == (
            "CREATED",
            razorpay["order_id"],
            Decimal("508.00"),
        )
        reservation = StockReservation.objects.get(order_id=order["id"])
        assert reservation.expires_at is not None
        assert CouponRedemption.objects.get(order_id=order["id"]).status == RedemptionStatus.HELD
        assert checkout.cart()["items"]  # the cart is kept until the payment is captured

    def test_payment_window_comes_from_app_config(self, checkout, shop):
        from apps.cms.models import AppConfig

        config = AppConfig.load()
        config.payment_window_minutes = 10
        config.save()
        checkout.fill((shop.canola_1l, 2))
        before = timezone.now()
        order = Order.objects.get(pk=checkout.place("ONLINE")["order"]["id"])
        assert timedelta(minutes=10) <= order.payment_expires_at - before < timedelta(minutes=11)

    def test_gateway_down_creates_nothing(self, checkout, shop, monkeypatch):
        def down(self, **kwargs):
            raise PaymentGatewayError("timeout")

        monkeypatch.setattr(FakeRazorpayGateway, "create_order", down)
        checkout.fill((shop.canola_1l, 2))
        body = checkout.place("ONLINE", status=503)
        assert body["error"]["code"] == "SERVICE_UNAVAILABLE"
        assert not Order.objects.exists()
        assert reserved(shop, shop.canola_1l) == 0


class TestIdempotency:
    def test_replay_returns_the_first_order(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        key = new_key()
        expected = checkout.cart()["bill"]["grand_total"]
        first = checkout.place("ONLINE", key=key, expected=expected)
        again = checkout.place("ONLINE", key=key, expected=expected, status=200)
        assert again["order"]["id"] == first["order"]["id"]
        assert again["razorpay"]["order_id"] == first["razorpay"]["order_id"]
        assert Order.objects.count() == 1
        assert reserved(shop, shop.canola_1l) == 2  # not reserved twice

    def test_same_key_other_body_is_400(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        key = new_key()
        checkout.place("COD", key=key)
        body = checkout.place("ONLINE", key=key, status=400)
        assert body["error"]["details"] == {
            "Idempotency-Key": ["This key was already used for a different request. Use a new key."]
        }

    def test_a_failed_attempt_is_not_remembered(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        key = new_key()
        checkout.place("COD", key=key, expected="1.00", status=409)  # PRICE_CHANGED
        assert checkout.place("COD", key=key)["order"]["status"] == "PLACED"

    def test_keys_are_per_user(self, checkout, shop, make_auth_client):
        from apps.accounts.tests.factories import UserFactory
        from apps.orders.tests.conftest import Checkout

        key = new_key()
        checkout.fill((shop.canola_1l, 1), (shop.chia, 1))
        checkout.place("COD", key=key)
        other_user = UserFactory()
        other = Checkout(make_auth_client(other_user), shop, make_address(other_user))
        other.fill((shop.chia, 1), (shop.flax, 1))
        theirs = other.place("COD", key=key)["order"]  # 201: a key is scoped to its user
        assert theirs["id"] == Order.objects.get(user=other_user).pk
        assert Order.objects.count() == 2


class TestGuards:
    def test_one_unpaid_order_at_a_time(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        pending = checkout.place("ONLINE")["order"]["id"]
        body = checkout.place("COD", status=409)
        assert body["error"] == {
            "code": "INVALID_STATE_TRANSITION",
            "message": "You have an order awaiting payment. Complete or cancel it first.",
            "details": {"pending_order_id": pending},
        }

    def test_price_changed(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        expected = checkout.cart()["bill"]["grand_total"]
        StoreInventory.objects.filter(store=shop.store_model, variant=shop.canola_1l).update(
            price_override=Decimal("269.00")
        )
        body = checkout.place("COD", expected=expected, status=409)
        assert body["error"] == {
            "code": "PRICE_CHANGED",
            "message": "The bill has changed. Refresh the cart.",
            "details": {"expected_grand_total": "558.00", "grand_total": "538.00"},
        }

    def test_stock_unavailable(self, checkout, shop):
        from apps.inventory.models import stock_write

        checkout.fill((shop.canola_5l, 2))
        row = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_5l)
        row.on_hand = 1
        with stock_write():
            row.save(update_fields=["on_hand"])
        body = checkout.place("ONLINE", expected="2598.00", status=409)
        assert body["error"]["details"] == {
            "items": [
                {"variant_id": shop.canola_5l.pk, "requested_quantity": 2, "orderable_quantity": 1}
            ]
        }

    def test_minimum_order(self, checkout, shop):
        checkout.fill((shop.flax, 1))
        body = checkout.place("COD", status=422)
        assert body["error"]["code"] == "MIN_ORDER_NOT_MET"
        assert body["error"]["details"] == {
            "min_order_value": "99.00",
            "item_total": "79.00",
            "amount_to_min_order": "20.00",
        }

    def test_address_outside_and_other_users_address(self, checkout, shop, user):
        from apps.accounts.tests.factories import UserFactory

        checkout.fill((shop.canola_1l, 2))
        far = make_address(user, OUTSIDE)
        body = checkout.place("COD", address_id=far.pk, status=422)
        assert (body["error"]["code"], body["error"]["details"]) == (
            "NOT_SERVICEABLE",
            {"address_id": far.pk},
        )
        theirs = make_address(UserFactory())
        body = checkout.place("COD", address_id=theirs.pk, status=400)
        assert body["error"]["details"] == {"address_id": ["Address not found."]}

    def test_store_closed(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        shop.store_model.is_accepting_orders = False
        shop.store_model.save()
        body = checkout.place("COD", status=422)
        assert body["error"]["code"] == "STORE_CLOSED"
        assert body["error"]["details"] == {"store_id": shop.store_model.pk, "opens_at": None}

    def test_coupon_no_longer_valid(self, checkout, shop):
        applied = coupon()
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        expected = checkout.cart()["bill"]["grand_total"]
        Coupon.objects.filter(pk=applied.pk).update(ends_at=timezone.now())
        body = checkout.place("COD", expected=expected, status=422)
        assert body["error"]["code"] == "COUPON_EXPIRED"

    def test_coupon_used_up_meanwhile(self, checkout, shop):
        """The limit is re-checked on the locked coupon row at placement (code review F2)."""
        from apps.accounts.tests.factories import UserFactory
        from apps.orders.tests.factories import OrderFactory

        applied = coupon(usage_limit_total=1, usage_limit_per_user=None)
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "JIVO50"}, headers=checkout.headers)
        expected = checkout.cart()["bill"]["grand_total"]
        other = UserFactory()
        CouponRedemption.objects.create(
            coupon=applied,
            user=other,
            order=OrderFactory(user=other),
            discount_amount=Decimal(50),
            status=RedemptionStatus.APPLIED,
        )
        body = checkout.place("COD", expected=expected, status=422)
        assert body["error"]["code"] == "COUPON_USAGE_EXCEEDED"
        assert reserved(shop, shop.canola_1l) == 0  # rolled back

    def test_empty_cart(self, checkout, shop):
        checkout.fill((shop.canola_1l, 1))
        CartItem.objects.all().delete()
        body = checkout.place("COD", expected="0.00", status=400)
        assert body["error"]["details"] == {"non_field_errors": ["Your cart is empty."]}

    def test_client_info_is_recorded(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        expected = checkout.cart()["bill"]["grand_total"]
        response = checkout.client.post(
            ORDERS,
            {
                "address_id": checkout.address.pk,
                "payment_method": "COD",
                "expected_grand_total": expected,
            },
            headers={
                **checkout.headers,
                "Idempotency-Key": new_key(),
                "X-App-Name": "customer",
                "X-App-Version": "1.4.2",
                "X-Platform": "android",
            },
        )
        assert response.status_code == 201
        order = Order.objects.get()
        assert (order.client_app_version, order.client_platform) == ("1.4.2", "android")
