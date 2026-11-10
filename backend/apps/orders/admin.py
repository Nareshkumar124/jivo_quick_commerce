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
- Phase 4 follow-up (QA BUG-0010): "Issue refund" (a detail action, `/<id>/refund/`) for
  `payments.issue_refund` (Super Admin, Finance; Support up to `SUPPORT_REFUND_LIMIT`). It shows
  the server's refundable amount, posts once (one-time token + `submit_once.js`) and calls
  `order_refunds.manual_refund` through `ops_console.order_actions`; refusals (role limit, cap,
  not paid online, state) are form errors.
- QA BUG-0011: CSV / Excel export (django-import-export, the project's formula-escaping
  formats) of the store-scoped, filtered list. Roles without full PII get the masked phone and
  no address. Money is written as plain numbers ("300.00"); Excel cells are text because of the
  known XLSX type gap (xfail in apps/catalog/tests/test_admin_import_export.py).
"""

from django.contrib import admin, messages
from django.contrib.admin.utils import unquote
from django.core.exceptions import PermissionDenied
from django.db.models import BooleanField, Value
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.template.response import TemplateResponse
from django.urls import reverse
from django.utils.html import format_html, format_html_join
from django.utils.safestring import mark_safe
from import_export import fields as export_fields
from import_export import resources
from import_export.admin import ExportMixin
from unfold.admin import ModelAdmin, TabularInline
from unfold.contrib.import_export.forms import ExportForm
from unfold.decorators import action, display

from apps.ops_console import capabilities, once, order_actions, status
from apps.ops_console.admin_support import ImportExportPermissionsMixin
from apps.ops_console.forms import ManualRefundForm
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


class OrderResource(resources.ModelResource):
    """Orders export (05 §2 "export CSV", BUG-0011). Built per request with the viewer's PII
    level: full-PII roles get the customer's phone and the delivery locality; everyone else the
    masked phone and no address. Money is written as stored, two decimals."""

    order = export_fields.Field(column_name="order_number", attribute="order_number")
    placed = export_fields.Field(column_name="placed_at_ist")
    store_code = export_fields.Field(column_name="store")
    customer_name = export_fields.Field(column_name="customer_name")
    customer_phone = export_fields.Field(column_name="customer_phone")
    delivery_area = export_fields.Field(column_name="delivery_area")
    status_label = export_fields.Field(column_name="status", attribute="status")
    method = export_fields.Field(column_name="payment_method", attribute="payment_method")
    payment = export_fields.Field(column_name="payment_status", attribute="payment_status")
    coupon = export_fields.Field(column_name="coupon_code", attribute="coupon_code")
    item_total = export_fields.Field(column_name="item_total", attribute="item_total")
    coupon_discount = export_fields.Field(
        column_name="coupon_discount", attribute="coupon_discount"
    )
    delivery_fee = export_fields.Field(column_name="delivery_fee", attribute="delivery_fee")
    small_cart_fee = export_fields.Field(column_name="small_cart_fee", attribute="small_cart_fee")
    handling_fee = export_fields.Field(column_name="handling_fee", attribute="handling_fee")
    tip = export_fields.Field(column_name="tip", attribute="tip")
    grand_total = export_fields.Field(column_name="grand_total", attribute="grand_total")
    amount_refunded = export_fields.Field(
        column_name="amount_refunded", attribute="amount_refunded"
    )

    MONEY = (
        "item_total",
        "coupon_discount",
        "delivery_fee",
        "small_cart_fee",
        "handling_fee",
        "tip",
        "grand_total",
        "amount_refunded",
    )

    class Meta:
        model = Order
        # import-export 4 applies this list to declared fields too: name every column.
        fields = (
            "order",
            "placed",
            "store_code",
            "customer_name",
            "customer_phone",
            "delivery_area",
            "status_label",
            "method",
            "payment",
            "coupon",
            "item_total",
            "coupon_discount",
            "delivery_fee",
            "small_cart_fee",
            "handling_fee",
            "tip",
            "grand_total",
            "amount_refunded",
        )

    def __init__(self, *args, full_pii: bool = False, **kwargs):
        super().__init__(*args, **kwargs)
        self.full_pii = full_pii

    def get_export_order(self):
        return (
            "order",
            "placed",
            "store_code",
            "customer_name",
            "customer_phone",
            "delivery_area",
            "status_label",
            "method",
            "payment",
            "coupon",
            *self.MONEY,
        )

    def dehydrate_placed(self, order) -> str:
        from django.utils import timezone

        from apps.ops_console.dates import DISPLAY_TZ

        moment = order.placed_at or order.created_at
        return timezone.localtime(moment, DISPLAY_TZ).strftime("%Y-%m-%d %H:%M")

    def dehydrate_store_code(self, order) -> str:
        return order.store.code

    def dehydrate_customer_name(self, order) -> str:
        return (order.user.name or "").strip()

    def dehydrate_customer_phone(self, order) -> str:
        from apps.ops_console.pii import mask_phone

        phone = order.user.phone or ""
        return phone if self.full_pii else mask_phone(phone)

    def dehydrate_delivery_area(self, order) -> str:
        if not self.full_pii:
            return ""
        snapshot = order.address_snapshot if isinstance(order.address_snapshot, dict) else {}
        parts = (snapshot.get(key) for key in ("area", "city", "pincode"))
        return ", ".join(str(part) for part in parts if part)

    def export_field(self, field, instance, **kwargs):
        value = super().export_field(field, instance, **kwargs)
        if field.column_name in self.MONEY:
            amount = getattr(instance, field.column_name)
            return f"{amount:.2f}" if amount is not None else ""
        return value


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
class OrderAdmin(StoreScopedAdminMixin, ImportExportPermissionsMixin, ExportMixin, ModelAdmin):
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
    actions_detail = ["issue_refund"]
    resource_classes = [OrderResource]
    export_form_class = ExportForm
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

    # ---------------------------------------------------------------- export (BUG-0011)

    def get_export_queryset(self, request):
        # The changelist's queryset (store-scoped, filtered, searched) with what the rows need.
        return super().get_export_queryset(request).select_related("store", "user")

    def get_data_for_export(self, request, queryset, **kwargs):
        """At most `ORDERS_EXPORT_MAX_ROWS` rows per file (oldest dropped: the list's newest-first
        order); every export is audited (`orders.export`: rows, cap, PII level)."""
        from django.conf import settings

        from apps.core import audit
        from apps.core.net import client_ip

        cap = int(getattr(settings, "ORDERS_EXPORT_MAX_ROWS", 5000))
        rows = queryset.count()
        capped = rows > cap
        if capped:
            queryset = queryset[:cap]
            self.message_user(
                request,
                f"The export has the newest {cap} of {rows} orders. "
                "Narrow the filters for the rest.",
                messages.WARNING,
            )
        audit.record(
            request.user,
            "orders.export",
            ("orders.order", "list"),
            {
                "rows": min(rows, cap),
                "matched": rows,
                "capped": capped,
                "full_pii": can_view_full_phone(request.user),
            },
            ip=client_ip(request),
        )
        return super().get_data_for_export(request, queryset, **kwargs)

    def get_export_resource_kwargs(self, request, **kwargs):
        kwargs = super().get_export_resource_kwargs(request, **kwargs)
        kwargs["full_pii"] = can_view_full_phone(request.user)
        return kwargs

    # ---------------------------------------------------------------- refund (BUG-0010)

    def has_issue_refund_permission(self, request, object_id=None) -> bool:
        return (
            self.has_view_permission(request)
            and capabilities.allowed(request.user, capabilities.ISSUE_REFUND)
            and order_actions.available(order_actions.MANUAL_REFUND)
        )

    @action(description="Issue refund", url_path="refund", permissions=["issue_refund"])
    def issue_refund(self, request, object_id):
        if not self.has_issue_refund_permission(request):
            raise PermissionDenied
        # Scoped first: another store's order is a 404, never fetched and then checked.
        order = get_object_or_404(self.get_queryset(request), pk=unquote(object_id))
        back = reverse("admin:orders_order_change", args=[order.pk])
        refundable = order_actions.refundable(order)
        form = ManualRefundForm(
            request.POST or None,
            refundable=refundable,
            initial={"once": once.new_token(once.MANUAL_REFUND)},
        )
        if request.method == "POST" and form.is_valid():
            if not once.consume(request.user, once.MANUAL_REFUND, form.cleaned_data["once"]):
                form.add_error(None, once.MSG_REUSED)
            else:
                amount = form.cleaned_data["amount"]
                try:
                    refund = order_actions.manual_refund(
                        order, amount, actor=request.user, note=form.cleaned_data["note"]
                    )
                except order_actions.ActionRefused as refusal:
                    form.add_error(
                        "amount" if refusal.code == order_actions.INVALID else None,
                        refusal.message,
                    )
                else:
                    self.message_user(
                        request,
                        f"Refund of {inr(refund.amount)} started for {order.order_number}. "
                        "The customer gets it in 5-7 working days.",
                        messages.SUCCESS,
                    )
                    return HttpResponseRedirect(back)
        if request.method == "POST":
            # A fresh token for the next attempt (a consumed or refused one cannot be reused).
            data = form.data.copy()
            data["once"] = once.new_token(once.MANUAL_REFUND)
            form.data = data
        context = {
            **self.admin_site.each_context(request),
            "opts": self.opts,
            "title": f"Refund {order.order_number}",
            "order": order,
            "form": form,
            "refundable": refundable,
            "refundable_display": inr(refundable),
            "grand_total": inr(order.grand_total),
            "amount_paid": inr(getattr(order, "amount_paid", None)),
            "amount_refunded": inr(order.amount_refunded),
            "is_online": order.payment_method == "ONLINE",
            "back": back,
        }
        request.current_app = self.admin_site.name
        return TemplateResponse(request, "admin/orders/order/refund.html", context)

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
