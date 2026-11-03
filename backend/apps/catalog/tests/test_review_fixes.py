"""P2 code review fixes in the catalog API: id-or-slug lookups are ASCII-only (#1, the same class
of bug as BUG-0002), and paginated bodies are cached under the canonical query (#6)."""

from unittest import mock

import pytest

from apps.catalog.services import parse_id_or_slug
from apps.catalog.validators import validate_not_all_digits

pytestmark = pytest.mark.django_db

ODD = ["\u00b2", "\u0663", "%00", "a%00b", "\uff11\uff10\uff11", "caf\u00e9", "%20"]


class TestIdOrSlug:
    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            ("101", 101),
            (" 101 ", 101),
            ("jivo-canola-oil", "jivo-canola-oil"),
            ("\u00b2", None),
            ("\u0663", None),
            ("\uff11\uff10\uff11", None),
            ("a\x00b", None),
            ("\x00", None),
            ("", None),
            ("1" * 19, None),  # beyond bigint: not an id, and not a slug of digits either
        ],
    )
    def test_parse(self, value, expected):
        assert parse_id_or_slug(value) == expected

    @pytest.mark.parametrize("value", ODD)
    def test_product_detail_never_500(self, store_client, value):
        """Review #1: a superscript-two id was a 500 (`int()` failed); NUL reached psycopg."""
        response = store_client.get(f"/api/v1/products/{value}/")
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "NOT_FOUND"

    @pytest.mark.parametrize("param", ["category", "collection"])
    @pytest.mark.parametrize("value", ["\u00b2", "\u0663", "\uff11"])
    def test_list_filters_never_500(self, store_client, param, value):
        response = store_client.get("/api/v1/products/", {param: value})
        assert response.status_code == 404

    @pytest.mark.parametrize("param", ["category", "collection", "q"])
    def test_nul_in_query_parameters_is_a_validation_error(self, store_client, param):
        """DRF's CharField rejects NUL before any query (also for search `q`)."""
        path = "/api/v1/search/" if param == "q" else "/api/v1/products/"
        response = store_client.get(path, {param: "oil\x00"})
        assert response.status_code == 400
        assert param in response.json()["error"]["details"]

    def test_real_ids_and_slugs_still_work(self, store_client, world):
        assert store_client.get(f"/api/v1/products/{world.canola.pk}/").status_code == 200
        assert store_client.get(f"/api/v1/products/{world.canola.slug}/").status_code == 200

    def test_slug_validator_is_ascii(self):
        from django.core.exceptions import ValidationError

        with pytest.raises(ValidationError):
            validate_not_all_digits("2024")
        validate_not_all_digits("\u00b2")  # not "only digits" (SlugField rejects it anyway)


class TestCanonicalPagination:
    """Review #6: junk or reordered query parameters neither create new cache entries nor end
    up in a body served to other clients."""

    def test_links_carry_only_the_validated_query(self, store_client):
        response = store_client.get(
            "/api/v1/products/",
            {"sort": "price_asc", "page_size": "2", "utm": "<script>", "category": "edible-oils"},
        )
        body = response.json()
        assert body["next"] == (
            "http://testserver/api/v1/products/"
            "?category=edible-oils&page=2&page_size=2&sort=price_asc"
        )
        assert "utm" not in body["next"]
        second = store_client.get(body["next"]).json()
        assert second["previous"] == (
            "http://testserver/api/v1/products/?category=edible-oils&page_size=2&sort=price_asc"
        )

    def test_equivalent_queries_share_one_cache_entry(self, store_client):
        from apps.catalog import views

        with mock.patch.object(views, "cached", wraps=views.cached) as spy:
            store_client.get("/api/v1/search/", {"q": "oil", "x": "1"})
            store_client.get("/api/v1/search/", {"x": "2", "q": "oil", "page": "01"})
        keys = [call.args[2] for call in spy.call_args_list]
        assert keys[0] == keys[1]

    def test_invalid_page_is_still_404(self, store_client):
        assert store_client.get("/api/v1/search/", {"q": "oil", "page": "99"}).status_code == 404
