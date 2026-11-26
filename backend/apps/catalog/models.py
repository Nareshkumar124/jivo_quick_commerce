"""Catalog (07 §2.3): categories (two levels), products with label information, variants (SKUs),
images, collections, banners and trending searches.

The catalog is central; prices and stock per store live in `inventory.StoreInventory`. Images are
public media (`apps.core.storage.public_storage`), processed on save (`apps.catalog.images`).
"""

import re
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models
from simple_history.models import HistoricalRecords

from apps.catalog.choices import BannerAudience, BannerLinkType
from apps.catalog.images import RandomImagePath, is_new_upload, prepare_image, validate_image_upload
from apps.catalog.validators import (
    validate_highlights,
    validate_label_attributes,
    validate_not_all_digits,
)
from apps.core.models import TimeStampedModel
from apps.core.storage import public_storage

MAX_COLLECTION_ITEMS = 100


class ProcessedImageMixin(models.Model):
    """Processes a newly assigned `image` on save (validation, EXIF strip, renditions)."""

    IMAGE_SQUARE = True

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if is_new_upload(self.image):
            prepare_image(self.image, square=self.IMAGE_SQUARE)
        super().save(*args, **kwargs)


class Category(ProcessedImageMixin, TimeStampedModel):
    """Two levels in v1: top-level categories and their sub-categories."""

    name = models.CharField(max_length=80)
    slug = models.SlugField(max_length=80, unique=True, validators=[validate_not_all_digits])
    parent = models.ForeignKey(
        "self", on_delete=models.PROTECT, null=True, blank=True, related_name="children"
    )
    image = models.ImageField(
        upload_to=RandomImagePath("categories"),
        storage=public_storage,
        blank=True,
        validators=[validate_image_upload],
    )
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ["sort_order", "name"]
        constraints = [
            models.CheckConstraint(
                condition=~models.Q(parent=models.F("id")), name="category_not_own_parent"
            ),
        ]

    def __str__(self) -> str:
        return self.name

    def clean(self) -> None:
        super().clean()
        if self.parent_id is None:
            return
        if self.parent_id == self.pk:
            raise ValidationError({"parent": "A category cannot be its own parent."})
        if self.parent.parent_id is not None:
            raise ValidationError({"parent": "Choose a top-level category (two levels only)."})
        if self.pk and Category.objects.filter(parent_id=self.pk).exists():
            raise ValidationError(
                {"parent": "This category has sub-categories, so it must stay top-level."}
            )


class Product(TimeStampedModel):
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=160, unique=True, validators=[validate_not_all_digits])
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="products")
    brand = models.CharField(max_length=60, default="Jivo")
    short_description = models.CharField(max_length=300, blank=True)
    description = models.TextField(
        blank=True, help_text="Plain text; separate paragraphs with a blank line."
    )
    highlights = models.JSONField(default=list, blank=True, validators=[validate_highlights])
    attributes = models.JSONField(
        default=dict,
        blank=True,
        validators=[validate_label_attributes],
        help_text="Label information (09 §4): see apps.catalog.validators.LABEL_KEYS.",
    )
    is_veg = models.BooleanField(default=True, help_text="FSSAI veg mark.")
    hsn_code = models.CharField(
        max_length=8, blank=True, validators=[RegexValidator(r"^[0-9]{4,8}$", "4-8 digits.")]
    )
    gst_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("28"))],
        help_text="GST percent, e.g. 5.00 (D-12).",
    )
    search_keywords = models.CharField(
        max_length=500, blank=True, help_text="Comma-separated search tags."
    )
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "name"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(gst_rate__gte=0, gst_rate__lte=28), name="product_gst_range"
            ),
        ]
        indexes = [models.Index(fields=["category", "is_active"], name="product_category_idx")]

    def __str__(self) -> str:
        return self.name

    def label(self, key: str) -> str:
        return (self.attributes or {}).get(key) or ""


class VariantUnit(models.TextChoices):
    ML = "ml", "ml"
    L = "l", "L"
    G = "g", "g"
    KG = "kg", "kg"
    PIECE = "pc", "piece"


class ProductVariant(TimeStampedModel):
    """A sellable SKU. Price history is kept (07 §2.10)."""

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="variants")
    sku = models.CharField(max_length=40, unique=True)
    name = models.CharField(max_length=40, help_text='Chip label, e.g. "1 L".')
    net_quantity = models.CharField(
        max_length=40, help_text='As on the pack (Legal Metrology), e.g. "1 L" or "2 x 1 L".'
    )
    unit_value = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
        help_text="Total quantity in `unit` for the unit price, e.g. 1000 with ml.",
    )
    unit = models.CharField(max_length=2, choices=VariantUnit.choices, blank=True)
    mrp = models.DecimalField(max_digits=12, decimal_places=2)
    selling_price = models.DecimalField(max_digits=12, decimal_places=2)
    max_qty_per_order = models.PositiveSmallIntegerField(default=5)
    # `db_default` too: the database fills 1 for code that does not know the column yet (the old
    # release during a deploy, or after a code rollback). `default` keeps 1 on new Python objects.
    min_qty_per_order = models.PositiveSmallIntegerField(
        default=1,
        db_default=1,
        help_text=(
            "Fewest units a customer can order in one order (e.g. 5 cartons). At most the "
            "maximum per order. The item counts as out of stock when fewer can be sold."
        ),
    )
    barcode = models.CharField(max_length=32, blank=True)
    sap_item_code = models.CharField(max_length=40, null=True, blank=True, unique=True)
    weight_grams = models.PositiveIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)
    history = HistoricalRecords()

    class Meta:
        ordering = ["sort_order", "id"]
        # ADR 0004 §2: the "Bottle prices" page (catalog.services.set_variant_price). Super Admin.
        permissions = [("manage_prices", "Can change bottle prices (Store management)")]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(selling_price__gt=0, selling_price__lte=models.F("mrp")),
                name="variant_price_within_mrp",
            ),
            models.CheckConstraint(
                condition=models.Q(max_qty_per_order__gte=1), name="variant_max_qty_positive"
            ),
            models.CheckConstraint(
                condition=models.Q(min_qty_per_order__gte=1), name="variant_min_qty_positive"
            ),
            models.CheckConstraint(
                condition=models.Q(min_qty_per_order__lte=models.F("max_qty_per_order")),
                name="variant_min_qty_within_max",
            ),
            models.CheckConstraint(
                condition=(
                    models.Q(unit_value__isnull=True, unit="")
                    | models.Q(unit_value__gt=0, unit__in=VariantUnit.values)
                ),
                name="variant_unit_pair",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.product.name} {self.name}"

    def clean(self) -> None:
        super().clean()
        if self.mrp is not None and self.selling_price is not None:
            if self.selling_price <= 0:
                raise ValidationError({"selling_price": "Must be above 0."})
            if self.selling_price > self.mrp:
                raise ValidationError({"selling_price": "Cannot be above the MRP."})
        if self.pk is not None and self.mrp is not None:
            # A store price override must stay at most the MRP (review #3): lower the overrides
            # first. (The catalog also ignores an override above the MRP, as a backstop.)
            above = (
                self.inventory.filter(price_override__gt=self.mrp)
                .select_related("store")
                .order_by("store__code")
            )
            codes = [row.store.code for row in above[:5]]
            if codes:
                raise ValidationError(
                    {
                        "mrp": (
                            "Stores sell this item above the new MRP with a price override "
                            f"({', '.join(codes)}). Lower or remove those overrides first."
                        )
                    }
                )
            tiers_above = list(
                self.price_tiers.filter(price__gt=self.mrp).values_list(
                    "min_order_units", flat=True
                )
            )
            if tiers_above:
                raise ValidationError(
                    {
                        "mrp": (
                            "Price tiers from "
                            f"{', '.join(str(units) for units in tiers_above)} units are above the "
                            "new MRP. Lower those tier prices first."
                        )
                    }
                )
        if (self.unit_value is None) != (not self.unit):
            raise ValidationError({"unit": "Set both the unit value and the unit, or neither."})
        if (
            self.min_qty_per_order is not None
            and self.max_qty_per_order is not None
            and self.min_qty_per_order > self.max_qty_per_order
        ):
            raise ValidationError(
                {"min_qty_per_order": "Cannot be above the maximum quantity per order."}
            )


class VariantPriceTier(TimeStampedModel):
    """A volume (slab) price (ADR 0001, 08 §6.2): when one order has at least `min_order_units`
    qualifying units (every unit of every variant that has tiers, any mix), each unit of this
    variant costs `price`. The highest tier reached applies; below the lowest tier, the normal
    price does. A variant without tiers is priced as before."""

    variant = models.ForeignKey(
        ProductVariant, on_delete=models.CASCADE, related_name="price_tiers"
    )
    min_order_units = models.PositiveSmallIntegerField(
        help_text="From this many qualifying units in the order (all tiered items together)."
    )
    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        help_text="Price per unit (GST inclusive) at this tier. Above 0 and at most the MRP.",
    )
    history = HistoricalRecords()

    class Meta:
        ordering = ["variant", "min_order_units"]
        constraints = [
            models.UniqueConstraint(
                fields=["variant", "min_order_units"], name="variantpricetier_unique_units"
            ),
            models.CheckConstraint(
                condition=models.Q(min_order_units__gte=1), name="variantpricetier_units_positive"
            ),
            models.CheckConstraint(
                condition=models.Q(price__gt=0), name="variantpricetier_price_positive"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.variant_id}: from {self.min_order_units} units at {self.price}"

    def clean(self) -> None:
        super().clean()
        if self.price is not None and self.variant_id is not None and self.price > self.variant.mrp:
            raise ValidationError({"price": "Cannot be above the MRP."})


class ProductImage(ProcessedImageMixin, TimeStampedModel):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="images")
    variant = models.ForeignKey(
        ProductVariant,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="images",
        help_text="Set for an image of one variant only (e.g. the 5 L jar).",
    )
    image = models.ImageField(
        upload_to=RandomImagePath("products"),
        storage=public_storage,
        validators=[validate_image_upload],
    )
    alt_text = models.CharField(max_length=150, blank=True)
    sort_order = models.IntegerField(default=0)
    source_sha256 = models.CharField(
        max_length=64,
        blank=True,
        default="",
        editable=False,
        help_text="SHA-256 of the source file, set by `import_catalog_images` (idempotency key).",
    )

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            # One loaded file per product (or variant), even when two loader runs overlap.
            # Admin uploads leave source_sha256 empty and are not limited. NULL variants count
            # as equal (NULLS NOT DISTINCT, PostgreSQL 15+), so product-level images are covered.
            models.UniqueConstraint(
                fields=["product", "variant", "source_sha256"],
                condition=~models.Q(source_sha256=""),
                nulls_distinct=False,
                name="productimage_source_unique",
            ),
        ]

    def __str__(self) -> str:
        return f"Image {self.pk} of {self.product_id}"

    def clean(self) -> None:
        super().clean()
        if self.variant_id and self.variant.product_id != self.product_id:
            raise ValidationError({"variant": "The variant must belong to this product."})


class Collection(TimeStampedModel):
    name = models.CharField(max_length=80)
    slug = models.SlugField(max_length=80, unique=True, validators=[validate_not_all_digits])
    show_on_home = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    stores = models.ManyToManyField(
        "stores.DarkStore",
        blank=True,
        related_name="collections",
        help_text="Empty = all stores.",
    )

    class Meta:
        ordering = ["sort_order", "name"]

    def __str__(self) -> str:
        return self.name


class CollectionItem(TimeStampedModel):
    """At most MAX_COLLECTION_ITEMS per collection (checked in clean() and the service)."""

    collection = models.ForeignKey(Collection, on_delete=models.CASCADE, related_name="items")
    variant = models.ForeignKey(
        ProductVariant, on_delete=models.CASCADE, related_name="collection_items"
    )
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            models.UniqueConstraint(fields=["collection", "variant"], name="collectionitem_unique"),
        ]

    def __str__(self) -> str:
        return f"{self.collection_id}: {self.variant_id}"

    def clean(self) -> None:
        super().clean()
        if self.collection_id is None:
            return
        others = CollectionItem.objects.filter(collection_id=self.collection_id)
        if self.pk:
            others = others.exclude(pk=self.pk)
        if others.count() >= MAX_COLLECTION_ITEMS:
            raise ValidationError(f"A collection holds at most {MAX_COLLECTION_ITEMS} items.")


class Banner(ProcessedImageMixin, TimeStampedModel):
    IMAGE_SQUARE = False

    title = models.CharField(max_length=120)
    image = models.ImageField(
        upload_to=RandomImagePath("banners"),
        storage=public_storage,
        validators=[validate_image_upload],
        help_text="Wide image, about 2.25:1 (e.g. 1080 x 480).",
    )
    link_type = models.CharField(
        max_length=12, choices=BannerLinkType.choices, default=BannerLinkType.NONE
    )
    link_value = models.CharField(
        max_length=300,
        blank=True,
        help_text="Slug for category/collection/product, https URL for url, empty for none.",
    )
    audience = models.CharField(
        max_length=20,
        choices=BannerAudience.choices,
        default=BannerAudience.ALL,
        help_text="Who sees it. New = no order placed yet (signed-out visitors count as new).",
    )
    stores = models.ManyToManyField(
        "stores.DarkStore", blank=True, related_name="banners", help_text="Empty = all stores."
    )
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(starts_at__isnull=True)
                    | models.Q(ends_at__isnull=True)
                    | models.Q(ends_at__gt=models.F("starts_at"))
                ),
                name="banner_ends_after_starts",
            ),
        ]

    def __str__(self) -> str:
        return self.title

    def clean(self) -> None:
        super().clean()
        value = self.link_value.strip()
        if self.link_type in (BannerLinkType.NONE, BannerLinkType.REFERRAL):
            if value:
                raise ValidationError({"link_value": "Leave empty when the banner has no target."})
        elif self.link_type == BannerLinkType.URL:
            if not value.startswith("https://"):
                raise ValidationError({"link_value": "Enter an https:// URL."})
        elif not re.fullmatch(r"[-a-zA-Z0-9_]+", value):
            raise ValidationError({"link_value": "Enter the target's slug."})


class TrendingSearch(TimeStampedModel):
    """Admin-defined trending searches (03 §2.7), returned by `search/suggest` for a blank `q`."""

    term = models.CharField(max_length=60, unique=True)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["sort_order", "term"]

    def __str__(self) -> str:
        return self.term
