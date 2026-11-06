"""Phase 2 endpoints: home, categories, products, search, collections (06 §2.4).

Every endpoint is per store: it takes the `X-Store-Id` header (rules in `apps.stores.context`).
All are public. Home is optionally authenticated (a sent token is checked, for "buy again"); the
others ignore credentials, so a stale token never blocks browsing.

Views are thin: `get_store()` resolves `X-Store-Id` (400 / 404 `STORE_NOT_FOUND`), then the
body comes from `apps.catalog.services` through the per-store cache (`apps.catalog.cache`).
Store status and "buy again" are never cached.
"""

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog import examples as ex
from apps.catalog import services
from apps.catalog.cache import cached
from apps.catalog.serializers import (
    CategoryTreeSerializer,
    CollectionDetailSerializer,
    HomeFeedSerializer,
    PaginatedProductCardListSerializer,
    ProductDetailSerializer,
    ProductListQuerySerializer,
    SearchQuerySerializer,
    SearchSuggestionsSerializer,
    SuggestQuerySerializer,
)
from apps.core.errors import ErrorCode
from apps.core.pagination import CanonicalPagination, canonical_page_query
from apps.core.schema import (
    OPTIONAL_AUTH_UNAUTHORIZED,
    PAGE_NOT_FOUND,
    PAGINATION_PARAMETERS,
    error_example,
    validation_error,
)
from apps.core.throttling import SearchThrottle
from apps.stores.context import get_store
from apps.stores.schema import STORE_ID_PARAMETER, store_responses
from apps.stores.services import store_status

TAGS = ["catalog"]

CATEGORY_NOT_FOUND = error_example(
    ErrorCode.NOT_FOUND, "Category not found.", name="CATEGORY_NOT_FOUND"
)
COLLECTION_NOT_FOUND = error_example(
    ErrorCode.NOT_FOUND, "Collection not found.", name="COLLECTION_NOT_FOUND"
)
PRODUCT_NOT_FOUND = error_example(
    ErrorCode.NOT_FOUND,
    "Product not found.",
    name="PRODUCT_NOT_FOUND",
    summary="Unknown, inactive, or not sold at this store",
)
INVALID_SORT = validation_error(
    {"sort": ['"cheapest" is not a valid choice.']}, name="Invalid sort"
)


def _ok(serializer, description: str, *examples: tuple[str, dict]) -> OpenApiResponse:
    return OpenApiResponse(
        serializer,
        description=description,
        examples=[
            OpenApiExample(name, value=value, response_only=True) for name, value in examples
        ],
    )


class _PublicStoreView(APIView):
    """Public, per-store, credentials ignored."""

    authentication_classes: list = []
    permission_classes = [AllowAny]

    def page(self, request: Request, queryset, store, link_params: dict) -> dict:
        paginator = CanonicalPagination(link_params)
        products = paginator.paginate_queryset(
            services.with_card_data(queryset, store), request, view=self
        )
        return paginator.get_paginated_response(services.page_cards(products)).data


def _page_key(request: Request, link_params: dict, page: str) -> tuple:
    """Pagination bodies hold absolute URLs: key on the host, the path and the canonical query
    (validated parameters only; review #6), never the raw query string."""
    return (request.get_host(), request.path, tuple(sorted(link_params.items())), page)


class HomeView(APIView):
    """Optionally authenticated: anonymous works; a sent token is checked (401 if invalid)."""

    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="home_retrieve",
        tags=TAGS,
        summary="Home feed for a store",
        description=(
            "Banners, top-level categories, collection rails and, when signed in, 'buy again' "
            "(03 §2.5), all for the store in `X-Store-Id`.\n\n"
            "Optional authentication: send the token when signed in so `buy_again` is filled. "
            "An invalid or expired token gets 401 `TOKEN_INVALID` (refresh and retry); it is "
            "never silently treated as anonymous.\n\n"
            "`store` is the store's current status: show the store-closed banner when "
            "`store.is_open` is false (browsing stays allowed). Pull to refresh reloads this "
            "and re-checks serviceability."
        ),
        parameters=[STORE_ID_PARAMETER],
        responses=store_responses(
            {
                200: _ok(
                    HomeFeedSerializer,
                    "The home feed.",
                    ("Anonymous", ex.HOME_ANONYMOUS),
                    ("Signed in, with buy again", ex.HOME_SIGNED_IN),
                    ("Store closed", ex.HOME_STORE_CLOSED),
                ),
                401: OPTIONAL_AUTH_UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        store = get_store(request)
        body = cached("home", store.pk, (), lambda: services.home_body(store))
        user = request.user if request.user.is_authenticated else None
        data = {
            "store": store_status(store).as_dict(),
            **body,
            "buy_again": services.buy_again(store, user),
        }
        return Response(data)


class CategoryTreeView(_PublicStoreView):
    @extend_schema(
        operation_id="categories_list",
        tags=TAGS,
        summary="Category tree for a store",
        description=(
            "Top-level categories and their sub-categories that have products at this store "
            "(Categories tab, and the left rail of the product list). Two levels, not paginated."
        ),
        auth=[],
        parameters=[STORE_ID_PARAMETER],
        responses=store_responses(
            {200: _ok(CategoryTreeSerializer, "The category tree.", ("Tree", ex.CATEGORY_TREE))}
        ),
    )
    def get(self, request: Request) -> Response:
        store = get_store(request)
        return Response(cached("categories", store.pk, (), lambda: services.category_tree(store)))


class ProductListView(_PublicStoreView):
    @extend_schema(
        operation_id="products_list",
        tags=TAGS,
        summary="Product list (category, collection or all)",
        description=(
            "Product tiles with their variants, prices and stock at this store, paginated "
            "(infinite scroll). Filter by `category` (a top-level category includes its "
            "sub-categories) and/or `collection`; with neither, all products of the store. "
            "Products the store does not sell are never listed; out-of-stock ones are listed "
            "after in-stock ones, greyed out."
        ),
        auth=[],
        parameters=[STORE_ID_PARAMETER, ProductListQuerySerializer, *PAGINATION_PARAMETERS],
        responses=store_responses(
            {
                200: _ok(
                    PaginatedProductCardListSerializer,
                    "One page of products.",
                    ("Category edible-oils", ex.PRODUCTS_EDIBLE_OILS),
                    ("Sorted by price, first of several pages", ex.PRODUCTS_PRICE_ASC_PAGE_1),
                    ("No products", ex.PRODUCTS_EMPTY),
                ),
            },
            bad_request=(INVALID_SORT,),
            not_found=(CATEGORY_NOT_FOUND, COLLECTION_NOT_FOUND, PAGE_NOT_FOUND),
        ),
    )
    def get(self, request: Request) -> Response:
        store = get_store(request)
        query = ProductListQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        params = query.validated_data

        link_params, page = canonical_page_query(request, params)

        def build() -> dict:
            queryset = services.product_list_queryset(
                store,
                category=params.get("category"),
                collection=params.get("collection"),
                sort=params["sort"],
            )
            return self.page(request, queryset, store, link_params)

        key = _page_key(request, link_params, page)
        return Response(cached("products", store.pk, key, build))


class ProductDetailView(_PublicStoreView):
    @extend_schema(
        operation_id="products_retrieve",
        tags=TAGS,
        summary="Product detail",
        description=(
            "All variants this store sells (with price and stock), the gallery per variant, "
            "highlights, the label information required by FSSAI and Legal Metrology (09 §4) "
            "and similar products. 404 `NOT_FOUND` when the product is unknown, inactive, or "
            "not sold at this store."
        ),
        auth=[],
        parameters=[
            STORE_ID_PARAMETER,
            OpenApiParameter(
                "id_or_slug",
                OpenApiTypes.STR,
                OpenApiParameter.PATH,
                description=(
                    'Product id (e.g. "101") or slug (e.g. "jivo-cold-pressed-canola-oil").'
                ),
            ),
        ],
        responses=store_responses(
            {
                200: _ok(
                    ProductDetailSerializer,
                    "The product.",
                    ("Canola oil, two variants", ex.CANOLA_DETAIL),
                    ("Imported olive oil", ex.OLIVE_DETAIL),
                ),
            },
            not_found=(PRODUCT_NOT_FOUND,),
        ),
    )
    def get(self, request: Request, id_or_slug: str) -> Response:
        store = get_store(request)
        body = cached(
            "product", store.pk, (id_or_slug,), lambda: services.product_detail(store, id_or_slug)
        )
        return Response(body)


class SearchView(_PublicStoreView):
    throttle_classes = [SearchThrottle]  # T-814 (H3)

    @extend_schema(
        operation_id="search_products",
        tags=TAGS,
        summary="Search products",
        description=(
            "Same tiles as the product list, best match first. Matches product name, variant, "
            "tags and category. No results: 200 with `count: 0`; show the empty state with "
            "trending searches from `GET /search/suggest/`."
        ),
        auth=[],
        parameters=[STORE_ID_PARAMETER, SearchQuerySerializer, *PAGINATION_PARAMETERS],
        responses=store_responses(
            {
                200: _ok(
                    PaginatedProductCardListSerializer,
                    "One page of results.",
                    ('Results for "oil"', ex.SEARCH_OIL),
                    ("No results", ex.PRODUCTS_EMPTY),
                ),
            },
            bad_request=(
                validation_error({"q": ["This field is required."]}, name="Missing q"),
                validation_error({"q": ["This field may not be blank."]}, name="Blank q"),
                INVALID_SORT,
            ),
            not_found=(PAGE_NOT_FOUND,),
        ),
    )
    def get(self, request: Request) -> Response:
        store = get_store(request)
        query = SearchQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        params = query.validated_data

        link_params, page = canonical_page_query(request, params)

        def build() -> dict:
            queryset = services.search_queryset(store, params["q"], params["sort"])
            return self.page(request, queryset, store, link_params)

        key = _page_key(request, link_params, page)
        return Response(cached("search", store.pk, key, build))


class SearchSuggestView(_PublicStoreView):
    throttle_classes = [SearchThrottle]  # T-814 (H3)

    @extend_schema(
        operation_id="search_suggest",
        tags=TAGS,
        summary="Typeahead suggestions, or trending searches",
        description=(
            "Call while typing (debounced 300 ms). Up to 10 suggestions: products and "
            "categories open directly (`slug`), keywords run a search (`query`). With a blank "
            "or missing `q`, returns the trending searches (03 §2.7) as `keyword` items. "
            "Recent searches are kept on the device."
        ),
        auth=[],
        parameters=[STORE_ID_PARAMETER, SuggestQuerySerializer],
        responses=store_responses(
            {
                200: _ok(
                    SearchSuggestionsSerializer,
                    "Suggestions.",
                    ('Typing "can"', ex.SUGGEST_CAN),
                    ("Trending (blank q)", ex.SUGGEST_TRENDING),
                    ("No match", ex.SUGGEST_NONE),
                ),
            },
            bad_request=(
                validation_error(
                    {"q": ["Ensure this field has no more than 100 characters."]},
                    name="q too long",
                ),
            ),
        ),
    )
    def get(self, request: Request) -> Response:
        store = get_store(request)
        query = SuggestQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        q = query.validated_data["q"]
        return Response(cached("suggest", store.pk, (q,), lambda: services.suggestions(store, q)))


class CollectionDetailView(_PublicStoreView):
    @extend_schema(
        operation_id="collections_retrieve",
        tags=TAGS,
        summary="Collection page",
        description=(
            "A collection ('See all' on a home rail, or a banner link) with its products at "
            "this store. 404 `NOT_FOUND` when unknown, inactive or not shown at this store."
        ),
        auth=[],
        parameters=[
            STORE_ID_PARAMETER,
            OpenApiParameter(
                "slug",
                OpenApiTypes.STR,
                OpenApiParameter.PATH,
                description='Collection slug, e.g. "bestsellers".',
            ),
        ],
        responses=store_responses(
            {
                200: _ok(
                    CollectionDetailSerializer,
                    "The collection.",
                    ("Bestsellers", ex.COLLECTION_BESTSELLERS_DETAIL),
                ),
            },
            not_found=(COLLECTION_NOT_FOUND,),
        ),
    )
    def get(self, request: Request, slug: str) -> Response:
        store = get_store(request)
        body = cached(
            "collection", store.pk, (slug,), lambda: services.collection_detail(store, slug)
        )
        return Response(body)
