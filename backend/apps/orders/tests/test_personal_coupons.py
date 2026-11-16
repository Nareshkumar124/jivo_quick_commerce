"""Personal coupons (referral rewards, added 2026-11-13) through the real cart and order API:
the owner sees, applies and orders with one; another customer can neither see nor use it (IDOR)."""

from decimal import Decimal

import pytest

from apps.accounts.tests.factories import UserFactory
from apps.cart.models import Cart
from apps.promotions import services as promotions
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus

pytestmark = pytest.mark.django_db

COUPONS = "/api/v1/cart/coupons/"
COUPON = "/api/v1/cart/coupon/"


def reward(owner) -> Coupon:
    return promotions.create_personal_coupon(
        owner,
        amount=Decimal("90.00"),
        valid_days=30,
        min_order_value=Decimal("0.00"),
        title="₹90 off: referral reward",
    )


def sheet(checkout) -> dict:
    response = checkout.client.get(COUPONS, headers=checkout.headers)
    assert response.status_code == 200
    return {offer["code"]: offer for offer in response.json()["results"]}


def apply(checkout, code):
    return checkout.client.post(COUPON, {"code": code}, headers=checkout.headers)


def test_owner_sees_applies_and_orders_with_it(checkout, shop, user):
    """Listed for its owner with `is_personal`, applied like any code, used once by the order."""
    coupon = reward(user)
    checkout.fill((shop.canola_1l, 2))
    offer = sheet(checkout)[coupon.code]
    assert (offer["is_personal"], offer["is_eligible"], offer["savings"]) == (True, True, "90.00")
    assert offer["ends_at"] is not None
    response = apply(checkout, coupon.code.lower())
    assert response.status_code == 200, response.content
    assert response.json()["bill"]["coupon_discount"] == "90.00"
    body = checkout.place("COD")
    assert body["order"]["bill"]["coupon_discount"] == "90.00"
    redemption = CouponRedemption.objects.get(coupon=coupon)
    assert (redemption.user, redemption.status) == (user, RedemptionStatus.APPLIED)
    # One use: gone from the sheet, refused if typed again.
    checkout.fill((shop.chia, 1))
    assert coupon.code not in sheet(checkout)
    again = apply(checkout, coupon.code)
    assert again.status_code == 422
    assert again.json()["error"]["code"] == "COUPON_USAGE_EXCEEDED"


def test_another_customer_can_neither_see_nor_apply_it(checkout, shop):
    """IDOR: someone else's personal coupon answers exactly like an unknown code."""
    theirs = reward(UserFactory())
    checkout.fill((shop.canola_1l, 2))
    assert theirs.code not in sheet(checkout)
    response = apply(checkout, theirs.code)
    unknown = apply(checkout, "REFNOSUCH99")
    assert response.status_code == unknown.status_code == 422
    assert response.json()["error"]["code"] == unknown.json()["error"]["code"] == "COUPON_INVALID"
    assert response.json()["error"]["message"] == unknown.json()["error"]["message"]
    assert checkout.cart()["coupon"] is None


def test_placement_refuses_another_customers_coupon(checkout, shop, user):
    """Even if one got onto the cart, the order is refused and nothing is used or reserved."""
    theirs = reward(UserFactory())
    checkout.fill((shop.canola_1l, 2))
    expected = checkout.cart()["bill"]["grand_total"]
    Cart.objects.filter(user=user).update(coupon=theirs)
    body = checkout.place("COD", expected=expected, status=422)
    assert body["error"]["code"] == "COUPON_INVALID"
    assert not CouponRedemption.objects.filter(coupon=theirs).exists()
