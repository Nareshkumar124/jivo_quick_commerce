"""Referrals admin (07 §2.5a, 06 §2.1 "Referral"; added 2026-11-13).

Who: the roles that manage coupons edit the settings (05 §3 "Coupons": Super Admin, Catalog
Manager); the roles that view coupons view the settings, referrals and codes (Support, Finance).
All by model permissions (`referrals.*`, granted in `apps.accounts.roles`), never by group name.
ADR 0004 (user, 2026-11-26): the referral on/off and the reward quantities are offers, so only
`promotions.manage_offers` (Super Admin) changes them; for the others they are read-only (not in
the form). The validity days and the old ₹ fields keep the rule above.

- Referral settings: a single row (id 1, like App configuration). The list page opens it; no
  add, no delete. Changes are kept in its history (django-simple-history, view-only) and in the
  audit log (`referral_settings.change`). The reward terms are read when a reward is given, so a
  change applies to rewards given from then on.
- ADR 0002 (2026-11-25): the reward is now 1 free carton for each customer (and a welcome
  reward for new accounts), valid `reward_validity_days`. `reward_amount` and
  `reward_min_order_value` are no longer used for new rewards: they sit in their own
  "old ₹ rewards only" section. The referral list says "1 free carton" for free-carton rewards
  and the ₹ amount for the older ones.
- ADR 0003 (2026-11-26): the number of free cartons is a setting: `welcome_reward_quantity`
  ("Welcome gift") and `reward_quantity` (each person of a referral), 1 to 10. A reward keeps
  the quantity it was given with (its coupon's `value`), so the referral list reads "N free
  cartons" from the coupon, never from today's setting.
- Referrals and referral codes: read-only for everyone, superusers included. Rows change only
  through `apps.referrals.services` (customers enter codes in the app; the reward is a Celery
  task). Customers are shown per the PII policy (`ops_console.pii`): a masked phone for roles
  without full customer access, who also cannot search by phone (a partial-phone search would
  reveal the hidden digits).
"""

from django import forms
from django.contrib import admin
from django.core.exceptions import PermissionDenied
from django.db import transaction
from django.db.models import BooleanField, Value
from django.shortcuts import redirect
from django.urls import reverse
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.core import audit
from apps.ops_console import status
from apps.ops_console.admin_support import ReadOnlyHistoryAdmin
from apps.ops_console.cartons import free_cartons
from apps.ops_console.money import RupeeInput, inr
from apps.ops_console.pii import can_view_full_phone, customer_label
from apps.ops_console.store_management import can_manage_offers
from apps.promotions import rewards
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import Referral, ReferralCode, ReferralSettings

AUDIT_SETTINGS_CHANGE = "referral_settings.change"

OLD_REWARDS = "(old ₹ rewards only)"
LABEL_REWARD_AMOUNT = f"Reward amount {OLD_REWARDS}"
LABEL_MIN_ORDER = f"Minimum item total {OLD_REWARDS}"
# ADR 0003: free cartons per reward.
LABEL_WELCOME_QUANTITY = "Welcome gift (free cartons)"
LABEL_REWARD_QUANTITY = "Referral reward per person (free cartons)"
QUANTITY_FIELDS = {
    "welcome_reward_quantity": "welcome_reward_cartons",
    "reward_quantity": "reward_cartons",
}
# ADR 0004: without `promotions.manage_offers` these show in words (read-only).
OFFER_FIELDS = {"is_enabled": "program_state", **QUANTITY_FIELDS}

# Badge per referral status (labels unique: unfold's `@display(label=...)` maps label -> tone).
REFERRAL_BADGES = {
    ReferralStatus.PENDING: status.Badge("Waiting for first delivery", status.WARNING),
    ReferralStatus.REWARDED: status.Badge("Rewarded", status.SUCCESS),
    ReferralStatus.VOID: status.Badge("No reward (void)", status.NEUTRAL),
}

PHONE_SEARCH_FIELDS = ("referrer__phone", "referred__phone")


def _full_pii(queryset, request):
    """Annotate each row with whether this viewer sees customers in full."""
    full = can_view_full_phone(request.user)
    return queryset.annotate(full_pii=Value(full, output_field=BooleanField()))


class _ReadOnlyAdmin(ModelAdmin):
    """Viewed with the model's view permission; never added, changed or deleted here."""

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}


# --------------------------------------------------------------------------- settings


class ReferralSettingsForm(forms.ModelForm):
    class Meta:
        model = ReferralSettings
        fields = (
            "is_enabled",
            "welcome_reward_quantity",
            "reward_quantity",
            "reward_amount",
            "reward_validity_days",
            "reward_min_order_value",
        )
        widgets = {
            "welcome_reward_quantity": forms.NumberInput(attrs={"min": "1", "max": "10"}),
            "reward_quantity": forms.NumberInput(attrs={"min": "1", "max": "10"}),
            "reward_amount": RupeeInput(attrs={"min": "1", "max": "1000"}),
            "reward_min_order_value": RupeeInput,
        }
        labels = {
            "is_enabled": "Referral program on",
            "welcome_reward_quantity": LABEL_WELCOME_QUANTITY,
            "reward_quantity": LABEL_REWARD_QUANTITY,
            "reward_amount": LABEL_REWARD_AMOUNT,
            "reward_validity_days": "Reward valid for (days)",
            "reward_min_order_value": LABEL_MIN_ORDER,
        }
        help_texts = {
            "is_enabled": (
                "Off: customers cannot enter a code, and a friend whose first order is "
                "delivered while it is off gets no reward."
            ),
            "welcome_reward_quantity": (
                "Free cartons a new customer account gets (1 to 10). Rewards already given keep "
                "their own quantity."
            ),
            "reward_quantity": (
                "Free cartons each of the two customers gets when the friend's first order is "
                "delivered (1 to 10). Rewards already given keep their own quantity."
            ),
            "reward_amount": (
                "Not used for new rewards: the referral reward is now free cartons. Kept from "
                "the old ₹ off reward (₹1 to ₹1,000)."
            ),
            "reward_validity_days": "Days each reward (referral and welcome) can be used, from "
            "the day it is given (1 to 365).",
            "reward_min_order_value": "Not used for free-carton rewards (they need the store's "
            "minimum paid cartons). Kept from the old ₹ off reward. 0 = no minimum.",
        }


@admin.register(ReferralSettings)
class ReferralSettingsAdmin(ReadOnlyHistoryAdmin, ModelAdmin):
    form = ReferralSettingsForm
    money_fields = ("reward_amount", "reward_min_order_value")
    readonly_fields = (
        "updated_at",
        "reward_label",
        "program_state",
        "welcome_reward_cartons",
        "reward_cartons",
        "reward_amount_inr",
        "reward_min_order_value_inr",
    )
    fieldsets = (
        ("Program", {"fields": ("is_enabled",)}),
        (
            "Reward",
            {
                "fields": (
                    "reward_label",
                    "welcome_reward_quantity",
                    "reward_quantity",
                    "reward_validity_days",
                ),
                "description": (
                    "New customer accounts get the welcome gift. When a friend's first order is "
                    "delivered, both customers get the referral reward. Each is a one-use "
                    "personal reward of free cartons of the store's free carton size (Pricing "
                    "config; where none is set, the customer picks the size). The quantities "
                    "and the validity are read when a reward is given: a change applies to "
                    "rewards given from now on."
                ),
            },
        ),
        (
            "Old ₹ rewards",
            {
                "fields": ("reward_amount", "reward_min_order_value"),
                "description": (
                    "Before the free-carton rewards, each customer got ₹ off. These values are "
                    "not used for new rewards; ₹ coupons already given keep their own amount, "
                    "minimum and expiry."
                ),
            },
        ),
        ("Record", {"fields": ("updated_at",)}),
    )

    def changelist_view(self, request, extra_context=None):
        """A singleton: the list page opens the one settings row (created with the defaults
        on first use, as the API does)."""
        if not self.has_view_or_change_permission(request):
            raise PermissionDenied
        config = ReferralSettings.load()
        return redirect(reverse("admin:referrals_referralsettings_change", args=[config.pk]))

    def has_add_permission(self, request) -> bool:
        return False  # the one row always exists (the list page creates it)

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_fieldsets(self, request, obj=None):
        shown = {}
        if not can_manage_offers(request.user):
            # ADR 0004: the referral switch and the reward quantities are offers (Super Admin
            # only): shown in words and left out of the form, so a POST can't change them.
            shown = OFFER_FIELDS
        if obj is not None and not self.has_change_permission(request, obj):
            # View-only roles: the amounts in rupees and the quantities as "N free cartons",
            # instead of bare numbers.
            shown = {name: f"{name}_inr" for name in self.money_fields} | OFFER_FIELDS
        if shown:
            return tuple(
                (
                    title,
                    {
                        **options,
                        "fields": tuple(shown.get(name, name) for name in options["fields"]),
                    },
                )
                for title, options in self.fieldsets
            )
        return self.fieldsets

    def save_model(self, request, obj, form, change):
        with transaction.atomic():
            super().save_model(request, obj, form, change)
            audit.record(
                request.user,
                AUDIT_SETTINGS_CHANGE,
                obj,
                {
                    "fields": sorted(form.changed_data),
                    "is_enabled": obj.is_enabled,
                    "welcome_reward_quantity": obj.welcome_reward_quantity,
                    "reward_quantity": obj.reward_quantity,
                    "reward_amount": f"{obj.reward_amount:.2f}",
                    "reward_validity_days": obj.reward_validity_days,
                    "reward_min_order_value": f"{obj.reward_min_order_value:.2f}",
                },
                ip=request.META.get("REMOTE_ADDR"),
            )

    @display(description="New rewards")
    def reward_label(self, obj) -> str:
        """The saved settings in words (ADR 0003), e.g. "Welcome gift: 2 free cartons.
        Referral: 2 free cartons for each person."."""
        return (
            f"Welcome gift: {free_cartons(obj.welcome_reward_quantity)}. "
            f"Referral: {free_cartons(obj.reward_quantity)} for each person."
        )

    @display(description="Referral program")
    def program_state(self, obj) -> str:
        return "On" if obj.is_enabled else "Off"

    @display(description=LABEL_WELCOME_QUANTITY)
    def welcome_reward_cartons(self, obj) -> str:
        return free_cartons(obj.welcome_reward_quantity)

    @display(description=LABEL_REWARD_QUANTITY)
    def reward_cartons(self, obj) -> str:
        return free_cartons(obj.reward_quantity)

    @display(description=LABEL_REWARD_AMOUNT)
    def reward_amount_inr(self, obj) -> str:
        return inr(obj.reward_amount)

    @display(description=LABEL_MIN_ORDER)
    def reward_min_order_value_inr(self, obj) -> str:
        if not obj.reward_min_order_value:
            return "No minimum"
        return inr(obj.reward_min_order_value)


# --------------------------------------------------------------------------- referrals


@admin.register(Referral)
class ReferralAdmin(_ReadOnlyAdmin):
    list_display = (
        "created_at",
        "referred_label",
        "referrer_label",
        "code",
        "status_badge",
        "reward_order_number",
        "reward",
        "referrer_coupon_code",
        "referred_coupon_code",
        "rewarded_at",
        "note",
    )
    list_display_links = ("created_at", "referred_label")
    list_filter = ("status",)
    list_select_related = (
        "referrer",
        "referred",
        "reward_order",
        "referrer_coupon",
        "referred_coupon",
    )
    search_fields = ("code",)
    search_help_text = "Referral code, or a customer's phone (roles that see customers in full)"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fieldsets = (
        (
            "Referral",
            {"fields": ("referred_label", "referrer_label", "code", "status_badge", "created_at")},
        ),
        (
            "Reward",
            {
                "fields": (
                    "reward_order_number",
                    "reward",
                    "referrer_coupon_code",
                    "referred_coupon_code",
                    "rewarded_at",
                    "note",
                ),
                "description": (
                    "Given once, when the friend's first order is delivered: free cartons for "
                    "each customer (the quantity set when it was given), as a one-use personal "
                    "reward (see Coupons). Older referrals got a ₹ off coupon."
                ),
            },
        ),
    )
    readonly_fields = (
        "referred_label",
        "referrer_label",
        "code",
        "status_badge",
        "created_at",
        "reward_order_number",
        "reward",
        "referrer_coupon_code",
        "referred_coupon_code",
        "rewarded_at",
        "note",
    )

    def get_queryset(self, request):
        return _full_pii(super().get_queryset(request), request).select_related(
            *self.list_select_related
        )

    def get_search_fields(self, request):
        if can_view_full_phone(request.user):
            return (*self.search_fields, *PHONE_SEARCH_FIELDS)
        return self.search_fields

    @display(description="Friend (joined with the code)")
    def referred_label(self, obj) -> str:
        return customer_label(obj.referred, full=getattr(obj, "full_pii", False))

    @display(description="Referrer (code owner)")
    def referrer_label(self, obj) -> str:
        return customer_label(obj.referrer, full=getattr(obj, "full_pii", False))

    @display(
        description="Status",
        ordering="status",
        label={badge.label: badge.tone for badge in REFERRAL_BADGES.values()},
    )
    def status_badge(self, obj) -> str:
        badge = REFERRAL_BADGES.get(obj.status)
        return badge.label if badge else str(obj.status)

    @display(description="Reward order")
    def reward_order_number(self, obj) -> str:
        # Plain text: not every role that views referrals may open orders.
        return obj.reward_order.order_number if obj.reward_order_id else "-"

    @display(description="Reward (each)", ordering="reward_amount")
    def reward(self, obj) -> str:
        # ADR 0002: a free-carton reward has no ₹ amount; older referrals keep theirs.
        # ADR 0003: its cartons are the coupon's own quantity (both get the same).
        if obj.referrer_coupon_id and rewards.is_reward(obj.referrer_coupon):
            return free_cartons(obj.referrer_coupon.value)
        return inr(obj.reward_amount)

    @display(description="Referrer's coupon")
    def referrer_coupon_code(self, obj) -> str:
        return obj.referrer_coupon.code if obj.referrer_coupon_id else "-"

    @display(description="Friend's coupon")
    def referred_coupon_code(self, obj) -> str:
        return obj.referred_coupon.code if obj.referred_coupon_id else "-"


@admin.register(ReferralCode)
class ReferralCodeAdmin(_ReadOnlyAdmin):
    list_display = ("code", "customer", "created_at")
    list_select_related = ("user",)
    search_fields = ("code",)
    search_help_text = "Referral code"
    ordering = ("code",)
    list_per_page = 100
    show_full_result_count = False
    fields = ("code", "customer", "created_at")
    readonly_fields = fields

    def get_queryset(self, request):
        return _full_pii(super().get_queryset(request), request).select_related("user")

    @display(description="Customer")
    def customer(self, obj) -> str:
        return customer_label(obj.user, full=getattr(obj, "full_pii", False))
