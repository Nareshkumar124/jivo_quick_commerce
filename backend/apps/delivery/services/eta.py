"""The live ETA (08 §8), computed on the server, cheap (no routing API, a few arithmetic steps):

    eta_minutes = prep left
                + rider_to_store_minutes
                + store_to_customer_km / avg_speed x 60
                + buffer

- Prep left: `store.avg_prep_minutes` minus the time since the store accepted (or the order was
  placed), never below zero; 0 once the order is PACKED.
- Rider to store: the typical rider wait (`ETA_RIDER_WAIT_MINUTES`) while no rider is assigned
  (dispatch not started, searching, offered, unassigned: the same as the serviceability and
  placement ETA); the rider's latest point to the store while ASSIGNED; 0 at the store.
- Once picked up (order OUT_FOR_DELIVERY): the rider's latest point to the drop, plus the buffer.
- Distances are straight lines x `ETA_ROAD_FACTOR`, at `ETA_AVG_SPEED_KMPH`. At least 1 minute.
- Terminal orders (and orders not yet PLACED) have no live ETA (None).

`Order.eta_at` stays the promise made at placement; the live ETA is only published
(`order.eta` on the order socket) and returned by `GET /orders/{id}/track/` (`live_eta_*`).
"""

import math
from dataclasses import dataclass
from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone

from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.orders.choices import OrderStatus
from apps.stores.services import haversine_km

# Orders that still have a live ETA (PLACED .. OUT_FOR_DELIVERY).
LIVE_ORDER_STATUSES = frozenset(
    {
        OrderStatus.PLACED,
        OrderStatus.ACCEPTED,
        OrderStatus.PACKING,
        OrderStatus.PACKED,
        OrderStatus.OUT_FOR_DELIVERY,
    }
)
PREP_DONE_STATUSES = frozenset({OrderStatus.PACKED, OrderStatus.OUT_FOR_DELIVERY})
ON_THE_WAY_TASK_STATUSES = frozenset({TS.PICKED_UP, TS.AT_CUSTOMER})


@dataclass(frozen=True)
class Eta:
    minutes: int
    eta_at: datetime


def travel_minutes(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    km = haversine_km(lat1, lng1, lat2, lng2) * settings.ETA_ROAD_FACTOR
    return km / max(settings.ETA_AVG_SPEED_KMPH, 1) * 60  # a 0 setting never divides


def prep_left_minutes(order, now: datetime) -> float:
    if order.status in PREP_DONE_STATUSES:
        return 0.0
    started = order.accepted_at or order.placed_at
    prep = float(order.store.avg_prep_minutes)
    if started is None:
        return prep
    return max(0.0, prep - (now - started).total_seconds() / 60)


def compute(order, task=None, rider_point: tuple[float, float] | None = None, now=None):
    """The live `Eta` of `order` (see the module doc), or None when it has none. `task` is the
    order's delivery task (or None); `rider_point` the rider's latest `(lat, lng)`, if known.
    No queries beyond `order.store` (select it with the order)."""
    now = now or timezone.now()
    if order.status not in LIVE_ORDER_STATUSES:
        return None
    store = order.store
    drop = order.delivery_location
    task_status = getattr(task, "status", None)
    if order.status == OrderStatus.OUT_FOR_DELIVERY or task_status in ON_THE_WAY_TASK_STATUSES:
        if task_status == TS.AT_CUSTOMER:
            minutes = 0.0
        elif rider_point is not None:
            minutes = travel_minutes(rider_point[0], rider_point[1], drop.y, drop.x)
        else:
            minutes = travel_minutes(store.location.y, store.location.x, drop.y, drop.x)
        total = minutes + settings.ETA_BUFFER_MINUTES
    else:
        if task_status == TS.AT_STORE:
            to_store = 0.0
        elif task_status == TS.ASSIGNED and rider_point is not None:
            to_store = travel_minutes(
                rider_point[0], rider_point[1], store.location.y, store.location.x
            )
        else:
            to_store = float(settings.ETA_RIDER_WAIT_MINUTES)
        total = (
            prep_left_minutes(order, now)
            + to_store
            + travel_minutes(store.location.y, store.location.x, drop.y, drop.x)
            + settings.ETA_BUFFER_MINUTES
        )
    minutes = max(1, math.ceil(total))
    return Eta(minutes=minutes, eta_at=now + timedelta(minutes=minutes))


def rider_point(task) -> tuple[float, float] | None:
    """The `(lat, lng)` of the task's rider: Redis, else the rider row; None without a rider."""
    if task is None or not task.rider_id:
        return None
    from apps.delivery.services.shifts import latest_location

    location = latest_location(task.rider)
    if location is None:
        return None
    return (location["lat"], location["lng"])


def for_order(order, now=None, *, point: tuple[float, float] | None = None):
    """The live `Eta` of `order` with its task and the rider's latest point (or `point`)."""
    if order.status not in LIVE_ORDER_STATUSES:
        return None
    from apps.delivery.models import DeliveryTask

    task = DeliveryTask.objects.select_related("rider").filter(order=order).first()
    if point is None:
        point = rider_point(task)
    return compute(order, task, point, now=now)


def for_order_id(order_id: int, now=None, *, point=None):
    from apps.orders.models import Order

    order = Order.objects.select_related("store").filter(pk=order_id).first()
    if order is None:
        return None
    return for_order(order, now, point=point)
