"""`compute_bill()` (08 §6.2) with the D-09 defaults, and the PRICE_CHANGED guard."""

from decimal import Decimal

import pytest

from apps.cart import examples as ex
from apps.cart.services import (
    EMPTY_BILL,
    BillLine,
    PricingRules,
    compute_bill,
    ensure_expected_total,
    pricing_rules,
)
from apps.core.exceptions import ApiError
from apps.promotions.models import Coupon
from apps.stores.models import D09_PRICING, PricingConfig

D09 = PricingRules(**D09_PRICING)
OILS, SEEDS = 11, 3


def line(selling: str, quantity: int = 1, mrp: str | None = None, category=OILS, variant=1):
    return BillLine(
        variant_id=variant,
        category_id=category,
        mrp=Decimal(mrp or selling),
        selling_price=Decimal(selling),
        quantity=quantity,
    )


def coupon(code="TEST", **kwargs) -> Coupon:
    defaults = {"title": code, "discount_type": "FLAT", "value": Decimal("50.00")}
    return Coupon.objects.create(code=code, **{**defaults, **kwargs})


def as_strings(bill) -> dict:
    return bill.as_dict()


class TestFees:
    def test_empty_cart_is_all_zero(self):
        assert compute_bill([], D09, tip=Decimal("20.00")) == EMPTY_BILL
        assert set(EMPTY_BILL.as_dict().values()) == {"0.00"}

    @pytest.mark.parametrize(
        ("item_total", "delivery", "small"),
        [
            ("79.00", "25.00", "15.00"),
            ("148.99", "25.00", "15.00"),
            ("149.00", "25.00", "0.00"),  # small-cart fee only *below* ₹149
            ("298.99", "25.00", "0.00"),
            ("299.00", "0.00", "0.00"),  # free delivery *from* ₹299 (08 §6.2: >=)
            ("1500.00", "0.00", "0.00"),
        ],
    )
    def test_d09_thresholds(self, item_total, delivery, small):
        bill = compute_bill([line(item_total)], D09)
        assert (str(bill.delivery_fee), str(bill.small_cart_fee)) == (delivery, small)
        expected = Decimal(item_total) + Decimal(delivery) + Decimal(small)
        assert bill.grand_total == expected

    def test_totals_and_savings(self):
        bill = compute_bill(
            [line("279.00", 2, mrp="349.00"), line("225.00", 1, mrp="250.00", variant=2)],
            D09,
            tip=Decimal("20"),
        )
        assert as_strings(bill) == ex.CART_READY["bill"] | {
            "coupon_discount": "0.00",
            "grand_total": "803.00",
            "total_savings": "165.00",
        }

    def test_handling_fee_and_no_delivery_fee_store(self):
        rules = PricingRules(
            **{**D09_PRICING, "delivery_fee": Decimal(0), "handling_fee": Decimal("4.50")}
        )
        bill = compute_bill([line("119.00")], rules)
        assert (bill.delivery_fee, bill.handling_fee) == (Decimal("0.00"), Decimal("4.50"))
        assert bill.grand_total == Decimal("138.50")  # 119 + small cart 15 + handling 4.50

    def test_tip_is_rounded_to_the_paisa(self):
        bill = compute_bill([line("300.00")], D09, tip=Decimal("10.005"))
        assert bill.tip == Decimal("10.01")
        assert bill.grand_total == Decimal("310.01")

    def test_pricing_rules_default_to_d09(self, db):
        assert pricing_rules(987654) == D09  # a store without a PricingConfig row
        assert PricingRules.from_config(PricingConfig()) == D09


@pytest.mark.django_db
class TestCoupons:
    def test_thresholds_are_before_the_coupon(self):
        """D-09: ₹299 of items keeps free delivery although the coupon takes the total lower."""
        bill = compute_bill([line("299.00")], D09, coupon=coupon(min_order_value=Decimal(299)))
        assert as_strings(bill) == ex.CART_COUPON_KEEPS_FREE_DELIVERY["bill"]

    def test_flat_coupon_never_exceeds_the_item_total(self):
        bill = compute_bill([line("79.00")], D09, coupon=coupon(value=Decimal("500.00")))
        assert bill.coupon_discount == Decimal("79.00")
        assert bill.grand_total == Decimal("40.00")  # only the fees remain

    def test_percent_rounds_half_up_and_respects_the_cap(self):
        percent = coupon(discount_type="PERCENT", value=Decimal("10.00"))
        assert compute_bill([line("78.35")], D09, coupon=percent).coupon_discount == Decimal(
            "7.84"
        )  # 7.835
        capped = coupon("CAP", discount_type="PERCENT", value=Decimal("50"), max_discount=10)
        assert compute_bill([line("300.00")], D09, coupon=capped).coupon_discount == Decimal(
            "10.00"
        )

    def test_category_coupon_only_on_its_items_and_capped_at_their_total(self, shop):
        flat = coupon("OILS100", value=Decimal("100.00"))
        flat.categories.add(shop.oils)  # top level: includes Canola Oil
        lines = [
            line("79.00", category=shop.canola_cat.pk),
            line("500.00", category=shop.seeds.pk, variant=2),
        ]
        bill = compute_bill(lines, D09, coupon=flat)
        assert bill.coupon_discount == Decimal("79.00")  # PM decision: capped at eligible items
        percent = coupon("OILS15", discount_type="PERCENT", value=Decimal("15"))
        percent.categories.add(shop.canola_cat)
        assert compute_bill(lines, D09, coupon=percent).coupon_discount == Decimal("11.85")

    @pytest.mark.parametrize(
        "name",
        [
            "CART_READY",
            "CART_COUPON_KEEPS_FREE_DELIVERY",
            "CART_SMALL",
            "CART_BELOW_MINIMUM",
            "CART_STOCK_ISSUES",
            "CART_COUPON_NOT_APPLICABLE",
        ],
    )
    def test_reproduces_every_published_example(self, name):
        cart = ex.ALL_CARTS[name]
        lines = [
            BillLine(
                variant_id=item["variant"]["id"],
                category_id=OILS,
                mrp=Decimal(item["variant"]["mrp"]),
                selling_price=Decimal(item["variant"]["selling_price"]),
                quantity=item["quantity"],
            )
            for item in cart["items"]
        ]
        applied = cart["coupon"] and cart["coupon"]["is_applicable"]
        jivo50 = coupon("JIVO50", min_order_value=Decimal("299.00")) if applied else None
        bill = compute_bill(lines, D09, coupon=jivo50, tip=Decimal(cart["tip"]))
        assert as_strings(bill) == cart["bill"]


class TestPriceChanged:
    def test_matching_total_passes(self):
        ensure_expected_total(compute_bill([line("300.00")], D09), Decimal("300"))

    def test_mismatch_is_409_price_changed(self):
        bill = compute_bill([line("300.00")], D09)
        with pytest.raises(ApiError) as caught:
            ensure_expected_total(bill, Decimal("299.99"))
        assert caught.value.status_code == 409
        assert caught.value.error_code == "PRICE_CHANGED"
        assert caught.value.details == {
            "expected_grand_total": "299.99",
            "grand_total": "300.00",
        }
