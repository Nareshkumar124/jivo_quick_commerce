"""Slice 5.4 Ops screens and buttons (apps/ops_console/delivery_ops*.py; DL-61 a, 05 §1.4, §1.5).

Runs on both sides of the 5.4 merge:
- before it, the cash / payouts screens are refused to everyone and the unlock / fail buttons
  are disabled (a crafted POST gets 501); force offline already works (its service exists);
- the panel side (role matrix, store scoping, form validation, which service is called with
  what) is tested with a stand-in service, so it is covered now;
- the `HAS_*_54` tests run the real 5.4 services once they are merged.
"""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import Rider
from apps.ops_console import capabilities, delivery_ops
from apps.ops_console.tests import test_dispatch
from apps.ops_console.tests.helpers import (
    CASH_ROLES,
    DISPATCH_ROLES,
    HAS_CASH_54,
    HAS_PAYOUTS_54,
    PAYOUT_ROLES,
    PRINCIPALS,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import make_order
from apps.ops_console.tests.test_dispatch import make_task, online, task_url
from apps.orders.choices import OrderStatus
from apps.stores.services import grant_store_access

pytestmark = pytest.mark.django_db

world = test_dispatch.world  # the dispatch fixture: two stores, riders, tasks

HX = {"HTTP_HX_REQUEST": "true"}
CALLS: list[tuple] = []
THIS = "apps.ops_console.tests.test_delivery_ops"


def stand_in(*args, **kwargs):
    """A stand-in 5.4 service: records the call."""
    CALLS.append((args, kwargs))


@pytest.fixture
def fake_services(monkeypatch):
    """Every 5.4 action points at `stand_in`, so the panel side runs before the merge."""
    CALLS.clear()
    for action in (
        delivery_ops.UNLOCK_PICKUP,
        delivery_ops.UNLOCK_OTP,
        delivery_ops.FAIL_DELIVERY,
        delivery_ops.FORCE_OFFLINE,
    ):
        monkeypatch.setitem(delivery_ops.SERVICES, action, (THIS, "stand_in"))
    return CALLS


def at_store(world, **kwargs):
    task = world["assigned"]
    task.status = TS.AT_STORE
    task.pickup_attempts = kwargs.get("pickup_attempts", 5)
    task.pickup_locked_at = timezone.now()
    task.save(update_fields=["status", "pickup_attempts", "pickup_locked_at"])
    return task


def out_for_delivery(world, status=TS.AT_CUSTOMER):
    order = make_order(world["own"], OrderStatus.OUT_FOR_DELIVERY, order_number="JV-DSP-0050")
    rider = online(Rider.objects.get(pk=world["rider"].pk))
    return make_task(
        order,
        status,
        rider=rider,
        picked_up_at=timezone.now() - timedelta(minutes=5),
        otp_attempts=5,
        otp_locked_at=timezone.now(),
    )


# --------------------------------------------------------------------------- task buttons


def test_unlock_and_fail_buttons_follow_state_and_availability(client, world):
    client.force_login(staff_in_role(roles.OPS))
    task = at_store(world)
    page = client.get(task_url(task)).content.decode()
    assert 'data-testid="unlock-pickup"' in page
    assert 'data-testid="unlock-otp"' not in page  # not at the customer
    assert 'data-testid="mark-failed"' not in page  # not picked up
    disabled = 'data-testid="unlock-pickup" disabled'
    assert (disabled in page) is not delivery_ops.available(delivery_ops.UNLOCK_PICKUP)

    road = out_for_delivery(world)
    page = client.get(task_url(road)).content.decode()
    assert 'data-testid="unlock-otp"' in page
    assert 'data-testid="mark-failed"' in page
    assert 'data-testid="unlock-pickup"' not in page


def test_missing_54_service_is_501_and_not_called(client, world, monkeypatch):
    monkeypatch.setitem(
        delivery_ops.SERVICES, delivery_ops.UNLOCK_PICKUP, (THIS, "no_such_service")
    )
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(task_url(at_store(world), "ops:dispatch-unlock-pickup"), **HX)
    assert response.status_code == 501


@pytest.mark.parametrize(
    ("name", "fail"),
    [
        ("ops:dispatch-unlock-pickup", False),
        ("ops:dispatch-unlock-otp", False),
        ("ops:dispatch-fail", True),
    ],
)
def test_task_buttons_call_the_service_with_the_order(client, world, fake_services, name, fail):
    user = staff_in_role(roles.OPS)
    client.force_login(user)
    task = out_for_delivery(world)
    reason = delivery_ops.fail_reasons()[0][0]
    data = {"reason": reason, "note": "No answer   x3"} if fail else {}
    response = client.post(task_url(task, name), data, **HX)
    assert response.status_code == 204, response.content
    assert "ops:toast" in response["HX-Trigger"]
    (args, kwargs) = fake_services[0]
    assert args == (task.order_id,)
    assert kwargs["by"] == user
    if fail:
        assert kwargs["reason"] == reason
        assert kwargs["note"] == "No answer   x3"  # the service normalises it


def test_fail_needs_reason_and_note(client, world, fake_services):
    client.force_login(staff_in_role(roles.OPS))
    task = out_for_delivery(world)
    response = client.post(task_url(task, "ops:dispatch-fail"), {"reason": ""}, **HX)
    assert response.status_code == 400
    assert fake_services == []


@pytest.mark.parametrize(
    "name", ["ops:dispatch-unlock-pickup", "ops:dispatch-unlock-otp", "ops:dispatch-fail"]
)
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_task_buttons_role_matrix(client, world, fake_services, principal, name):
    """DL-61 (a): Super Admin, Ops, Store Manager (own store). Support, Finance, Store Staff and
    the rest: 403 and no service call."""
    login_with_stores(client, principal, world["own"])
    task = out_for_delivery(world)
    data = {"reason": delivery_ops.fail_reasons()[0][0], "note": "Gate locked"}
    response = client.post(task_url(task, name), data)
    assert response.status_code == expected_status(principal, DISPATCH_ROLES, 302), principal
    assert bool(fake_services) is (principal in DISPATCH_ROLES)


def test_other_store_task_is_404_and_not_called(client, world, fake_services):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, world["own"])
    client.force_login(manager)
    other = world["other_task"]
    for name in ("ops:dispatch-unlock-pickup", "ops:dispatch-unlock-otp", "ops:dispatch-fail"):
        assert client.post(task_url(other, name), {"note": "x"}).status_code == 404
    assert fake_services == []


def test_task_buttons_need_post(client, world):
    client.force_login(staff_in_role(roles.OPS))
    assert client.get(task_url(at_store(world), "ops:dispatch-unlock-pickup")).status_code == 405


# --------------------------------------------------------------------------- force offline


def offline_url(rider) -> str:
    return reverse("ops:dispatch-force-offline", args=[rider.pk])


def test_force_offline_button_on_idle_riders_only(client, world):
    client.force_login(staff_in_role(roles.OPS))
    board = client.get(reverse("ops:dispatch")).content.decode()
    assert f'data-testid="force-offline-{world["rider"].pk}"' in board
    assert f'data-testid="force-offline-{world["busy_rider"].pk}"' not in board  # on a task


def test_force_offline_real_service(client, world):
    """`shifts.force_offline` is on the branch already: Ops takes an idle rider offline."""
    client.force_login(staff_in_role(roles.OPS))
    rider = world["rider"]
    response = client.post(offline_url(rider), **HX)
    assert response.status_code == 204, response.content
    rider.refresh_from_db()
    assert rider.is_online is False


def test_force_offline_refused_during_a_task(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(offline_url(world["busy_rider"]), **HX)
    assert response.status_code == 409
    assert Rider.objects.get(pk=world["busy_rider"].pk).is_online is True


def test_force_offline_other_store_rider_is_404(client, world, fake_services):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, world["own"])
    client.force_login(manager)
    assert client.post(offline_url(world["other_rider"])).status_code == 404
    assert fake_services == []


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_force_offline_role_matrix(client, world, fake_services, principal):
    login_with_stores(client, principal, world["own"])
    response = client.post(offline_url(world["rider"]))
    assert response.status_code == expected_status(principal, DISPATCH_ROLES, 302), principal
    assert bool(fake_services) is (principal in DISPATCH_ROLES)


# --------------------------------------------------------------------------- cash, payouts


@pytest.mark.parametrize("url_name", ["ops:cash", "ops:cash-riders"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_cash_role_matrix(client, world, principal, url_name):
    """05 §3 "Cash deposit entry" + DL-61 (a): Super Admin, Ops, Store Manager own, Finance.
    Before the 5.4 merge: nobody (CASH_ROLES is empty)."""
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(url_name))
    assert response.status_code == expected_status(principal, CASH_ROLES), principal


@pytest.mark.parametrize("url_name", ["ops:payouts", "ops:payouts-list"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_payouts_role_matrix(client, world, principal, url_name):
    """05 §3 "Payouts": Super Admin, Finance. Before the 5.4 merge: nobody."""
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(url_name))
    assert response.status_code == expected_status(principal, PAYOUT_ROLES), principal


@pytest.mark.skipif(HAS_CASH_54, reason="5.4 merged: covered by the real-service tests")
def test_cash_and_payouts_hidden_before_54(client, world):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    page = client.get(reverse("ops:dashboard")).content.decode()
    assert reverse("ops:cash") not in page
    assert reverse("ops:payouts") not in page
    rider = world["rider"]
    response = client.post(reverse("ops:cash-deposit", args=[rider.pk]), {"amount": "10.00"})
    assert response.status_code == 403


@pytest.mark.skipif(not HAS_CASH_54, reason="needs the slice 5.4 cash service")
def test_store_manager_records_deposit_for_own_rider(client, world):
    from apps.delivery.services import cash

    rider = world["rider"]
    cash.record_cash(rider, Decimal("500.00"), "COD_COLLECTED", note="test")
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, world["own"])
    client.force_login(manager)
    page = client.get(reverse("ops:cash"))
    assert page.status_code == 200
    assert f'data-testid="cash-rider-{world["other_rider"].pk}"' not in page.content.decode()
    url = reverse("ops:cash-deposit", args=[rider.pk])
    data = {"amount": "200.00", "key": "k-1"}
    assert client.post(url, data, **HX).status_code == 204
    assert client.post(url, data, **HX).status_code == 204  # same key: one deposit
    rider.refresh_from_db()
    assert rider.cash_in_hand == Decimal("300.00")
    too_much = client.post(url, {"amount": "999.00", "key": "k-2"}, **HX)
    assert too_much.status_code == 400
    other = reverse("ops:cash-deposit", args=[world["other_rider"].pk])
    assert client.post(other, {"amount": "1.00"}, **HX).status_code == 404


@pytest.mark.skipif(not HAS_PAYOUTS_54, reason="needs the slice 5.4 payout service")
def test_finance_creates_and_pays_a_payout(client, world):
    from apps.delivery.models import Payout, RiderEarning

    RiderEarning.objects.create(
        rider=world["rider"], type="INCENTIVE", amount=Decimal("120.00"), earned_at=timezone.now()
    )
    client.force_login(staff_in_role(roles.FINANCE))
    today = timezone.localdate().isoformat()
    response = client.post(
        reverse("ops:payouts-create"), {"period_start": today, "period_end": today}, **HX
    )
    assert response.status_code == 204, response.content
    payout = Payout.objects.get(rider=world["rider"])
    assert payout.amount == Decimal("120.00")
    paid = client.post(reverse("ops:payout-paid", args=[payout.pk]), {"reference": "UTR1"}, **HX)
    assert paid.status_code == 204
    payout.refresh_from_db()
    assert payout.status == "PAID"
    assert client.post(reverse("ops:payout-void", args=[payout.pk]), **HX).status_code == 400


# --------------------------------------------------------------------------- review fixes


def stand_in_cash_riders(user, store_id=None):
    from apps.stores.services import stores_for

    return Rider.objects.filter(home_store__in=stores_for(user)).select_related("home_store")


@pytest.fixture
def fake_cash(monkeypatch):
    """The cash screen with stand-in 5.4 services (panel side, before the merge)."""
    CALLS.clear()
    monkeypatch.setitem(capabilities.SERVICE_GATED, capabilities.CASH_DEPOSIT, (THIS, "stand_in"))
    monkeypatch.setitem(
        delivery_ops.SERVICES, delivery_ops.CASH_RIDERS, (THIS, "stand_in_cash_riders")
    )
    monkeypatch.setitem(delivery_ops.SERVICES, delivery_ops.RECORD_DEPOSIT, (THIS, "stand_in"))
    return CALLS


def deposit(client, rider, **data):
    return client.post(reverse("ops:cash-deposit", args=[rider.pk]), data, **HX)


def test_deposit_key_is_required(client, world, fake_cash):
    client.force_login(make_superuser())
    rider = world["rider"]
    assert deposit(client, rider, amount="10.00").status_code == 400
    assert deposit(client, rider, amount="10.00", key="").status_code == 400
    assert fake_cash == []


def test_same_key_twice_is_passed_through_for_one_deposit(client, world, fake_cash):
    """The service records one deposit per key (real-service test below); the panel must send
    the form's key unchanged on a resend, and the rider's home store."""
    client.force_login(make_superuser())
    rider = world["rider"]
    for _ in range(2):
        assert deposit(client, rider, amount="10.00", key="k-1").status_code == 204
    keys = [kwargs["idempotency_key"] for _, kwargs in fake_cash]
    assert keys == ["k-1", "k-1"]
    assert {kwargs["store_id"] for _, kwargs in fake_cash} == {rider.home_store_id}


def test_deposit_at_another_store_is_refused(client, world, fake_cash):
    client.force_login(make_superuser())
    rider = world["rider"]
    response = deposit(client, rider, amount="10.00", key="k-2", store=world["other"].pk)
    assert response.status_code == 400
    assert fake_cash == []
    ok = deposit(client, rider, amount="10.00", key="k-3", store=world["own"].pk)
    assert ok.status_code == 204


@pytest.mark.skipif(not HAS_CASH_54, reason="needs the slice 5.4 cash service")
def test_real_deposit_same_key_once_empty_key_refused(client, world):
    from apps.delivery.models import RiderCashLedger
    from apps.delivery.services import cash

    rider = world["rider"]
    cash.record_cash(rider, Decimal("500.00"), "COD_COLLECTED", note="test")
    client.force_login(staff_in_role(roles.OPS))
    assert deposit(client, rider, amount="50.00", key="same").status_code == 204
    assert deposit(client, rider, amount="50.00", key="same").status_code == 204
    assert deposit(client, rider, amount="50.00", key="").status_code == 400
    assert RiderCashLedger.objects.filter(rider=rider, entry_type="DEPOSIT").count() == 1
    rider.refresh_from_db()
    assert rider.cash_in_hand == Decimal("450.00")
    other_store = deposit(client, rider, amount="5.00", key="x", store=world["other"].pk)
    assert other_store.status_code == 400


@pytest.mark.parametrize("role", [roles.OPS, roles.STORE_MANAGER])
@pytest.mark.parametrize("url_name", ["ops:payouts", "ops:payouts-list", "ops:payouts-create"])
def test_payouts_refused_to_ops_and_store_manager(client, world, monkeypatch, role, url_name):
    """05 §3 "Payouts": Super Admin, Finance only. Even with the service present (forced here),
    Ops and Store Manager get 403, and their roles never hold `delivery.manage_payouts`."""
    monkeypatch.setitem(capabilities.SERVICE_GATED, capabilities.PAYOUTS, (THIS, "stand_in"))
    user = staff_in_role(role)
    if role == roles.STORE_MANAGER:
        grant_store_access(user, world["own"])
    client.force_login(user)
    assert not user.has_perm("delivery.manage_payouts")
    assert "delivery.manage_payouts" not in roles.ROLE_PERMISSIONS[role]
    method = client.post if url_name == "ops:payouts-create" else client.get
    assert method(reverse(url_name)).status_code == 403


def test_manage_payouts_only_for_finance_among_listed_roles():
    holders = {
        role for role, perms in roles.ROLE_PERMISSIONS.items() if "delivery.manage_payouts" in perms
    }
    expected = {roles.FINANCE} if HAS_PAYOUTS_54 else set()
    assert holders == expected  # Super Admin gets every permission implicitly


def make_superuser():
    from apps.ops_console.tests.helpers import SUPERUSER, make_principal

    return make_principal(SUPERUSER)
