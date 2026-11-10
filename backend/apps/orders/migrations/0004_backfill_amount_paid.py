"""Phase 4: `Order.amount_paid` for online orders already paid (before T8a existed, so their
grand_total is what was captured)."""

from django.db import migrations
from django.db.models import F

PAID_STATES = ("PAID", "REFUND_PENDING", "REFUNDED", "PARTIALLY_REFUNDED")


def backfill(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    Order.objects.filter(
        payment_method="ONLINE", placed_at__isnull=False, payment_status__in=PAID_STATES
    ).update(amount_paid=F("grand_total"))


class Migration(migrations.Migration):
    dependencies = [("orders", "0003_phase4_invoice_amount_paid")]

    operations = [migrations.RunPython(backfill, migrations.RunPython.noop)]
