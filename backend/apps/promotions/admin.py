"""Promotions admin (05 §2 "Coupons", 05 §3 "Coupons": Super Admin and Catalog Manager manage,
Support and Finance view; DL-45, DL-46).

- Coupons: every type the model supports (flat, percent with a cap, category, first order only,
  hidden code), validity window and usage limits. Changes are kept in the coupon's history
  (django-simple-history, view-only). The form adds panel rules on top of the model's own
  validation: a percent coupon needs a cap, a flat coupon has none, codes are unique ignoring
  case.
- A coupon is deleted only while it has never been used (redemptions and orders protect it);
  otherwise it is switched off.
- Redemptions: read-only, one row per order that used a coupon (`apps.promotions.services` writes
  them). Customers are shown per the PII policy (`ops_console.pii`); the order number is plain
  text because not every coupon role may open orders.
"""

from django import forms
from django.contrib import admin
from django.db.models import BooleanField, Count, Q, Value
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.ops_console import status
from apps.ops_console.admin_support import ReadOnlyHistoryAdmin
from apps.ops_console.money import RupeeInput, inr
from apps.ops_console.pii import can_view_full_phone, customer_label
from apps.ops_console.scoping import ScopedStoreFilter, StoreScopedAdminMixin
from apps.promotions.choices import DiscountType
from apps.promotions.models import COUNTED_STATUSES, Coupon, CouponRedemption
from apps.promotions.services import normalise_code

# Redemptions that use up the coupon (HELD + APPLIED), as the usage limits count them.
COUNTED = Q(redemptions__status__in=COUNTED_STATUSES)

MSG_CAP_REQUIRED = "A percent coupon needs a maximum discount (cap) in rupees."
MSG_NO_CAP_ON_FLAT = "A flat coupon has no cap: its value is the discount. Leave this empty."
MSG_CODE_TAKEN = "A coupon with this code already exists (codes ignore upper and lower case)."
MSG_CODE_SPACES = "Use letters and numbers without spaces, e.g. JIVO50."


class CouponAdminForm(forms.ModelForm):
    class Meta:
        model = Coupon
        fields = (
            "code",
            "title",
            "description",
            "discount_type",
            "value",
            "max_discount",
            "min_order_value",
            "starts_at",
            "ends_at",
            "usage_limit_total",
            "usage_limit_per_user",
            "first_order_only",
            "stores",
            "categories",
            "is_active",
            "is_visible",
        )
        widgets = {
            "max_discount": RupeeInput,
            "min_order_value": RupeeInput,
        }
        help_texts = {
            "value": "FLAT: rupees off. PERCENT: percent off, from 0.01 to 100.",
            "max_discount": "Percent coupons: the most the discount can be, in rupees "
            "(required). Flat coupons: leave empty.",
        }

    def clean_code(self) -> str:
        code = normalise_code(self.cleaned_data.get("code", ""))
        if any(character.isspace() for character in code):
            raise forms.ValidationError(MSG_CODE_SPACES)
        taken = Coupon.objects.filter(code__iexact=code)
        if self.instance.pk:
            taken = taken.exclude(pk=self.instance.pk)
        if code and taken.exists():
            raise forms.ValidationError(MSG_CODE_TAKEN)
        return code

    def clean(self):
        cleaned = super().clean()
        kind = cleaned.get("discount_type")
        cap = cleaned.get("max_discount")
        if kind == DiscountType.PERCENT and cap is None and "max_discount" not in self.errors:
            self.add_error("max_discount", MSG_CAP_REQUIRED)
        if kind == DiscountType.FLAT and cap is not None:
            self.add_error("max_discount", MSG_NO_CAP_ON_FLAT)
        return cleaned


class CouponStateFilter(admin.SimpleListFilter):
    title = "state"
    parameter_name = "state"

    def lookups(self, request, model_admin):
        return [(code, badge.label) for code, badge in status.BADGES[status.COUPON].items()]

    def queryset(self, request, queryset):
        now = timezone.now()
        started = Q(starts_at__isnull=True) | Q(starts_at__lte=now)
        expired = Q(ends_at__isnull=False, ends_at__lte=now)
        value = self.value()
        if value == "inactive":
            return queryset.filter(is_active=False)
        if value == "expired":
            return queryset.filter(expired, is_active=True)
        if value == "scheduled":
            return queryset.filter(is_active=True).exclude(started).exclude(expired)
        if value == "live":
            return queryset.filter(started, is_active=True).exclude(expired)
        return queryset


@admin.register(Coupon)
class CouponAdmin(ReadOnlyHistoryAdmin, ModelAdmin):
    form = CouponAdminForm
    list_display = (
        "code",
        "title",
        "discount",
        "minimum",
        "valid",
        "uses",
        "per_user",
        "audience",
        "state_badge",
    )
    list_display_links = ("code", "title")
    list_filter = (
        CouponStateFilter,
        "discount_type",
        "first_order_only",
        "is_visible",
        "is_active",
    )
    search_fields = ("code", "title")
    search_help_text = "Code or title"
    ordering = ("code",)
    list_per_page = 50
    filter_horizontal = ("stores", "categories")
    readonly_fields = ("state_badge", "usage_summary", "created_at", "updated_at")
    fieldsets = (
        (
            "Coupon",
            {
                "fields": ("code", "title", "description", "is_active", "is_visible"),
                "description": (
                    "Hidden codes (not listed in the app) still work when typed. Codes are "
                    "stored in capitals; customers may type them in any case."
                ),
            },
        ),
        ("Discount", {"fields": ("discount_type", "value", "max_discount", "min_order_value")}),
        (
            "Validity (IST)",
            {"fields": ("starts_at", "ends_at"), "description": "Empty start: valid now."},
        ),
        (
            "Usage limits",
            {
                "fields": ("usage_limit_total", "usage_limit_per_user", "first_order_only"),
                "description": (
                    "Orders awaiting online payment already count; a failed or abandoned "
                    "payment gives the use back."
                ),
            },
        ),
        ("Where it applies", {"fields": ("stores", "categories")}),
        ("Status", {"fields": ("state_badge", "usage_summary", "created_at", "updated_at")}),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(counted_uses=Count("redemptions", filter=COUNTED))
            .prefetch_related("categories")
        )

    def get_fieldsets(self, request, obj=None):
        if obj is None:
            return self.fieldsets[:-1]  # nothing to report on a new coupon
        return self.fieldsets

    def has_delete_permission(self, request, obj=None) -> bool:
        if not super().has_delete_permission(request, obj):
            return False
        # Used coupons are referenced by redemptions and orders (protected): switch them off.
        return obj is None or not (obj.redemptions.exists() or obj.orders.exists())

    def get_actions(self, request):
        actions = super().get_actions(request)
        actions.pop("delete_selected", None)  # one by one, so used coupons are refused
        return actions

    # ---------------------------------------------------------------- columns

    @display(description="Discount", ordering="value")
    def discount(self, obj) -> str:
        if obj.discount_type == DiscountType.PERCENT:
            text = f"{obj.value.normalize():f}% off"
            if obj.max_discount is not None:
                text += f", up to {inr(obj.max_discount)}"
        else:
            text = f"{inr(obj.value)} off"
        if obj.pk and obj.categories.all():  # prefetched
            text += " (selected categories)"
        return text

    @display(description="Min. item total", ordering="min_order_value")
    def minimum(self, obj) -> str:
        return inr(obj.min_order_value)

    @display(description="Valid (IST)")
    def valid(self, obj) -> str:
        def day(moment):
            return timezone.localtime(moment).strftime("%d %b %Y %H:%M")

        start = day(obj.starts_at) if obj.starts_at else "now"
        end = day(obj.ends_at) if obj.ends_at else "no end"
        return f"{start} to {end}"

    @display(description="Uses / limit", ordering="counted_uses")
    def uses(self, obj) -> str:
        limit = obj.usage_limit_total if obj.usage_limit_total is not None else "no limit"
        return f"{obj.counted_uses} / {limit}"

    @display(description="Per customer")
    def per_user(self, obj) -> str:
        if obj.usage_limit_per_user is None:
            return "No limit"
        return str(obj.usage_limit_per_user)

    @display(description="Audience")
    def audience(self, obj) -> str:
        parts = []
        if obj.first_order_only:
            parts.append("First order")
        if not obj.is_visible:
            parts.append("Hidden code")
        return ", ".join(parts) or "Everyone"

    @display(description="State", label=status.label_tones(status.COUPON))
    def state_badge(self, obj) -> str:
        if obj.pk is None:
            return "-"
        return status.BADGES[status.COUPON][status.coupon_state(obj, timezone.now())].label

    @display(description="Usage")
    def usage_summary(self, obj) -> str:
        if obj.pk is None:
            return "-"
        counts = dict(obj.redemptions.values_list("status").annotate(count=Count("id")).order_by())
        parts = [
            f"{badge.label}: {counts.get(code, 0)}"
            for code, badge in status.BADGES[status.REDEMPTION].items()
        ]
        url = reverse("admin:promotions_couponredemption_changelist")
        return format_html(
            '{}<br><a class="text-primary-600 dark:text-primary-500" '
            'href="{}?coupon={}">View the {} redemption(s)</a>',
            ", ".join(parts),
            url,
            obj.pk,
            sum(counts.values()),
        )


# --------------------------------------------------------------------------- redemptions


class RedemptionStoreFilter(ScopedStoreFilter):
    field = "order__store"


class RedemptionCouponFilter(admin.SimpleListFilter):
    """By coupon (`?coupon=<id>`, the link on each coupon page). Django's related-only filter
    is dropped, and its parameter silently ignored, while only one coupon has been used."""

    title = "coupon"
    parameter_name = "coupon"

    def lookups(self, request, model_admin):
        return [(str(pk), code) for pk, code in Coupon.objects.values_list("pk", "code")]

    def queryset(self, request, queryset):
        value = self.value()
        if not value:
            return queryset
        if not value.isdigit():
            return queryset.none()
        return queryset.filter(coupon_id=int(value))


@admin.register(CouponRedemption)
class CouponRedemptionAdmin(StoreScopedAdminMixin, ModelAdmin):
    """Read-only for everyone, superusers included: rows follow their order (08 T1-T5)."""

    store_field = "order__store"
    list_display = (
        "created_at",
        "coupon_code",
        "order_number",
        "customer",
        "discount",
        "status_badge",
    )
    list_display_links = ("created_at", "coupon_code")
    list_filter = (
        "status",
        RedemptionCouponFilter,
        RedemptionStoreFilter,
        ("created_at", admin.DateFieldListFilter),
    )
    list_select_related = ("coupon", "order", "user")
    search_fields = ("coupon__code", "order__order_number")
    search_help_text = "Coupon code or order number"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fields = (
        "created_at",
        "coupon_code",
        "order_number",
        "customer",
        "discount",
        "status_badge",
        "updated_at",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(
                full_pii=Value(can_view_full_phone(request.user), output_field=BooleanField())
            )
        )

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    @display(description="Coupon", ordering="coupon__code")
    def coupon_code(self, obj) -> str:
        return obj.coupon.code

    @display(description="Order", ordering="order__order_number")
    def order_number(self, obj) -> str:
        return obj.order.order_number

    @display(description="Customer")
    def customer(self, obj) -> str:
        return customer_label(obj.user, full=getattr(obj, "full_pii", False))

    @display(description="Discount", ordering="discount_amount")
    def discount(self, obj) -> str:
        return inr(obj.discount_amount)

    @display(description="Status", label=status.label_tones(status.REDEMPTION))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.REDEMPTION, obj.status).label
