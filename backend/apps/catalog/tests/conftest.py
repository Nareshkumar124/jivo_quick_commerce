"""A small Gurugram catalog for one open store (plus a second store), built through the services
so the stock ledger is intact."""

from dataclasses import dataclass
from decimal import Decimal

import pytest
from drf_spectacular.generators import SchemaGenerator

from apps.catalog.models import Banner, Collection, CollectionItem, TrendingSearch
from apps.catalog.tests.factories import (
    CategoryFactory,
    ProductFactory,
    ProductImageFactory,
    VariantFactory,
    image_upload,
)
from apps.inventory.tests.factories import stock
from apps.stores.tests.factories import DarkStoreFactory


@dataclass
class World:
    store: object
    other_store: object
    oils: object
    canola_cat: object
    beverages: object
    empty_cat: object
    canola: object
    canola_1l: object
    canola_5l: object
    olive: object
    olive_1l: object
    mustard: object
    mustard_1l: object
    juice: object
    juice_500: object
    bestsellers: object
    offers: object


@pytest.fixture
def world(db) -> World:
    store = DarkStoreFactory(name="Jivo Sector 14, Gurugram")
    other_store = DarkStoreFactory(name="Jivo Noida 18")
    oils = CategoryFactory(name="Edible Oils", slug="edible-oils", sort_order=1)
    canola_cat = CategoryFactory(name="Canola Oil", slug="canola-oil", parent=oils)
    beverages = CategoryFactory(name="Wellness Beverages", slug="wellness-beverages", sort_order=2)
    empty_cat = CategoryFactory(name="Seeds", slug="seeds", sort_order=3)

    canola = ProductFactory(
        name="Jivo Cold Pressed Canola Oil",
        slug="jivo-cold-pressed-canola-oil",
        category=canola_cat,
        search_keywords="canola, cooking oil, omega 3",
        highlights=["Rich in omega-3"],
        attributes={
            "ingredients": "Cold pressed canola oil (100%).",
            "country_of_origin": "India",
            "fssai_license_no": "10020064000123",
            "nutrition": {
                "columns": ["Per 100 ml"],
                "rows": [{"name": "Energy (kcal)", "values": ["828"], "is_sub_row": False}],
            },
        },
        sort_order=1,
    )
    canola_1l = VariantFactory(product=canola, sku="JV-CAN-1L", name="1 L", sort_order=1)
    canola_5l = VariantFactory(
        product=canola,
        sku="JV-CAN-5L",
        name="5 L",
        net_quantity="5 L",
        unit_value=Decimal("5000"),
        mrp=Decimal("1650.00"),
        selling_price=Decimal("1299.00"),
        max_qty_per_order=3,
        sort_order=2,
    )
    ProductImageFactory(product=canola, alt_text="Canola bottle")
    ProductImageFactory(product=canola, variant=canola_5l, alt_text="Canola 5 L jar")

    olive = ProductFactory(
        name="Jivo Pomace Olive Oil", slug="jivo-pomace-olive-oil", category=oils
    )
    olive_1l = VariantFactory(
        product=olive, sku="JV-OLV-1L", mrp=Decimal("899.00"), selling_price=Decimal("699.00")
    )
    mustard = ProductFactory(name="Jivo Mustard Oil", slug="jivo-mustard-oil", category=oils)
    mustard_1l = VariantFactory(
        product=mustard, sku="JV-MUS-1L", mrp=Decimal("210.00"), selling_price=Decimal("189.00")
    )
    juice = ProductFactory(
        name="Jivo Wheatgrass Juice", slug="jivo-wheatgrass-juice", category=beverages
    )
    juice_500 = VariantFactory(
        product=juice,
        sku="JV-WG-500",
        name="500 ml",
        unit_value=Decimal("500"),
        mrp=Decimal("250.00"),
        selling_price=Decimal("225.00"),
    )
    # Not listed anywhere: inactive product, inactive variant, a variant not sold at the store.
    hidden = ProductFactory(name="Jivo Hidden Oil", category=oils, is_active=False)
    stock(store, VariantFactory(product=hidden), 10)
    stock(store, VariantFactory(product=canola, sku="JV-CAN-OLD", is_active=False), 10)
    VariantFactory(product=ProductFactory(name="Jivo Unsold Ghee", category=oils))

    stock(store, canola_1l, 40)
    stock(store, canola_5l, 2)  # LOW_STOCK
    stock(store, olive_1l, 12)
    stock(store, mustard_1l, 0)  # sold here, out of stock
    stock(store, juice_500, 9)
    stock(other_store, olive_1l, 5)

    bestsellers = Collection.objects.create(name="Bestsellers", slug="bestsellers", sort_order=1)
    for order, variant in enumerate([mustard_1l, canola_1l, olive_1l, juice_500]):
        CollectionItem.objects.create(collection=bestsellers, variant=variant, sort_order=order)
    offers = Collection.objects.create(name="Offers", slug="offers", sort_order=2)
    offers.stores.add(store)
    CollectionItem.objects.create(collection=offers, variant=canola_5l)
    Banner.objects.create(
        title="Canola deal",
        image=image_upload(1080, 480, "JPEG"),
        link_type="collection",
        link_value="offers",
    )
    elsewhere = Banner.objects.create(title="Noida only", image=image_upload(1080, 480, "JPEG"))
    elsewhere.stores.add(other_store)
    TrendingSearch.objects.create(term="olive oil", sort_order=1)
    TrendingSearch.objects.create(term="wheatgrass", sort_order=2)
    TrendingSearch.objects.create(term="retired", is_active=False)

    return World(
        store, other_store, oils, canola_cat, beverages, empty_cat, canola, canola_1l,
        canola_5l, olive, olive_1l, mustard, mustard_1l, juice, juice_500, bestsellers, offers,
    )  # fmt: skip


@pytest.fixture
def store_client(api_client, world):
    api_client.credentials(HTTP_X_STORE_ID=str(world.store.pk))
    return api_client


@pytest.fixture(scope="session")
def openapi_components() -> dict:
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


@pytest.fixture
def conforms(openapi_components):
    """Assert a real response body is a valid instance of an OpenAPI component (strict)."""
    import jsonschema

    from tests.test_schema_examples import to_json_schema

    def check(body, component: str) -> None:
        validator = to_json_schema(
            {"$ref": f"#/components/schemas/{component}"}, openapi_components
        )
        jsonschema.validate(body, validator)

    return check
