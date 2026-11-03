"""Coupon rules, the coupon sheet and coupon use by orders (07 §2.5, 08 T1-T5)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.db import IntegrityError
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.cart.services import BillLine
from apps.catalog.tests.factories import CategoryFactory
from apps.core.exceptions import ApiError
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.promotions import services
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

NOW = timezone.now()


def make(code="JIVO50", **kwargs) -> Coupon:
    defaults = {
        "title": "Flat ₹50 off",
        "discount_type": "FLAT",
        "value": Decimal("50.00"),
        "min_order_value": Decimal("299.00"),
        "usage_limit_per_user": 1,
    }
    return Coupon.objects.create(code=code, **{**defaults, **kwargs})


def lines(*totals, category=1):
    return [
        BillLine(
            variant_id=index,
            category_id=category,
            mrp=Decimal(total),
            selling_price=Decimal(total),
            quantity=1,
        )
        for index, total in enumerate(totals)
    ]


@pytest.fixture
def store():
    return DarkStoreFactory()


def check(coupon, user, store, *totals, category=1, now=NOW):
    cart_lines = lines(*totals, category=category)
    return services.check_coupon(
        coupon,
        user=user,
        store_id=store.pk,
        lines=cart_lines,
        item_total=sum((line.line_total for line in cart_lines), Decimal(0)),
        now=now,
    )


def redeem(coupon, user, as_status=RedemptionStatus.APPLIED, **order):
    return CouponRedemption.objects.create(
        coupon=coupon,
        user=user,
        order=OrderFactory(user=user, **order),
        discount_amount=Decimal("50.00"),
        status=as_status,
    )


class TestCodes:
    def test_codes_are_stored_in_capitals_and_unique_ignoring_case(self):
        assert make("  jivo50 ").code == "JIVO50"
        with pytest.raises(IntegrityError):
            make("Jivo50")

    @pytest.mark.parametrize("typed", ["jivo50", " JIVO50 ", "Jivo50"])
    def test_find_is_case_insensitive(self, typed):
        coupon = make()
        assert services.find_coupon(typed) == coupon

    @pytest.mark.parametrize("typed", ["", "   ", "NOPE"])
    def test_find_nothing(self, typed):
        make()
        assert services.find_coupon(typed) is None


class TestChecks:
    """In order: INVALID, EXPIRED, STORE, USAGE, FIRST_ORDER, MIN_ORDER, NO_ITEMS (module doc)."""

    def test_applicable(self, user, store):
        result = check(make(), user, store, "300.00")
        assert result.ok
        assert result.discount == Decimal("50.00")
        assert result.details() == {"code": "JIVO50"}

    def test_inactive_or_not_started_is_invalid(self, user, store):
        assert check(make(is_active=False), user, store, "300").error == "COUPON_INVALID"
        later = make("LATER", starts_at=NOW + timedelta(hours=1))
        assert check(later, user, store, "300").error == "COUPON_INVALID"
        assert check(later, user, store, "300", now=NOW + timedelta(hours=2)).ok

    def test_expired(self, user, store):
        result = check(make(ends_at=NOW - timedelta(seconds=1)), user, store, "300")
        assert (result.error, result.message) == ("COUPON_EXPIRED", "This coupon has expired.")

    def test_other_store(self, user, store):
        coupon = make()
        coupon.stores.add(DarkStoreFactory())
        result = check(coupon, user, store, "300")
        assert (result.error, result.reason) == ("COUPON_NOT_ELIGIBLE", "STORE")
        coupon.stores.add(store)
        assert check(coupon, user, store, "300").ok

    def test_per_user_limit_counts_held_and_applied(self, user, store):
        coupon = make(usage_limit_per_user=2)
        redeem(coupon, user, RedemptionStatus.APPLIED)
        assert check(coupon, user, store, "300").ok
        redeem(coupon, user, RedemptionStatus.HELD, status=OrderStatus.PAYMENT_PENDING)
        result = check(coupon, user, store, "300")
        assert (result.error, result.scope) == ("COUPON_USAGE_EXCEEDED", "per_user")
        assert result.details() == {"code": "JIVO50", "scope": "per_user"}

    def test_released_and_reversed_uses_do_not_count(self, user, store):
        coupon = make(usage_limit_per_user=1)
        redeem(coupon, user, RedemptionStatus.RELEASED, placed_at=None)
        redeem(coupon, user, RedemptionStatus.REVERSED)
        assert check(coupon, user, store, "300").ok

    def test_total_limit(self, user, store):
        coupon = make(usage_limit_total=1, usage_limit_per_user=None)
        redeem(coupon, UserFactory())
        result = check(coupon, user, store, "300")
        assert (result.error, result.scope, result.message) == (
            "COUPON_USAGE_EXCEEDED",
            "total",
            "This coupon has been fully redeemed.",
        )

    def test_unlimited(self, user, store):
        coupon = make(usage_limit_total=None, usage_limit_per_user=None)
        for _ in range(3):
            redeem(coupon, user)
        assert check(coupon, user, store, "300").ok

    def test_first_order_only(self, user, store):
        """PM decision: only an earlier order that reached PLACED counts."""
        coupon = make("WELCOME100", first_order_only=True, min_order_value=Decimal(0))
        OrderFactory(user=user, status=OrderStatus.PAYMENT_FAILED, placed_at=None)
        OrderFactory(user=user, status=OrderStatus.CANCELLED, placed_at=None)
        assert check(coupon, user, store, "300").ok
        OrderFactory(user=user, status=OrderStatus.CANCELLED)  # placed, then cancelled
        result = check(coupon, user, store, "300")
        assert (result.error, result.reason) == ("COUPON_NOT_ELIGIBLE", "FIRST_ORDER_ONLY")

    def test_min_order_compares_the_item_total_before_the_coupon(self, user, store):
        coupon = make()
        result = check(coupon, user, store, "225.00")
        assert (result.error, result.reason, result.amount_to_unlock) == (
            "COUPON_NOT_ELIGIBLE",
            "MIN_ORDER_VALUE",
            Decimal("74.00"),
        )
        assert result.message == "Add items worth ₹74 more to use this coupon."
        assert result.details() == {
            "code": "JIVO50",
            "reason": "MIN_ORDER_VALUE",
            "min_order_value": "299.00",
            "amount_to_unlock": "74.00",
        }
        assert check(coupon, user, store, "299.00").ok

    def test_category_coupon_needs_a_qualifying_item(self, user, store):
        oils = CategoryFactory()
        canola = CategoryFactory(parent=oils)
        coupon = make("OILS15", min_order_value=Decimal(0))
        coupon.categories.add(oils)
        result = check(coupon, user, store, "300", category=CategoryFactory().pk)
        assert (result.error, result.reason) == ("COUPON_NOT_ELIGIBLE", "NO_ELIGIBLE_ITEMS")
        assert check(coupon, user, store, "300", category=canola.pk).ok  # sub-category counts

    def test_empty_cart(self, user, store):
        result = check(make(min_order_value=Decimal(0)), user, store)
        assert result.reason == "NO_ELIGIBLE_ITEMS"

    def test_as_error(self, user, store):
        error = check(make(), user, store, "100").as_error()
        assert (error.status_code, error.error_code) == (422, "COUPON_NOT_ELIGIBLE")


class TestOffers:
    def offers(self, user, store, *totals, applied=None):
        cart_lines = lines(*totals)
        return services.coupon_offers(
            user=user,
            store_id=store.pk,
            lines=cart_lines,
            item_total=sum((line.line_total for line in cart_lines), Decimal(0)),
            applied=applied,
            now=NOW,
        )

    def test_sheet(self, user, store):
        jivo50 = make()
        make("JIVO10", discount_type="PERCENT", value=Decimal(10), max_discount=Decimal(100),
             min_order_value=Decimal(499))  # fmt: skip
        make("BIGSAVE200", value=Decimal(200), min_order_value=Decimal(1499))
        make("WELCOME100", value=Decimal(100), first_order_only=True, min_order_value=Decimal(0))
        make("HIDDEN", is_visible=False)
        make("OLD", ends_at=NOW - timedelta(days=1))
        make("SOON", starts_at=NOW + timedelta(days=1))
        elsewhere = make("ELSEWHERE")
        elsewhere.stores.add(DarkStoreFactory())
        used = make("USED")
        redeem(used, user)
        OrderFactory(user=user)  # an earlier placed order: WELCOME100 not eligible

        offers = self.offers(user, store, "783.00", applied=jivo50)
        assert [offer["code"] for offer in offers] == [
            "JIVO10",
            "JIVO50",
            "BIGSAVE200",
            "WELCOME100",
        ]
        by_code = {offer["code"]: offer for offer in offers}
        assert by_code["JIVO10"]["savings"] == "78.30"
        assert by_code["JIVO50"]["is_applied"] is True
        assert by_code["BIGSAVE200"] | {} == by_code["BIGSAVE200"]
        assert (
            by_code["BIGSAVE200"]["ineligible_reason"],
            by_code["BIGSAVE200"]["amount_to_unlock"],
            by_code["BIGSAVE200"]["message"],
        ) == ("MIN_ORDER_VALUE", "716.00", "Add items worth ₹716 more to unlock.")
        assert by_code["WELCOME100"]["ineligible_reason"] == "FIRST_ORDER_ONLY"
        assert by_code["WELCOME100"]["savings"] is None
        assert by_code["JIVO10"]["max_discount"] == "100.00"
        assert by_code["JIVO50"]["max_discount"] is None

    def test_store_specific_coupon_is_listed_at_its_store(self, user, store):
        coupon = make("HERE")
        coupon.stores.add(store, DarkStoreFactory())
        assert [offer["code"] for offer in self.offers(user, store, "300")] == ["HERE"]


class TestUseByOrders:
    @pytest.fixture
    def order(self, user):
        return OrderFactory(user=user, status=OrderStatus.PAYMENT_PENDING, placed_at=None)

    def statuses(self, order):
        return CouponRedemption.objects.get(order=order).status

    def test_hold_then_confirm(self, order):
        coupon = make()
        services.hold_coupon(order, coupon, Decimal("50.00"))
        assert self.statuses(order) == RedemptionStatus.HELD
        assert services.confirm_coupon(order) is True
        assert self.statuses(order) == RedemptionStatus.APPLIED
        assert services.confirm_coupon(order) is False  # idempotent
        assert services.reverse_coupon(order) is True
        assert self.statuses(order) == RedemptionStatus.REVERSED

    def test_hold_then_release(self, order):
        coupon = make()
        services.hold_coupon(order, coupon, Decimal("50.00"))
        assert services.release_coupon(order) is True
        assert services.release_coupon(order) is False
        assert self.statuses(order) == RedemptionStatus.RELEASED
        usage = services.usage_for([coupon], order.user).get(coupon.pk, services.Usage())
        assert usage.by_user == 0

    def test_cod_applies_at_once(self, user):
        coupon = make()
        order = OrderFactory(user=user)
        services.apply_coupon_now(order, coupon, Decimal("50.00"))
        assert self.statuses(order) == RedemptionStatus.APPLIED

    def test_limits_are_rechecked_when_used(self, user, order):
        """Two orders racing for the last use: the second is refused (coupon row locked)."""
        coupon = make(usage_limit_per_user=1)
        services.hold_coupon(order, coupon, Decimal("50.00"))
        other = OrderFactory(user=user, status=OrderStatus.PAYMENT_PENDING, placed_at=None)
        with pytest.raises(ApiError) as caught:
            services.hold_coupon(other, coupon, Decimal("50.00"))
        assert caught.value.error_code == "COUPON_USAGE_EXCEEDED"
        assert caught.value.details["scope"] == "per_user"

    def test_total_limit_is_rechecked_when_used(self, order):
        coupon = make(usage_limit_total=1, usage_limit_per_user=None)
        redeem(coupon, UserFactory())
        with pytest.raises(ApiError) as caught:
            services.apply_coupon_now(order, coupon, Decimal("50.00"))
        assert caught.value.details["scope"] == "total"
