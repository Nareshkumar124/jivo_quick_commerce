"""Enums of the Phase 2 catalog contract (published under the names in
SPECTACULAR_SETTINGS["ENUM_NAME_OVERRIDES"]). Values are a stable contract: add, never rename."""

from django.db import models


class ProductSort(models.TextChoices):
    """`sort` on product lists and search (03 §2.6). In-stock products always come first."""

    RELEVANCE = "relevance", "Relevance (default)"
    PRICE_ASC = "price_asc", "Price: low to high"
    PRICE_DESC = "price_desc", "Price: high to low"
    DISCOUNT = "discount", "Discount: highest first"


class StockStatus(models.TextChoices):
    """Availability of a variant at the store in `X-Store-Id`."""

    IN_STOCK = "IN_STOCK", "In stock"
    LOW_STOCK = "LOW_STOCK", "In stock, only a few left: show 'Only {units_left} left'"
    OUT_OF_STOCK = "OUT_OF_STOCK", "Out of stock: grey the tile out, no ADD button"


class BannerLinkType(models.TextChoices):
    """What a home banner opens (07 §2.3). `link_value` holds the target."""

    CATEGORY = "category", "Product list of the category whose slug is link_value"
    COLLECTION = "collection", "Collection page whose slug is link_value"
    PRODUCT = "product", "Product detail whose slug is link_value"
    URL = "url", "External https URL in link_value (open in the browser)"
    NONE = "none", "Not tappable"


class SuggestionType(models.TextChoices):
    """Kind of a search suggestion (03 §2.7)."""

    PRODUCT = "product", "A product: open its detail page (slug)"
    CATEGORY = "category", "A category: open its product list (slug)"
    KEYWORD = "keyword", "A search term (typed match or trending): run the search with `query`"
