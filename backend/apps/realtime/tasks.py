"""Real-time Celery tasks (06 §5 `broadcast_ws`, `purge_old_locations`). All idempotent: a
message carries current state, so a retry that sends it twice is harmless."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(
    name="realtime.broadcast_ws",
    autoretry_for=(Exception,),
    retry_backoff=1,
    retry_backoff_max=10,
    max_retries=3,
)
def broadcast_ws(groups: list[str], body: dict) -> int:
    from apps.realtime.services import send_now

    send_now(groups, body)
    return len(groups)


@shared_task(
    name="realtime.publish_order_event",
    autoretry_for=(Exception,),
    retry_backoff=1,
    retry_backoff_max=10,
    max_retries=3,
)
def publish_order_event(event: str, order_id: int) -> list[str]:
    """The socket side of an order domain event (apps.orders.tasks.order_event)."""
    from apps.realtime import services

    return services.publish_order_event(event, order_id)


@shared_task(name="realtime.publish_rider_location", max_retries=0)
def publish_rider_location_task(
    rider_id: int, lat: float, lng: float, recorded_at: str, **kwargs
) -> list[str]:
    """Not retried: the next ping (seconds later) supersedes this one."""
    from apps.realtime import services

    return services.send_rider_location(rider_id, lat, lng, recorded_at, **kwargs)


_RETRIED = {
    "autoretry_for": (Exception,),
    "retry_backoff": 1,
    "retry_backoff_max": 10,
    "max_retries": 3,
}


@shared_task(name="realtime.publish_order_eta", **_RETRIED)
def publish_order_eta_task(order_id: int) -> bool:
    """`order.eta` after a delivery task status change (08 §8). Sends the ETA as of now."""
    from apps.realtime import services

    return services.send_order_eta(order_id)


@shared_task(name="realtime.publish_cash", **_RETRIED)
def publish_cash_task(rider_id: int, reason: str) -> bool:
    """`cash.updated`: the rider's cash as it is now (a repeat sends the same state)."""
    from apps.realtime import services

    return services.send_cash_updated(rider_id, reason)


@shared_task(name="realtime.publish_rider_presence", **_RETRIED)
def publish_rider_presence_task(rider_id: int) -> bool:
    """`rider.status` (ops): online and on-task as they are now."""
    from apps.realtime import services

    return services.send_rider_presence(rider_id)


@shared_task(name="realtime.publish_notification_new", **_RETRIED)
def publish_notification_new_task(notification_id: int) -> bool:
    """`notification.new` (api-requests #47): the entry and the unread count as they are now."""
    from apps.realtime import services

    return services.send_notification_new(notification_id)


@shared_task(name="realtime.purge_old_locations")
def purge_old_locations() -> int:
    """Beat, daily: delete rider locations older than RIDER_LOCATION_RETENTION_DAYS."""
    from apps.realtime import services

    deleted = services.purge_old_locations()
    logger.info("Purged %s old rider location(s)", deleted)
    return deleted
