"""Minimum units per order for the whole cart (2026-11-13; 06 §2.5, 08 §6.2): a store's
`PricingConfig.min_order_units` (0 = off) counted over every line together (any mix of SKUs),
with the store's `order_unit_label` ("cartons"). Modelled on the minimum order value: the cart
`thresholds` show how many units are missing and checkout is blocked with MIN_UNITS_NOT_MET.
Units are what would be ordered once the lines' stock fixes are made: each line counts
min(quantity, orderable_quantity), so an out-of-stock line counts 0."""

import pytest
from django.db import connection

from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import CART, blocker_codes, set_stock
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db

api = cart_api.api  # the cart API tests' fixtures (every 200 checked against the schema)
components = cart_api.components

BLOCKER = "Add {n} more cartons to place your order (minimum 5 cartons)."


@pytest.fixture
def five_cartons(shop):
    return PricingConfig.objects.create(
        store=shop.store_model, min_order_units=5, order_unit_label="cartons"
    )


def units_part(body) -> tuple:
    t = body["thresholds"]
    return t["min_order_units"], t["units_to_min_order"], t["order_unit_label"]


class TestModel:
    def test_defaults_keep_the_rule_off(self, shop):
        config = PricingConfig.objects.create(store=shop.store_model)
        assert (config.min_order_units, config.order_unit_label) == (0, "items")

    @pytest.mark.parametrize(
        ("table", "column", "default"),
        [
            ("stores_pricingconfig", "min_order_units", "0"),
            ("stores_historicalpricingconfig", "min_order_units", "0"),
            ("stores_pricingconfig", "order_unit_label", "'items'::character varying"),
            ("stores_historicalpricingconfig", "order_unit_label", "'items'::character varying"),
        ],
    )
    def test_database_defaults(self, table, column, default):
        """Deploy safety: the previous release (or a code rollback) can still insert pricing
        rows and their history rows, the database fills the rule-off values."""
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT column_default FROM information_schema.columns "
                "WHERE table_name = %s AND column_name = %s",
                [table, column],
            )
            assert cursor.fetchone() == (default,)


class TestRuleOff:
    def test_unchanged_without_a_minimum(self, api, shop):
        """min_order_units 0 (the default): no unit blocker, nothing missing."""
        body = api.add(shop.chia, 1)
        assert units_part(body) == (0, None, "items")
        assert "MIN_UNITS_NOT_MET" not in blocker_codes(body)


class TestMinimumUnits:
    def test_below_the_minimum_blocks_checkout(self, api, shop, address, five_cartons):
        """3 units of a 5-carton minimum: 2 missing, blocked with the store's label."""
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.canola_1l, 2)
        body = api.add(shop.chia, 1)
        assert units_part(body) == (5, 2, "cartons")
        assert body["checkout"] == {
            "can_place_order": False,
            "blockers": [{"code": "MIN_UNITS_NOT_MET", "message": BLOCKER.format(n=2)}],
        }

    @pytest.mark.parametrize(("canola", "chia"), [(2, 3), (4, 3)])
    def test_at_or_above_the_minimum_with_mixed_items(
        self, api, shop, address, five_cartons, canola, chia
    ):
        """Any mix of SKUs counts together: 2 + 3 and 4 + 3 units both meet a minimum of 5."""
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.canola_1l, canola)
        body = api.add(shop.chia, chia)
        assert units_part(body) == (5, None, "cartons")
        assert body["checkout"] == {"can_place_order": True, "blockers": []}

    def test_unavailable_units_are_not_counted(self, api, shop, five_cartons):
        """An out-of-stock line counts 0 and a line above its stock counts what can be supplied:
        3 + 2 units in the cart, the 2 chia now out of stock, so 3 count."""
        api.add(shop.canola_1l, 3)
        api.add(shop.chia, 2)
        set_stock(shop.store_model, shop.chia, on_hand=0)
        body = api.call("get", CART)
        assert units_part(body) == (5, 2, "cartons")
        assert blocker_codes(body)[:2] == ["STOCK_UNAVAILABLE", "MIN_UNITS_NOT_MET"]
        set_stock(shop.store_model, shop.chia, on_hand=1)  # 2 in the cart, 1 can be supplied
        assert units_part(api.call("get", CART)) == (5, 1, "cartons")

    def test_empty_cart_shows_the_whole_minimum(self, api, shop, five_cartons):
        body = api.call("get", CART)
        assert units_part(body) == (5, 5, "cartons")
        assert blocker_codes(body) == ["CART_EMPTY"]
