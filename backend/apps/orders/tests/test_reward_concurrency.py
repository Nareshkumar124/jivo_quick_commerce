"""ADR-0002 §13 with real concurrency (two database connections, committed data): a free-carton
reward has a usage limit of 1, checked on the locked coupon row in the placement transaction,
so two orders racing for the same reward never both get it."""

from decimal import Decimal

import pytest
from django.db import transaction

from apps.accounts.tests.factories import UserFactory
from apps.core.exceptions import ApiError
from apps.orders.tests.factories import OrderFactory
from apps.orders.tests.test_concurrency import outcome, race
from apps.promotions import rewards
from apps.promotions import services as promotions
from apps.promotions.choices import CouponSource, RewardStatus
from apps.promotions.models import CouponRedemption

pytestmark = pytest.mark.django_db(transaction=True)


@pytest.mark.parametrize("use", ["hold_coupon", "apply_coupon_now"])
def test_a_reward_is_never_used_twice(use):
    """ADR-0002: two orders of the owner use the same reward at once: one wins, the other is
    refused with COUPON_USAGE_EXCEEDED and nothing is recorded for it."""
    user = UserFactory()
    reward = rewards.create_reward(user, source=CouponSource.WELCOME)
    orders = [OrderFactory(user=user) for _ in range(2)]

    def job(order):
        def run():
            with transaction.atomic():
                return getattr(promotions, use)(order, reward, Decimal("0.00"))

        return run

    wins, losses = outcome(race(*(job(order) for order in orders)))
    assert len(wins) == 1
    assert len(losses) == 1
    assert isinstance(losses[0], ApiError)
    assert losses[0].error_code == "COUPON_USAGE_EXCEEDED"
    assert CouponRedemption.objects.filter(coupon=reward).count() == 1
    state = rewards.reward_state(rewards.rewards_of(user).get(pk=reward.pk))
    assert state.status == RewardStatus.CLAIMED


def test_two_welcome_rewards_at_once_make_one():
    """ADR-0002 §7: the database keeps one welcome reward per customer, whatever the race."""
    user = UserFactory()

    def grant():
        with transaction.atomic():
            return rewards.grant_welcome_reward(user)

    results = race(grant, grant)
    assert not [r for r in results if isinstance(r, Exception)]
    assert sum(r is not None for r in results) == 1
    assert rewards.rewards_of(user).filter(source=CouponSource.WELCOME).count() == 1
