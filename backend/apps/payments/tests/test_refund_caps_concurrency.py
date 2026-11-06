"""T-814 review (PM item 5): the Support caps hold under real concurrency (two DB connections,
committed data): two agents refunding one order, and one agent refunding two orders at once."""

import threading
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.db import connection

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.orders.models import Order
from apps.payments import order_refunds
from apps.payments.order_refunds import RefundCapExceeded

pytestmark = pytest.mark.django_db(transaction=True)
D = Decimal


def staff(role):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


def race(*jobs):
    barrier = threading.Barrier(len(jobs))
    results: list = [None] * len(jobs)

    def run(index, job):
        try:
            barrier.wait()
            results[index] = job()
        except Exception as exc:
            results[index] = exc
        finally:
            connection.close()

    threads = [threading.Thread(target=run, args=(i, job)) for i, job in enumerate(jobs)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)
    return results


@pytest.fixture
def make_paid(checkout, shop):
    def make() -> Order:
        checkout.fill((shop.canola_1l, 2))
        placement = checkout.place("ONLINE")
        checkout.verify(placement, payment_id=f"pay_Race{Order.objects.count():010d}")
        return Order.objects.get(pk=placement["order"]["id"])

    return make


def test_two_agents_one_order_per_order_cap(make_paid):
    order = make_paid()
    one, two = staff(roles.SUPPORT), staff(roles.SUPPORT)
    results = race(
        lambda: order_refunds.manual_refund(order.pk, D("300"), by=one),
        lambda: order_refunds.manual_refund(order.pk, D("300"), by=two),
    )
    wins = [r for r in results if not isinstance(r, Exception)]
    losses = [r for r in results if isinstance(r, Exception)]
    assert len(wins) == 1, results
    assert len(losses) == 1, results
    assert isinstance(losses[0], RefundCapExceeded), results
    assert order_refunds.support_refunded_on_order(order) == D("300.00")


def test_one_agent_two_orders_daily_cap(make_paid, settings):
    settings.SUPPORT_REFUND_DAILY_LIMIT = D("500.00")
    first, second = make_paid(), make_paid()
    agent = staff(roles.SUPPORT)
    results = race(
        lambda: order_refunds.manual_refund(first.pk, D("300"), by=agent),
        lambda: order_refunds.manual_refund(second.pk, D("300"), by=agent),
    )
    wins = [r for r in results if not isinstance(r, Exception)]
    losses = [r for r in results if isinstance(r, Exception)]
    assert len(wins) == 1, results
    assert len(losses) == 1, results
    assert isinstance(losses[0], RefundCapExceeded), results
    assert order_refunds.refunded_today_by(agent) == D("300.00")
