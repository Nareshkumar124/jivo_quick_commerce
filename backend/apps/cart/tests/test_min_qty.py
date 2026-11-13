"""Per-variant minimum order quantity in the cart (2026-11-13; 06 §2.5, 08 §6.1): a line of 1 to
`min_qty_per_order` - 1 units is refused with 422 `MIN_QTY_REQUIRED`, when adding and when
lowering; 0 always removes; a line left below a raised minimum is flagged and blocks checkout;
`min_qty_per_order` 1 behaves exactly as before. Every 200 is checked against the `Cart` schema
(which now requires `variant.min_qty_per_order`)."""

import pytest

from apps.cart.models import CartItem
from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import ITEMS, blocker_codes, set_stock

pytestmark = pytest.mark.django_db

# The cart API tests' fixtures: `api` calls the cart as the signed-in customer and validates
# every 200 against the published schema.
api = cart_api.api
components = cart_api.components


def set_minimum(variant, minimum: int, maximum: int | None = None) -> None:
    variant.min_qty_per_order = minimum
    if maximum is not None:
        variant.max_qty_per_order = maximum
    variant.save()


def min_error(variant, minimum: int) -> dict:
    return {
        "code": "MIN_QTY_REQUIRED",
        "message": f"You need to order at least {minimum} of this item.",
        "details": {"variant_id": variant.pk, "min_qty_per_order": minimum},
    }


@pytest.fixture
def carton(shop):
    """The 1 L line sold only from 5 units (10 in stock, at most 10 per order)."""
    set_minimum(shop.canola_1l, 5, maximum=10)
    return shop.canola_1l


class TestAdding:
    @pytest.mark.parametrize("quantity", [1, 4])
    def test_below_the_minimum_is_refused(self, api, carton, quantity):
        """Adding 1..min-1 units: 422 MIN_QTY_REQUIRED, nothing saved."""
        body = api.add(carton, quantity, status=422)
        assert body["error"] == min_error(carton, 5)
        assert not CartItem.objects.exists()

    def test_the_minimum_and_above_are_accepted(self, api, carton):
        body = api.add(carton, 5)
        line = body["items"][0]
        assert (line["quantity"], line["issue"]) == (5, None)
        assert line["variant"]["min_qty_per_order"] == 5
        assert api.add(carton, 10)["items"][0]["quantity"] == 10

    def test_maximum_is_still_checked_first(self, api, carton):
        assert api.add(carton, 11, status=422)["error"]["code"] == "MAX_QTY_EXCEEDED"

    def test_fewer_free_units_than_the_minimum_is_out_of_stock(self, api, shop, carton):
        """4 free with a minimum of 5: the item cannot be sold, orderable_quantity 0."""
        set_stock(shop.store_model, carton, on_hand=10, reserved=6)
        body = api.add(carton, 5, status=409)
        assert body["error"]["message"] == "This item is out of stock."
        assert body["error"]["details"]["items"] == [
            {"variant_id": carton.pk, "requested_quantity": 5, "orderable_quantity": 0}
        ]

    def test_increasing_a_line_still_below_the_minimum(self, api, shop):
        """A line added before the minimum was raised: raising it to less than the minimum is
        refused, raising it to the minimum is accepted."""
        api.add(shop.canola_1l, 2)
        set_minimum(shop.canola_1l, 5)
        assert api.add(shop.canola_1l, 3, status=422)["error"] == min_error(shop.canola_1l, 5)
        assert api.add(shop.canola_1l, 5)["items"][0]["quantity"] == 5


class TestLowering:
    def test_below_the_minimum_is_refused_and_zero_removes(self, api, carton):
        """A customer at the minimum who wants fewer must remove the line (quantity 0)."""
        api.add(carton, 7)
        assert api.add(carton, 5)["items"][0]["quantity"] == 5
        assert api.add(carton, 4, status=422)["error"] == min_error(carton, 5)
        assert CartItem.objects.get(variant=carton).quantity == 5
        assert api.add(carton, 0)["items"] == []

    def test_patch_below_the_minimum_is_refused_and_delete_works(self, api, carton):
        line_id = api.add(carton, 6)["items"][0]["id"]
        body = api.call("patch", f"{ITEMS}{line_id}/", {"quantity": 1}, status=422)
        assert body["error"] == min_error(carton, 5)
        assert api.call("patch", f"{ITEMS}{line_id}/", {"quantity": 5})["items"][0]["quantity"] == 5
        assert api.call("delete", f"{ITEMS}{line_id}/")["items"] == []

    def test_a_stock_issue_can_still_be_stepped_down_to_the_minimum(self, api, shop, carton):
        """Lowering is never refused for stock: 8 in the cart, 6 left, step down to 6."""
        api.add(carton, 8)
        set_stock(shop.store_model, carton, on_hand=6)
        flagged = api.add(carton, 7)
        assert flagged["items"][0]["issue"]["code"] == "QUANTITY_UNAVAILABLE"
        assert api.add(carton, 6)["items"][0]["issue"] is None


class TestMinimumOne:
    def test_behaves_as_before(self, api, shop):
        """min_qty_per_order 1 (the default): any quantity from 1 up and down is accepted."""
        assert shop.chia.min_qty_per_order == 1
        assert api.add(shop.chia, 1)["items"][0]["variant"]["min_qty_per_order"] == 1
        api.add(shop.chia, 3)
        body = api.add(shop.chia, 1)
        assert (body["items"][0]["quantity"], body["items"][0]["issue"]) == (1, None)


class TestRaisedMinimum:
    def test_line_below_a_raised_minimum_is_flagged_and_blocks_checkout(self, api, shop, address):
        """The minimum was raised after the line was added: the line keeps its quantity, is
        flagged MIN_QTY_REQUIRED and blocks checkout (not as a stock problem)."""
        api.call("patch", "/api/v1/cart/", {"address_id": address.pk})
        api.add(shop.canola_1l, 2)
        set_minimum(shop.canola_1l, 5)
        body = api.call("get", "/api/v1/cart/")
        line = body["items"][0]
        assert line["quantity"] == 2
        assert line["variant"]["orderable_quantity"] == 5
        assert line["issue"] == {
            "code": "MIN_QTY_REQUIRED",
            "message": "At least 5 per order. Increase the quantity to 5 or remove it.",
        }
        assert blocker_codes(body) == ["MIN_QTY_REQUIRED"]
        assert body["checkout"]["can_place_order"] is False
        assert body["checkout"]["blockers"][0]["message"] == (
            "Some items are below their minimum quantity per order. Increase them or remove "
            "them to continue."
        )
        fixed = api.add(shop.canola_1l, 5)
        assert fixed["items"][0]["issue"] is None
        assert fixed["checkout"]["can_place_order"] is True

    def test_stock_issue_comes_before_the_minimum(self, api, shop):
        """A line below its minimum whose store also cannot supply the minimum is OUT_OF_STOCK
        (orderable 0), a stock problem."""
        api.add(shop.canola_1l, 2)
        set_minimum(shop.canola_1l, 5)
        set_stock(shop.store_model, shop.canola_1l, on_hand=4)
        body = api.call("get", "/api/v1/cart/")
        assert body["items"][0]["issue"]["code"] == "OUT_OF_STOCK"
        assert blocker_codes(body) == ["STOCK_UNAVAILABLE", "ADDRESS_REQUIRED"]
