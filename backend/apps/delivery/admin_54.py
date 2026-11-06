"""SLICE 5.4 admin: rider cash ledger, earnings, payouts and earning rules (05 §2 "Rider earnings
& payouts", 07 §2.8). Imported by `admin.py` only once the 5.4 models are on the branch.

- Cash ledger (`delivery.view_ridercashledger`: Super Admin, Ops, Store Manager own, Finance):
  read-only and append-only; deposits are recorded on `/ops/cash/` (`cash.record_deposit`).
- Earnings and payouts (`view_riderearning` / `view_payout`: Super Admin, Finance): read-only;
  batches, "mark paid" and "void" are on `/ops/payouts/` (`payouts.*`).
- Earning rules: Super Admin adds a new rule (a rule in force is never edited, the model says
  "add a new one"); no change or delete. The add is audited (`delivery.earning_rule_added`).

Store-scoped roles see only riders whose home store is one of theirs.
"""

from django.contrib import admin
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.core import audit
from apps.core.net import client_ip
from apps.delivery.admin import ReadOnlyMixin, ScopedObjectMixin
from apps.delivery.models import EarningRule, Payout, RiderCashLedger, RiderEarning
from apps.ops_console.money import inr
from apps.ops_console.scoping import is_store_scoped
from apps.stores.services import stores_for


def _scoped(queryset, user, path: str = "rider__home_store__in"):
    return queryset.filter(**{path: stores_for(user)}) if is_store_scoped(user) else queryset


@admin.register(RiderCashLedger)
class RiderCashLedgerAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = (
        "recorded_at",
        "rider_name",
        "entry_type",
        "amount_inr",
        "balance_inr",
        "order_number",
        "store_code",
        "recorded_by",
    )
    list_filter = ("entry_type",)
    search_fields = ("rider__full_name", "order__order_number")
    list_select_related = ("rider", "order", "store", "recorded_by")
    ordering = ("-recorded_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = (
        "rider_name",
        "entry_type",
        "amount_inr",
        "balance_inr",
        "order_number",
        "store_code",
        "recorded_by",
        "note",
        "recorded_at",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return _scoped(
            super().get_queryset(request).select_related("rider", "order", "store", "recorded_by"),
            request.user,
        )

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name

    @display(description="Amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Cash in hand after")
    def balance_inr(self, obj) -> str:
        return inr(obj.balance_after)

    @display(description="Order")
    def order_number(self, obj) -> str:
        return obj.order.order_number if obj.order_id else "-"

    @display(description="Store")
    def store_code(self, obj) -> str:
        return obj.store.code if obj.store_id else "-"


@admin.register(RiderEarning)
class RiderEarningAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = ("earned_at", "rider_name", "type", "amount_inr", "order_number", "paid")
    list_filter = ("type",)
    search_fields = ("rider__full_name", "task__order__order_number")
    list_select_related = ("rider", "task__order", "payout")
    ordering = ("-earned_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = ("rider_name", "type", "amount_inr", "order_number", "note", "earned_at", "paid")
    readonly_fields = fields

    def get_queryset(self, request):
        return _scoped(
            super().get_queryset(request).select_related("rider", "task__order", "payout"),
            request.user,
        )

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name

    @display(description="Amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)

    @display(description="Order")
    def order_number(self, obj) -> str:
        return obj.task.order.order_number if obj.task_id else "-"

    @display(description="Payout", boolean=True)
    def paid(self, obj) -> bool:
        return bool(obj.payout_id) and obj.payout.status == "PAID"


@admin.register(Payout)
class PayoutAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = ("rider_name", "period_start", "period_end", "amount_inr", "status", "paid_at")
    list_filter = ("status",)
    search_fields = ("rider__full_name", "reference")
    list_select_related = ("rider",)
    ordering = ("-period_end", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = (
        "rider_name",
        "period_start",
        "period_end",
        "amount_inr",
        "status",
        "reference",
        "paid_at",
        "created_at",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return _scoped(super().get_queryset(request).select_related("rider"), request.user)

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name

    @display(description="Amount")
    def amount_inr(self, obj) -> str:
        return inr(obj.amount)


@admin.register(EarningRule)
class EarningRuleAdmin(ModelAdmin):
    list_display = ("effective_from", "base_inr", "per_km_inr", "per_km_after", "note")
    ordering = ("-effective_from",)
    fields = ("base_per_order", "per_km_rate", "per_km_after", "effective_from", "note")

    def has_change_permission(self, request, obj=None) -> bool:
        return False  # a rule in force is never edited: add a new one

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    def save_model(self, request, obj, form, change):
        obj.created_by = request.user
        super().save_model(request, obj, form, change)
        audit.record(
            request.user,
            "delivery.earning_rule_added",
            obj,
            {
                "base_per_order": f"{obj.base_per_order:.2f}",
                "per_km_rate": f"{obj.per_km_rate:.2f}",
                "per_km_after": f"{obj.per_km_after:.2f}",
            },
            ip=client_ip(request),
        )

    @display(description="Base per order")
    def base_inr(self, obj) -> str:
        return inr(obj.base_per_order)

    @display(description="Per km")
    def per_km_inr(self, obj) -> str:
        return inr(obj.per_km_rate)
