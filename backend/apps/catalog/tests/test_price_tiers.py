"""Volume (slab) price tiers in the catalog (ADR 0001): the `VariantPriceTier` rules, the rate
chart in the catalog API (`price_tiers`), and `manage.py set_price_tiers` (dry run by default,
idempotent, all-or-nothing), including the shipped Jivo Water file."""

import json
from decimal import Decimal
from pathlib import Path

import pytest
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import IntegrityError, transaction

from apps.catalog.models import ProductVariant, VariantPriceTier
from apps.catalog.price_tiers import read_plan
from apps.catalog.tests.factories import VariantFactory

pytestmark = pytest.mark.django_db

D = Decimal
WATER_FILE = Path(__file__).resolve().parents[1] / "data" / "jivo_water_price_tiers.json"


class TestModel:
    @pytest.mark.parametrize(
        ("units", "price"), [(0, "80.00"), (5, "0.00")], ids=["units-0", "price-0"]
    )
    def test_db_constraints(self, units, price):
        """min_order_units >= 1 and price > 0 are DB check constraints."""
        variant = VariantFactory()
        with transaction.atomic(), pytest.raises(IntegrityError):
            VariantPriceTier.objects.create(variant=variant, min_order_units=units, price=D(price))

    def test_one_price_per_units(self):
        variant = VariantFactory()
        VariantPriceTier.objects.create(variant=variant, min_order_units=5, price=D("90.00"))
        with transaction.atomic(), pytest.raises(IntegrityError):
            VariantPriceTier.objects.create(variant=variant, min_order_units=5, price=D("80.00"))

    def test_price_cannot_be_above_the_mrp(self):
        variant = VariantFactory(mrp=D("90.00"), selling_price=D("90.00"))
        tier = VariantPriceTier(variant=variant, min_order_units=5, price=D("95.00"))
        with pytest.raises(ValidationError) as caught:
            tier.full_clean()
        assert caught.value.message_dict == {"price": ["Cannot be above the MRP."]}

    def test_mrp_cannot_drop_below_a_tier(self):
        """Lowering the MRP under a tier price is refused (like a store override above MRP)."""
        variant = VariantFactory(mrp=D("125.00"), selling_price=D("120.00"))
        VariantPriceTier.objects.create(variant=variant, min_order_units=25, price=D("122.00"))
        variant.mrp, variant.selling_price = D("100.00"), D("100.00")
        with pytest.raises(ValidationError) as caught:
            variant.clean()
        assert "Price tiers from 25 units are above the new MRP" in caught.value.messages[0]


class TestCatalogApi:
    def test_rate_chart_on_cards_and_detail(self, store_client, world, conforms):
        """`price_tiers` lists a variant's tiers, lowest first; [] for a variant without."""
        VariantPriceTier.objects.create(variant=world.canola_1l, min_order_units=10, price=D("260"))
        VariantPriceTier.objects.create(variant=world.canola_1l, min_order_units=5, price=D("270"))
        cache.clear()
        cards = store_client.get("/api/v1/products/?category=canola-oil").json()
        conforms(cards, "PaginatedProductCardList")
        chart = {v["id"]: v["price_tiers"] for v in cards["results"][0]["variants"]}
        assert chart == {
            world.canola_1l.pk: [
                {"min_order_units": 5, "price": "270.00"},
                {"min_order_units": 10, "price": "260.00"},
            ],
            world.canola_5l.pk: [],
        }
        detail = store_client.get(f"/api/v1/products/{world.canola.slug}/").json()
        conforms(detail, "ProductDetail")
        assert detail["variants"][0]["price_tiers"] == chart[world.canola_1l.pk]


def write(tmp_path, variants) -> Path:
    path = tmp_path / "tiers.json"
    path.write_text(json.dumps({"variants": variants}), encoding="utf-8")
    return path


def run(path, *flags) -> str:
    from io import StringIO

    out = StringIO()
    call_command("set_price_tiers", "--file", str(path), *flags, stdout=out)
    return out.getvalue()


class TestSetPriceTiersCommand:
    @pytest.fixture
    def variant(self):
        variant = VariantFactory(sku="JVW-TEST-1L", mrp=D("120.00"), selling_price=D("100.00"))
        VariantPriceTier.objects.create(variant=variant, min_order_units=3, price=D("99.00"))
        return variant

    @pytest.fixture
    def plan_file(self, tmp_path, variant):
        return write(
            tmp_path,
            [
                {
                    "sku": variant.sku,
                    "mrp": "90.00",
                    "selling_price": "90.00",
                    "tiers": [
                        {"min_order_units": 25, "price": "87.00"},
                        {"min_order_units": 5, "price": "90.00"},
                    ],
                }
            ],
        )

    def tiers(self, variant) -> list:
        return list(variant.price_tiers.values_list("min_order_units", "price"))

    def test_dry_run_changes_nothing(self, plan_file, variant):
        output = run(plan_file)
        assert "mrp 120.00 -> 90.00, selling_price 100.00 -> 90.00" in output
        assert "Dry run" in output
        variant.refresh_from_db()
        assert (variant.mrp, variant.selling_price) == (D("120.00"), D("100.00"))
        assert self.tiers(variant) == [(3, D("99.00"))]

    def test_commit_sets_prices_and_exactly_the_listed_tiers_idempotently(self, plan_file, variant):
        run(plan_file, "--commit", "--yes")
        variant.refresh_from_db()
        assert (variant.mrp, variant.selling_price) == (D("90.00"), D("90.00"))
        assert self.tiers(variant) == [(5, D("90.00")), (25, D("87.00"))]  # the 3+ tier removed
        again = run(plan_file, "--commit", "--yes")
        assert "prices unchanged" in again
        assert "created 0, updated 0, removed 0, unchanged 2" in again

    def test_any_error_saves_nothing(self, tmp_path, variant):
        """The first entry is valid and applied, the second fails: the run is rolled back."""
        path = write(
            tmp_path,
            [
                {"sku": variant.sku, "tiers": [{"min_order_units": 5, "price": "95.00"}]},
                {"sku": "NO-SUCH-SKU", "tiers": []},
            ],
        )
        with pytest.raises(CommandError):
            run(path, "--commit", "--yes")
        assert self.tiers(variant) == [(3, D("99.00"))]

    def test_tier_above_the_new_mrp_is_refused(self, tmp_path, variant):
        path = write(
            tmp_path,
            [{"sku": variant.sku, "mrp": "90.00", "selling_price": "90.00",
              "tiers": [{"min_order_units": 5, "price": "95.00"}]}],
        )  # fmt: skip
        with pytest.raises(CommandError):
            run(path, "--commit", "--yes")
        variant.refresh_from_db()
        assert variant.mrp == D("120.00")

    def test_shipped_water_file_is_valid(self):
        """The staging file: three box sizes, five slabs each, MRP = selling = the 5+ price."""
        plans, errors = read_plan(WATER_FILE)
        assert errors == []
        assert [p.sku for p in plans] == ["JVW-WTR-1L-12", "JVW-WTR-500ML-24", "JVW-WTR-250ML-24"]
        for plan in plans:
            assert [t.min_order_units for t in plan.tiers] == [5, 25, 50, 100, 250]
            assert plan.mrp == plan.selling_price == plan.tiers[0].price
        assert [t.price for t in plans[1].tiers] == [D(p) for p in (125, 122, 120, 117, 115)]

    def test_variant_rows_are_untouched_by_a_tiers_only_entry(self, tmp_path, variant):
        path = write(tmp_path, [{"sku": variant.sku, "tiers": []}])
        run(path, "--commit", "--yes")
        assert ProductVariant.objects.get(pk=variant.pk).selling_price == D("100.00")
        assert self.tiers(variant) == []


@pytest.mark.parametrize(
    ("content", "error"),
    [
        ("not json", "Cannot read"),
        ('{"variants": []}', 'non-empty "variants" list'),
        ('{"variants": [{"tiers": []}]}', "sku is required"),
        ('{"variants": [{"sku": "A", "tiers": []}, {"sku": "A", "tiers": []}]}', "listed twice"),
        ('{"variants": [{"sku": "A", "mrp": "abc", "tiers": []}]}', "is not an amount"),
        ('{"variants": [{"sku": "A", "selling_price": "1.234", "tiers": []}]}', "2 decimals"),
        ('{"variants": [{"sku": "A"}]}', '"tiers" must be a list'),
        ('{"variants": [{"sku": "A", "tiers": [{"min_order_units": 0, "price": "1"}]}]}', ">= 1"),
        (
            '{"variants": [{"sku": "A", "tiers": [{"min_order_units": true, "price": "1"}]}]}',
            ">= 1",
        ),
        (
            '{"variants": [{"sku": "A", "tiers": [{"min_order_units": 5, "price": "1"}, '
            '{"min_order_units": 5, "price": "2"}]}]}',
            "listed twice",
        ),
        (
            '{"variants": [{"sku": "A", "tiers": [{"min_order_units": 5, "price": "0"}]}]}',
            "above 0",
        ),
    ],
)
def test_file_errors_are_reported(tmp_path, content, error):
    """The file is checked before any database work; each problem is named."""
    path = tmp_path / "tiers.json"
    path.write_text(content, encoding="utf-8")
    _plans, errors = read_plan(path)
    assert any(error in message for message in errors), errors


def test_command_refuses_a_missing_file_and_a_bad_file(tmp_path):
    with pytest.raises(CommandError, match="File not found"):
        run(tmp_path / "missing.json")
    bad = tmp_path / "bad.json"
    bad.write_text('{"variants": []}', encoding="utf-8")
    with pytest.raises(CommandError, match="nothing was saved"):
        run(bad)


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/products/?category=edible-oils",
        "/api/v1/products/jivo-cold-pressed-canola-oil/",
        "/api/v1/home/",
    ],
)
def test_tiers_add_no_queries_per_variant(store_client, world, django_assert_max_num_queries, path):
    """09 §1: the tier prefetch is one query per variant list, never one per variant: list,
    detail and home cost the same once every variant has two tiers (cold catalog cache)."""
    from unittest import mock

    from apps.catalog.tests.test_api import _bypass_cache
    from apps.cms.services import get_app_config

    get_app_config()  # the app-guard middleware's config read is cached separately
    variants = (world.canola_1l, world.canola_5l, world.olive_1l, world.mustard_1l, world.juice_500)
    with mock.patch("apps.catalog.views.cached", side_effect=_bypass_cache):
        store_client.get(path)  # warm the store snapshot (cached separately)
        with django_assert_max_num_queries(50) as captured:
            assert store_client.get(path).status_code == 200
        without_tiers = len(captured)  # a number now: the next request resets the query log
        assert without_tiers > 0
        for variant in variants:
            VariantPriceTier.objects.create(
                variant=variant, min_order_units=5, price=variant.selling_price
            )
            VariantPriceTier.objects.create(
                variant=variant, min_order_units=25, price=variant.selling_price - 1
            )
        with django_assert_max_num_queries(without_tiers):
            body = store_client.get(path).json()
    assert '"price_tiers": [{"min_order_units": 5' in json.dumps(body)
