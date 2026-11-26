"""ADR-0003 on orders: with the store's fixed free size (1 L), the free cartons placed are 1 L
whatever the paid sizes; a reward's `value` cartons (2) are reserved with the paid units and
committed at pickup as one SALE movement per variant; under the placement locks the fixed size
gets no fallback, and a reward whose 2 cartons no longer fit is dropped and stays AVAILABLE."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.db import transaction

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.inventory import services as inventory
from apps.inventory.models import MovementType, StockMovement, StockReservation, StoreInventory
from apps.orders import store_ops
from apps.orders.models import Order
from apps.orders.tests.test_free_cartons import lines_of, reserved, state
from apps.promotions import rewards
from apps.promotions.choices import CouponSource, RewardStatus
from apps.promotions.models import CouponRedemption
from apps.referrals.models import ReferralSettings
from apps.stores.services import grant_store_access

pytestmark = pytest.mark.django_db

COUPON = "/api/v1/cart/coupon/"


@pytest.fixture
def fixed(water):
    water.pricing.free_unit_variant = water.one_litre
    water.pricing.cod_max_order_value = Decimal("5000.00")
    water.pricing.save()
    ReferralSettings.objects.update_or_create(
        pk=1, defaults={"welcome_reward_quantity": 2, "reward_quantity": 2}
    )
    return water


@pytest.fixture
def welcome(user, fixed):
    return rewards.create_reward(user, source=CouponSource.WELCOME)  # 2 cartons


@pytest.fixture
def staff(shop):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=roles.STORE_MANAGER))
    grant_store_access(user, shop.store_model)
    return user


def apply_reward(checkout, code):
    """ADR-0003: applied without a size."""
    response = checkout.client.post(COUPON, {"code": code}, headers=checkout.headers)
    assert response.status_code == 200, response.content
    return response.json()


def place(checkout, *lines, reward=None, expected=None):
    checkout.fill(*lines)
    if reward is not None:
        apply_reward(checkout, reward)
    placement = checkout.place("COD", expected=expected)
    return Order.objects.get(pk=placement["order"]["id"])


class TestPlacement:
    def test_quarter_litre_order_gets_a_free_litre_carton(self, checkout, shop, fixed):
        """10 x 250 ml: the order's free line is 1 x 1 L (VOLUME_OFFER), reserved."""
        order = place(checkout, (fixed.quarter, 10))
        assert lines_of(order) == [
            (fixed.quarter.pk, 10, Decimal("110.00"), False, ""),
            (fixed.one_litre.pk, 1, Decimal("0.00"), True, "VOLUME_OFFER"),
        ]
        assert (reserved(shop, fixed.quarter), reserved(shop, fixed.one_litre)) == (10, 1)
        assert order.grand_total == Decimal("1100.00")

    def test_reward_reserves_both_cartons(self, checkout, shop, fixed, welcome):
        """ADR-0003 §2: 5 x 500 ml + the 2-carton reward: a REWARD line of 2 x 1 L; one
        reservation of 2 for 1 L, in the placement transaction; the reward is CLAIMED."""
        order = place(checkout, (fixed.half, 5), reward=welcome.code)
        assert lines_of(order) == [
            (fixed.half.pk, 5, Decimal("140.00"), False, ""),
            (fixed.one_litre.pk, 2, Decimal("0.00"), True, "REWARD"),
        ]
        assert {
            (r.variant_id, r.quantity) for r in StockReservation.objects.filter(order=order)
        } == {(fixed.half.pk, 5), (fixed.one_litre.pk, 2)}
        assert order.coupon == welcome
        assert state(welcome) == RewardStatus.CLAIMED

    def test_volume_and_reward_of_the_same_size_reserve_together(
        self, checkout, shop, fixed, welcome
    ):
        """10 x 500 ml + reward: 1 L free = 1 (volume) + 2 (reward), one reservation of 3."""
        order = place(checkout, (fixed.half, 10), reward=welcome.code)
        free = [(i.variant_id, i.quantity, i.free_source) for i in order.items.filter(is_free=True)]
        assert sorted(free) == sorted(
            [(fixed.one_litre.pk, 1, "VOLUME_OFFER"), (fixed.one_litre.pk, 2, "REWARD")]
        )
        assert StockReservation.objects.get(order=order, variant=fixed.one_litre).quantity == 3


class TestCommit:
    def test_pickup_commits_the_two_reward_cartons(self, checkout, shop, fixed, welcome, staff):
        """08 T9: on_hand and reserved drop by paid + free per variant, one SALE movement
        each: 500 ml -5, 1 L -2."""
        order = place(checkout, (fixed.half, 5), reward=welcome.code)
        store_ops.accept_order(order.pk, by=staff)
        store_ops.start_packing(order.pk, by=staff)
        store_ops.mark_packed(order.pk, by=staff)
        with transaction.atomic():
            assert inventory.commit_reservations(order) == 2
        for variant, units in ((fixed.half, 5), (fixed.one_litre, 2)):
            row = StoreInventory.objects.get(store=shop.store_model, variant=variant)
            assert (row.on_hand, row.reserved) == (100 - units, 0)
            movement = StockMovement.objects.get(order=order, variant=variant)
            assert (movement.type, movement.delta) == (MovementType.SALE, -units)

    def test_cancel_releases_both_cartons_and_returns_the_reward(
        self, checkout, shop, fixed, welcome
    ):
        order = place(checkout, (fixed.half, 5), reward=welcome.code)
        response = checkout.client.post(
            f"/api/v1/orders/{order.pk}/cancel/", {"reason": "CHANGED_MIND"}
        )
        assert response.status_code == 200, response.content
        assert reserved(shop, fixed.one_litre) == 0
        assert state(welcome) == RewardStatus.AVAILABLE


class TestPlacementRace:
    """A free carton that ran out between the cart read and the placement's stock locks
    (simulated right after the placement's `evaluate()`, as in test_free_cartons.py)."""

    @pytest.fixture
    def after_evaluate(self, monkeypatch, shop):
        from apps.cart import services as cart_services
        from apps.cart.tests.test_api import set_stock
        from apps.orders import services

        def install(*changes):
            real = cart_services.evaluate

            def evaluate(*args, **kwargs):
                result = real(*args, **kwargs)
                for variant, on_hand in changes:
                    set_stock(shop.store_model, variant, on_hand)
                return result

            monkeypatch.setattr(services.cart_services, "evaluate", evaluate)

        return install

    def test_two_carton_reward_that_no_longer_fits_is_dropped(
        self, checkout, shop, fixed, welcome, after_evaluate
    ):
        """ADR-0003 §2 + ADR-0002 §6: only 1 x 1 L left for the 2-carton reward: the order is
        placed without it, nothing of 1 L is reserved and the reward stays AVAILABLE."""
        checkout.fill((fixed.half, 5))
        expected = apply_reward(checkout, welcome.code)["bill"]["grand_total"]
        after_evaluate((fixed.one_litre, 1))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert not order.items.filter(is_free=True).exists()
        assert (order.coupon_id, order.coupon_code) == (None, "")
        assert not CouponRedemption.objects.filter(coupon=welcome).exists()
        assert state(welcome) == RewardStatus.AVAILABLE
        assert reserved(shop, fixed.one_litre) == 0
        assert reserved(shop, fixed.half) == 5

    def test_reward_fits_volume_carton_does_not(
        self, checkout, shop, fixed, welcome, after_evaluate
    ):
        """10 x 500 ml + reward need 3 x 1 L; 2 left under the lock: the reward's 2 are kept
        (reward first), the volume carton is left out (no fallback to 500 ml)."""
        checkout.fill((fixed.half, 10))
        expected = apply_reward(checkout, welcome.code)["bill"]["grand_total"]
        after_evaluate((fixed.one_litre, 2))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        free = [(i.variant_id, i.quantity, i.free_source) for i in order.items.filter(is_free=True)]
        assert free == [(fixed.one_litre.pk, 2, "REWARD")]
        assert (reserved(shop, fixed.one_litre), reserved(shop, fixed.half)) == (2, 10)
        assert state(welcome) == RewardStatus.CLAIMED

    def test_fixed_size_switched_off_under_the_lock(
        self, checkout, shop, fixed, welcome, monkeypatch
    ):
        """Code review: 1 L is switched off (stock kept) between the cart read and the locks:
        neither the volume carton nor the reward's 2 cartons are given; the reward stays
        AVAILABLE and nothing of 1 L is reserved."""
        from apps.cart import services as cart_services
        from apps.orders import services

        checkout.fill((fixed.half, 10))
        expected = apply_reward(checkout, welcome.code)["bill"]["grand_total"]
        real = cart_services.evaluate

        def evaluate(*args, **kwargs):
            result = real(*args, **kwargs)
            StoreInventory.objects.filter(store=shop.store_model, variant=fixed.one_litre).update(
                is_available=False
            )
            return result

        monkeypatch.setattr(services.cart_services, "evaluate", evaluate)
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert not order.items.filter(is_free=True).exists()
        assert (reserved(shop, fixed.half), reserved(shop, fixed.one_litre)) == (10, 0)
        assert state(welcome) == RewardStatus.AVAILABLE

    def test_fixed_size_gone_no_fallback(self, checkout, shop, fixed, after_evaluate):
        """10 x 250 ml earn 1 x 1 L; 1 L runs out under the lock: no free carton (250 ml has
        stock but is never used as a fallback)."""
        checkout.fill((fixed.quarter, 10))
        expected = checkout.cart()["bill"]["grand_total"]
        after_evaluate((fixed.one_litre, 0))
        order = Order.objects.get(pk=checkout.place(expected=expected)["order"]["id"])
        assert not order.items.filter(is_free=True).exists()
        assert (reserved(shop, fixed.quarter), reserved(shop, fixed.one_litre)) == (10, 0)
