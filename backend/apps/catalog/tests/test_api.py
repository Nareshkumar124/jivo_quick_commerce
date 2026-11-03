"""Catalog API for one store (06 §2.4): real responses conform to the published contract, store
scoping, default variant and sorting rules, stock flags (DL-26), caching and query counts."""

from decimal import Decimal
from unittest import mock

import pytest
import redis
from django.core.cache import cache

from apps.cms.services import get_app_config
from apps.inventory import services as inventory
from apps.inventory.models import MovementType

pytestmark = pytest.mark.django_db


def default_of(card: dict) -> dict:
    return next(v for v in card["variants"] if v["id"] == card["default_variant_id"])


class TestStoreLookup:
    @pytest.mark.parametrize("path", ["/api/v1/home/", "/api/v1/products/", "/api/v1/categories/"])
    def test_unknown_store(self, api_client, world, path):
        response = api_client.get(path, headers={"X-Store-Id": "999999"})
        assert response.status_code == 404
        assert response.json()["error"] == {
            "code": "STORE_NOT_FOUND",
            "message": "This store is not available. Check serviceability again.",
            "details": {"store_id": 999999},
        }

    def test_deactivated_store(self, store_client, world):
        world.store.is_active = False
        world.store.save()
        assert store_client.get("/api/v1/categories/").json()["error"]["code"] == "STORE_NOT_FOUND"

    def test_closed_store_is_browsable(self, store_client, world, conforms):
        world.store.is_accepting_orders = False
        world.store.save()
        response = store_client.get("/api/v1/home/")
        assert response.status_code == 200
        assert response.json()["store"] == {
            "id": world.store.pk,
            "name": "Jivo Sector 14, Gurugram",
            "is_open": False,
            "opens_at": None,
        }


class TestHome:
    def test_anonymous_home(self, store_client, world, conforms):
        body = store_client.get("/api/v1/home/").json()
        conforms(body, "HomeFeed")
        assert body["store"]["is_open"] is True
        assert [b["title"] for b in body["banners"]] == ["Canola deal"]  # not the Noida banner
        assert body["banners"][0]["image"]["large"].endswith("-1024.webp")
        assert [c["slug"] for c in body["categories"]] == ["edible-oils", "wellness-beverages"]
        rails = {r["slug"]: r for r in body["collections"]}
        assert list(rails) == ["bestsellers", "offers"]
        names = [card["name"] for card in rails["bestsellers"]["products"]]
        # item order, out-of-stock (mustard) last
        assert names == [
            "Jivo Cold Pressed Canola Oil",
            "Jivo Pomace Olive Oil",
            "Jivo Wheatgrass Juice",
            "Jivo Mustard Oil",
        ]
        deal = rails["offers"]["products"][0]
        assert deal["default_variant_id"] == world.canola_5l.pk  # the collection's variant
        assert deal["image"]["alt_text"] == "Canola 5 L jar"
        assert body["buy_again"] == []

    def test_signed_in_home(self, make_auth_client, user, world):
        client = make_auth_client(user)
        response = client.get("/api/v1/home/", headers={"X-Store-Id": str(world.store.pk)})
        assert response.status_code == 200
        assert response.json()["buy_again"] == []  # orders arrive in Phase 3/4

    def test_store_specific_collection_hidden_elsewhere(self, api_client, world):
        body = api_client.get(
            "/api/v1/home/", headers={"X-Store-Id": str(world.other_store.pk)}
        ).json()
        assert [r["slug"] for r in body["collections"]] == ["bestsellers"]
        assert [c["name"] for c in body["collections"][0]["products"]] == ["Jivo Pomace Olive Oil"]
        assert [b["title"] for b in body["banners"]] == ["Canola deal", "Noida only"]


class TestCategories:
    def test_tree_has_only_categories_with_products_here(self, store_client, world, conforms):
        body = store_client.get("/api/v1/categories/").json()
        conforms(body, "CategoryTree")
        assert [(n["slug"], [c["slug"] for c in n["children"]]) for n in body["results"]] == [
            ("edible-oils", ["canola-oil"]),
            ("wellness-beverages", []),
        ]


class TestProductList:
    def test_category_includes_sub_categories(self, store_client, world, conforms):
        body = store_client.get("/api/v1/products/?category=edible-oils").json()
        conforms(body, "PaginatedProductCardList")
        names = [p["name"] for p in body["results"]]
        assert names[-1] == "Jivo Mustard Oil"  # out of stock last
        assert set(names) == {
            "Jivo Cold Pressed Canola Oil",
            "Jivo Pomace Olive Oil",
            "Jivo Mustard Oil",
        }
        assert body["count"] == 3

    def test_by_category_id(self, store_client, world):
        body = store_client.get(f"/api/v1/products/?category={world.canola_cat.pk}").json()
        assert [p["slug"] for p in body["results"]] == ["jivo-cold-pressed-canola-oil"]

    def test_tile_fields(self, store_client, world):
        body = store_client.get("/api/v1/products/?category=canola-oil").json()
        card = body["results"][0]
        assert card["default_variant_id"] == world.canola_1l.pk  # first in stock
        assert [v["name"] for v in card["variants"]] == ["1 L", "5 L"]  # inactive variant hidden
        one_litre, five_litre = card["variants"]
        assert one_litre | {"image": None} == {
            "id": world.canola_1l.pk,
            "name": "1 L",
            "mrp": "349.00",
            "selling_price": "279.00",
            "discount_amount": "70.00",
            "discount_percent": 20,
            "unit_price": {"amount": "27.90", "per": "100 ml"},
            "stock_status": "IN_STOCK",
            "orderable_quantity": 5,
            "units_left": None,
            "max_qty_per_order": 5,
            "image": None,
        }
        assert (five_litre["stock_status"], five_litre["units_left"]) == ("LOW_STOCK", 2)
        assert five_litre["orderable_quantity"] == 2
        assert five_litre["unit_price"] == {"amount": "25.98", "per": "100 ml"}
        assert five_litre["image"]["alt_text"] == "Canola 5 L jar"  # own image first
        assert one_litre["image"]["alt_text"] == "Canola bottle"  # falls back to the product's

    def test_store_price_override(self, store_client, world):
        row = world.olive_1l.inventory.get(store=world.store)
        inventory.set_price_override(row, Decimal("649.00"))
        cache.clear()
        card = store_client.get("/api/v1/products/?category=edible-oils").json()["results"]
        olive = next(c for c in card if c["slug"] == "jivo-pomace-olive-oil")
        assert (
            olive["variants"][0]["selling_price"],
            olive["variants"][0]["discount_percent"],
        ) == (
            "649.00",
            27,
        )

    @pytest.mark.parametrize(("sort", "reverse"), [("price_asc", False), ("price_desc", True)])
    def test_price_sorts_use_the_default_variant(self, store_client, world, sort, reverse):
        results = store_client.get(f"/api/v1/products/?sort={sort}").json()["results"]
        in_stock = [c for c in results if default_of(c)["stock_status"] != "OUT_OF_STOCK"]
        assert results[: len(in_stock)] == in_stock  # in stock first
        prices = [Decimal(default_of(c)["selling_price"]) for c in in_stock]
        assert prices == sorted(prices, reverse=reverse)

    def test_discount_sort(self, store_client, world):
        results = store_client.get("/api/v1/products/?sort=discount").json()["results"]
        in_stock = [default_of(c)["discount_percent"] for c in results][:-1]
        assert in_stock == sorted(in_stock, reverse=True)

    def test_collection_filter_prefers_the_collection_variant(self, store_client, world):
        body = store_client.get("/api/v1/products/?collection=offers").json()
        assert [c["default_variant_id"] for c in body["results"]] == [world.canola_5l.pk]
        bestsellers = store_client.get(
            f"/api/v1/products/?collection={world.bestsellers.pk}"
        ).json()["results"]
        assert [c["slug"] for c in bestsellers][-1] == "jivo-mustard-oil"
        assert bestsellers[0]["slug"] == "jivo-cold-pressed-canola-oil"  # item order

    def test_pagination(self, store_client, world):
        body = store_client.get("/api/v1/products/?page_size=2").json()
        assert body["count"] == 4
        assert len(body["results"]) == 2
        assert "page=2" in body["next"]
        response = store_client.get("/api/v1/products/?page=9")
        assert response.status_code == 404
        assert response.json()["error"]["message"] == "Invalid page."

    @pytest.mark.parametrize(
        ("query", "message"),
        [("category=nope", "Category not found."), ("collection=nope", "Collection not found.")],
    )
    def test_unknown_filters(self, store_client, world, query, message):
        response = store_client.get(f"/api/v1/products/?{query}")
        assert response.status_code == 404
        assert response.json()["error"] == {"code": "NOT_FOUND", "message": message, "details": {}}

    def test_store_only_collection_is_404_elsewhere(self, api_client, world):
        response = api_client.get(
            "/api/v1/products/?collection=offers", headers={"X-Store-Id": str(world.other_store.pk)}
        )
        assert response.status_code == 404


class TestProductDetail:
    def test_by_slug_and_id(self, store_client, world, conforms):
        body = store_client.get("/api/v1/products/jivo-cold-pressed-canola-oil/").json()
        conforms(body, "ProductDetail")
        assert store_client.get(f"/api/v1/products/{world.canola.pk}/").json() == body
        assert body["category"]["slug"] == "canola-oil"
        assert body["ingredients"] == "Cold pressed canola oil (100%)."
        assert body["fssai_license_no"] == "10020064000123"
        assert body["importer"] == ""
        assert body["nutrition"]["columns"] == ["Per 100 ml"]
        one_litre, five_litre = body["variants"]
        assert (one_litre["sku"], one_litre["net_quantity"]) == ("JV-CAN-1L", "1 L")
        assert [i["alt_text"] for i in one_litre["images"]] == ["Canola bottle"]
        assert [i["alt_text"] for i in five_litre["images"]] == ["Canola 5 L jar", "Canola bottle"]
        similar = [p["slug"] for p in body["similar_products"]]
        assert similar == []  # alone in its sub-category

    def test_similar_products(self, store_client, world):
        body = store_client.get("/api/v1/products/jivo-pomace-olive-oil/").json()
        assert [p["slug"] for p in body["similar_products"]] == ["jivo-mustard-oil"]

    @pytest.mark.parametrize("lookup", ["no-such-product", "999999", "jivo-unsold-ghee"])
    def test_not_found(self, store_client, world, lookup):
        response = store_client.get(f"/api/v1/products/{lookup}/")
        assert response.status_code == 404
        assert response.json()["error"]["message"] == "Product not found."

    def test_not_sold_at_this_store(self, api_client, world):
        response = api_client.get(
            "/api/v1/products/jivo-wheatgrass-juice/",
            headers={"X-Store-Id": str(world.other_store.pk)},
        )
        assert response.status_code == 404


class TestSearch:
    @pytest.mark.parametrize(
        ("q", "expected"),
        [
            ("canola", ["jivo-cold-pressed-canola-oil"]),
            ("omega", ["jivo-cold-pressed-canola-oil"]),  # tag
            ("500 ml", ["jivo-wheatgrass-juice"]),  # variant name
            ("wellness", ["jivo-wheatgrass-juice"]),  # category
            ("JIVO olive", ["jivo-pomace-olive-oil"]),  # every term must match
            ("ghee", []),  # not sold here
        ],
    )
    def test_matches(self, store_client, world, conforms, q, expected):
        body = store_client.get("/api/v1/search/", {"q": q}).json()
        conforms(body, "PaginatedProductCardList")
        assert [p["slug"] for p in body["results"]] == expected

    def test_rank_and_stock_order(self, store_client, world):
        slugs = [p["slug"] for p in store_client.get("/api/v1/search/?q=oil").json()["results"]]
        assert slugs[-1] == "jivo-mustard-oil"
        assert set(slugs) == {
            "jivo-cold-pressed-canola-oil",
            "jivo-pomace-olive-oil",
            "jivo-mustard-oil",
        }


class TestSuggest:
    def test_trending_for_blank_query(self, store_client, world, conforms):
        body = store_client.get("/api/v1/search/suggest/").json()
        conforms(body, "SearchSuggestions")
        assert body == {
            "query": "",
            "suggestions": [
                {"type": "keyword", "text": t, "query": t, "id": None, "slug": None, "image": None}
                for t in ("olive oil", "wheatgrass")
            ],
        }

    def test_typing(self, store_client, world, conforms):
        body = store_client.get("/api/v1/search/suggest/?q=canola").json()
        conforms(body, "SearchSuggestions")
        kinds = [(s["type"], s["slug"]) for s in body["suggestions"]]
        assert kinds == [
            ("product", "jivo-cold-pressed-canola-oil"),
            ("category", "canola-oil"),
        ]

    def test_trending_keyword_match(self, store_client, world):
        body = store_client.get("/api/v1/search/suggest/?q=wheat").json()
        assert [s["type"] for s in body["suggestions"]] == ["product", "keyword"]


class TestCollections:
    def test_detail(self, store_client, world, conforms):
        body = store_client.get("/api/v1/collections/bestsellers/").json()
        conforms(body, "CollectionDetail")
        assert [p["slug"] for p in body["products"]][-1] == "jivo-mustard-oil"
        assert len(body["products"]) == 4

    def test_unknown(self, store_client, world):
        response = store_client.get("/api/v1/collections/nope/")
        assert response.status_code == 404
        assert response.json()["error"]["message"] == "Collection not found."


class TestCaching:
    def test_stock_change_invalidates_after_commit(
        self, store_client, world, django_capture_on_commit_callbacks
    ):
        def juice_status():
            body = store_client.get("/api/v1/products/?category=wellness-beverages").json()
            return body["results"][0]["variants"][0]["stock_status"]

        assert juice_status() == "IN_STOCK"
        with django_capture_on_commit_callbacks(execute=True):
            inventory.adjust_stock(
                store=world.store,
                variant=world.juice_500,
                delta=-8,
                movement_type=MovementType.DAMAGE,
                reason="leak",
            )
        assert juice_status() == "LOW_STOCK"

    def test_catalog_edit_invalidates(
        self, store_client, world, django_capture_on_commit_callbacks
    ):
        assert store_client.get("/api/v1/categories/").json()["results"][0]["name"] == "Edible Oils"
        with django_capture_on_commit_callbacks(execute=True):
            world.oils.name = "Cooking Oils"
            world.oils.save()
        assert (
            store_client.get("/api/v1/categories/").json()["results"][0]["name"] == "Cooking Oils"
        )

    def test_cached_responses_skip_the_database(
        self, store_client, world, django_assert_max_num_queries
    ):
        get_app_config()
        store_client.get("/api/v1/home/")
        with django_assert_max_num_queries(0):  # store from the snapshot, body from Redis
            assert store_client.get("/api/v1/home/").status_code == 200

    def test_redis_down_serves_from_the_database(self, store_client, world):
        get_app_config()
        down = redis.exceptions.ConnectionError("down")
        with mock.patch("apps.catalog.cache.cache.get", side_effect=down):
            assert store_client.get("/api/v1/categories/").status_code == 200
        with mock.patch("apps.catalog.cache.cache.set", side_effect=down):
            assert store_client.get("/api/v1/categories/").status_code == 200


def _bypass_cache(kind, store_id, parts, build):
    return build()


class TestQueryCounts:
    """09 §1: list endpoints use a constant number of queries (cold cache)."""

    @pytest.fixture(autouse=True)
    def _cold(self, world):
        get_app_config()  # the app-guard middleware's config read is cached separately

    @pytest.mark.parametrize(
        ("path", "limit"),
        [
            ("/api/v1/home/", 14),
            ("/api/v1/products/", 9),
            ("/api/v1/products/?collection=bestsellers&sort=price_asc", 9),
            ("/api/v1/products/jivo-cold-pressed-canola-oil/", 10),
            ("/api/v1/search/?q=oil", 9),
            ("/api/v1/categories/", 5),
        ],
    )
    def test_constant_queries(
        self, store_client, world, django_assert_max_num_queries, path, limit
    ):
        with (
            mock.patch("apps.catalog.views.cached", side_effect=_bypass_cache),
            django_assert_max_num_queries(limit),
        ):
            assert store_client.get(path).status_code == 200

    def test_home_does_not_grow_with_products(
        self, store_client, world, django_assert_max_num_queries
    ):
        from apps.catalog.models import CollectionItem
        from apps.catalog.tests.factories import VariantFactory
        from apps.inventory.tests.factories import stock

        with mock.patch("apps.catalog.views.cached", side_effect=_bypass_cache):
            store_client.get("/api/v1/home/")  # warm the store snapshot (cached separately)
            with django_assert_max_num_queries(200) as before:
                store_client.get("/api/v1/home/")
            for _ in range(5):
                variant = VariantFactory()
                stock(world.store, variant, 3)
                CollectionItem.objects.create(collection=world.bestsellers, variant=variant)
            with django_assert_max_num_queries(200) as after:
                store_client.get("/api/v1/home/")
        assert len(after.captured_queries) == len(before.captured_queries)
