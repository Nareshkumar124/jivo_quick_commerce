"""Phase 2 R1 contract: catalog routes, authentication behaviour, the `X-Store-Id` header errors
on every operation, and request validation messages that match the documented examples.
Catalog behaviour (stock, prices, sorting, query counts) is tested in R2."""

import pytest
from django.urls import reverse

from apps.catalog import examples as ex
from apps.catalog import views
from apps.catalog.serializers import (
    ProductListQuerySerializer,
    SearchQuerySerializer,
    SuggestQuerySerializer,
)

STORE_SCOPED_PATHS = [
    "/api/v1/home/",
    "/api/v1/categories/",
    "/api/v1/products/",
    "/api/v1/products/jivo-cold-pressed-canola-oil/",
    "/api/v1/products/101/",
    "/api/v1/search/?q=oil",
    "/api/v1/search/suggest/?q=can",
    "/api/v1/collections/bestsellers/",
]


def test_routes():
    assert reverse("home") == "/api/v1/home/"
    assert reverse("category-tree") == "/api/v1/categories/"
    assert reverse("product-list") == "/api/v1/products/"
    assert reverse("product-detail", args=["101"]) == "/api/v1/products/101/"
    assert reverse("search") == "/api/v1/search/"
    assert reverse("search-suggest") == "/api/v1/search/suggest/"
    assert reverse("collection-detail", args=["bestsellers"]) == "/api/v1/collections/bestsellers/"


@pytest.mark.parametrize(
    "view",
    [
        views.CategoryTreeView,
        views.ProductListView,
        views.ProductDetailView,
        views.SearchView,
        views.SearchSuggestView,
        views.CollectionDetailView,
    ],
)
def test_browsing_ignores_credentials(view):
    # A stale token must never block browsing; only home uses the (optional) token.
    assert list(view.authentication_classes) == []


@pytest.mark.django_db
class TestStoreHeader:
    @pytest.mark.parametrize("path", STORE_SCOPED_PATHS)
    def test_missing_header(self, api_client, path):
        response = api_client.get(path)
        assert response.status_code == 400
        assert response.json()["error"] == {
            "code": "VALIDATION_ERROR",
            "message": "Some fields are invalid.",
            "details": {"X-Store-Id": ["This header is required."]},
        }

    @pytest.mark.parametrize("path", STORE_SCOPED_PATHS)
    def test_malformed_header(self, api_client, path):
        response = api_client.get(path, headers={"X-Store-Id": "GGN-01"})
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "X-Store-Id": ["A valid store id is required."]
        }


@pytest.mark.django_db
class TestHomeAuthentication:
    def test_anonymous_is_allowed(self, api_client):
        # Reaches the store-header check: no 401 for anonymous callers.
        assert api_client.get("/api/v1/home/").status_code == 400

    def test_a_sent_token_is_checked(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer expired-or-garbage")
        response = api_client.get("/api/v1/home/", headers={"X-Store-Id": "1"})
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "TOKEN_INVALID"

    def test_browsing_ignores_a_garbage_token(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer expired-or-garbage")
        assert api_client.get("/api/v1/categories/").status_code == 400  # header, not 401


@pytest.mark.django_db
def test_invalid_sort_matches_the_documented_example(api_client):
    from apps.stores.tests.factories import DarkStoreFactory

    store = DarkStoreFactory()
    response = api_client.get(
        "/api/v1/products/?sort=cheapest", headers={"X-Store-Id": str(store.pk)}
    )
    assert response.status_code == 400
    assert response.json()["error"]["details"] == {"sort": ['"cheapest" is not a valid choice.']}


class TestQueryValidation:
    def test_product_list_defaults(self):
        serializer = ProductListQuerySerializer(data={})
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data == {"sort": "relevance"}

    @pytest.mark.parametrize("sort", ["relevance", "price_asc", "price_desc", "discount"])
    def test_sorts(self, sort):
        data = {"category": "edible-oils", "collection": "2", "sort": sort}
        assert ProductListQuerySerializer(data=data).is_valid()

    @pytest.mark.parametrize(
        ("data", "message"),
        [({}, "This field is required."), ({"q": ""}, "This field may not be blank.")],
    )
    def test_search_requires_q(self, data, message):
        serializer = SearchQuerySerializer(data=data)
        assert not serializer.is_valid()
        assert serializer.errors == {"q": [message]}

    def test_search_trims_q(self):
        serializer = SearchQuerySerializer(data={"q": "  canola  "})
        assert serializer.is_valid()
        assert serializer.validated_data == {"q": "canola", "sort": "relevance"}

    @pytest.mark.parametrize("data", [{}, {"q": ""}, {"q": "   "}])
    def test_suggest_blank_means_trending(self, data):
        serializer = SuggestQuerySerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data == {"q": ""}

    def test_suggest_max_length(self):
        serializer = SuggestQuerySerializer(data={"q": "x" * 101})
        assert not serializer.is_valid()
        assert serializer.errors == {"q": ["Ensure this field has no more than 100 characters."]}


class TestExamplesAreConsistent:
    """The fakes built from the examples must show correct money (02 §5, 08 §6.2)."""

    VARIANTS = [
        ex.CANOLA_1L,
        ex.CANOLA_5L,
        ex.OLIVE_1L,
        ex.MUSTARD_1L,
        ex.WHEATGRASS_500ML,
        ex.ALOE_1L,
    ]

    @pytest.mark.parametrize("variant", VARIANTS, ids=lambda v: str(v["id"]))
    def test_discounts(self, variant):
        from decimal import ROUND_FLOOR, Decimal

        mrp, price = Decimal(variant["mrp"]), Decimal(variant["selling_price"])
        assert Decimal(variant["discount_amount"]) == mrp - price
        percent = ((mrp - price) * 100 / mrp).to_integral_value(rounding=ROUND_FLOOR)
        assert variant["discount_percent"] == percent

    @pytest.mark.parametrize("variant", VARIANTS, ids=lambda v: str(v["id"]))
    def test_stock_fields(self, variant):
        status, orderable = variant["stock_status"], variant["orderable_quantity"]
        assert orderable <= variant["max_qty_per_order"]
        assert (status == "OUT_OF_STOCK") == (orderable == 0)
        assert (status == "LOW_STOCK") == (variant["units_left"] is not None)

    def test_default_variant_is_one_of_the_variants(self):
        cards = [ex.CANOLA, ex.CANOLA_5L_DEAL, ex.OLIVE, ex.MUSTARD, ex.WHEATGRASS, ex.ALOE]
        for card in [*cards, ex.CANOLA_DETAIL, ex.OLIVE_DETAIL]:
            assert card["default_variant_id"] in {v["id"] for v in card["variants"]}
