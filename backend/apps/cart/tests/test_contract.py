"""Phase 3 R1 contract: cart routes, authentication, the `X-Store-Id` header on every operation,
request validation messages that match the documented examples, and money that is consistent in
every example (the apps build their fakes from them).

The bills are recomputed here independently from 08 §6.2 with the D-09 defaults. Cart behaviour
(compute_bill, stock checks, coupons) is tested in R2.
"""

from decimal import ROUND_HALF_UP, Decimal

import pytest
from django.urls import reverse

from apps.cart import examples as ex
from apps.cart.serializers import (
    CartItemAddSerializer,
    CartItemUpdateSerializer,
    CartUpdateSerializer,
    CouponApplySerializer,
    DeliveryInstructionsSerializer,
)
from apps.promotions import examples as promo

CART_OPERATIONS = [
    ("get", "/api/v1/cart/"),
    ("patch", "/api/v1/cart/"),
    ("delete", "/api/v1/cart/"),
    ("post", "/api/v1/cart/items/"),
    ("patch", "/api/v1/cart/items/501/"),
    ("delete", "/api/v1/cart/items/501/"),
    ("get", "/api/v1/cart/coupons/"),
    ("post", "/api/v1/cart/coupon/"),
    ("delete", "/api/v1/cart/coupon/"),
]
# A valid body for each operation.
VALID_BODIES = {
    ("patch", "/api/v1/cart/"): ex.CART_UPDATE_REQUEST,
    ("post", "/api/v1/cart/items/"): ex.ITEM_ADD_REQUEST,
    ("patch", "/api/v1/cart/items/501/"): ex.ITEM_UPDATE_REQUEST,
    ("post", "/api/v1/cart/coupon/"): ex.COUPON_APPLY_REQUEST,
}

# D-09 defaults (01 §5), as the examples assume them.
MIN_ORDER = Decimal("99.00")
DELIVERY_FEE = Decimal("25.00")
FREE_DELIVERY_FROM = Decimal("299.00")
SMALL_CART_FEE = Decimal("15.00")
SMALL_CART_BELOW = Decimal("149.00")
HANDLING_FEE = Decimal("0.00")
COD_MAX = Decimal("2000.00")
CENT = Decimal("0.01")


def money(value) -> str:
    return str(Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP))


def test_routes():
    assert reverse("cart") == "/api/v1/cart/"
    assert reverse("cart-items") == "/api/v1/cart/items/"
    assert reverse("cart-item-detail", args=[501]) == "/api/v1/cart/items/501/"
    assert reverse("cart-coupons") == "/api/v1/cart/coupons/"
    assert reverse("cart-coupon") == "/api/v1/cart/coupon/"


@pytest.mark.django_db
class TestAccessAndHeaders:
    @pytest.mark.parametrize(("method", "path"), CART_OPERATIONS)
    def test_authentication_required(self, api_client, method, path):
        response = getattr(api_client, method)(path, headers={"X-Store-Id": "1"})
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "AUTH_REQUIRED"

    @pytest.mark.parametrize(("method", "path"), CART_OPERATIONS)
    def test_store_header_required(self, auth_client, method, path):
        response = getattr(auth_client, method)(path, VALID_BODIES.get((method, path)))
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {"X-Store-Id": ["This header is required."]}

    @pytest.mark.parametrize(("method", "path"), CART_OPERATIONS)
    def test_unknown_store(self, auth_client, method, path):
        response = getattr(auth_client, method)(
            path, VALID_BODIES.get((method, path)), headers={"X-Store-Id": "999999"}
        )
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "STORE_NOT_FOUND"

    def test_get_validates_address_id(self, auth_client):
        from apps.stores.tests.factories import DarkStoreFactory

        store = DarkStoreFactory()
        response = auth_client.get(
            "/api/v1/cart/?address_id=0", headers={"X-Store-Id": str(store.pk)}
        )
        assert response.status_code == 400
        assert set(response.json()["error"]["details"]) == {"address_id"}


class TestRequestValidation:
    """The messages in the documented examples are the server's real messages."""

    def test_tip_above_the_maximum(self, settings):
        serializer = CartUpdateSerializer(data={"tip": "500.01"})
        assert not serializer.is_valid()
        assert serializer.errors == {"tip": ["Ensure this value is less than or equal to 500.00."]}

    @pytest.mark.parametrize("tip", ["0.00", "20", "500.00"])
    def test_tip_values(self, tip):
        assert CartUpdateSerializer(data={"tip": tip}).is_valid()

    @pytest.mark.parametrize("tip", ["-1.00", "10.555", "abc"])
    def test_bad_tips(self, tip):
        assert not CartUpdateSerializer(data={"tip": tip}).is_valid()

    def test_repeated_chip(self):
        serializer = CartUpdateSerializer(
            data={"instructions": {"chips": ["LEAVE_AT_DOOR", "LEAVE_AT_DOOR"], "note": ""}}
        )
        assert not serializer.is_valid()
        assert serializer.errors == {"instructions": {"chips": ["Each chip can be selected once."]}}

    def test_instructions(self):
        serializer = DeliveryInstructionsSerializer(data=ex.INSTRUCTIONS)
        assert serializer.is_valid(), serializer.errors
        assert not DeliveryInstructionsSerializer(
            data={"chips": ["RING_TWICE"], "note": ""}
        ).is_valid()
        assert not DeliveryInstructionsSerializer(data={"chips": [], "note": "x" * 201}).is_valid()

    def test_empty_patch_is_valid(self):
        assert CartUpdateSerializer(data={}).is_valid()

    def test_add_quantity_zero_removes(self):
        assert CartItemAddSerializer(data=ex.ITEM_REMOVE_REQUEST).is_valid()

    def test_add_negative_quantity(self):
        serializer = CartItemAddSerializer(data={"variant_id": 1001, "quantity": -1})
        assert not serializer.is_valid()
        assert serializer.errors == {
            "quantity": ["Ensure this value is greater than or equal to 0."]
        }

    def test_update_needs_a_positive_quantity(self):
        serializer = CartItemUpdateSerializer(data={"quantity": 0})
        assert not serializer.is_valid()
        assert serializer.errors == {
            "quantity": ["Ensure this value is greater than or equal to 1."]
        }

    def test_update_quantity_is_required_even_on_patch(self):
        serializer = CartItemUpdateSerializer(data={}, partial=True)
        assert not serializer.is_valid()
        assert serializer.errors == {"quantity": ["This field is required."]}

    def test_blank_coupon_code(self):
        serializer = CouponApplySerializer(data={"code": "  "})
        assert not serializer.is_valid()
        assert serializer.errors == {"code": ["This field may not be blank."]}


# --------------------------------------------------------------------------- money in examples


def recompute(cart: dict) -> dict:
    """08 §6.2 from the lines, the coupon discount and the tip in the example."""
    items = cart["items"]
    if not items:
        return dict(ex.EMPTY_BILL)
    mrp_total = sum(Decimal(line["variant"]["mrp"]) * line["quantity"] for line in items)
    item_total = sum(Decimal(line["variant"]["selling_price"]) * line["quantity"] for line in items)
    coupon = cart["coupon"]
    coupon_discount = Decimal(coupon["discount"]) if coupon else Decimal(0)
    assert coupon_discount <= item_total
    delivery_fee = Decimal(0) if item_total >= FREE_DELIVERY_FROM else DELIVERY_FEE
    small_cart_fee = SMALL_CART_FEE if item_total < SMALL_CART_BELOW else Decimal(0)
    tip = Decimal(cart["tip"])
    grand_total = item_total - coupon_discount + delivery_fee + small_cart_fee + HANDLING_FEE + tip
    return {
        "mrp_total": money(mrp_total),
        "item_total": money(item_total),
        "product_discount": money(mrp_total - item_total),
        "coupon_discount": money(coupon_discount),
        "delivery_fee": money(delivery_fee),
        "small_cart_fee": money(small_cart_fee),
        "handling_fee": money(HANDLING_FEE),
        "tip": money(tip),
        "grand_total": money(grand_total),
        "total_savings": money(mrp_total - item_total + coupon_discount),
    }


@pytest.mark.parametrize("name", list(ex.ALL_CARTS))
class TestCartExamples:
    def test_bill(self, name):
        cart = ex.ALL_CARTS[name]
        assert cart["bill"] == recompute(cart)

    def test_lines(self, name):
        cart = ex.ALL_CARTS[name]
        for line in cart["items"]:
            variant, quantity = line["variant"], line["quantity"]
            assert line["line_mrp_total"] == money(Decimal(variant["mrp"]) * quantity)
            assert line["line_total"] == money(Decimal(variant["selling_price"]) * quantity)
            has_issue = quantity > variant["orderable_quantity"]
            assert (line["issue"] is not None) == has_issue, line["id"]
            if has_issue:
                expected = (
                    "OUT_OF_STOCK"
                    if variant["orderable_quantity"] == 0
                    else ("QUANTITY_UNAVAILABLE")
                )
                assert line["issue"]["code"] == expected
        assert cart["item_count"] == sum(line["quantity"] for line in cart["items"])

    def test_thresholds(self, name):
        cart = ex.ALL_CARTS[name]
        item_total = Decimal(cart["bill"]["item_total"])
        thresholds = cart["thresholds"]
        assert thresholds["min_order_value"] == money(MIN_ORDER)
        assert thresholds["free_delivery_threshold"] == money(FREE_DELIVERY_FROM)
        to_min = MIN_ORDER - item_total
        assert thresholds["amount_to_min_order"] == (money(to_min) if to_min > 0 else None)
        to_free = FREE_DELIVERY_FROM - item_total
        assert thresholds["amount_to_free_delivery"] == (money(to_free) if to_free > 0 else None)

    def test_payment_methods(self, name):
        cart = ex.ALL_CARTS[name]
        methods = {option["method"]: option for option in cart["payment_methods"]}
        assert list(methods) == ["ONLINE", "COD"]
        assert methods["ONLINE"]["is_available"] is True
        cod_ok = Decimal(cart["bill"]["grand_total"]) <= COD_MAX
        assert methods["COD"]["is_available"] is cod_ok
        assert (methods["COD"]["unavailable_reason"] is None) == cod_ok
        assert (methods["COD"]["message"] is None) == cod_ok

    def test_blockers(self, name):
        cart = ex.ALL_CARTS[name]
        codes = [blocker["code"] for blocker in cart["checkout"]["blockers"]]
        assert cart["checkout"]["can_place_order"] is (not codes)
        if not cart["items"]:
            assert codes == ["CART_EMPTY"]
            return
        item_total = Decimal(cart["bill"]["item_total"])
        assert ("MIN_ORDER_NOT_MET" in codes) == (item_total < MIN_ORDER)
        assert ("STOCK_UNAVAILABLE" in codes) == any(line["issue"] for line in cart["items"])
        assert ("ADDRESS_REQUIRED" in codes) == (cart["address"] is None)
        address_bad = cart["address"] is not None and not cart["address"]["is_serviceable"]
        assert ("NOT_SERVICEABLE" in codes) == address_bad
        assert ("STORE_CLOSED" in codes) == (not cart["store"]["is_open"])
        coupon_bad = cart["coupon"] is not None and not cart["coupon"]["is_applicable"]
        assert any(code.startswith("COUPON_") for code in codes) == coupon_bad
        if cart["coupon"] is not None:
            unlock = cart["coupon"]["amount_to_unlock"]
            assert (unlock is not None) == ("MIN_ORDER_NOT_MET" in codes or "Add items" in (
                cart["coupon"]["message"] or ""
            ))  # fmt: skip


def test_thresholds_are_checked_before_the_coupon():
    """D-09: ₹299 of items is free delivery even when the coupon brings the total below it."""
    bill = ex.CART_COUPON_KEEPS_FREE_DELIVERY["bill"]
    assert Decimal(bill["item_total"]) == FREE_DELIVERY_FROM
    assert Decimal(bill["grand_total"]) < FREE_DELIVERY_FROM
    assert bill["delivery_fee"] == "0.00"


def test_the_examples_cover_every_fee_case():
    bills = [cart["bill"] for cart in ex.ALL_CARTS.values()]
    assert any(bill["delivery_fee"] != "0.00" for bill in bills)
    assert any(bill["small_cart_fee"] != "0.00" for bill in bills)
    assert any(bill["coupon_discount"] != "0.00" for bill in bills)
    assert any(bill["tip"] != "0.00" for bill in bills)


class TestCouponExamples:
    """Savings against CART_READY (item total ₹783; ₹558 of it edible oils)."""

    ITEM_TOTAL = Decimal("783.00")
    OILS_SUBTOTAL = Decimal("558.00")

    def discount(self, offer: dict, eligible: Decimal) -> str:
        value = Decimal(offer["value"])
        if offer["discount_type"] == "FLAT":
            amount = value
        else:
            amount = (eligible * value / 100).quantize(CENT, rounding=ROUND_HALF_UP)
        if offer["max_discount"] is not None:
            amount = min(amount, Decimal(offer["max_discount"]))
        return money(min(amount, self.ITEM_TOTAL))

    def test_cart_ready_has_jivo50_applied(self):
        assert ex.CART_READY["bill"]["item_total"] == money(self.ITEM_TOTAL)
        oils = sum(
            Decimal(line["line_total"])
            for line in ex.CART_READY["items"]
            if line["product"]["id"] == 101
        )
        assert oils == self.OILS_SUBTOTAL
        applied = [offer["code"] for offer in promo.COUPON_LIST["results"] if offer["is_applied"]]
        assert applied == [ex.CART_READY["coupon"]["code"]]

    @pytest.mark.parametrize("offer", promo.COUPON_LIST["results"], ids=lambda o: o["code"])
    def test_offer(self, offer):
        eligible = self.OILS_SUBTOTAL if offer["code"] == "OILS15" else self.ITEM_TOTAL
        min_order = Decimal(offer["min_order_value"])
        if offer["is_eligible"]:
            assert offer["savings"] == self.discount(offer, eligible)
            assert offer["ineligible_reason"] is None
            assert offer["message"] is None
            assert offer["amount_to_unlock"] is None
            assert self.ITEM_TOTAL >= min_order
        else:
            assert offer["savings"] is None
            assert offer["ineligible_reason"] is not None
            assert offer["message"]
            if offer["ineligible_reason"] == "MIN_ORDER_VALUE":
                assert offer["amount_to_unlock"] == money(min_order - self.ITEM_TOTAL)
            else:
                assert offer["amount_to_unlock"] is None

    def test_eligible_first_by_savings(self):
        results = promo.COUPON_LIST["results"]
        eligible = [offer for offer in results if offer["is_eligible"]]
        assert results[: len(eligible)] == eligible
        savings = [Decimal(offer["savings"]) for offer in eligible]
        assert savings == sorted(savings, reverse=True)
