"""ADR-0002 §1: `manage.py set_flat_rates` gives Jivo Water one flat rate per carton (MRP =
selling price = the rate) and removes the variants' volume price tiers. Dry run by default;
--commit saves; idempotent; any error saves nothing."""

import json
from decimal import Decimal as D
from io import StringIO
from pathlib import Path

import pytest
from django.conf import settings
from django.core.management import call_command
from django.core.management.base import CommandError

from apps.catalog.flat_rates import read_rates
from apps.catalog.models import VariantPriceTier
from apps.catalog.tests.factories import VariantFactory
from apps.inventory.models import StoreInventory
from apps.inventory.tests.factories import stock
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

WATER_FILE = Path(settings.BASE_DIR) / "apps" / "catalog" / "data" / "jivo_water_flat_rates.json"
SLABS = [(5, "90.00"), (25, "87.00"), (50, "85.00"), (100, "82.00"), (250, "80.00")]


def run(path, *flags) -> str:
    out = StringIO()
    call_command("set_flat_rates", "--file", str(path), *flags, stdout=out)
    return out.getvalue()


@pytest.fixture
def water():
    """The three Jivo Water cartons as ADR 0001 left them: slab prices, MRP = the 5+ rate."""
    variants = {}
    for sku, base in (("JVW-WTR-1L-12", "90.00"), ("JVW-WTR-250ML-24", "90.00"),
                      ("JVW-WTR-500ML-24", "125.00")):  # fmt: skip
        variant = VariantFactory(sku=sku, mrp=D(base), selling_price=D(base))
        for units, price in SLABS:
            VariantPriceTier.objects.create(
                variant=variant, min_order_units=units, price=min(D(price), D(base))
            )
        variants[sku] = variant
    return variants


def prices(variant) -> tuple:
    variant.refresh_from_db()
    return variant.mrp, variant.selling_price, variant.price_tiers.count()


def test_shipped_file_has_the_users_rates():
    """1 L ₹110, 250 ml ₹110, 500 ml ₹140 (user, 2026-11-25), on the ADR 0001 SKUs."""
    plans, errors = read_rates(WATER_FILE)
    assert errors == []
    assert {plan.sku: plan.mrp for plan in plans} == {
        "JVW-WTR-1L-12": D("110.00"),
        "JVW-WTR-250ML-24": D("110.00"),
        "JVW-WTR-500ML-24": D("140.00"),
    }
    assert all(plan.mrp == plan.selling_price and plan.tiers == [] for plan in plans)


def test_dry_run_changes_nothing(water):
    output = run(WATER_FILE)
    assert "mrp 90.00 -> 110.00, selling_price 90.00 -> 110.00" in output
    assert "removed 5" in output
    assert "Dry run" in output
    for variant in water.values():
        assert prices(variant)[2] == 5
    assert prices(water["JVW-WTR-500ML-24"])[:2] == (D("125.00"), D("125.00"))


def test_commit_sets_flat_rates_and_removes_tiers_idempotently(water):
    run(WATER_FILE, "--commit", "--yes")
    assert prices(water["JVW-WTR-1L-12"]) == (D("110.00"), D("110.00"), 0)
    assert prices(water["JVW-WTR-250ML-24"]) == (D("110.00"), D("110.00"), 0)
    assert prices(water["JVW-WTR-500ML-24"]) == (D("140.00"), D("140.00"), 0)
    again = run(WATER_FILE, "--commit", "--yes")
    assert again.count("prices unchanged") == 3
    assert "removed 0" in again


def test_store_overrides_are_reported_not_changed(water):
    store = DarkStoreFactory(code="GGN-01")
    row = stock(store, water["JVW-WTR-1L-12"], 10)
    StoreInventory.objects.filter(pk=row.pk).update(price_override=D("100.00"))
    output = run(WATER_FILE, "--commit", "--yes")
    assert "JVW-WTR-1L-12 has a price override of 100.00 at store GGN-01" in output
    row.refresh_from_db()
    assert row.price_override == D("100.00")


def test_any_error_saves_nothing(tmp_path, water):
    path = tmp_path / "rates.json"
    path.write_text(
        json.dumps(
            {"variants": [{"sku": "JVW-WTR-1L-12", "rate": "110.00"}, {"sku": "NOPE", "rate": "1"}]}
        ),
        encoding="utf-8",
    )
    with pytest.raises(CommandError):
        run(path, "--commit", "--yes")
    assert prices(water["JVW-WTR-1L-12"]) == (D("90.00"), D("90.00"), 5)


@pytest.mark.parametrize(
    ("content", "error"),
    [
        ({"variants": []}, 'non-empty "variants"'),
        ({"variants": [{"rate": "1"}]}, "sku is required"),
        ({"variants": [{"sku": "A"}]}, "rate is required"),
        ({"variants": [{"sku": "A", "rate": "0"}]}, "must be above 0"),
        ({"variants": [{"sku": "A", "rate": "1"}, {"sku": "A", "rate": "2"}]}, "listed twice"),
    ],
)
def test_file_errors(tmp_path, content, error):
    path = tmp_path / "rates.json"
    path.write_text(json.dumps(content), encoding="utf-8")
    _plans, errors = read_rates(path)
    assert any(error in message for message in errors), errors


def test_missing_and_unreadable_files(tmp_path):
    with pytest.raises(CommandError, match="File not found"):
        run(tmp_path / "missing.json")
    bad = tmp_path / "bad.json"
    bad.write_text("{", encoding="utf-8")
    assert read_rates(bad)[1][0].startswith("Cannot read")
    with pytest.raises(CommandError):
        run(bad, "--commit", "--yes")
