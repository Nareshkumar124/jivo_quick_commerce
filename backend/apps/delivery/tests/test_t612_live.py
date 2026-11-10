# ruff: noqa: F811 - the `flow` fixture is imported from test_task_flow
"""T-612: delivery -> sockets. Rider location fan-out behind the tracking gate, the live ETA
(08 §8) on status changes, location updates and `track/`, the rider socket events
(`offer.new` / `offer.expired` / `offer.withdrawn` / `task.updated` / `cash.updated`) with their
FCM data pushes, and the store-scoped dispatch events on `/ws/ops/live/` (`task.status`,
`rider.status`).

Channel-layer sends are recorded (`apps.realtime.services.send_now`); every payload is validated
against its `Ws...` component. Real sockets: test_t612_sockets.py."""

from datetime import timedelta
from decimal import Decimal
from types import SimpleNamespace

import jsonschema
import pytest
from django.contrib.gis.geos import Point
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.delivery import hooks
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryOffer, DeliveryTask, Rider
from apps.delivery.services import cash, dispatch, eta, ops, shifts
from apps.delivery.tests.test_task_flow import AT_DROP, flow  # noqa: F401
from apps.orders.choices import OrderStatus
from apps.realtime import services
from apps.realtime.groups import order_group, rider_group, store_group
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db

# Which component validates a message of each type, per audience.
COMPONENT = {
    ("rider", "offer.new"): "WsOfferNewMessage",
    ("rider", "offer.expired"): "WsOfferExpiredMessage",
    ("rider", "offer.withdrawn"): "WsOfferWithdrawnMessage",
    ("rider", "task.updated"): "WsTaskUpdatedMessage",
    ("rider", "cash.updated"): "WsCashUpdatedMessage",
    ("ops", "task.status"): "WsOpsTaskStatusMessage",
    ("ops", "rider.status"): "WsRiderStatusMessage",
    ("ops", "rider.location"): "WsOpsRiderLocationMessage",
    ("ops", "order.status"): "WsOrderStatusMessage",
    ("ops", "order.created"): "WsOrderCreatedMessage",
    ("ops", "alert"): "WsAlertMessage",
    ("customer", "order.status"): "WsOrderStatusMessage",
    ("customer", "order.eta"): "WsOrderEtaMessage",
    ("customer", "rider.location"): "WsRiderLocationMessage",
    ("user", "notification.new"): "WsNotificationNewMessage",
}


@pytest.fixture(scope="module")
def components() -> dict:
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


class Sent:
    def __init__(self):
        self.items: list[tuple[list[str], dict]] = []

    def to(self, group: str, type_: str | None = None) -> list[dict]:
        return [
            body
            for groups, body in self.items
            if group in groups and (type_ is None or body["type"] == type_)
        ]

    def validate(self, components) -> None:
        """Every recorded message validates against its component (by audience)."""
        for groups, body in self.items:
            for group in groups:
                prefix = group.split(".")[0]
                audience = {"rider": "rider", "ops": "ops", "user": "user"}.get(prefix, "customer")
                name = COMPONENT[(audience, body["type"])]
                jsonschema.validate(
                    body, to_json_schema({"$ref": f"#/components/schemas/{name}"}, components)
                )


@pytest.fixture
def sent(monkeypatch):
    record = Sent()
    monkeypatch.setattr(
        services, "send_now", lambda groups, body: record.items.append((list(groups), body))
    )
    return record


@pytest.fixture
def pushes(monkeypatch):
    calls = []
    monkeypatch.setattr(
        hooks, "send_push", lambda user, event, data: calls.append((user.pk, event, dict(data)))
    )
    return calls


@pytest.fixture
def commit(django_capture_on_commit_callbacks):
    return lambda: django_capture_on_commit_callbacks(execute=True)


# --------------------------------------------------------------------------- ETA (08 §8)


def _order(status, *, accepted_minutes_ago=None, prep=10):
    now = timezone.now()
    store = SimpleNamespace(location=Point(77.05, 28.45, srid=4326), avg_prep_minutes=prep)
    return SimpleNamespace(
        status=status,
        store=store,
        delivery_location=Point(77.05, 28.4680, srid=4326),  # ~2 km north of the store
        accepted_at=now - timedelta(minutes=accepted_minutes_ago)
        if accepted_minutes_ago is not None
        else None,
        placed_at=now - timedelta(minutes=1),
    )


def test_eta_formula_follows_08_section_8(settings):
    """P6-TC: prep + rider to store + store to customer + buffer; straight line x 1.3 at
    20 km/h; at least 1 minute; none once the order ended."""
    settings.ETA_AVG_SPEED_KMPH = 20.0
    settings.ETA_ROAD_FACTOR = 1.3
    settings.ETA_BUFFER_MINUTES = 2
    settings.ETA_RIDER_WAIT_MINUTES = 3
    now = timezone.now()
    km = eta.haversine_km(28.45, 77.05, 28.468, 77.05)
    drive = km * 1.3 / 20 * 60  # ~7 min
    placed = _order(OrderStatus.PLACED)
    placed.placed_at = now  # prep not started
    # No rider yet: prep + typical wait + store->drop + buffer.
    assert eta.compute(placed, None, None, now=now).minutes == pytest.approx(
        10 + 3 + drive + 2, abs=1
    )
    # Prep partly done (accepted 4 min ago), rider ASSIGNED 1 km away from the store.
    accepted = _order(OrderStatus.PACKING, accepted_minutes_ago=4)
    task = SimpleNamespace(status=TS.ASSIGNED)
    rider_km = eta.haversine_km(28.459, 77.05, 28.45, 77.05) * 1.3 / 20 * 60
    got = eta.compute(accepted, task, (28.459, 77.05), now=now)
    assert got.minutes == pytest.approx(6 + rider_km + drive + 2, abs=1)
    assert got.eta_at == now + timedelta(minutes=got.minutes)
    # Rider at the store and the order packed: travel + buffer only.
    packed = _order(OrderStatus.PACKED)
    at_store = eta.compute(packed, SimpleNamespace(status=TS.AT_STORE), None, now=now)
    assert at_store.minutes == pytest.approx(drive + 2, abs=1)
    # Out for delivery: rider position -> drop + buffer.
    out = _order(OrderStatus.OUT_FOR_DELIVERY)
    halfway = eta.compute(out, SimpleNamespace(status=TS.PICKED_UP), (28.459, 77.05), now=now)
    assert halfway.minutes < at_store.minutes
    # At the door: the buffer only.
    door = eta.compute(out, SimpleNamespace(status=TS.AT_CUSTOMER), (28.468, 77.05), now=now)
    assert door.minutes == 2
    # No rider position while out: from the store.
    assert eta.compute(out, SimpleNamespace(status=TS.PICKED_UP), None, now=now).minutes == (
        at_store.minutes
    )
    for ended in (OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.PAYMENT_PENDING):
        assert eta.compute(_order(ended), None, None, now=now) is None


def test_prep_left_never_goes_below_zero():
    order = _order(OrderStatus.PACKING, accepted_minutes_ago=60)
    assert eta.prep_left_minutes(order, timezone.now()) == 0.0
    order = _order(OrderStatus.ACCEPTED)
    order.placed_at = None
    assert eta.prep_left_minutes(order, timezone.now()) == 10.0


def test_track_returns_the_live_eta(flow):
    """`GET /orders/{id}/track/` exposes `live_eta_at` / `live_eta_minutes`; null once ended."""
    f = flow()
    from apps.delivery.tests.test_task_flow import Flow  # noqa: F401

    url = f"/api/v1/orders/{f.order.pk}/track/"
    customer = f.order.user
    from rest_framework.test import APIClient

    from apps.accounts.services.auth import issue_tokens

    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(customer, 'customer')[0]}")
    before = client.get(url).json()
    assert isinstance(before["live_eta_minutes"], int)
    assert before["live_eta_minutes"] >= 1
    assert before["live_eta_at"]
    f.to_customer()
    assert f.deliver().status_code == 200
    after = client.get(url).json()
    assert after["live_eta_at"] is None
    assert after["live_eta_minutes"] is None
    assert eta.for_order_id(999_999) is None


# --------------------------------------------------------------------------- ops dispatch board


def test_dispatch_events_reach_the_store_ops_group(flow, sent, commit, components):
    """Task created (SEARCHING), offered, accepted (ASSIGNED): `task.status` to the order's
    store only, `rider.status` (on_task) for the rider, `order.eta` to the customer."""
    f = flow()
    store = store_group(f.order.store_id)
    with commit():
        dispatch.dispatch_order(f.order.pk)
    with commit():
        offer = DeliveryOffer.objects.get(task__order=f.order, status="PENDING")
        assert f.client.post(f"/api/v1/rider/offers/{offer.pk}/accept/").status_code == 200
    board = sent.to(store, "task.status")
    assert [(m["data"]["previous_status"], m["data"]["status"]) for m in board] == [
        (None, "SEARCHING"),
        (None, "OFFERED"),  # created and offered in one transaction: previous unknown
        ("OFFERED", "ASSIGNED"),
    ]
    assigned = board[-1]["data"]
    assert assigned["rider_id"] == f.rider.pk
    assert assigned["assignment_mode"] == "AUTO"
    assert assigned["order_number"] == f.order.order_number
    assert "customer" not in str(assigned).lower()
    status = sent.to(store, "rider.status")[-1]["data"]
    assert (status["rider_id"], status["on_task"], status["is_online"]) == (
        f.rider.pk,
        True,
        True,
    )
    assert sent.to(order_group(f.order.pk), "order.eta")
    # Store scoping: nothing about this task goes to any other store's group.
    assert all(
        g in (store, order_group(f.order.pk), rider_group(f.rider.pk))
        for groups, _ in sent.items
        for g in groups
    )
    sent.validate(components)


def test_task_failure_reaches_ops(flow, sent, commit, components):
    f = flow()
    f.to_customer()
    task = DeliveryTask.objects.get(pk=f.task_id)
    task.arrived_customer_at = timezone.now() - timedelta(hours=1)
    task.save(update_fields=["arrived_customer_at"])
    with commit():
        response = f.client.post(
            f.url("fail"), {"reason": "CUSTOMER_REFUSED", "note": "Refused"}, format="multipart"
        )
    assert response.status_code == 200, response.json()
    [failed] = sent.to(store_group(f.order.store_id), "task.status")
    assert (failed["data"]["previous_status"], failed["data"]["status"]) == (
        "AT_CUSTOMER",
        "RETURNING",
    )
    sent.validate(components)


def test_rider_online_and_offline_reach_ops(make_rider, rider_client, sent, commit, components):
    rider = make_rider(online=False)
    client = rider_client(rider)
    with commit():
        assert (
            client.post(
                "/api/v1/rider/shift/start/", {"lat": 28.4501, "lng": 77.0501}, format="json"
            ).status_code
            == 200
        )
    with commit():
        assert client.post("/api/v1/rider/shift/end/").status_code == 200
    statuses = [m["data"] for m in sent.to(store_group(rider.home_store_id), "rider.status")]
    assert [(s["is_online"], s["on_task"]) for s in statuses] == [(True, False), (False, False)]
    sent.validate(components)


def test_unchanged_task_saves_publish_nothing(flow, sent, commit):
    f = flow()
    with commit():
        dispatch.dispatch_order(f.order.pk)
    sent.items.clear()
    with commit():
        task = DeliveryTask.objects.get(order=f.order)
        task.payout_amount = Decimal("1.00")
        task.save()
    assert sent.items == []


def test_presence_and_eta_skip_unknown_ids(sent):
    assert services.send_rider_presence(999_999) is False
    assert services.send_cash_updated(999_999, "DEPOSIT") is False
    assert services.send_order_eta(999_999) is False
    with pytest.raises(ValueError, match="Unknown cash"):
        services.publish_cash_updated(1, reason="NOPE")
    assert sent.items == []


# --------------------------------------------------------------------------- rider events


def test_offer_new_reaches_only_the_offered_rider(flow, sent, pushes, commit, components):
    f = flow()
    with commit():
        dispatch.dispatch_order(f.order.pk)
    [offer] = sent.to(rider_group(f.rider.pk), "offer.new")
    assert offer["data"]["task_id"] == DeliveryTask.objects.get(order=f.order).pk
    assert [p[1] for p in pushes] == ["rider.offer_new"]
    sent.validate(components)


def test_offer_expiry_sends_offer_expired(flow, sent, pushes, commit, components):
    f = flow()
    dispatch.dispatch_order(f.order.pk)
    offer = DeliveryOffer.objects.get(task__order=f.order, status="PENDING")
    with commit():
        assert dispatch.expire_offer(offer.pk, now=offer.expires_at) == "expired"
    [expired] = sent.to(rider_group(f.rider.pk), "offer.expired")
    assert expired["data"] == {"offer_id": offer.pk, "task_id": offer.task_id, "reason": "EXPIRED"}
    assert sent.to(rider_group(f.rider.pk), "offer.withdrawn") == []
    push = next(p for p in pushes if p[1] == "rider.offer_expired")
    assert push[0] == f.rider.user_id
    assert push[2]["offer_id"] == offer.pk
    sent.validate(components)


def test_going_offline_withdraws_the_offer(flow, sent, pushes, commit, components):
    f = flow()
    dispatch.dispatch_order(f.order.pk)
    offer = DeliveryOffer.objects.get(task__order=f.order, status="PENDING")
    with commit():
        shifts.end_shift(f.rider.user)
    [withdrawn] = sent.to(rider_group(f.rider.pk), "offer.withdrawn")
    assert withdrawn["data"]["reason"] == "RIDER_OFFLINE"
    assert withdrawn["data"]["offer_id"] == offer.pk
    assert "rider.offer_withdrawn" in [p[1] for p in pushes]
    sent.validate(components)


def test_cancellation_withdraws_the_offer(flow, admin, sent, pushes, commit, components):
    from apps.orders import store_ops

    f = flow()
    dispatch.dispatch_order(f.order.pk)
    with commit():
        store_ops.cancel_by_staff(f.order.pk, by=admin, reason="CUSTOMER_REQUEST")
    [withdrawn] = sent.to(rider_group(f.rider.pk), "offer.withdrawn")
    assert withdrawn["data"]["reason"] == "ORDER_CANCELLED"
    sent.validate(components)


def test_cancellation_of_an_assigned_task(flow, admin, sent, pushes, commit, components):
    from apps.orders import store_ops

    f = flow()
    f.accept()
    with commit():
        store_ops.cancel_by_staff(f.order.pk, by=admin, reason="CUSTOMER_REQUEST")
    [updated] = sent.to(rider_group(f.rider.pk), "task.updated")
    assert updated["data"]["change"] == "ORDER_CANCELLED"
    assert updated["data"]["status"] == "CANCELLED"
    assert updated["data"]["order_status"] == "CANCELLED"
    assert "rider.task_cancelled" in [p[1] for p in pushes]
    # Ops: the task left the board, the rider is free again.
    board = sent.to(store_group(f.order.store_id), "task.status")
    assert board[-1]["data"]["status"] == "CANCELLED"
    assert sent.to(store_group(f.order.store_id), "rider.status")[-1]["data"]["on_task"] is False
    sent.validate(components)


def test_packed_order_updates_the_rider_task(flow, sent, pushes, commit, components):
    f = flow()
    f.accept()
    with commit():
        f.steps.pack(f.order)
    [updated] = sent.to(rider_group(f.rider.pk), "task.updated")
    assert updated["data"]["change"] == "ORDER_PACKED"
    assert updated["data"]["order_status"] == "PACKED"
    assert "rider.order_ready" in [p[1] for p in pushes]
    sent.validate(components)


def test_manual_assign_and_unassign(flow, make_rider, admin, sent, pushes, commit, components):
    f = flow()
    dispatch.dispatch_order(f.order.pk)  # offered to f.rider
    other = make_rider((28.4510, 77.05))
    with commit():
        dispatch.manual_assign(f.order.pk, other.pk, by=admin)
    [taken] = sent.to(rider_group(f.rider.pk), "offer.withdrawn")
    assert taken["data"]["reason"] == "TAKEN"
    [assigned] = sent.to(rider_group(other.pk), "task.updated")
    assert assigned["data"]["change"] == "ASSIGNED"
    assert "rider.task_assigned" in [p[1] for p in pushes]
    board = sent.to(store_group(f.order.store_id), "task.status")
    assert board[-1]["data"]["assignment_mode"] == "MANUAL"
    sent.items.clear()
    with commit():
        dispatch.unassign(f.order.pk, by=admin)
    [reassigned] = sent.to(rider_group(other.pk), "task.updated")
    assert reassigned["data"]["change"] == "REASSIGNED"
    assert reassigned["data"]["status"] == "SEARCHING"
    sent.validate(components)


def test_manual_assign_withdraws_the_riders_other_offer(
    flow, place, store_steps, make_rider, admin, sent, commit
):
    f = flow()
    dispatch.dispatch_order(f.order.pk)  # f.rider holds an offer for this order
    second = place()
    store_steps.accept(second)
    with commit():
        dispatch.manual_assign(second.pk, f.rider.pk, by=admin)
    reasons = [m["data"]["reason"] for m in sent.to(rider_group(f.rider.pk), "offer.withdrawn")]
    assert reasons == ["REASSIGNED"]


def test_ops_actions_update_the_rider(flow, admin, sent, pushes, commit, components):
    f = flow()
    f.to_customer()
    task = DeliveryTask.objects.get(pk=f.task_id)
    DeliveryTask.objects.filter(pk=task.pk).update(otp_attempts=2)
    with commit():
        ops.unlock_delivery_otp(f.order.pk, by=admin)
    with commit():
        ops.fail_delivery(f.order.pk, reason="CUSTOMER_REFUSED", note="Refused", by=admin)
    changes = [m["data"]["change"] for m in sent.to(rider_group(f.rider.pk), "task.updated")]
    assert changes == ["STATUS_CHANGED", "STATUS_CHANGED"]
    assert [p[1] for p in pushes if p[1].startswith("rider.t") or "return" in p[1]] == [
        "rider.task_updated",
        "rider.return_to_store",
    ]
    from apps.orders import store_ops

    sent.items.clear()
    with commit():
        store_ops.receive_return(f.order.pk, by=admin)
    [closed] = sent.to(rider_group(f.rider.pk), "task.updated")
    assert closed["data"]["status"] == "RETURNED"
    sent.validate(components)


def test_ops_confirm_delivery_updates_the_rider(flow, admin, sent, commit, components):
    f = flow(method="ONLINE")
    f.to_customer()
    with commit():
        ops.confirm_delivery(f.order.pk, otp=f.otp(), by=admin)
    [done] = sent.to(rider_group(f.rider.pk), "task.updated")
    assert (done["data"]["status"], done["data"]["order_status"]) == ("DELIVERED", "DELIVERED")
    sent.validate(components)


# --------------------------------------------------------------------------- cash.updated


def test_cash_updates_reach_the_rider(flow, admin, sent, pushes, commit, components):
    f = flow()
    f.to_customer()
    with commit():
        assert f.deliver().status_code == 200
    [collected] = sent.to(rider_group(f.rider.pk), "cash.updated")
    f.order.refresh_from_db()
    assert collected["data"]["reason"] == "COD_COLLECTED"
    assert collected["data"]["cash_in_hand"] == str(f.order.grand_total)
    assert "rider.cash_updated" not in [p[1] for p in pushes]  # the rider's own collection
    sent.items.clear()
    with commit():
        cash.record_deposit(
            f.rider.pk,
            f.order.grand_total,
            store_id=f.order.store_id,
            by=admin,
            idempotency_key="k1",
        )
    [deposit] = sent.to(rider_group(f.rider.pk), "cash.updated")
    assert deposit["data"]["reason"] == "DEPOSIT"
    assert deposit["data"]["cash_in_hand"] == "0.00"
    assert [p[1] for p in pushes].count("rider.cash_updated") == 1
    sent.validate(components)


def test_cash_limit_skip_sets_deposit_required(place, store_steps, make_rider, sent, commit):
    rider = make_rider()
    Rider.objects.filter(pk=rider.pk).update(
        cash_in_hand=Decimal("90.00"), cash_limit=Decimal("100.00")
    )
    order = place()
    store_steps.accept(order)
    with commit():
        dispatch.dispatch_order(order.pk)
    [flag] = sent.to(rider_group(rider.pk), "cash.updated")
    assert flag["data"]["reason"] == "DEPOSIT_REQUIRED"
    assert flag["data"]["deposit_required"] is True
    sent.items.clear()
    with commit():  # already flagged: no repeat
        DeliveryTask.objects.filter(order=order).update(next_dispatch_at=None)
        dispatch.dispatch_order(order.pk)
    assert sent.to(rider_group(rider.pk), "cash.updated") == []


# --------------------------------------------------------------------------- location fan-out


def test_location_fan_out_follows_the_tracking_gate(flow, sent, commit, components, settings):
    """Pings reach the customer only while the task is customer-visible (ASSIGNED ..
    AT_CUSTOMER), with `order.eta` while out for delivery; the latest point is in Redis."""
    settings.WS_ETA_MIN_INTERVAL_SECONDS = 1
    f = flow()

    def ping(lat=28.4502):
        point = {
            "lat": lat,
            "lng": 77.0503,
            "accuracy": 8.0,
            "recorded_at": timezone.now().isoformat(),
        }
        with commit():
            response = f.client.post("/api/v1/rider/locations/", {"points": [point]}, format="json")
        assert response.status_code in (200, 201), response.json()

    customer = order_group(f.order.pk)
    ping()  # online, no task: ops map only
    assert sent.to(customer) == []
    assert sent.to(store_group(f.rider.home_store_id), "rider.location")
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    assert f.pickup().status_code == 200
    from django.core.cache import cache

    cache.delete(f"ws:eta:{f.order.pk}")
    ping(28.4505)
    assert sent.to(customer, "rider.location")[-1]["data"]["lat"] == 28.4505
    assert sent.to(customer, "order.eta")
    rider = Rider.objects.get(pk=f.rider.pk)
    assert shifts.latest_location(rider)["lat"] == 28.4505  # Redis
    assert f.at_customer().status_code == 200
    assert f.deliver().status_code == 200
    sent.items.clear()
    ping(28.4507)  # still online after the delivery
    assert sent.to(customer) == []  # task DELIVERED: the gate is closed
    sent.validate(components)


def test_eta_from_location_only_while_out_for_delivery(flow, sent):
    f = flow()
    assert services.publish_eta_from_location(f.order.pk, 28.45, 77.05) is False
    assert sent.items == []


def test_order_eta_payload(flow, sent, components):
    f = flow()
    assert services.send_order_eta(f.order.pk) is True
    [message] = sent.to(order_group(f.order.pk), "order.eta")
    assert message["data"]["eta_minutes"] >= 1
    sent.validate(components)
    assert AT_DROP  # fixture module imported for `flow`


# --------------------------------------------------------------------------- review fixes


def _offered_task(f):
    dispatch.dispatch_order(f.order.pk)
    return DeliveryTask.objects.get(order=f.order)  # status OFFERED, snapshot from the DB


def test_refresh_from_db_refreshes_the_snapshot(flow, sent, commit):
    """Another process changed the task; after `refresh_from_db` the snapshot follows the DB:
    re-saving the DB state publishes nothing, a real change still publishes."""
    f = flow()
    task = _offered_task(f)
    DeliveryTask.objects.filter(pk=task.pk).update(status=TS.SEARCHING)
    task.refresh_from_db()
    with commit():
        task.save()
    assert sent.items == []
    task.status = TS.UNASSIGNED
    with commit():
        task.save()
    [board] = sent.to(store_group(f.order.store_id), "task.status")
    assert (board["data"]["previous_status"], board["data"]["status"]) == (
        "SEARCHING",
        "UNASSIGNED",
    )


def test_partial_refresh_keeps_an_unsaved_change(flow, sent, commit):
    f = flow()
    task = _offered_task(f)
    task.status = TS.SEARCHING
    task.refresh_from_db(fields=["attempt_count"])
    with commit():
        task.save()
    assert sent.to(store_group(f.order.store_id), "task.status")


def test_a_rolled_back_save_does_not_move_the_snapshot(flow, sent, commit):
    """The change is rolled back; saving it again later must still publish."""
    from django.db import transaction

    f = flow()
    task = _offered_task(f)
    task.status = TS.SEARCHING

    def save_then_fail():
        with transaction.atomic():
            task.save()
            raise RuntimeError("rollback")

    with pytest.raises(RuntimeError, match="rollback"):
        save_then_fail()
    assert task._live_snapshot == (TS.OFFERED, None)
    with commit():
        task.save()
    [board] = sent.to(store_group(f.order.store_id), "task.status")
    assert (board["data"]["previous_status"], board["data"]["status"]) == ("OFFERED", "SEARCHING")
    assert task._live_snapshot == (TS.SEARCHING, None)  # moved on commit


def test_deferred_status_publishes_rather_than_skips(flow, sent, commit):
    f = flow()
    task = _offered_task(f)
    deferred = DeliveryTask.objects.select_related("order").only("id", "order").get(pk=task.pk)
    assert deferred._live_snapshot is None
    deferred.status = TS.SEARCHING
    with commit():
        deferred.save(update_fields=["status"])
    [board] = sent.to(store_group(f.order.store_id), "task.status")
    assert board["data"]["previous_status"] is None


def test_task_save_path_query_count(flow, sent):
    """With the order cached (`select_related("order")` / the locked order), a status change
    costs only the UPDATE before commit: the observer adds no query."""
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    f = flow()
    _offered_task(f)
    task = DeliveryTask.objects.select_related("order").get(order=f.order)
    task.status = TS.SEARCHING
    with CaptureQueriesContext(connection) as queries:
        task.save(update_fields=["status", "updated_at"])
    assert len(queries) == 1, [q["sql"] for q in queries.captured_queries]


def test_cash_flag_pushes_once_per_rider_with_a_stable_ref(
    place, store_steps, make_rider, sent, pushes, commit
):
    rider = make_rider()
    Rider.objects.filter(pk=rider.pk).update(
        cash_in_hand=Decimal("90.00"), cash_limit=Decimal("100.00")
    )
    order = place()
    store_steps.accept(order)
    with commit():
        dispatch.dispatch_order(order.pk)
    flagged_at = Rider.objects.get(pk=rider.pk).cash_skipped_at
    assert pushes == [] or all(p[1] == "rider.cash_updated" for p in pushes)
    refs = [p[2]["ref"] for p in pushes if p[1] == "rider.cash_updated"]
    assert refs == [f"deposit:{rider.pk}:{flagged_at.isoformat()}"]


# --------------------------------------------------------------------------- QA bug fixes


def test_pickup_sends_out_for_delivery_status_once(flow, sent, pushes, commit, components):
    """BUG-0021 (P6-TC-14, P6-TC-59): T9 sends `order.status` OUT_FOR_DELIVERY once to the
    order socket and once to the store's ops feed, and still exactly one T9 notification."""
    from apps.notifications.models import Notification

    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    sent.items.clear()
    with commit():
        assert f.pickup().status_code == 200
    customer = [
        m
        for m in sent.to(order_group(f.order.pk), "order.status")
        if m["data"]["status"] == "OUT_FOR_DELIVERY"
    ]
    ops = [
        m
        for m in sent.to(store_group(f.order.store_id), "order.status")
        if m["data"]["status"] == "OUT_FOR_DELIVERY"
    ]
    assert len(customer) == 1
    assert len(ops) == 1
    assert sent.to(order_group(f.order.pk), "order.eta")
    assert (
        Notification.objects.filter(user=f.order.user, event="order.out_for_delivery").count() == 1
    )
    sent.validate(components)


def test_location_fan_out_keeps_the_heading(flow, sent, commit, components):
    """BUG-0022 (P6-TC-14): `rider.location` carries the ping's heading to the customer and ops."""
    f = flow()
    f.accept()
    sent.items.clear()
    point = {
        "lat": 28.4502,
        "lng": 77.0503,
        "accuracy": 8.0,
        "heading": 72.5,
        "recorded_at": timezone.now().isoformat(),
    }
    with commit():
        response = f.client.post("/api/v1/rider/locations/", {"points": [point]}, format="json")
    assert response.status_code in (200, 201), response.json()
    [customer] = sent.to(order_group(f.order.pk), "rider.location")
    assert customer["data"]["heading"] == 72.5
    [ops] = sent.to(store_group(f.rider.home_store_id), "rider.location")
    assert ops["data"]["heading"] == 72.5
    sent.validate(components)
