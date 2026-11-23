"""Live tracking helpers (T-821): road routes for a task's current leg, the customer's 8-step
progress, staleness and the distance left. Read-only: nothing here changes an order or a task
(states change only through `orders.services.transition()` and the delivery services).

Legs (from the task status):
- `TO_STORE`: ASSIGNED, AT_STORE (rider -> store; then store -> drop is still ahead).
- `TO_CUSTOMER`: PICKED_UP, AT_CUSTOMER (rider -> drop).

Routes come from `apps.maps.services` (Google Routes API with traffic when configured, else
the straight line x road factor), cached and throttled per task leg.

Progress steps (customer tracking), each reached from real order/task data:

- CONFIRMED: the order is placed (paid or COD); `at` = `placed_at`.
- PREPARING: the store accepted it (T6); `accepted_at`.
- PACKED: packed (T8); `packed_at`.
- RIDER_ASSIGNED: a rider accepted or was assigned; the task's `assigned_at`.
- PICKED_UP: T9 (order OUT_FOR_DELIVERY); `picked_up_at`.
- ON_THE_WAY: picked up and the rider is outside the store geofence (`RIDER_STORE_GEOFENCE_M`),
  or at the drop; `at` null (derived from the position).
- ARRIVING: on the way and within `TRACKING_ARRIVING_RADIUS_M` of the drop, or the task is
  AT_CUSTOMER; the task's `arrived_customer_at`, else null.
- DELIVERED: T10; `delivered_at`.

A later step being reached marks the earlier ones done (e.g. no ping between pickup and
arrival), except that RIDER_ASSIGNED does not imply PACKED: a rider is often assigned while the
store is still packing, so `current` can be RIDER_ASSIGNED with PACKED not done yet.
`current` is the last reached step; `outcome` is null while active, else DELIVERED, CANCELLED,
DELIVERY_FAILED or RETURNED (the steps stay as far as they got).
"""

from datetime import datetime

from django.conf import settings
from django.utils import timezone

from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.maps import services as maps
from apps.orders.choices import OrderStatus
from apps.stores.services import haversine_km

LEG_TO_STORE = "TO_STORE"
LEG_TO_CUSTOMER = "TO_CUSTOMER"
LEGS = (LEG_TO_STORE, LEG_TO_CUSTOMER)
TO_STORE_STATUSES = frozenset({TS.ASSIGNED, TS.AT_STORE})
TO_CUSTOMER_STATUSES = frozenset({TS.PICKED_UP, TS.AT_CUSTOMER})
# A task in one of these has (or had, for this delivery) a rider; SEARCHING/OFFERED/UNASSIGNED
# after an unassign, and CANCELLED, do not count as "rider assigned".
HAD_RIDER_STATUSES = frozenset(
    {
        TS.ASSIGNED,
        TS.AT_STORE,
        TS.PICKED_UP,
        TS.AT_CUSTOMER,
        TS.DELIVERED,
        TS.FAILED,
        TS.RETURNING,
        TS.RETURNED,
    }
)

STEPS = (
    "CONFIRMED",
    "PREPARING",
    "PACKED",
    "RIDER_ASSIGNED",
    "PICKED_UP",
    "ON_THE_WAY",
    "ARRIVING",
    "DELIVERED",
)
STEP_LABELS = {
    "CONFIRMED": "Order confirmed",
    "PREPARING": "Preparing your order",
    "PACKED": "Packed",
    "RIDER_ASSIGNED": "Rider assigned",
    "PICKED_UP": "Picked up",
    "ON_THE_WAY": "On the way",
    "ARRIVING": "Arriving",
    "DELIVERED": "Delivered",
}
OUTCOMES = frozenset(
    {
        OrderStatus.DELIVERED,
        OrderStatus.CANCELLED,
        OrderStatus.DELIVERY_FAILED,
        OrderStatus.RETURNED,
    }
)
NOT_PLACED = frozenset({OrderStatus.PAYMENT_PENDING, OrderStatus.PAYMENT_FAILED})


def meters(a: tuple[float, float], b: tuple[float, float]) -> int:
    return round(haversine_km(a[0], a[1], b[0], b[1]) * 1000)


def store_point(order) -> tuple[float, float]:
    return (order.store.location.y, order.store.location.x)


def drop_point(order) -> tuple[float, float]:
    return (order.delivery_location.y, order.delivery_location.x)


def leg_of(task) -> str | None:
    status = getattr(task, "status", None)
    if status in TO_STORE_STATUSES:
        return LEG_TO_STORE
    if status in TO_CUSTOMER_STATUSES:
        return LEG_TO_CUSTOMER
    return None


def is_stale(recorded_at: datetime | None, now: datetime | None = None) -> bool:
    """True when there is no position, or it is older than TRACKING_STALE_SECONDS."""
    if recorded_at is None:
        return True
    now = now or timezone.now()
    return (now - recorded_at).total_seconds() > settings.TRACKING_STALE_SECONDS


def leg_destination(order, leg: str) -> tuple[float, float]:
    return store_point(order) if leg == LEG_TO_STORE else drop_point(order)


def rider_route(
    task, order, point: tuple[float, float] | None, now=None, *, cached_only: bool = False
):
    """The `TrackedRoute` from the rider's `point` along the task's current leg, or None (no
    leg, no position, or a task without a pk)."""
    leg = leg_of(task)
    if leg is None or point is None or getattr(task, "pk", None) is None:
        return None
    return maps.tracked_route(
        f"task:{task.pk}:{leg}", point, leg_destination(order, leg), now, cached_only=cached_only
    )


def store_drop_route(order, now=None, *, cached_only: bool = False):
    """The store -> drop `Route` (fixed, cached), or None for an order without a pk."""
    if getattr(order, "pk", None) is None:
        return None
    key = f"order:{order.pk}:store-drop"
    return maps.fixed_route(
        key, store_point(order), drop_point(order), now, cached_only=cached_only
    )


def distance_remaining_m(
    order, task, tracked, now=None, *, cached_only: bool = False
) -> int | None:
    """Metres the rider still has to ride to the customer: the current leg's route, plus the
    store -> drop leg while heading to the store. None without a route (no rider position)."""
    if tracked is None:
        return None
    distance = tracked.route.distance_m
    if leg_of(task) == LEG_TO_STORE:
        fixed = store_drop_route(order, now, cached_only=cached_only)
        distance += fixed.distance_m if fixed is not None else 0
    return distance


def route_body(task, tracked) -> dict | None:
    if tracked is None:
        return None
    route = tracked.route
    return {
        "leg": leg_of(task),
        "polyline": route.polyline,
        "distance_m": route.distance_m,
        "duration_s": round(route.duration_s),
        "provider": route.provider,
        "traffic_aware": route.traffic_aware,
        "computed_at": tracked.computed_at,
    }


def progress(order, task, point: tuple[float, float] | None) -> dict:
    """The 8 customer steps (module doc)."""
    status = order.status
    task_status = getattr(task, "status", None)
    reached: dict[str, datetime | bool | None] = {}

    def mark(step: str, at=None) -> None:
        reached[step] = at

    if order.placed_at is not None and status not in NOT_PLACED:
        mark("CONFIRMED", order.placed_at)
    if order.accepted_at is not None:
        mark("PREPARING", order.accepted_at)
    if order.packed_at is not None:
        mark("PACKED", order.packed_at)
    if task is not None and task.assigned_at is not None and task_status in HAD_RIDER_STATUSES:
        mark("RIDER_ASSIGNED", task.assigned_at)
    if order.picked_up_at is not None:
        mark("PICKED_UP", order.picked_up_at)
        on_the_way = task_status == TS.AT_CUSTOMER or status in OUTCOMES - {OrderStatus.CANCELLED}
        if point is not None and task_status in TO_CUSTOMER_STATUSES:
            if meters(point, store_point(order)) > settings.RIDER_STORE_GEOFENCE_M:
                on_the_way = True
            if meters(point, drop_point(order)) <= settings.TRACKING_ARRIVING_RADIUS_M:
                on_the_way = True
                mark("ARRIVING", None)
        if on_the_way:
            mark("ON_THE_WAY", None)
        if task_status == TS.AT_CUSTOMER or (task is not None and task.arrived_customer_at):
            mark("ARRIVING", task.arrived_customer_at)
    if status == OrderStatus.DELIVERED:
        mark("DELIVERED", order.delivered_at)
    # A later step implies the earlier ones (e.g. no ping between pickup and arrival); a rider
    # assigned during packing does not make the order packed.
    indexes = [STEPS.index(step) for step in reached]
    last = max(indexes, default=-1)

    def done(index: int, step: str) -> bool:
        if step in reached:
            return True
        later = [i for i in indexes if i > index]
        if step == "PACKED":
            later = [i for i in later if STEPS[i] != "RIDER_ASSIGNED"]
        return bool(later)

    steps = [
        {
            "key": step,
            "label": STEP_LABELS[step],
            "done": done(index, step),
            "at": reached.get(step) if step in reached else None,
        }
        for index, step in enumerate(STEPS)
    ]
    return {
        "current": STEPS[last] if last >= 0 else None,
        "outcome": status if status in OUTCOMES else None,
        "steps": steps,
    }
