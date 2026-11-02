from datetime import time

import factory
from django.contrib.gis.geos import MultiPolygon, Point, Polygon

from apps.stores.models import DarkStore, StoreTiming

# A 0.1 x 0.1 degree square around (28.45, 77.05) in Gurugram (about 11 x 10 km).
SQUARE = (77.00, 28.40, 77.10, 28.50)


def square_area(bbox=SQUARE) -> MultiPolygon:
    return MultiPolygon(Polygon.from_bbox(bbox), srid=4326)


class DarkStoreFactory(factory.django.DjangoModelFactory):
    """An active store accepting orders, open all week (00:00-23:59) unless `timings=False`."""

    class Meta:
        model = DarkStore
        skip_postgeneration_save = True

    code = factory.Sequence(lambda n: f"TST-{n:03d}")
    name = factory.Sequence(lambda n: f"Jivo Test Store {n}")
    address = "Plot 7, Sector 14"
    city = "Gurugram"
    state = "Haryana"
    pincode = "122001"
    location = factory.LazyFunction(lambda: Point(77.05, 28.45, srid=4326))
    service_area = factory.LazyFunction(square_area)
    invoice_prefix = factory.Sequence(lambda n: f"TS{n:04d}")

    @factory.post_generation
    def timings(self, create, extracted, **kwargs):
        if not create or extracted is False:
            return
        for weekday in range(7):
            StoreTiming.objects.create(
                store=self, weekday=weekday, opens_at=time(0, 0), closes_at=time(23, 59)
            )
