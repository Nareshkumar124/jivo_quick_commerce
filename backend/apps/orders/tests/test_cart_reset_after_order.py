"""After an order is placed, the cart's tip and delivery instructions/note reset (user, 2026-11-14),
so the next order doesn't silently reuse them."""

import pytest

from apps.orders.tests.conftest import CART

pytestmark = pytest.mark.django_db


def test_tip_and_instructions_reset_after_an_order(checkout, shop):
    checkout.fill((shop.canola_1l, 2))
    response = checkout.client.patch(
        CART,
        {"tip": "20.00", "instructions": {"chips": ["LEAVE_AT_DOOR"], "note": "Gate 2"}},
        headers=checkout.headers,
        format="json",
    )
    assert response.status_code == 200, response.content
    assert checkout.cart()["tip"] == "20.00"

    checkout.place()

    cart = checkout.cart()
    assert cart["tip"] == "0.00"
    assert cart["instructions"] == {"chips": [], "note": ""}
    assert cart["coupon"] is None
