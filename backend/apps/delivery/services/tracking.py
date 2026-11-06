"""`GET /orders/{id}/track/` body (api-requests #28, #33). The order is already scoped to its
owner by the caller (`orders.services.get_own_order`; another user's order is 404).

- `rider`: the assigned rider (task ASSIGNED, AT_STORE, PICKED_UP, AT_CUSTOMER) while the order
  is active; null before assignment and once the order ended. Position from the rider's latest
  point (Redis, else the row).
- The rider's phone and `delivery_otp`: only while the order is OUT_FOR_DELIVERY (DL-56, user
  decision 2026-11-04); null otherwise. Masked/proxy calling is planned.
"""

from django.conf import settings
from django.utils import timezone

from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import DocumentType
from apps.orders.choices import TERMINAL_STATUSES, OrderStatus
from apps.orders.models import Order

TRACKED_TASK_STATUSES = frozenset({TS.ASSIGNED, TS.AT_STORE, TS.PICKED_UP, TS.AT_CUSTOMER})


def rider_body(order: Order, rider, location: dict | None, photo_url: str | None) -> dict:
    """The `rider` object of `track/` for the order's owner."""
    show_contact = order.status == OrderStatus.OUT_FOR_DELIVERY
    return {
        "name": _short_name(rider.full_name),
        "phone": rider.user.phone if show_contact else None,
        "photo": photo_url,
        "lat": location["lat"] if location else None,
        "lng": location["lng"] if location else None,
        "updated_at": location["recorded_at"] if location else None,
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
    from apps.delivery.models import DeliveryTask

    return (
        DeliveryTask.objects.select_related("rider__user")
        .filter(order=order, status__in=TRACKED_TASK_STATUSES)
        .first()
    )


def track_body(order: Order, now=None) -> dict:
    from apps.delivery.services.shifts import latest_location
    from apps.delivery.services.tasks import delivery_otp

    store = order.store
    finished = order.status in TERMINAL_STATUSES
    task = None if finished else _task(order)
    rider = None
    if task is not None and task.rider_id:
        rider = rider_body(order, task.rider, latest_location(task.rider), _photo_url(task.rider))
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "status": order.status,
        "eta_at": None if finished else order.eta_at,
        "store": {
            "id": store.pk,
            "name": store.name,
            "lat": store.location.y,
            "lng": store.location.x,
        },
        "destination": {"lat": order.delivery_location.y, "lng": order.delivery_location.x},
        "rider": rider,
        "delivery_otp": delivery_otp(task, order),
        "server_time": now or timezone.now(),
    }
