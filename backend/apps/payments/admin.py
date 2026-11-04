"""Payments admin (05 §2 "Payments & refunds", 05 §3 "Refund"; DL-46): read-only.

- Payments and refunds: `payments.view_payment` / `payments.view_refund` (Super Admin, Support,
  Finance). Scoped to the user's stores through the order (`stores_for`): no store role holds
  these permissions today, so this is fail-closed defence.
- Webhook events: `payments.view_paymentwebhookevent` (Super Admin, Finance).
- Nobody adds, changes or deletes rows here, superusers included: payments and refunds change
  only through the payment services (08 §4), and refunds are started from the order (Phase 4).
- Phase 4 (T-401c): "Retry failed refund" calls `payments.order_refunds.retry_refund(refund_id,
  by=)` (via `ops_console.order_actions`) once per selected refund. The service owns the rules
  (role and scope, failed or stuck-pending refunds only, never twice, audit). Capability
  `retry_refund` = `payments.issue_refund` (Super Admin, Finance, Support).
- `Payment.raw` and `PaymentWebhookEvent.payload` are Razorpay entities holding the customer's
  contact, email, VPA and card details: never rendered. Only allow-listed scalar keys are shown
  (`ops_console.pii.gateway_fields`).
"""

from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.db.models import BooleanField, Value
from django.urls import reverse
from django.utils.html import format_html, format_html_join
from unfold.admin import ModelAdmin
from unfold.decorators import action, display

from apps.ops_console import capabilities, order_actions, status
from apps.ops_console.money import inr
from apps.ops_console.pii import can_view_full_phone, gateway_fields, person_label, webhook_entities
from apps.ops_console.scoping import ScopedStoreFilter, StoreScopedAdminMixin
from apps.payments.models import Payment, PaymentWebhookEvent, Refund


class OrderStoreFilter(ScopedStoreFilter):
    field = "order__store"


class ReadOnlyAdmin(ModelAdmin):
    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}


def order_link(order) -> str:
    """The order page enforces its own permission and store scope."""
    url = reverse("admin:orders_order_change", args=[order.pk])
    return format_html(
        '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>',
        url,
        order.order_number,
    )


def pairs_table(pairs) -> str:
    if not pairs:
        return "-"
    return format_html(
        '<table class="text-sm"><tbody>{}</tbody></table>',
        format_html_join(
            "",
            '<tr><th class="pr-6 py-0.5 text-left font-normal">{}</th>'
            '<td class="py-0.5 font-mono">{}</td></tr>',
            pairs,
        ),
    )


@admin.register(Payment)
class PaymentAdmin(StoreScopedAdminMixin, ReadOnlyAdmin):
    store_field = "order__store"
    list_display = (
        "created_at",
        "order_number",
        "store_code",
        "gateway",
        "method",
        "status_badge",
        "amount_inr",
        "gateway_payment_id",
        "captured_at",
    )
    list_display_links = ("created_at", "order_number")
    list_filter = (
        "status",
        "gateway",
        OrderStoreFilter,
        ("created_at", admin.DateFieldListFilter),
    )
    list_select_related = ("order", "order__store")
    search_fields = ("order__order_number", "gateway_order_id", "gateway_payment_id")
    search_help_text = "Order number, gateway order id or gateway payment id"
    ordering = ("-created_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fieldsets = (
        (
            "Payment attempt",
            {
                "fields": (
                    "order_display",
                    "gateway",
                    "method",
                    "status_badge",
                    "amount_inr",
                    "currency",
                    "created_at",
                    "captured_at",
                )
            },
        ),
        ("Gateway references", {"fields": ("gateway_order_id", "gateway_payment_id")}),
        ("Error", {"fields": ("error_code", "error_description")}),
        (
            "Gateway data (summary)",
            {
                "fields": ("gateway_summary",),
                "description": (
                    "Identifiers, states and amounts (in paise, as the gateway sends them) "
                    "only. The customer's contact, email, UPI id and card details in the "
                    "gateway's data are never shown."
                ),
            },
        ),
    )

    def get_readonly_fields(self, request, obj=None):
        return [name for _title, options in self.fieldsets for name in options["fields"]]

    @display(description="Order", ordering="order__order_number")
    def order_number(self, obj) -> str:
        return obj.order.order_number

    @display(description="Order")
    def order_display(self, obj) -> str:
        return order_link(obj.order)

    @display(description="Store", ordering="order__store__code")
    def store_code(self, obj) -> str:
        return obj.order.store.code

    @display(description="Status", ordering="status", label=status.label_tones(status.PAYMENT))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.PAYMENT, obj.status).label

    @display(description="Amount", ordering="amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Gateway data")
    def gateway_summary(self, obj) -> str:
        return pairs_table(gateway_fields(obj.raw))


@admin.register(Refund)
class RefundAdmin(StoreScopedAdminMixin, ReadOnlyAdmin):
    store_field = "order__store"
    list_display = (
        "created_at",
        "order_number",
        "amount_inr",
        "status_badge",
        "reason",
        "initiated",
        "gateway_refund_id",
        "processed_at",
    )
    list_display_links = ("created_at", "order_number")
    list_filter = (
        "status",
        OrderStoreFilter,
        ("created_at", admin.DateFieldListFilter),
    )
    # Not in get_queryset(): the changelist skips list_select_related when the queryset already
    # has a select_related() (Django), which would bring back one query per row.
    list_select_related = ("order", "initiated_by", "payment")
    search_fields = ("order__order_number", "gateway_refund_id")
    search_help_text = "Order number or gateway refund id"
    ordering = ("-created_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = (
        "order_display",
        "payment_display",
        "amount_inr",
        "status_badge",
        "reason",
        "initiated",
        "gateway_refund_id",
        "idempotency_key",
        "created_at",
        "processed_at",
    )
    readonly_fields = fields
    actions = ["retry_failed"]

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(
                full_pii=Value(can_view_full_phone(request.user), output_field=BooleanField())
            )
        )

    # ---------------------------------------------------------------- retry (T-401c)

    def get_actions(self, request):
        # ReadOnlyAdmin drops every action; this one is a service call, not an edit.
        actions = ModelAdmin.get_actions(self, request)
        actions.pop("delete_selected", None)
        return actions

    def has_retry_permission(self, request) -> bool:
        return capabilities.allowed(
            request.user, capabilities.RETRY_REFUND
        ) and order_actions.available(order_actions.RETRY_REFUND)

    @action(description="Retry failed refund (send to the gateway again)", permissions=["retry"])
    def retry_failed(self, request, queryset):
        if not self.has_retry_permission(request):
            raise PermissionDenied
        sent = 0
        skipped: dict[str, int] = {}

        def skip(reason: str) -> None:
            skipped[reason] = skipped.get(reason, 0) + 1

        # `queryset` is the changelist's, already scoped to the user's stores. The service
        # checks the role, scope, state (failed, or stuck pending) and earlier retries under
        # lock, and writes the audit entry; the panel only reports its answers.
        for refund in queryset.order_by("pk"):
            try:
                order_actions.retry_refund(refund, actor=request.user)
            except order_actions.ActionRefused as refusal:
                skip(refusal.message)
                continue
            sent += 1
        self.message_user(request, f"Sent {sent} refund(s) to the gateway again.", messages.SUCCESS)
        for reason, count in skipped.items():
            self.message_user(request, f"Skipped {count} refund(s): {reason}", messages.WARNING)

    @display(description="Order", ordering="order__order_number")
    def order_number(self, obj) -> str:
        return obj.order.order_number

    @display(description="Order")
    def order_display(self, obj) -> str:
        return order_link(obj.order)

    @display(description="Payment")
    def payment_display(self, obj) -> str:
        payment = obj.payment
        reference = payment.gateway_payment_id or payment.gateway_order_id or f"#{payment.pk}"
        url = reverse("admin:payments_payment_change", args=[payment.pk])
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}">{} {}</a>',
            url,
            payment.get_gateway_display(),
            reference,
        )

    @display(description="Amount", ordering="amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Status", ordering="status", label=status.label_tones(status.REFUND))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.REFUND, obj.status).label

    @display(description="Initiated by")
    def initiated(self, obj) -> str:
        if obj.initiated_by_id is None:
            return "Automatic"
        return person_label(obj.initiated_by, full=bool(getattr(obj, "full_pii", False)))


class ProcessedFilter(admin.SimpleListFilter):
    title = "processing"
    parameter_name = "processing"

    def lookups(self, request, model_admin):
        return [
            ("done", "Processed"),
            ("error", "With an error"),
            ("waiting", "Not processed yet"),
        ]

    def queryset(self, request, queryset):
        value = self.value()
        if value == "done":
            return queryset.filter(processed_at__isnull=False)
        if value == "error":
            return queryset.exclude(error="")
        if value == "waiting":
            return queryset.filter(processed_at__isnull=True)
        return queryset


@admin.register(PaymentWebhookEvent)
class PaymentWebhookEventAdmin(ReadOnlyAdmin):
    """Signed gateway events, one per `event_id` (08 §4 rule 2). Finance and Super Admin."""

    list_display = ("created_at", "event_type", "event_id", "processed_at", "has_error")
    list_display_links = ("created_at", "event_type")
    list_filter = (ProcessedFilter, "event_type", ("created_at", admin.DateFieldListFilter))
    search_fields = ("event_id",)
    search_help_text = "Event id (X-Razorpay-Event-Id)"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fieldsets = (
        (
            "Event",
            {"fields": ("event_id", "event_type", "signature_valid", "created_at", "processed_at")},
        ),
        ("Processing error", {"fields": ("error",)}),
        (
            "Payload (summary)",
            {
                "fields": ("payload_summary",),
                "description": (
                    "Identifiers, amounts (in paise, as the gateway sends them) and states only. "
                    "The customer's contact, email, UPI id and card details are never shown."
                ),
            },
        ),
    )

    def get_readonly_fields(self, request, obj=None):
        return [name for _title, options in self.fieldsets for name in options["fields"]]

    @display(description="Error", boolean=True)
    def has_error(self, obj) -> bool:
        return bool(obj.error)

    @display(description="Payload")
    def payload_summary(self, obj) -> str:
        entities = webhook_entities(obj.payload)
        if not entities:
            return "-"
        return format_html_join(
            "",
            '<p class="font-semibold mt-2">{}</p>{}',
            ((name, pairs_table(fields)) for name, fields in entities),
        )
