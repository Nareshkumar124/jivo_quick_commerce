from django.db import models


class NotificationCategory(models.TextChoices):
    """07 §2.9 `Notification.category`."""

    ORDER = "order", "Order updates"
    PROMO = "promo", "Offers"
    SYSTEM = "system", "Account and app"
    SUPPORT = "support", "Help and support"  # Phase 7: support ticket replies


class Channel(models.TextChoices):
    PUSH = "PUSH", "Push (FCM)"
    SMS = "SMS", "SMS"


class DeliveryStatus(models.TextChoices):
    """Per channel of one notification. A channel moves PENDING -> SENDING -> SENT / SKIPPED /
    FAILED exactly once, so a retried task never sends twice."""

    NONE = "NONE", "Not requested"
    PENDING = "PENDING", "Queued"
    SENDING = "SENDING", "Sending"
    SENT = "SENT", "Sent"
    SKIPPED = "SKIPPED", "Skipped (no device, no phone or no DLT template)"
    FAILED = "FAILED", "Failed"


FINAL_STATUSES = frozenset({DeliveryStatus.SENT, DeliveryStatus.SKIPPED, DeliveryStatus.FAILED})
