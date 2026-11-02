from django.db import models


class TimeStampedModel(models.Model):
    """Abstract base: every table has `created_at` and `updated_at` (07 §0)."""

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        get_latest_by = "created_at"
