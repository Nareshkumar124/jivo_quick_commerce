"""ADR 0004 §2: `catalog.services.set_variant_price()`. MRP = selling price = the new price; its
validation, permission and audit; carts and checkout use it at once; placed orders keep their
price snapshot (08 §6)."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.catalog.models import VariantPriceTier
from apps.catalog.services import MSG_PRICE_HAS_TIERS, MSG_PRICE_INVALID, set_variant_price
from apps.core.models import AuditLog
from apps.inventory.models import StoreInventory
from apps.orders.models import OrderItem

pytestmark = pytest.mark.django_db


@pytest.fixture
def admin_user():
    return SuperUserFactory()


def role_user(role):
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


class TestService:
    def test_sets_mrp_and_selling_price(self, shop, admin_user):
        variant = shop.canola_1l  # MRP 349, selling 279
        assert set_variant_price(variant, "300", actor=admin_user) is True
        assert (variant.mrp, variant.selling_price) == (Decimal("300.00"), Decimal("300.00"))
        variant.refresh_from_db()
        assert (variant.mrp, variant.selling_price) == (Decimal("300.00"), Decimal("300.00"))
        assert set_variant_price(variant, Decimal("300.00"), actor=admin_user) is False
        entry = AuditLog.objects.get(action="variant.price")
        assert (entry.actor, entry.object_type, entry.object_id) == (
            admin_user,
            "catalog.productvariant",
            str(variant.pk),
        )
        assert entry.changes == {
            "mrp": ["349.00", "300.00"],
            "selling_price": ["279.00", "300.00"],
        }
        assert variant.history.count() >= 2  # saved through the model (price history)

    @pytest.mark.parametrize(
        "price",
        [
            *("0", "-1", "0.001", "10000.01", "abc", "", "NaN", None, True),
            # Strict parsing (code review): plain ASCII digits and one dot only
            *("1_000", "1 000", "1e3", "+5", "5.", ".5", "1.2.3", "Infinity"),
            *("\u0663\u0660\u0660", "\uff13\uff10\uff10", "\u0969\u0966\u0966", "300\u00a0"),
        ],
        ids=lambda value: repr(value),
    )
    def test_invalid_prices(self, shop, admin_user, price):
        with pytest.raises(ValidationError) as error:
            set_variant_price(shop.canola_1l, price, actor=admin_user)
        assert error.value.message_dict == {"price": [MSG_PRICE_INVALID]}
        assert not AuditLog.objects.exists()

    def test_limits(self, shop, admin_user):
        assert set_variant_price(shop.canola_1l, "0.01", actor=admin_user)
        assert set_variant_price(shop.canola_1l, "10000", actor=admin_user)
        assert set_variant_price(shop.canola_1l, " 299.5 ", actor=admin_user)  # outer spaces ok
        assert shop.canola_1l.selling_price == Decimal("299.50")
        assert set_variant_price(shop.canola_1l, Decimal("310.00"), actor=admin_user)
        assert set_variant_price(shop.canola_1l, 320, actor=admin_user)

    def test_refused_while_price_tiers_exist(self, shop, admin_user):
        VariantPriceTier.objects.create(
            variant=shop.canola_1l, min_order_units=5, price=Decimal("250.00")
        )
        with pytest.raises(ValidationError) as error:
            set_variant_price(shop.canola_1l, "300", actor=admin_user)
        assert error.value.message_dict == {"price": [MSG_PRICE_HAS_TIERS]}
        shop.canola_1l.refresh_from_db()
        assert shop.canola_1l.mrp == Decimal("349.00")

    def test_store_override_above_the_new_price_is_refused(self, shop, admin_user):
        StoreInventory.objects.filter(store=shop.store_model, variant=shop.canola_1l).update(
            price_override=Decimal("260.00")
        )
        with pytest.raises(ValidationError) as error:
            set_variant_price(shop.canola_1l, "250", actor=admin_user)
        assert "mrp" in error.value.message_dict
        assert set_variant_price(shop.canola_1l, "270", actor=admin_user)  # override 260 wins

    @pytest.mark.parametrize("role", [roles.CATALOG_MANAGER, roles.OPS, roles.FINANCE])
    def test_other_roles_are_refused(self, shop, role):
        with pytest.raises(PermissionDenied):
            set_variant_price(shop.canola_1l, "300", actor=role_user(role))
        with pytest.raises(PermissionDenied):
            set_variant_price(shop.canola_1l, "300", actor=None)

    def test_super_admin_role_may(self, shop):
        assert set_variant_price(shop.canola_1l, "300", actor=role_user(roles.SUPER_ADMIN))


class TestCartCheckoutAndOrders:
    def test_live_cart_checkout_and_the_order_snapshot(self, checkout, shop, admin_user):
        cart = checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        assert cart["items"][0]["variant"]["selling_price"] == "279.00"
        set_variant_price(shop.canola_1l, "300", actor=admin_user)
        cart = checkout.cart()  # the cart reads the live price at once
        line = cart["items"][0]
        assert (line["variant"]["selling_price"], line["variant"]["mrp"]) == ("300.00", "300.00")
        assert line["line_total"] == "600.00"
        body = checkout.place("COD", expected=cart["bill"]["grand_total"])
        assert body["order"]["bill"] == cart["bill"]
        item = OrderItem.objects.get(order_id=body["order"]["id"], variant=shop.canola_1l)
        assert (item.mrp, item.selling_price) == (Decimal("300.00"), Decimal("300.00"))
        # A later change never re-prices the placed order (08 §6)
        set_variant_price(shop.canola_1l, "320", actor=admin_user)
        item.refresh_from_db()
        assert (item.mrp, item.selling_price) == (Decimal("300.00"), Decimal("300.00"))
        detail = checkout.client.get(f"/api/v1/orders/{body['order']['id']}/").json()
        assert detail["bill"] == body["order"]["bill"]
        prices = {i["variant_id"]: i["selling_price"] for i in detail["items"]}
        assert prices[shop.canola_1l.pk] == "300.00"

    def test_old_displayed_total_is_refused_after_a_change(self, checkout, shop, admin_user):
        """08 T1: a client still showing the old total gets PRICE_CHANGED, never the old
        price."""
        cart = checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        set_variant_price(shop.canola_1l, "300", actor=admin_user)
        body = checkout.place("COD", expected=cart["bill"]["grand_total"], status=409)
        assert body["error"]["code"] == "PRICE_CHANGED"
