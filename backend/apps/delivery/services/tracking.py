"""`GET /orders/{id}/track/` body (api-requests #28). The order is already scoped to its owner
by the caller (`orders.services`). Slice 5.3 fills `rider` (from the delivery task, ASSIGNED
until the order ends) and `delivery_otp` (only while OUT_FOR_DELIVERY)."""

from django.utils import timezone

from apps.orders.choices import TERMINAL_STATUSES
from apps.orders.models import Order


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
        "rider": None,  # slice 5.3: the assigned rider while the order is active
        "delivery_otp": None,  # slice 5.3: only while OUT_FOR_DELIVERY
        "server_time": now or timezone.now(),
    }
