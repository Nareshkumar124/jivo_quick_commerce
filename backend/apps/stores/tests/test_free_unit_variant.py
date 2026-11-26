"""ADR-0003: `PricingConfig.free_unit_variant`, the size every free carton uses at a store. It
must be a size the store sells (`clean()`), cannot be deleted while used (PROTECT), and
seed_demo points GGN-01 at the 1 L water carton when the store sells it."""

import pytest
from django.core.exceptions import ValidationError
from django.db.models import ProtectedError

from apps.catalog.tests.factories import VariantFactory
from apps.inventory.tests.factories import stock
from apps.stores.models import PricingConfig
from apps.stores.seed import DEMO_STORE_CODE, WATER_1L_SKU, seed_free_unit_variant
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


class Out:
    def __init__(self):
        self.lines = []

    def write(self, text):
        self.lines.append(text)


def test_default_is_empty():
    pricing = PricingConfig.objects.create(store=DarkStoreFactory())
    assert pricing.free_unit_variant is None
    pricing.full_clean()


def test_a_size_the_store_sells_is_accepted():
    store = DarkStoreFactory()
    variant = VariantFactory()
    stock(store, variant, 0)  # out of stock is fine: the cart shows a notice
    pricing = PricingConfig(store=store, free_unit_variant=variant)
    pricing.full_clean()


def test_a_size_the_store_does_not_sell_is_refused():
    store = DarkStoreFactory()
    variant = VariantFactory()
    stock(DarkStoreFactory(), variant, 10)  # sold elsewhere only
    pricing = PricingConfig(store=store, free_unit_variant=variant)
    with pytest.raises(ValidationError) as error:
        pricing.full_clean()
    assert error.value.message_dict["free_unit_variant"] == [
        "This size is not sold at this store. Choose one it sells."
    ]


def test_the_free_size_cannot_be_deleted():
    """PROTECT: only the pricing row refers to this variant (no stock rows or movements)."""
    variant = VariantFactory()
    PricingConfig.objects.create(store=DarkStoreFactory(), free_unit_variant=variant)
    with pytest.raises(ProtectedError):
        variant.delete()


class TestSeed:
    def demo_store(self):
        store = DarkStoreFactory(code=DEMO_STORE_CODE)
        return PricingConfig.objects.create(store=store)

    def test_points_the_demo_store_at_the_one_litre_carton(self):
        pricing = self.demo_store()
        one_litre = VariantFactory(sku=WATER_1L_SKU)
        stock(pricing.store, one_litre, 50)
        seed_free_unit_variant(Out(), {})
        pricing.refresh_from_db()
        assert pricing.free_unit_variant == one_litre

    def test_nothing_when_the_store_does_not_sell_it(self):
        pricing = self.demo_store()
        VariantFactory(sku=WATER_1L_SKU)  # in the catalog, no stock row at GGN-01
        out = Out()
        seed_free_unit_variant(out, {})
        pricing.refresh_from_db()
        assert pricing.free_unit_variant is None
        assert "not sold there" in out.lines[-1]

    def test_a_size_set_in_the_admin_is_kept(self):
        pricing = self.demo_store()
        chosen = VariantFactory()
        stock(pricing.store, chosen, 5)
        stock(pricing.store, VariantFactory(sku=WATER_1L_SKU), 5)
        pricing.free_unit_variant = chosen
        pricing.save()
        seed_free_unit_variant(Out(), {})
        pricing.refresh_from_db()
        assert pricing.free_unit_variant == chosen
