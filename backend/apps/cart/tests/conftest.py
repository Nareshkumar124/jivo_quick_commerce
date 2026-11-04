"""A small shop for cart tests: one open store (D-09 pricing by default), a second store, three
categories with priced, stocked variants, and a customer with an address inside the store's
area."""

from dataclasses import dataclass
from decimal import Decimal

import pytest
from django.contrib.gis.geos import Point

from apps.accounts.models import Address
from apps.catalog.tests.factories import CategoryFactory, ProductFactory, VariantFactory
from apps.inventory.tests.factories import stock
from apps.stores.services import active_store
from apps.stores.tests.factories import DarkStoreFactory

INSIDE = (28.45, 77.05)  # inside the factory store's square
OUTSIDE = (28.70, 77.40)  # outside every factory store


def make_address(user, lat_lng=INSIDE, **kwargs) -> Address:
    lat, lng = lat_lng
    data = {
        "label": "home",
        "receiver_name": user.name or "Customer",
        "receiver_phone": user.phone or "+919876543210",
        "house": "Flat 402",
        "building_street": "Sunshine Apartments",
        "city": "Gurugram",
        "state": "Haryana",
        "pincode": "122001",
        "lat": Decimal(str(lat)),
        "lng": Decimal(str(lng)),
        "location": Point(lng, lat, srid=4326),
        **kwargs,
    }
    return Address.objects.create(user=user, **data)


@dataclass
class Shop:
    store_model: object
    other_store_model: object
    oils: object
    canola_cat: object
    seeds: object
    canola_1l: object  # ₹349 MRP, ₹279; 10 in stock; max 5
    canola_5l: object  # ₹1650 MRP, ₹1299; 2 in stock; max 3
    chia: object  # seeds: ₹150 MRP, ₹119; 20 in stock
    flax: object  # seeds: ₹99 MRP, ₹79; 20 in stock
    unsold: object  # active, but no stock row at the store

    @property
    def store(self):
        """The store as `X-Store-Id` resolves it (cached StoreArea)."""
        return active_store(self.store_model.pk)

    @property
    def other_store(self):
        return active_store(self.other_store_model.pk)

    def headers(self, store=None) -> dict:
        return {"X-Store-Id": str((store or self.store_model).pk)}


@pytest.fixture
def shop(db) -> Shop:
    store = DarkStoreFactory(name="Jivo Sector 14, Gurugram")
    other = DarkStoreFactory(name="Jivo Sector 29, Gurugram")
    oils = CategoryFactory(name="Edible Oils", slug="edible-oils")
    canola_cat = CategoryFactory(name="Canola Oil", slug="canola-oil", parent=oils)
    seeds = CategoryFactory(name="Seeds & Superfoods", slug="seeds-superfoods")
    canola = ProductFactory(name="Jivo Cold Pressed Canola Oil", category=canola_cat)
    canola_1l = VariantFactory(product=canola, name="1 L", sort_order=1)
    canola_5l = VariantFactory(
        product=canola,
        name="5 L",
        mrp=Decimal("1650.00"),
        selling_price=Decimal("1299.00"),
        max_qty_per_order=3,
        sort_order=2,
    )
    chia = VariantFactory(
        product=ProductFactory(name="Jivo Chia Seeds", category=seeds),
        name="100 g",
        unit="g",
        unit_value=Decimal("100"),
        mrp=Decimal("150.00"),
        selling_price=Decimal("119.00"),
    )
    flax = VariantFactory(
        product=ProductFactory(name="Jivo Roasted Flax Seeds", category=seeds),
        name="200 g",
        unit="g",
        unit_value=Decimal("200"),
        mrp=Decimal("99.00"),
        selling_price=Decimal("79.00"),
    )
    unsold = VariantFactory(product=ProductFactory(name="Jivo Olive Oil", category=oils))
    for variant, quantity in ((canola_1l, 10), (canola_5l, 2), (chia, 20), (flax, 20)):
        stock(store, variant, quantity)
        stock(other, variant, 50)
    return Shop(store, other, oils, canola_cat, seeds, canola_1l, canola_5l, chia, flax, unsold)


@pytest.fixture
def address(user):
    return make_address(user)
