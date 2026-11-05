"""Seams to Phase 6 (`notifications`, `realtime`, built in parallel in `.worktrees/backend6`).

Delivery code calls ONLY these functions for push and WebSocket side effects; it never builds
its own FCM sender or socket code. Until P6 merges into develop they are thin local stubs that
log. At merge the PM rewires each one to the real function named in its docstring (or replaces
this module with re-exports). Every call site is after commit and must stay best effort.
"""

import logging

logger = logging.getLogger(__name__)


def send_push(user, event: str, data: dict) -> None:
    """-> `apps.notifications.send_push(user, event, data)` (P6). Used in 5.3 for the rider
    offer push and the COD-amount-changed push."""
    logger.info(
        "hooks.send_push (stub until P6): event=%s user=%s", event, getattr(user, "pk", None)
    )


def publish_rider_location(rider_id: int, lat: float, lng: float, recorded_at) -> None:
    """-> `apps.realtime.publish_rider_location(...)` (P6): fan the rider's newest position out
    to the customer tracking and ops map groups. Called from location ingestion."""
    logger.debug("hooks.publish_rider_location (stub until P6): rider=%s", rider_id)


def publish_offer(rider_id: int, offer: dict) -> None:
    """-> `apps.realtime.publish_offer(...)` (P6): `offer.new` on `/ws/v1/rider/`. Called from
    dispatch (slice 5.3)."""
    logger.info("hooks.publish_offer (stub until P6): rider=%s", rider_id)


def ops_alert(kind: str, data: dict) -> None:
    """-> the P6 ops alert (`alert` on `/ws/ops/live/`, 06 §4). Kinds used in slice 5.3:
    `DISPATCH_UNASSIGNED`, `DELIVERY_OTP_LOCKED`, `MOCKED_LOCATION`, `RIDER_STALE_ON_TASK`.
    Until P6 it is logged at WARNING so ops tooling can pick it up from the logs."""
    logger.warning("Ops alert %s: %s", kind, data)
