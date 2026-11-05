"""Seams to Phase 6 (`notifications`, `realtime`).

Delivery code calls ONLY these functions for push and WebSocket side effects; it never builds
its own FCM sender or socket code. Since the P6 merge they call the real functions. Every call
site is after commit, and each hook is best effort: a failure is logged, never raised into the
delivery flow (apps fall back to polling, and FCM is retried by its own task).
"""

import logging

from django.apps import apps
from django.core.exceptions import FieldError

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
