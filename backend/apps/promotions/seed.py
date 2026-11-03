"""seed_demo step (idempotent): demo coupons for manual testing (Phase 3): a flat coupon, a
percent coupon with a cap, a category coupon and a first-order coupon, all visible, plus a hidden
code."""

from decimal import Decimal

from apps.catalog.models import Category
from apps.promotions.models import Coupon

DEMO_COUPONS = [
    {
        "code": "JIVO50",
        "title": "Flat ₹50 off",
        "description": "On orders of ₹299 or more.",
        "discount_type": "FLAT",
        "value": Decimal("50.00"),
        "min_order_value": Decimal("299.00"),
        "usage_limit_per_user": 3,
    },
    {
        "code": "JIVO10",
        "title": "10% off",
        "description": "On orders of ₹499 or more, up to ₹100.",
        "discount_type": "PERCENT",
        "value": Decimal("10.00"),
        "max_discount": Decimal("100.00"),
        "min_order_value": Decimal("499.00"),
        "usage_limit_per_user": 3,
    },
    {
        "code": "OILS15",
        "title": "15% off cooking oils",
        "description": "On edible oils, up to ₹150.",
        "discount_type": "PERCENT",
        "value": Decimal("15.00"),
        "max_discount": Decimal("150.00"),
        "min_order_value": Decimal("0.00"),
        "usage_limit_per_user": 3,
        "_categories": ["edible-oils"],
    },
    {
        "code": "WELCOME100",
        "title": "₹100 off your first order",
        "description": "On your first order of ₹399 or more.",
        "discount_type": "FLAT",
        "value": Decimal("100.00"),
        "min_order_value": Decimal("399.00"),
        "first_order_only": True,
        "usage_limit_per_user": 1,
    },
    {
        "code": "JIVOSTAFF",
        "title": "Staff ₹25 off",
        "description": "Hidden code for testing manual entry.",
        "discount_type": "FLAT",
        "value": Decimal("25.00"),
        "min_order_value": Decimal("0.00"),
        "is_visible": False,
        "usage_limit_per_user": None,
    },
]


def seed_coupons(stdout, options) -> None:
    for spec in DEMO_COUPONS:
        data = dict(spec)
        slugs = data.pop("_categories", [])
        code = data.pop("code")
        defaults = {"is_active": True, "is_visible": True, "first_order_only": False, **data}
        coupon, _ = Coupon.objects.update_or_create(code=code, defaults=defaults)
        if slugs:
            coupon.categories.set(Category.objects.filter(slug__in=slugs))
    stdout.write(f"  coupons: {', '.join(spec['code'] for spec in DEMO_COUPONS)}")
