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
- Personal coupons (`owner`, added 2026-11-13; referral rewards are personal): the owner is
  chosen only when a coupon is created (a customer id; the lookup opens the Customers admin for
  roles that may see customers in full) and is read-only afterwards, so a coupon customers or
  orders already use never changes hands. The owner is shown per the PII policy, never as
  `str(user)` (the phone).
- Free-carton rewards (ADR 0002: `discount_type` FREE_UNIT, with a `source`: welcome or
  referral) are made by the system only, so FREE_UNIT is not offered on the form. On a reward's
  page the type, value, cap and minimum are replaced by "N free cartons" and the reward's status,
  and its usage limits (one use) are read-only, also against a crafted POST (the fields are not
  in the form). The list shows and filters the type and the source.
- ADR 0003: a reward's `value` is its number of free cartons (1 to 10), so the list, the
  reward's page and the redemptions say "N free cartons" from it; the cartons are the store's
  free carton size (Pricing config).
"""

from urllib.parse import urlencode

from django import forms
from django.contrib import admin
from django.contrib.admin.views.main import TO_FIELD_VAR
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db.models import BooleanField, Count, Q, Value
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display
from unfold.widgets import UnfoldForeignKeyRawIdWidget

from apps.ops_console import status
from apps.ops_console.admin_support import ReadOnlyHistoryAdmin
from apps.ops_console.cartons import free_cartons
from apps.ops_console.money import RupeeInput, inr
from apps.ops_console.params import parse_ascii_id
from apps.ops_console.pii import can_view_full_phone, customer_label
from apps.ops_console.scoping import ScopedStoreFilter, StoreScopedAdminMixin
from apps.promotions import rewards
from apps.promotions.choices import DiscountType, RewardStatus
from apps.promotions.models import COUNTED_STATUSES, Coupon, CouponRedemption
from apps.promotions.services import (
    MSG_CODE_LOCKED,
    MSG_CODE_TAKEN,
    MSG_LIMIT_BELOW_USES,
    counted_uses,
    is_used,
    normalise_code,
    save_coupon,
)

# Redemptions that use up the coupon (HELD + APPLIED), as the usage limits count them.
COUNTED = Q(redemptions__status__in=COUNTED_STATUSES)

MSG_CAP_REQUIRED = "A percent coupon needs a maximum discount (cap) in rupees."
MSG_NO_CAP_ON_FLAT = "A flat coupon has no cap: its value is the discount. Leave this empty."
MSG_CODE_SPACES = "Use letters and numbers without spaces, e.g. JIVO50."
MSG_OWNER_NOT_CUSTOMER = "Enter the id of an active customer account (not a staff account)."
PUBLIC_COUPON = "Public (everyone)"

# ADR 0002: a free-carton reward's page shows these instead of the money fields.
REWARD_FIELDSET = (
    "Reward",
    {
        "fields": ("reward_kind", "reward_status"),
        "description": (
            "A free-carton reward gives no money off: its cartons are the store's free carton "
            "size (Pricing config; where none is set, the customer picks the size), and the "
            "order still needs the store's minimum paid cartons. One use; its type, number of "
            "cartons and limits are fixed. Switch it off or change its end date if needed."
        ),
    },
)
# Fixed on a reward (one use, ADR 0002 §13): read-only on its page.
REWARD_FIXED_FIELDS = ("usage_limit_total", "usage_limit_per_user", "first_order_only")
STORE_MINIMUM = "Store minimum (cartons)"


def owner_choices():
    """Who may own a personal coupon: active customer accounts."""
    return get_user_model().objects.filter(is_staff=False, is_superuser=False, is_active=True)


class CustomerRawIdWidget(UnfoldForeignKeyRawIdWidget):
    """The owner's id input. Unlike Django's raw-id widget it never shows `str(user)` (the
    phone): the label is the customer per the PII policy, and the lookup and link go to the
    Customers admin only for roles that may open it (`accounts.view_customer`)."""

    def __init__(self, rel, admin_site, *, full_pii: bool, attrs=None, using=None):
        super().__init__(rel, admin_site, attrs, using)
        self.full_pii = full_pii

    def get_context(self, name, value, attrs):
        context = super().get_context(name, value, attrs)
        context["related_url"] = None
        if self.full_pii:
            changelist = reverse("admin:accounts_customer_changelist")
            context["related_url"] = f"{changelist}?{urlencode({TO_FIELD_VAR: 'id'})}"
        return context

    def label_and_url_for_value(self, value):
        try:
            customer = owner_choices().filter(pk=int(value)).first()
        except (TypeError, ValueError):
            customer = None
        if customer is None:
            return "", ""
        url = reverse("admin:accounts_customer_change", args=[customer.pk]) if self.full_pii else ""
        return customer_label(customer, full=self.full_pii), url


class _SaveRefused(Exception):
    def __init__(self, error: ValidationError):
        super().__init__(str(error))
        self.error = error


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
            "owner",  # on the add page only (CouponAdmin.get_fieldsets)
        )
        widgets = {
            "max_discount": RupeeInput,
            "min_order_value": RupeeInput,
        }
        help_texts = {
            "value": "FLAT: rupees off. PERCENT: percent off, from 0.01 to 100.",
            "max_discount": "Percent coupons: the most the discount can be, in rupees "
            "(required). Flat coupons: leave empty.",
            "owner": "Empty: a public coupon. A customer's id: a personal coupon that only this "
            "customer sees and can use. It cannot be changed after saving.",
        }
        labels = {"owner": "Personal coupon for (customer id)"}

    # Set by CouponAdmin when `save_coupon` refused the save (a raced code, a limit below the
    # counted uses...): shown as errors of this form, nothing saved.
    save_refusal: ValidationError | None = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        kind = self.fields.get("discount_type")
        if kind is not None:
            # ADR 0002: free-carton rewards are made by the system (welcome, referral), never
            # here; a reward's own page has no type field (CouponAdmin.get_fieldsets).
            kind.choices = [
                choice for choice in kind.choices if choice[0] != DiscountType.FREE_UNIT
            ]

    def code_taken(self, code: str) -> bool:
        taken = Coupon.objects.filter(code__iexact=code)
        if self.instance.pk:
            taken = taken.exclude(pk=self.instance.pk)
        return taken.exists()

    def clean_code(self) -> str:
        code = normalise_code(self.cleaned_data.get("code", ""))
        if any(character.isspace() for character in code):
            raise forms.ValidationError(MSG_CODE_SPACES)
        if self.instance.pk and code != self.instance.code and is_used(self.instance):
            # The admin shows the code read-only once used; this guards a crafted POST.
            raise forms.ValidationError(MSG_CODE_LOCKED)
        if code and self.code_taken(code):
            raise forms.ValidationError(MSG_CODE_TAKEN)
        return code

    def clean_usage_limit_total(self):
        limit = self.cleaned_data.get("usage_limit_total")
        if limit is not None and self.instance.pk:
            uses = counted_uses(self.instance)
            if limit < uses:
                raise forms.ValidationError(MSG_LIMIT_BELOW_USES.format(uses=uses))
        return limit

    def clean(self):
        cleaned = super().clean()
        if self.save_refusal is not None:
            self.add_error(None, self.save_refusal)
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


class CouponKindFilter(admin.SimpleListFilter):
    """Personal coupons (one customer, e.g. referral rewards) or public ones."""

    title = "personal or public"
    parameter_name = "kind"

    def lookups(self, request, model_admin):
        return [("personal", "Personal (one customer)"), ("public", "Public")]

    def queryset(self, request, queryset):
        value = self.value()
        if value == "personal":
            return queryset.filter(owner__isnull=False)
        if value == "public":
            return queryset.filter(owner__isnull=True)
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
        "source_label",
        "owner_label",
        "state_badge",
    )
    list_display_links = ("code", "title")
    list_filter = (
        CouponStateFilter,
        CouponKindFilter,
        "discount_type",
        "source",
        "first_order_only",
        "is_visible",
        "is_active",
    )
    search_fields = ("code", "title")
    search_help_text = "Code or title"
    ordering = ("code",)
    list_per_page = 50
    filter_horizontal = ("stores", "categories")
    raw_id_fields = ("owner",)  # widget: CustomerRawIdWidget (formfield_for_foreignkey)
    readonly_fields = (
        "state_badge",
        "usage_summary",
        "owner_label",
        "source_label",
        "reward_kind",
        "reward_status",
        "created_at",
        "updated_at",
    )
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
        (
            "Who can use it",
            {
                # "owner" on the add page, "owner_label" (read-only) afterwards: get_fieldsets.
                "fields": ("owner",),
                "description": (
                    "A personal coupon is listed and works only for its customer (referral "
                    "rewards are personal coupons). The customer is set when the coupon is "
                    "created and cannot be changed."
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
        (
            "Status",
            {
                "fields": (
                    "state_badge",
                    "usage_summary",
                    "source_label",
                    "created_at",
                    "updated_at",
                )
            },
        ),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(
                counted_uses=Count("redemptions", filter=COUNTED),
                full_pii=Value(can_view_full_phone(request.user), output_field=BooleanField()),
            )
            .select_related("owner")
            .prefetch_related("categories")
        )

    def get_fieldsets(self, request, obj=None):
        if obj is None:
            return self.fieldsets[:-1]  # nothing to report on a new coupon
        fieldsets = self.fieldsets
        if rewards.is_reward(obj):
            # ADR 0002: no money fields on a free-carton reward (so a crafted POST cannot change
            # its type, value, cap or minimum either: the form has no such fields).
            fieldsets = tuple(
                REWARD_FIELDSET if title == "Discount" else (title, options)
                for title, options in fieldsets
            )
        # An existing coupon never changes hands: its owner is shown, not a field (so a crafted
        # POST cannot set it either: the form has no `owner` field).
        return tuple(
            (
                title,
                {
                    **options,
                    "fields": tuple(
                        "owner_label" if name == "owner" else name for name in options["fields"]
                    ),
                },
            )
            for title, options in fieldsets
        )

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "owner":
            kwargs["queryset"] = owner_choices()
            kwargs["widget"] = CustomerRawIdWidget(
                db_field.remote_field,
                self.admin_site,
                full_pii=can_view_full_phone(request.user),
                using=kwargs.get("using"),
            )
            formfield = super().formfield_for_foreignkey(db_field, request, **kwargs)
            formfield.error_messages["invalid_choice"] = MSG_OWNER_NOT_CUSTOMER
            return formfield
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

    def get_readonly_fields(self, request, obj=None):
        fields = list(super().get_readonly_fields(request, obj))
        if is_used(obj):
            fields.append("code")  # customers and orders refer to it (T-406c)
        if rewards.is_reward(obj):
            fields.extend(REWARD_FIXED_FIELDS)  # one use (ADR 0002 §13)
        return fields

    def get_form(self, request, obj=None, change=False, **kwargs):
        form = super().get_form(request, obj, change, **kwargs)
        refusal = getattr(request, "_coupon_save_refusal", None)
        if refusal is not None:
            form = type(form.__name__, (form,), {"save_refusal": refusal})
        return form

    def save_model(self, request, obj, form, change):
        """`apps.promotions.services.save_coupon` is the one door (T-406c): it re-checks the
        edit guards on the locked row and turns a raced code into an error. Its refusal is a
        `ValidationError` (dict); `changeform_view` shows it as form errors, never a 500."""
        try:
            save_coupon(obj)
        except ValidationError as error:
            raise _SaveRefused(error) from error

    def changeform_view(self, request, object_id=None, form_url="", extra_context=None):
        try:
            return super().changeform_view(request, object_id, form_url, extra_context)
        except _SaveRefused as refused:
            # Everything of the first attempt was rolled back. Show the form again with the
            # refusal as its errors (nothing is saved: the form is invalid this time).
            request._coupon_save_refusal = refused.error
            return super().changeform_view(request, object_id, form_url, extra_context)

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
        if rewards.is_reward(obj):
            return free_cartons(obj.value)  # no money off (ADR 0002); N cartons (ADR 0003)
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
        if rewards.is_reward(obj) and not obj.min_order_value:
            return STORE_MINIMUM  # a reward needs the store's minimum paid cartons
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
        parts = ["Personal"] if obj.owner_id else []
        if obj.first_order_only:
            parts.append("First order")
        if not obj.is_visible:
            parts.append("Hidden code")
        return ", ".join(parts) or "Everyone"

    @display(description="Personal for")
    def owner_label(self, obj) -> str:
        if obj is None or obj.owner_id is None:
            return PUBLIC_COUPON
        # Masked unless this viewer sees customers in full (history pages: always masked).
        return customer_label(obj.owner, full=getattr(obj, "full_pii", False))

    @display(description="Source", ordering="source")
    def source_label(self, obj) -> str:
        if obj is None or obj.pk is None:
            return "-"
        return obj.get_source_display()

    @display(description="Reward")
    def reward_kind(self, obj) -> str:
        return f"{free_cartons(obj.value)} (₹0, the store's free carton size)"

    @display(description="Reward status")
    def reward_status(self, obj) -> str:
        """ADR 0002 §10, derived by the backend (`rewards.reward_state`), never stored."""
        if obj is None or obj.pk is None or not rewards.is_reward(obj):
            return "-"
        state = rewards.reward_state(obj)
        label = RewardStatus(state.status).label
        if state.order is not None:
            # Plain text: not every coupon role may open orders.
            return f"{label} (order {state.order.order_number})"
        return label

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
        coupon_id = parse_ascii_id(value)
        if coupon_id is None:
            return queryset.none()
        return queryset.filter(coupon_id=coupon_id)


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
        if rewards.is_reward(obj.coupon):
            # A free line at ₹0 on the order (ADR 0002), of the coupon's quantity (ADR 0003).
            return free_cartons(obj.coupon.value)
        return inr(obj.discount_amount)

    @display(description="Status", label=status.label_tones(status.REDEMPTION))
    def status_badge(self, obj) -> str:
        return status.badge_for(status.REDEMPTION, obj.status).label
