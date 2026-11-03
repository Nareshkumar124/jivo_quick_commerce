"""Payment enums. Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class WebhookResult(models.TextChoices):
    PROCESSED = "processed", "Processed"
    DUPLICATE = "duplicate", "Already processed (same event id): nothing done"
    IGNORED = "ignored", "Event type not handled: nothing done"
