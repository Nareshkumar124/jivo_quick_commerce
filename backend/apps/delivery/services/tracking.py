"""`GET /orders/{id}/track/` body (api-requests #28). The order is already scoped to its owner
by the caller (`orders.services`). Slice 5.3 fills `rider` (from the delivery task, ASSIGNED
until the order ends) and `delivery_otp` (only while OUT_FOR_DELIVERY)."""

from django.utils import timezone

from apps.orders.choices import TERMINAL_STATUSES, OrderStatus
from apps.orders.models import Order


def rider_body(order: Order, rider, location: dict | None, photo_url: str | None) -> dict:
    """The `rider` object of `track/` for the order's owner (the caller scoped the order).
    The rider's phone only while OUT_FOR_DELIVERY (user decision 2026-11-04; the same rule
    applies to `delivery_otp`); masked/proxy calling is planned."""
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


def track_body(order: Order, now=None) -> dict:
    store = order.store
    finished = order.status in TERMINAL_STATUSES
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
        "rider": None,  # slice 5.3: rider_body(order, task.rider, ...) while a task is assigned
        "delivery_otp": None,  # slice 5.3: only while OUT_FOR_DELIVERY
        "server_time": now or timezone.now(),
    }
