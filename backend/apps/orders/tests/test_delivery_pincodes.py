"""ADR 0004 §1, the address check end to end: `cart.services.serves()` is the single gate of the
cart blocker, the cart address (422) and placement (422). A store with delivery pincodes serves
an address only when its pincode is an active pincode of the store; a store without any keeps
the service-area rule."""

import pytest

from apps.cart import services as cart_services
from apps.cart.models import Cart
from apps.cart.tests.conftest import OUTSIDE, make_address
from apps.orders.models import Order
from apps.orders.tests.conftest import CART
from apps.stores.models import DeliveryPincode

pytestmark = pytest.mark.django_db

ONLY_110027 = (
    "We don't deliver here yet. We deliver in Rajouri Garden (110027). "
    "We'll come to your area soon."
)


def deliver_to(shop, pincode="110027", **kwargs) -> DeliveryPincode:
    return DeliveryPincode.objects.create(
        store=shop.store_model, pincode=pincode, area_name="Rajouri Garden", **kwargs
    )


def blockers(body) -> dict:
    return {b["code"]: b["message"] for b in body["checkout"]["blockers"]}


class TestServes:
    def test_active_pincode_is_served(self, shop, user):
        deliver_to(shop)
        assert cart_services.serves(shop.store, make_address(user, pincode="110027"))
        # the exact rule is the pincode: the pin's position does not matter in pincode mode
        assert cart_services.serves(shop.store, make_address(user, OUTSIDE, pincode="110027"))

    def test_inactive_pincode_is_not_served(self, shop, user):
        deliver_to(shop, is_active=False)
        address = make_address(user, pincode="110027")
        assert not cart_services.serves(shop.store, address)
        assert cart_services.not_served_message(shop.store, address, "default") == (
            "We don't deliver here yet. We'll come to your area soon."
        )

    def test_unknown_pincode_is_not_served(self, shop, user):
        deliver_to(shop)
        address = make_address(user, pincode="110064")  # inside the service area
        assert not cart_services.serves(shop.store, address)
        assert cart_services.not_served_message(shop.store, address, "default") == ONLY_110027

    def test_pincode_whitespace_is_ignored(self, shop, user):
        """The column holds 6 characters, so padding can only come from an unsaved address."""
        deliver_to(shop)
        address = make_address(user, pincode="110027")
        address.pincode = " 110027 "
        assert cart_services.serves(shop.store, address)
        address.pincode = None
        assert not cart_services.serves(shop.store, address)

    def test_no_pincodes_keeps_the_service_area(self, shop, user):
        assert shop.store.pincode_mode is False
        address = make_address(user, pincode="110064")
        assert cart_services.serves(shop.store, address)
        far = make_address(user, OUTSIDE)
        assert not cart_services.serves(shop.store, far)
        assert cart_services.not_served_message(shop.store, far, "default") == "default"


class TestCartAndPlacement:
    def test_active_pincode_end_to_end(self, checkout, shop, user):
        deliver_to(shop)
        ok = make_address(user, pincode="110027")
        checkout.fill((shop.canola_1l, 2), (shop.chia, 1), with_address=False)
        response = checkout.client.patch(CART, {"address_id": ok.pk}, headers=checkout.headers)
        assert response.status_code == 200, response.content
        assert "NOT_SERVICEABLE" not in blockers(response.json())
        body = checkout.place("COD", address_id=ok.pk)
        assert body["order"]["status"] == "PLACED"

    @pytest.mark.parametrize("active", [True, False])
    def test_other_or_inactive_pincode_cannot_be_set(self, checkout, shop, user, active):
        deliver_to(shop, is_active=active)
        pincode = "110064" if active else "110027"
        far = make_address(user, pincode=pincode)  # inside the service area
        response = checkout.client.patch(CART, {"address_id": far.pk}, headers=checkout.headers)
        assert response.status_code == 422, response.content
        error = response.json()["error"]
        assert (error["code"], error["details"]) == ("NOT_SERVICEABLE", {"address_id": far.pk})
        assert error["message"].startswith("We don't deliver here yet.")
        assert Cart.objects.get(user=user).address_id is None

    def test_saved_address_blocks_checkout_and_placement(self, checkout, shop, user):
        """The cart address was set before the store switched to pincode mode."""
        far = make_address(user, pincode="110064")
        checkout.address = far
        cart = checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        assert cart["checkout"]["can_place_order"] is True
        deliver_to(shop)
        cart = checkout.cart()
        assert cart["checkout"]["can_place_order"] is False
        assert blockers(cart)["NOT_SERVICEABLE"] == ONLY_110027
        body = checkout.place("COD", expected=cart["bill"]["grand_total"], status=422)
        assert body["error"] == {
            "code": "NOT_SERVICEABLE",
            "message": ONLY_110027,
            "details": {"address_id": far.pk},
        }
        assert not Order.objects.filter(user=user).exists()

    def test_newly_activated_pincode_is_served_at_once(self, checkout, shop, user):
        row = deliver_to(shop, is_active=False)
        address = make_address(user, pincode="110027")
        checkout.address = address
        cart = checkout.fill((shop.canola_1l, 2), (shop.chia, 1))  # its address PATCH is 422
        assert "ADDRESS_REQUIRED" in blockers(cart)
        row.is_active = True
        row.save()
        response = checkout.client.patch(CART, {"address_id": address.pk}, headers=checkout.headers)
        assert response.status_code == 200, response.content
        assert checkout.place("COD")["order"]["status"] == "PLACED"

    def test_no_pincodes_places_as_before(self, checkout, shop, user):
        checkout.address = make_address(user, pincode="110064")
        checkout.fill((shop.canola_1l, 2), (shop.chia, 1))
        assert checkout.place("COD")["order"]["status"] == "PLACED"
