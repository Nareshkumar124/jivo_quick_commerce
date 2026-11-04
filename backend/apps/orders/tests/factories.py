"""A minimal valid order (consistent bill, per the database constraints). Order placement
arrives in Phase 3 R2b; until then tests build orders directly."""

from decimal import Decimal

import factory
from django.contrib.gis.geos import Point
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.orders.choices import OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.models import Order
from apps.stores.tests.factories import DarkStoreFactory

SNAPSHOT = {
    "label": "home",
    "custom_label": "",
    "receiver_name": "Asha Verma",
    "receiver_phone": "+919876543210",
    "house": "Flat 402",
    "building_street": "Sunshine Apartments",
    "landmark": "",
    "area": "Sector 14",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.45,
    "lng": 77.05,
}


class OrderFactory(factory.django.DjangoModelFactory):
    """A COD order for ₹300 of items: PLACED unless `status`/`placed_at` say otherwise."""

    class Meta:
        model = Order

    order_number = factory.Sequence(lambda n: f"JV-261103-{n:06d}")
    user = factory.SubFactory(UserFactory)
    store = factory.SubFactory(DarkStoreFactory)
    address_snapshot = factory.LazyFunction(lambda: dict(SNAPSHOT))
    delivery_location = factory.LazyFunction(lambda: Point(77.05, 28.45, srid=4326))
    status = OrderStatus.PLACED
    payment_method = PaymentMethod.COD
    payment_status = PaymentStatus.COD_PENDING
    mrp_total = Decimal("350.00")
    item_total = Decimal("300.00")
    product_discount = Decimal("50.00")
    grand_total = Decimal("300.00")
    idempotency_key = factory.Sequence(lambda n: f"test-key-{n:08d}")
    placed_at = factory.LazyFunction(timezone.now)
