"""Per-variant minimum order quantity (`min_qty_per_order`, 2026-11-13; 07 ProductVariant,
08 §6.1): the model constraints, and the catalog API publishing it, with a variant whose free
units are below its minimum shown as out of stock (never buyable) and never picked as the
in-stock default variant."""

import pytest
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.db import IntegrityError, connection, transaction

from apps.catalog.models import ProductVariant
from apps.catalog.tests.factories import VariantFactory

pytestmark = pytest.mark.django_db


def set_limits(variant, *, minimum: int, maximum: int | None = None) -> None:
    variant.min_qty_per_order = minimum
    if maximum is not None:
        variant.max_qty_per_order = maximum
    variant.save()
    cache.clear()  # the catalog cache is bumped on commit; tests run inside one transaction


class TestModel:
    def test_default_is_one(self):
        """Existing and new variants have no minimum unless one is set."""
        assert VariantFactory().min_qty_per_order == 1

    @pytest.mark.parametrize(
        "table", ["catalog_productvariant", "catalog_historicalproductvariant"]
    )
    def test_database_fills_one_for_code_that_omits_the_column(self, table):
        """Deploy safety: the column has a DB default of 1 (db_default), so the previous
        release (and a code rollback) can still insert variants and their history rows."""
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT column_default, is_nullable FROM information_schema.columns "
                "WHERE table_name = %s AND column_name = 'min_qty_per_order'",
                [table],
            )
            assert cursor.fetchone() == ("1", "NO")

    @pytest.mark.parametrize(("minimum", "maximum"), [(0, 5), (6, 5)])
    def test_db_constraints(self, minimum, maximum):
        """min_qty_per_order >= 1 and <= max_qty_per_order are DB check constraints."""
        variant = VariantFactory(max_qty_per_order=5)
        with transaction.atomic(), pytest.raises(IntegrityError):
            ProductVariant.objects.filter(pk=variant.pk).update(
                min_qty_per_order=minimum, max_qty_per_order=maximum
            )

    def test_minimum_equal_to_maximum_is_allowed(self):
        variant = VariantFactory(max_qty_per_order=5, min_qty_per_order=5)
        variant.full_clean()
        assert ProductVariant.objects.get(pk=variant.pk).min_qty_per_order == 5

    def test_clean_explains_a_minimum_above_the_maximum(self):
        """The admin form and the catalog import get a field error, not a DB error."""
        variant = VariantFactory.build(max_qty_per_order=5, min_qty_per_order=6)
        with pytest.raises(ValidationError) as caught:
            variant.clean()
        assert caught.value.message_dict == {
            "min_qty_per_order": ["Cannot be above the maximum quantity per order."]
        }


class TestCatalogApi:
    def test_variant_publishes_its_minimum(self, store_client, world, conforms):
        """API exposes min_qty_per_order (integer >= 1) next to max_qty_per_order."""
        set_limits(world.canola_1l, minimum=5, maximum=10)  # 40 in stock
        body = store_client.get("/api/v1/products/?category=canola-oil").json()
        conforms(body, "PaginatedProductCardList")
        variant = body["results"][0]["variants"][0]
        assert (
            variant["min_qty_per_order"],
            variant["max_qty_per_order"],
            variant["orderable_quantity"],
            variant["stock_status"],
        ) == (5, 10, 10, "IN_STOCK")

    def test_detail_publishes_its_minimum(self, store_client, world, conforms):
        set_limits(world.canola_1l, minimum=2)
        body = store_client.get(f"/api/v1/products/{world.canola.slug}/").json()
        conforms(body, "ProductDetail")
        assert {v["id"]: v["min_qty_per_order"] for v in body["variants"]} == {
            world.canola_1l.pk: 2,
            world.canola_5l.pk: 1,
        }

    def test_fewer_free_units_than_the_minimum_is_out_of_stock(self, store_client, world):
        """2 in stock, minimum 3: orderable_quantity 0, OUT_OF_STOCK, no units_left (never
        looks buyable, exact stock not published)."""
        set_limits(world.canola_5l, minimum=3, maximum=3)
        body = store_client.get("/api/v1/products/?category=canola-oil").json()
        five_litre = next(
            v for v in body["results"][0]["variants"] if v["id"] == world.canola_5l.pk
        )
        assert (
            five_litre["stock_status"],
            five_litre["orderable_quantity"],
            five_litre["units_left"],
        ) == ("OUT_OF_STOCK", 0, None)

    def test_default_variant_skips_one_below_its_minimum(self, store_client, world):
        """The SQL "in stock" (default variant and in-stock-first sorting) uses the minimum:
        the 1 L (40 free, minimum 50) is not in stock, so the 5 L (2 free) is the default."""
        set_limits(world.canola_1l, minimum=50, maximum=60)
        card = store_client.get("/api/v1/products/?category=canola-oil").json()["results"][0]
        assert card["default_variant_id"] == world.canola_5l.pk
