"""Notifications admin (05 §2 "Notifications", P6; 08 §9).

- **Notifications** (inbox entries and the push / SMS sent for each event): read only for
  everyone, superusers included. Nobody adds, changes or deletes a row here: rows are written by
  `apps.notifications.services.notify()` and its delivery tasks. Gated on
  `notifications.view_notification` (no role holds it yet: superusers only until the backend
  grants it, see the P6 admin report).
- **No resend action**: the backend has no resend service yet (a channel moves to a final state
  exactly once, so a resend needs a new service, not a status edit here).
- **PII**: the recipient is shown as "User <id>" plus a masked phone, for every role. The push
  and SMS texts (`push_body`, `sms_body`) and the inbox `body` can hold a delivery OTP, so they
  are never rendered (the inbox title only); neither are `data` (only its `link`) nor
  `dedupe_key`.
- **Store scoping** (fail closed): a store-scoped user sees only notifications of orders in
  their stores (`stores_for`), never account or rider notifications.
- **Templates** (`NotificationTemplate`, 08 §9 text overrides): editable with the model
  permissions (`notifications.*_notificationtemplate`). Every add, change and delete writes
  `core.AuditLog` (changed field names only, never the text). An SMS template needs its DLT
  template id (TRAI DLT, 09 §4).
"""

from django import forms
from django.contrib import admin
from django.db import transaction
from django.db.models import Q
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.notifications.catalog import SPECS
from apps.notifications.choices import Channel, DeliveryStatus
from apps.notifications.models import Notification, NotificationTemplate
from apps.ops_console.pii import mask_phone
from apps.ops_console.scoping import is_store_scoped, visible_stores

DELIVERY_TONES = {
    DeliveryStatus.NONE.label: "neutral",
    DeliveryStatus.PENDING.label: "info",
    DeliveryStatus.SENDING.label: "warning",
    DeliveryStatus.SENT.label: "success",
    DeliveryStatus.SKIPPED.label: "neutral",
    DeliveryStatus.FAILED.label: "danger",
}


def delivery_label(value: str) -> str:
    try:
        return DeliveryStatus(value).label
    except ValueError:
        return value or "-"


class StuckSendFilter(admin.SimpleListFilter):
    """Sends that are not final: queued or sending (a dead worker leaves SENDING until the
    stuck-send sweeper runs), or failed."""

    title = "needs attention"
    parameter_name = "attention"

    def lookups(self, request, model_admin):
        return (("in_flight", "Queued or sending"), ("failed", "Failed (push or SMS)"))

    def queryset(self, request, queryset):
        in_flight = (DeliveryStatus.PENDING, DeliveryStatus.SENDING)
        if self.value() == "in_flight":
            return queryset.filter(Q(push_status__in=in_flight) | Q(sms_status__in=in_flight))
        if self.value() == "failed":
            failed = DeliveryStatus.FAILED
            return queryset.filter(Q(push_status=failed) | Q(sms_status=failed))
        return queryset


@admin.register(Notification)
class NotificationAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "event",
        "app",
        "recipient",
        "order_display",
        "push_badge",
        "sms_badge",
        "inbox_state",
    )
    list_display_links = ("created_at", "event")
    list_filter = (
        StuckSendFilter,
        "push_status",
        "sms_status",
        "app",
        "category",
        "event",
        ("created_at", admin.DateFieldListFilter),
    )
    list_select_related = ("user",)
    search_fields = ("event", "=order_id", "=user__id")
    search_help_text = "Event (e.g. order.placed), order id or user id"
    ordering = ("-created_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fieldsets = (
        (
            "Event",
            {"fields": ("event", "app", "category", "recipient", "order_display", "link")},
        ),
        (
            "Inbox",
            {
                "fields": ("in_inbox", "title", "read_at"),
                "description": "The inbox text is not shown: it can carry a delivery OTP.",
            },
        ),
        (
            "Delivery",
            {
                "fields": (
                    "push_badge",
                    "push_sent_at",
                    "sms_badge",
                    "sms_dlt_template_id",
                    "sms_sent_at",
                ),
                "description": "Each channel moves Queued -> Sending -> Sent / Skipped / Failed "
                "once. Push and SMS texts are not shown: they can hold a delivery OTP.",
            },
        ),
        ("Record", {"fields": ("created_at", "updated_at")}),
    )
    readonly_fields = (
        "event",
        "app",
        "category",
        "recipient",
        "order_display",
        "link",
        "in_inbox",
        "title",
        "read_at",
        "push_badge",
        "push_sent_at",
        "sms_badge",
        "sms_dlt_template_id",
        "sms_sent_at",
        "created_at",
        "updated_at",
    )

    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        if is_store_scoped(request.user):
            from apps.orders.models import Order

            order_ids = Order.objects.filter(store__in=visible_stores(request.user)).values("pk")
            queryset = queryset.filter(order_id__in=order_ids)
        return queryset

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    @display(description="Recipient")
    def recipient(self, obj) -> str:
        phone = mask_phone(getattr(obj.user, "phone", None))
        return f"User {obj.user_id}, {phone}" if phone else f"User {obj.user_id}"

    @display(description="Order", ordering="order_id")
    def order_display(self, obj) -> str:
        if not obj.order_id:
            return "-"
        # The order page enforces its own permission and store scope.
        url = reverse("admin:orders_order_change", args=[obj.order_id])
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}">#{}</a>',
            url,
            obj.order_id,
        )

    @display(description="Push", ordering="push_status", label=DELIVERY_TONES)
    def push_badge(self, obj) -> str:
        return delivery_label(obj.push_status)

    @display(description="SMS", ordering="sms_status", label=DELIVERY_TONES)
    def sms_badge(self, obj) -> str:
        return delivery_label(obj.sms_status)

    @display(description="Inbox")
    def inbox_state(self, obj) -> str:
        if not obj.in_inbox:
            return "-"
        return "Read" if obj.read_at else "Unread"

    @display(description="Link")
    def link(self, obj) -> str:
        return obj.link or "-"


# --------------------------------------------------------------------------- templates


def event_choices() -> list[tuple[str, str]]:
    return [(event, event) for event in sorted(SPECS)]


class NotificationTemplateForm(forms.ModelForm):
    event = forms.ChoiceField(choices=event_choices, help_text="An event of the 08 §9 catalog.")

    class Meta:
        model = NotificationTemplate
        fields = ("event", "channel", "app", "title", "body", "dlt_template_id", "is_active")

    def clean(self):
        cleaned = super().clean()
        channel = cleaned.get("channel")
        if channel == Channel.SMS and not (cleaned.get("dlt_template_id") or "").strip():
            self.add_error(
                "dlt_template_id",
                "An SMS template needs its TRAI DLT template id; without it the SMS is not sent.",
            )
        if channel == Channel.SMS and (cleaned.get("title") or "").strip():
            self.add_error("title", "SMS has no title. Leave it empty.")
        return cleaned


@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(ModelAdmin):
    form = NotificationTemplateForm
    list_display = ("event", "channel", "app", "is_active", "dlt_template_id", "updated_at")
    list_filter = ("channel", "app", "is_active")
    search_fields = ("event",)
    ordering = ("event", "channel", "app")
    list_per_page = 50
    readonly_fields = ("built_in_text",)
    fieldsets = (
        (None, {"fields": ("event", "channel", "app", "is_active")}),
        (
            "Text",
            {
                "fields": ("title", "body", "dlt_template_id", "built_in_text"),
                "description": "Use {{placeholder}} names from the event's context; unknown "
                "names render empty. An SMS must match its DLT-registered text exactly.",
            },
        ),
    )

    @display(description="Built-in text")
    def built_in_text(self, obj) -> str:
        spec = SPECS.get(getattr(obj, "event", "") or "")
        if spec is None:
            return "-"
        if getattr(obj, "channel", None) == Channel.SMS:
            return spec.sms or "(this event sends no SMS)"
        return f"{spec.title}: {spec.body}"

    def save_model(self, request, obj, form, change):
        from apps.core import audit

        with transaction.atomic():
            super().save_model(request, obj, form, change)
            audit.record(
                request.user,
                "notification_template.change" if change else "notification_template.add",
                obj,
                {"fields": sorted(form.changed_data), "is_active": obj.is_active},
                ip=request.META.get("REMOTE_ADDR"),
            )

    def delete_model(self, request, obj):
        from apps.core import audit

        with transaction.atomic():
            audit.record(
                request.user,
                "notification_template.delete",
                obj,
                {"event": obj.event, "channel": obj.channel, "app": obj.app},
                ip=request.META.get("REMOTE_ADDR"),
            )
            super().delete_model(request, obj)

    def delete_queryset(self, request, queryset):
        from apps.core import audit

        with transaction.atomic():
            for obj in queryset:
                audit.record(
                    request.user,
                    "notification_template.delete",
                    obj,
                    {"event": obj.event, "channel": obj.channel, "app": obj.app},
                    ip=request.META.get("REMOTE_ADDR"),
                )
            super().delete_queryset(request, queryset)
