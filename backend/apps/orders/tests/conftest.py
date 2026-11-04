"""Order tests drive the real API from a filled cart (the cart tests' shop and address)."""

import uuid
from decimal import Decimal

import pytest

from apps.cart.tests.conftest import address, shop  # noqa: F401 - shared fixtures
from apps.payments.gateways import FAKE_KEY_SECRET, razorpay_payment_signature
from apps.payments.models import Payment

CART = "/api/v1/cart/"
ORDERS = "/api/v1/orders/"
VERIFY = "/api/v1/payments/razorpay/verify/"


def new_key() -> str:
    return str(uuid.uuid4())


def sign(gateway_order_id: str, payment_id: str) -> str:
    """The dev-only fake gateway scheme (06 §2.6)."""
    return razorpay_payment_signature(FAKE_KEY_SECRET, gateway_order_id, payment_id)


class Checkout:
    """The customer's side: fill the cart, read the bill, place, verify."""

    def __init__(self, client, the_shop, the_address):
        self.client, self.shop, self.address = client, the_shop, the_address
        self.headers = the_shop.headers()

    def fill(self, *lines, with_address=True):
        for variant, quantity in lines:
            response = self.client.post(
                f"{CART}items/",
                {"variant_id": variant.pk, "quantity": quantity},
                headers=self.headers,
            )
            assert response.status_code == 200, response.content
        if with_address:
            self.client.patch(CART, {"address_id": self.address.pk}, headers=self.headers)
        return self.cart()

    def cart(self) -> dict:
        return self.client.get(CART, headers=self.headers).json()

    def place(self, method="COD", *, key=None, expected=None, address_id=None, status=201):
        expected = expected if expected is not None else self.cart()["bill"]["grand_total"]
        response = self.client.post(
            ORDERS,
            {
                "address_id": address_id or self.address.pk,
                "payment_method": method,
                "expected_grand_total": expected,
            },
            headers={**self.headers, "Idempotency-Key": key or new_key()},
        )
        assert response.status_code == status, response.content
        return response.json()

    def verify(self, placement: dict, payment_id="pay_TestPayment0001", *, status=200, sig=None):
        order_id = placement["razorpay"]["order_id"]
        response = self.client.post(
            VERIFY,
            {
                "order_id": placement["order"]["id"],
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": sig or sign(order_id, payment_id),
            },
        )
        assert response.status_code == status, response.content
        return response.json()


@pytest.fixture
def checkout(auth_client, shop, address):  # noqa: F811 - fixtures imported above
    return Checkout(auth_client, shop, address)


def open_payment(order_id: int) -> Payment:
    return Payment.objects.filter(order_id=order_id, status="CREATED").latest("created_at")


ZERO = Decimal("0.00")
