"""Orders admin: free cartons (ADR 0002).

- Free lines show a "Free: volume offer" / "Free: reward" badge, their stored ₹0 price and line
  total, and their quantity. Paid lines show "-" in that column.
- The bill stays as stored (grand total and item total unchanged) and adds one row, the free
  cartons' MRP value from the backend's helper, only on orders with free cartons.
- The role matrix and store scoping are unchanged on an order with free cartons.
"""

from decimal import Decimal

import pytest
from django.contrib import admin
from django.urls import reverse

from apps.accounts import roles
from apps.catalog.tests.factories import VariantFactory
from apps.ops_console.tests.helpers import (
    ORDER_VIEW_ROLES,
    PRINCIPALS,
    STORE_SCOPED,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.orders.admin import FREE_VALUE_LABEL, OrderItemInline
from apps.orders.choices import FreeSource
from apps.orders.models import Order, OrderItem
from apps.orders.tests.factories import OrderFactory
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


def line(order, variant, *, quantity, source=None) -> OrderItem:
    free = source is not None
    price = Decimal("0.00") if free else variant.selling_price
    return OrderItem.objects.create(
        order=order,
        variant=variant,
        product=variant.product,
        product_name="Jivo Water",
        variant_name=variant.name,
        sku=variant.sku,
        mrp=variant.mrp,
        selling_price=price,
        quantity=quantity,
        line_total=price * quantity,
        is_free=free,
        free_source=source or "",
    )


@pytest.fixture
def shop():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    order = OrderFactory(
        store=own,
        order_number="JV-FREE-000101",
        mrp_total=Decimal("1100.00"),
        item_total=Decimal("1100.00"),
        product_discount=Decimal("0.00"),
        grand_total=Decimal("1100.00"),
    )
    water_1l = VariantFactory(
        sku="JW-1L", name="1 L x 12", mrp=Decimal("110.00"), selling_price=Decimal("110.00")
    )
    water_500 = VariantFactory(
        sku="JW-500", name="500 ml x 24", mrp=Decimal("140.00"), selling_price=Decimal("140.00")
    )
    line(order, water_1l, quantity=10)
    line(order, water_1l, quantity=1, source=FreeSource.VOLUME_OFFER)
    line(order, water_500, quantity=1, source=FreeSource.REWARD)
    other_order = OrderFactory(store=other, order_number="JV-FREE-000202")
    line(other_order, water_1l, quantity=1, source=FreeSource.VOLUME_OFFER)
    return {"own": own, "other": other, "order": order, "other_order": other_order}


def change_url(order) -> str:
    return reverse("admin:orders_order_change", args=[order.pk])


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_matrix_unchanged_on_an_order_with_free_cartons(client, shop, principal):
    login_with_stores(client, principal, shop["own"])
    response = client.get(change_url(shop["order"]))
    assert response.status_code == expected_status(principal, ORDER_VIEW_ROLES), principal


@pytest.mark.parametrize("role", sorted(STORE_SCOPED))
def test_other_store_order_with_free_cartons_is_404(client, shop, role):
    login_with_stores(client, role, shop["own"])
    assert client.get(change_url(shop["other_order"])).status_code == 404


class TestDetail:
    def test_free_lines_show_badge_price_and_quantity(self, client, shop):
        login_with_stores(client, roles.STORE_STAFF, shop["own"])
        response = client.get(change_url(shop["order"]))
        html = response.content.decode()
        assert response.status_code == 200
        assert "Free: volume offer" in html
        assert "Free: reward" in html
        assert "₹0.00" in html  # stored selling price and line total of the free lines
        inline = OrderItemInline(Order, admin.site)
        rows = {
            (item.sku, item.free_source): inline.free_badge(item)
            for item in shop["order"].items.all()
        }
        assert rows == {
            ("JW-1L", ""): "-",
            ("JW-1L", FreeSource.VOLUME_OFFER): "Free: volume offer",
            ("JW-500", FreeSource.REWARD): "Free: reward",
        }

    def test_bill_as_stored_plus_the_free_cartons_value(self, client, shop):
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(change_url(shop["order"])).content.decode()
        assert FREE_VALUE_LABEL in html
        # 1 x ₹110 (1 L) + 1 x ₹140 (500 ml), from `orders.presenters.free_items_value`.
        assert "₹250.00" in html
        # Item total and grand total stay as stored: free cartons are not charged.
        assert html.count("₹1,100.00") >= 2

    def test_no_free_row_without_free_cartons(self, client, shop):
        plain = OrderFactory(store=shop["own"], order_number="JV-FREE-000303")
        line(plain, VariantFactory(), quantity=2)
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(change_url(plain)).content.decode()
        assert FREE_VALUE_LABEL not in html
