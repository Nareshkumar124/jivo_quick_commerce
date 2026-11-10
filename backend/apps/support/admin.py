"""Support tickets in the admin (05 §2 Support, P7): read-only records for Super Admin, Ops and
Support (`support.view_supportticket`). Replies, status, priority and assignment happen in the
Ops support console (`/ops/support/`), which calls `apps.support.services`; nothing here saves a
ticket or a message. Message bodies are personal data: shown to these roles only, never in the
list or search (search is by ticket id or order number).
"""

from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from apps.ops_console import status
from apps.support.models import CannedReply, SupportTicket, TicketAttachment, TicketMessage


class ReadOnlyMixin:
    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False


class TicketMessageInline(ReadOnlyMixin, TabularInline):
    model = TicketMessage
    extra = 0
    fields = ("created_at", "is_staff", "sender_label", "body")
    readonly_fields = fields
    ordering = ("created_at", "id")
    show_change_link = False

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("sender")

    @admin.display(description="From")
    def sender_label(self, obj):
        if not obj.is_staff:
            return "Customer"
        sender = obj.sender
        if sender is None:
            return "Support"
        return (sender.name or "").strip() or sender.email or f"User {sender.pk}"


@admin.register(SupportTicket)
class SupportTicketAdmin(ReadOnlyMixin, ModelAdmin):
    list_display = (
        "number_link",
        "subject",
        "status_label",
        "priority_label",
        "category",
        "app",
        "assigned_label",
        "last_activity_at",
    )
    list_filter = ("status", "priority", "category", "app")
    search_fields = ("=id", "order__order_number")
    search_help_text = "Ticket id (number without TK-) or order number."
    ordering = ("-last_activity_at", "-id")
    list_select_related = ("order", "assigned_to")
    list_per_page = 50
    show_full_result_count = False
    inlines = [TicketMessageInline]
    fields = (
        "console_link",
        "customer",
        "app",
        "category",
        "subject",
        "order",
        "status",
        "priority",
        "assigned_label",
        "last_activity_at",
        "resolved_at",
        "closed_at",
        "created_at",
    )
    readonly_fields = fields

    @display(description="Ticket", ordering="id")
    def number_link(self, obj):
        return format_html(
            '<a href="{}">{}</a>',
            reverse("admin:support_supportticket_change", args=[obj.pk]),
            obj.number,
        )

    @display(description="Status", label=status.label_tones(status.TICKET))
    def status_label(self, obj):
        return status.badge_for(status.TICKET, obj.status).label

    @display(description="Priority", label=status.label_tones(status.TICKET_PRIORITY))
    def priority_label(self, obj):
        return status.badge_for(status.TICKET_PRIORITY, obj.priority).label

    @display(description="Assigned to")
    def assigned_label(self, obj):
        user = obj.assigned_to
        if user is None:
            return "Unassigned"
        return (user.name or "").strip() or user.email or f"User {user.pk}"

    @display(description="Customer")
    def customer(self, obj):
        """By id, linked to the Customers admin, which applies its own PII rules (05 §3)."""
        return format_html(
            '<a href="{}">Customer {}</a>',
            reverse("admin:accounts_customer_change", args=[obj.user_id]),
            obj.user_id,
        )

    @display(description="Support console")
    def console_link(self, obj):
        return format_html(
            '<a class="text-primary-600" href="{}">Reply or update in the support console</a>',
            reverse("ops:support-ticket", args=[obj.pk]),
        )


# --------------------------------------------------------------------------- P7 models
@admin.register(CannedReply)
class CannedReplyAdmin(ModelAdmin):
    """05 §2 Support "canned replies": plain text with {{ticket_number}} and
    {{order_number}} placeholders (filled by `services.render_canned_reply`). Who may add or
    change them is the model permission (backend roles)."""

    list_display = ("title", "category", "sort_order", "is_active", "updated_at")
    list_editable = ("sort_order", "is_active")
    list_filter = ("is_active", "category")
    search_fields = ("title",)
    ordering = ("sort_order", "title")
    fields = ("title", "category", "body", "sort_order", "is_active")


@admin.register(TicketAttachment)
class TicketAttachmentAdmin(ReadOnlyMixin, ModelAdmin):
    """Customer photos on tickets: metadata only, read-only. The image opens from the Ops
    support console through a short-lived signed URL (`staff_attachment_url`), never from a
    stored link here (private bucket, 09)."""

    list_display = ("key", "ticket_link", "size", "created_at")
    search_fields = ("=ticket__id", "=key")
    list_select_related = ("ticket",)
    ordering = ("-created_at", "-id")
    fields = ("key", "ticket_link", "size", "created_at")
    readonly_fields = fields

    @display(description="Ticket")
    def ticket_link(self, obj):
        return format_html(
            '<a href="{}">{}</a>',
            reverse("ops:support-ticket", args=[obj.ticket_id]),
            obj.ticket.number,
        )
