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

from apps.catalog.choices import BannerLinkType
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
    barcode = models.CharField(max_length=32, blank=True)
    sap_item_code = models.CharField(max_length=40, null=True, blank=True, unique=True)
    weight_grams = models.PositiveIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)
    history = HistoricalRecords()

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(selling_price__gt=0, selling_price__lte=models.F("mrp")),
                name="variant_price_within_mrp",
            ),
            models.CheckConstraint(
                condition=models.Q(max_qty_per_order__gte=1), name="variant_max_qty_positive"
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
        if (self.unit_value is None) != (not self.unit):
            raise ValidationError({"unit": "Set both the unit value and the unit, or neither."})


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

    class Meta:
        ordering = ["sort_order", "id"]

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
        if self.link_type == BannerLinkType.NONE:
            if value:
                raise ValidationError({"link_value": "Leave empty when the banner has no link."})
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
