"""seed_demo step (idempotent): the demo dark store GGN-01 in Gurugram with a real service area,
opening hours 07:00-23:00 IST every day, pricing config (zeros until D-09) and store access for
the seeded Store Manager and Store Staff."""

from datetime import time

from django.contrib.gis.geos import MultiPolygon, Point, Polygon

from apps.accounts.models import User
from apps.stores.models import DarkStore, PricingConfig, StoreTiming
from apps.stores.services import grant_store_access

DEMO_STORE_CODE = "GGN-01"
# Sector 14 area, Gurugram. The polygon covers roughly Sectors 4-17, 21-23 and DLF Phase I-II
# west of the Sushant Lok line (a point like 28.4646, 77.0864 is outside).
STORE_LOCATION = Point(77.0440, 28.4710, srid=4326)
SERVICE_AREA = MultiPolygon(
    Polygon(
        (
            (77.000, 28.430),
            (77.075, 28.430),
            (77.080, 28.470),
            (77.060, 28.500),
            (77.000, 28.495),
            (77.000, 28.430),
        )
    ),
    srid=4326,
)
SCOPED_STAFF = ("store.manager@jivo.test", "store.staff@jivo.test")


def seed_stores(stdout, options) -> None:
    store, created = DarkStore.objects.update_or_create(
        code=DEMO_STORE_CODE,
        defaults={
            "name": "Jivo Sector 14, Gurugram",
            "address": "Plot 21, Old Delhi-Gurgaon Road, Sector 14",
            "city": "Gurugram",
            "state": "Haryana",
            "pincode": "122001",
            "location": STORE_LOCATION,
            "service_area": SERVICE_AREA,
            "avg_prep_minutes": 8,
            "phone": "+911244000014",
            "gstin": "06AAACJ1234F1Z5",
            "fssai_license_no": "10020064000123",
            "invoice_prefix": "GGN01",
            "priority": 10,
        },
    )
    for weekday in range(7):
        StoreTiming.objects.update_or_create(
            store=store, weekday=weekday, defaults={"opens_at": time(7), "closes_at": time(23)}
        )
    PricingConfig.objects.get_or_create(store=store)
    for email in SCOPED_STAFF:
        user = User.objects.filter(email=email).first()
        if user is not None:
            grant_store_access(user, store)
    stdout.write(f"  store {store.code} ({'created' if created else 'updated'}), open 07-23 IST")
