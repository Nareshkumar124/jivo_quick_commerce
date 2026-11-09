"""Seams to Phase 6 (`notifications`, `realtime`).

Delivery code calls ONLY these functions for push and WebSocket side effects; it never builds
its own FCM sender or socket code. Since the P6 merge they call the real functions. Every call
site is after commit, and each hook is best effort: a failure is logged, never raised into the
delivery flow (apps fall back to polling, and FCM is retried by its own task).
"""

import logging

from django.apps import apps
from django.core.exceptions import FieldError
from django.db import transaction

from apps.delivery.choices import DeliveryTaskStatus

logger = logging.getLogger(__name__)

# The customer may see the rider only while the rider is on the way to them (08 §9 "Task
# ASSIGNED: rider name shown in tracking" .. AT_CUSTOMER). Never on a failed or returning task.
CUSTOMER_TRACKING_TASK_STATUSES = frozenset(
    {
        DeliveryTaskStatus.ASSIGNED,
        DeliveryTaskStatus.AT_STORE,
        DeliveryTaskStatus.PICKED_UP,
        DeliveryTaskStatus.AT_CUSTOMER,
    }
)


def send_push(user, event: str, data: dict) -> None:
    """`apps.notifications.send_push(user, event, data)`: rider offer and COD-amount-changed
    pushes (events in `apps.notifications.catalog`, e.g. `rider.offer_new`)."""
    from apps import notifications

    try:
        notifications.send_push(user, event, data)
    except Exception:
        logger.exception(
            "hooks.send_push failed: event=%s user=%s", event, getattr(user, "pk", None)
        )


def active_task_order_id(rider_id: int) -> int | None:
    """The order of the rider's task while the customer may track it, else None. None until the
    slice 5.3 `DeliveryTask` model exists (field names: `rider`, `order`, `status`)."""
    try:
        DeliveryTask = apps.get_model("delivery", "DeliveryTask")
    except LookupError:
        return None
    try:
        return (
            DeliveryTask.objects.filter(
                rider_id=rider_id, status__in=sorted(CUSTOMER_TRACKING_TASK_STATUSES)
            )
            .order_by("-pk")
            .values_list("order_id", flat=True)
            .first()
        )
    except FieldError:
        logger.exception("hooks.active_task_order_id: DeliveryTask fields changed, update me")
        return None


def publish_rider_location(
    rider_id: int, lat: float, lng: float, recorded_at, *, heading: float | None = None
) -> None:
    """`apps.realtime.publish_rider_location(...)`: the ops map of the rider's home store, and
    the customer tracking socket of the order **only while the rider has an active task for it**
    (`active_task_order_id`). Called from location ingestion."""
    from apps import realtime

    try:
        realtime.publish_rider_location(
            rider_id,
            lat,
            lng,
            recorded_at,
            order_id=active_task_order_id(rider_id),
            heading=heading,
        )
    except Exception:
        logger.exception("hooks.publish_rider_location failed: rider=%s", rider_id)


def publish_offer(rider_id: int, offer: dict) -> None:
    """`apps.realtime.publish_offer(...)`: `offer.new` on `/ws/v1/rider/` (dispatch, 5.3)."""
    from apps import realtime

    try:
        realtime.publish_offer(rider_id, offer)
    except Exception:
        logger.exception("hooks.publish_offer failed: rider=%s", rider_id)


def notify_order(order, event: str, **extra) -> None:
    """`apps.notifications.notify_order(order, event, **extra)`: the customer notification of a
    Phase 5 moment that needs more than the order id (08 §9: T9 "out for delivery" with the
    rider's name and the OTP, AT_CUSTOMER "rider has arrived"). Idempotent: the notification is
    deduplicated per (event, customer, order). Called after commit."""
    from apps import notifications

    try:
        notifications.notify_order(order, event, **extra)
    except Exception:
        logger.exception("hooks.notify_order failed: event=%s order=%s", event, order.pk)


# Ops alert texts (`alert` on `/ws/ops/live/`, 06 §4; codes in `apps.realtime.contract`).
OPS_ALERT_MESSAGES = {
    "DISPATCH_UNASSIGNED": "No rider found for order {order_number}. Assign one manually.",
    "PICKUP_CODE_LOCKED": "Order {order_number}: pickup locked after too many wrong codes.",
    "DELIVERY_OTP_LOCKED": "Order {order_number}: delivery OTP locked after too many wrong "
    "attempts.",
    "STOCK_NOT_COMMITTED": "Order {order_number} was picked up with no active stock reservation.",
    "ARRIVAL_GEOFENCE_OVERRIDE": "Order {order_number}: the rider marked arrival {distance_m} m "
    "from the drop pin ({reason}).",
    "MOCKED_LOCATION": "Rider {rider_id} is sending mocked (fake GPS) locations.",
    "RIDER_STALE_ON_TASK": "Rider {rider_id} is on a task but has sent no location recently.",
}


class _Blank(dict):
    def __missing__(self, key):
        return "?"


def _alert_target(data: dict) -> tuple[int | None, int | None, int | None]:
    """(store_id, order_id, rider_id) of an alert: the store from `store_id`, else the order's,
    else the task's, else the rider's home store."""
    store_id, order_id, rider_id = data.get("store_id"), data.get("order_id"), data.get("rider_id")
    if store_id is None and order_id is not None:
        Order = apps.get_model("orders", "Order")
        store_id = Order.objects.filter(pk=order_id).values_list("store_id", flat=True).first()
    if data.get("task_id") is not None and (store_id is None or order_id is None):
        DeliveryTask = apps.get_model("delivery", "DeliveryTask")
        row = DeliveryTask.objects.filter(pk=data["task_id"]).values("store_id", "order_id").first()
        if row:
            store_id = store_id if store_id is not None else row["store_id"]
            order_id = order_id if order_id is not None else row["order_id"]
    if store_id is None and rider_id is not None:
        Rider = apps.get_model("delivery", "Rider")
        store_id = Rider.objects.filter(pk=rider_id).values_list("home_store_id", flat=True).first()
    return store_id, order_id, rider_id


def ops_alert(kind: str, data: dict) -> None:
    """An ops `alert` on `/ws/ops/live/` (06 §4) to the store's ops group, through
    `apps.realtime.publish_ops_alert` (after commit, best effort), and logged at WARNING so the
    log keeps a record. Kinds: the keys of `OPS_ALERT_MESSAGES`. An alert with no store (no
    order, task or rider found) is only logged."""
    logger.warning("Ops alert %s: %s", kind, data)
    from apps import realtime

    try:
        store_id, order_id, rider_id = _alert_target(data)
        if store_id is None:
            return
        text = OPS_ALERT_MESSAGES.get(kind, kind).format_map(_Blank(data))
        realtime.publish_ops_alert(
            store_id=store_id,
            code=kind,
            message_text=text,
            order_id=order_id,
            rider_id=rider_id,
        )
    except Exception:
        logger.exception("hooks.ops_alert failed: kind=%s", kind)


# --------------------------------------------------------------------------- T-612 rider events
# Rider-facing socket messages (`/ws/v1/rider/`) with their FCM data push (06 §4.3), for changes
# the rider did not make themselves. Call these inside the service's transaction: each one
# schedules its work with `transaction.on_commit` (and runs at once outside a transaction).


def _on_commit(label: str, func) -> None:
    def run() -> None:
        try:
            func()
        except Exception:
            logger.exception("hooks.%s failed", label)

    transaction.on_commit(run)


def offer_closed(offer, order, reason: str) -> None:
    """The rider's pending offer is gone: `offer.expired` (reason EXPIRED) or `offer.withdrawn`
    (TAKEN, ORDER_CANCELLED, REASSIGNED, RIDER_OFFLINE), plus the push."""
    from apps import realtime

    rider_id, user = offer.rider_id, offer.rider.user
    ids = {"offer_id": offer.pk, "task_id": offer.task_id}
    push = {**ids, "order_number": order.order_number, "status": offer.status}

    def send() -> None:
        if reason == "EXPIRED":
            realtime.publish_offer_expired(rider_id, **ids)
            send_push(user, "rider.offer_expired", push)
        else:
            realtime.publish_offer_withdrawn(rider_id, reason=reason, **ids)
            send_push(user, "rider.offer_withdrawn", push)

    _on_commit("offer_closed", send)


def task_updated(
    task,
    order,
    change: str,
    *,
    rider=None,
    push_event: str | None = None,
    push_data: dict | None = None,
) -> None:
    """`task.updated` to the task's rider (or `rider`, e.g. the one just taken off), with the
    push `push_event` (a `rider.*` event in `apps.notifications.catalog`), if given."""
    from apps import realtime

    rider = rider if rider is not None else task.rider
    if rider is None:
        return
    rider_id, user = rider.pk, rider.user
    data = {
        "task_id": task.pk,
        "order_id": order.pk,
        "status": task.status,
        "order_status": order.status,
        "change": change,
    }

    def send() -> None:
        realtime.publish_task_updated(rider_id, **data)
        if push_event:
            send_push(user, push_event, push_data or {"task_id": task.pk})

    _on_commit("task_updated", send)


def cash_updated(rider, reason: str, *, push_ref: str | None = None) -> None:
    """`cash.updated` to the rider (the balance as it is when sent); with `push_ref`, also the
    `rider.cash_updated` push (one per ref: staff deposits and adjustments, the deposit flag)."""
    from apps import realtime

    rider_id, user = rider.pk, rider.user

    def send() -> None:
        realtime.publish_cash_updated(rider_id, reason=reason)
        if push_ref:
            send_push(user, "rider.cash_updated", {"ref": push_ref})

    _on_commit("cash_updated", send)


# --------------------------------------------------------------------------- T-612 ops / ETA


def task_changed(task, previous_status: str | None, previous_rider_id: int | None) -> None:
    """A task was created or changed status or rider (`apps.delivery.live`): `task.status` to the
    store's ops sockets, `rider.status` for the riders whose on-task state may have changed, and
    a recomputed `order.eta` to the customer (08 §8)."""
    from apps import realtime
    from apps.realtime.services import task_status_data

    order_number = (
        task.order.order_number
        if "order" in task._state.fields_cache
        else apps.get_model("orders", "Order")
        .objects.filter(pk=task.order_id)
        .values_list("order_number", flat=True)
        .first()
    )
    data = task_status_data(task, order_number or "", previous_status)
    store_id, order_id = task.store_id, task.order_id
    riders = {r for r in (previous_rider_id, task.rider_id) if r}

    def send() -> None:
        realtime.publish_task_status(store_id, data)
        for rider_id in sorted(riders):
            realtime.publish_rider_presence(rider_id)
        realtime.publish_order_eta(order_id)

    _on_commit("task_changed", send)


def rider_presence(rider_id: int) -> None:
    """`rider.status` to ops after the rider went online or offline."""
    from apps import realtime

    _on_commit("rider_presence", lambda: realtime.publish_rider_presence(rider_id))
