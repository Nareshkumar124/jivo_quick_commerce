"""Volume (slab) prices in the cart (ADR 0001, 08 §6.2): one tier for the whole cart, chosen by
the units of every tiered item together (any mix of sizes, units the store cannot supply not
counted); each tiered line takes its own price at that tier; variants without tiers are priced
as before. Every 200 is validated against the published `Cart` schema."""

from decimal import Decimal

import pytest

from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import CART, set_stock
from apps.catalog.models import VariantPriceTier
from apps.catalog.tests.factories import ProductFactory, VariantFactory
from apps.inventory.models import StoreInventory
from apps.inventory.tests.factories import stock

pytestmark = pytest.mark.django_db

api = cart_api.api  # the cart API tests' fixtures
components = cart_api.components

D = Decimal
# Jivo Water per-box rates (user, 2026-11-13): min boxes -> (1 L, 500 ml, 250 ml)
SLABS = {
    5: (90, 125, 90),
    25: (87, 122, 87),
    50: (85, 120, 85),
    100: (82, 117, 82),
    250: (80, 115, 80),
}
SIZES = (("1 L x 12", 90), ("500 ml x 24", 125), ("250 ml x 24", 90))


def make_water(store, *, boxes: int = 1000) -> list:
    """The three box sizes with their slabs, `boxes` in stock each, up to 1000 per order."""
    product = ProductFactory(name="Jivo Water")
    sizes = []
    for column, (name, price) in enumerate(SIZES):
        variant = VariantFactory(
            product=product,
            name=name,
            mrp=D(price),
            selling_price=D(price),
            max_qty_per_order=1000,
        )
        for units, prices in SLABS.items():
            VariantPriceTier.objects.create(
                variant=variant, min_order_units=units, price=D(prices[column])
            )
        stock(store, variant, boxes)
        sizes.append(variant)
    return sizes


@pytest.fixture
def water(shop):
    return make_water(shop.store_model)


def prices_of(body) -> dict:
    return {line["variant"]["id"]: line["price_per_unit"] for line in body["items"]}


class TestNoTiers:
    def test_untiered_items_are_priced_as_before(self, api, shop):
        """No tiers: price_per_unit is the selling price, no tier, an empty rate chart."""
        body = api.add(shop.canola_1l, 5)
        line = body["items"][0]
        assert (line["price_per_unit"], line["price_tier"], line["line_total"]) == (
            "279.00",
            None,
            "1395.00",
        )
        assert line["variant"]["price_tiers"] == []
        assert body["bill"]["item_total"] == "1395.00"


class TestSlabs:
    @pytest.mark.parametrize(
        ("boxes", "price", "tier"),
        [
            (4, "90.00", None),  # below the lowest tier: the normal price (the order minimum is 5)
            (5, "90.00", 5),
            (24, "90.00", 5),
            (25, "87.00", 25),
            (49, "87.00", 25),
            (50, "85.00", 50),
            (99, "85.00", 50),
            (100, "82.00", 100),
            (249, "82.00", 100),
            (250, "80.00", 250),
            (600, "80.00", 250),  # above 500: the same rate
        ],
    )
    def test_each_boundary(self, api, water, boxes, price, tier):
        """1 L boxes at each slab boundary (5/25/50/100/250): the bill uses the slab price."""
        body = api.add(water[0], boxes)
        line = body["items"][0]
        assert line["price_per_unit"] == price
        assert line["price_tier"] == (
            None if tier is None else {"min_order_units": tier, "price": price}
        )
        total = f"{D(price) * boxes:.2f}"
        assert line["line_total"] == body["bill"]["item_total"] == total

    def test_rate_chart_is_published(self, api, water):
        body = api.add(water[1], 5)
        assert body["items"][0]["variant"]["price_tiers"] == [
            {"min_order_units": 5, "price": "125.00"},
            {"min_order_units": 25, "price": "122.00"},
            {"min_order_units": 50, "price": "120.00"},
            {"min_order_units": 100, "price": "117.00"},
            {"min_order_units": 250, "price": "115.00"},
        ]

    def test_mixed_sizes_share_one_slab(self, api, shop, water):
        """10 x 1 L + 10 x 500 ml + 5 x 250 ml = 25 boxes: every size at its own 25+ price; an
        item without tiers neither counts nor changes price."""
        one, half, quarter = water
        api.add(one, 10)
        api.add(half, 10)
        api.add(quarter, 5)
        body = api.add(shop.chia, 1)
        assert prices_of(body) == {
            one.pk: "87.00",
            half.pk: "122.00",
            quarter.pk: "87.00",
            shop.chia.pk: "119.00",
        }
        assert body["bill"]["item_total"] == "2644.00"  # 870 + 1220 + 435 + 119
        assert body["bill"]["mrp_total"] == "2750.00"  # 900 + 1250 + 450 + 150
        assert body["bill"]["product_discount"] == "106.00"  # the slab saving (+ chia's)
        # One box fewer: 24 boxes, back to the 5+ prices for every size.
        assert prices_of(api.add(quarter, 4))[one.pk] == "90.00"

    def test_unavailable_units_do_not_count(self, api, shop, water):
        """20 x 1 L + 5 x 500 ml = 25 boxes; the 500 ml sells out, so 20 count (5+ price).
        A line above its stock counts only what can be supplied."""
        one, half, _ = water
        api.add(one, 20)
        assert prices_of(api.add(half, 5))[one.pk] == "87.00"
        set_stock(shop.store_model, half, on_hand=0)
        assert prices_of(api.call("get", CART))[one.pk] == "90.00"
        set_stock(shop.store_model, half, on_hand=1000)
        set_stock(shop.store_model, one, on_hand=19)  # 20 wanted, 19 can be supplied: 24 count
        assert prices_of(api.call("get", CART))[one.pk] == "90.00"

    def test_a_tier_never_raises_a_lower_store_price(self, api, shop, water):
        """A store override (₹80) below the 25+ price (₹87) stays; no tier is shown."""
        one = water[0]
        StoreInventory.objects.filter(store=shop.store_model, variant=one).update(
            price_override=D("80.00")
        )
        line = api.add(one, 25)["items"][0]
        assert (line["price_per_unit"], line["price_tier"]) == ("80.00", None)


def nudge(body) -> tuple:
    t = body["thresholds"]
    return t["tier_units"], t["next_price_tier"]


class TestNextTierNudge:
    """`thresholds.tier_units` / `next_price_tier` and each line's `next_tier_price`, so the app
    can say "Add 1 more box to get ₹87/box" without computing money."""

    def test_no_tiers_means_no_nudge(self, api, shop):
        body = api.add(shop.canola_1l, 2)
        assert nudge(body) == (0, None)
        assert body["items"][0]["next_tier_price"] is None

    def test_one_box_before_the_next_slab(self, api, water):
        """24 boxes: 1 more reaches 25, where the 1 L box drops from ₹90 to ₹87."""
        body = api.add(water[0], 24)
        assert nudge(body) == (24, {"min_order_units": 25, "units_to_next_tier": 1})
        assert body["items"][0]["next_tier_price"] == "87.00"

    def test_a_slab_that_lowers_nothing_is_skipped(self, api, water):
        """4 boxes: the 5+ price equals the normal ₹90, so the nudge points to 25 (₹87)."""
        body = api.add(water[0], 4)
        assert nudge(body) == (4, {"min_order_units": 25, "units_to_next_tier": 21})
        assert body["items"][0]["next_tier_price"] == "87.00"

    @pytest.mark.parametrize("boxes", [250, 600])
    def test_top_slab_has_no_next(self, api, water, boxes):
        body = api.add(water[0], boxes)
        assert nudge(body) == (boxes, None)
        assert body["items"][0]["next_tier_price"] is None

    def test_mixed_sizes_get_their_own_next_price(self, api, shop, water):
        """10 x 1 L + 10 x 500 ml + 4 x 250 ml = 24: each size's 25+ price; an item without
        tiers has none."""
        one, half, quarter = water
        api.add(one, 10)
        api.add(half, 10)
        api.add(quarter, 4)
        body = api.add(shop.chia, 1)
        assert nudge(body) == (24, {"min_order_units": 25, "units_to_next_tier": 1})
        assert {line["variant"]["id"]: line["next_tier_price"] for line in body["items"]} == {
            one.pk: "87.00",
            half.pk: "122.00",
            quarter.pk: "87.00",
            shop.chia.pk: None,
        }

    def test_no_next_price_when_a_lower_store_price_stays(self, api, shop, water):
        """A ₹80 store override: no tier lowers it, so no nudge for that line or the cart."""
        StoreInventory.objects.filter(store=shop.store_model, variant=water[0]).update(
            price_override=D("80.00")
        )
        body = api.add(water[0], 24)
        assert nudge(body) == (24, None)
        assert body["items"][0]["next_tier_price"] is None


class TestQueryCounts:
    def test_cart_and_checkout_stay_flat_with_more_tiered_lines(
        self, api, shop, user, address, django_assert_max_num_queries
    ):
        """09 §1: GET /cart/ and the checkout evaluation (`evaluate()`, used by order
        placement) cost the same with 1 or 6 tiered lines (the tiers are prefetched once)."""
        from apps.cart import services
        from apps.cart.models import Cart

        sizes = make_water(shop.store_model) + make_water(shop.store_model)  # 6 tiered variants
        api.call("patch", CART, {"address_id": address.pk})
        api.add(sizes[0], 5)
        api.call("get", CART)  # warm the per-process caches (store snapshot, app config)

        def evaluate():
            cart = Cart.objects.select_related("coupon", "address").get(user=user)
            return services.evaluate(cart, shop.store, user)

        # Counts are kept as numbers at once: `captured_queries` is read from the live query
        # log, which the next request resets.
        with django_assert_max_num_queries(50) as captured:
            api.call("get", CART)
        read_one = len(captured)
        with django_assert_max_num_queries(50) as captured:
            assert len(evaluate().lines) == 1
        evaluate_one = len(captured)
        assert read_one > 0
        assert evaluate_one > 0
        for variant in sizes[1:]:
            api.add(variant, 5)
        with django_assert_max_num_queries(read_one):
            body = api.call("get", CART)
        assert body["thresholds"]["tier_units"] == 30
        assert {line["price_per_unit"] for line in body["items"]} == {"87.00", "122.00"}
        with django_assert_max_num_queries(evaluate_one):
            assert len(evaluate().lines) == 6
