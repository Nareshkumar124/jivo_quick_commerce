"""`GET /orders/{id}/track/` body (api-requests #28, #33). The order is already scoped to its
owner by the caller (`orders.services.get_own_order`; another user's order is 404).

- `rider`: the assigned rider (task ASSIGNED, AT_STORE, PICKED_UP, AT_CUSTOMER) while the order
  is active; null before assignment and once the order ended. Position from the rider's latest
  point (Redis, else the row).
- The rider's phone and `delivery_otp`: only while the order is OUT_FOR_DELIVERY (DL-56, user
  decision 2026-11-04); null otherwise. Masked/proxy calling is planned.
- T-821 (additive): the rider's `heading`, `is_stale` and `vehicle_type`; `route` (encoded
  polyline of the current leg, road distance and duration), `distance_remaining_m` and the
  8-step `progress` (`apps.delivery.services.live_tracking`). No new personal data: the rider's
  vehicle number is never shown.
"""

from django.conf import settings
from django.utils import timezone

from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import DocumentType
from apps.orders.choices import TERMINAL_STATUSES, OrderStatus
from apps.orders.models import Order

TRACKED_TASK_STATUSES = frozenset({TS.ASSIGNED, TS.AT_STORE, TS.PICKED_UP, TS.AT_CUSTOMER})


def rider_body(order: Order, rider, location: dict | None, photo_url: str | None, now=None) -> dict:
    """The `rider` object of `track/` for the order's owner."""
    from apps.delivery.services.live_tracking import is_stale

    show_contact = order.status == OrderStatus.OUT_FOR_DELIVERY
    recorded_at = location["recorded_at"] if location else None
    return {
        "name": _short_name(rider.full_name),
        "phone": rider.user.phone if show_contact else None,
        "photo": photo_url,
        "vehicle_type": rider.vehicle_type or None,
        "lat": location["lat"] if location else None,
        "lng": location["lng"] if location else None,
        "heading": location.get("heading") if location else None,
        "updated_at": recorded_at,
        "is_stale": is_stale(recorded_at, now),
    }


def _short_name(full_name: str) -> str:
    """ "Ravi Kumar" -> "Ravi K." (privacy)."""
    parts = full_name.split()
    if len(parts) < 2:
        return full_name
    return f"{parts[0]} {parts[-1][0]}."


def _photo_url(rider) -> str | None:
    from apps.delivery.services.presenters import signed_url

    document = rider.documents.filter(doc_type=DocumentType.PHOTO).first()
    if document is None or not document.file:
        return None
    return signed_url(document.file.name, settings.RIDER_PHOTO_URL_EXPIRY_SECONDS)


def _task(order: Order):
    """The order's delivery task in any state (one per order), with its rider, or None."""
    from apps.delivery.models import DeliveryTask

    return DeliveryTask.objects.select_related("rider__user").filter(order=order).first()


def track_body(order: Order, now=None) -> dict:
    from apps.delivery.services import eta as eta_service
    from apps.delivery.services import live_tracking
    from apps.delivery.services.shifts import latest_location
    from apps.delivery.services.tasks import delivery_otp

    now = now or timezone.now()
    store = order.store
    finished = order.status in TERMINAL_STATUSES
    any_task = _task(order)
    task = any_task if any_task is not None and any_task.status in TRACKED_TASK_STATUSES else None
    if finished:
        task = None
    rider = None
    point = None
    if task is not None and task.rider_id:
        location = latest_location(task.rider)
        rider = rider_body(order, task.rider, location, _photo_url(task.rider), now)
        point = (location["lat"], location["lng"]) if location else None
    tracked = live_tracking.rider_route(task, order, point, now) if task is not None else None
    live = None if finished else eta_service.compute(order, task, point, now=now)
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "status": order.status,
        "eta_at": None if finished else order.eta_at,
        "live_eta_at": live.eta_at if live else None,
        "live_eta_minutes": live.minutes if live else None,
        "store": {
            "id": store.pk,
            "name": store.name,
            "lat": store.location.y,
            "lng": store.location.x,
        },
        "destination": {"lat": order.delivery_location.y, "lng": order.delivery_location.x},
        "rider": rider,
        "delivery_otp": delivery_otp(task, order),
        "task_status": any_task.status if any_task is not None else None,
        "route": live_tracking.route_body(task, tracked),
        "distance_remaining_m": live_tracking.distance_remaining_m(order, task, tracked, now),
        "progress": live_tracking.progress(order, any_task, point),
        "server_time": now,
    }
