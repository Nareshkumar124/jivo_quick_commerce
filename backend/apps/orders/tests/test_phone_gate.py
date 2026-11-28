"""`POST /orders/` delivery-contact gate (2026-11-28, email OTP review): an order needs a number
the rider and the store can call. The account's login phone or the address's `receiver_phone`
is enough; only with neither is the answer 422 `PHONE_REQUIRED`. Test ids P8-EOTP-nn are listed
in docs/plan/phase-8-hardening-and-launch.md §3."""

import pytest
from django.utils import timezone

from apps.accounts.models import Address
from apps.accounts.services import contact
from apps.accounts.tests.factories import UserFactory
from apps.cart.tests.conftest import make_address
from apps.inventory.models import StockReservation
from apps.orders.models import Order
from apps.orders.tests.conftest import Checkout, new_key

pytestmark = pytest.mark.django_db

RECEIVER = "+919812345678"
ADDRESSES = "/api/v1/addresses/"


@pytest.fixture
def email_user(db):
    """A customer who signed up with email: verified email, no login phone."""
    return UserFactory(phone=None, email="asha.verma@example.com", email_verified_at=timezone.now())


@pytest.fixture
def email_checkout(email_user, make_auth_client, shop):
    """Checkout for the email customer, delivering to an address without a receiver phone."""
    address = make_address(email_user, receiver_phone="")
    return Checkout(make_auth_client(email_user), shop, address)


def blocker_codes(cart: dict) -> list[str]:
    return [blocker["code"] for blocker in cart["checkout"]["blockers"]]


class TestHasDeliveryContact:
    @pytest.mark.parametrize(
        ("receiver", "expected"),
        [
            (RECEIVER, True),
            ("", False),
            ("9812345678", False),  # not E.164
            ("+915812345678", False),  # not a mobile series
            ("+91981234567\n", False),
        ],
    )
    def test_receiver_phone_without_a_login_phone(self, email_user, receiver, expected):
        address = Address(user=email_user, receiver_phone=receiver)
        assert contact.has_delivery_contact(email_user, address) is expected

    def test_login_phone_is_enough(self, user):
        assert contact.has_delivery_contact(user, Address(user=user, receiver_phone="")) is True
        assert contact.has_delivery_contact(user, None) is True

    def test_no_address_no_phone(self, email_user):
        assert contact.has_delivery_contact(email_user, None) is False


class TestEmailOnlyCustomer:
    def test_no_phone_anywhere_is_phone_required(self, email_checkout, shop):
        """P8-EOTP-22: no login phone and no receiver phone: 422 PHONE_REQUIRED naming the
        address; nothing is created or reserved, and the cart shows the blocker first."""
        cart = email_checkout.fill((shop.canola_1l, 2))
        assert "PHONE_REQUIRED" in blocker_codes(cart)
        assert cart["checkout"]["can_place_order"] is False
        body = email_checkout.place("COD", status=422)
        assert body["error"]["code"] == "PHONE_REQUIRED"
        assert body["error"]["details"] == {"address_id": email_checkout.address.pk}
        assert not Order.objects.exists()
        assert not StockReservation.objects.exists()

    def test_receiver_phone_on_the_address_is_enough(self, email_checkout, shop):
        """P8-EOTP-26: the fix without SMS: save a receiver phone on the address (no OTP), then
        the same cart is orderable and the order carries that number for the rider."""
        email_checkout.fill((shop.canola_1l, 2))
        response = email_checkout.client.patch(
            f"{ADDRESSES}{email_checkout.address.pk}/", {"receiver_phone": RECEIVER}
        )
        assert response.status_code == 200, response.content
        cart = email_checkout.cart()
        assert "PHONE_REQUIRED" not in blocker_codes(cart)
        assert cart["checkout"]["can_place_order"] is True
        placement = email_checkout.place("COD")
        order = Order.objects.get(pk=placement["order"]["id"])
        assert order.address_snapshot["receiver_phone"] == RECEIVER
        assert order.user.phone is None  # the login phone is untouched

    def test_online_checkout_prefills_the_receiver_phone(self, email_checkout, shop):
        Address.objects.filter(pk=email_checkout.address.pk).update(receiver_phone=RECEIVER)
        email_checkout.fill((shop.canola_1l, 2))
        placement = email_checkout.place("ONLINE")
        assert placement["razorpay"]["prefill"]["contact"] == RECEIVER

    def test_replay_after_the_receiver_phone_was_removed(self, email_checkout, shop):
        """A replay returns the order already placed, whatever the address says now."""
        Address.objects.filter(pk=email_checkout.address.pk).update(receiver_phone=RECEIVER)
        email_checkout.fill((shop.canola_1l, 2))
        key = new_key()
        expected = email_checkout.cart()["bill"]["grand_total"]
        first = email_checkout.place("COD", key=key, expected=expected)
        Address.objects.filter(pk=email_checkout.address.pk).update(receiver_phone="")
        again = email_checkout.place("COD", key=key, expected=expected, status=200)
        assert again["order"]["id"] == first["order"]["id"]


class TestPhoneCustomer:
    def test_login_phone_without_a_receiver_phone(self, checkout, shop):
        """The login phone alone still satisfies the gate (semantics unchanged)."""
        Address.objects.filter(pk=checkout.address.pk).update(receiver_phone="")
        cart = checkout.fill((shop.canola_1l, 2))
        assert "PHONE_REQUIRED" not in blocker_codes(cart)
        assert checkout.place("COD")["order"]["status"] == "PLACED"

    def test_idempotent_replay_still_returns_200(self, checkout, shop):
        """P8-EOTP-27: an existing phone customer's replay of `POST /orders/` with the same
        Idempotency-Key returns the first order (200) after the PHONE_REQUIRED gate was added."""
        checkout.fill((shop.canola_1l, 2))
        key = new_key()
        expected = checkout.cart()["bill"]["grand_total"]
        first = checkout.place("COD", key=key, expected=expected)
        again = checkout.place("COD", key=key, expected=expected, status=200)
        assert again["order"]["id"] == first["order"]["id"]
        assert Order.objects.count() == 1
