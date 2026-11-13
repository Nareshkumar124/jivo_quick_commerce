"""The referral safety sweep (06 §5 `reward_pending_referrals`, beat hourly): a PENDING referral
whose customer already has a DELIVERED order is rewarded through the normal idempotent path, so a
lost `order.delivered` event never loses a reward and nothing is ever rewarded twice."""

from datetime import timedelta

import pytest
from django.conf import settings
from django.utils import timezone

from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.referrals import services, tasks
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import ReferralSettings
from apps.referrals.tests import test_rewards as rewards
from apps.referrals.tests.test_rewards import delivered, personal_coupons

pytestmark = pytest.mark.django_db

friend = rewards.friend  # the reward tests' fixtures: `referral` = `user` joined with `friend`
referral = rewards.referral


def sweep() -> dict:
    return tasks.reward_pending_referrals.apply().get()


def test_is_scheduled_hourly():
    entry = next(
        e
        for e in settings.CELERY_BEAT_SCHEDULE.values()
        if e["task"] == "referrals.reward_pending_referrals"
    )
    assert str(entry["schedule"].minute) == "{25}"
    assert len(entry["schedule"].hour) == 24


def test_lost_event_is_rewarded_once_for_the_earliest_delivered_order(referral, user):
    """The event never ran: the sweep rewards for the earliest delivered order, once; a second
    sweep (and the late event) change nothing."""
    later = delivered(user)
    earliest = OrderFactory(
        user=user,
        status=OrderStatus.DELIVERED,
        delivered_at=timezone.now() - timedelta(days=1),
    )
    assert sweep() == {"rewarded": 1}
    referral.refresh_from_db()
    assert (referral.status, referral.reward_order) == (ReferralStatus.REWARDED, earliest)
    assert personal_coupons().count() == 2
    assert sweep() == {}  # no PENDING referral left
    assert services.reward_for_order(later.pk) == "already_rewarded"
    assert personal_coupons().count() == 2


def test_already_rewarded_referral_is_left_alone(referral, user):
    order = delivered(user)
    assert services.reward_for_order(order.pk) == "rewarded"
    assert sweep() == {}
    assert personal_coupons().count() == 2


@pytest.mark.parametrize("status", [OrderStatus.PLACED, OrderStatus.CANCELLED])
def test_no_delivered_order_means_nothing(referral, user, status):
    OrderFactory(user=user, status=status)
    assert sweep() == {}
    referral.refresh_from_db()
    assert referral.status == ReferralStatus.PENDING
    assert not personal_coupons().exists()


def test_program_off_voids_as_in_the_normal_path(referral, user):
    config = ReferralSettings.load()
    config.is_enabled = False
    config.save()
    order = delivered(user)
    assert sweep() == {"void": 1}
    referral.refresh_from_db()
    assert (referral.status, referral.reward_order) == (ReferralStatus.VOID, order)
    assert not personal_coupons().exists()


def test_batch_limit_and_one_failure_does_not_stop_the_rest(
    referral, user, friend, monkeypatch, caplog
):
    """At most `limit` per run (oldest first); an error on one referral is logged and the
    next one is still rewarded."""
    from apps.accounts.tests.factories import UserFactory

    other = UserFactory()
    services.apply_code(other, services.code_for(friend).code)
    delivered(user)
    delivered(other)
    assert services.reward_pending_referrals(limit=1) == {"rewarded": 1}

    third = UserFactory()
    services.apply_code(third, services.code_for(friend).code)
    delivered(third)
    real = services.reward_for_order
    calls = []

    def flaky(order_id, *, now=None):
        calls.append(order_id)
        if len(calls) == 1:
            raise RuntimeError("boom")
        return real(order_id, now=now)

    monkeypatch.setattr(services, "reward_for_order", flaky)
    assert services.reward_pending_referrals() == {"error": 1, "rewarded": 1}
    assert "Referral sweep" in caplog.text
    assert services.reward_pending_referrals() == {"rewarded": 1}  # retried next run
