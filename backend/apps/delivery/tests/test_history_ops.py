"""Slice 5.4 (T-514b): the rider's task history (04 §2.8, #22/#24) and the ops delivery actions
(05 §1.4): unlock pickup / delivery OTP, ops-verified delivery, ops-marked T13, the rider board
and manual-dispatch candidates. Role matrix and store scope per 05 §3 ("Manual dispatch").

Test case IDs are provisional backend IDs (P5-TC-63 to P5-TC-69)."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.models import AuditLog
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryTask, RiderCashLedger, RiderEarning
from apps.delivery.services import ops
from apps.delivery.tests.test_task_flow import Flow
from apps.orders.choices import OrderStatus, PaymentStatus
from apps.orders.models import OrderStatusHistory
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HISTORY = "/api/v1/rider/tasks/history/"


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


def offline(rider) -> None:
    from apps.delivery.models import Rider

    Rider.objects.filter(pk=rider.pk).update(is_online=False)


@pytest.fixture
def manager(shop):
    return staff(roles.STORE_MANAGER, shop.store_model)


# --------------------------------------------------------------------------- history


def test_history_list_paging_filter_and_scope(flow, make_rider, rider_client, admin):
    """P5-TC-63: ended tasks only, newest first, `before_id` paging, `from`/`to` on the IST end
    day; CANCELLED before pickup has null distance and payout; another rider sees none."""
    from apps.orders import store_ops

    rider = make_rider()
    done = flow(rider=rider)
    done.to_customer()
    assert done.deliver().status_code == 200
    cancelled = flow(rider=rider)
    cancelled.accept()
    store_ops.cancel_by_staff(cancelled.order.pk, by=admin, reason="CUSTOMER_REQUEST")
    active = flow(rider=rider)
    active.accept()

    page = done.client.get(HISTORY, {"page_size": 1}).json()
    assert page["count"] == 2
    first = page["results"][0]
    assert first["task_id"] == cancelled.task_id
    assert first["status"] == "CANCELLED"
    assert first["distance_km"] is None
    assert first["payout"] is None
    older = done.client.get(page["next"]).json()["results"][0]
    assert older["task_id"] == done.task_id
    assert older["status"] == "DELIVERED"
    assert Decimal(older["payout"]) > 0
    assert older["distance_km"] is not None

    today = timezone.localdate().isoformat()
    assert done.client.get(HISTORY, {"from": today, "to": today}).json()["count"] == 2
    assert done.client.get(HISTORY, {"from": "2026-01-01", "to": "2026-01-02"}).json()["count"] == 0
    assert done.client.get(HISTORY, {"to": "2026-01-02"}).json()["count"] == 0
    bad = done.client.get(HISTORY, {"from": "2026-01-02", "to": "2026-01-01"})
    assert bad.status_code == 400

    other = rider_client(make_rider((28.4510, 77.05)))
    assert other.get(HISTORY).json()["count"] == 0


def test_history_detail_scope_and_privacy(flow, make_rider, rider_client):
    """P5-TC-64: the detail of an ended task of the caller; another rider's (IDOR) or a still
    active task is 404; no customer name, phone or address in it."""
    done = flow()
    done.to_customer()
    assert done.deliver().status_code == 200
    url = f"{HISTORY}{done.task_id}/"
    body = done.client.get(url).json()
    assert body["task_id"] == done.task_id
    assert body["payment_type"] == "COD"
    assert body["cod_collected"] == str(done.order.grand_total)
    assert body["earnings"]["lines"][0]["type"] == "BASE"
    assert body["item_count"] == 2
    text = str(body)
    snapshot = done.order.address_snapshot
    for secret in (
        snapshot.get("receiver_phone"),
        snapshot.get("receiver_name"),
        snapshot.get("house"),
    ):
        if secret:
            assert secret not in text
    other = rider_client(make_rider((28.4510, 77.05), online=False))
    assert other.get(url).status_code == 404
    offline(done.rider)
    active = flow(rider=make_rider((28.4502, 77.05)))
    active.accept()
    assert active.client.get(f"{HISTORY}{active.task_id}/").status_code == 404


# --------------------------------------------------------------------------- unlocks


def test_unlock_pickup(flow, manager, settings, monkeypatch, shop):
    """P5-TC-65: after the pickup lock (423) ops give new tries; role matrix and store scope."""
    from apps.delivery.throttling import RiderPickupThrottle

    monkeypatch.setattr(RiderPickupThrottle, "allow_request", lambda self, request, view: True)
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    for _ in range(settings.PICKUP_CODE_MAX_ATTEMPTS):
        f.pickup(code="ZZZZ")
    assert f.pickup().status_code == 423
    state = f.client.get("/api/v1/rider/tasks/current/").json()["task"]["pickup_code"]
    assert state == {"attempts_remaining": 0, "locked": True}
    with pytest.raises(PermissionDenied):
        ops.unlock_pickup(f.order.pk, by=staff(roles.STORE_STAFF, shop.store_model))
    with pytest.raises(ValidationError):
        ops.unlock_pickup(f.order.pk, by=staff(roles.STORE_MANAGER, DarkStoreFactory()))
    task = ops.unlock_pickup(f.order.pk, by=manager)
    assert task.pickup_locked_at is None
    assert task.pickup_attempts == 0
    state = f.client.get("/api/v1/rider/tasks/current/").json()["task"]["pickup_code"]
    assert state == {"attempts_remaining": settings.PICKUP_CODE_MAX_ATTEMPTS, "locked": False}
    assert AuditLog.objects.filter(action="delivery.unlock_pickup").exists()
    with pytest.raises(ValidationError, match="Nothing is locked"):
        ops.unlock_pickup(f.order.pk, by=manager)
    assert f.pickup().status_code == 200
    with pytest.raises(ValidationError):
        ops.unlock_pickup(f.order.pk, by=manager)  # no longer at the store


def test_unlock_delivery_otp(flow, manager):
    """P5-TC-66: after 5 wrong OTPs (423) ops unlock: 5 new tries with the same OTP."""
    f = flow()
    f.to_customer()
    for _ in range(5):
        f.deliver(otp="0000" if f.otp() != "0000" else "1111")
    assert f.deliver().status_code == 423
    task = ops.unlock_delivery_otp(f.order.pk, by=manager)
    assert task.otp_locked_at is None
    assert task.otp_attempts == 0
    with pytest.raises(ValidationError, match="Nothing is locked"):
        ops.unlock_delivery_otp(f.order.pk, by=manager)
    assert f.deliver().status_code == 200
    with pytest.raises(ValidationError):
        ops.unlock_delivery_otp(f.order.pk, by=manager)


# --------------------------------------------------------------------------- ops T10 / T13


def test_ops_confirm_delivery(flow, manager):
    """P5-TC-67: ops verify the OTP the customer reads to them: wrong is refused (audited);
    right completes T10 for the rider (cash in hand, earnings, actor ops)."""
    f = flow()
    f.to_customer()
    with pytest.raises(ValidationError):
        ops.confirm_delivery(f.order.pk, otp=f.otp(), by=manager)  # COD needs the mode
    with pytest.raises(ValidationError):
        ops.confirm_delivery(f.order.pk, otp=f.otp(), cod_mode="upi", by=manager)  # not paid
    wrong = "0000" if f.otp() != "0000" else "1111"
    with pytest.raises(ValidationError, match="does not match"):
        ops.confirm_delivery(f.order.pk, otp=wrong, cod_mode="cash", by=manager)
    assert AuditLog.objects.filter(action="delivery.ops_otp_wrong").exists()
    task = ops.confirm_delivery(f.order.pk, otp=f.otp(), cod_mode="cash", by=manager)
    assert task.status == TS.DELIVERED
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.DELIVERED
    assert f.order.payment_status == PaymentStatus.COD_COLLECTED
    assert RiderCashLedger.objects.get(rider=f.rider).amount == f.order.grand_total
    assert RiderEarning.objects.filter(task=task).exists()
    last = OrderStatusHistory.objects.filter(order=f.order).latest("pk")
    assert last.actor_type == "ops"
    with pytest.raises(ValidationError):
        ops.confirm_delivery(f.order.pk, otp=f.otp(), cod_mode="cash", by=manager)


def test_ops_confirm_prepaid_and_paid_qr(flow, manager, api_client):
    from apps.delivery.tests.test_cod_qr import pay

    prepaid = flow("ONLINE")
    prepaid.to_customer()
    otp = prepaid.otp()
    assert ops.confirm_delivery(prepaid.order.pk, otp=otp, by=manager).status == TS.DELIVERED
    offline(prepaid.rider)
    cod = flow()
    cod.to_customer()
    qr = cod.client.post(cod.url("cod-qr")).json()
    pay(api_client, qr)
    with pytest.raises(ValidationError, match="already paid by UPI"):
        ops.confirm_delivery(cod.order.pk, otp=cod.otp(), cod_mode="cash", by=manager)
    task = ops.confirm_delivery(cod.order.pk, otp=cod.otp(), cod_mode="upi", by=manager)
    assert task.status == TS.DELIVERED
    assert not RiderCashLedger.objects.filter(rider=cod.rider).exists()


def test_ops_fail_delivery(flow, manager, shop):
    """P5-TC-68: ops mark T13 without the rider's 10-minute wait; a note is required; refunds
    as for the rider (ONLINE WRONG_ADDRESS: full); audited; store scope."""
    f = flow("ONLINE")
    f.to_customer()
    with pytest.raises(ValidationError):
        ops.fail_delivery(f.order.pk, reason="WRONG_ADDRESS", note=" ", by=manager)
    with pytest.raises(ValidationError):
        ops.fail_delivery(f.order.pk, reason="BORED", note="x", by=manager)
    with pytest.raises(PermissionDenied):
        ops.fail_delivery(
            f.order.pk,
            reason="WRONG_ADDRESS",
            note="x",
            by=staff(roles.FINANCE),
        )
    task = ops.fail_delivery(
        f.order.pk, reason="CUSTOMER_NOT_REACHABLE", note="Called 3 times", by=manager
    )
    assert task.status == TS.RETURNING
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.DELIVERY_FAILED
    assert f.order.refunds.exists()
    assert AuditLog.objects.filter(action="delivery.ops_fail_delivery").exists()
    with pytest.raises(ValidationError):
        ops.fail_delivery(f.order.pk, reason="OTHER", note="again", by=manager)


# --------------------------------------------------------------------------- read side


def test_rider_board_and_assignable_riders(flow, manager, make_rider, shop):
    """P5-TC-69: 05 §1.4 board: states, cash, last ping age, current task; scoped to the
    user's stores; manual-dispatch candidates nearest first with the COD cash check."""
    busy = flow()
    busy.accept()
    idle = make_rider((28.4520, 77.05))
    board = {row["rider_id"]: row for row in ops.rider_board(manager)}
    assert board[busy.rider.pk]["state"] == "to_store"
    assert board[busy.rider.pk]["task"]["order_number"] == busy.order.order_number
    assert board[idle.pk]["state"] == "idle"
    assert board[idle.pk]["last_ping_age_seconds"] is not None
    assert ops.rider_board(manager, store_id=DarkStoreFactory().pk) == []
    assert ops.rider_board(staff(roles.STORE_MANAGER, DarkStoreFactory())) == []
    with pytest.raises(PermissionDenied):
        ops.rider_board(staff(roles.FINANCE))

    waiting = flow(rider=idle)
    candidates = ops.assignable_riders(waiting.order.pk, by=manager)
    assert [row["rider_id"] for row in candidates] == [idle.pk]
    assert candidates[0]["within_cash_limit"] is True
    with pytest.raises(ValidationError):
        ops.assignable_riders(waiting.order.pk, by=staff(roles.STORE_MANAGER, DarkStoreFactory()))
    with pytest.raises(PermissionDenied):
        ops.assignable_riders(waiting.order.pk, by=staff(roles.FINANCE))


def test_task_state_mapping():
    class R:
        is_online = False

    assert ops._state(R(), None) == "offline"
    for status, state in (
        (TS.AT_STORE, "at_store"),
        (TS.PICKED_UP, "delivering"),
        (TS.RETURNING, "returning"),
    ):
        assert ops._state(R(), DeliveryTask(status=status)) == state
