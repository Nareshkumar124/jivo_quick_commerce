"""Volume (slab) prices at order placement and after (ADR 0001, 08 §6.2/§6.3): the order line
snapshots the slab price the cart showed, and a later recalculation (items unavailable, T8a)
keeps those prices: it never re-tiers, so the amount payable never goes up."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.cart.tests.test_price_tiers import make_water
from apps.catalog.models import VariantPriceTier
from apps.catalog.tests.factories import ProductFactory, VariantFactory
from apps.inventory.tests.factories import stock
from apps.orders import store_ops
from apps.orders.models import Order
from apps.promotions.models import Coupon
from apps.stores.models import PricingConfig
from apps.stores.services import grant_store_access

pytestmark = pytest.mark.django_db

D = Decimal


@pytest.fixture
def water(shop):
    # COD up to ₹1 lakh so a wholesale order can be placed as cash on delivery.
    PricingConfig.objects.create(store=shop.store_model, cod_max_order_value=D("100000.00"))
    return make_water(shop.store_model)


def test_order_lines_snapshot_the_slab_price(checkout, water):
    """25 x 1 L at ₹87 (the 25+ slab): the order's line and bill equal what the cart showed."""
    cart = checkout.fill((water[0], 25))
    assert cart["items"][0]["price_per_unit"] == "87.00"
    body = checkout.place("COD")
    order = Order.objects.get(pk=body["order"]["id"])
    item = order.items.get()
    assert (item.mrp, item.selling_price, item.line_total) == (D("90.00"), D("87.00"), D("2175.00"))
    assert (order.item_total, order.product_discount) == (D("2175.00"), D("75.00"))
    assert body["order"]["bill"] == cart["bill"]


def test_partial_unavailability_keeps_the_order_prices(checkout, shop, water):
    """25 boxes at ₹87; the store cannot supply 1. The 24 left stay at ₹87 (no re-tiering to
    the 5+ price of ₹90), so the amount payable only goes down."""
    checkout.fill((water[0], 25))
    order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
    staff = StaffUserFactory()
    staff.groups.add(Group.objects.get(name=roles.STORE_STAFF))
    grant_store_access(staff, shop.store_model)
    store_ops.accept_order(order.pk, by=staff)
    store_ops.start_packing(order.pk, by=staff)
    line = order.items.get()
    before = order.grand_total
    store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
    order.refresh_from_db()
    line.refresh_from_db()
    assert (line.selling_price, line.line_total) == (D("87.00"), D("2088.00"))  # 24 x 87
    assert order.item_total == D("2088.00")
    assert order.grand_total < before


def tiered(shop, tiers: dict, price: str = "90.00"):
    """A variant at `price` (MRP = selling price) with `tiers` {min units: price}, 1000 in
    stock, up to 1000 per order."""
    variant = VariantFactory(
        product=ProductFactory(),
        mrp=D(price),
        selling_price=D(price),
        max_qty_per_order=1000,
    )
    for units, tier_price in tiers.items():
        VariantPriceTier.objects.create(variant=variant, min_order_units=units, price=D(tier_price))
    stock(shop.store_model, variant, 1000)
    return variant


def pricing(shop, **values) -> None:
    PricingConfig.objects.filter(store=shop.store_model).update(**values)


@pytest.mark.parametrize(
    ("coupon", "discount"),
    [
        # 10% of the tiered 25 x 87 = 2175 (not of 25 x 90 = 2250)
        ({"discount_type": "PERCENT", "value": D(10), "max_discount": D(1000)}, "217.50"),
        # minimum ₹2,200: met at the normal price (2250) but not at the slab price (2175)
        ({"discount_type": "FLAT", "value": D(50), "min_order_value": D("2200.00")}, None),
    ],
    ids=["percent-on-tiered-total", "min-order-on-tiered-total"],
)
def test_coupon_uses_the_tiered_item_total(checkout, water, coupon, discount):
    """Coupons see the slab prices: the discount and the coupon's minimum order are computed
    on the tiered item total."""
    Coupon.objects.create(code="SLAB", title="Slab test", **{"min_order_value": D(0), **coupon})
    checkout.fill((water[0], 25))
    response = checkout.client.post(
        "/api/v1/cart/coupon/", {"code": "SLAB"}, headers=checkout.headers
    )
    if discount is None:
        assert response.status_code == 422
        error = response.json()["error"]
        assert (error["code"], error["details"]["amount_to_unlock"]) == (
            "COUPON_NOT_ELIGIBLE",
            "25.00",
        )
        return
    assert response.status_code == 200, response.content
    order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
    assert (order.item_total, order.coupon_discount) == (D("2175.00"), D(discount))
    assert order.grand_total == D("2175.00") - D(discount)


@pytest.mark.parametrize(
    ("config", "fee_field", "fee"),
    [
        ({"free_delivery_threshold": D("2200.00")}, "delivery_fee", D("25.00")),
        ({"small_cart_threshold": D("2200.00")}, "small_cart_fee", D("15.00")),
    ],
    ids=["delivery-fee", "small-cart-fee"],
)
def test_fee_threshold_crossed_only_by_the_slab_price(
    checkout, shop, water, config, fee_field, fee
):
    """25 boxes are ₹2,250 at the normal price but ₹2,175 at the slab price: a ₹2,200 fee
    threshold is judged on the slab price, so the fee applies."""
    pricing(shop, **config)
    checkout.fill((water[0], 25))
    order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
    assert order.item_total == D("2175.00")
    assert getattr(order, fee_field) == fee
    assert order.grand_total == D("2175.00") + fee


def test_variants_with_different_tier_tables_share_the_units(checkout, shop, water):
    """25 tiered units: A reaches its 25+ price; B has no 25 tier and keeps its 5+ price; C's
    only tier starts at 50, so it keeps its normal price but its units still count."""
    a = tiered(shop, {5: "90.00", 25: "87.00"})
    b = tiered(shop, {5: "120.00"}, price="125.00")
    c = tiered(shop, {50: "80.00"})
    cart = checkout.fill((a, 10), (b, 10), (c, 5))
    assert cart["thresholds"]["tier_units"] == 25
    order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
    prices = {item.variant_id: item.selling_price for item in order.items.all()}
    assert prices == {a.pk: D("87.00"), b.pk: D("120.00"), c.pk: D("90.00")}
    assert order.item_total == D("2520.00")  # 870 + 1200 + 450


@pytest.mark.parametrize(("units", "price"), [(1, "80.00"), (9, "80.00"), (10, "70.00")])
def test_lowest_tier_at_one_unit(checkout, shop, water, units, price):
    """A tier from 1 unit applies to the very first unit."""
    pricing(shop, min_order_value=D("0.00"))
    variant = tiered(shop, {1: "80.00", 10: "70.00"})
    checkout.fill((variant, units))
    order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
    item = order.items.get()
    assert (item.selling_price, order.item_total) == (D(price), D(price) * units)
