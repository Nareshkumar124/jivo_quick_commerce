"""Bulk import/export of the catalog (05 §2 "Products & variants", D-17), django-import-export.

The column format is a contract with the `catalog-data` agent and Jivo's SAP exports: it is
documented column by column in docs/admin-panel-architecture.md §10. Change both together.

- One CSV per resource, imported in this order: categories, products, variants.
- Rows are matched by their natural key (category/product `slug`, variant `sku`): an existing key
  updates the row, a new key creates it. Rows are never deleted by an import.
- Every row runs the model validation (`clean_model_instances`): two-level categories, selling
  price within the MRP, the unit pair, label attributes, slugs. Rows are saved one by one (no bulk
  mode) so the catalog cache invalidation signals and the variant price history run.
- Images are not imported here (uploaded in the admin).
"""

import json

from django.core.exceptions import ValidationError
from import_export import fields, resources, widgets

from apps.catalog.models import Category, Product, ProductVariant
from apps.catalog.validators import LABEL_TEXT_KEYS

HIGHLIGHT_SEPARATOR = "|"


class StrictBooleanWidget(widgets.BooleanWidget):
    """1/0 or true/false (any case). Empty keeps the current value (new rows: the default).
    Anything else is an error, instead of import-export's silent False."""

    def clean(self, value, row=None, **kwargs):
        text = "" if value is None else str(value).strip().lower()
        if text in ("1", "true"):
            return True
        if text in ("0", "false"):
            return False
        if text == "":
            return None
        raise ValueError("Use 1 (yes) or 0 (no).")


class SlugForeignKeyWidget(widgets.ForeignKeyWidget):
    """A foreign key given by the target's slug, with a readable error for unknown slugs."""

    def __init__(self, model, label: str):
        super().__init__(model, field="slug")
        self.label = label

    def clean(self, value, row=None, **kwargs):
        if value is None or str(value).strip() == "":
            return None
        try:
            return self.model.objects.get(slug=str(value).strip())
        except self.model.DoesNotExist:
            raise ValueError(f"No {self.label} with slug {str(value).strip()!r}.") from None


class NullableCharWidget(widgets.CharWidget):
    """Empty cell -> NULL, for unique nullable codes (`sap_item_code`): two variants without a
    code must not collide on an empty string."""

    def clean(self, value, row=None, **kwargs):
        text = "" if value is None else str(value).strip()
        return text or None


class PipeListWidget(widgets.Widget):
    """A list of short texts in one cell: `Cold pressed | Rich in MUFA`."""

    def clean(self, value, row=None, **kwargs):
        text = "" if value is None else str(value)
        return [part.strip() for part in text.split(HIGHLIGHT_SEPARATOR) if part.strip()]

    def render(self, value, obj=None, **kwargs):
        return f" {HIGHLIGHT_SEPARATOR} ".join(value or [])


def _boolean(attribute: str) -> fields.Field:
    return fields.Field(
        attribute=attribute,
        column_name=attribute,
        widget=StrictBooleanWidget(),
        saves_null_values=False,
    )


class CatalogResourceOptions:
    """Shared Meta options."""

    clean_model_instances = True
    skip_unchanged = True
    report_skipped = True
    use_transactions = True
    use_bulk = False


# --------------------------------------------------------------------------- categories

# Column headers (the file format) and the resource field names behind them, in file order.
CATEGORY_COLUMNS = ("slug", "name", "parent_slug", "sort_order", "is_active")
CATEGORY_FIELDS = ("slug", "name", "parent", "sort_order", "is_active")


class CategoryResource(resources.ModelResource):
    parent = fields.Field(
        attribute="parent",
        column_name="parent_slug",
        widget=SlugForeignKeyWidget(Category, "category"),
    )
    is_active = _boolean("is_active")

    class Meta(CatalogResourceOptions):
        model = Category
        import_id_fields = ("slug",)
        fields = CATEGORY_FIELDS
        export_order = CATEGORY_FIELDS
        import_order = CATEGORY_FIELDS


# --------------------------------------------------------------------------- products


def _label(key: str) -> fields.Field:
    # Export reads attributes[key]; import is done in ProductResource.import_instance (one JSON
    # field, several columns).
    return fields.Field(attribute=f"attributes__{key}", column_name=key, readonly=True)


PRODUCT_COLUMNS = (
    "slug",
    "name",
    "category_slug",
    "brand",
    "short_description",
    "description",
    "highlights",
    "is_veg",
    "hsn_code",
    "gst_rate",
    "search_keywords",
    "is_active",
    "sort_order",
    *LABEL_TEXT_KEYS,
    "nutrition",
)
PRODUCT_FIELDS = tuple("category" if name == "category_slug" else name for name in PRODUCT_COLUMNS)


class ProductResource(resources.ModelResource):
    category = fields.Field(
        attribute="category",
        column_name="category_slug",
        widget=SlugForeignKeyWidget(Category, "category"),
    )
    highlights = fields.Field(
        attribute="highlights", column_name="highlights", widget=PipeListWidget()
    )
    is_veg = _boolean("is_veg")
    is_active = _boolean("is_active")
    ingredients = _label("ingredients")
    shelf_life = _label("shelf_life")
    storage_instructions = _label("storage_instructions")
    country_of_origin = _label("country_of_origin")
    manufacturer = _label("manufacturer")
    marketer = _label("marketer")
    importer = _label("importer")
    consumer_care = _label("consumer_care")
    fssai_license_no = _label("fssai_license_no")
    nutrition = fields.Field(
        attribute="attributes__nutrition",
        column_name="nutrition",
        readonly=True,
        widget=widgets.JSONWidget(),
    )

    class Meta(CatalogResourceOptions):
        model = Product
        import_id_fields = ("slug",)
        fields = PRODUCT_FIELDS
        export_order = PRODUCT_FIELDS
        import_order = PRODUCT_FIELDS

    def import_instance(self, instance, row, **kwargs):
        errors: dict = {}
        try:
            super().import_instance(instance, row, **kwargs)
        except ValidationError as error:
            errors = error.update_error_dict(errors)
        try:
            instance.attributes = label_attributes(instance.attributes, row)
        except ValueError as error:
            errors.setdefault("attributes", []).append(str(error))
        if errors:
            raise ValidationError(errors)


def label_attributes(current: dict | None, row) -> dict:
    """`Product.attributes` from the label columns present in `row`. An empty cell clears the
    key; a column missing from the file keeps the current value. `nutrition` is JSON text."""
    attributes = dict(current or {})
    for key in LABEL_TEXT_KEYS:
        if key not in row:
            continue
        text = "" if row[key] is None else str(row[key]).strip()
        if text:
            attributes[key] = text
        else:
            attributes.pop(key, None)
    if "nutrition" in row:
        text = "" if row["nutrition"] is None else str(row["nutrition"]).strip()
        if not text:
            attributes.pop("nutrition", None)
        else:
            try:
                attributes["nutrition"] = json.loads(text)
            except json.JSONDecodeError:
                raise ValueError("nutrition is not valid JSON.") from None
    return attributes


# --------------------------------------------------------------------------- variants

VARIANT_COLUMNS = (
    "sku",
    "product_slug",
    "name",
    "net_quantity",
    "unit_value",
    "unit",
    "mrp",
    "selling_price",
    "max_qty_per_order",
    "barcode",
    "sap_item_code",
    "weight_grams",
    "is_active",
    "sort_order",
)
VARIANT_FIELDS = tuple("product" if name == "product_slug" else name for name in VARIANT_COLUMNS)


class ProductVariantResource(resources.ModelResource):
    product = fields.Field(
        attribute="product",
        column_name="product_slug",
        widget=SlugForeignKeyWidget(Product, "product"),
    )
    sap_item_code = fields.Field(
        attribute="sap_item_code", column_name="sap_item_code", widget=NullableCharWidget()
    )
    is_active = _boolean("is_active")

    class Meta(CatalogResourceOptions):
        model = ProductVariant
        import_id_fields = ("sku",)
        fields = VARIANT_FIELDS
        export_order = VARIANT_FIELDS
        import_order = VARIANT_FIELDS
