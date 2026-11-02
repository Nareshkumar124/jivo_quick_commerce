"""Phase 2 API contract: home, categories, products, search, collections (06 §2.4).

Explicit (non-model) serializers: the shapes are the contract, independent of how the catalog and
per-store inventory are stored (Phase 2 R2). Everything is per store (`X-Store-Id`): prices
include the store's price override, and stock is the store's.

Component names avoid Flutter class names (`Image`, `Banner`, `Category`, `Card`), because the
generated Dart models are imported into widget code.
"""

from rest_framework import serializers

from apps.catalog.choices import BannerLinkType, ProductSort, StockStatus, SuggestionType
from apps.stores.serializers import StoreStatusSerializer

MAX_QUERY_LENGTH = 100


def money(help_text: str) -> serializers.DecimalField:
    """Money: a 2-decimal string such as "249.00" (02 §5). Never a float."""
    return serializers.DecimalField(max_digits=12, decimal_places=2, help_text=help_text)


# --------------------------------------------------------------------------- shared pieces


class ImageSetSerializer(serializers.Serializer):
    """One picture in three widths (made at upload, 09 §1). Product and category images are
    square on a white background; banner images are wide (about 2.25:1)."""

    thumbnail = serializers.URLField(help_text="About 256 px wide: cart lines, suggestions.")
    medium = serializers.URLField(help_text="About 512 px wide: product tiles, category grid.")
    large = serializers.URLField(help_text="About 1024 px wide: detail gallery and zoom, banners.")
    alt_text = serializers.CharField(
        allow_blank=True, help_text="Accessibility label (may be empty)."
    )


class UnitPriceSerializer(serializers.Serializer):
    """Unit sale price for comparison (Legal Metrology), e.g. ₹27.90 per 100 ml."""

    amount = money("Selling price per `per`.")
    per = serializers.CharField(help_text='The unit quantity, e.g. "100 ml", "100 g", "1 kg".')


class VariantSummarySerializer(serializers.Serializer):
    """A sellable variant (SKU) with its price and stock at the store."""

    id = serializers.IntegerField(help_text="Variant id: what the cart adds (Phase 3).")
    name = serializers.CharField(help_text='Variant label shown on tiles and chips, e.g. "1 L".')
    mrp = money("MRP (inclusive of all taxes). Show struck out when above `selling_price`.")
    selling_price = money("Price at this store (the store's price override when set).")
    discount_amount = money('`mrp` - `selling_price`, "0.00" when none ("You save ₹70").')
    discount_percent = serializers.IntegerField(
        min_value=0,
        max_value=99,
        help_text=(
            "Whole percent off MRP, rounded down (never overstated). Show the badge "
            "('20% OFF') only when above 0."
        ),
    )
    unit_price = UnitPriceSerializer(
        allow_null=True, help_text="Unit sale price; null when not applicable."
    )
    stock_status = serializers.ChoiceField(choices=StockStatus.choices)
    orderable_quantity = serializers.IntegerField(
        min_value=0,
        help_text=(
            "Units a customer can add right now: min(units in stock at this store, "
            "`max_qty_per_order`). 0 when out of stock. Cap the ADD stepper here."
        ),
    )
    units_left = serializers.IntegerField(
        allow_null=True,
        min_value=1,
        help_text=(
            "Set only when `stock_status` is LOW_STOCK: the units left, for 'Only 2 left'. "
            "Null otherwise (exact stock is not published)."
        ),
    )
    max_qty_per_order = serializers.IntegerField(
        min_value=1, help_text="Per-order limit for this variant (also enforced by the cart)."
    )
    image = ImageSetSerializer(
        allow_null=True,
        help_text="The variant's own first image, else the product's. Null when none.",
    )


class ProductCardSerializer(serializers.Serializer):
    """A product tile (03 §2.5): used by home rails, lists, search, collections, similar items."""

    id = serializers.IntegerField()
    slug = serializers.SlugField(help_text="For product links: `GET /products/{slug}/`.")
    name = serializers.CharField(help_text='e.g. "Jivo Cold Pressed Canola Oil".')
    brand = serializers.CharField(help_text='"Jivo" for every product in v1.')
    is_veg = serializers.BooleanField(help_text="FSSAI veg mark (green dot) when true.")
    image = ImageSetSerializer(
        allow_null=True,
        help_text="Image of the default variant (see `default_variant_id`). Null when none.",
    )
    default_variant_id = serializers.IntegerField(
        help_text=(
            "The variant the tile shows and ADD adds: the one this list is about (e.g. the "
            "collection item or past purchase), else the first in-stock variant, else the "
            "first. Always one of `variants`."
        )
    )
    variants = VariantSummarySerializer(
        many=True,
        help_text=(
            "Every active variant this store sells, in display order (the chips on the detail "
            "page), including out-of-stock ones. With more than one, ADD opens a variant "
            "picker. Never empty."
        ),
    )


class CategoryTileSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(help_text='e.g. "Edible Oils".')
    slug = serializers.SlugField(help_text="Use as `category` on `GET /products/`.")
    image = ImageSetSerializer(allow_null=True, help_text="Square image. Null when none.")


class PaginatedProductCardListSerializer(serializers.Serializer):
    """Standard page (02 §5): `?page=&page_size=`, default 20, max 100."""

    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = ProductCardSerializer(many=True)


# --------------------------------------------------------------------------- home


class HomeBannerSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    title = serializers.CharField(help_text="Accessibility label / analytics name.")
    image = ImageSetSerializer(help_text="Wide banner image (about 2.25:1).")
    link_type = serializers.ChoiceField(choices=BannerLinkType.choices)
    link_value = serializers.CharField(
        allow_blank=True,
        help_text=(
            "category/collection/product: the target's slug. url: an absolute https URL. "
            'none: "". Ignore a banner whose target no longer opens (404).'
        ),
    )


class CollectionRailSerializer(serializers.Serializer):
    """A horizontal product rail on home ('Bestsellers', 'Offers', ...)."""

    id = serializers.IntegerField()
    name = serializers.CharField()
    slug = serializers.SlugField(help_text="'See all' opens `GET /collections/{slug}/`.")
    products = ProductCardSerializer(
        many=True, help_text="Up to 10 products in the collection's order, out-of-stock last."
    )
    has_more = serializers.BooleanField(help_text="True when the collection has more products.")


class HomeFeedSerializer(serializers.Serializer):
    store = StoreStatusSerializer(
        help_text="Current status of the store in `X-Store-Id` (store-closed banner)."
    )
    banners = HomeBannerSerializer(
        many=True,
        help_text="Active banners for this store, in admin order (auto-scrolling carousel).",
    )
    categories = CategoryTileSerializer(
        many=True,
        help_text="Top-level categories with products at this store, in admin order.",
    )
    collections = CollectionRailSerializer(
        many=True,
        help_text="Collections shown on home for this store, in admin order. Empty rails omitted.",
    )
    buy_again = ProductCardSerializer(
        many=True,
        help_text=(
            "'Previously bought': up to 10 variants from the user's delivered orders that this "
            "store sells, most recent first (`default_variant_id` is the bought variant). Empty "
            "when anonymous or without history (hide the rail)."
        ),
    )


# --------------------------------------------------------------------------- categories


class CategoryNodeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    slug = serializers.SlugField()
    image = ImageSetSerializer(allow_null=True)
    children = CategoryTileSerializer(
        many=True,
        help_text=(
            "Sub-categories with products at this store (the left rail of the product list). "
            "Empty when the category has none: list it directly."
        ),
    )


class CategoryTreeSerializer(serializers.Serializer):
    results = CategoryNodeSerializer(
        many=True,
        help_text=(
            "Top-level categories with products at this store, in admin order. Two levels in "
            "v1 (top-level and sub-categories). Not paginated."
        ),
    )


# --------------------------------------------------------------------------- products


class ProductListQuerySerializer(serializers.Serializer):
    category = serializers.CharField(
        required=False,
        max_length=120,
        help_text=(
            "Category id or slug. A top-level category includes its sub-categories. Unknown or "
            "inactive: 404 `NOT_FOUND`."
        ),
    )
    collection = serializers.CharField(
        required=False,
        max_length=120,
        help_text="Collection id or slug. Unknown or inactive: 404 `NOT_FOUND`.",
    )
    sort = serializers.ChoiceField(
        choices=ProductSort.choices,
        default=ProductSort.RELEVANCE,
        help_text=(
            "relevance (default): admin order (collection order with `collection`). Prices "
            "use each product's default variant. In-stock products always come first."
        ),
    )


class VariantDetailSerializer(VariantSummarySerializer):
    sku = serializers.CharField(help_text="Stock keeping unit (support, analytics).")
    net_quantity = serializers.CharField(
        help_text='Net quantity as on the pack (Legal Metrology), e.g. "1 L" or "2 x 1 L".'
    )
    images = ImageSetSerializer(
        many=True,
        help_text=(
            "Gallery when this variant is selected: its own images first, then the product's "
            "shared images. May be empty (show a placeholder)."
        ),
    )


class NutritionRowSerializer(serializers.Serializer):
    name = serializers.CharField(help_text='Nutrient, e.g. "Energy (kcal)".')
    values = serializers.ListField(
        child=serializers.CharField(allow_blank=True),
        help_text='One value per column, as printed, e.g. ["900", "135"]. "" = not stated.',
    )
    is_sub_row = serializers.BooleanField(
        help_text='Indent under the previous row (e.g. "Saturated fat" under "Total fat").'
    )


class NutritionTableSerializer(serializers.Serializer):
    """The nutrition table as printed on the label (FSSAI)."""

    columns = serializers.ListField(
        child=serializers.CharField(),
        help_text='Column headings, e.g. ["Per 100 ml", "Per serving (15 ml)"].',
    )
    rows = NutritionRowSerializer(many=True)


class ProductDetailSerializer(serializers.Serializer):
    """Product detail (03 §2.6) with the mandatory label information (09 §4: FSSAI and Legal
    Metrology). Label text fields are "" when not applicable: hide the row."""

    id = serializers.IntegerField()
    slug = serializers.SlugField()
    name = serializers.CharField()
    brand = serializers.CharField()
    is_veg = serializers.BooleanField(help_text="FSSAI veg mark (green dot) when true.")
    category = CategoryTileSerializer(help_text="The product's category (breadcrumb, links).")
    short_description = serializers.CharField(allow_blank=True, help_text="One or two lines.")
    description = serializers.CharField(
        allow_blank=True,
        help_text="Plain text; paragraphs are separated by a blank line. No HTML or Markdown.",
    )
    highlights = serializers.ListField(
        child=serializers.CharField(), help_text="Key highlights (bullet points)."
    )
    default_variant_id = serializers.IntegerField(
        help_text="Variant selected when the page opens (the one tapped, else first in stock)."
    )
    variants = VariantDetailSerializer(
        many=True,
        help_text=(
            "Every active variant this store sells, in chip order (1 L / 2 L / 5 L), "
            "including out-of-stock ones. Never empty."
        ),
    )
    ingredients = serializers.CharField(allow_blank=True)
    nutrition = NutritionTableSerializer(
        allow_null=True, help_text="Null when the product has no nutrition table."
    )
    shelf_life = serializers.CharField(
        allow_blank=True, help_text='Best-before guidance, e.g. "9 months from manufacture".'
    )
    storage_instructions = serializers.CharField(allow_blank=True)
    country_of_origin = serializers.CharField(allow_blank=True)
    manufacturer = serializers.CharField(
        allow_blank=True, help_text="Name and address of the manufacturer or packer."
    )
    marketer = serializers.CharField(
        allow_blank=True, help_text="Name and address of the marketer, when different."
    )
    importer = serializers.CharField(
        allow_blank=True, help_text="Name and address of the importer, for imported products."
    )
    consumer_care = serializers.CharField(
        allow_blank=True, help_text="Consumer care details (phone, email, address)."
    )
    fssai_license_no = serializers.CharField(
        allow_blank=True, help_text="FSSAI licence number printed on the label (14 digits)."
    )
    similar_products = ProductCardSerializer(
        many=True,
        help_text="Up to 10 products from the same category at this store, in stock first.",
    )


# --------------------------------------------------------------------------- search


class SearchQuerySerializer(serializers.Serializer):
    q = serializers.CharField(
        max_length=MAX_QUERY_LENGTH,
        help_text="Search text (trimmed). Matches product name, variant, tags and category.",
    )
    sort = serializers.ChoiceField(
        choices=ProductSort.choices,
        default=ProductSort.RELEVANCE,
        help_text="relevance (default): best match first. In-stock products always come first.",
    )


class SuggestQuerySerializer(serializers.Serializer):
    q = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
        max_length=MAX_QUERY_LENGTH,
        help_text="Text typed so far (debounce 300 ms). Blank or missing: trending searches.",
    )


class SearchSuggestionSerializer(serializers.Serializer):
    type = serializers.ChoiceField(choices=SuggestionType.choices)
    text = serializers.CharField(help_text="What to show in the suggestion row.")
    query = serializers.CharField(
        help_text="The search term to run (and save in recent searches) when tapped."
    )
    id = serializers.IntegerField(
        allow_null=True, help_text="Product or category id; null for keywords."
    )
    slug = serializers.SlugField(
        allow_null=True, help_text="Product or category slug to open; null for keywords."
    )
    image = ImageSetSerializer(allow_null=True, help_text="Product or category image, if any.")


class SearchSuggestionsSerializer(serializers.Serializer):
    query = serializers.CharField(
        allow_blank=True, help_text="The `q` these are for (match it to the latest keystroke)."
    )
    suggestions = SearchSuggestionSerializer(
        many=True,
        help_text=(
            "Up to 10, best first. For a blank `q`: the trending searches (`keyword`), possibly "
            "empty."
        ),
    )


# --------------------------------------------------------------------------- collections


class CollectionDetailSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    slug = serializers.SlugField()
    products = ProductCardSerializer(
        many=True,
        help_text=(
            "All products of the collection that this store sells (at most 100), in the "
            "collection's order, out-of-stock last. For sorting or paging use "
            "`GET /products/?collection={slug}`."
        ),
    )
