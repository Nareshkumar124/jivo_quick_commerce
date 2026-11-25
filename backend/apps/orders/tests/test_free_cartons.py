"""ADR-0002 on orders: free cartons become ₹0 order lines (`is_free`, `free_source`), are
reserved with the paid units in the placement transaction and committed at pickup with a
`StockMovement`; after ordering they are fixed (08 §6.3 / ADR-0002 §6); invoices show them at
₹0. Free-carton rewards: CLAIMED by the order, back to AVAILABLE on cancel or payment failure,
USED on delivery, never used twice."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.db import transaction
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.cart.models import Cart, CartItem
from apps.inventory import services as inventory
from apps.inventory.models import (
    MovementType,
    ReservationStatus,
    StockMovement,
    StockReservation,
    StoreInventory,
)
from apps.orders import invoices, services, store_ops
from apps.orders.choices import ActorType, OrderStatus
from apps.orders.models import Order
from apps.payments.models import Refund
from apps.promotions import rewards
from apps.promotions.choices import CouponSource, RewardStatus
from apps.promotions.models import CouponRedemption, RedemptionStatus
from apps.stores.services import grant_store_access

pytestmark = pytest.mark.django_db

COUPON = "/api/v1/cart/coupon/"
REWARDS = "/api/v1/account/rewards/"


@pytest.fixture
def staff(shop):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=roles.STORE_MANAGER))
    grant_store_access(user, shop.store_model)
    return user


@pytest.fixture
def welcome(user):
    return rewards.create_reward(user, source=CouponSource.WELCOME)


def apply_reward(checkout, code, variant):
    response = checkout.client.post(
        COUPON, {"code": code, "free_variant_id": variant.pk}, headers=checkout.headers
    )
    assert response.status_code == 200, response.content
    return response.json()


def place(checkout, *lines, method="COD", reward=None, verify=True):
    checkout.fill(*lines)
    if reward is not None:
        apply_reward(checkout, *reward)
    placement = checkout.place(method)
    if method == "ONLINE" and verify:
        checkout.verify(placement)
    return Order.objects.get(pk=placement["order"]["id"]), placement


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


def lines_of(order) -> list[tuple]:
    return [
        (item.variant_id, item.quantity, item.selling_price, item.is_free, item.free_source)
        for item in order.items.order_by("id")
    ]


def advance(order, *statuses):
    """Move an order through the state machine (08 §2) with `transition()`."""
    for status in statuses:
        with transaction.atomic():
            locked = Order.objects.select_for_update().get(pk=order.pk)
            services.transition(locked, status, actor_type=ActorType.SYSTEM)
    order.refresh_from_db()
    return order


def state(coupon):
    coupon = rewards.rewards_of(coupon.owner).get(pk=coupon.pk)
    return rewards.reward_state(coupon).status


class TestPlacement:
    def test_free_lines_are_stored_and_reserved_with_the_paid_units(
        self, checkout, shop, water, welcome, user
    ):
        """ADR-0002 §5: 1 L x12 paid + 1 free 1 L (volume) + 1 free 500 ml (reward): one
        reservation per variant for paid + free, in the placement transaction."""
        order, placement = place(checkout, (water.one_litre, 12), reward=(welcome.code, water.half))
        assert lines_of(order) == [
            (water.one_litre.pk, 12, Decimal("110.00"), False, ""),
            (water.one_litre.pk, 1, Decimal("0.00"), True, "VOLUME_OFFER"),
            (water.half.pk, 1, Decimal("0.00"), True, "REWARD"),
        ]
        assert (order.item_total, order.coupon_discount, order.grand_total) == (
            Decimal("1320.00"),
            Decimal("0.00"),
            Decimal("1320.00"),
        )
        assert order.coupon == welcome
        assert {
            (r.variant_id, r.quantity, r.status)
            for r in StockReservation.objects.filter(order=order)
        } == {
            (water.one_litre.pk, 13, ReservationStatus.ACTIVE),
            (water.half.pk, 1, ReservationStatus.ACTIVE),
        }
        assert (reserved(shop, water.one_litre), reserved(shop, water.half)) == (13, 1)
        body = placement["order"]
        assert body["bill"]["free_items_value"] == "250.00"
        assert body["bill"]["total_savings"] == "250.00"
        assert body["item_count"] == 12  # paid units only, like the cart (free not counted)
        free = [line for line in body["items"] if line["is_free"]]
        assert [(f["variant_id"], f["free_source"], f["line_total"]) for f in free] == [
            (water.one_litre.pk, "VOLUME_OFFER", "0.00"),
            (water.half.pk, "REWARD", "0.00"),
        ]
        paid = [line for line in body["items"] if not line["is_free"]]
        assert paid[0]["free_source"] is None
        # The cart keeps nothing of the order: lines, reward and its size are gone.
        cart = Cart.objects.get(user=user)
        assert (cart.coupon_id, cart.free_variant_id) == (None, None)
        assert not CartItem.objects.filter(cart=cart).exists()

    def test_reward_is_claimed_by_the_order(self, checkout, auth_client, water, welcome):
        order, _ = place(checkout, (water.one_litre, 5), reward=(welcome.code, water.half))
        assert state(welcome) == RewardStatus.CLAIMED
        body = auth_client.get(REWARDS).json()
        assert body["available"] == [
            {
                "code": welcome.code,
                "title": "1 free carton: welcome reward",
                "source": "WELCOME",
                "status": "CLAIMED",
                "expires_at": body["available"][0]["expires_at"],
                "order_number": order.order_number,
            }
        ]
        assert [entry["kind"] for entry in body["history"]] == ["CLAIMED", "EARNED"]

    def test_online_order_holds_the_reward_until_paid(self, checkout, water, welcome):
        order, _ = place(
            checkout,
            (water.one_litre, 5),
            method="ONLINE",
            reward=(welcome.code, water.half),
            verify=False,
        )
        redemption = CouponRedemption.objects.get(order=order)
        assert (redemption.status, redemption.discount_amount) == (
            RedemptionStatus.HELD,
            Decimal("0.00"),
        )
        assert state(welcome) == RewardStatus.CLAIMED

    def test_no_free_line_when_the_stock_cannot_supply_it(self, checkout, shop, water):
        from apps.cart.tests.test_api import set_stock

        set_stock(shop.store_model, water.one_litre, 10)
        order, _ = place(checkout, (water.one_litre, 10))
        assert lines_of(order) == [(water.one_litre.pk, 10, Decimal("110.00"), False, "")]
        assert reserved(shop, water.one_litre) == 10

    def test_the_reward_cannot_be_used_twice(self, checkout, water, welcome):
        """ADR-0002 §13: usage limit 1; a claimed reward cannot go on another cart."""
        place(checkout, (water.one_litre, 5), reward=(welcome.code, water.half))
        checkout.fill((water.one_litre, 5))
        response = checkout.client.post(
            COUPON,
            {"code": welcome.code, "free_variant_id": water.half.pk},
            headers=checkout.headers,
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "COUPON_USAGE_EXCEEDED"

    def test_placement_refuses_a_reward_used_meanwhile(self, checkout, water, welcome, user):
        """The reward was used by another order after it went on the cart: the placement's
        locked re-check refuses it and nothing is created."""
        from apps.orders.tests.factories import OrderFactory
        from apps.promotions import services as promotions

        checkout.fill((water.one_litre, 5))
        apply_reward(checkout, welcome.code, water.half)
        with transaction.atomic():
            promotions.apply_coupon_now(OrderFactory(user=user), welcome, Decimal("0.00"))
        response = checkout.client.post(
            "/api/v1/orders/",
            {
                "address_id": checkout.address.pk,
                "payment_method": "COD",
                "expected_grand_total": "550.00",
            },
            headers={**checkout.headers, "Idempotency-Key": "reward-used-meanwhile"},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "COUPON_USAGE_EXCEEDED"
        assert not StockReservation.objects.exists()


class TestStock:
    def test_pickup_commits_paid_and_free_units(self, checkout, shop, water, welcome, staff):
        """08 T9 / ADR-0002 §5: on_hand and reserved drop by paid + free, one SALE movement
        per variant."""
        order, _ = place(checkout, (water.one_litre, 10), reward=(welcome.code, water.half))
        store_ops.accept_order(order.pk, by=staff)
        store_ops.start_packing(order.pk, by=staff)
        store_ops.mark_packed(order.pk, by=staff)
        with transaction.atomic():
            assert inventory.commit_reservations(order) == 2
        for variant, units in ((water.one_litre, 11), (water.half, 1)):
            row = StoreInventory.objects.get(store=shop.store_model, variant=variant)
            assert (row.on_hand, row.reserved) == (100 - units, 0)
            movement = StockMovement.objects.get(order=order, variant=variant)
            assert (movement.type, movement.delta) == (MovementType.SALE, -units)

    def test_cancel_releases_free_units_and_returns_the_reward(
        self, checkout, shop, water, welcome
    ):
        """08 T11 + ADR-0002 §10: the reservation (paid + free) is released and the reward is
        AVAILABLE again."""
        order, _ = place(checkout, (water.one_litre, 10), reward=(welcome.code, water.half))
        response = checkout.client.post(
            f"/api/v1/orders/{order.pk}/cancel/", {"reason": "CHANGED_MIND"}
        )
        assert response.status_code == 200, response.content
        assert (reserved(shop, water.one_litre), reserved(shop, water.half)) == (0, 0)
        assert state(welcome) == RewardStatus.AVAILABLE

    def test_payment_failure_returns_the_reward(self, checkout, shop, water, welcome):
        """08 T4: the online payment window ends unpaid; the reward is AVAILABLE again and
        can be applied to the (kept) cart."""
        order, _ = place(
            checkout,
            (water.one_litre, 5),
            method="ONLINE",
            reward=(welcome.code, water.half),
            verify=False,
        )
        later = timezone.now() + timedelta(hours=1)
        assert services.expire_order(order.pk, later) == "failed"
        assert state(welcome) == RewardStatus.AVAILABLE
        assert reserved(shop, water.half) == 0
        apply_reward(checkout, welcome.code, water.half)

    def test_an_expired_reward_does_not_come_back(self, checkout, water, welcome, user):
        order, _ = place(checkout, (water.one_litre, 5), reward=(welcome.code, water.half))
        with freeze_time(welcome.ends_at + timedelta(minutes=1)):
            services.cancel_order(user, order.pk, reason="CHANGED_MIND")
            assert state(welcome) == RewardStatus.EXPIRED

    def test_delivery_marks_the_reward_used(self, checkout, auth_client, water, welcome):
        order, _ = place(checkout, (water.one_litre, 10), reward=(welcome.code, water.half))
        advance(
            order,
            OrderStatus.ACCEPTED,
            OrderStatus.PACKING,
            OrderStatus.PACKED,
            OrderStatus.OUT_FOR_DELIVERY,
            OrderStatus.DELIVERED,
        )
        assert state(welcome) == RewardStatus.USED
        body = auth_client.get(REWARDS).json()
        assert body["available"] == []
        kinds = {
            (entry["kind"], entry["quantity"], entry["order_number"]) for entry in body["history"]
        }
        assert kinds == {
            ("EARNED", 1, None),
            ("CLAIMED", 1, order.order_number),
            ("USED", 1, order.order_number),
            ("VOLUME_FREE", 1, order.order_number),
        }

    def test_failed_delivery_uses_the_reward_up(self, checkout, water, welcome):
        """No return path but cancel and payment failure (ADR-0002 §13)."""
        order, _ = place(checkout, (water.one_litre, 5), reward=(welcome.code, water.half))
        advance(
            order,
            OrderStatus.ACCEPTED,
            OrderStatus.PACKING,
            OrderStatus.PACKED,
            OrderStatus.OUT_FOR_DELIVERY,
            OrderStatus.DELIVERY_FAILED,
        )
        assert state(welcome) == RewardStatus.USED


class TestPartialUnavailability:
    """08 §6.3 / ADR-0002 §6: free cartons are fixed once ordered; a free carton that cannot be
    supplied is dropped; the amount payable never goes up."""

    def to_packing(self, order, staff):
        store_ops.accept_order(order.pk, by=staff)
        store_ops.start_packing(order.pk, by=staff)

    def test_removing_paid_units_keeps_the_free_cartons(self, checkout, shop, water, staff):
        order, _ = place(checkout, (water.one_litre, 20), method="ONLINE")  # 2 free
        self.to_packing(order, staff)
        paid = order.items.get(is_free=False)
        store_ops.mark_item_unavailable(order.pk, paid.pk, unavailable=5, by=staff)
        order.refresh_from_db()
        free = order.items.get(is_free=True)
        assert (free.quantity, free.quantity_unavailable) == (2, 0)
        assert (order.item_total, order.grand_total) == (Decimal("1650.00"), Decimal("1650.00"))
        assert reserved(shop, water.one_litre) == 17  # 15 paid + 2 free
        refund = Refund.objects.get(order=order)  # only the paid units removed: ₹550
        assert refund.amount == Decimal("550.00")

    def test_a_free_carton_the_store_cannot_supply_is_dropped(self, checkout, shop, water, staff):
        order, _ = place(checkout, (water.one_litre, 20), method="ONLINE")
        self.to_packing(order, staff)
        free = order.items.get(is_free=True)
        store_ops.mark_item_unavailable(order.pk, free.pk, unavailable=1, by=staff)
        order.refresh_from_db()
        free.refresh_from_db()
        assert (free.quantity_unavailable, free.line_total) == (1, Decimal("0.00"))
        assert (order.item_total, order.grand_total) == (Decimal("2200.00"), Decimal("2200.00"))
        assert not Refund.objects.filter(order=order).exists()  # ₹0: nothing to refund
        assert reserved(shop, water.one_litre) == 21
        body = checkout.client.get(f"/api/v1/orders/{order.pk}/").json()
        assert body["bill"]["free_items_value"] == "110.00"
        assert order.status == OrderStatus.PACKING

    def test_free_cartons_alone_are_not_an_order(self, checkout, water, staff):
        """All paid units unavailable: the order is cancelled even though free ones remain."""
        order, _ = place(checkout, (water.one_litre, 10))
        self.to_packing(order, staff)
        paid = order.items.get(is_free=False)
        store_ops.mark_item_unavailable(order.pk, paid.pk, unavailable=10, by=staff)
        order.refresh_from_db()
        assert order.status == OrderStatus.CANCELLED


class TestInvoiceAndReorder:
    def test_invoice_shows_free_lines_at_zero(self, checkout, water):
        """The coupon share goes to paid lines only; free lines at ₹0, marked "(free)"."""
        from apps.cart.tests.test_api import coupon

        coupon(min_order_value=Decimal(0))
        checkout.fill((water.one_litre, 10))
        response = checkout.client.post(COUPON, {"code": "JIVO50"}, headers=checkout.headers)
        assert response.status_code == 200
        order = Order.objects.get(pk=checkout.place()["order"]["id"])
        lines = invoices.tax_lines(order)
        assert [(line.quantity, line.gross) for line in lines[:2]] == [
            (10, Decimal("1050.00")),
            (1, Decimal("0.00")),
        ]
        assert lines[1].description.endswith("(free)")
        assert (lines[1].taxable, lines[1].tax) == (Decimal("0.00"), Decimal("0.00"))

    def test_reorder_skips_free_lines(self, checkout, water, welcome, user):
        order, _ = place(checkout, (water.one_litre, 10), reward=(welcome.code, water.half))
        response = checkout.client.post(
            f"/api/v1/orders/{order.pk}/reorder/", headers=checkout.headers
        )
        assert response.status_code == 200, response.content
        cart = Cart.objects.get(user=user)
        assert list(cart.items.values_list("variant_id", "quantity")) == [(water.one_litre.pk, 10)]


class TestPlacementRace:
    """Code review / ADR-0002 §3, §6: a free carton that ran out between the cart read and the
    placement's stock locks never blocks the order. Simulated by changing the stock right after
    the placement's `evaluate()` (same transaction, before the locks)."""

    @pytest.fixture
    def after_evaluate(self, monkeypatch, shop):
        from apps.cart import services as cart_services
        from apps.cart.tests.test_api import set_stock

        def install(*changes):
            real = cart_services.evaluate

            def evaluate(*args, **kwargs):
                result = real(*args, **kwargs)
                for variant, on_hand in changes:
                    set_stock(shop.store_model, variant, on_hand)
                return result

            monkeypatch.setattr(services.cart_services, "evaluate", evaluate)

        return install

    def test_volume_carton_falls_back_to_the_next_size(self, checkout, shop, water, after_evaluate):
        """1 L x10 + 500 ml x10 earn 2 free 1 L; 1 L is down to the paid 10: 2 free 500 ml."""
        water.pricing.cod_max_order_value = Decimal("5000.00")  # ₹2,500 paid, COD
        water.pricing.save()
        checkout.fill((water.one_litre, 10), (water.half, 10))
        expected = checkout.cart()["bill"]["grand_total"]
        after_evaluate((water.one_litre, 10))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert [
            (i.variant_id, i.quantity, i.free_source) for i in order.items.filter(is_free=True)
        ] == [(water.half.pk, 2, "VOLUME_OFFER")]
        assert (reserved(shop, water.one_litre), reserved(shop, water.half)) == (10, 12)

    def test_no_size_left_places_the_order_without_it(self, checkout, shop, water, after_evaluate):
        checkout.fill((water.one_litre, 10))
        expected = checkout.cart()["bill"]["grand_total"]
        after_evaluate((water.one_litre, 10))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert not order.items.filter(is_free=True).exists()
        assert reserved(shop, water.one_litre) == 10
        assert order.grand_total == Decimal("1100.00")

    def test_reward_carton_gone_keeps_the_reward(
        self, checkout, shop, water, welcome, after_evaluate
    ):
        """The reward's size ran out: the order is placed without it and the reward is not used
        (still AVAILABLE, no redemption, no coupon on the order)."""
        checkout.fill((water.one_litre, 5))
        expected = apply_reward(checkout, welcome.code, water.half)["bill"]["grand_total"]
        after_evaluate((water.half, 0))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert not order.items.filter(is_free=True).exists()
        assert (order.coupon_id, order.coupon_code) == (None, "")
        assert not CouponRedemption.objects.filter(coupon=welcome).exists()
        assert state(welcome) == RewardStatus.AVAILABLE
        assert reserved(shop, water.half) == 0

    def test_paid_units_short_is_still_409_with_paid_quantities(
        self, checkout, shop, water, after_evaluate
    ):
        checkout.fill((water.one_litre, 10))  # 1 free carton expected
        expected = checkout.cart()["bill"]["grand_total"]
        after_evaluate((water.one_litre, 5))
        body = checkout.place(expected=expected, status=409)
        assert body["error"]["code"] == "STOCK_UNAVAILABLE"
        assert body["error"]["details"] == {
            "items": [
                {
                    "variant_id": water.one_litre.pk,
                    "requested_quantity": 10,
                    "orderable_quantity": 5,
                }
            ]
        }
        assert not Order.objects.exists()
