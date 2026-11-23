"""Ops live delivery dashboard data (T-821, 05 §1.4 "Dispatch & rider map"): one read-only
snapshot of every active delivery in the staff user's stores, and the per-delivery progress
that `/ws/ops/live/` pushes as `delivery.progress`.

Access (05 §3 "Live order board" row: Super Admin, Ops, Store Manager own stores, Support
view; Store Staff and Finance none): `orders.view_order` and `orders.cancel_order`, the same
pair as the panel's live board capability (`ops_console.capabilities.LIVE_BOARD`), and the
stores of `stores_for(user)` (Store Manager: their `StaffStoreAccess` stores only). Everything
is filtered by those stores first, so another store's order or rider is simply absent. The
customer's name, the drop point and the area are included only for users who handle orders or
customers (`accounts.view_customer`, `delivery.dispatch_order` or `orders.process_order`; 05 §3
"Customers (PII)": store roles see a name), else null. No phone,
no street address, no OTP or pickup code.

Nothing here writes: assign / reassign / cancel stay in `apps.delivery.services.dispatch`,
`apps.delivery.services.ops` and `apps.orders.store_ops`.

Stats (all within the user's stores, `store_id` narrows to one):
- `active_orders`: orders PLACED .. OUT_FOR_DELIVERY.
- `riders_online`: online riders whose home store is in scope; `riders_delivering`: those with a
  task ASSIGNED .. RETURNING.
- `awaiting_assignment`: tasks SEARCHING, OFFERED or UNASSIGNED.
- `to_store` / `at_store`: tasks ASSIGNED / AT_STORE.
- `picked_up`: tasks PICKED_UP or AT_CUSTOMER (the order is OUT_FOR_DELIVERY);
  `in_transit`: PICKED_UP only (riding to the customer).
- `delayed`: active deliveries listed whose `is_delayed` is true (past the promised `eta_at`, or
  a live ETA later than it by more than TRACKING_DELAY_GRACE_MINUTES).
- `completed_today`: orders delivered since IST midnight.
"""

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db.models import Count, Q
from django.utils import timezone

from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import LiveRiderState
from apps.delivery.models import RIDER_BUSY_STATUSES, DeliveryTask, Rider
from apps.delivery.services import eta as eta_service
from apps.delivery.services import live_tracking
from apps.delivery.services.shifts import latest_location
from apps.orders.choices import OrderStatus
from apps.orders.models import Order
from apps.stores.services import stores_for

LIVE_BOARD_PERMISSIONS = ("orders.view_order", "orders.cancel_order")
CUSTOMER_NAME_PERMISSIONS = (
    "accounts.view_customer",
    "delivery.dispatch_order",
    "orders.process_order",
)
ACTIVE_ORDER_STATUSES = (
    OrderStatus.PLACED,
    OrderStatus.ACCEPTED,
    OrderStatus.PACKING,
    OrderStatus.PACKED,
    OrderStatus.OUT_FOR_DELIVERY,
)
WAITING = (TS.SEARCHING, TS.OFFERED, TS.UNASSIGNED)
RIDER_STATE = {
    TS.ASSIGNED: LiveRiderState.TO_STORE,
    TS.AT_STORE: LiveRiderState.AT_STORE,
    TS.PICKED_UP: LiveRiderState.DELIVERING,
    TS.AT_CUSTOMER: LiveRiderState.DELIVERING,
    TS.FAILED: LiveRiderState.RETURNING,
    TS.RETURNING: LiveRiderState.RETURNING,
}
LIST_LIMIT = 200
TASK_SECRETS = ("delivery_otp_encrypted",)


def can_view(user) -> bool:
    return bool(
        user
        and user.is_authenticated
        and user.is_active
        and user.is_staff
        and user.has_perms(LIVE_BOARD_PERMISSIONS)
    )


def shows_customer_name(user) -> bool:
    return any(user.has_perm(perm) for perm in CUSTOMER_NAME_PERMISSIONS)


def _short_name(full_name: str) -> str:
    from apps.delivery.services.tracking import _short_name as short

    return short(full_name or "")


def is_delayed(order, live, now: datetime) -> bool:
    if order.eta_at is None:
        return False
    if now > order.eta_at:
        return True
    grace = timedelta(minutes=settings.TRACKING_DELAY_GRACE_MINUTES)
    return live is not None and live.eta_at > order.eta_at + grace


def delivery_progress(order, task, point, now=None, *, cached_only: bool = False) -> dict:
    """Route, distance left, live ETA and the delay flag of one delivery (no customer data)."""
    now = now or timezone.now()
    tracked = (
        live_tracking.rider_route(task, order, point, now, cached_only=cached_only)
        if task is not None
        else None
    )
    live = eta_service.compute(order, task, point, now=now, cached_only=cached_only)
    return {
        "tracked": tracked,
        "distance_remaining_m": live_tracking.distance_remaining_m(
            order, task, tracked, now, cached_only=cached_only
        ),
        "live_eta_at": live.eta_at if live else None,
        "live_eta_minutes": live.minutes if live else None,
        "is_delayed": is_delayed(order, live, now),
    }


def _rider_row(rider: Rider, task, now) -> dict:
    location = latest_location(rider)
    recorded_at = location["recorded_at"] if location else None
    if task is not None and task.status in RIDER_STATE and not rider.is_online:
        state = LiveRiderState.OFFLINE
    elif task is not None and task.status in RIDER_STATE:
        state = RIDER_STATE[task.status]
    else:
        state = LiveRiderState.IDLE
    return {
        "rider_id": rider.pk,
        "name": _short_name(rider.full_name),
        "store_id": rider.home_store_id,
        "is_online": rider.is_online,
        "state": state,
        "task_id": task.pk if task is not None else None,
        "order_id": task.order_id if task is not None else None,
        "lat": location["lat"] if location else None,
        "lng": location["lng"] if location else None,
        "heading": location.get("heading") if location else None,
        "updated_at": recorded_at,
        "is_stale": live_tracking.is_stale(recorded_at, now),
        "last_seen_at": rider.last_location_received_at,
    }


def snapshot(user, store_id: int | None = None, now=None) -> dict:
    """The live dashboard for `user` (see the module doc). Raises `PermissionDenied` without
    `orders.view_order`; a `store_id` outside the user's stores gives an empty snapshot."""
    if not can_view(user):
        raise PermissionDenied
    now = now or timezone.now()
    stores = stores_for(user)
    if store_id is not None:
        stores = stores.filter(pk=store_id)
    store_list = list(stores.order_by("code", "pk"))
    store_ids = [store.pk for store in store_list]
    names = shows_customer_name(user)

    orders_qs = Order.objects.filter(store_id__in=store_ids, status__in=ACTIVE_ORDER_STATUSES)
    orders = list(
        orders_qs.select_related("store", "user").order_by("placed_at", "pk")[: LIST_LIMIT + 1]
    )
    truncated = len(orders) > LIST_LIMIT
    orders = orders[:LIST_LIMIT]
    tasks = {
        task.order_id: task
        for task in DeliveryTask.objects.filter(order__in=orders)
        .defer(*TASK_SECRETS)
        .select_related("rider")
    }
    rider_tasks = {
        task.rider_id: task
        for task in DeliveryTask.objects.filter(
            store_id__in=store_ids, status__in=RIDER_BUSY_STATUSES
        ).only("pk", "order_id", "rider_id", "status", "store_id")
    }
    riders = list(
        Rider.objects.filter(
            Q(is_online=True, home_store_id__in=store_ids) | Q(pk__in=list(rider_tasks))
        ).order_by("full_name", "pk")[:LIST_LIMIT]
    )
    rider_rows = [_rider_row(rider, rider_tasks.get(rider.pk), now) for rider in riders]
    positions = {
        row["rider_id"]: (row["lat"], row["lng"]) for row in rider_rows if row["lat"] is not None
    }
    rows_by_rider = {row["rider_id"]: row for row in rider_rows}

    deliveries = []
    for order in orders:
        task = tasks.get(order.pk)
        rider = task.rider if task is not None and task.rider_id else None
        point = positions.get(rider.pk) if rider is not None else None
        if rider is not None and rider.pk not in positions and rider.pk not in rows_by_rider:
            location = latest_location(rider)
            point = (location["lat"], location["lng"]) if location else None
        # Read-only on routes: a snapshot of many deliveries never calls the provider.
        progress = delivery_progress(order, task, point, now, cached_only=True)
        rider_row = rows_by_rider.get(rider.pk) if rider is not None else None
        snapshot_area = order.address_snapshot or {}
        deliveries.append(
            {
                "order_id": order.pk,
                "order_number": order.order_number,
                "store_id": order.store_id,
                "customer_name": ((order.user.name or "").strip() or None) if names else None,
                "area": (snapshot_area.get("area") or None) if names else None,
                "drop": (
                    {"lat": order.delivery_location.y, "lng": order.delivery_location.x}
                    if names
                    else None
                ),
                "order_status": order.status,
                "task_id": task.pk if task is not None else None,
                "task_status": task.status if task is not None else None,
                "rider_id": rider.pk if rider is not None else None,
                "rider_name": _short_name(rider.full_name) if rider is not None else None,
                "placed_at": order.placed_at,
                "eta_at": order.eta_at,
                "live_eta_at": progress["live_eta_at"],
                "live_eta_minutes": progress["live_eta_minutes"],
                "distance_remaining_m": progress["distance_remaining_m"],
                "is_delayed": progress["is_delayed"],
                "last_update_at": rider_row["updated_at"] if rider_row else None,
                "is_stale": rider_row["is_stale"] if rider_row else None,
                "rider_online": rider.is_online if rider is not None else None,
            }
        )

    task_counts = dict(
        DeliveryTask.objects.filter(store_id__in=store_ids, order__status__in=ACTIVE_ORDER_STATUSES)
        .values_list("status")
        .annotate(n=Count("pk"))
        .values_list("status", "n")
    )
    online = Rider.objects.filter(is_online=True, home_store_id__in=store_ids)
    midnight = timezone.localtime(now, ZoneInfo(settings.STORE_TIME_ZONE)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    stats = {
        "active_orders": orders_qs.count(),
        "riders_online": online.count(),
        "riders_delivering": online.filter(pk__in=list(rider_tasks)).count(),
        "awaiting_assignment": sum(task_counts.get(s, 0) for s in WAITING),
        "to_store": task_counts.get(TS.ASSIGNED, 0),
        "at_store": task_counts.get(TS.AT_STORE, 0),
        "picked_up": task_counts.get(TS.PICKED_UP, 0) + task_counts.get(TS.AT_CUSTOMER, 0),
        "in_transit": task_counts.get(TS.PICKED_UP, 0),
        "delayed": sum(1 for row in deliveries if row["is_delayed"]),
        "completed_today": Order.objects.filter(
            store_id__in=store_ids, status=OrderStatus.DELIVERED, delivered_at__gte=midnight
        ).count(),
    }
    return {
        "generated_at": now,
        "stale_after_seconds": settings.TRACKING_STALE_SECONDS,
        "stores": [
            {
                "id": store.pk,
                "code": store.code,
                "name": store.name,
                "lat": store.location.y,
                "lng": store.location.x,
            }
            for store in store_list
        ],
        "stats": stats,
        "riders": rider_rows,
        "deliveries": deliveries,
        "truncated": truncated,
    }


def progress_message_data(order, task, point, now=None) -> dict:
    """`delivery.progress` on `/ws/ops/live/` (store group): ids, states, distance, live ETA and
    delay. No customer data (06 §4)."""
    from apps.realtime.services import iso

    now = now or timezone.now()
    progress = delivery_progress(order, task, point, now)
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "store_id": order.store_id,
        "task_id": task.pk if task is not None else None,
        "rider_id": task.rider_id if task is not None else None,
        "order_status": order.status,
        "task_status": task.status if task is not None else None,
        "distance_remaining_m": progress["distance_remaining_m"],
        "live_eta_at": iso(progress["live_eta_at"]),
        "live_eta_minutes": progress["live_eta_minutes"],
        "is_delayed": progress["is_delayed"],
        "updated_at": iso(now),
    }
