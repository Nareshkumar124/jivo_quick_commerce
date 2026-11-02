"""Backfill `Address.location` from the `lat`/`lng` decimals (Phase 2, backward compatible).

The decimals stay (and keep being written) until a later migration switches reads to `location`
and drops them. Reverse is a no-op: 0003's reverse removes the column.
"""

from django.contrib.gis.geos import Point
from django.db import migrations

BATCH = 500


def backfill(apps, schema_editor):
    Address = apps.get_model("accounts", "Address")
    pending = Address.objects.filter(location__isnull=True).order_by("pk")
    while True:
        batch = list(pending[:BATCH])
        if not batch:
            break
        for address in batch:
            address.location = Point(float(address.lng), float(address.lat), srid=4326)
        Address.objects.bulk_update(batch, ["location"])


class Migration(migrations.Migration):
    dependencies = [("accounts", "0003_address_location")]

    operations = [migrations.RunPython(backfill, migrations.RunPython.noop, elidable=True)]
