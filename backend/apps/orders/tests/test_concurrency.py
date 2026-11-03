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
