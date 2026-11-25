"""Free cartons (ADR 0002) on the store packing console, the slip, the rider handover (PACKED
ticket) and the store returns list.

- Free lines (`OrderItem.is_free`, ₹0, with a `free_source`) are in the pick list like paid
  ones: a FREE badge with the source, "₹0", the units to pack, a tick needed before "Mark
  packed", and the item count says how many are free.
- "Can't supply" on a free line never cancels the order, and a paid line is the last one when
  only free cartons would be left (as `store_ops.mark_item_unavailable` counts paid units
  only).
- The role matrix (05 §3 "Packing console") is unchanged; no extra query per free line.
"""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.catalog.tests.factories import VariantFactory
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryTask
from apps.delivery.tests.factories import active_rider
from apps.ops_console import packing
from apps.ops_console.tests.helpers import (
    PACKING_ROLES,
    PRINCIPALS,
    RECEIVE_RETURN_ROLES,
    expected_status,
    login_with_stores,
)
from apps.ops_console.tests.orders_support import make_order
from apps.orders.choices import FreeSource, OrderStatus
from apps.orders.models import OrderItem
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}


def paid_line(order, variant, quantity=10) -> OrderItem:
    return OrderItem.objects.create(
        order=order,
        variant=variant,
        product=variant.product,
        product_name=variant.product.name,
        variant_name=variant.name,
        sku=variant.sku,
        mrp=variant.mrp,
        selling_price=variant.selling_price,
        quantity=quantity,
        line_total=variant.selling_price * quantity,
    )


def free_line(order, variant, source=FreeSource.VOLUME_OFFER, quantity=1) -> OrderItem:
    """A free carton as the backend stores it (₹0, `is_free`, its source)."""
    return OrderItem.objects.create(
        order=order,
        variant=variant,
        product=variant.product,
        product_name=variant.product.name,
        variant_name=variant.name,
        sku=variant.sku,
        mrp=variant.mrp,
        selling_price=Decimal("0.00"),
        quantity=quantity,
        line_total=Decimal("0.00"),
        is_free=True,
        free_source=source,
    )


def with_free_cartons(store, status=OrderStatus.PACKING, number="JV-FREE-0001", **kwargs):
    """10 paid cartons of one size, 1 free of the same size (volume offer) and 1 free of
    another size (reward)."""
    order = make_order(store, status, lines=0, order_number=number, **kwargs)
    water_1l = VariantFactory(sku=f"{number}-1L", name="1 L x 12")
    water_500 = VariantFactory(sku=f"{number}-500", name="500 ml x 24")
    paid = paid_line(order, water_1l)
    volume = free_line(order, water_1l)
    reward = free_line(order, water_500, FreeSource.REWARD)
    return order, paid, volume, reward


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")


@pytest.fixture
def packing_order(store):
    return with_free_cartons(store, pickup_code="K7Q2")


def page(store) -> str:
    return reverse("ops:packing", args=[store.code])


def ticket_for(response, order):
    return next(
        ticket
        for queue in response.context["console"].queues
        for ticket in queue.tickets
        if ticket.order.pk == order.pk
    )


# --------------------------------------------------------------------------- access (unchanged)


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_packing_matrix_unchanged_with_free_cartons(client, store, packing_order, principal):
    login_with_stores(client, principal, store)
    response = client.get(page(store))
    assert response.status_code == expected_status(principal, PACKING_ROLES), principal


# --------------------------------------------------------------------------- pick list


class TestPickList:
    def test_free_lines_show_badge_source_price_and_units(self, client, store, packing_order):
        order, paid, volume, reward = packing_order
        login_with_stores(client, roles.STORE_STAFF, store)
        response = client.get(reverse("ops:packing-queues", args=[store.code]), **HX)
        html = response.content.decode()
        assert response.status_code == 200
        volume_key = f"{volume.sku}-free-volume_offer"
        reward_key = f"{reward.sku}-free-reward"
        # The paid line keeps its SKU test ids; each free line gets its own.
        assert f'data-testid="line-{paid.sku}"' in html
        assert f'data-testid="free-{volume_key}"' in html
        assert f'data-testid="free-{reward_key}"' in html
        assert "Free: volume offer" in html
        assert "Free: reward" in html
        assert "₹0" in html
        assert f'data-testid="pack-{paid.sku}">× 10<' in html  # noqa: RUF001
        assert f'data-testid="pack-{volume_key}">× 1<' in html  # noqa: RUF001
        assert f'data-testid="pack-{reward_key}">× 1<' in html  # noqa: RUF001
        assert "ops-pickrow--free" in html
        # 12 cartons in the bag, 2 of them free.
        assert f'data-testid="free-count-{order.order_number}">(incl. 2 free)' in html
        assert "12 items" in html

    def test_free_lines_must_be_ticked_before_mark_packed(self, client, store, packing_order):
        order, paid, volume, reward = packing_order
        login_with_stores(client, roles.STORE_STAFF, store)
        ticket = ticket_for(client.get(page(store)), order)
        assert set(ticket.pick_ids) == {str(paid.pk), str(volume.pk), str(reward.pk)}
        assert ticket.units == 12
        assert ticket.free_units == 2

    def test_cant_supply_never_cancels_on_a_free_line(self, client, store, packing_order):
        order, paid, volume, reward = packing_order
        login_with_stores(client, roles.STORE_MANAGER, store)
        response = client.get(page(store))
        lines = {line.pk: line for line in ticket_for(response, order).lines}
        # Free cartons never keep an order alone: removing all paid units cancels it.
        assert lines[paid.pk].would_empty is True
        assert lines[volume.pk].would_empty is False
        assert lines[reward.pk].would_empty is False
        html = response.content.decode()
        assert f'data-testid="cant-supply-{volume.sku}-free-volume_offer"' in html
        assert 'data-free="1"' in html
        assert 'data-variant="1 L x 12 (free)"' in html

    def test_two_paid_lines_still_keep_each_other(self, store):
        order, paid, _volume, _reward = with_free_cartons(store, number="JV-FREE-0002")
        other = paid_line(order, VariantFactory(sku="JV-FREE-0002-OIL"), quantity=2)
        ticket = next(
            t for q in packing.build(store).queues for t in q.tickets if t.order.pk == order.pk
        )
        lines = {line.pk: line for line in ticket.lines}
        assert lines[paid.pk].would_empty is False
        assert lines[other.pk].would_empty is False

    def test_rider_handover_ticket_lists_free_cartons(self, client, store):
        order, _paid, volume, reward = with_free_cartons(
            store, OrderStatus.PACKED, number="JV-FREE-0003", pickup_code="R2D4"
        )
        login_with_stores(client, roles.STORE_STAFF, store)
        response = client.get(page(store))
        ticket = ticket_for(response, order)
        assert {line.pk for line in ticket.lines} >= {volume.pk, reward.pk}
        html = response.content.decode()
        assert f'data-testid="free-{volume.sku}-free-volume_offer"' in html
        assert f'data-testid="free-count-{order.order_number}">(incl. 2 free)' in html

    def test_queries_do_not_grow_with_free_lines(self, client, store):
        login_with_stores(client, roles.STORE_STAFF, store)
        with_free_cartons(store, number="JV-FREE-0010")
        client.get(page(store))  # warm-up
        with CaptureQueriesContext(connection) as few:
            assert client.get(page(store)).status_code == 200
        for n in range(11, 14):
            with_free_cartons(store, number=f"JV-FREE-00{n}")
        with CaptureQueriesContext(connection) as many:
            assert client.get(page(store)).status_code == 200
        assert len(many) == len(few)


# --------------------------------------------------------------------------- slip


def test_slip_lists_free_cartons_and_counts_them(client, store, packing_order):
    order, paid, volume, reward = packing_order
    login_with_stores(client, roles.STORE_STAFF, store)
    response = client.get(reverse("ops:packing-slip", args=[store.code, order.pk]))
    html = response.content.decode()
    assert response.status_code == 200
    assert "12 items (incl. 2 free)" in html
    assert f'data-testid="slip-free-{volume.sku}-free-volume_offer">FREE: VOLUME OFFER ₹0' in html
    assert f'data-testid="slip-free-{reward.sku}-free-reward">FREE: REWARD ₹0' in html
    assert f'data-testid="slip-pack-{paid.sku}">Pack 10<' in html
    assert f'data-testid="slip-pack-{volume.sku}-free-volume_offer">Pack 1<' in html


# --------------------------------------------------------------------------- returns


def test_returns_list_marks_free_cartons(client, store):
    order, _paid, volume, reward = with_free_cartons(
        store, OrderStatus.DELIVERY_FAILED, number="JV-FREE-0020"
    )
    rider = active_rider(preferred_store=store)
    now = timezone.now()
    DeliveryTask.objects.create(
        order=order,
        store=store,
        status=TS.RETURNING,
        rider=rider,
        distance_km=Decimal("2.40"),
        payout_amount=Decimal("35.00"),
        search_started_at=now - timedelta(minutes=30),
        assigned_at=now - timedelta(minutes=25),
        assignment_mode="AUTO",
        failed_at=now,
    )
    assert roles.STORE_MANAGER in RECEIVE_RETURN_ROLES
    login_with_stores(client, roles.STORE_MANAGER, store)
    response = client.get(reverse("ops:store-returns-list", args=[store.code]), **HX)
    html = response.content.decode()
    assert response.status_code == 200
    assert f'name="damaged_{volume.pk}"' in html
    assert f'name="damaged_{reward.pk}"' in html
    assert "Free: volume offer" in html
    assert "Free: reward" in html
