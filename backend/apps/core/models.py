from django.db import models


class TimeStampedModel(models.Model):
    """Abstract base: every table has `created_at` and `updated_at` (07 §0)."""

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        get_latest_by = "created_at"


def _append_only():
    from django.core.exceptions import ValidationError

    return ValidationError("The audit log is append-only.")


class AuditLogQuerySet(models.QuerySet):
    def update(self, **kwargs):
        raise _append_only()

    def delete(self):
        raise _append_only()

    def bulk_update(self, objs, fields, batch_size=None):
        raise _append_only()


class AuditLog(models.Model):
    """Who changed what and when (05 §2 Audit log, 07 §2.10): staff actions on orders, stock,
    prices, refunds, riders and config. Append-only; written by `apps.core.audit.record()`.
    `changes` holds before/after values, never personal data (ids, statuses, amounts)."""

    actor = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_entries",
        help_text="Empty for system actions.",
    )
    action = models.CharField(max_length=60, help_text='e.g. "order.cancel", "refund.issue".')
    object_type = models.CharField(max_length=60, help_text='e.g. "orders.order".')
    object_id = models.CharField(max_length=64)
    changes = models.JSONField(default=dict, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = AuditLogQuerySet.as_manager()

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(fields=["object_type", "object_id"], name="auditlog_object_idx"),
            models.Index(fields=["-created_at"], name="auditlog_created_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.action} {self.object_type}:{self.object_id}"

    def save(self, *args, **kwargs):
        if self.pk is not None:
            raise _append_only()
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise _append_only()
