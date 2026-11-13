"""Per-variant minimum order quantity at order placement and reorder (2026-11-13; 08 §6.1, T1/T2
guards): a line below its variant's minimum (the minimum was raised after it was added) is
refused with 422 `MIN_QTY_REQUIRED` and nothing is placed or reserved; reorder never puts a line
back below the minimum."""

import pytest

from apps.inventory.models import StockReservation, StoreInventory, stock_write
from apps.orders.models import Order

pytestmark = pytest.mark.django_db

REORDER = "/api/v1/orders/{}/reorder/"


def set_minimum(variant, minimum: int) -> None:
    variant.min_qty_per_order = minimum
    variant.save(update_fields=["min_qty_per_order", "updated_at"])


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


class TestPlacement:
    def test_line_below_the_minimum_is_refused(self, checkout, shop):
        """Placement re-checks the minimum: 422 MIN_QTY_REQUIRED naming the item, no order,
        nothing reserved."""
        checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        set_minimum(shop.canola_1l, 5)
        body = checkout.place("COD", status=422)
        assert body["error"] == {
            "code": "MIN_QTY_REQUIRED",
            "message": "You need to order at least 5 of Jivo Cold Pressed Canola Oil 1 L.",
            "details": {"variant_id": shop.canola_1l.pk, "min_qty_per_order": 5},
        }
        assert not Order.objects.exists()
        assert not StockReservation.objects.exists()
        assert reserved(shop, shop.canola_1l) == 0

    def test_stock_problems_are_reported_first(self, checkout, shop):
        """A short line is STOCK_UNAVAILABLE as before; a line below its minimum is not listed
        there (its stock is fine)."""
        checkout.fill((shop.canola_1l, 2), (shop.canola_5l, 2))
        set_minimum(shop.canola_1l, 5)
        row = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_5l)
        row.on_hand = 1
        with stock_write():
            row.save(update_fields=["on_hand"])
        body = checkout.place("ONLINE", status=409)
        assert body["error"]["details"] == {
            "items": [
                {"variant_id": shop.canola_5l.pk, "requested_quantity": 2, "orderable_quantity": 1}
            ]
        }

    def test_at_the_minimum_the_order_is_placed(self, checkout, shop):
        set_minimum(shop.canola_1l, 5)
        checkout.fill((shop.canola_1l, 5))
        order = checkout.place("ONLINE")["order"]
        assert order["items"][0]["quantity"] == 5
        assert reserved(shop, shop.canola_1l) == 5


class TestReorder:
    def test_a_past_order_below_todays_minimum_is_not_put_back(self, checkout, shop):
        """Reorder never adds more than was ordered and never leaves a line below the minimum:
        the 1 L line (2 ordered, minimum now 5) is reported MIN_QTY_REQUIRED, the rest is
        added. A line already at the minimum is left alone and not reported."""
        checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        order_id = checkout.place("COD")["order"]["id"]
        set_minimum(shop.canola_1l, 5)
        response = checkout.client.post(REORDER.format(order_id), headers=checkout.headers)
        assert response.status_code == 200, response.content
        body = response.json()
        assert {line["variant"]["id"]: line["quantity"] for line in body["cart"]["items"]} == {
            shop.chia.pk: 1
        }
        assert body["unavailable"] == [
            {
                "variant_id": shop.canola_1l.pk,
                "product_name": "Jivo Cold Pressed Canola Oil",
                "variant_name": "1 L",
                "requested_quantity": 2,
                "added_quantity": 0,
                "reason": "MIN_QTY_REQUIRED",
            }
        ]
        assert body["added_count"] == 1

        checkout.fill((shop.canola_1l, 5), with_address=False)
        again = checkout.client.post(REORDER.format(order_id), headers=checkout.headers).json()
        assert again["unavailable"] == []
        assert {line["variant"]["id"]: line["quantity"] for line in again["cart"]["items"]} == {
            shop.canola_1l.pk: 5,
            shop.chia.pk: 1,
        }

    def test_a_line_already_below_the_minimum_is_not_raised(self, checkout, shop):
        """The cart still holds 1 unit from before the minimum was raised: reorder of 2 would
        leave it below the minimum, so it stays as it is and is reported."""
        checkout.fill((shop.canola_1l, 2))
        order_id = checkout.place("COD")["order"]["id"]
        checkout.fill((shop.canola_1l, 1), with_address=False)
        set_minimum(shop.canola_1l, 5)
        body = checkout.client.post(REORDER.format(order_id), headers=checkout.headers).json()
        assert body["cart"]["items"][0]["quantity"] == 1
        assert body["unavailable"][0]["reason"] == "MIN_QTY_REQUIRED"
        assert body["unavailable"][0]["added_quantity"] == 1
