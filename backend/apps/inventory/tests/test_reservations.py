"""Stock reservations (08 §6.1): reserve under row locks, release idempotently, clear expiry."""

from datetime import timedelta

import pytest
from django.db import transaction
from django.utils import timezone

from apps.catalog.tests.factories import VariantFactory
from apps.core.exceptions import ApiError
from apps.inventory import services
from apps.inventory.models import ReservationStatus, StockReservation, StoreInventory
from apps.inventory.services import ReservationLine
from apps.inventory.tests.factories import stock
from apps.orders.tests.factories import OrderFactory
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def setup():
    store = DarkStoreFactory()
    a, b = VariantFactory(), VariantFactory(max_qty_per_order=3)
    stock(store, a, 5)
    stock(store, b, 2, reserved=1)
    order = OrderFactory(store=store, status="PAYMENT_PENDING", placed_at=None)
    return store, a, b, order


def row(store, variant) -> StoreInventory:
    return StoreInventory.objects.get(store=store, variant=variant)


def test_reserve_and_release(setup):
    store, a, b, order = setup
    expires = timezone.now() + timedelta(minutes=15)
    with transaction.atomic():
        services.reserve(
            order,
            store.pk,
            [ReservationLine(b.pk, 1, 3), ReservationLine(a.pk, 2, 5)],
            expires_at=expires,
        )
    assert (row(store, a).reserved, row(store, b).reserved) == (2, 2)
    assert {(r.variant_id, r.quantity, r.status) for r in StockReservation.objects.all()} == {
        (a.pk, 2, ReservationStatus.ACTIVE),
        (b.pk, 1, ReservationStatus.ACTIVE),
    }
    assert services.clear_reservation_expiry(order) == 2
    assert set(StockReservation.objects.values_list("expires_at", flat=True)) == {None}
    assert services.release_reservations(order) == 2
    assert services.release_reservations(order) == 0  # idempotent
    assert (row(store, a).reserved, row(store, b).reserved) == (0, 1)
    assert row(store, a).on_hand == 5  # on_hand changes only at pickup (T9)


def test_short_lines_are_all_listed_and_nothing_is_reserved(setup):
    store, a, b, order = setup
    unsold = VariantFactory()
    with transaction.atomic(), pytest.raises(ApiError) as caught:
        services.reserve(
            order,
            store.pk,
            [
                ReservationLine(a.pk, 1, 5),
                ReservationLine(b.pk, 2, 3),
                ReservationLine(unsold.pk, 1, 5),
            ],
        )
    assert caught.value.error_code == "STOCK_UNAVAILABLE"
    assert caught.value.details == {
        "items": [
            {"variant_id": b.pk, "requested_quantity": 2, "orderable_quantity": 1},
            {"variant_id": unsold.pk, "requested_quantity": 1, "orderable_quantity": 0},
        ]
    }
    assert row(store, a).reserved == 0
    assert not StockReservation.objects.exists()


def test_switched_off_item_is_not_reservable(setup):
    store, a, _, order = setup
    StoreInventory.objects.filter(store=store, variant=a).update(is_available=False)
    with transaction.atomic(), pytest.raises(ApiError):
        services.reserve(order, store.pk, [ReservationLine(a.pk, 1, 5)])


def test_reserve_needs_the_placement_transaction(setup):
    from django.db import connection

    store, a, _, order = setup
    connection.in_atomic_block, saved = False, connection.in_atomic_block  # as if no transaction
    try:
        with pytest.raises(RuntimeError, match="placement transaction"):
            services.reserve(order, store.pk, [ReservationLine(a.pk, 1, 5)])
    finally:
        connection.in_atomic_block = saved
