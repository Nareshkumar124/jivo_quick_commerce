"""seed_demo's Phase 3 step: demo coupons, idempotent."""

import pytest
from django.core.management import call_command

from apps.promotions.models import Coupon
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db


def test_demo_coupons_and_d09_pricing():
    call_command("seed_demo")
    call_command("seed_demo")
    codes = set(Coupon.objects.values_list("code", flat=True))
    assert codes == {"JIVO50", "JIVO10", "OILS15", "WELCOME100", "JIVOSTAFF"}
    oils = Coupon.objects.get(code="OILS15")
    assert list(oils.categories.values_list("slug", flat=True)) == ["edible-oils"]
    assert Coupon.objects.get(code="WELCOME100").first_order_only is True
    assert Coupon.objects.get(code="JIVOSTAFF").is_visible is False
    pricing = PricingConfig.objects.get(store__code="GGN-01")
    assert (pricing.min_order_value, pricing.delivery_fee, pricing.cod_enabled) == (99, 25, True)
