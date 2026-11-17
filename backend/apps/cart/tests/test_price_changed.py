"""API request #56 (customer CA-19): a cart line's `previous_selling_price`, the store's selling
price when the customer last set the line's quantity, shown when it differs from today's. Display
only: the bill always uses today's price (`compute_bill()`), and it never blocks checkout. Every
200 is validated against the published `Cart` schema."""

from decimal import Decimal

import pytest

from apps.accounts.tests.factories import UserFactory
from apps.cart.models import CartItem
from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import CART, ITEMS
from apps.cart.tests.test_price_tiers import make_water
from apps.catalog.models import ProductVariant
from apps.inventory.models import StoreInventory

pytestmark = pytest.mark.django_db

api = cart_api.api  # the cart API tests' fixtures
components = cart_api.components


def set_price(variant, price: str) -> None:
    ProductVariant.objects.filter(pk=variant.pk).update(selling_price=Decimal(price))


def set_override(store, variant, price: str | None) -> None:
    StoreInventory.objects.filter(store=store, variant=variant).update(
        price_override=Decimal(price) if price is not None else None
    )


def line_of(body, variant) -> dict:
    return next(line for line in body["items"] if line["variant"]["id"] == variant.pk)


class TestSnapshot:
    def test_a_new_line_has_no_flag_and_stores_the_price(self, api, shop):
        line = api.add(shop.canola_1l, 2)["items"][0]
        assert line["previous_selling_price"] is None
        assert CartItem.objects.get(variant=shop.canola_1l).seen_selling_price == Decimal("279.00")

    def test_selling_price_change_is_flagged_and_billed_at_todays_price(self, api, shop):
        api.add(shop.canola_1l, 2)
        set_price(shop.canola_1l, "299.00")
        body = api.call("get", CART)
        line = body["items"][0]
        assert (line["previous_selling_price"], line["variant"]["selling_price"]) == (
            "279.00",
            "299.00",
        )
        # Money: today's price only; the previous price is never billed.
        assert (line["price_per_unit"], line["line_total"]) == ("299.00", "598.00")
        assert body["bill"]["item_total"] == "598.00"

    def test_a_price_drop_is_flagged_too(self, api, shop):
        api.add(shop.chia, 1)
        set_price(shop.chia, "109.00")
        assert line_of(api.call("get", CART), shop.chia)["previous_selling_price"] == "119.00"

    def test_store_override_change_is_flagged(self, api, shop):
        api.add(shop.canola_1l, 1)
        set_override(shop.store_model, shop.canola_1l, "259.00")
        line = api.call("get", CART)["items"][0]
        assert (line["previous_selling_price"], line["price_per_unit"]) == ("279.00", "259.00")

    def test_back_to_the_seen_price_clears_the_flag(self, api, shop):
        api.add(shop.canola_1l, 1)
        set_price(shop.canola_1l, "299.00")
        set_price(shop.canola_1l, "279.00")
        assert api.call("get", CART)["items"][0]["previous_selling_price"] is None

    def test_not_a_checkout_blocker(self, api, shop, address):
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.canola_1l, 2)
        set_price(shop.canola_1l, "289.00")
        body = api.call("get", CART)
        assert body["items"][0]["previous_selling_price"] == "279.00"
        assert body["items"][0]["issue"] is None
        assert body["checkout"] == {"can_place_order": True, "blockers": []}

    def test_lines_stored_before_the_snapshot_are_never_flagged(self, api, shop):
        """Existing rows (null after the migration) show no flag, whatever the price does."""
        api.add(shop.canola_1l, 2)
        CartItem.objects.update(seen_selling_price=None)
        set_price(shop.canola_1l, "299.00")
        assert api.call("get", CART)["items"][0]["previous_selling_price"] is None


class TestReset:
    def test_a_quantity_change_resets_it(self, api, shop):
        api.add(shop.canola_1l, 2)
        set_price(shop.canola_1l, "299.00")
        assert api.add(shop.canola_1l, 3)["items"][0]["previous_selling_price"] is None
        assert CartItem.objects.get().seen_selling_price == Decimal("299.00")

    def test_a_decrease_resets_it(self, api, shop):
        api.add(shop.canola_1l, 3)
        set_price(shop.canola_1l, "299.00")
        assert api.add(shop.canola_1l, 1)["items"][0]["previous_selling_price"] is None

    def test_setting_the_same_quantity_acknowledges_it(self, api, shop):
        api.add(shop.canola_1l, 2)
        set_price(shop.canola_1l, "299.00")
        line = api.add(shop.canola_1l, 2)["items"][0]
        assert (line["quantity"], line["previous_selling_price"]) == (2, None)

    def test_patching_the_line_resets_it(self, api, shop):
        line_id = api.add(shop.canola_1l, 2)["items"][0]["id"]
        set_price(shop.canola_1l, "299.00")
        body = api.call("patch", f"{ITEMS}{line_id}/", {"quantity": 2})
        assert body["items"][0]["previous_selling_price"] is None

    def test_only_the_line_set_is_reset(self, api, shop):
        api.add(shop.canola_1l, 1)
        api.add(shop.chia, 1)
        set_price(shop.canola_1l, "299.00")
        set_price(shop.chia, "129.00")
        body = api.add(shop.chia, 2)
        assert line_of(body, shop.chia)["previous_selling_price"] is None
        assert line_of(body, shop.canola_1l)["previous_selling_price"] == "279.00"

    def test_a_read_never_resets_it(self, api, shop):
        api.add(shop.canola_1l, 1)
        set_price(shop.canola_1l, "299.00")
        api.call("get", CART)
        assert api.call("get", CART)["items"][0]["previous_selling_price"] == "279.00"
        assert CartItem.objects.get().seen_selling_price == Decimal("279.00")

    def test_removing_and_adding_again_starts_fresh(self, api, shop):
        api.add(shop.canola_1l, 1)
        set_price(shop.canola_1l, "299.00")
        api.add(shop.canola_1l, 0)
        assert api.add(shop.canola_1l, 1)["items"][0]["previous_selling_price"] is None


class TestTiers:
    def test_reaching_a_tier_is_not_a_price_change(self, api, shop):
        """The cart's own units moving it into a volume tier lowers `price_per_unit`, not the
        store's selling price: no flag on any line (ADR 0001 tiers are cart-wide)."""
        litre, half = make_water(shop.store_model)[:2]
        api.add(litre, 20)  # 20 units: tier 5 (₹90)
        body = api.add(half, 10)  # 30 units: tier 25 for both
        first = line_of(body, litre)
        assert (first["price_per_unit"], first["price_tier"]["min_order_units"]) == ("87.00", 25)
        assert {line["previous_selling_price"] for line in body["items"]} == {None}

    def test_tiered_line_compares_the_store_price_and_bills_the_tier(self, api, shop):
        litre = make_water(shop.store_model)[0]
        api.add(litre, 30)  # tier 25: ₹87 a box
        set_price(litre, "88.00")  # the store price (before tiers) changes; the tier does not
        line = api.call("get", CART)["items"][0]
        assert line["previous_selling_price"] == "90.00"
        assert line["variant"]["selling_price"] == "88.00"
        assert (line["price_per_unit"], line["line_total"]) == ("87.00", "2610.00")


class TestStoreFollowing:
    def test_another_stores_price_is_flagged_until_set(self, api, shop):
        api.add(shop.canola_1l, 1)
        set_override(shop.other_store_model, shop.canola_1l, "269.00")
        other = shop.other_store_model
        assert api.call("get", CART, store=other)["items"][0]["previous_selling_price"] == "279.00"
        body = api.add(shop.canola_1l, 1, store=other)
        assert body["items"][0]["previous_selling_price"] is None


class TestIdor:
    def test_another_users_line_stays_404_and_untouched(self, api, shop, make_auth_client):
        other = make_auth_client(UserFactory())
        other.post(ITEMS, {"variant_id": shop.chia.pk, "quantity": 1}, headers=shop.headers())
        theirs = CartItem.objects.get(variant=shop.chia)
        set_price(shop.chia, "129.00")
        api.call("patch", f"{ITEMS}{theirs.pk}/", {"quantity": 1}, status=404)
        theirs.refresh_from_db()
        assert theirs.seen_selling_price == Decimal("119.00")
        body = other.get(CART, headers=shop.headers()).json()
        assert body["items"][0]["previous_selling_price"] == "119.00"
