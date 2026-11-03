"""Catalog admin (05 §2 "Categories", "Products & variants", "Collections", "Banners"; 05 §3
"Catalog, collections, banners": Super Admin and Catalog Manager edit, Ops / Store Manager /
Store Staff / Support view).

The catalog is central (no store scoping). Prices are master data: variant MRP and selling price
are edited here by catalog roles and kept in the variant's price history; store price overrides
live in the inventory admin.
"""

from django.contrib import admin
from django.db.models import Case, Count, IntegerField, Max, Min, Q, Value, When
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.utils.html import format_html, format_html_join
from import_export.admin import ImportExportModelAdmin
from import_export.formats.base_formats import CSV
from unfold.admin import ModelAdmin, StackedInline, TabularInline
from unfold.contrib.import_export.forms import ExportForm, ImportForm
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
)
from apps.catalog.validators import LABEL_TEXT_KEYS
from apps.ops_console.admin_support import ImportExportPermissionsMixin, ReadOnlyHistoryAdmin


class CatalogImportExportAdmin(ImportExportPermissionsMixin, ModelAdmin, ImportExportModelAdmin):
    """CSV import/export with unfold's forms. Import needs add + change on the model (catalog
    roles), export needs view. Excel needs `tablib[xlsx]` (not installed; reported)."""

    import_form_class = ImportForm
    export_form_class = ExportForm
    import_formats = [CSV]
    export_formats = [CSV]


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
                    ("mrp", "selling_price", "max_qty_per_order"),
                    ("unit_value", "unit", "weight_grams"),
                    ("barcode", "sap_item_code"),
                    ("is_active", "sort_order"),
                )
            },
        ),
    )


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


@admin.register(ProductVariant)
class ProductVariantAdmin(ReadOnlyHistoryAdmin, CatalogImportExportAdmin):
    """Every SKU. Price changes are kept in the variant's history (History button)."""

    resource_classes = [ProductVariantResource]
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
        ("Price", {"fields": (("mrp", "selling_price"), "max_qty_per_order")}),
        ("Unit price display", {"fields": (("unit_value", "unit"),)}),
        ("Codes", {"fields": (("barcode", "sap_item_code"), "weight_grams")}),
        (None, {"fields": (("is_active", "sort_order"),)}),
    )

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
        "stores_shown",
        "starts_at",
        "ends_at",
        "state",
        "sort_order",
        "is_active",
    )
    list_display_links = ("title",)
    list_editable = ("sort_order", "is_active")
    list_filter = ("is_active", "link_type")
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
                    "address. None: not tappable."
                ),
            },
        ),
        ("Where and when", {"fields": ("stores", ("starts_at", "ends_at"))}),
        (None, {"fields": (("sort_order", "is_active"),)}),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("stores")

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        field = super().formfield_for_dbfield(db_field, request, **kwargs)
        if db_field.name in ("starts_at", "ends_at") and field is not None:
            # Until the staff IST middleware lands the admin works in UTC; say which.
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
