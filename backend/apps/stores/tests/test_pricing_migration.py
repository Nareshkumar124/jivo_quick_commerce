"""Migration stores.0004 (Phase 3, PM default): pricing rows still at the old all-zero defaults
get the D-09 values; rows someone edited are left as they are."""

import importlib
from decimal import Decimal

import pytest
from django.apps import apps

from apps.stores.models import D09_PRICING, PricingConfig
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

ZEROS = {
    "min_order_value": 0,
    "delivery_fee": 0,
    "free_delivery_threshold": 0,
    "small_cart_fee": 0,
    "small_cart_threshold": 0,
    "handling_fee": 0,
    "cod_enabled": False,
    "cod_max_order_value": 0,
}
migration = importlib.import_module("apps.stores.migrations.0004_fill_d09_pricing")


def values(config: PricingConfig) -> dict:
    config.refresh_from_db()
    return {field: getattr(config, field) for field in D09_PRICING}


def test_fills_untouched_rows_only():
    untouched = PricingConfig.objects.create(store=DarkStoreFactory(), **ZEROS)
    edited = PricingConfig.objects.create(
        store=DarkStoreFactory(), **{**ZEROS, "delivery_fee": Decimal("10.00")}
    )
    cod_on = PricingConfig.objects.create(
        store=DarkStoreFactory(), **{**ZEROS, "cod_enabled": True}
    )
    migration.fill_untouched_rows(apps, None)
    assert values(untouched) == D09_PRICING
    assert values(edited)["delivery_fee"] == Decimal("10.00")
    assert values(edited)["min_order_value"] == Decimal("0.00")
    assert values(cod_on)["min_order_value"] == Decimal("0.00")


def test_new_rows_default_to_d09():
    assert values(PricingConfig.objects.create(store=DarkStoreFactory())) == D09_PRICING
