"""DL-61 (user decisions, 2026-11-05) in slice 5.4:
(a) ops delivery actions: Super Admin, Ops, Store Manager own store; Finance also records cash
    deposits; Support (and Store Staff) none;
(b) COD offers only within the cash limit, a "deposit cash" flag for the rider, no ops override;
(c) the per-delivery fee is earned at pickup, also for failed/returned deliveries; nothing before;
(d) 2 refused COD deliveries block COD; ops can lift it.

Provisional backend IDs P5-TC-70 to P5-TC-75."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError

from apps.accounts import roles
from apps.accounts.models import User
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.exceptions import ApiError
from apps.delivery.choices import EarningType
from apps.delivery.models import DeliveryTask, Rider, RiderEarning
from apps.delivery.services import cash, dispatch, kyc, ops, shifts
from apps.delivery.tests.test_task_flow import Flow
from apps.orders import store_ops
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

ME = "/api/v1/rider/me/"


@pytest.fixture(autouse=True)
def _roles():
    roles.sync_roles()


def staff(role, *stores):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    for store in stores:
        grant_store_access(user, store)
    return user


@pytest.fixture
def flow(place, make_rider, rider_client, store_steps):
    def make(method="COD", rider=None):
        order = place(method)
        store_steps.accept(order)
        rider = rider or make_rider()
        return Flow(order, rider, rider_client(rider), store_steps)

    return make


# --------------------------------------------------------------------------- (c) earnings


def test_fee_is_earned_at_pickup_and_kept_on_failure(flow, admin):
    """P5-TC-70: nothing before pickup; BASE + DISTANCE at pickup; a failed then returned
    delivery keeps them (no tip); the history shows the payout."""
    f = flow("ONLINE")
    f.accept()
    f.at_store()
    assert not RiderEarning.objects.filter(task_id=f.task_id).exists()  # nothing before pickup
    f.steps.pack(f.order)
    assert f.pickup().status_code == 200
    types = set(RiderEarning.objects.filter(task_id=f.task_id).values_list("type", flat=True))
    assert EarningType.BASE in types
    assert EarningType.TIP not in types
    assert f.client.get("/api/v1/rider/tasks/current/").json()["task"]["earnings"]["total"]
    assert f.at_customer().status_code == 200
    response = f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart")
    assert response.status_code == 200, response.json()
    store_ops.receive_return(f.order.pk, by=admin)
    item = f.client.get("/api/v1/rider/tasks/history/").json()["results"][0]
    assert item["status"] == "RETURNED"
    assert Decimal(item["payout"]) >= Decimal("30.00")
    summary = f.client.get("/api/v1/rider/earnings/").json()
    assert summary["orders_count"] == 0  # delivered orders
    assert summary["orders"][0]["task_id"] == f.task_id  # but the pay is listed


# --------------------------------------------------------------------------- (b) cash limit


def test_deposit_required_flag_when_skipped_for_cash(flow, make_rider, shop):
    """P5-TC-71: a rider left out of a COD offer for cash gets `deposit_required` (even below
    the limit); prepaid still offered; a deposit clears it; ops cannot override (422)."""
    rider = make_rider()
    Rider.objects.filter(pk=rider.pk).update(
        cash_in_hand=Decimal("4900.00"), cash_limit=Decimal("5000.00")
    )
    cod = flow(rider=rider)
    dispatch.dispatch_order(cod.order.pk)
    assert not cod.order.delivery_task.offers.filter(rider=rider).exists()
    me = cod.client.get(ME).json()["cash"]
    assert me["limit_reached"] is False
    assert me["deposit_required"] is True
    with pytest.raises(ApiError) as exc:
        dispatch.manual_assign(cod.order.pk, rider.pk, by=staff(roles.OPS))
    assert exc.value.error_code == "CASH_LIMIT_EXCEEDED"
    cash.record_deposit(rider.pk, "1000.00", by=staff(roles.STORE_MANAGER, shop.store_model))
    assert cod.client.get(ME).json()["cash"]["deposit_required"] is False


# --------------------------------------------------------------------------- (a) permissions


def test_ops_rider_actions_role_matrix(make_rider, shop):
    """P5-TC-72: force offline and set cash limit: Super Admin, Ops, Store Manager of the
    rider's home store; another store's manager: not found; Support, Finance, Store Staff: no."""
    rider = make_rider()
    mine = staff(roles.STORE_MANAGER, shop.store_model)
    for role in (roles.SUPPORT, roles.FINANCE, roles.STORE_STAFF):
        user = staff(role, shop.store_model)
        with pytest.raises(PermissionDenied):
            shifts.force_offline(rider.pk, by=user)
        with pytest.raises(PermissionDenied):
            kyc.set_cash_limit(rider.pk, "100.00", by=user)
    other = staff(roles.STORE_MANAGER, DarkStoreFactory())
    with pytest.raises(ValidationError):
        shifts.force_offline(rider.pk, by=other)
    with pytest.raises(ValidationError):
        kyc.set_cash_limit(rider.pk, "100.00", by=other)
    assert kyc.set_cash_limit(rider.pk, "3000.00", by=mine).cash_limit == Decimal("3000.00")
    assert shifts.force_offline(rider.pk, by=mine).is_online is False
    assert kyc.set_cash_limit(rider.pk, "4000.00", by=staff(roles.OPS)).cash_limit == Decimal(
        "4000.00"
    )


def test_receive_return_role_matrix(flow, shop):
    """P5-TC-73: receive return: Store Manager own store (Ops, Super Admin); not Store Staff,
    Support or another store's manager."""
    f = flow()
    f.to_customer()
    response = f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart")
    assert response.status_code == 200, response.json()
    for user in (staff(roles.STORE_STAFF, shop.store_model), staff(roles.SUPPORT)):
        with pytest.raises(PermissionDenied):
            store_ops.receive_return(f.order.pk, by=user)
    with pytest.raises(ValidationError):
        store_ops.receive_return(f.order.pk, by=staff(roles.STORE_MANAGER, DarkStoreFactory()))
    store_ops.receive_return(f.order.pk, by=staff(roles.STORE_MANAGER, shop.store_model))
    assert DeliveryTask.objects.get(pk=f.task_id).status == "RETURNED"


def test_ops_delivery_actions_refused_to_support(flow):
    f = flow()
    f.to_customer()
    support = staff(roles.SUPPORT)
    for action in (
        lambda: ops.unlock_delivery_otp(f.order.pk, by=support),
        lambda: ops.fail_delivery(f.order.pk, reason="OTHER", note="x", by=support),
        lambda: ops.confirm_delivery(f.order.pk, otp="1234", cod_mode="cash", by=support),
        lambda: dispatch.retry_dispatch(f.order.pk, by=support),
        lambda: cash.record_deposit(f.rider.pk, "1", by=support),
    ):
        with pytest.raises(PermissionDenied):
            action()


# --------------------------------------------------------------------------- (d) COD block


def test_cod_block_after_two_refusals_and_ops_lift(flow, make_rider, user):
    """P5-TC-74: two refused COD deliveries block COD (online only); Store Manager cannot lift;
    Ops lifts it; afterwards one more refusal does not re-block (the count restarts)."""

    def refuse(lat):
        f = flow(rider=make_rider((lat, 77.05)))
        f.to_customer()
        response = f.client.post(f.url("fail"), {"reason": "CUSTOMER_REFUSED"}, format="multipart")
        assert response.status_code == 200, response.json()

    refuse(28.4501)
    assert User.objects.get(pk=user.pk).cod_blocked is False
    refuse(28.4502)
    assert User.objects.get(pk=user.pk).cod_blocked is True
    with pytest.raises(PermissionDenied):
        ops.lift_cod_block(user.pk, by=staff(roles.STORE_MANAGER))
    ops_user = staff(roles.OPS)
    assert ops.lift_cod_block(user.pk, by=ops_user) is True
    assert ops.lift_cod_block(user.pk, by=ops_user) is False  # nothing to lift
    with pytest.raises(ValidationError):
        ops.lift_cod_block(ops_user.pk, by=ops_user)  # staff, not a customer
    refuse(28.4503)
    assert User.objects.get(pk=user.pk).cod_blocked is False
    refuse(28.4504)
    assert User.objects.get(pk=user.pk).cod_blocked is True
