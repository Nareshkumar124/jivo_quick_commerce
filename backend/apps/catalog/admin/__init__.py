"""Catalog admin (05 §2 "Categories", "Products & variants", "Collections", "Banners"; 05 §3
"Catalog, collections, banners": Super Admin and Catalog Manager edit, Ops / Store Manager /
Store Staff / Support view).

The catalog is central (no store scoping). Prices are master data, kept in the variant's price
history; store price overrides live in the inventory admin.

ADR 0004 (user, 2026-11-26): only a Super Admin changes prices (`catalog.manage_prices`, normally
through Ops "Store management → Bottle prices"). Without it, a saved variant's MRP and selling
price are read-only here (variant page, the product page's variant rows, CSV import) and the
volume price tiers are view-only; a crafted POST changes nothing (the fields are not in the
form, or are disabled). A new variant still gets its first price from the catalog roles: it is
on sale nowhere until a store has stock of it.
"""

from django.contrib import admin
from django.core.exceptions import ValidationError
from django.db.models import Case, Count, IntegerField, Max, Min, Q, Value, When
from django.db.models.functions import Coalesce
from django.forms.models import BaseInlineFormSet
from django.utils import timezone
from django.utils.html import format_html, format_html_join
from import_export.admin import ImportExportModelAdmin
from unfold.admin import ModelAdmin, StackedInline, TabularInline
from unfold.contrib.import_export.forms import ExportForm
from unfold.decorators import display

from apps.catalog.admin.forms import (
    LABEL_LABELS,
    CollectionItemFormSet,
    ProductAdminForm,
)
from apps.catalog.admin.resources import (
    CategoryResource,
    ProductResource,
    ProductVariantResource,
)
from apps.catalog.models import (
    MAX_COLLECTION_ITEMS,
    Banner,
    Category,
    Collection,
    CollectionItem,
    Product,
    ProductImage,
    ProductVariant,
    TrendingSearch,
    VariantPriceTier,
)
from apps.catalog.validators import LABEL_TEXT_KEYS
from apps.ops_console.admin_support import (
    ImportExportPermissionsMixin,
    LimitedImportForm,
    ReadOnlyHistoryAdmin,
)
from apps.ops_console.store_management import can_manage_prices

PRICE_FIELDS = ("mrp", "selling_price")
MSG_PRICE_LOCKED = "Only a Super Admin can change prices (Store management → Bottle prices)."


class LockSavedPricesMixin:
    """For a variant form: a saved variant's MRP and selling price are disabled, so Django keeps
    the saved values whatever is posted. A new variant (no pk) keeps its price fields."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance.pk is None:
            return
        for name in PRICE_FIELDS:
            field = self.fields.get(name)
            if field is not None:
                field.disabled = True
                field.help_text = MSG_PRICE_LOCKED


class CatalogImportExportAdmin(ImportExportPermissionsMixin, ModelAdmin, ImportExportModelAdmin):
    """CSV and Excel (.xlsx) import/export with unfold's forms (docs/admin-panel-architecture.md
    §10). Import needs add + change on the model (catalog roles), export needs view.

    The formats are the project's (`IMPORT_EXPORT_FORMATS` = `apps.core.export_formats`), which
    escape spreadsheet formulas on export: never set `import_formats` / `export_formats` here
    (guard test in apps/catalog/tests/test_admin_import_export.py). Uploads are limited by
    `LimitedImportForm` (1 MB, 2000 rows, UTF-8 CSV or a readable .xlsx)."""

    import_form_class = LimitedImportForm
    export_form_class = ExportForm


def thumbnail(image, size: int = 40) -> str:
    if not image:
        return "-"
    return format_html(
        '<img src="{}" alt="" width="{}" height="{}" loading="lazy" '
        'style="object-fit: cover; border-radius: 4px">',
        image.url,
        size,
        size,
    )


def format_html_list(items) -> str:
    if not items:
        return "-"
    return format_html(
        '<ul class="list-disc ml-4">{}</ul>',
        format_html_join("", "<li>{}</li>", ((item,) for item in items)),
    )


def format_html_table(table: dict) -> str:
    """A label nutrition table (validated shape: columns, rows of name/values/is_sub_row)."""
    head = format_html_join(
        "", '<th class="pr-4 text-left">{}</th>', ((c,) for c in table["columns"])
    )
    rows = format_html_join(
        "",
        '<tr><td class="pr-4{}">{}</td>{}</tr>',
        (
            (
                " pl-4" if row.get("is_sub_row") else "",
                row["name"],
                format_html_join("", '<td class="pr-4">{}</td>', ((v,) for v in row["values"])),
            )
            for row in table["rows"]
        ),
    )
    return format_html(
        "<table><thead><tr><th></th>{}</tr></thead><tbody>{}</tbody></table>", head, rows
    )


# --------------------------------------------------------------------------- categories


class CategoryLevelFilter(admin.SimpleListFilter):
    title = "level"
    parameter_name = "level"

    def lookups(self, request, model_admin):
        return [("top", "Top level"), ("sub", "Sub-category")]

    def queryset(self, request, queryset):
        if self.value() == "top":
            return queryset.filter(parent__isnull=True)
        if self.value() == "sub":
            return queryset.filter(parent__isnull=False)
        return queryset


@admin.register(Category)
class CategoryAdmin(CatalogImportExportAdmin):
    resource_classes = [CategoryResource]
    list_display = (
        "tree_name",
        "image_preview",
        "slug",
        "product_count",
        "sort_order",
        "is_active",
    )
    list_display_links = ("tree_name",)
    list_editable = ("sort_order", "is_active")
    list_filter = (CategoryLevelFilter, "is_active")
    list_select_related = ("parent",)
    search_fields = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    fields = ("name", "slug", "parent", "image", "image_preview", "sort_order", "is_active")
    readonly_fields = ("image_preview",)

    def get_queryset(self, request):
        """Tree order: each top-level category followed by its sub-categories."""
        return (
            super()
            .get_queryset(request)
            .annotate(
                root_sort=Coalesce("parent__sort_order", "sort_order"),
                root_name=Coalesce("parent__name", "name"),
                is_child=Case(
                    When(parent__isnull=True, then=Value(0)),
                    default=Value(1),
                    output_field=IntegerField(),
                ),
                products_total=Count("products", distinct=True),
            )
            .order_by("root_sort", "root_name", "is_child", "sort_order", "name")
        )

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "parent":
            kwargs["queryset"] = Category.objects.filter(parent__isnull=True)
            kwargs["help_text"] = "Empty for a top-level category. Two levels only."
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

    @display(description="Category", ordering="root_name")
    def tree_name(self, obj) -> str:
        return f"{obj.parent.name} / {obj.name}" if obj.parent_id else obj.name

    @display(description="Image")
    def image_preview(self, obj) -> str:
        return thumbnail(obj.image)

    @display(description="Products", ordering="products_total")
    def product_count(self, obj) -> int:
        return obj.products_total


# --------------------------------------------------------------------------- products


class ProductVariantInline(StackedInline):
    model = ProductVariant
    extra = 0
    tab = True
    show_change_link = True
    fieldsets = (
        (
            None,
            {
                "fields": (
                    ("sku", "name", "net_quantity"),
                    ("mrp", "selling_price", "min_qty_per_order", "max_qty_per_order"),
                    ("unit_value", "unit", "weight_grams"),
                    ("barcode", "sap_item_code"),
                    ("is_active", "sort_order"),
                )
            },
        ),
    )

    def get_formset(self, request, obj=None, **kwargs):
        formset = super().get_formset(request, obj, **kwargs)
        if not can_manage_prices(request.user):
            # ADR 0004: saved rows keep their price; new rows still take a first price.
            formset.form = type(formset.form.__name__, (LockSavedPricesMixin, formset.form), {})
        return formset


class ProductImageInline(TabularInline):
    model = ProductImage
    extra = 0
    tab = True
    fields = ("image", "preview", "variant", "alt_text", "sort_order")
    readonly_fields = ("preview",)

    def get_formset(self, request, obj=None, **kwargs):
        formset = super().get_formset(request, obj, **kwargs)
        field = formset.form.base_fields.get("variant")
        if field is not None:  # only this product's variants
            field.queryset = (
                ProductVariant.objects.filter(product=obj)
                if obj is not None
                else ProductVariant.objects.none()
            )
        return formset

    @display(description="Preview")
    def preview(self, obj) -> str:
        return thumbnail(obj.image, 56)


def _label_display(key: str):
    def show(self, obj) -> str:
        return obj.label(key) or "-"

    show.__name__ = key
    return display(description=LABEL_LABELS[key])(show)


@admin.register(Product)
class ProductAdmin(CatalogImportExportAdmin):
    resource_classes = [ProductResource]
    form = ProductAdminForm
    inlines = [ProductVariantInline, ProductImageInline]
    list_display = (
        "name",
        "category",
        "variant_count",
        "price_range",
        "gst_rate",
        "hsn_code",
        "is_veg",
        "is_active",
        "sort_order",
    )
    list_filter = ("is_active", "is_veg", "category", "gst_rate")
    list_select_related = ("category",)
    search_fields = (
        "name",
        "slug",
        "variants__sku",
        "variants__sap_item_code",
        "variants__barcode",
    )
    search_help_text = "Name, slug, SKU, SAP item code or barcode"
    prepopulated_fields = {"slug": ("name",)}
    list_per_page = 50
    fieldsets = (
        (
            "Product",
            {
                "fields": (
                    "name",
                    "slug",
                    "category",
                    "brand",
                    ("is_active", "is_veg"),
                    "sort_order",
                )
            },
        ),
        (
            "Description",
            {"fields": ("short_description", "description", "highlights_text", "search_keywords")},
        ),
        ("Tax", {"fields": (("hsn_code", "gst_rate"),)}),
        (
            "Label information (09 §4, Legal Metrology / FSSAI)",
            {"fields": (*LABEL_TEXT_KEYS, "nutrition")},
        ),
    )
    readonly_fields = ()

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(
                variants_total=Count("variants", distinct=True),
                price_min=Min("variants__selling_price", filter=Q(variants__is_active=True)),
                price_max=Max("variants__selling_price", filter=Q(variants__is_active=True)),
            )
        )

    def get_readonly_fields(self, request, obj=None):
        if obj is not None and not self.has_change_permission(request, obj):
            # View-only roles: show the assembled values (admin methods below).
            return ("highlights_text", *LABEL_TEXT_KEYS, "nutrition")
        return super().get_readonly_fields(request, obj)

    @display(description="Variants", ordering="variants_total")
    def variant_count(self, obj) -> int:
        return obj.variants_total

    @display(description="Selling price (active variants)")
    def price_range(self, obj) -> str:
        if obj.price_min is None:
            return "-"
        if obj.price_min == obj.price_max:
            return f"₹{obj.price_min}"
        return f"₹{obj.price_min} to ₹{obj.price_max}"

    @display(description="Highlights")
    def highlights_text(self, obj) -> str:
        return format_html_list(obj.highlights)

    @display(description="Nutrition table")
    def nutrition(self, obj) -> str:
        table = (obj.attributes or {}).get("nutrition")
        if not table:
            return "-"
        return format_html_table(table)


for _key in LABEL_TEXT_KEYS:
    setattr(ProductAdmin, _key, _label_display(_key))


class VariantPriceTierFormSet(BaseInlineFormSet):
    """Checks every slab price against the MRP saved on the same page: the variant may be new
    (the model's own check needs a saved variant) or its MRP may change in this form."""

    def clean(self):
        super().clean()
        mrp = getattr(self.instance, "mrp", None)
        if mrp is None:
            return
        for form in self.forms:
            data = getattr(form, "cleaned_data", None) or {}
            price = data.get("price")
            if not data.get("DELETE") and price is not None and price > mrp:
                raise ValidationError(f"A slab price (₹{price}) can't be above the MRP (₹{mrp}).")


class VariantPriceTierInline(TabularInline):
    """Volume (slab) prices: from `min_order_units` boxes in the whole order, this variant costs
    `price` each (GST included, at most the MRP). See docs/adr/0001-volume-price-tiers.md."""

    model = VariantPriceTier
    formset = VariantPriceTierFormSet
    fk_name = "variant"
    extra = 0
    tab = True
    fields = ("min_order_units", "price")
    ordering = ("min_order_units",)

    # ADR 0004: tiers are prices, so only `catalog.manage_prices` adds, changes or removes them
    # (Django ignores posted rows the inline may not add, change or delete).
    def has_add_permission(self, request, obj=None) -> bool:
        return super().has_add_permission(request, obj) and can_manage_prices(request.user)

    def has_change_permission(self, request, obj=None) -> bool:
        return super().has_change_permission(request, obj) and can_manage_prices(request.user)

    def has_delete_permission(self, request, obj=None) -> bool:
        return super().has_delete_permission(request, obj) and can_manage_prices(request.user)


@admin.register(ProductVariant)
class ProductVariantAdmin(ReadOnlyHistoryAdmin, CatalogImportExportAdmin):
    """Every SKU. Price changes are kept in the variant's history (History button)."""

    resource_classes = [ProductVariantResource]
    inlines = [VariantPriceTierInline]
    list_display = (
        "sku",
        "product",
        "name",
        "mrp",
        "selling_price",
        "discount",
        "max_qty_per_order",
        "sap_item_code",
        "barcode",
        "is_active",
    )
    list_display_links = ("sku",)
    list_filter = ("is_active", "product__category")
    list_select_related = ("product",)
    search_fields = ("sku", "sap_item_code", "barcode", "product__name", "name")
    search_help_text = "SKU, SAP item code, barcode or product name"
    ordering = ("product__name", "sort_order", "id")
    list_per_page = 50
    autocomplete_fields = ("product",)
    fieldsets = (
        (None, {"fields": ("product", ("sku", "name", "net_quantity"))}),
        (
            "Price",
            {"fields": (("mrp", "selling_price"), ("min_qty_per_order", "max_qty_per_order"))},
        ),
        ("Unit price display", {"fields": (("unit_value", "unit"),)}),
        ("Codes", {"fields": (("barcode", "sap_item_code"), "weight_grams")}),
        (None, {"fields": (("is_active", "sort_order"),)}),
    )

    def get_readonly_fields(self, request, obj=None):
        fields = tuple(super().get_readonly_fields(request, obj))
        if obj is not None and not can_manage_prices(request.user):
            fields += PRICE_FIELDS  # ADR 0004: left out of the form, so a POST can't set them
        return fields

    def get_fieldsets(self, request, obj=None):
        fieldsets = super().get_fieldsets(request, obj)
        if obj is None or can_manage_prices(request.user):
            return fieldsets
        return tuple(
            (title, {**options, "description": MSG_PRICE_LOCKED} if title == "Price" else options)
            for title, options in fieldsets
        )

    def get_search_results(self, request, queryset, search_term):
        queryset, may_have_duplicates = super().get_search_results(request, queryset, search_term)
        from apps.stores.admin import is_free_size_lookup

        if is_free_size_lookup(request):
            # ADR 0003: the pricing page's "Free carton size" offers active variants only (the
            # form validates the same list).
            queryset = queryset.filter(is_active=True, product__is_active=True)
        return queryset, may_have_duplicates

    @display(description="Discount")
    def discount(self, obj) -> str:
        if not obj.mrp or obj.selling_price >= obj.mrp:
            return "-"
        return f"{int((obj.mrp - obj.selling_price) * 100 / obj.mrp)}%"


# --------------------------------------------------------------------------- collections, banners


class CollectionItemInline(TabularInline):
    model = CollectionItem
    formset = CollectionItemFormSet
    extra = 0
    max_num = MAX_COLLECTION_ITEMS
    fields = ("variant", "sort_order")
    autocomplete_fields = ("variant",)
    ordering = ("sort_order", "id")
    verbose_name_plural = f"Items (ordered, at most {MAX_COLLECTION_ITEMS})"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("variant", "variant__product")


def store_summary(obj) -> str:
    codes = [store.code for store in obj.stores.all()]
    return ", ".join(codes) if codes else "All stores"


@admin.register(Collection)
class CollectionAdmin(ModelAdmin):
    inlines = [CollectionItemInline]
    list_display = (
        "name",
        "slug",
        "item_count",
        "stores_shown",
        "show_on_home",
        "sort_order",
        "is_active",
    )
    list_editable = ("sort_order", "is_active")
    list_filter = ("is_active", "show_on_home")
    search_fields = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    filter_horizontal = ("stores",)
    fields = ("name", "slug", "show_on_home", "stores", "sort_order", "is_active")

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(items_total=Count("items", distinct=True))
            .prefetch_related("stores")
        )

    @display(description="Items", ordering="items_total")
    def item_count(self, obj) -> int:
        return obj.items_total

    @display(description="Stores")
    def stores_shown(self, obj) -> str:
        return store_summary(obj)


BANNER_STATES = {"Live": "success", "Scheduled": "info", "Ended": "warning", "Off": "danger"}


@admin.register(Banner)
class BannerAdmin(ModelAdmin):
    list_display = (
        "title",
        "image_preview",
        "link",
        "audience",
        "stores_shown",
        "starts_at",
        "ends_at",
        "state",
        "sort_order",
        "is_active",
    )
    list_display_links = ("title",)
    list_editable = ("sort_order", "is_active")
    list_filter = ("is_active", "link_type", "audience")
    search_fields = ("title", "link_value")
    filter_horizontal = ("stores",)
    readonly_fields = ("image_preview",)
    fieldsets = (
        (None, {"fields": ("title", "image", "image_preview")}),
        (
            "Link",
            {
                "fields": ("link_type", "link_value"),
                "description": (
                    "Category, collection or product: the target's slug. URL: an https:// "
                    "address. Refer a friend: opens Refer & earn (leave the value empty). "
                    "None: not tappable."
                ),
            },
        ),
        ("Where and when", {"fields": ("audience", "stores", ("starts_at", "ends_at"))}),
        (None, {"fields": (("sort_order", "is_active"),)}),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("stores")

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        field = super().formfield_for_dbfield(db_field, request, **kwargs)
        if db_field.name in ("starts_at", "ends_at") and field is not None:
            # The staff time-zone middleware shows and takes admin times in IST; say which.
            zone = timezone.get_current_timezone_name()
            empty = "starts immediately" if db_field.name == "starts_at" else "never ends"
            field.help_text = f"Time zone: {zone}. Empty: {empty}."
        return field

    @display(description="Image")
    def image_preview(self, obj) -> str:
        return thumbnail(obj.image, 64)

    @display(description="Opens")
    def link(self, obj) -> str:
        if obj.link_type == "none":
            return "-"
        return f"{obj.link_type}: {obj.link_value}"

    @display(description="Stores")
    def stores_shown(self, obj) -> str:
        return store_summary(obj)

    @display(description="Now", label=BANNER_STATES)
    def state(self, obj) -> str:
        now = timezone.now()
        if not obj.is_active:
            return "Off"
        if obj.starts_at and obj.starts_at > now:
            return "Scheduled"
        if obj.ends_at and obj.ends_at <= now:
            return "Ended"
        return "Live"


@admin.register(TrendingSearch)
class TrendingSearchAdmin(ModelAdmin):
    """Search terms suggested for an empty search box (03 §2.7)."""

    list_display = ("term", "sort_order", "is_active")
    list_editable = ("sort_order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("term",)
    ordering = ("sort_order", "term")
