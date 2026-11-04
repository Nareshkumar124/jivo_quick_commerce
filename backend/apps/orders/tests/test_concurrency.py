"""Code review F3: real concurrency (two database connections, committed data). The row locks of
the placement path serialise competing orders, so a coupon's last use and a store's last unit
are never given twice."""

import threading
import uuid
from decimal import Decimal

import pytest
from django.db import connection, transaction

from apps.accounts.tests.factories import UserFactory
from apps.cart.models import Cart, CartItem
from apps.cart.tests.conftest import make_address
from apps.core.exceptions import ApiError
from apps.inventory.models import StoreInventory, stock_write
from apps.orders import services
from apps.orders.models import Order
from apps.orders.tests.factories import OrderFactory
from apps.promotions import services as promotions
from apps.promotions.models import Coupon, CouponRedemption

pytestmark = pytest.mark.django_db(transaction=True)


def race(*jobs):
    """Run the jobs in parallel threads, released together; return their results/exceptions."""
    barrier = threading.Barrier(len(jobs))
    results: list = [None] * len(jobs)

    def run(index, job):
        try:
            barrier.wait()
            results[index] = job()
        except Exception as exc:
            results[index] = exc
        finally:
            connection.close()

    threads = [threading.Thread(target=run, args=(i, job)) for i, job in enumerate(jobs)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)
    return results


def coupon(**limits) -> Coupon:
    return Coupon.objects.create(
        code="RACE50", title="Race", discount_type="FLAT", value=Decimal(50), **limits
    )


def holder(order, the_coupon):
    def job():
        with transaction.atomic():
            return promotions.hold_coupon(order, the_coupon, Decimal(50))

    return job


def outcome(results):
    wins = [r for r in results if not isinstance(r, Exception)]
    losses = [r for r in results if isinstance(r, Exception)]
    return wins, losses


def test_last_use_of_a_coupon_overall():
    the_coupon = coupon(usage_limit_total=1, usage_limit_per_user=None)
    orders = [OrderFactory(status="PAYMENT_PENDING", placed_at=None) for _ in range(2)]
    wins, losses = outcome(race(*(holder(order, the_coupon) for order in orders)))
    assert len(wins) == 1
    assert len(losses) == 1
    assert isinstance(losses[0], ApiError)
    assert (losses[0].error_code, losses[0].details["scope"]) == ("COUPON_USAGE_EXCEEDED", "total")
    assert CouponRedemption.objects.count() == 1


def test_last_use_of_a_coupon_per_customer():
    the_coupon = coupon(usage_limit_per_user=1)
    user = UserFactory()
    orders = [OrderFactory(user=user, status="PAYMENT_PENDING", placed_at=None) for _ in range(2)]
    wins, losses = outcome(race(*(holder(order, the_coupon) for order in orders)))
    assert len(wins) == 1
    assert (losses[0].error_code, losses[0].details["scope"]) == (
        "COUPON_USAGE_EXCEEDED",
        "per_user",
    )


def test_two_customers_and_the_last_unit(shop):
    """Two COD orders for a store's last 5 L can: one is placed, the other gets 409."""
    row = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_5l)
    row.on_hand = 1
    with stock_write():
        row.save(update_fields=["on_hand"])
    store = shop.store

    def customer():
        user = UserFactory()
        address = make_address(user)
        cart = Cart.objects.create(user=user, store=shop.store_model, address=address)
        CartItem.objects.create(cart=cart, variant=shop.canola_5l, quantity=1)

        def job():
            return services.place_order(
                user,
                store,
                address_id=address.pk,
                payment_method="COD",
                expected_grand_total=Decimal("1299.00"),
                idempotency_key=str(uuid.uuid4()),
            )

        return job

    wins, losses = outcome(race(customer(), customer()))
    assert len(wins) == 1
    assert len(losses) == 1
    assert isinstance(losses[0], ApiError)
    assert losses[0].error_code == "STOCK_UNAVAILABLE"
    assert losses[0].details["items"][0]["orderable_quantity"] == 0
    row.refresh_from_db()
    assert (row.on_hand, row.reserved) == (1, 1)
    assert Order.objects.count() == 1


def test_one_customer_double_tap_with_one_key(shop):
    """The same Idempotency-Key twice at once: one order; the loser returns the winner's."""
    user = UserFactory()
    address = make_address(user)
    cart = Cart.objects.create(user=user, store=shop.store_model, address=address)
    CartItem.objects.create(cart=cart, variant=shop.canola_1l, quantity=2)
    key, store = str(uuid.uuid4()), shop.store

    def job():
        return services.place_order(
            user,
            store,
            address_id=address.pk,
            payment_method="ONLINE",
            expected_grand_total=Decimal("558.00"),
            idempotency_key=key,
        )

    results = race(job, job)
    assert all(not isinstance(result, Exception) for result in results), results
    assert {result.order.pk for result in results} == {Order.objects.get().pk}
    assert sorted(result.created for result in results) == [False, True]


# --------------------------------------------------------------------------- code review M3
# The paths after placement, raced: each must give exactly one transition (one history row per
# transition), at most one Refund per capture key, and a `reserved` that matches the outcome.


def pending_order(shop):
    """An ONLINE order for 2 x canola 1 L (₹558) awaiting payment, committed."""
    user = UserFactory()
    address = make_address(user)
    cart = Cart.objects.create(user=user, store=shop.store_model, address=address)
    CartItem.objects.create(cart=cart, variant=shop.canola_1l, quantity=2)
    placement = services.place_order(
        user,
        shop.store,
        address_id=address.pk,
        payment_method="ONLINE",
        expected_grand_total=Decimal("558.00"),
        idempotency_key=str(uuid.uuid4()),
    )
    payment = placement.order.payments.get()
    return user, placement.order, payment.gateway_order_id


def captured(gateway_order_id: str, payment_id: str) -> dict:
    return {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": payment_id,
                    "order_id": gateway_order_id,
                    "amount": 55800,
                    "method": "upi",
                }
            }
        },
    }


def transitions(order) -> list[str]:
    from apps.orders.models import OrderStatusHistory

    return list(
        OrderStatusHistory.objects.filter(order=order)
        .order_by("id")
        .values_list("to_status", flat=True)
    )


def reserved(shop) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_1l).reserved


def test_webhook_and_webhook_with_one_event_id(shop):
    from apps.payments.models import PaymentWebhookEvent, Refund
    from apps.payments.services import handle_webhook

    _, order, gateway_order_id = pending_order(shop)
    event = captured(gateway_order_id, "pay_RaceHookHook1")
    results = race(*(lambda: handle_webhook("evt_race_same", event) for _ in range(2)))
    assert sorted(str(result) for result in results) == ["duplicate", "processed"], results
    order.refresh_from_db()
    assert order.status == "PLACED"
    assert transitions(order) == ["PAYMENT_PENDING", "PLACED"]
    assert PaymentWebhookEvent.objects.count() == 1
    assert Refund.objects.count() == 0
    assert reserved(shop) == 2


def test_verify_and_webhook_for_one_payment(shop):
    from apps.orders.tests.conftest import sign
    from apps.payments.models import Payment, Refund
    from apps.payments.services import handle_webhook, verify_payment

    user, order, gateway_order_id = pending_order(shop)
    payment_id = "pay_RaceVerifyHk1"

    def verify():
        return verify_payment(
            user,
            order_id=order.pk,
            razorpay_order_id=gateway_order_id,
            razorpay_payment_id=payment_id,
            signature=sign(gateway_order_id, payment_id),
        ).status

    results = race(
        verify, lambda: handle_webhook("evt_race_verify", captured(gateway_order_id, payment_id))
    )
    assert results[0] == "PLACED"
    assert str(results[1]) == "processed"
    order.refresh_from_db()
    assert transitions(order) == ["PAYMENT_PENDING", "PLACED"]
    assert list(Payment.objects.values_list("status", "gateway_payment_id")) == [
        ("CAPTURED", payment_id)
    ]
    assert Refund.objects.count() == 0
    assert reserved(shop) == 2


def test_expiry_and_expiry(shop):
    from django.utils import timezone

    from apps.inventory.models import StockReservation

    _, order, _ = pending_order(shop)
    Order.objects.filter(pk=order.pk).update(payment_expires_at=timezone.now())
    results = race(*(lambda: services.expire_order(order.pk) for _ in range(2)))
    assert sorted(results) == ["failed", "skipped"], results
    order.refresh_from_db()
    assert transitions(order) == ["PAYMENT_PENDING", "PAYMENT_FAILED"]
    assert reserved(shop) == 0  # released once, never below zero
    assert set(StockReservation.objects.values_list("status", flat=True)) == {"RELEASED"}


def test_capture_and_cancel(shop):
    """Either the capture wins (PLACED, the cancel is refused) or the cancel wins (CANCELLED, the
    late capture is refunded once); never both, never neither."""
    from apps.payments.models import Refund

    user, order, gateway_order_id = pending_order(shop)
    payment_id = "pay_RaceCancel001"

    def capture():
        return services.capture_payment(
            order.pk, gateway_order_id=gateway_order_id, payment_id=payment_id, amount_paise=55800
        ).outcome

    def cancel():
        return services.cancel_order(user, order.pk, reason="OTHER").status

    results = race(capture, cancel)
    order.refresh_from_db()
    if order.status == "PLACED":
        assert results[0] == "placed"
        assert isinstance(results[1], ApiError)
        assert results[1].error_code == "INVALID_STATE_TRANSITION"
        assert transitions(order) == ["PAYMENT_PENDING", "PLACED"]
        assert Refund.objects.count() == 0
        assert reserved(shop) == 2
    else:
        assert order.status == "CANCELLED"
        assert results == ["late_capture", "CANCELLED"]
        assert transitions(order) == ["PAYMENT_PENDING", "CANCELLED"]
        assert list(Refund.objects.values_list("idempotency_key", "reason")) == [
            (f"capture:{payment_id}", "late_capture")
        ]
        assert reserved(shop) == 0
