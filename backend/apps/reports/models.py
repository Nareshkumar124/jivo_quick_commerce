"""Report exports (05 §4, Phase 7). Reports read the other apps' tables; the only stored rows are
the CSV exports that run in Celery (`apps.reports.services.request_export`). The model also
carries the report permissions (05 §3 "Reports" row)."""

from django.conf import settings
from django.db import models


class ExportStatus(models.TextChoices):
    PENDING = "PENDING", "Queued"
    RUNNING = "RUNNING", "Running"
    DONE = "DONE", "Ready"
    FAILED = "FAILED", "Failed"


def export_upload_to(instance, filename: str) -> str:
    return f"reports/{instance.requested_by_id}/{instance.pk}-{instance.report}.csv"


class ReportExport(models.Model):
    report = models.CharField(max_length=40, help_text="Report key (apps.reports.registry).")
    params = models.JSONField(default=dict, help_text="{start, end, store_id} (IST dates).")
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="report_exports"
    )
    status = models.CharField(
        max_length=8, choices=ExportStatus.choices, default=ExportStatus.PENDING
    )
    file = models.FileField(upload_to=export_upload_to, blank=True, max_length=200)
    row_count = models.PositiveIntegerField(default=0)
    error = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [models.Index(fields=["requested_by", "-created_at"], name="reports_exp_user")]
        permissions = [
            ("view_reports", "Can view sales, order and operations reports and the dashboard"),
            ("view_catalog_reports", "Can view product sales and inventory reports"),
            ("view_finance_reports", "Can view GST and rider earnings / payout reports"),
        ]

    def __str__(self) -> str:
        return f"{self.report} export {self.pk} ({self.status})"
