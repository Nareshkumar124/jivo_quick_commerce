"""Database constraints keep every order's bill consistent (08 §6.2, code review of R2a)."""

from decimal import Decimal

import pytest
from django.db import IntegrityError, transaction

from apps.orders.tests.factories import OrderFactory

pytestmark = pytest.mark.django_db


def test_a_valid_bill_saves():
    order = OrderFactory(
        mrp_total=Decimal("350.00"),
        item_total=Decimal("300.00"),
        product_discount=Decimal("50.00"),
        coupon_discount=Decimal("30.00"),
        delivery_fee=Decimal("25.00"),
        small_cart_fee=Decimal("0.00"),
        handling_fee=Decimal("2.00"),
        tip=Decimal("10.00"),
        grand_total=Decimal("307.00"),
    )
    assert order.pk


@pytest.mark.parametrize(
    ("changes", "constraint"),
    [
        ({"grand_total": Decimal("299.99")}, "order_grand_total_formula"),
        ({"product_discount": Decimal("40.00")}, "order_product_discount_formula"),
        ({"tip": Decimal("-1.00"), "grand_total": Decimal("299.00")}, "order_money_not_negative"),
        ({"amount_refunded": Decimal("300.01")}, "order_refund_within_paid"),
    ],
)
def test_an_inconsistent_bill_is_refused(changes, constraint):
    with transaction.atomic(), pytest.raises(IntegrityError, match=constraint):
        OrderFactory(**changes)


def test_coupon_never_exceeds_the_item_total():
    with (
        transaction.atomic(),
        pytest.raises(IntegrityError, match="order_coupon_within_item_total"),
    ):
        OrderFactory(
            item_total=Decimal("300.00"),
            mrp_total=Decimal("300.00"),
            product_discount=Decimal("0.00"),
            coupon_discount=Decimal("300.01"),
            delivery_fee=Decimal("0.01"),
            grand_total=Decimal("0.00"),
        )
