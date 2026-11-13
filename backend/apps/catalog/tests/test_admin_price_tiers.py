"""Admin: slab prices are checked against the MRP saved on the same page (review of
backend/water-slabs; the model's own check needs a saved variant)."""

from decimal import Decimal

import pytest
from django.forms.models import inlineformset_factory

from apps.catalog.admin import VariantPriceTierFormSet
from apps.catalog.models import ProductVariant, VariantPriceTier

TierFormSet = inlineformset_factory(
    ProductVariant,
    VariantPriceTier,
    formset=VariantPriceTierFormSet,
    fk_name="variant",
    fields=("min_order_units", "price"),
    extra=0,
)


def _data(*rows):
    data = {
        "price_tiers-TOTAL_FORMS": str(len(rows)),
        "price_tiers-INITIAL_FORMS": "0",
        "price_tiers-MIN_NUM_FORMS": "0",
        "price_tiers-MAX_NUM_FORMS": "1000",
    }
    for i, (units, price) in enumerate(rows):
        data[f"price_tiers-{i}-min_order_units"] = str(units)
        data[f"price_tiers-{i}-price"] = price
    return data


@pytest.mark.django_db
def test_a_slab_price_above_the_new_mrp_is_refused():
    """A new variant (unsaved) with MRP 90 can't get a slab at 95."""
    formset = TierFormSet(
        _data((25, "87.00"), (50, "95.00")), instance=ProductVariant(mrp=Decimal("90"))
    )
    assert not formset.is_valid()
    assert "can't be above the MRP" in formset.non_form_errors()[0]


@pytest.mark.django_db
def test_slab_prices_at_or_below_the_mrp_are_accepted():
    formset = TierFormSet(
        _data((5, "90.00"), (25, "87.00")), instance=ProductVariant(mrp=Decimal("90"))
    )
    assert formset.is_valid(), formset.errors
