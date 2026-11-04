"""Publishing to sockets (06 §4): payload builders, group fan-out and the functions other apps
call (re-exported by `apps.realtime`).

Callers' functions (`publish_*`) only schedule work: after commit they queue a Celery task, so a
rolled-back change never reaches a socket and the caller never waits on Redis. Tasks send to
the channel layer; failures are retried, then dropped (apps poll as the fallback, 09 §1).
"""

import logging
import math
from datetime import UTC, datetime, timedelta

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.apps import apps as django_apps
from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.db.models import F, Sum
from django.utils import timezone

from apps.realtime import contract
from apps.realtime.groups import order_group, rider_group, store_group

logger = logging.getLogger(__name__)

# The consumer method that forwards a group message to the socket (`ws_message`).
GROUP_MESSAGE_TYPE = "ws.message"


def iso(value: datetime | None) -> str | None:
    """UTC ISO 8601 with "Z", as DRF renders datetimes."""
    if value is None:
        return None
    if timezone.is_naive(value):
        value = timezone.make_aware(value, UTC)
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def message(type_: str, data: dict | None = None) -> dict:
    body: dict = {"type": type_}
    if data is not None:
        body["data"] = data
    body["sent_at"] = iso(timezone.now())
    return body


def send_now(groups, body: dict) -> None:
    """Send `body` to every group now (Celery tasks and tests). Raises on a channel-layer error."""
    layer = get_channel_layer()
    send = async_to_sync(layer.group_send)
    for group in dict.fromkeys(groups):
        send(group, {"type": GROUP_MESSAGE_TYPE, "message": body})


def broadcast(groups, body: dict) -> None:
    """After commit, queue `broadcast_ws` (best effort: a queueing error is logged, not raised)."""
    from apps.realtime.tasks import broadcast_ws

    groups = list(dict.fromkeys(groups))

    def queue() -> None:
        try:
            broadcast_ws.delay(groups, body)
        except Exception:
            logger.exception("broadcast_ws not queued: %s to %s", body.get("type"), groups)

    transaction.on_commit(queue)


# --------------------------------------------------------------------------- order payloads


def order_status_data(order) -> dict:
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "store_id": order.store_id,
        "status": order.status,
        "payment_status": order.payment_status,
        "eta_at": iso(order.eta_at),
        "updated_at": iso(order.updated_at),
    }


def order_created_data(order) -> dict:
    from apps.core.money import money_str

    units = order.items.aggregate(n=Sum(F("quantity") - F("quantity_unavailable")))["n"] or 0
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "store_id": order.store_id,
        "status": order.status,
        "payment_method": order.payment_method,
        "item_count": units,
        "grand_total": money_str(order.grand_total),
        "placed_at": iso(order.placed_at),
        "eta_at": iso(order.eta_at),
    }


ALERT_MESSAGES = {
    "ACCEPTANCE_SLA_BREACHED": "Order {number} has not been accepted within {sla} seconds.",
    "LATE_CAPTURE": "Order {number}: a payment was captured after the order failed. It is being "
    "refunded automatically.",
    "REFUND_FAILED": "Order {number}: a refund failed at the gateway. Retry it from the order.",
    "DELIVERY_FAILED": "Order {number} could not be delivered. Expect the return.",
}
# Order domain events (apps.orders.events) that raise an ops alert, with their alert code.
ORDER_EVENT_ALERTS = {
    "order.acceptance_sla_breached": "ACCEPTANCE_SLA_BREACHED",
    "payment.late_capture": "LATE_CAPTURE",
    "payment.refund_failed": "REFUND_FAILED",
    "order.delivery_failed": "DELIVERY_FAILED",
}
# Events that are not a status change (no `order.status`).
NON_STATUS_EVENTS = frozenset(
    {"order.acceptance_sla_breached", "payment.late_capture", "payment.refund_failed"}
)


def alert_data(code: str, message_text: str, *, store_id=None, order_id=None, rider_id=None):
    return {
        "code": code,
        "message": message_text,
        "store_id": store_id,
        "order_id": order_id,
        "rider_id": rider_id,
        "at": iso(timezone.now()),
    }


def publish_order_event(event: str, order_id: int) -> list[str]:
    """Run by the `realtime.publish_order_event` task for every order domain event: the
    order's current status to its owner and its store, `order.created` on PLACED, and the ops
    alert of alert events. Returns the message types sent. Idempotent: it sends current state."""
    from apps.orders.models import Order

    order = Order.objects.filter(pk=order_id).first()
    if order is None:
        return []
    sent = []
    stores = [store_group(order.store_id)]
    if event not in NON_STATUS_EVENTS:
        send_now(
            [order_group(order.pk), *stores],
            message(contract.ORDER_STATUS, order_status_data(order)),
        )
        sent.append(contract.ORDER_STATUS)
    if event == "order.placed":
        send_now(stores, message(contract.ORDER_CREATED, order_created_data(order)))
        sent.append(contract.ORDER_CREATED)
    if (code := ORDER_EVENT_ALERTS.get(event)) is not None:
        text = ALERT_MESSAGES[code].format(
            number=order.order_number, sla=settings.STORE_ACCEPTANCE_SLA_SECONDS
        )
        send_now(
            stores,
            message(
                contract.ALERT,
                alert_data(code, text, store_id=order.store_id, order_id=order.pk),
            ),
        )
        sent.append(contract.ALERT)
    return sent


# --------------------------------------------------------------------------- Phase 5 calls


def _rider_model():
    try:
        return django_apps.get_model("delivery", "Rider")
    except LookupError:
        return None


def rider_home_store_id(rider_id: int) -> int | None:
    Rider = _rider_model()
    if Rider is None:
        return None
    return Rider.objects.filter(pk=rider_id).values_list("home_store_id", flat=True).first()


def publish_rider_location(
    rider_id: int,
    lat: float,
    lng: float,
    recorded_at,
    *,
    store_id: int | None = None,
    order_id: int | None = None,
    heading: float | None = None,
) -> None:
    """`rider.location` to the ops map of the rider's store (`store_id`, else the rider's home
    store) and, with `order_id`, to that order's customer. Pass `order_id` only while the rider
    has an active task for it (ASSIGNED .. AT_CUSTOMER). While the order is OUT_FOR_DELIVERY an
    `order.eta` follows, at most every WS_ETA_MIN_INTERVAL_SECONDS (08 §8)."""
    from apps.realtime.tasks import publish_rider_location_task

    args = (
        rider_id,
        float(lat),
        float(lng),
        iso(recorded_at) if isinstance(recorded_at, datetime) else recorded_at,
    )
    kwargs = {
        "store_id": store_id,
        "order_id": order_id,
        "heading": None if heading is None else float(heading),
    }

    def queue() -> None:
        try:
            publish_rider_location_task.delay(*args, **kwargs)
        except Exception:
            logger.exception("rider location not queued: rider %s", rider_id)

    transaction.on_commit(queue)


def send_rider_location(rider_id, lat, lng, recorded_at, *, store_id, order_id, heading) -> list:
    """The task body of `publish_rider_location`. Returns the message types sent."""
    sent = []
    store_id = store_id if store_id is not None else rider_home_store_id(rider_id)
    if store_id is not None:
        data = {
            "rider_id": rider_id,
            "store_id": store_id,
            "order_id": order_id,
            "lat": lat,
            "lng": lng,
            "heading": heading,
            "recorded_at": recorded_at,
        }
        send_now([store_group(store_id)], message(contract.RIDER_LOCATION, data))
        sent.append("ops:" + contract.RIDER_LOCATION)
    if order_id is not None:
        data = {
            "order_id": order_id,
            "lat": lat,
            "lng": lng,
            "heading": heading,
            "recorded_at": recorded_at,
        }
        send_now([order_group(order_id)], message(contract.RIDER_LOCATION, data))
        sent.append(contract.RIDER_LOCATION)
        if publish_eta_from_location(order_id, lat, lng):
            sent.append(contract.ORDER_ETA)
    return sent


def eta_minutes_from(lat: float, lng: float, drop_lat: float, drop_lng: float) -> int:
    """08 §8 once the order is on its way: rider to drop (straight line x road factor) at the
    average speed, plus the buffer. At least 1 minute."""
    from apps.stores.services import haversine_km

    km = haversine_km(lat, lng, drop_lat, drop_lng) * settings.ETA_ROAD_FACTOR
    minutes = km / settings.ETA_AVG_SPEED_KMPH * 60 + settings.ETA_BUFFER_MINUTES
    return max(1, math.ceil(minutes))


def publish_eta_from_location(order_id: int, lat: float, lng: float) -> bool:
    """`order.eta` for an order OUT_FOR_DELIVERY, throttled per order. Only published, never
    stored (`Order.eta_at` stays the promise made at placement)."""
    from apps.orders.choices import OrderStatus
    from apps.orders.models import Order

    if not cache.add(f"ws:eta:{order_id}", 1, timeout=settings.WS_ETA_MIN_INTERVAL_SECONDS):
        return False
    point = (
        Order.objects.filter(pk=order_id, status=OrderStatus.OUT_FOR_DELIVERY)
        .values_list("delivery_location", flat=True)
        .first()
    )
    if point is None:
        cache.delete(f"ws:eta:{order_id}")
        return False
    minutes = eta_minutes_from(lat, lng, point.y, point.x)
    eta_at = timezone.now() + timedelta(minutes=minutes)
    data = {"order_id": order_id, "eta_at": iso(eta_at), "eta_minutes": minutes}
    send_now([order_group(order_id)], message(contract.ORDER_ETA, data))
    return True


def publish_offer(rider_id: int, offer: dict) -> None:
    """`offer.new` to the rider; `offer` is the `RiderOffer` body (as serialized for the API)."""
    broadcast([rider_group(rider_id)], message(contract.OFFER_NEW, dict(offer)))


def publish_offer_withdrawn(rider_id: int, *, offer_id: int, task_id: int, reason: str) -> None:
    if reason not in contract.OFFER_WITHDRAWN_REASONS:
        raise ValueError(f"Unknown offer.withdrawn reason {reason!r}")
    data = {"offer_id": offer_id, "task_id": task_id, "reason": reason}
    broadcast([rider_group(rider_id)], message(contract.OFFER_WITHDRAWN, data))


def publish_task_updated(
    rider_id: int, *, task_id: int, order_id: int, status: str, order_status: str, change: str
) -> None:
    if change not in contract.TASK_CHANGES:
        raise ValueError(f"Unknown task.updated change {change!r}")
    data = {
        "task_id": task_id,
        "order_id": order_id,
        "status": status,
        "order_status": order_status,
        "change": change,
    }
    broadcast([rider_group(rider_id)], message(contract.TASK_UPDATED, data))


def publish_rider_status(rider_id: int, *, store_id: int, is_online: bool, on_task: bool) -> None:
    data = {
        "rider_id": rider_id,
        "store_id": store_id,
        "is_online": bool(is_online),
        "on_task": bool(on_task),
        "updated_at": iso(timezone.now()),
    }
    broadcast([store_group(store_id)], message(contract.RIDER_STATUS, data))


def publish_ops_alert(
    *,
    store_id: int,
    code: str,
    message_text: str,
    order_id: int | None = None,
    rider_id: int | None = None,
) -> None:
    """An ops `alert` for one store (Phase 5: DISPATCH_UNASSIGNED, DELIVERY_FAILED)."""
    data = alert_data(code, message_text, store_id=store_id, order_id=order_id, rider_id=rider_id)
    broadcast([store_group(store_id)], message(contract.ALERT, data))


# --------------------------------------------------------------------------- retention


def purge_old_locations(now=None, batch_size: int = 5000) -> int:
    """Delete `delivery.RiderLocation` rows older than RIDER_LOCATION_RETENTION_DAYS (07 §2.8),
    in batches. A no-op while the Phase 5 model is not installed."""
    try:
        RiderLocation = django_apps.get_model("delivery", "RiderLocation")
    except LookupError:
        return 0
    cutoff = (now or timezone.now()) - timedelta(days=settings.RIDER_LOCATION_RETENTION_DAYS)
    total = 0
    while True:
        ids = list(
            RiderLocation.objects.filter(recorded_at__lt=cutoff).values_list("pk", flat=True)[
                :batch_size
            ]
        )
        if not ids:
            return total
        deleted, _ = RiderLocation.objects.filter(pk__in=ids).delete()
        total += deleted
