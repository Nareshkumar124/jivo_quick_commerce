"""T-814 (M3, DL-59): Support refund caps (₹500 in total per order, ₹5,000 per agent per IST
day; both settings), and the ops alert on unusual refund volume per staff member."""

import re
from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import ValidationError
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.orders.models import Order
from apps.payments import order_refunds
from apps.payments.order_refunds import RefundCapExceeded

pytestmark = pytest.mark.django_db
D = Decimal
IST = ZoneInfo("Asia/Kolkata")


def staff(role):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


@pytest.fixture
def make_paid(checkout, shop):
    """Online orders for 2 x canola 1 L (₹558 each), paid."""

    def make() -> Order:
        checkout.fill((shop.canola_1l, 2))
        placement = checkout.place("ONLINE")
        checkout.verify(placement, payment_id=f"pay_Cap{Order.objects.count():011d}")
        return Order.objects.get(pk=placement["order"]["id"])

    return make


class TestPerOrderCap:
    def test_support_total_per_order(self, make_paid):
        order = make_paid()
        support, other_support = staff(roles.SUPPORT), staff(roles.SUPPORT)
        order_refunds.manual_refund(order.pk, D("300"), by=support)
        # The cap is Support's total on the order, whoever in Support refunds.
        with pytest.raises(RefundCapExceeded, match=re.escape("₹200.00 is left")):
            order_refunds.manual_refund(order.pk, D("200.01"), by=other_support)
        assert order_refunds.manual_refund(order.pk, D("200"), by=other_support)
        with pytest.raises(RefundCapExceeded):
            order_refunds.manual_refund(order.pk, D("0.01"), by=support)
        assert order_refunds.support_refunded_on_order(order) == D("500.00")

    def test_finance_refunds_do_not_use_supports_cap_and_are_uncapped(self, make_paid):
        order = make_paid()
        order_refunds.manual_refund(order.pk, D("58"), by=staff(roles.FINANCE))
        assert order_refunds.support_refunded_on_order(order) == D("0.00")
        assert order_refunds.manual_refund(order.pk, D("500"), by=staff(roles.SUPPORT))

    def test_finance_and_super_admin_above_the_cap(self, make_paid, superuser):
        order = make_paid()
        assert order_refunds.manual_refund(order.pk, D("501"), by=staff(roles.FINANCE))
        other = make_paid()
        assert order_refunds.manual_refund(other.pk, D("558"), by=superuser)
        third = make_paid()
        assert order_refunds.manual_refund(third.pk, D("558"), by=staff(roles.SUPER_ADMIN))

    def test_cap_is_a_setting(self, make_paid, settings):
        settings.SUPPORT_REFUND_LIMIT = D("50.00")
        order = make_paid()
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(order.pk, D("50.01"), by=staff(roles.SUPPORT))


class TestDailyCap:
    def test_daily_cap_per_agent(self, make_paid, settings):
        settings.SUPPORT_REFUND_DAILY_LIMIT = D("150.00")
        first, second = make_paid(), make_paid()
        support = staff(roles.SUPPORT)
        order_refunds.manual_refund(first.pk, D("100"), by=support)
        with pytest.raises(RefundCapExceeded, match=re.escape("₹50.00 is left today")):
            order_refunds.manual_refund(second.pk, D("60"), by=support)
        # Another agent has their own daily allowance.
        assert order_refunds.manual_refund(second.pk, D("60"), by=staff(roles.SUPPORT))
        assert order_refunds.manual_refund(second.pk, D("50"), by=support)
        assert order_refunds.refunded_today_by(support) == D("150.00")

    def test_ist_day_boundary(self, make_paid, settings):
        """23:50 IST and 00:10 IST the next day are different days, though both are 18:xx UTC
        on one UTC date."""
        settings.SUPPORT_REFUND_DAILY_LIMIT = D("100.00")
        first, second = make_paid(), make_paid()
        support = staff(roles.SUPPORT)
        before_midnight = datetime(2026, 11, 5, 23, 50, tzinfo=IST)
        after_midnight = datetime(2026, 11, 6, 0, 10, tzinfo=IST)
        with freeze_time(before_midnight):
            order_refunds.manual_refund(first.pk, D("100"), by=support)
            with pytest.raises(RefundCapExceeded):
                order_refunds.manual_refund(second.pk, D("1"), by=support)
        with freeze_time(after_midnight):
            assert order_refunds.refunded_today_by(support) == D("0.00")
            assert order_refunds.manual_refund(second.pk, D("100"), by=support)
            with pytest.raises(RefundCapExceeded):
                order_refunds.manual_refund(second.pk, D("1"), by=support)

    def test_finance_has_no_daily_cap(self, make_paid, settings):
        settings.SUPPORT_REFUND_DAILY_LIMIT = D("10.00")
        finance = staff(roles.FINANCE)
        assert order_refunds.manual_refund(make_paid().pk, D("100"), by=finance)
        assert order_refunds.manual_refund(make_paid().pk, D("100"), by=finance)


class TestRefundVolumeAlert:
    def test_alert_once_per_hour_above_the_threshold(
        self, make_paid, superuser, settings, caplog, django_capture_on_commit_callbacks
    ):
        settings.REFUND_VOLUME_ALERT_PER_HOUR = 2
        order = make_paid()
        with caplog.at_level("ERROR"), django_capture_on_commit_callbacks(execute=True):
            for _ in range(2):
                order_refunds.manual_refund(order.pk, D("10"), by=superuser)
            assert "refund_volume_high" not in caplog.text
            order_refunds.manual_refund(order.pk, D("10"), by=superuser)
            order_refunds.manual_refund(order.pk, D("10"), by=superuser)
        alerts = [r for r in caplog.records if "payment.refund_volume_high" in r.getMessage()]
        assert len(alerts) == 1  # the ops alert (orders.order_event), once per hour
        assert "Refund volume: staff" in caplog.text
