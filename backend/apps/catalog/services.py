"""Catalog read services for one store (06 §2.4). Views stay thin; bodies are plain dicts in the
published contract shapes (cached per store, see `apps.catalog.cache`). `store` is anything with
`pk`: a `DarkStore`, or the cached `apps.stores.services.StoreArea` resolved from `X-Store-Id`.

Store scope: a product is listed only when the store sells at least one of its active variants
(a `StoreInventory` row exists); products, their category and its parent must be active.

Default variant (one definition, used by SQL sorting and by the tile):
1. the variant this context is about (collection item, past purchase), if the store sells it;
2. else the first in-stock variant in display order;
3. else the first variant in display order.
"In stock first" and the price/discount sorts all use the default variant.
"""

import re
from collections.abc import Iterable, Sequence
from decimal import ROUND_FLOOR, ROUND_HALF_UP, Decimal

from django.db.models import (
    Case,
    DecimalField,
    Exists,
    F,
    FilteredRelation,
    IntegerField,
    OuterRef,
    Prefetch,
    Q,
    QuerySet,
    Subquery,
    Value,
    When,
)
from django.utils import timezone
from rest_framework.exceptions import NotFound

from apps.catalog.choices import ProductSort, SuggestionType
from apps.catalog.images import image_set
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
    VariantUnit,
)
from apps.catalog.validators import LABEL_TEXT_KEYS
from apps.inventory.services import availability
from apps.stores.models import DarkStore

CENT = Decimal("0.01")
RAIL_SIZE = 10
SIMILAR_SIZE = 10
SUGGESTION_LIMIT = 10
MAX_SEARCH_TERMS = 5

# --------------------------------------------------------------------------- querysets


def effective_price_expression(override_ref: str):
    """SQL twin of `apps.inventory.services.effective_price` (keep them identical): the store
    override when it is set, above 0 and at most the variant's MRP, else the variant's
    `selling_price`. An override left above the MRP by a later MRP cut is ignored, never sold."""
    return Case(
        When(
            Q(**{f"{override_ref}__isnull": False})
            & Q(**{f"{override_ref}__gt": 0})
            & Q(**{f"{override_ref}__lte": F("mrp")}),
            then=F(override_ref),
        ),
        default=F("selling_price"),
        output_field=DecimalField(max_digits=12, decimal_places=2),
    )


def sold_variants(store: DarkStore) -> QuerySet[ProductVariant]:
    """Active variants sold at `store`, annotated with the store's stock and effective price."""
    return (
        ProductVariant.objects.filter(is_active=True)
        .annotate(
            store_inv=FilteredRelation("inventory", condition=Q(inventory__store_id=store.pk))
        )
        .filter(store_inv__isnull=False)
        .annotate(
            inv_on_hand=F("store_inv__on_hand"),
            inv_reserved=F("store_inv__reserved"),
            inv_is_available=F("store_inv__is_available"),
            inv_price=effective_price_expression("store_inv__price_override"),
            in_stock=Case(
                When(
                    Q(store_inv__is_available=True)
                    & Q(store_inv__on_hand__gt=F("store_inv__reserved")),
                    then=Value(1),
                ),
                default=Value(0),
                output_field=IntegerField(),
            ),
        )
        .order_by("sort_order", "id")
    )


def _visible_products() -> QuerySet[Product]:
    return Product.objects.filter(is_active=True, category__is_active=True).filter(
        Q(category__parent__isnull=True) | Q(category__parent__is_active=True)
    )


def sold_products(store: DarkStore) -> QuerySet[Product]:
    """Visible products with at least one variant sold at `store` (no sort annotations)."""
    return _visible_products().filter(Exists(sold_variants(store).filter(product=OuterRef("pk"))))


def store_products(store: DarkStore, preferred=None) -> QuerySet[Product]:
    """`sold_products()` annotated for sorting by the default variant: `default_in_stock`,
    `default_price`, `default_discount` (percent off MRP). `preferred` is an expression giving
    the context's variant id per product (annotated as `preferred_variant_id` first, so the
    default-variant subquery can refer to it)."""
    products = sold_products(store)
    default = sold_variants(store).filter(product=OuterRef("pk"))
    if preferred is not None:
        products = products.annotate(preferred_variant_id=preferred)
        default = default.annotate(
            preferred=Case(
                When(id=OuterRef("preferred_variant_id"), then=Value(0)),
                default=Value(1),
                output_field=IntegerField(),
            )
        ).order_by("preferred", "-in_stock", "sort_order", "id")
    else:
        default = default.order_by("-in_stock", "sort_order", "id")
    discount = default.annotate(pct=(F("mrp") - F("inv_price")) * 100 / F("mrp"))
    return products.annotate(
        default_in_stock=Subquery(default.values("in_stock")[:1]),
        default_price=Subquery(default.values("inv_price")[:1]),
        default_discount=Subquery(discount.values("pct")[:1]),
    )


def with_card_data(queryset: QuerySet[Product], store: DarkStore) -> QuerySet[Product]:
    """Prefetches for `product_card()`: store variants (+ their images) and shared images."""
    ordered_images = ProductImage.objects.order_by("sort_order", "id")
    return queryset.select_related("category").prefetch_related(
        Prefetch(
            "variants",
            queryset=sold_variants(store).prefetch_related(
                Prefetch("images", queryset=ordered_images, to_attr="own_images")
            ),
            to_attr="store_variants",
        ),
        Prefetch(
            "images",
            queryset=ordered_images.filter(variant__isnull=True),
            to_attr="shared_images",
        ),
    )


SORT_ORDERING = {
    ProductSort.PRICE_ASC: ("default_price", "sort_order", "name", "id"),
    ProductSort.PRICE_DESC: ("-default_price", "sort_order", "name", "id"),
    ProductSort.DISCOUNT: ("-default_discount", "sort_order", "name", "id"),
}


def sort_products(queryset: QuerySet[Product], sort: str, relevance: Sequence[str]):
    """In-stock (default variant) first for every sort, then the sort, then a stable order."""
    ordering = SORT_ORDERING.get(sort, tuple(relevance))
    return queryset.order_by("-default_in_stock", *ordering)


# --------------------------------------------------------------------------- serialisation


def money(value: Decimal) -> str:
    return str(Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP))


def _discount_percent(mrp: Decimal, price: Decimal) -> int:
    if mrp <= 0 or price >= mrp:
        return 0
    pct = ((mrp - price) * 100 / mrp).to_integral_value(rounding=ROUND_FLOOR)
    return max(0, min(99, int(pct)))


UNIT_BASIS = {
    VariantUnit.ML: (Decimal(1), "100 ml", Decimal(100)),
    VariantUnit.L: (Decimal(1000), "100 ml", Decimal(100)),
    VariantUnit.G: (Decimal(1), "100 g", Decimal(100)),
    VariantUnit.KG: (Decimal(1000), "100 g", Decimal(100)),
    VariantUnit.PIECE: (Decimal(1), "1 pc", Decimal(1)),
}


def unit_price(variant: ProductVariant, price: Decimal) -> dict | None:
    if not variant.unit_value or variant.unit not in UNIT_BASIS:
        return None
    factor, label, per = UNIT_BASIS[variant.unit]
    base_quantity = Decimal(variant.unit_value) * factor
    return {"amount": money(price * per / base_quantity), "per": label}


def _variant_image(variant, product) -> dict | None:
    own = getattr(variant, "own_images", None) or []
    shared = getattr(product, "shared_images", None) or []
    first = own[0] if own else (shared[0] if shared else None)
    return image_set(first.image, first.alt_text) if first else None


def variant_summary(variant, product) -> dict:
    price = variant.inv_price
    stock = availability(
        on_hand=variant.inv_on_hand,
        reserved=variant.inv_reserved,
        is_available=variant.inv_is_available,
        max_qty_per_order=variant.max_qty_per_order,
    )
    return {
        "id": variant.pk,
        "name": variant.name,
        "mrp": money(variant.mrp),
        "selling_price": money(price),
        "discount_amount": money(max(variant.mrp - price, Decimal(0))),
        "discount_percent": _discount_percent(variant.mrp, price),
        "unit_price": unit_price(variant, price),
        "stock_status": str(stock.stock_status),
        "orderable_quantity": stock.orderable_quantity,
        "units_left": stock.units_left,
        "max_qty_per_order": variant.max_qty_per_order,
        "image": _variant_image(variant, product),
    }


def pick_default(variants: Sequence, preferred_id: int | None = None):
    """The default variant (module docstring). `variants` are in display order."""
    if preferred_id is not None:
        for variant in variants:
            if variant.pk == preferred_id:
                return variant
    for variant in variants:
        if variant.in_stock:
            return variant
    return variants[0]


def product_card(product: Product, preferred_id: int | None = None) -> dict:
    variants = product.store_variants
    default = pick_default(variants, preferred_id)
    summaries = [variant_summary(v, product) for v in variants]
    default_summary = next(s for s in summaries if s["id"] == default.pk)
    return {
        "id": product.pk,
        "slug": product.slug,
        "name": product.name,
        "brand": product.brand,
        "is_veg": product.is_veg,
        "image": default_summary["image"],
        "default_variant_id": default.pk,
        "variants": summaries,
    }


def category_tile(category: Category) -> dict:
    return {
        "id": category.pk,
        "name": category.name,
        "slug": category.slug,
        "image": image_set(category.image, category.name),
    }


def cards(products: Iterable[Product], preferred: dict[int, int] | None = None) -> list[dict]:
    preferred = preferred or {}
    return [product_card(p, preferred.get(p.pk)) for p in products if p.store_variants]


# --------------------------------------------------------------------------- lookups


# ASCII only: `str.isdigit()` is also true for "²" or "٣" (which `int()` then rejects), and a
# NUL character must never reach PostgreSQL (psycopg refuses it). Anything that is neither an
# id nor a well-formed slug is simply "not found", without a query.
_ID_RE = re.compile(r"[0-9]{1,18}")
_SLUG_RE = re.compile(r"[-a-zA-Z0-9_]+")


def parse_id_or_slug(value: str | None) -> int | str | None:
    """`"101"` -> 101, `"canola-oil"` -> `"canola-oil"`, anything else -> None."""
    value = (value or "").strip()
    if _ID_RE.fullmatch(value):
        return int(value)
    if _SLUG_RE.fullmatch(value):
        return value
    return None


def _id_or_slug(queryset: QuerySet, value: str):
    key = parse_id_or_slug(value)
    if key is None:
        return None
    if isinstance(key, int):
        return queryset.filter(pk=key).first()
    return queryset.filter(slug=key).first()


def _active_categories() -> QuerySet[Category]:
    return Category.objects.filter(is_active=True).filter(
        Q(parent__isnull=True) | Q(parent__is_active=True)
    )


def find_category(value: str) -> Category:
    category = _id_or_slug(_active_categories(), value)
    if category is None:
        raise NotFound("Category not found.")
    return category


def store_collections(store: DarkStore) -> QuerySet[Collection]:
    return (
        Collection.objects.filter(is_active=True)
        .filter(Q(stores__id=store.pk) | Q(stores__isnull=True))
        .distinct()
        .order_by("sort_order", "name", "id")
    )


def find_collection(store: DarkStore, value: str) -> Collection:
    collection = _id_or_slug(store_collections(store), value)
    if collection is None:
        raise NotFound("Collection not found.")
    return collection


# --------------------------------------------------------------------------- categories


def category_tree(store: DarkStore) -> dict:
    """Active categories with products sold at the store, two levels, admin order."""
    used = set(sold_products(store).values_list("category_id", flat=True).order_by().distinct())
    categories = list(_active_categories().order_by("sort_order", "name", "id"))
    children: dict[int, list[Category]] = {}
    for category in categories:
        if category.parent_id is not None and category.pk in used:
            children.setdefault(category.parent_id, []).append(category)
    results = []
    for category in categories:
        if category.parent_id is not None:
            continue
        kids = children.get(category.pk, [])
        if category.pk in used or kids:
            children_tiles = [category_tile(c) for c in kids]
            results.append({**category_tile(category), "children": children_tiles})
    return {"results": results}


# --------------------------------------------------------------------------- product lists


def _collection_items(store: DarkStore, collection: Collection) -> QuerySet[CollectionItem]:
    """The collection's items for the outer product, sold at the store, in item order."""
    return CollectionItem.objects.filter(
        collection=collection,
        variant__product=OuterRef("pk"),
        variant__in=sold_variants(store).values("pk"),
    ).order_by("sort_order", "id")


def product_list_queryset(
    store: DarkStore, *, category: str | None, collection: str | None, sort: str
) -> QuerySet[Product]:
    if collection:
        items = _collection_items(store, find_collection(store, collection))
        products = (
            store_products(store, preferred=Subquery(items.values("variant_id")[:1]))
            .filter(preferred_variant_id__isnull=False)
            .annotate(item_order=Subquery(items.values("sort_order")[:1]))
        )
        relevance = ("item_order", "sort_order", "name", "id")
    else:
        products = store_products(store)
        relevance = ("sort_order", "name", "id")
    if category:
        found = find_category(category)
        products = products.filter(Q(category=found) | Q(category__parent=found))
    return sort_products(products, sort, relevance)


def page_cards(products: Iterable[Product]) -> list[dict]:
    """Cards for one evaluated page (honours a `preferred_variant_id` annotation)."""
    products = list(products)
    preferred = {
        p.pk: p.preferred_variant_id for p in products if getattr(p, "preferred_variant_id", None)
    }
    return cards(products, preferred)


# --------------------------------------------------------------------------- search


def _terms(query: str) -> list[str]:
    return [t for t in re.split(r"\s+", query.strip()) if t][:MAX_SEARCH_TERMS]


def search_queryset(store: DarkStore, query: str, sort: str) -> QuerySet[Product]:
    """Every term must match the name, a sold variant's name, the tags or the category."""
    products = store_products(store)
    variant_names = sold_variants(store).filter(product=OuterRef("pk"))
    for index, term in enumerate(_terms(query)):
        flag = f"variant_match_{index}"
        products = products.annotate(
            **{flag: Exists(variant_names.filter(name__icontains=term))}
        ).filter(
            Q(name__icontains=term)
            | Q(search_keywords__icontains=term)
            | Q(category__name__icontains=term)
            | Q(category__parent__name__icontains=term)
            | Q(**{flag: True})
        )
    phrase = query.strip()
    products = products.annotate(
        rank=Case(
            When(name__istartswith=phrase, then=Value(3)),
            When(name__icontains=phrase, then=Value(2)),
            default=Value(1),
            output_field=IntegerField(),
        )
    )
    return sort_products(products, sort, ("-rank", "sort_order", "name", "id"))


def suggestions(store: DarkStore, query: str) -> dict:
    query = query.strip()
    if not query:
        trending = TrendingSearch.objects.filter(is_active=True).order_by("sort_order", "term")
        items = [_keyword(t.term) for t in trending[:SUGGESTION_LIMIT]]
        return {"query": "", "suggestions": items}
    products = with_card_data(search_queryset(store, query, ProductSort.RELEVANCE), store)[:5]
    items = []
    for card in cards(products):
        items.append(
            {
                "type": SuggestionType.PRODUCT.value,
                "text": card["name"],
                "query": card["name"].lower(),
                "id": card["id"],
                "slug": card["slug"],
                "image": card["image"],
            }
        )
    used = set(sold_products(store).values_list("category_id", flat=True).order_by().distinct())
    for category in _active_categories().filter(name__icontains=query).order_by("sort_order")[:3]:
        if category.pk in used or category.children.filter(pk__in=used).exists():
            items.append(
                {
                    "type": SuggestionType.CATEGORY.value,
                    "text": category.name,
                    "query": category.name.lower(),
                    "id": category.pk,
                    "slug": category.slug,
                    "image": image_set(category.image, category.name),
                }
            )
    for trend in TrendingSearch.objects.filter(is_active=True, term__icontains=query)[:3]:
        items.append(_keyword(trend.term))
    return {"query": query, "suggestions": items[:SUGGESTION_LIMIT]}


def _keyword(term: str) -> dict:
    return {
        "type": SuggestionType.KEYWORD.value,
        "text": term,
        "query": term,
        "id": None,
        "slug": None,
        "image": None,
    }


# --------------------------------------------------------------------------- detail


def product_detail(store: DarkStore, id_or_slug: str) -> dict:
    product = _id_or_slug(
        with_card_data(store_products(store), store).select_related("category"), id_or_slug
    )
    if product is None:
        raise NotFound("Product not found.")
    card = product_card(product)
    shared = product.shared_images
    variants = []
    for variant, summary in zip(product.store_variants, card["variants"], strict=True):
        gallery = [*variant.own_images, *shared]
        variants.append(
            {
                **summary,
                "sku": variant.sku,
                "net_quantity": variant.net_quantity,
                "images": [image_set(img.image, img.alt_text) for img in gallery],
            }
        )
    similar = with_card_data(
        sort_products(
            store_products(store).filter(category_id=product.category_id).exclude(pk=product.pk),
            ProductSort.RELEVANCE,
            ("sort_order", "name", "id"),
        ),
        store,
    )[:SIMILAR_SIZE]
    attributes = product.attributes or {}
    return {
        "id": product.pk,
        "slug": product.slug,
        "name": product.name,
        "brand": product.brand,
        "is_veg": product.is_veg,
        "category": category_tile(product.category),
        "short_description": product.short_description,
        "description": product.description,
        "highlights": list(product.highlights or []),
        "default_variant_id": card["default_variant_id"],
        "variants": variants,
        **{key: attributes.get(key) or "" for key in LABEL_TEXT_KEYS},
        "nutrition": attributes.get("nutrition"),
        "similar_products": cards(similar),
    }


# --------------------------------------------------------------------------- collections & home


def _rail_cards(store: DarkStore, collection_ids: list[int], limit: int) -> dict[int, list]:
    """Cards per collection (item order, out-of-stock last), in a constant number of queries."""
    sold_ids = sold_variants(store).values("pk")
    items = list(
        CollectionItem.objects.filter(collection_id__in=collection_ids, variant__in=sold_ids)
        .select_related("variant")
        .order_by("collection_id", "sort_order", "id")
    )
    product_ids = {item.variant.product_id for item in items}
    products = {
        p.pk: p
        for p in with_card_data(_visible_products().filter(pk__in=product_ids), store)
        if p.store_variants
    }
    rails: dict[int, list] = {cid: [] for cid in collection_ids}
    seen: dict[int, set] = {cid: set() for cid in collection_ids}
    for item in items:
        product = products.get(item.variant.product_id)
        if product is None or product.pk in seen[item.collection_id]:
            continue
        seen[item.collection_id].add(product.pk)
        rails[item.collection_id].append(product_card(product, item.variant_id))
    for cid, rail in rails.items():
        rail.sort(key=lambda card: _card_out_of_stock(card))  # stable: keeps item order
        rails[cid] = rail[:limit] if limit else rail
    return rails


def _card_out_of_stock(card: dict) -> bool:
    default = next(v for v in card["variants"] if v["id"] == card["default_variant_id"])
    return default["stock_status"] == "OUT_OF_STOCK"


def collection_detail(store: DarkStore, slug: str) -> dict:
    collection = store_collections(store).filter(slug=slug).first()
    if collection is None:
        raise NotFound("Collection not found.")
    products = _rail_cards(store, [collection.pk], MAX_COLLECTION_ITEMS)[collection.pk]
    return {
        "id": collection.pk,
        "name": collection.name,
        "slug": collection.slug,
        "products": products,
    }


def home_body(store: DarkStore) -> dict:
    """The cacheable part of `GET /home/` (no store status, no buy again)."""
    now = timezone.now()
    banners = (
        Banner.objects.filter(is_active=True)
        .filter(Q(starts_at__isnull=True) | Q(starts_at__lte=now))
        .filter(Q(ends_at__isnull=True) | Q(ends_at__gt=now))
        .filter(Q(stores__id=store.pk) | Q(stores__isnull=True))
        .distinct()
        .order_by("sort_order", "id")
    )
    tree = category_tree(store)["results"]
    collections = list(store_collections(store).filter(show_on_home=True))
    rails = _rail_cards(store, [c.pk for c in collections], 0)
    collection_rails = [
        {
            "id": c.pk,
            "name": c.name,
            "slug": c.slug,
            "products": rails[c.pk][:RAIL_SIZE],
            "has_more": len(rails[c.pk]) > RAIL_SIZE,
        }
        for c in collections
        if rails[c.pk]
    ]
    return {
        "banners": [
            {
                "id": b.pk,
                "title": b.title,
                "image": image_set(b.image, b.title),
                "link_type": b.link_type,
                "link_value": b.link_value,
            }
            for b in banners
        ],
        "categories": [{k: v for k, v in node.items() if k != "children"} for node in tree],
        "collections": collection_rails,
    }


def buy_again(store: DarkStore, user) -> list[dict]:
    """'Previously bought' rail. Orders arrive in Phase 3/4; until then always empty."""
    return []
