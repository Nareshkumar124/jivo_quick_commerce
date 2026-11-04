"""Phase 3 (PM default, awaiting confirmation): pricing rows still at the old all-zero defaults
get the D-09 values. Rows anyone has edited (any non-zero amount, or COD switched on) are left
as they are. Values are copied here, not imported, so the migration never changes later."""

from decimal import Decimal

from django.db import migrations

ZERO = Decimal("0.00")
MONEY_FIELDS = (
    "min_order_value",
    "delivery_fee",
    "free_delivery_threshold",
    "small_cart_fee",
    "small_cart_threshold",
    "handling_fee",
    "cod_max_order_value",
)
D09 = {
    "min_order_value": Decimal("99.00"),
    "delivery_fee": Decimal("25.00"),
    "free_delivery_threshold": Decimal("299.00"),
    "small_cart_fee": Decimal("15.00"),
    "small_cart_threshold": Decimal("149.00"),
    "handling_fee": Decimal("0.00"),
    "cod_enabled": True,
    "cod_max_order_value": Decimal("2000.00"),
}


def fill_untouched_rows(apps, schema_editor):
    PricingConfig = apps.get_model("stores", "PricingConfig")
    untouched = PricingConfig.objects.filter(cod_enabled=False, **dict.fromkeys(MONEY_FIELDS, ZERO))
    untouched.update(**D09)


class Migration(migrations.Migration):
    dependencies = [("stores", "0003_pricingconfig_d09_defaults")]

    operations = [migrations.RunPython(fill_untouched_rows, migrations.RunPython.noop)]
