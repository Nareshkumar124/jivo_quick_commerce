"""T10 and the referral reward (added 2026-11-13): when a referred customer's first order is
delivered through the rider API, the reward is given after commit by the `order.delivered`
domain event, never inside the delivery request."""

import pytest

from apps.accounts.tests.factories import UserFactory
from apps.delivery.tests.test_task_flow import flow  # noqa: F401
from apps.promotions.models import Coupon
from apps.referrals import services as referrals
from apps.referrals.choices import ReferralStatus

pytestmark = pytest.mark.django_db


def test_rider_delivery_rewards_the_referral_after_commit(
    flow,  # noqa: F811
    user,
    django_capture_on_commit_callbacks,
):
    friend = UserFactory()
    referral = referrals.apply_code(user, referrals.code_for(friend).code)
    f = flow()
    assert f.order.user_id == user.pk
    f.to_customer()
    with django_capture_on_commit_callbacks(execute=False) as callbacks:
        assert f.deliver().status_code == 200
    referral.refresh_from_db()
    assert referral.status == ReferralStatus.PENDING  # nothing in the delivery request
    for callback in callbacks:  # the transaction commits: run the after-commit side effects
        callback()
    referral.refresh_from_db()
    assert referral.status == ReferralStatus.REWARDED
    assert referral.reward_order_id == f.order.pk
    owners = set(Coupon.objects.filter(owner__isnull=False).values_list("owner_id", flat=True))
    assert owners == {user.pk, friend.pk}


def test_delivery_without_a_referral_gives_no_coupon(
    flow,  # noqa: F811
    django_capture_on_commit_callbacks,
):
    f = flow()
    f.to_customer()
    with django_capture_on_commit_callbacks(execute=True):
        assert f.deliver().status_code == 200
    assert not Coupon.objects.filter(owner__isnull=False).exists()
