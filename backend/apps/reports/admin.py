"""Report exports in the admin (05 §4, P7; model from backend/phase-7): read-only metadata.

Who may see the list is the model's view permission (Super Admin through the backend roles).
The file itself is never linked from here: a requester downloads their own export from the Ops
reports page through `export_download_url` (a short-lived signed URL, own exports only, after
re-checking the report permission). Rows hold report keys, dates and store ids only.
"""

from django.contrib import admin
from unfold.admin import ModelAdmin

from apps.reports.models import ReportExport


@admin.register(ReportExport)
class ReportExportAdmin(ModelAdmin):
    list_display = ("report", "requested_by_label", "status", "row_count", "created_at")
    list_filter = ("status", "report")
    search_fields = ("=id", "report")
    list_select_related = ("requested_by",)
    ordering = ("-created_at", "-id")
    fields = (
        "report",
        "params",
        "requested_by_label",
        "status",
        "row_count",
        "error",
        "created_at",
        "finished_at",
    )
    readonly_fields = fields

    @admin.display(description="Requested by")
    def requested_by_label(self, obj):
        user = obj.requested_by
        return (user.name or "").strip() or user.email or f"User {user.pk}"

    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False
