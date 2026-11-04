"""Notification Celery tasks (06 §5 `send_push` / `send_sms`). All idempotent: each channel of a
notification is claimed once (apps.notifications.services), so a retry never sends twice."""

import logging

from celery import shared_task

from apps.notifications.choices import Channel
from apps.notifications.push import PushError
from apps.notifications.sms import SmsError

logger = logging.getLogger(__name__)

MAX_RETRIES = 5


def _deliver(task, channel: str, notification_id: int, deliver) -> str:
    from apps.notifications import services

    try:
        return deliver(notification_id)
    except (PushError, SmsError) as exc:
        if task.request.retries >= MAX_RETRIES:
            logger.error(
                "%s for notification %s failed after %s retries",
                channel,
                notification_id,
                MAX_RETRIES,
            )
            services.fail(notification_id, channel)
            return "failed"
        raise task.retry(exc=exc, countdown=min(2 ** (task.request.retries + 1), 300)) from exc


@shared_task(bind=True, name="notifications.send_push", max_retries=MAX_RETRIES)
def send_push_task(self, notification_id: int) -> str:
    from apps.notifications import services

    return _deliver(self, Channel.PUSH, notification_id, services.deliver_push)


@shared_task(bind=True, name="notifications.send_sms", max_retries=MAX_RETRIES)
def send_sms_task(self, notification_id: int) -> str:
    from apps.notifications import services

    return _deliver(self, Channel.SMS, notification_id, services.deliver_sms)


@shared_task(
    bind=True,
    name="notifications.notify_order_event",
    autoretry_for=(Exception,),
    retry_backoff=2,
    max_retries=3,
)
def notify_order_event(self, event: str, order_id: int) -> str:
    """The customer notification of an order domain event (08 §9). Idempotent (dedupe key)."""
    from apps.notifications import services

    notification = services.notify_order_event(event, order_id)
    return "notified" if notification is not None else "none"


@shared_task(name="notifications.sweep_stuck_sends")
def sweep_stuck_sends() -> int:
    """Beat, every 15 minutes: channels stuck SENDING -> FAILED, texts blanked, alert logged."""
    from apps.notifications import services

    return services.sweep_stuck_sends()


@shared_task(name="notifications.purge_old_notifications")
def purge_old_notifications() -> int:
    """Beat, daily: delete inbox entries older than NOTIFICATION_RETENTION_DAYS."""
    from apps.notifications import services

    deleted = services.purge_old_notifications()
    logger.info("Purged %s old notification(s)", deleted)
    return deleted
