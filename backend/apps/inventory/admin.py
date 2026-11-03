"""Inventory admin (05 §2 "Inventory", 05 §3 "Inventory adjust" / "Inventory view").

Rules (docs/admin-panel-architecture.md §5):
- `on_hand` and `reserved` are never editable anywhere in the panel. Stock changes only through
  `apps.inventory.services`: `adjust_stock` (inward / damage), `set_counted_stock` (audit count)
  and `apply_inward_batch` (CSV), each writing `StockMovement` rows.
- The other settings go through their services too: `set_availability`,
  `update_inventory_settings` (threshold, rack) and `set_price_override` (validated against the
  MRP). `save_model` never calls `obj.save()`.
- Service errors show on the form: each form first runs the service in a rolled-back
  transaction (`dry_run`), so the service is the one source of validation rules.
- Store scoping: every queryset is limited by `stores_for(user)`; custom views fetch the row from
  that queryset (another store's row is a 404).
- `StockMovement` (the ledger) is read-only for everyone, superusers included.
"""

import csv
import io
import re
from dataclasses import dataclass

from django import forms
from django.contrib import admin, messages
from django.contrib.admin.utils import unquote
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import F
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.template.response import TemplateResponse
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import action, display
from unfold.widgets import (
    UnfoldAdminFileFieldWidget,
    UnfoldAdminIntegerFieldWidget,
    UnfoldAdminRadioSelectWidget,
    UnfoldAdminSelectWidget,
    UnfoldAdminTextareaWidget,
    UnfoldAdminTextInputWidget,
)

from apps.catalog.models import ProductVariant
from apps.inventory.models import MovementType, StockMovement, StoreInventory
from apps.inventory.services import (
    MAX_REASON,
    InwardRow,
    adjust_stock,
    apply_inward_batch,
    can_adjust_stock,
    set_availability,
    set_counted_stock,
    set_price_override,
    update_inventory_settings,
)
from apps.ops_console.admin_support import ReadOnlyHistoryAdmin, add_service_errors, dry_run
from apps.ops_console.scoping import ScopedStoreFilter, StoreScopedAdminMixin, visible_stores
from apps.ops_console.selectors import ON_SALE

ADJUST_STOCK = "inventory.adjust_stock"
TOGGLE_AVAILABILITY = "inventory.toggle_availability"
# Store price override: Super Admin / Catalog Manager (apps/accounts/roles.py). There is no
# dedicated permission yet (reported to the backend); the price authority is the permission to
# change variant prices.
SET_STORE_PRICE = "catalog.change_productvariant"

# Fields of StoreInventory a user may change, by the permission that unlocks them.
EDITABLE_BY_PERMISSION = {
    TOGGLE_AVAILABILITY: ("is_available",),
    ADJUST_STOCK: ("low_stock_threshold", "rack_location"),
    SET_STORE_PRICE: ("price_override",),
}
SETTINGS_FIELDS = ("is_available", "low_stock_threshold", "rack_location", "price_override")
# Never editable: the identity of the row and the stock numbers (changed only by the services).
ALWAYS_READ_ONLY = (
    "store",
    "variant",
    "on_hand",
    "reserved",
    "available_display",
    "ledger_link",
    "variant_prices",
    "created_at",
    "updated_at",
)

# Bulk inward CSV (docs/admin-panel-architecture.md §10).
INWARD_HEADER = ["sku", "quantity"]
MAX_INWARD_ROWS = 2000
MAX_INWARD_BYTES = 1_000_000


def editable_fields(user) -> tuple[str, ...]:
    fields: list[str] = []
    for permission, names in EDITABLE_BY_PERMISSION.items():
        if user.has_perm(permission):
            fields.extend(names)
    return tuple(name for name in SETTINGS_FIELDS if name in fields)


def apply_settings(inventory_pk: int, changes: dict) -> StoreInventory:
    """Apply changed settings through the services; raises one ValidationError with every
    field's message."""
    inventory = StoreInventory.objects.select_related("variant").get(pk=inventory_pk)
    errors: dict[str, list[str]] = {}

    def attempt(call):
        try:
            call()
        except ValidationError as error:
            for key, messages_ in error.message_dict.items():
                errors.setdefault(key, []).extend(messages_)

    if "is_available" in changes:
        attempt(lambda: set_availability(inventory, is_available=changes["is_available"]))
    settings_kwargs = {
        key: changes[key] for key in ("low_stock_threshold", "rack_location") if key in changes
    }
    if settings_kwargs:
        attempt(lambda: update_inventory_settings(inventory, **settings_kwargs))
    if "price_override" in changes:
        attempt(lambda: set_price_override(inventory, changes["price_override"]))
    if errors:
        raise ValidationError(errors)
    return inventory


class StoreInventoryForm(forms.ModelForm):
    """Holds only the settings the user may change (the admin drops read-only fields). `clean()`
    asks the services, in a rolled-back transaction, whether the change is valid."""

    class Meta:
        model = StoreInventory
        fields = SETTINGS_FIELDS

    def changed_settings(self) -> dict:
        return {
            name: self.cleaned_data[name]
            for name in self.changed_data
            if name in SETTINGS_FIELDS and name in self.cleaned_data
        }

    def clean(self):
        cleaned = super().clean()
        # The services are the validation (price within MRP, threshold, ...); skip the model
        # constraint re-check, which would repeat their messages in database wording.
        self._validate_unique = False
        changes = self.changed_settings()
        if changes and self.instance.pk and not self.errors:
            try:
                dry_run(apply_settings, self.instance.pk, changes)
            except ValidationError as error:
                add_service_errors(self, error)
        return cleaned


class LowStockFilter(admin.SimpleListFilter):
    """`available` (on hand - reserved) against the row's threshold, as the service alerts."""

    title = "stock level"
    parameter_name = "stock"

    def lookups(self, request, model_admin):
        return [
            ("low", "Low (below threshold, incl. out)"),
            ("out", "Out of stock (none available)"),
            ("ok", "At or above threshold"),
        ]

    def queryset(self, request, queryset):
        value = self.value()
        if value == "low":
            return queryset.filter(available_qty__lt=F("low_stock_threshold"))
        if value == "out":
            return queryset.filter(available_qty__lte=0)
        if value == "ok":
            return queryset.filter(available_qty__gte=F("low_stock_threshold"))
        return queryset


class OnSaleFilter(admin.SimpleListFilter):
    """Switched on, at an active store, active variant and product (the dashboard's "on sale",
    `ops_console.selectors.ON_SALE`)."""

    title = "on sale"
    parameter_name = "on_sale"

    def lookups(self, request, model_admin):
        return [("1", "On sale"), ("0", "Not on sale (switched off or inactive)")]

    def queryset(self, request, queryset):
        if self.value() == "1":
            return queryset.filter(ON_SALE)
        if self.value() == "0":
            return queryset.exclude(ON_SALE)
        return queryset


def with_available(queryset):
    return queryset.annotate(available_qty=F("on_hand") - F("reserved"))


STOCK_LEVEL_LABELS = {"Out of stock": "danger", "Low": "warning", "OK": "success"}


@admin.register(StoreInventory)
class StoreInventoryAdmin(StoreScopedAdminMixin, ReadOnlyHistoryAdmin, ModelAdmin):
    form = StoreInventoryForm
    list_display = (
        "store_code",
        "sku",
        "item",
        "on_hand",
        "reserved",
        "available",
        "low_stock_threshold",
        "stock_level",
        "is_available",
        "price",
        "updated_at",
    )
    list_display_links = ("sku", "item")
    list_filter = (
        ScopedStoreFilter,
        LowStockFilter,
        OnSaleFilter,
        "is_available",
        ("variant__product__category", admin.RelatedOnlyFieldListFilter),
    )
    list_select_related = ("store", "variant", "variant__product")
    search_fields = (
        "variant__sku",
        "variant__sap_item_code",
        "variant__barcode",
        "variant__product__name",
    )
    search_help_text = "SKU, SAP item code, barcode or product name"
    ordering = ("store__priority", "store__code", "variant__product__name", "variant__sort_order")
    list_per_page = 50
    show_full_result_count = False
    actions = ["mark_available", "mark_unavailable"]
    actions_list = ["inward"]
    actions_detail = ["adjust"]
    fieldsets = (
        (
            "Stock (changed only by stock adjustments)",
            {"fields": ("store", "variant", "on_hand", "reserved", "available_display")},
        ),
        ("Settings", {"fields": ("is_available", "low_stock_threshold", "rack_location")}),
        ("Price at this store", {"fields": ("variant_prices", "price_override")}),
        ("Record", {"fields": ("ledger_link", "created_at", "updated_at")}),
    )

    # ---------------------------------------------------------------- permissions

    def get_queryset(self, request):
        return with_available(super().get_queryset(request))

    def has_add_permission(self, request) -> bool:
        return False  # rows are created by the stock services (inward creates the row)

    def has_delete_permission(self, request, obj=None) -> bool:
        return False  # the ledger must keep summing to on_hand

    def has_change_permission(self, request, obj=None) -> bool:
        return self.has_view_permission(request, obj) and bool(editable_fields(request.user))

    def has_adjust_stock_permission(self, request, object_id=None) -> bool:
        return self.has_view_permission(request) and request.user.has_perm(ADJUST_STOCK)

    def has_toggle_availability_permission(self, request) -> bool:
        return self.has_view_permission(request) and request.user.has_perm(TOGGLE_AVAILABILITY)

    def get_readonly_fields(self, request, obj=None):
        editable = editable_fields(request.user)
        return ALWAYS_READ_ONLY + tuple(name for name in SETTINGS_FIELDS if name not in editable)

    # ---------------------------------------------------------------- saving (services only)

    def save_model(self, request, obj, form, change):
        changes = form.changed_settings()
        if changes:
            apply_settings(obj.pk, changes)  # validated in form.clean(); never obj.save()

    # ---------------------------------------------------------------- columns

    @display(description="Store", ordering="store__code")
    def store_code(self, obj) -> str:
        return obj.store.code

    @display(description="SKU", ordering="variant__sku")
    def sku(self, obj) -> str:
        return obj.variant.sku

    @display(description="Item", ordering="variant__product__name")
    def item(self, obj) -> str:
        return f"{obj.variant.product.name} {obj.variant.name}"

    @display(description="Available", ordering="available_qty")
    def available(self, obj) -> int:
        return obj.available_qty

    @display(description="Level", label=STOCK_LEVEL_LABELS)
    def stock_level(self, obj) -> str:
        if obj.available_qty <= 0:
            return "Out of stock"
        if obj.available_qty < obj.low_stock_threshold:
            return "Low"
        return "OK"

    @display(description="Price")
    def price(self, obj) -> str:
        if obj.price_override is not None:
            return f"₹{obj.price_override} (store)"
        return f"₹{obj.variant.selling_price}"

    @display(description="Available")
    def available_display(self, obj) -> int:
        return obj.on_hand - obj.reserved

    @display(description="Variant MRP / selling price")
    def variant_prices(self, obj) -> str:
        return f"MRP ₹{obj.variant.mrp} / selling ₹{obj.variant.selling_price}"

    @display(description="Stock ledger")
    def ledger_link(self, obj) -> str:
        url = reverse("admin:inventory_stockmovement_changelist")
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}?store={}&variant={}">'
            "Movements of this item at this store</a>",
            url,
            obj.store_id,
            obj.variant_id,
        )

    # ---------------------------------------------------------------- bulk availability

    def _set_availability(self, request, queryset, available: bool):
        count = 0
        for inventory in queryset.select_related(None):
            if inventory.is_available != available:
                set_availability(inventory, is_available=available)
                count += 1
        word = "available" if available else "unavailable"
        self.message_user(request, f"Marked {count} item(s) {word}.", messages.SUCCESS)

    @action(description="Mark available", permissions=["toggle_availability"])
    def mark_available(self, request, queryset):
        self._set_availability(request, queryset, True)

    @action(
        description="Mark unavailable (shows out of stock)", permissions=["toggle_availability"]
    )
    def mark_unavailable(self, request, queryset):
        self._set_availability(request, queryset, False)

    # ---------------------------------------------------------------- adjust one row

    @action(description="Adjust stock", url_path="adjust", permissions=["adjust_stock"])
    def adjust(self, request, object_id):
        inventory = get_object_or_404(
            self.get_queryset(request).select_related("store", "variant", "variant__product"),
            pk=unquote(object_id),
        )
        if not can_adjust_stock(request.user, inventory.store):
            raise PermissionDenied
        form = StockAdjustmentForm(request.POST or None)
        if request.method == "POST" and form.is_valid():
            try:
                movement = form.apply(inventory, request.user)
            except ValidationError as error:
                add_service_errors(form, error, StockAdjustmentForm.SERVICE_FIELDS)
            else:
                if movement is None:
                    self.message_user(request, "No change: the count equals on hand.")
                else:
                    self.message_user(
                        request,
                        f"{movement.get_type_display()} {movement.delta:+d}: "
                        f"{movement.on_hand_after} now on hand.",
                        messages.SUCCESS,
                    )
                return HttpResponseRedirect(
                    reverse("admin:inventory_storeinventory_change", args=[inventory.pk])
                )
        recent = (
            StockMovement.objects.filter(store=inventory.store, variant=inventory.variant)
            .select_related("created_by")
            .order_by("-created_at", "-id")[:10]
        )
        context = {
            **self.admin_site.each_context(request),
            "opts": self.opts,
            "title": f"Adjust stock: {inventory.variant.product.name} {inventory.variant.name}",
            "inventory": inventory,
            "form": form,
            "recent": recent,
        }
        request.current_app = self.admin_site.name
        return TemplateResponse(request, "admin/inventory/storeinventory/adjust.html", context)

    # ---------------------------------------------------------------- bulk inward (CSV)

    @action(description="Stock inward (CSV)", url_path="inward", permissions=["adjust_stock"])
    def inward(self, request):
        stores = adjustable_stores(request.user)
        confirming = request.method == "POST" and request.POST.get("confirm") == "yes"
        form = InwardForm(
            request.POST or None, request.FILES or None, stores=stores, confirming=confirming
        )
        preview = None
        if request.method == "POST" and form.is_valid():
            store, rows, reason = form.cleaned_data["store"], form.rows, form.cleaned_data["reason"]
            if not can_adjust_stock(request.user, store):
                raise PermissionDenied
            run = apply_inward_batch if confirming else _dry_inward
            try:
                movements = run(store=store, rows=rows, reason=reason, actor=request.user)
            except ValidationError as error:
                add_service_errors(form, error, InwardForm.SERVICE_FIELDS)
            else:
                if confirming:
                    units = sum(movement.delta for movement in movements)
                    self.message_user(
                        request,
                        f"Received {units} unit(s) across {len(movements)} line(s) at "
                        f"{store.code}.",
                        messages.SUCCESS,
                    )
                    changelist = reverse("admin:inventory_storeinventory_changelist")
                    return HttpResponseRedirect(f"{changelist}?store={store.pk}")
                preview = inward_preview(movements)
                form = InwardForm(
                    initial={
                        "store": store.pk,
                        "reason": reason,
                        "payload": rows_to_csv(rows),
                    },
                    stores=stores,
                    confirming=True,
                )
        context = {
            **self.admin_site.each_context(request),
            "opts": self.opts,
            "title": "Stock inward",
            "form": form,
            "preview": preview,
            "header": ",".join(INWARD_HEADER),
            "max_rows": MAX_INWARD_ROWS,
        }
        request.current_app = self.admin_site.name
        return TemplateResponse(request, "admin/inventory/storeinventory/inward.html", context)


# --------------------------------------------------------------------------- adjustment forms


class StockAdjustmentForm(forms.Form):
    INWARD = "inward"
    DAMAGE = "damage"
    COUNT = "count"
    KINDS = (
        (INWARD, "Inward: stock received (adds the quantity)"),
        (DAMAGE, "Damage / expiry: stock removed (subtracts the quantity)"),
        (COUNT, "Audit count: set on hand to the counted quantity"),
    )
    # Service argument -> form field.
    SERVICE_FIELDS = {"delta": "quantity", "counted": "quantity", "type": "kind"}

    kind = forms.ChoiceField(choices=KINDS, widget=UnfoldAdminRadioSelectWidget)
    quantity = forms.IntegerField(
        min_value=0,
        widget=UnfoldAdminIntegerFieldWidget,
        help_text="Units. For an audit count, the number counted on the shelf.",
    )
    reason = forms.CharField(
        max_length=MAX_REASON,
        widget=UnfoldAdminTextInputWidget,
        help_text="Required, e.g. the GRN / invoice number, or what was damaged and why.",
    )

    def apply(self, inventory: StoreInventory, actor) -> StockMovement | None:
        kind = self.cleaned_data["kind"]
        quantity = self.cleaned_data["quantity"]
        reason = self.cleaned_data["reason"]
        if kind == self.COUNT:
            return set_counted_stock(
                store=inventory.store,
                variant=inventory.variant,
                counted=quantity,
                reason=reason,
                actor=actor,
            )
        movement_type = MovementType.INWARD if kind == self.INWARD else MovementType.DAMAGE
        delta = quantity if kind == self.INWARD else -quantity
        return adjust_stock(
            store=inventory.store,
            variant=inventory.variant,
            delta=delta,
            movement_type=movement_type,
            reason=reason,
            actor=actor,
        )


def adjustable_stores(user):
    """Stores where `user` may adjust stock (05 §3: Store Manager own store, Super Admin all)."""
    if not user.has_perm(ADJUST_STOCK):
        return visible_stores(user).none()
    return visible_stores(user).order_by("priority", "code")


def parse_inward_csv(text: str) -> list[InwardRow]:
    """`sku,quantity` lines (docs/admin-panel-architecture.md §10). The header row is optional;
    line N in messages is the Nth data line, as the service counts."""
    reader = csv.reader(io.StringIO(text.strip("\r\n")))
    lines = list(reader)
    if lines and [cell.strip().lower() for cell in lines[0]] == INWARD_HEADER:
        lines = lines[1:]
    if not lines:
        raise ValidationError("The file has no rows.")
    if len(lines) > MAX_INWARD_ROWS:
        raise ValidationError(
            f"At most {MAX_INWARD_ROWS} rows per file; split it into several files."
        )
    rows, errors = [], []
    for number, cells in enumerate(lines, start=1):
        if len(cells) != len(INWARD_HEADER):
            errors.append(f"line {number}: expected 2 values (sku,quantity), found {len(cells)}.")
            continue
        sku, quantity = cells[0].strip(), cells[1].strip()
        if not sku:
            errors.append(f"line {number}: the SKU is empty.")
        elif not re.fullmatch(r"[0-9]+", quantity):
            errors.append(f"line {number}: the quantity must be a whole number above 0.")
        else:
            rows.append(InwardRow(sku=sku, quantity=int(quantity)))
    if errors:
        raise ValidationError(errors)
    return rows


def rows_to_csv(rows: list[InwardRow]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(INWARD_HEADER)
    for row in rows:
        writer.writerow([row.sku, row.quantity])
    return buffer.getvalue()


class InwardForm(forms.Form):
    """Step 1: upload (or paste) and preview through a rolled-back service call. Step 2
    (`confirm=yes`): the previewed rows travel in `payload` and the service runs for real; it
    validates everything again, so the payload needs no trust."""

    SERVICE_FIELDS = {"rows": "file"}

    store = forms.ModelChoiceField(queryset=None, widget=UnfoldAdminSelectWidget)
    file = forms.FileField(
        required=False,
        widget=UnfoldAdminFileFieldWidget,
        help_text="CSV, UTF-8, header sku,quantity. The SKU column also accepts SAP item codes.",
    )
    pasted = forms.CharField(
        required=False,
        label="Or paste rows",
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 4, "placeholder": "JV-OIL-1L,24"}),
        help_text="One sku,quantity per line, for a few items.",
    )
    reason = forms.CharField(
        max_length=MAX_REASON,
        widget=UnfoldAdminTextInputWidget,
        help_text="Required, e.g. the GRN or invoice number.",
    )
    payload = forms.CharField(required=False, widget=forms.HiddenInput)

    def __init__(self, *args, stores, confirming: bool = False, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["store"].queryset = stores
        self.confirming = confirming
        self.rows: list[InwardRow] = []

    def clean(self):
        cleaned = super().clean()
        if self.confirming:
            text = cleaned.get("payload") or ""
        else:
            upload = cleaned.get("file")
            if upload is not None:
                if upload.size > MAX_INWARD_BYTES:
                    self.add_error("file", "The file is larger than 1 MB; split it.")
                    return cleaned
                try:
                    text = upload.read().decode("utf-8-sig")
                except UnicodeDecodeError:
                    self.add_error("file", "Save the file as CSV UTF-8 and try again.")
                    return cleaned
            else:
                text = cleaned.get("pasted") or ""
            if not text.strip():
                self.add_error("file", "Choose a CSV file or paste rows.")
                return cleaned
        try:
            self.rows = parse_inward_csv(text)
        except ValidationError as error:
            for message in error.messages:
                self.add_error("file", message)
        return cleaned


def _dry_inward(**kwargs):
    return dry_run(apply_inward_batch, **kwargs)


@dataclass(frozen=True)
class PreviewRow:
    sku: str
    item: str
    quantity: int
    before: int
    after: int


def inward_preview(movements: list[StockMovement]) -> list[PreviewRow]:
    variants = ProductVariant.objects.select_related("product").in_bulk(
        {movement.variant_id for movement in movements}
    )
    rows = []
    for movement in movements:
        variant = variants[movement.variant_id]
        rows.append(
            PreviewRow(
                sku=variant.sku,
                item=f"{variant.product.name} {variant.name}",
                quantity=movement.delta,
                before=movement.on_hand_after - movement.delta,
                after=movement.on_hand_after,
            )
        )
    return rows


# --------------------------------------------------------------------------- ledger


class MovementVariantFilter(admin.SimpleListFilter):
    """`?variant=<id>` from an inventory row's "Movements" link (no lookup list: too many)."""

    title = "item"
    parameter_name = "variant"

    def lookups(self, request, model_admin):
        value = self.value()
        if not value:
            return []
        variant = None
        if value.isdigit():
            variant = ProductVariant.objects.filter(pk=int(value)).only("sku").first()
        return [(value, variant.sku if variant else f"#{value}")]

    def queryset(self, request, queryset):
        value = self.value()
        if not value:
            return queryset
        return queryset.filter(variant_id=int(value)) if value.isdigit() else queryset.none()


@admin.register(StockMovement)
class StockMovementAdmin(StoreScopedAdminMixin, ModelAdmin):
    """The append-only stock ledger (07 §2.4): read-only for everyone, superusers included."""

    list_display = (
        "created_at",
        "store_code",
        "sku",
        "type_label",
        "signed_delta",
        "on_hand_after",
        "reason",
        "actor",
    )
    list_filter = (
        ScopedStoreFilter,
        MovementVariantFilter,
        "type",
        ("created_at", admin.DateFieldListFilter),
    )
    list_select_related = ("store", "variant", "created_by")
    search_fields = ("variant__sku", "variant__sap_item_code", "reason")
    search_help_text = "SKU, SAP item code or reason"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fields = (
        "created_at",
        "store",
        "variant",
        "type",
        "delta",
        "on_hand_after",
        "reason",
        "created_by",
    )
    readonly_fields = fields

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    @display(description="Store", ordering="store__code")
    def store_code(self, obj) -> str:
        return obj.store.code

    @display(description="SKU", ordering="variant__sku")
    def sku(self, obj) -> str:
        return obj.variant.sku

    @display(
        description="Type",
        label={
            MovementType.INWARD.label: "success",
            MovementType.RETURN.label: "success",
            MovementType.TRANSFER_IN.label: "success",
            MovementType.SALE.label: "info",
            MovementType.TRANSFER_OUT.label: "info",
            MovementType.DAMAGE.label: "danger",
            MovementType.AUDIT_ADJUSTMENT.label: "warning",
        },
    )
    def type_label(self, obj) -> str:
        return obj.get_type_display()

    @display(description="Change", ordering="delta")
    def signed_delta(self, obj) -> str:
        return f"{obj.delta:+d}"

    @display(description="By")
    def actor(self, obj) -> str:
        user = obj.created_by
        if user is None:
            return "System"
        return user.name or user.email or f"User {user.pk}"
