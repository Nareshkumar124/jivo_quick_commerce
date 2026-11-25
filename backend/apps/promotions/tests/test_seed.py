"""seed_demo's Phase 3 step: demo coupons, idempotent."""

import pytest
from django.core.management import call_command

from apps.promotions.models import Coupon
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db


def test_demo_coupons_and_d09_pricing():
    call_command("seed_demo")
    call_command("seed_demo")
    codes = set(Coupon.objects.filter(owner__isnull=True).values_list("code", flat=True))
    assert codes == {"JIVO50", "JIVO10", "OILS15", "WELCOME100", "JIVOSTAFF"}
    oils = Coupon.objects.get(code="OILS15")
    assert list(oils.categories.values_list("slug", flat=True)) == ["edible-oils"]
    assert Coupon.objects.get(code="WELCOME100").first_order_only is True
    assert Coupon.objects.get(code="JIVOSTAFF").is_visible is False
    pricing = PricingConfig.objects.get(store__code="GGN-01")
    assert (pricing.min_order_value, pricing.delivery_fee, pricing.cod_enabled) == (99, 25, True)
    assert pricing.free_unit_every == 10  # ADR-0002: the demo store shows the volume offer


def test_demo_welcome_reward_is_given_once():
    """ADR-0002: the test customer gets one welcome reward, however often seed_demo runs."""
    from apps.accounts.seed import TEST_CUSTOMER_PHONE
    from apps.promotions.choices import CouponSource

    call_command("seed_demo")
    call_command("seed_demo")
    rewards = Coupon.objects.filter(owner__phone=TEST_CUSTOMER_PHONE)
    assert list(rewards.values_list("source", "discount_type")) == [
        (CouponSource.WELCOME, "FREE_UNIT")
    ]


def test_an_offer_switched_off_is_switched_on_again():
    """The demo store's volume offer is on after seeding, also when it was off before."""
    call_command("seed_demo")
    PricingConfig.objects.filter(store__code="GGN-01").update(free_unit_every=0)
    call_command("seed_demo")
    assert PricingConfig.objects.get(store__code="GGN-01").free_unit_every == 10
