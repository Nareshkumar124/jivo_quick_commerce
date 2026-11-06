"""Slice 5.3 (T-514a): the delivery task end to end (08 T9, T10, T13, T14), the delivery OTP,
COD cash, geofences, refunds on failure, the store receiving returns, races, IDOR and
`GET /orders/{id}/track/`."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts.models import User
from apps.accounts.tests.factories import UserFactory
from apps.core.exceptions import ApiError
from apps.delivery import hooks
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryOffer, DeliveryTask, Rider, RiderCashLedger
from apps.delivery.services import dispatch
from apps.delivery.tests.factories import jpeg_upload
from apps.inventory.models import ReservationStatus, StockMovement, StockReservation, StoreInventory
from apps.orders.choices import OrderStatus, PaymentStatus
from apps.orders.models import Order, OrderStatusHistory
from apps.payments.models import Refund

pytestmark = pytest.mark.django_db

AT_STORE = {"lat": 28.4501, "lng": 77.0501, "accuracy": 8}
AT_DROP = {"lat": 28.4500, "lng": 77.0500, "accuracy": 8}  # the address pin is the store's point


class Flow:
    """One order taken by one rider through the API."""

    def __init__(self, order, rider, client, store_steps):
        self.order, self.rider, self.client, self.steps = order, rider, client, store_steps
        self.task_id = None

    def url(self, action: str) -> str:
        return f"/api/v1/rider/tasks/{self.task_id}/{action}/"

    def accept(self):
        dispatch.dispatch_order(self.order.pk)
        offer = DeliveryOffer.objects.get(task__order=self.order, status="PENDING")
        response = self.client.post(f"/api/v1/rider/offers/{offer.pk}/accept/")
        assert response.status_code == 200, response.json()
        self.task_id = response.json()["id"]
        return response.json()

    def at_store(self, **position):
        return self.client.post(self.url("arrived-store"), position or AT_STORE, format="json")

    def pickup(self, code=None):
        self.order.refresh_from_db()
        return self.client.post(
            self.url("pickup"), {"order_code": code or self.order.pickup_code}, format="json"
        )

    def at_customer(self, **body):
        return self.client.post(self.url("arrived-customer"), body or AT_DROP, format="json")

    def otp(self) -> str:
        from apps.delivery.services.tasks import delivery_otp

        task = DeliveryTask.objects.get(pk=self.task_id)
        self.order.refresh_from_db()
        return delivery_otp(task, self.order)

    def deliver(self, otp=None, cod="due"):
        body = {"otp": otp or self.otp()}
        self.order.refresh_from_db()
        if cod == "due":
            body["cod"] = {"mode": "cash", "amount": str(self.order.grand_total)}
        elif cod is not None:
            body["cod"] = cod
        return self.client.post(self.url("deliver"), body, format="json")

    def to_customer(self):
        self.accept()
        assert self.at_store().status_code == 200
        self.steps.pack(self.order)
        assert self.pickup().status_code == 200
        assert self.at_customer().status_code == 200


@pytest.fixture
def flow(place, make_rider, rider_client, store_steps):
    def make(method="COD", rider=None):
        order = place(method)
        store_steps.accept(order)
        rider = rider or make_rider()
        return Flow(order, rider, rider_client(rider), store_steps)

    return make


def stock_of(order):
    item = order.items.get()
    return StoreInventory.objects.get(store=order.store, variant=item.variant)


# --------------------------------------------------------------------------- arrived at store


def test_arrived_store_geofence(flow):
    f = flow()
    f.accept()
    far = f.at_store(lat=28.46, lng=77.05)
    assert far.status_code == 422
    assert far.json()["error"]["details"]["radius_m"] == 200
    assert far.json()["error"]["details"]["distance_m"] > 1000
    # Accuracy widens the fence by at most 50 m.
    edge = f.at_store(lat=28.45225, lng=77.05, accuracy=500)  # ~250 m
    assert edge.status_code == 200, edge.json()
    assert edge.json()["status"] == "AT_STORE"
    assert f.at_store().json()["status"] == "AT_STORE"  # idempotent


# --------------------------------------------------------------------------- pickup (T9)


def test_pickup_commits_stock_and_generates_the_otp(flow):
    f = flow()
    f.accept()
    f.at_store()
    stock = stock_of(f.order)
    on_hand, reserved = stock.on_hand, stock.reserved
    not_packed = f.pickup(code="ABCD")
    assert not_packed.status_code == 409
    assert not_packed.json()["error"]["details"]["order_status"] == "ACCEPTED"
    f.steps.pack(f.order)
    assert f.pickup(code="ZZZZ").json()["error"]["code"] == "PICKUP_CODE_INVALID"
    response = f.pickup()
    assert response.status_code == 200, response.json()
    assert response.json()["status"] == "PICKED_UP"
    assert response.json()["order_status"] == "OUT_FOR_DELIVERY"
    stock.refresh_from_db()
    assert stock.on_hand == on_hand - 2
    assert stock.reserved == reserved - 2
    movement = StockMovement.objects.get(order=f.order, type="SALE")
    assert (movement.delta, movement.on_hand_after) == (-2, stock.on_hand)
    assert StockReservation.objects.get(order=f.order).status == ReservationStatus.COMMITTED
    otp = f.otp()
    assert otp
    assert len(otp) == 4
    assert otp.isdigit()
    history = OrderStatusHistory.objects.filter(order=f.order).latest("id")
    assert (history.to_status, history.actor_type) == ("OUT_FOR_DELIVERY", "rider")
    # A repeated pickup changes nothing (no second SALE).
    assert f.pickup().status_code == 200
    assert StockMovement.objects.filter(order=f.order, type="SALE").count() == 1


def test_pickup_with_the_bag_qr(flow):
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    f.order.refresh_from_db()
    wrong_order = f.pickup(code=f"JQC1:JV-000000-000000:{f.order.pickup_code}")
    assert wrong_order.json()["error"]["code"] == "PICKUP_CODE_INVALID"
    qr = f"jqc1:{f.order.order_number}:{f.order.pickup_code.lower()}"
    assert f.pickup(code=qr).status_code == 200


def test_pickup_before_arriving_is_refused(flow):
    f = flow()
    f.accept()
    f.steps.pack(f.order)
    response = f.pickup()
    assert response.status_code == 409
    assert response.json()["error"]["details"]["status"] == "ASSIGNED"


# --------------------------------------------------------------------------- customer


def test_arrived_customer_geofence_and_override(flow, monkeypatch):
    pushes = []
    monkeypatch.setattr(hooks, "send_push", lambda user, event, data: pushes.append(event))
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    assert f.at_customer(lat=28.46, lng=77.05).status_code == 422
    response = f.at_customer(lat=28.46, lng=77.05, override_reason="Gate closed, at gate 2")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "AT_CUSTOMER"
    assert body["not_reachable_after"] is not None
    task = DeliveryTask.objects.get(pk=f.task_id)
    assert task.arrival_override_reason == "Gate closed, at gate 2"


# --------------------------------------------------------------------------- deliver (T10)


def test_deliver_cod_cash(flow, django_capture_on_commit_callbacks):
    f = flow()
    f.to_customer()
    with django_capture_on_commit_callbacks(execute=True):
        response = f.deliver()
    assert response.status_code == 200, response.json()
    assert response.json()["status"] == "DELIVERED"
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.DELIVERED
    assert f.order.payment_status == PaymentStatus.COD_COLLECTED
    entry = RiderCashLedger.objects.get(order=f.order)
    assert entry.amount == f.order.grand_total == entry.balance_after
    f.rider.refresh_from_db()
    assert f.rider.cash_in_hand == f.order.grand_total
    task = DeliveryTask.objects.get(pk=f.task_id)
    assert task.ended_at is not None
    # The rider is free; the ended task shows as recent_task.
    current = f.client.get("/api/v1/rider/tasks/current/").json()
    assert current["task"] is None
    assert current["recent_task"]["status"] == "DELIVERED"
    # The invoice was generated on DELIVERED.
    assert hasattr(Order.objects.get(pk=f.order.pk), "invoice")


def test_deliver_prepaid(flow):
    f = flow("ONLINE")
    f.to_customer()
    assert f.deliver(cod={"mode": "cash", "amount": "1.00"}).status_code == 400  # prepaid
    response = f.deliver(cod=None)
    assert response.status_code == 200
    f.order.refresh_from_db()
    assert f.order.payment_status == PaymentStatus.PAID
    assert not RiderCashLedger.objects.exists()


def test_cod_mismatch_uses_no_otp_attempt(flow):
    f = flow()
    f.to_customer()
    wrong = f.deliver(cod={"mode": "cash", "amount": "1.00"})
    assert wrong.status_code == 400
    assert wrong.json()["error"]["details"]["amount_due"] == str(f.order.grand_total)
    assert f.deliver(cod=None).status_code == 400  # COD needs the collection
    upi = f.deliver(cod={"mode": "upi", "amount": str(f.order.grand_total)})
    assert upi.status_code == 400  # the UPI QR is slice 5.4: never confirmed yet
    assert DeliveryTask.objects.get(pk=f.task_id).otp_attempts == 0


def test_wrong_otp_counts_and_locks(flow, monkeypatch):
    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    f = flow()
    f.to_customer()
    right = f.otp()
    wrong = "0000" if right != "0000" else "1111"
    for remaining in (4, 3, 2, 1):
        response = f.deliver(otp=wrong)
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "DELIVERY_OTP_INVALID"
        assert response.json()["error"]["details"] == {"attempts_remaining": remaining}
    locked = f.deliver(otp=wrong)
    assert locked.status_code == 423
    assert locked.json()["error"]["details"] == {"attempts_remaining": 0}
    assert alerts == ["DELIVERY_OTP_LOCKED"]
    # Locked: even the right OTP (and any COD path) is refused; the rider cannot reset it.
    assert f.deliver(otp=right).status_code == 423
    task = f.client.get("/api/v1/rider/tasks/current/").json()["task"]
    assert task["delivery_otp"] == {"length": 4, "attempts_remaining": 0, "locked": True}
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.OUT_FOR_DELIVERY


def test_deliver_before_arriving_is_refused(flow):
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    response = f.deliver()
    assert response.status_code == 409
    assert response.json()["error"]["details"]["status"] == "PICKED_UP"


# --------------------------------------------------------------------------- fail (T13) / T14


def test_fail_not_reachable_needs_the_wait(flow):
    f = flow()
    f.to_customer()
    body = {"reason": "CUSTOMER_NOT_REACHABLE", "call_attempts": 2}
    early = f.client.post(f.url("fail"), body, format="multipart")
    assert early.status_code == 409
    assert early.json()["error"]["details"]["reason"] == "WAIT_NOT_ELAPSED"
    with freeze_time(timezone.now() + timedelta(minutes=11)):
        late = f.client.post(f.url("fail"), body, format="multipart")
    # The 15-minute access token is still valid 11 minutes later.
    assert late.status_code == 200, late.json()
    assert late.json()["status"] == "RETURNING"
    assert late.json()["fail_reason"] == "CUSTOMER_NOT_REACHABLE"
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.DELIVERY_FAILED
    assert f.order.payment_status == PaymentStatus.FAILED  # COD: nothing due


def test_fail_online_refund_keeps_the_delivery_fee_on_customer_fault(flow, settings):
    settings.REFUND_KEEP_DELIVERY_FEE_ON_CUSTOMER_FAULT = True
    f = flow("ONLINE")
    f.to_customer()
    response = f.client.post(
        f.url("fail"), {"reason": "CUSTOMER_REFUSED", "photo": jpeg_upload()}, format="multipart"
    )
    assert response.status_code == 200, response.json()
    f.order.refresh_from_db()
    refund = Refund.objects.get(payment__order=f.order)
    assert refund.amount == f.order.grand_total - f.order.delivery_fee
    assert DeliveryTask.objects.get(pk=f.task_id).fail_photo


def test_fail_online_full_refund_when_not_the_customers_fault(flow):
    f = flow("ONLINE")
    f.to_customer()
    f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart")
    f.order.refresh_from_db()
    assert Refund.objects.get(payment__order=f.order).amount == f.order.grand_total


def test_repeated_cod_refusals_block_cod(flow, make_rider, settings):
    settings.COD_BLOCK_AFTER_REFUSALS = 2
    first = flow()
    first.to_customer()
    first.client.post(first.url("fail"), {"reason": "CUSTOMER_REFUSED"}, format="multipart")
    customer = User.objects.get(pk=first.order.user_id)
    assert customer.cod_blocked is False
    second = flow(rider=make_rider())
    second.to_customer()
    second.client.post(second.url("fail"), {"reason": "CUSTOMER_REFUSED"}, format="multipart")
    customer.refresh_from_db()
    assert customer.cod_blocked is True


def test_fail_before_pickup_is_refused(flow):
    f = flow()
    f.accept()
    response = f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart")
    assert response.status_code == 409


def test_store_receives_the_return(flow, admin):
    from apps.orders import store_ops

    f = flow()
    f.to_customer()
    stock = stock_of(f.order)
    after_sale = stock.on_hand
    f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart")
    item = f.order.items.get()
    with pytest.raises(ValidationError):
        store_ops.receive_return(f.order.pk, by=admin, damaged={item.pk: 5})  # only 2 units
    with pytest.raises(ValidationError):
        store_ops.receive_return(f.order.pk, by=admin, damaged={999999: 1})
    store_ops.receive_return(f.order.pk, by=admin, damaged={item.pk: 1})
    stock.refresh_from_db()
    assert stock.on_hand == after_sale + 1  # one good unit back; the damaged one recorded
    kinds = list(
        StockMovement.objects.filter(order=f.order).order_by("id").values_list("type", "delta")
    )
    assert kinds == [("SALE", -2), ("RETURN", 2), ("DAMAGE", -1)]
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.RETURNED
    task = DeliveryTask.objects.get(pk=f.task_id)
    assert task.status == TS.RETURNED
    assert task.ended_at is not None
    assert f.client.get("/api/v1/rider/tasks/current/").json()["task"] is None
    with pytest.raises(ApiError):
        store_ops.receive_return(f.order.pk, by=admin)  # only once


def test_return_needs_a_failed_delivery(flow, admin):
    from apps.orders import store_ops

    f = flow()
    with pytest.raises(ApiError):
        store_ops.receive_return(f.order.pk, by=admin)


# --------------------------------------------------------------------------- races & cancel


def test_cancel_frees_an_assigned_rider(
    flow, admin, monkeypatch, django_capture_on_commit_callbacks
):
    from apps.orders import store_ops

    pushes = []
    monkeypatch.setattr(hooks, "send_push", lambda user, event, data: pushes.append(event))
    f = flow()
    f.accept()
    f.at_store()
    with django_capture_on_commit_callbacks(execute=True):
        store_ops.cancel_by_staff(f.order.pk, by=admin, reason="CUSTOMER_REQUEST")
    assert "rider.task_cancelled" in pushes
    current = f.client.get("/api/v1/rider/tasks/current/").json()
    assert current["task"] is None
    assert current["recent_task"]["status"] == "CANCELLED"
    # The cancelled task's actions are refused (deliver vs cancel race: cancel won).
    response = f.pickup()
    assert response.status_code == 409
    assert response.json()["error"]["details"]["status"] == "CANCELLED"


def test_deliver_vs_cancel_after_pickup(flow, admin):
    """After pickup the order can no longer be cancelled (08 §7, T12 only before pickup)."""
    from apps.orders import store_ops

    f = flow()
    f.to_customer()
    with pytest.raises(ApiError):
        store_ops.cancel_by_staff(f.order.pk, by=admin, reason="CUSTOMER_REQUEST")
    assert f.deliver().status_code == 200


def test_one_active_task_per_rider(place, store_steps, make_rider, rider_client):
    rider = make_rider()
    first, second = place(), place()
    store_steps.accept(first)
    store_steps.accept(second)
    dispatch.dispatch_order(first.pk)
    offer = DeliveryOffer.objects.get(task__order=first)
    rider_client(rider).post(f"/api/v1/rider/offers/{offer.pk}/accept/")
    # Busy riders are not offered anything else.
    assert dispatch.dispatch_order(second.pk) == "no_candidate"


# --------------------------------------------------------------------------- IDOR


def test_task_idor(flow, make_rider, rider_client):
    f = flow()
    f.accept()
    other = rider_client(make_rider((28.46, 77.05)))
    for action in ("arrived-store", "pickup", "arrived-customer", "deliver"):
        response = other.post(
            f.url(action),
            {"lat": 28.45, "lng": 77.05, "order_code": "ABCD", "otp": "1234"},
            format="json",
        )
        assert response.status_code == 404, action
    assert (
        other.post(f.url("fail"), {"reason": "OTHER", "note": "x"}, format="multipart").status_code
        == 404
    )
    assert other.get("/api/v1/rider/tasks/current/").json()["task"] is None


# --------------------------------------------------------------------------- track


def test_track_shows_the_rider_and_the_otp_only_out_for_delivery(flow, make_auth_client):
    f = flow()
    customer = make_auth_client(User.objects.get(pk=f.order.user_id))
    url = f"/api/v1/orders/{f.order.pk}/track/"
    assert customer.get(url).json()["rider"] is None  # no rider yet
    f.accept()
    body = customer.get(url).json()
    assert body["rider"]["name"]
    assert body["rider"]["phone"] is None
    assert body["delivery_otp"] is None
    assert body["rider"]["lat"] == pytest.approx(28.45)
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    body = customer.get(url).json()
    assert body["rider"]["phone"] == f.rider.user.phone
    assert body["delivery_otp"] == f.otp()
    # Another customer never sees it (IDOR).
    assert make_auth_client(UserFactory()).get(url).status_code == 404
    f.at_customer()
    f.deliver()
    body = customer.get(url).json()
    assert body["rider"] is None
    assert body["delivery_otp"] is None


def test_track_task_status(flow, make_auth_client):
    """Customer track `task_status` (api-requests, customer app): null with no task, then the
    task's status through to DELIVERED; scoped to the order's owner (another customer: 404)."""
    f = flow()
    customer = make_auth_client(User.objects.get(pk=f.order.user_id))
    url = f"/api/v1/orders/{f.order.pk}/track/"
    DeliveryTask.objects.filter(order=f.order).delete()
    assert customer.get(url).json()["task_status"] is None
    f.accept()
    assert customer.get(url).json()["task_status"] == "ASSIGNED"
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    assert customer.get(url).json()["task_status"] == "PICKED_UP"
    f.at_customer()
    assert customer.get(url).json()["task_status"] == "AT_CUSTOMER"
    assert f.deliver().status_code == 200
    assert customer.get(url).json()["task_status"] == "DELIVERED"
    assert make_auth_client(UserFactory()).get(url).status_code == 404


# --------------------------------------------------------------------------- location link


def test_locations_are_linked_to_the_active_task(flow, monkeypatch):
    from apps.delivery.models import RiderLocation

    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    f = flow()
    f.accept()
    point = {
        "lat": 28.4502,
        "lng": 77.0502,
        "accuracy": 5,
        "recorded_at": timezone.now().isoformat(),
        "is_mocked": True,
    }
    response = f.client.post("/api/v1/rider/locations/", {"points": [point]}, format="json")
    assert response.status_code == 200, response.json()
    location = RiderLocation.objects.get(rider=f.rider)
    assert location.task_id == f.task_id
    assert location.is_mocked
    assert alerts == ["MOCKED_LOCATION"]
    heartbeat = f.client.post("/api/v1/rider/heartbeat/").json()
    assert heartbeat["active_task_id"] == f.task_id
    # Busy: going offline is refused.
    assert f.client.post("/api/v1/rider/shift/end/").status_code == 409


def test_cash_in_hand_blocks_cod_offers_after_collection(flow, settings):
    f = flow()
    f.to_customer()
    f.deliver()
    Rider.objects.filter(pk=f.rider.pk).update(cash_limit=Decimal("100.00"))
    me = f.client.get("/api/v1/rider/me/").json()
    assert me["cash"]["limit_reached"] is True
