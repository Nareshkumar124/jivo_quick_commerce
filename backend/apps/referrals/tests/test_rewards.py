"""The referral reward (06 §2.1 "Referral", §5 `reward_referral`; added 2026-11-13): both
customers get a personal ₹90 coupon when the referred customer's first order is DELIVERED,
exactly once, after commit through the order domain event."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from freezegun import freeze_time

from apps import notifications
from apps.accounts.tests.factories import UserFactory
from apps.notifications.choices import DeliveryStatus
from apps.notifications.models import Notification
from apps.orders import events
from apps.orders import tasks as order_tasks
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.promotions.choices import DiscountType
from apps.promotions.models import Coupon
from apps.referrals import services, tasks
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import Referral, ReferralSettings

pytestmark = pytest.mark.django_db

NOW = timezone.now().replace(microsecond=0)


@pytest.fixture
def friend():
    return UserFactory()


@pytest.fixture
def referral(user, friend) -> Referral:
    """`user` (new customer) joined with `friend`'s code."""
    return services.apply_code(user, services.code_for(friend).code)


def delivered(user, **kwargs):
    return OrderFactory(
        user=user, status=OrderStatus.DELIVERED, delivered_at=timezone.now(), **kwargs
    )


def personal_coupons():
    return Coupon.objects.filter(owner__isnull=False)


def run(order) -> str:
    return tasks.reward_referral.apply(args=[order.pk]).get()


class TestReward:
    @freeze_time(NOW)
    def test_first_delivered_order_rewards_both_customers(self, referral, user, friend):
        """Both get a FLAT ₹90 personal coupon, one use, valid 30 days, no minimum."""
        order = delivered(user)
        assert run(order) == "rewarded"
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.REWARDED
        assert referral.reward_order == order
        assert referral.reward_amount == Decimal("90.00")
        assert referral.rewarded_at == NOW
        for owner, coupon in (
            (friend, referral.referrer_coupon),
            (user, referral.referred_coupon),
        ):
            assert coupon.owner == owner
            assert coupon.discount_type == DiscountType.FLAT
            assert coupon.value == Decimal("90.00")
            assert coupon.min_order_value == Decimal("0.00")
            assert (coupon.usage_limit_total, coupon.usage_limit_per_user) == (1, 1)
            assert coupon.ends_at == NOW + timedelta(days=30)
            assert coupon.starts_at is None
            assert coupon.is_active
            assert coupon.is_visible
            assert not coupon.first_order_only
            assert coupon.code.startswith("REF")
            assert len(coupon.code) == 11
            assert coupon.title == "₹90 off: referral reward"
        assert referral.referrer_coupon.code != referral.referred_coupon.code
        assert personal_coupons().count() == 2

    def test_both_customers_are_notified_once(self, referral, user, friend):
        """Inbox + push `referral.reward_earned` ("You earned ₹90 off"), no SMS."""
        run(delivered(user))
        sent = Notification.objects.filter(event=services.REWARD_EVENT).order_by("user_id")
        assert {note.user_id for note in sent} == {user.pk, friend.pk}
        for note in sent:
            assert note.title == "You earned ₹90 off"
            assert note.sms_status == DeliveryStatus.NONE
            assert note.data["link"] == "jivo://account/referral"
            assert note.in_inbox
        by_user = {note.user_id: note.body for note in sent}
        assert by_user[friend.pk].startswith("Your friend's first order was delivered.")
        assert by_user[user.pk].startswith("Thanks for joining with a friend's code.")

    @pytest.mark.parametrize(
        "status",
        [
            OrderStatus.PLACED,
            OrderStatus.ACCEPTED,
            OrderStatus.OUT_FOR_DELIVERY,
            OrderStatus.CANCELLED,
            OrderStatus.DELIVERY_FAILED,
        ],
    )
    def test_no_reward_before_delivery_or_without_it(self, referral, user, status):
        """A placed, cancelled or failed order gives nothing; the referral stays PENDING."""
        order = OrderFactory(user=user, status=status)
        assert run(order) == "not_delivered"
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.PENDING
        assert not personal_coupons().exists()

    def test_a_cancelled_first_order_then_a_delivered_one(self, referral, user):
        """The reward comes with the first order that is actually delivered."""
        cancelled = OrderFactory(user=user, status=OrderStatus.CANCELLED)
        assert run(cancelled) == "not_delivered"
        assert run(delivered(user)) == "rewarded"

    def test_second_delivered_order_gives_nothing(self, referral, user):
        assert run(delivered(user)) == "rewarded"
        assert run(delivered(user)) == "already_rewarded"
        assert personal_coupons().count() == 2

    def test_the_task_is_idempotent(self, referral, user):
        """A retried or duplicated task finds the referral REWARDED: no second coupon or
        notification."""
        order = delivered(user)
        assert run(order) == "rewarded"
        assert run(order) == "already_rewarded"
        assert personal_coupons().count() == 2
        assert Notification.objects.filter(event=services.REWARD_EVENT).count() == 2

    def test_customer_without_a_referral(self, referral, friend):
        """The referrer's own orders (or anyone not referred) trigger nothing."""
        assert run(delivered(friend)) == "no_referral"
        assert run(delivered(UserFactory())) == "no_referral"
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.PENDING
        assert not personal_coupons().exists()

    def test_unknown_order(self):
        assert services.reward_for_order(999_999_999) == "not_delivered"

    def test_program_off_at_the_first_delivery_voids_the_referral(self, referral, user):
        """No reward then, and none later when the program is back on."""
        ReferralSettings.objects.update_or_create(pk=1, defaults={"is_enabled": False})
        order = delivered(user)
        assert run(order) == "void"
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.VOID
        assert referral.reward_order == order
        assert referral.note == services.NOTE_PROGRAM_OFF
        ReferralSettings.objects.filter(pk=1).update(is_enabled=True)
        assert run(delivered(user)) == "already_void"
        assert not personal_coupons().exists()

    @freeze_time(NOW)
    def test_settings_are_read_when_the_reward_is_given(self, referral, user):
        ReferralSettings.objects.update_or_create(
            pk=1,
            defaults={
                "reward_amount": Decimal("120.00"),
                "reward_validity_days": 7,
                "reward_min_order_value": Decimal("199.00"),
            },
        )
        run(delivered(user))
        referral.refresh_from_db()
        assert referral.reward_amount == Decimal("120.00")
        for coupon in (referral.referrer_coupon, referral.referred_coupon):
            assert coupon.value == Decimal("120.00")
            assert coupon.min_order_value == Decimal("199.00")
            assert coupon.ends_at == NOW + timedelta(days=7)
            assert coupon.title == "₹120 off: referral reward"

    def test_a_failing_notification_never_undoes_the_reward(self, referral, user, monkeypatch):
        def boom(*args, **kwargs):
            raise RuntimeError("push service down")

        monkeypatch.setattr(notifications, "notify", boom)
        assert run(delivered(user)) == "rewarded"
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.REWARDED
        assert personal_coupons().count() == 2


class TestDomainEvent:
    def test_order_delivered_event_queues_the_reward(self, referral, user):
        """`order.delivered` (after commit, `orders.order_event`) runs the reward task."""
        order = delivered(user)
        order_tasks.order_event(events.DELIVERED, order.pk)
        referral.refresh_from_db()
        assert referral.status == ReferralStatus.REWARDED

    @pytest.mark.parametrize("event", [events.PLACED, events.OUT_FOR_DELIVERY, events.CANCELLED])
    def test_other_events_do_not(self, referral, user, event, monkeypatch):
        queued = []
        monkeypatch.setattr(tasks.reward_referral, "delay", lambda order_id: queued.append(1))
        monkeypatch.setattr(order_tasks, "schedule_acceptance", lambda order_id: None)
        order_tasks.order_event(event, delivered(user).pk)
        assert queued == []

    def test_a_queue_failure_never_breaks_the_event_handler(self, user, monkeypatch, caplog):
        def broken(order_id):
            raise ConnectionError("broker down")

        monkeypatch.setattr(tasks.reward_referral, "delay", broken)
        order = delivered(user)
        assert order_tasks.order_event(events.DELIVERED, order.pk) == events.DELIVERED
        assert "referral reward not queued" in caplog.text
