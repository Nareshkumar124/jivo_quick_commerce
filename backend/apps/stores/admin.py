"""Stores admin (05 §2 "Dark stores", "Serviceability requests"; 05 §3 "Stores & service areas").

- Dark stores: Super Admin edits; Ops views all; Store Manager views only their own stores
  (`stores_for`). Stores are deactivated, never deleted (stock, orders and invoices point at
  them).
- The location pin and service area use the swappable map editor in `apps.ops_console.maps`.
  View-only roles see a read-only map instead of raw coordinates.
- Notify-me leads: read-only list with a map, phones shown per the PII policy.
"""

from django.contrib import admin, messages
from django.db.models import BooleanField, Value
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import action, display

from apps.ops_console.maps import MAP_FORMFIELD_OVERRIDES, MAP_MEDIA, feature, read_only_map
from apps.ops_console.pii import can_view_full_phone, mask_phone
from apps.ops_console.scoping import StoreScopedAdminMixin, visible_stores
from apps.stores.models import DarkStore, ServiceabilityRequest, StoreTiming
from apps.stores.services import store_status

# Map at most this many leads (newest first under the current filters) above the list.
LEADS_MAP_LIMIT = 500


class StoreTimingInline(TabularInline):
    model = StoreTiming
    extra = 0
    fields = ("weekday", "opens_at", "closes_at")
    ordering = ("weekday", "opens_at")
    verbose_name = "opening window"
    verbose_name_plural = (
        "Opening hours (IST). Several windows per day are allowed; a store without windows "
        "is never open. Past midnight: end the day at 23:59 and start the next day at 00:00."
    )


def set_accepting_orders(store: DarkStore, accepting: bool) -> bool:
    """Pause or resume orders at a store; True if it changed. Saves the one field so the
    post-save signal drops the serviceability snapshot.

    TODO(backend gap): replace with a `stores.services.set_accepting_orders(store, accepting,
    actor)` that records who paused the store (DarkStore has no history yet).
    """
    if store.is_accepting_orders == accepting:
        return False
    store.is_accepting_orders = accepting
    store.save(update_fields=["is_accepting_orders", "updated_at"])
    return True


STATUS_LABELS = {
    "Open now": "success",
    "Closed now": "info",
    "Paused": "warning",
    "Inactive": "danger",
}


@admin.register(DarkStore)
class DarkStoreAdmin(StoreScopedAdminMixin, ModelAdmin):
    store_field = "pk"
    formfield_overrides = {**ModelAdmin.formfield_overrides, **MAP_FORMFIELD_OVERRIDES}
    inlines = [StoreTimingInline]
    list_display = (
        "code",
        "name",
        "city",
        "status_now",
        "is_accepting_orders",
        "is_active",
        "avg_prep_minutes",
        "priority",
    )
    list_display_links = ("code", "name")
    list_filter = ("is_active", "is_accepting_orders", "city")
    search_fields = ("code", "name", "city", "pincode")
    search_help_text = "Code, name, city or pincode"
    ordering = ("priority", "code")
    actions = ["pause_orders", "resume_orders"]
    readonly_fields = (
        "status_now",
        "location_display",
        "service_area_map",
        "created_at",
        "updated_at",
    )
    fieldsets = (
        (
            "Store",
            {"fields": ("code", "name", "is_active", "is_accepting_orders", "priority")},
        ),
        ("Address", {"fields": ("address", "city", "state", "pincode", "phone")}),
        (
            "Location pin",
            {
                "fields": ("location",),
                "description": "Click the map at the store entrance. Riders navigate here.",
            },
        ),
        (
            "Service area",
            {
                "fields": ("service_area",),
                "description": (
                    "Draw the delivery area (one or more polygons). Customers inside it are "
                    "served by this store; where areas overlap, the open, nearest store wins, "
                    "then the lower priority number."
                ),
            },
        ),
        (
            "Operations",
            {"fields": ("avg_prep_minutes", "auto_accept_orders", "dispatch_radius_km")},
        ),
        ("Compliance & invoicing", {"fields": ("gstin", "fssai_license_no", "invoice_prefix")}),
        ("Record", {"fields": ("created_at", "updated_at")}),
    )

    @property
    def media(self):
        return super().media + MAP_MEDIA

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("timings")

    def has_delete_permission(self, request, obj=None) -> bool:
        return False  # deactivate instead: stock, orders and invoices reference the store

    def get_fieldsets(self, request, obj=None):
        """View-only roles get read-only maps instead of the editors (raw coordinates)."""
        fieldsets = super().get_fieldsets(request, obj)
        if obj is None or self.has_change_permission(request, obj):
            return fieldsets
        swap = {"location": "location_display", "service_area": "service_area_map"}
        return [
            (title, {**options, "fields": tuple(swap.get(f, f) for f in options["fields"])})
            for title, options in fieldsets
        ]

    @display(description="Now", label=STATUS_LABELS)
    def status_now(self, obj) -> str:
        if not obj.is_active:
            return "Inactive"
        if not obj.is_accepting_orders:
            return "Paused"
        return "Open now" if store_status(obj).is_open else "Closed now"

    @display(description="Location pin")
    def location_display(self, obj) -> str:
        if not obj.location:
            return "-"
        return read_only_map(
            [feature(obj.location, kind="store", name=obj.name)],
            height=240,
            label=f"Location of {obj.name}",
        )

    @display(description="Service area")
    def service_area_map(self, obj) -> str:
        features = []
        if obj.service_area:
            features.append(feature(obj.service_area, kind="area", name=obj.name))
        if obj.location:
            features.append(feature(obj.location, kind="store", name=obj.name))
        return read_only_map(features, label=f"Service area of {obj.name}")

    def _set_accepting(self, request, queryset, accepting: bool):
        count = sum(set_accepting_orders(store, accepting) for store in queryset)
        verb = "Resumed" if accepting else "Paused"
        self.message_user(request, f"{verb} orders at {count} store(s).", messages.SUCCESS)

    @action(description="Pause orders (temporarily closed)", permissions=["change"])
    def pause_orders(self, request, queryset):
        self._set_accepting(request, queryset, False)

    @action(description="Resume orders", permissions=["change"])
    def resume_orders(self, request, queryset):
        self._set_accepting(request, queryset, True)


# --------------------------------------------------------------------------- notify-me leads


@admin.register(ServiceabilityRequest)
class ServiceabilityRequestAdmin(ModelAdmin):
    """ "Notify me" leads for expansion planning (05 §2). Read-only; Super Admin may delete."""

    list_display = ("created_at", "address_text", "coordinates", "phone_display", "customer")
    list_filter = (("created_at", admin.DateFieldListFilter),)
    search_fields = ("address_text",)
    search_help_text = "Address text"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    list_select_related = ("user",)
    list_before_template = "admin/stores/serviceabilityrequest/leads_map.html"
    fields = ("created_at", "address_text", "coordinates", "phone_display", "customer", "lead_map")
    readonly_fields = fields

    @property
    def media(self):
        return super().media + MAP_MEDIA

    def get_queryset(self, request):
        # The PII decision travels on each row: list columns do not receive the request.
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

    def changelist_view(self, request, extra_context=None):
        extra_context = {**(extra_context or {}), "leads_map": self.leads_map(request)}
        return super().changelist_view(request, extra_context)

    def leads_map(self, request) -> str:
        """The newest leads (list filters do not apply) and the visible active store areas."""
        leads = self.get_queryset(request).only("location", "created_at")[:LEADS_MAP_LIMIT]
        features = [feature(lead.location, kind="lead") for lead in leads]
        stores = (
            visible_stores(request.user)
            .filter(is_active=True)
            .only("name", "location", "service_area")
        )
        for store in stores:
            features.append(feature(store.service_area, kind="area", name=store.name))
            features.append(feature(store.location, kind="store", name=store.name))
        return read_only_map(features, height=420, label="Notify-me leads and store areas")

    @display(description="Lat, lng")
    def coordinates(self, obj) -> str:
        return f"{obj.location.y:.5f}, {obj.location.x:.5f}"

    @display(description="Phone")
    def phone_display(self, obj) -> str:
        if not obj.phone:
            return "-"
        return obj.phone if getattr(obj, "full_pii", False) else mask_phone(obj.phone)

    @display(description="Customer")
    def customer(self, obj) -> str:
        if obj.user_id is None:
            return "-"
        name = obj.user.name or f"Customer {obj.user_id}"
        if not getattr(obj, "full_pii", False):
            return name
        url = reverse("admin:accounts_customer_change", args=[obj.user_id])
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>', url, name
        )

    @display(description="Map")
    def lead_map(self, obj) -> str:
        return read_only_map(
            [feature(obj.location, kind="lead")], height=280, label="Lead location"
        )
