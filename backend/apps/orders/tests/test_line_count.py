"""API request #57 (customer CA-29): `line_count` (distinct order lines) on `GET /orders/` rows,
next to `item_count` (units); and the reorder side of API request #56 (cart lines added by a
reorder take today's price as the price the customer saw)."""

from decimal import Decimal

import jsonschema
import pytest
from django.contrib.auth.models import Group
from django.db import connection
from django.test.utils import CaptureQueriesContext
from drf_spectacular.generators import SchemaGenerator

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.cart.models import CartItem
from apps.catalog.models import ProductVariant
from apps.orders import store_ops
from apps.orders.models import Order
from apps.orders.tests.conftest import ORDERS
from apps.orders.tests.factories import OrderFactory
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db


def place(checkout, *lines) -> Order:
    checkout.fill(*lines)
    return Order.objects.get(pk=checkout.place("COD")["order"]["id"])


def rows(checkout) -> dict:
    response = checkout.client.get(ORDERS)
    assert response.status_code == 200
    body = response.json()
    components = SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]
    jsonschema.validate(
        body,
        to_json_schema({"$ref": "#/components/schemas/PaginatedOrderSummaryList"}, components),
    )
    return {row["id"]: row for row in body["results"]}


class TestLineCount:
    def test_lines_and_units(self, checkout, shop):
        order = place(checkout, (shop.canola_1l, 2), (shop.chia, 3), (shop.flax, 1))
        row = rows(checkout)[order.pk]
        assert (row["line_count"], row["item_count"]) == (3, 6)

    def test_single_line_of_many_units(self, checkout, shop):
        order = place(checkout, (shop.chia, 4))
        row = rows(checkout)[order.pk]
        assert (row["line_count"], row["item_count"]) == (1, 4)

    def test_a_line_found_unavailable_still_counts(self, checkout, shop):
        """Like the detail's `items` and the row's `images`: the line stays on the order."""
        order = place(checkout, (shop.canola_1l, 2), (shop.chia, 1))
        staff = StaffUserFactory()
        staff.groups.add(Group.objects.get(name=roles.OPS))
        store_ops.accept_order(order.pk, by=staff)
        line = order.items.get(variant=shop.chia)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        row = rows(checkout)[order.pk]
        assert (row["line_count"], row["item_count"]) == (2, 2)

    def test_list_stays_scoped(self, checkout, shop):
        """IDOR unaffected: another customer's order is never listed."""
        mine = place(checkout, (shop.chia, 1))
        OrderFactory(user=UserFactory())
        assert list(rows(checkout)) == [mine.pk]

    def test_query_count_does_not_grow_with_orders_or_lines(self, checkout, shop, user):
        """Rule 15: `line_count` comes from the prefetched lines, never a query per order."""

        def count():
            with CaptureQueriesContext(connection) as queries:
                assert checkout.client.get(ORDERS).status_code == 200
            return len(queries)

        place(checkout, (shop.canola_1l, 1))
        one = count()
        place(checkout, (shop.canola_1l, 1), (shop.chia, 2), (shop.flax, 1))
        for _ in range(3):
            OrderFactory(user=user, status="DELIVERED")
        assert count() == one
        assert one <= 8


class TestReorderSeenPrice:
    URL = "/api/v1/orders/{}/reorder/"

    def test_reordered_lines_take_todays_price_without_a_flag(self, checkout, shop):
        order = place(checkout, (shop.canola_1l, 2))
        ProductVariant.objects.filter(pk=shop.canola_1l.pk).update(selling_price=Decimal("299.00"))
        response = checkout.client.post(self.URL.format(order.pk), headers=checkout.headers)
        assert response.status_code == 200, response.content
        line = response.json()["cart"]["items"][0]
        assert (line["price_per_unit"], line["previous_selling_price"]) == ("299.00", None)
        assert CartItem.objects.get(variant=shop.canola_1l).seen_selling_price == Decimal("299.00")

    def test_raising_an_existing_line_resets_its_price(self, checkout, shop):
        order = place(checkout, (shop.canola_1l, 3))
        checkout.fill((shop.canola_1l, 1), with_address=False)
        ProductVariant.objects.filter(pk=shop.canola_1l.pk).update(selling_price=Decimal("289.00"))
        assert checkout.cart()["items"][0]["previous_selling_price"] == "279.00"
        response = checkout.client.post(self.URL.format(order.pk), headers=checkout.headers)
        line = response.json()["cart"]["items"][0]
        assert (line["quantity"], line["previous_selling_price"]) == (3, None)
