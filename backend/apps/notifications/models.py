"""07 §2.9: notification templates and notifications (the in-app inbox, and the record of every
push and SMS sent for an event)."""

from django.conf import settings
from django.db import models

from apps.accounts.choices import AppName
from apps.core.models import TimeStampedModel
from apps.notifications.choices import Channel, DeliveryStatus, NotificationCategory


class NotificationTemplate(TimeStampedModel):
    """Overrides the built-in text of one event and channel (`apps.notifications.catalog`).

    Text uses `{{placeholder}}` (the event's context keys; unknown ones render empty). An SMS
    must match its DLT-registered template exactly (09 §4, TRAI DLT), so `dlt_template_id` is
    required for SMS: without it the SMS of that event is not sent.
    """

    event = models.CharField(max_length=64, help_text='e.g. "order.placed".')
    channel = models.CharField(max_length=8, choices=Channel.choices)
    app = models.CharField(max_length=16, choices=AppName.choices, default=AppName.CUSTOMER)
    title = models.CharField(max_length=120, blank=True, help_text="Push only.")
    body = models.CharField(max_length=500)
    dlt_template_id = models.CharField(
        max_length=32, blank=True, help_text="SMS only: the TRAI DLT template id."
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["event", "channel", "app"], name="notificationtemplate_unique_event"
            )
        ]

    def __str__(self) -> str:
        return f"{self.event} ({self.channel}, {self.app})"


class Notification(TimeStampedModel):
    """One event for one user: the inbox entry (when `in_inbox`) and the push / SMS sent for it.

    `dedupe_key` makes the event idempotent per (event, user, order): a retried task or a
    replayed domain event finds the row instead of notifying twice. The push and SMS texts can
    hold a delivery OTP, so they are kept only while their channel is not final: blanked when it
    becomes SENT, SKIPPED or FAILED, and by the stuck-send sweeper (`sweep_stuck_sends`) for a
    channel left SENDING by a dead worker. The inbox `title`/`body` never hold an OTP.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    app = models.CharField(max_length=16, choices=AppName.choices)
    event = models.CharField(max_length=64)
    category = models.CharField(max_length=10, choices=NotificationCategory.choices)
    title = models.CharField(max_length=120)
    body = models.CharField(max_length=500)
    data = models.JSONField(
        default=dict, blank=True, help_text="Push data payload: type, ids, `link` (jivo://)."
    )
    order_id = models.PositiveBigIntegerField(null=True, blank=True)
    dedupe_key = models.CharField(max_length=200, unique=True)
    in_inbox = models.BooleanField(default=True)
    read_at = models.DateTimeField(null=True, blank=True)

    push_status = models.CharField(
        max_length=10, choices=DeliveryStatus.choices, default=DeliveryStatus.NONE
    )
    push_title = models.CharField(max_length=120, blank=True)
    push_body = models.CharField(max_length=500, blank=True)
    push_sent_at = models.DateTimeField(null=True, blank=True)
    sms_status = models.CharField(
        max_length=10, choices=DeliveryStatus.choices, default=DeliveryStatus.NONE
    )
    sms_body = models.CharField(max_length=500, blank=True)
    sms_dlt_template_id = models.CharField(max_length=32, blank=True)
    sms_sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(
                fields=["user", "app", "-created_at"],
                condition=models.Q(in_inbox=True),
                name="notification_inbox_idx",
            ),
            models.Index(fields=["created_at"], name="notification_created_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.event} -> user {self.user_id}"

    @property
    def link(self) -> str | None:
        return self.data.get("link") or None

    @property
    def is_read(self) -> bool:
        return self.read_at is not None


__all__ = ["Channel", "DeliveryStatus", "Notification", "NotificationTemplate"]
