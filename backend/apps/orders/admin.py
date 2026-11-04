"""Orders admin (05 §2 "Orders"). Phase 3: **read-only** list and detail; the order actions
(cancel, refund, notes) arrive in Phase 4 and go through `orders.services.transition()` and the
refund services, never through this form.

- Who: `orders.view_order` (Super Admin, Ops, Store Manager, Store Staff, Support, Finance;
  DL-46). Nobody adds, edits or deletes an order here, superusers included.
- Store scoping: Store Manager / Store Staff see only their stores (`stores_for`); another
  store's order is a 404 (change and history pages) and never listed.
- Display methods never share a model field's name (Django would render the field instead).
- PII (05 §3 "Customers (PII)", `ops_console.pii`): roles with `accounts.view_customer` (Super
  Admin, Ops, Support) see the customer and delivery address in full and may search by phone.
  Everyone else (Store Manager, Store Staff, Finance) sees the name and a masked phone, the
  address locality only (no house, street, landmark or pin), no free-text note, and searches by
  order number or coupon code only. Free text written by the customer (delivery note, cancel
  note, timeline note) is hidden from them too. `str(user)` (the phone) is never rendered.
- Money is shown exactly as stored at placement (`compute_bill()` snapshot, 08 §6.2); nothing is
  added up here.
- Payments and refunds appear on the order only for roles that may view them
  (`payments.view_payment` / `payments.view_refund`). Gateway payloads are never shown.
"""

from django.contrib import admin
from django.db.models import BooleanField, Value
from django.urls import reverse
from django.utils.html import format_html, format_html_join
from django.utils.safestring import mark_safe
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from apps.ops_console import status
from apps.ops_console.money import inr
from apps.ops_console.pii import address_lines, can_view_full_phone, customer_label, person_label
from apps.ops_console.scoping import ScopedStoreFilter, StoreScopedAdminMixin
from apps.orders.choices import ActorType
from apps.orders.models import Order, OrderItem, OrderStatusHistory
from apps.payments.models import Payment, Refund

# 08 §6.2, in the order the customer's bill shows them.
BILL_ROWS = (
    ("mrp_total", "MRP total"),
    ("item_total", "Item total (selling prices)"),
    ("product_discount", "Product discount (MRP total less item total)"),
    ("coupon_discount", "Coupon discount"),
    ("delivery_fee", "Delivery fee"),
    ("small_cart_fee", "Small-cart fee"),
    ("handling_fee", "Handling fee"),
    ("tip", "Rider tip"),
    ("grand_total", "Grand total (amount payable)"),
    ("amount_refunded", "Amount refunded so far"),
)

FULL_SEARCH = ("user__phone", "address_snapshot__receiver_phone")
BASIC_SEARCH = ("order_number", "coupon_code")


def with_pii_flag(queryset, user):
    """List columns and inline cells do not receive the request: the PII decision travels on
    each row instead."""
    return queryset.annotate(full_pii=Value(can_view_full_phone(user), output_field=BooleanField()))


def _full(obj) -> bool:
    return bool(getattr(obj, "full_pii", False))


HIDDEN_NOTE = "(customer's note, hidden for your role)"


def customer_text(text: str, *, by_customer: bool, full: bool) -> str:
    """Free text a customer wrote (a cancel note, a timeline note) may hold a phone number or an
    address: full-PII roles only. Notes by staff, riders or the system are shown to everyone."""
    text = (text or "").strip()
    if not text:
        return "-"
    return text if full or not by_customer else HIDDEN_NOTE


class OrderDateFilter(admin.DateFieldListFilter):
    """Created today / last 7 days / this month / this year, in IST (staff time zone)."""

    def __init__(self, field, request, params, model, model_admin, field_path):
        super().__init__(field, request, params, model, model_admin, field_path)
        self.title = "order date (IST)"


class CustomerFilter(admin.SimpleListFilter):
    """`?customer=<user id>`: the "See all orders" link on a customer page. Shown only while it
    is in use (as "This customer", never a name or phone); it only narrows the already
    store-scoped list."""

    title = "customer"
    parameter_name = "customer"

    def lookups(self, request, model_admin):
        value = request.GET.get(self.parameter_name, "")
        return [(value, "This customer")] if value else []

    def has_output(self) -> bool:
        return bool(self.value())  # Django applies only the filters that have output

    def queryset(self, request, queryset):
        value = self.value()
        if not value:
            return queryset
        if not value.isdigit():
            return queryset.none()
        return queryset.filter(user_id=int(value))


class ReadOnlyInline(TabularInline):
    extra = 0
    can_delete = False
    show_change_link = False

    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False


class OrderItemInline(ReadOnlyInline):
    model = OrderItem
    fields = (
        "product_name",
        "variant_name",
        "sku",
        "hsn_code",
        "gst_rate",
        "mrp_inr",
        "price_inr",
        "quantity",
        "quantity_unavailable",
        "line_total_inr",
    )
    readonly_fields = fields
    verbose_name_plural = "Items (names and prices as ordered)"

    @display(description="MRP")
    def mrp_inr(self, obj) -> str:
        return inr(obj.mrp)

    @display(description="Selling price")
    def price_inr(self, obj) -> str:
        return inr(obj.selling_price)

    @display(description="Line total")
    def line_total_inr(self, obj) -> str:
        return inr(obj.line_total)


class PaymentInline(ReadOnlyInline):
    """Visible with `payments.view_payment` only (Django checks the inline model's permission)."""

    model = Payment
    fields = (
        "created_at",
        "gateway",
        "method",
        "status_badge",
        "amount_inr",
        "gateway_order_id",
        "gateway_payment_id",
        "captured_at",
        "error",
    )
    readonly_fields = fields
    ordering = ("created_at", "id")
    verbose_name_plural = "Payment attempts"

    @display(description="Status", label=status.label_tones(status.PAYMENT))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.PAYMENT, obj.status).label

    @display(description="Amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Error")
    def error(self, obj) -> str:
        return " ".join(part for part in (obj.error_code, obj.error_description) if part) or "-"


class RefundInline(ReadOnlyInline):
    """Visible with `payments.view_refund` only."""

    model = Refund
    fk_name = "order"
    fields = (
        "created_at",
        "amount_inr",
        "status_badge",
        "reason",
        "gateway_refund_id",
        "initiated",
        "processed_at",
    )
    readonly_fields = fields
    ordering = ("created_at", "id")
    verbose_name_plural = "Refunds"

    def get_queryset(self, request):
        return with_pii_flag(super().get_queryset(request), request.user).select_related(
            "initiated_by"
        )

    @display(description="Amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Status", label=status.label_tones(status.REFUND))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.REFUND, obj.status).label

    @display(description="Initiated by")
    def initiated(self, obj) -> str:
        if obj.initiated_by_id is None:
            return "Automatic"
        return person_label(obj.initiated_by, full=_full(obj))


class StatusHistoryInline(ReadOnlyInline):
    model = OrderStatusHistory
    fields = (
        "created_at",
        "from_badge",
        "to_badge",
        "actor_type",
        "actor_display",
        "note_display",
    )
    readonly_fields = fields
    ordering = ("created_at", "id")
    verbose_name_plural = "Status history (timeline)"

    def get_queryset(self, request):
        return with_pii_flag(super().get_queryset(request), request.user).select_related("actor")

    @display(description="From", label=status.label_tones(status.ORDER))
    def from_badge(self, obj) -> str:
        return status.badge_for(status.ORDER, obj.from_status).label if obj.from_status else "-"

    @display(description="To", label=status.label_tones(status.ORDER))
    def to_badge(self, obj) -> str:
        return status.badge_for(status.ORDER, obj.to_status).label

    @display(description="By")
    def actor_display(self, obj) -> str:
        return person_label(obj.actor, full=_full(obj)) if obj.actor_id else "-"

    @display(description="Note")
    def note_display(self, obj) -> str:
        by_customer = obj.actor_type == ActorType.CUSTOMER
        return customer_text(obj.note, by_customer=by_customer, full=_full(obj))


@admin.register(Order)
class OrderAdmin(StoreScopedAdminMixin, ModelAdmin):
    list_display = (
        "order_number",
        "created_at",
        "store_code",
        "customer_short",
        "status_badge",
        "payment_method",
        "payment_badge",
        "total",
    )
    list_display_links = ("order_number",)
    list_filter = (
        "status",
        ScopedStoreFilter,
        "payment_method",
        "payment_status",
        ("created_at", OrderDateFilter),
        CustomerFilter,
    )
    list_select_related = ("store", "user")
    search_help_text = (
        "Order number or coupon code; customer phone (any part) for roles that see phones"
    )
    ordering = ("-created_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    inlines = [OrderItemInline, PaymentInline, RefundInline, StatusHistoryInline]
    fieldsets = (
        (
            "Order",
            {
                "fields": (
                    "order_number",
                    "status_badge",
                    "store_label",
                    "created_at",
                    "placed_at",
                    "eta_at",
                    "payment_expires_at",
                )
            },
        ),
        (
            "Customer and delivery",
            {"fields": ("customer", "delivery_address", "delivery_instructions")},
        ),
        ("Payment", {"fields": ("payment_method", "payment_badge", "coupon_used")}),
        ("Bill (as charged at placement)", {"fields": ("bill",)}),
        (
            "Timeline",
            {
                "fields": (
                    "accepted_at",
                    "packing_started_at",
                    "packed_at",
                    "picked_up_at",
                    "delivered_at",
                    "cancelled_at",
                    "payment_failed_at",
                    "delivery_failed_at",
                    "returned_at",
                )
            },
        ),
        (
            "Cancellation",
            {"fields": ("cancel_reason", "cancelled_by_type", "cancellation_note")},
        ),
        ("App", {"fields": ("client_app_version", "client_platform")}),
    )

    def get_queryset(self, request):
        return with_pii_flag(super().get_queryset(request), request.user)

    def get_search_fields(self, request):
        if can_view_full_phone(request.user):
            return (*BASIC_SEARCH, *FULL_SEARCH)
        return BASIC_SEARCH  # masked roles must not probe phones digit by digit

    def get_readonly_fields(self, request, obj=None):
        return [name for _title, options in self.fieldsets for name in options["fields"]]

    # Read-only in Phase 3 for everyone: state changes only through the order services (P4).
    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    # ---------------------------------------------------------------- list columns

    @display(description="Store", ordering="store__code")
    def store_code(self, obj) -> str:
        return obj.store.code

    @display(description="Customer")
    def customer_short(self, obj) -> str:
        return customer_label(obj.user, full=_full(obj))

    @display(description="Status", ordering="status", label=status.label_tones(status.ORDER))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.ORDER, obj.status).label

    @display(
        description="Payment",
        ordering="payment_status",
        label=status.label_tones(status.ORDER_PAYMENT),
    )
    def payment_badge(self, obj) -> str:
        return status.badge_for(status.ORDER_PAYMENT, obj.payment_status).label

    @display(description="Grand total", ordering="grand_total")
    def total(self, obj) -> str:
        return inr(obj.grand_total)

    # ---------------------------------------------------------------- detail

    @display(description="Store")
    def store_label(self, obj) -> str:
        return f"{obj.store.code} {obj.store.name}"

    @display(description="Customer")
    def customer(self, obj) -> str:
        text = customer_label(obj.user, full=_full(obj))
        if not _full(obj):
            return text
        if obj.user.cod_blocked:
            text += " (cash on delivery blocked)"
        url = reverse("admin:accounts_customer_change", args=[obj.user_id])
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>', url, text
        )

    @display(description="Delivery address")
    def delivery_address(self, obj) -> str:
        lines = address_lines(obj.address_snapshot, full=_full(obj))
        if not lines:
            return "-"
        return format_html_join(mark_safe("<br>"), "{}", ((line,) for line in lines))

    @display(description="Delivery instructions")
    def delivery_instructions(self, obj) -> str:
        data = obj.instructions if isinstance(obj.instructions, dict) else {}
        chips = [str(chip) for chip in data.get("chips") or [] if chip]
        parts = [", ".join(chips)] if chips else []
        note = str(data.get("note") or "").strip()
        if note:
            # Free text may hold a phone number or a gate code: full-PII roles only.
            parts.append(f"Note: {customer_text(note, by_customer=True, full=_full(obj))}")
        return " · ".join(parts) or "-"

    @display(description="Cancel note")
    def cancellation_note(self, obj) -> str:
        by_customer = obj.cancelled_by_type == ActorType.CUSTOMER
        return customer_text(obj.cancel_note, by_customer=by_customer, full=_full(obj))

    @display(description="Coupon")
    def coupon_used(self, obj) -> str:
        return obj.coupon_code or "-"

    @display(description="Bill")
    def bill(self, obj) -> str:
        rows = []
        for name, label in BILL_ROWS:
            if name == "coupon_discount" and obj.coupon_code:
                label = f"{label} ({obj.coupon_code})"
            rows.append((label, inr(getattr(obj, name))))
        return format_html(
            '<table class="text-sm" data-testid="order-bill"><tbody>{}</tbody></table>',
            format_html_join(
                "",
                '<tr><th class="pr-6 py-0.5 text-left font-normal">{}</th>'
                '<td class="py-0.5 text-right font-medium">{}</td></tr>',
                rows,
            ),
        )
