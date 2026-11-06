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
    """Either the capture wins (PLACED, then the cancel is a T11 cancellation of a paid order,
    refunded in full; Phase 4) or the cancel wins (T5 CANCELLED, the late capture is refunded
    once). Both ways: cancelled, refunded exactly once, stock released."""
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
    assert order.status == "CANCELLED"
    assert results[1] == "CANCELLED"
    assert reserved(shop) == 0
    refunds = list(Refund.objects.values_list("idempotency_key", "reason", "amount"))
    if results[0] == "placed":
        assert transitions(order) == ["PAYMENT_PENDING", "PLACED", "CANCELLED"]
        assert refunds == [(f"cancel:{order.pk}", "customer_cancel", Decimal("558.00"))]
    else:
        assert results[0] == "late_capture"
        assert transitions(order) == ["PAYMENT_PENDING", "CANCELLED"]
        assert refunds == [(f"capture:{payment_id}", "late_capture", Decimal("558.00"))]


def test_refund_task_delivered_twice(shop, monkeypatch):
    """Code review M1: two workers run `process_refund` for one refund at once (a redelivery);
    exactly one calls the gateway. Since P4 (T-403c) that is the per-refund advisory lock, not
    a row lock held across the call."""
    import time

    from apps.payments.gateways import FakeRazorpayGateway
    from apps.payments.models import Refund
    from apps.payments.tasks import process_refund

    user, order, gateway_order_id = pending_order(shop)
    services.cancel_order(user, order.pk, reason="OTHER")
    payment_id = "pay_RaceRefund001"
    with monkeypatch.context() as queued:  # tests run Celery eagerly: keep the task queued
        queued.setattr(process_refund, "delay", lambda refund_id: None)
        outcome = services.capture_payment(
            order.pk, gateway_order_id=gateway_order_id, payment_id=payment_id, amount_paise=55800
        ).outcome
    assert outcome == "late_capture"
    refund = Refund.objects.get()
    assert (refund.status, refund.gateway_refund_id) == ("PENDING", "")

    calls: list[str] = []
    original = FakeRazorpayGateway.refund

    def slow_refund(self, **kwargs):
        calls.append(kwargs["receipt"])
        time.sleep(0.3)  # still sending while the other worker arrives
        return original(self, **kwargs)

    monkeypatch.setattr(FakeRazorpayGateway, "refund", slow_refund)
    results = race(*(lambda: process_refund.run(refund.pk) for _ in range(2)))
    assert sorted(results) == ["processed", "skipped"], results
    assert calls == [f"capture:{payment_id}"]
    refund.refresh_from_db()
    assert refund.status == "PROCESSED"
    assert Refund.objects.count() == 1


def test_refund_gateway_call_holds_no_row_lock(shop, monkeypatch):
    """T-403c (P4 review Major 1): while `process_refund` waits on the gateway, the order and
    refund rows are not locked: another transaction can lock both at once (NOWAIT)."""
    import threading

    from django.db import connection

    from apps.orders.models import Order
    from apps.payments.gateways import FakeRazorpayGateway
    from apps.payments.models import Refund
    from apps.payments.tasks import process_refund

    user, order, gateway_order_id = pending_order(shop)
    services.cancel_order(user, order.pk, reason="OTHER")
    with monkeypatch.context() as queued:
        queued.setattr(process_refund, "delay", lambda refund_id: None)
        services.capture_payment(
            order.pk,
            gateway_order_id=gateway_order_id,
            payment_id="pay_NoLockRefund01",
            amount_paise=55800,
        )
    refund = Refund.objects.get()
    in_call, release = threading.Event(), threading.Event()
    original = FakeRazorpayGateway.refund

    def waiting_refund(self, **kwargs):
        in_call.set()
        release.wait(10)
        return original(self, **kwargs)

    monkeypatch.setattr(FakeRazorpayGateway, "refund", waiting_refund)
    outcome = {}

    def worker():
        try:
            outcome["result"] = process_refund.run(refund.pk)
        finally:
            connection.close()

    thread = threading.Thread(target=worker)
    thread.start()
    try:
        assert in_call.wait(10)
        with transaction.atomic():
            Order.objects.select_for_update(nowait=True).get(pk=order.pk)
            Refund.objects.select_for_update(nowait=True).get(pk=refund.pk)
    finally:
        release.set()
        thread.join(10)
    assert outcome["result"] == "processed"
    refund.refresh_from_db()
    assert refund.status == "PROCESSED"


def test_slow_gateway_at_placement_holds_no_lock(shop, monkeypatch):
    """T-814 (M6): while the placement waits on a slow gateway, the customer's cart, the coupon
    and the stock rows are not locked (another transaction locks them NOWAIT), the order is
    already committed with its stock reserved, and the attempt is attached when the call
    returns."""
    from apps.payments.gateways import FakeRazorpayGateway

    user = UserFactory()
    address = make_address(user)
    cart = Cart.objects.create(user=user, store=shop.store_model, address=address)
    CartItem.objects.create(cart=cart, variant=shop.canola_1l, quantity=2)
    in_call, release = threading.Event(), threading.Event()
    original = FakeRazorpayGateway.create_order

    def slow_create_order(self, **kwargs):
        in_call.set()
        release.wait(10)
        return original(self, **kwargs)

    monkeypatch.setattr(FakeRazorpayGateway, "create_order", slow_create_order)
    outcome = {}

    def worker():
        try:
            outcome["placement"] = services.place_order(
                user,
                shop.store,
                address_id=address.pk,
                payment_method="ONLINE",
                expected_grand_total=Decimal("558.00"),
                idempotency_key=str(uuid.uuid4()),
            )
        except Exception as exc:  # pragma: no cover - reported by the assert below
            outcome["error"] = exc
        finally:
            connection.close()

    thread = threading.Thread(target=worker)
    thread.start()
    try:
        assert in_call.wait(10)
        with transaction.atomic():
            Cart.objects.select_for_update(nowait=True).get(pk=cart.pk)
            list(
                StoreInventory.objects.select_for_update(nowait=True).filter(store=shop.store_model)
            )
        pending = Order.objects.get(user=user)
        assert pending.status == "PAYMENT_PENDING"
        assert not pending.payments.exists()
        assert reserved(shop) == 2
    finally:
        release.set()
        thread.join(15)
    assert "error" not in outcome, outcome
    order = outcome["placement"].order
    assert outcome["placement"].created
    assert order.payments.get().status == "CREATED"
    assert reserved(shop) == 2


def test_gateway_failure_at_placement_races_a_replay(shop, monkeypatch):
    """T-814 (M6): the creating request's gateway call fails while a replay of the same key
    succeeds: the order keeps the replay's attempt (not ended), and stock stays reserved once."""
    from apps.payments.gateways import FakeRazorpayGateway, PaymentGatewayError

    user = UserFactory()
    address = make_address(user)
    cart = Cart.objects.create(user=user, store=shop.store_model, address=address)
    CartItem.objects.create(cart=cart, variant=shop.canola_1l, quantity=2)
    key = str(uuid.uuid4())
    calls = {"n": 0}
    lock = threading.Lock()
    original = FakeRazorpayGateway.create_order

    def first_fails(self, **kwargs):
        with lock:
            calls["n"] += 1
            first = calls["n"] == 1
        if first:
            raise PaymentGatewayError("timeout")
        return original(self, **kwargs)

    monkeypatch.setattr(FakeRazorpayGateway, "create_order", first_fails)

    def place():
        return services.place_order(
            user,
            shop.store,
            address_id=address.pk,
            payment_method="ONLINE",
            expected_grand_total=Decimal("558.00"),
            idempotency_key=key,
        )

    results = race(place, place)
    orders = Order.objects.filter(user=user)
    live = [o for o in orders if o.status == "PAYMENT_PENDING"]
    # Either the replay attached first (one live order, one attempt) or the failure ended the
    # order first (then the replay placed a fresh one, or got 503): never a stuck reservation.
    assert len(live) <= 1
    assert reserved(shop) == 2 * len(live)
    for order in live:
        assert order.payments.count() == 1
    assert any(not isinstance(r, Exception) for r in results) or not live
