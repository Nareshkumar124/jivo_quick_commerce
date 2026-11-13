"""Minimum units per order at placement (2026-11-13; 08 T1/T2 guards): the whole order must have
at least the store's `min_order_units` units (any mix of SKUs), checked exactly like the minimum
order value: 422 MIN_UNITS_NOT_MET, nothing placed or reserved."""

import pytest

from apps.inventory.models import StockReservation
from apps.orders.models import Order
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db


@pytest.fixture
def five_cartons(shop):
    return PricingConfig.objects.create(
        store=shop.store_model, min_order_units=5, order_unit_label="cartons"
    )


def test_below_the_minimum_units_is_refused(checkout, shop, five_cartons):
    """3 of 5 cartons: 422 MIN_UNITS_NOT_MET with what is missing; no order, nothing held."""
    checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
    body = checkout.place("COD", status=422)
    assert body["error"] == {
        "code": "MIN_UNITS_NOT_MET",
        "message": "Add 2 more cartons to place your order (minimum 5 cartons).",
        "details": {
            "min_order_units": 5,
            "order_units": 3,
            "units_to_min_order": 2,
            "order_unit_label": "cartons",
        },
    }
    assert not Order.objects.exists()
    assert not StockReservation.objects.exists()


def test_mixed_items_at_the_minimum_are_placed(checkout, shop, five_cartons):
    """2 + 3 units of two SKUs meet a minimum of 5."""
    checkout.fill((shop.canola_1l, 2), (shop.chia, 3))
    order = checkout.place("COD")["order"]
    assert sum(item["quantity"] for item in order["items"]) == 5


def test_rule_off_places_a_single_unit(checkout, shop):
    """min_order_units 0 (default): unchanged, one unit is enough."""
    checkout.fill((shop.canola_1l, 1))
    assert checkout.place("COD")["order"]["status"] == "PLACED"
