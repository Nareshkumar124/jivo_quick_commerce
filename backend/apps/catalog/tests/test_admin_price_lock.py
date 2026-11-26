"""ADR 0004 (user, 2026-11-26): only a Super Admin changes prices (`catalog.manage_prices`).

In the Django admin, without that permission:
- a saved variant's MRP and selling price are read-only (variant page) or disabled (the product
  page's variant rows), and a forged POST leaves them as they are;
- volume price tiers cannot be added, changed or removed;
- a CSV import that would change a saved variant's price is refused with a plain message.
A new variant still takes its first price (it is on sale nowhere until a store has stock).
"""

from decimal import Decimal

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse

from apps.accounts import roles
from apps.catalog.admin import MSG_PRICE_LOCKED
from apps.catalog.admin.resources import MSG_IMPORT_PRICE_LOCKED, VARIANT_COLUMNS
from apps.catalog.models import ProductVariant, VariantPriceTier
from apps.ops_console.tests.helpers import (
    CATALOG_EDIT_ROLES,
    PRICE_EDIT_ROLES,
    SUPERUSER,
    admin_form_data,
    login_as,
)

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


PRICE_INPUTS = ('name="mrp"', 'name="selling_price"')


def variant_url(variant) -> str:
    return reverse("admin:catalog_productvariant_change", args=[variant.pk])


@pytest.mark.parametrize("principal", sorted(CATALOG_EDIT_ROLES))
def test_variant_page_prices_only_for_super_admin(client, world, principal):
    login_as(client, principal)
    page = client.get(variant_url(world.canola_1l)).content.decode()
    editable = principal in PRICE_EDIT_ROLES
    for name in PRICE_INPUTS:
        assert (name in page) is editable, (principal, name)
    assert (MSG_PRICE_LOCKED in page) is not editable
    assert 'name="sku"' in page  # the rest of the variant stays editable


def test_catalog_manager_forged_price_post_changes_nothing(client, world):
    login_as(client, roles.CATALOG_MANAGER)
    url = variant_url(world.canola_1l)
    data = admin_form_data(client.get(url))
    data.update({"mrp": "1.00", "selling_price": "1.00", "barcode": "8900000000001"})
    response = client.post(url, data)
    assert response.status_code == 302, response.content.decode()[:2000]
    variant = ProductVariant.objects.get(pk=world.canola_1l.pk)
    assert variant.barcode == "8900000000001"  # the allowed change is saved
    assert (variant.mrp, variant.selling_price) == (
        world.canola_1l.mrp,
        world.canola_1l.selling_price,
    )


@pytest.mark.parametrize("principal", [roles.SUPER_ADMIN, SUPERUSER])
def test_super_admin_changes_the_price(client, world, principal):
    login_as(client, principal)
    url = variant_url(world.canola_1l)
    data = admin_form_data(client.get(url))
    data.update({"mrp": "399.00", "selling_price": "399.00"})
    response = client.post(url, data)
    assert response.status_code == 302, response.content.decode()[:2000]
    variant = ProductVariant.objects.get(pk=world.canola_1l.pk)
    assert (variant.mrp, variant.selling_price) == (Decimal("399.00"), Decimal("399.00"))


def test_product_page_variant_rows_keep_their_price(client, world):
    login_as(client, roles.CATALOG_MANAGER)
    url = reverse("admin:catalog_product_change", args=[world.canola.pk])
    response = client.get(url)
    page = response.content.decode()
    assert MSG_PRICE_LOCKED in page
    data = admin_form_data(response)
    forged = {key: "1.00" for key in data if key.endswith(("-mrp", "-selling_price"))}
    assert forged  # the variant rows are on the page
    data.update(forged)
    response = client.post(url, data)
    assert response.status_code == 302, response.content.decode()[:2000]
    for variant in (world.canola_1l, world.canola_5l):
        saved = ProductVariant.objects.get(pk=variant.pk)
        assert (saved.mrp, saved.selling_price) == (variant.mrp, variant.selling_price)


def test_price_tiers_are_view_only_without_the_price_permission(client, world):
    VariantPriceTier.objects.create(
        variant=world.canola_1l, min_order_units=10, price=Decimal("250.00")
    )
    url = variant_url(world.canola_1l)
    login_as(client, roles.SUPER_ADMIN)
    page = client.get(url).content.decode()
    assert 'name="price_tiers-0-price"' in page  # Super Admin edits tiers

    client.logout()
    login_as(client, roles.CATALOG_MANAGER)
    data = admin_form_data(client.get(url))
    data.update(
        {
            "price_tiers-TOTAL_FORMS": "2",
            "price_tiers-INITIAL_FORMS": "1",
            "price_tiers-0-id": str(world.canola_1l.price_tiers.get().pk),
            "price_tiers-0-variant": str(world.canola_1l.pk),
            "price_tiers-0-min_order_units": "10",
            "price_tiers-0-price": "1.00",
            "price_tiers-0-DELETE": "",
            "price_tiers-1-variant": str(world.canola_1l.pk),
            "price_tiers-1-min_order_units": "20",
            "price_tiers-1-price": "2.00",
        }
    )
    response = client.post(url, data)
    assert response.status_code == 302, response.content.decode()[:2000]
    tiers = list(world.canola_1l.price_tiers.values_list("min_order_units", "price"))
    assert tiers == [(10, Decimal("250.00"))]


# --------------------------------------------------------------------------- CSV import


def import_csv(client, *rows):
    header = ",".join(VARIANT_COLUMNS)
    upload = SimpleUploadedFile(
        "variants.csv", "\n".join([header, *rows]).encode("utf-8"), content_type="text/csv"
    )
    return client.post(
        reverse("admin:catalog_productvariant_import"),
        {"resource": "0", "format": "0", "import_file": upload},
    )


def canola_row(mrp: str, price: str, sku: str = "JV-CAN-1L") -> str:
    return f"{sku},jivo-cold-pressed-canola-oil,1 L,1 L,1000,ml,{mrp},{price},5,,,,1,1"


def test_catalog_manager_import_cannot_change_a_saved_price(client, world):
    login_as(client, roles.CATALOG_MANAGER)
    response = import_csv(client, canola_row("399.00", "399.00"))
    assert response.status_code == 200
    result = response.context["result"]
    assert result.has_validation_errors()
    assert MSG_IMPORT_PRICE_LOCKED in str([row.error_dict for row in result.invalid_rows])
    assert response.context.get("confirm_form") is None
    world.canola_1l.refresh_from_db()
    assert world.canola_1l.mrp != Decimal("399.00")

    # The same price again, or a new size with its first price, is fine.
    same = canola_row(f"{world.canola_1l.mrp:.2f}", f"{world.canola_1l.selling_price:.2f}")
    response = import_csv(client, same, canola_row("199.00", "199.00", sku="JV-CAN-NEW"))
    result = response.context["result"]
    assert not result.has_errors()
    assert not result.has_validation_errors(), [r.error_dict for r in result.invalid_rows]


def test_super_admin_import_changes_a_saved_price(client, world):
    login_as(client, roles.SUPER_ADMIN)
    response = import_csv(client, canola_row("399.00", "399.00"))
    result = response.context["result"]
    assert not result.has_errors()
    assert not result.has_validation_errors(), [r.error_dict for r in result.invalid_rows]
    assert result.totals["update"] == 1
