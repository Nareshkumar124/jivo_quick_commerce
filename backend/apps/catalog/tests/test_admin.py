"""Catalog admin (05 §2 "Categories", "Products & variants", "Collections", "Banners"; 05 §3:
Super Admin and Catalog Manager edit; Ops, Store Manager, Store Staff and Support view).

Covers the role matrix, the CSV import/export permissions (import needs add + change), the import
dry run and the column format (docs/admin-panel-architecture.md §10), the product label form,
the 100-item collection cap and list query counts. Uses the backend's `world` catalog fixture.
"""

from decimal import Decimal

import pytest
import tablib
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection
from django.test import Client
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory
from apps.catalog.admin.resources import (
    CATEGORY_COLUMNS,
    PRODUCT_COLUMNS,
    VARIANT_COLUMNS,
    CategoryResource,
    ProductResource,
    ProductVariantResource,
)
from apps.catalog.models import (
    MAX_COLLECTION_ITEMS,
    Banner,
    Category,
    Collection,
    CollectionItem,
    Product,
    ProductVariant,
)
from apps.catalog.tests.factories import ProductFactory, VariantFactory, image_upload
from apps.ops_console.tests.helpers import (
    CATALOG_EDIT_ROLES,
    CATALOG_VIEW_ROLES,
    PRINCIPALS,
    admin_form_data,
    expected_status,
    login_as,
    staff_in_role,
)

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


# --------------------------------------------------------------------------- role matrix

MODELS = ("category", "product", "productvariant", "collection", "banner", "trendingsearch")
PAGES = {
    **{f"admin:catalog_{model}_changelist": CATALOG_VIEW_ROLES for model in MODELS},
    **{f"admin:catalog_{model}_add": CATALOG_EDIT_ROLES for model in MODELS},
    **{f"admin:catalog_{model}_import": CATALOG_EDIT_ROLES for model in MODELS[:3]},
    **{f"admin:catalog_{model}_export": CATALOG_VIEW_ROLES for model in MODELS[:3]},
}


@pytest.mark.parametrize("url_name", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, principal, url_name):
    login_as(client, principal)
    response = client.get(reverse(url_name))
    expected = expected_status(principal, PAGES[url_name])
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_product_detail_matrix(client, world, principal):
    login_as(client, principal)
    response = client.get(reverse("admin:catalog_product_change", args=[world.canola.pk]))
    assert response.status_code == expected_status(principal, CATALOG_VIEW_ROLES)
    if response.status_code == 200:
        editable = 'name="gst_rate"' in response.content.decode()
        assert editable is (principal in CATALOG_EDIT_ROLES)


@pytest.mark.parametrize("role", [roles.OPS, roles.STORE_MANAGER, roles.STORE_STAFF, roles.SUPPORT])
def test_view_roles_cannot_change_prices(client, world, role):
    client.force_login(staff_in_role(role))
    url = reverse("admin:catalog_productvariant_change", args=[world.canola_1l.pk])
    response = client.post(url, {"selling_price": "1.00", "_save": "Save"})
    assert response.status_code == 403
    world.canola_1l.refresh_from_db()
    assert world.canola_1l.selling_price != Decimal("1.00")


# --------------------------------------------------------------------------- import / export


def csv_file(text: str) -> SimpleUploadedFile:
    return SimpleUploadedFile("import.csv", text.encode("utf-8"), content_type="text/csv")


VARIANT_HEADER = ",".join(VARIANT_COLUMNS)


class TestImportPermissions:
    @pytest.mark.parametrize("role", [roles.STORE_STAFF, roles.OPS, roles.SUPPORT])
    def test_view_roles_cannot_import(self, client, world, role):
        client.force_login(staff_in_role(role))
        row = "JV-NEW-1,jivo-cold-pressed-canola-oil,2 L,2 L,2000,ml,599.00,499.00,5,,,,1,0"
        response = client.post(
            reverse("admin:catalog_productvariant_import"),
            {"resource": "0", "format": "0", "import_file": csv_file(f"{VARIANT_HEADER}\n{row}")},
        )
        assert response.status_code == 403
        process = client.post(
            reverse("admin:catalog_productvariant_process_import"),
            {"import_file_name": "x", "original_file_name": "x.csv", "format": "0"},
        )
        assert process.status_code == 403
        assert not ProductVariant.objects.filter(sku="JV-NEW-1").exists()

    def test_view_roles_see_no_import_button(self, client):
        client.force_login(staff_in_role(roles.OPS))
        html = client.get(reverse("admin:catalog_product_changelist")).content.decode()
        assert reverse("admin:catalog_product_import") not in html
        assert reverse("admin:catalog_product_export") in html

    def test_import_post_needs_the_csrf_token(self, world):
        client = Client(enforce_csrf_checks=True)
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        response = client.post(
            reverse("admin:catalog_category_import"),
            {"resource": "0", "format": "0", "import_file": csv_file("slug,name\nx-cat,X")},
        )
        assert response.status_code == 403
        assert not Category.objects.filter(slug="x-cat").exists()


class TestImportFlow:
    def test_admin_preview_is_a_dry_run_then_confirm_imports(self, client, world):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        rows = [
            "JV-NEW-1,jivo-cold-pressed-canola-oil,2 L,2 L,2000,ml,599.00,499.00,5,,,,1,9",
            "JV-NEW-2,jivo-cold-pressed-canola-oil,500 ml,500 ml,500,ml,199.00,179.00,5,,,,1,10",
        ]
        response = client.post(
            reverse("admin:catalog_productvariant_import"),
            {
                "resource": "0",
                "format": "0",
                "import_file": csv_file("\n".join([VARIANT_HEADER, *rows])),
            },
        )
        assert response.status_code == 200
        result = response.context["result"]
        assert not result.has_errors()
        assert not result.has_validation_errors()
        assert result.totals["new"] == 2
        assert not ProductVariant.objects.filter(sku__startswith="JV-NEW").exists()  # dry run

        confirm = response.context["confirm_form"]
        response = client.post(
            reverse("admin:catalog_productvariant_process_import"),
            {name: confirm[name].value() for name in confirm.fields},
        )
        assert response.status_code == 302
        created = ProductVariant.objects.get(sku="JV-NEW-1")
        assert created.sap_item_code is None
        assert created.history.exists()  # price history from the first save

    def test_errors_are_reported_and_nothing_is_saved(self, client, world):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        rows = [
            "JV-BAD-1,no-such-product,1 L,1 L,1000,ml,100.00,90.00,5,,,,1,0",
            "JV-BAD-2,jivo-cold-pressed-canola-oil,1 L,1 L,1000,ml,100.00,150.00,5,,,,1,0",
        ]
        response = client.post(
            reverse("admin:catalog_productvariant_import"),
            {
                "resource": "0",
                "format": "0",
                "import_file": csv_file("\n".join([VARIANT_HEADER, *rows])),
            },
        )
        html = response.content.decode()
        assert response.status_code == 200
        assert "No product with slug &#x27;no-such-product&#x27;." in html
        assert "Cannot be above the MRP." in html
        assert "confirm_form" not in response.context or response.context["confirm_form"] is None
        assert not ProductVariant.objects.filter(sku__startswith="JV-BAD").exists()


def dataset(columns, *rows) -> tablib.Dataset:
    data = tablib.Dataset(headers=list(columns))
    for row in rows:
        data.append(row)
    return data


class TestResources:
    def test_export_columns_are_the_documented_format(self, world):
        assert CategoryResource().export().headers == list(CATEGORY_COLUMNS)
        assert ProductResource().export().headers == list(PRODUCT_COLUMNS)
        assert ProductVariantResource().export().headers == list(VARIANT_COLUMNS)

    def test_variant_dry_run_keeps_empty_sap_codes_null(self, world):
        base = ["jivo-cold-pressed-canola-oil", "2 L", "2 L", "2000", "ml", "599.00", "499.00"]
        data = dataset(
            VARIANT_COLUMNS,
            ["JV-A", *base, "5", "", "", "", "1", "0"],
            ["JV-B", *base, "5", "", "", "", "1", "1"],
        )
        result = ProductVariantResource().import_data(data, dry_run=True)
        assert not result.has_errors(), result.row_errors()
        assert not result.has_validation_errors(), [r.error_dict for r in result.invalid_rows]
        assert result.totals["new"] == 2
        assert not ProductVariant.objects.filter(sku__in=["JV-A", "JV-B"]).exists()

    def test_variant_import_updates_by_sku(self, world):
        sku = world.canola_1l.sku
        row = [
            sku, "jivo-cold-pressed-canola-oil", "1 L", "1 L", "1000", "ml",
            "349.00", "289.00", "4", "8901234567890", "SAP-CAN-1L", "920", "1", "0",
        ]  # fmt: skip
        result = ProductVariantResource().import_data(dataset(VARIANT_COLUMNS, row))
        assert not result.has_errors()
        assert not result.has_validation_errors()
        world.canola_1l.refresh_from_db()
        assert world.canola_1l.selling_price == Decimal("289.00")
        assert world.canola_1l.sap_item_code == "SAP-CAN-1L"
        assert world.canola_1l.max_qty_per_order == 4

    def test_strict_booleans(self, world):
        base = ["jivo-cold-pressed-canola-oil", "2 L", "2 L", "", "", "599.00", "499.00", "5"]
        data = dataset(VARIANT_COLUMNS, ["JV-C", *base, "", "", "", "yes", "0"])
        result = ProductVariantResource().import_data(data, dry_run=True)
        messages = str([row.error_dict for row in result.invalid_rows])
        assert "Use 1 (yes) or 0 (no)." in messages

    def test_categories_stay_two_levels(self, world):
        data = dataset(
            CATEGORY_COLUMNS,
            ["too-deep", "Too deep", world.canola_cat.slug, "0", "1"],
        )
        result = CategoryResource().import_data(data, dry_run=True)
        assert result.has_validation_errors()
        assert "two levels only" in str(result.invalid_rows[0].error_dict)

    def test_category_parent_in_the_same_file(self, world):
        data = dataset(
            CATEGORY_COLUMNS,
            ["ghee", "Ghee", "", "5", "1"],
            ["cow-ghee", "Cow ghee", "ghee", "1", "1"],
        )
        result = CategoryResource().import_data(data)
        assert not result.has_errors()
        assert not result.has_validation_errors()
        assert Category.objects.get(slug="cow-ghee").parent.slug == "ghee"

    def test_product_label_columns_build_the_attributes(self, world):
        nutrition = (
            '{"columns": ["Per 100 ml"], "rows": [{"name": "Energy", '
            '"values": ["900 kcal"], "is_sub_row": false}]}'
        )
        values = {
            "slug": "jivo-ghee-1l",
            "name": "Jivo Ghee",
            "category_slug": world.oils.slug,
            "brand": "Jivo",
            "short_description": "",
            "description": "",
            "highlights": "Pure | Rich aroma",
            "is_veg": "1",
            "hsn_code": "0405",
            "gst_rate": "12.00",
            "search_keywords": "ghee",
            "is_active": "1",
            "sort_order": "3",
            "ingredients": "Milk fat",
            "shelf_life": "9 months",
            "storage_instructions": "",
            "country_of_origin": "India",
            "manufacturer": "",
            "marketer": "",
            "importer": "",
            "consumer_care": "",
            "fssai_license_no": "10012345678901",
            "nutrition": nutrition,
        }
        data = dataset(PRODUCT_COLUMNS, [values[column] for column in PRODUCT_COLUMNS])
        result = ProductResource().import_data(data)
        assert not result.has_errors()
        assert not result.has_validation_errors(), [row.error_dict for row in result.invalid_rows]
        product = Product.objects.get(slug="jivo-ghee-1l")
        assert product.highlights == ["Pure", "Rich aroma"]
        assert product.attributes["ingredients"] == "Milk fat"
        assert product.attributes["nutrition"]["rows"][0]["name"] == "Energy"
        assert "storage_instructions" not in product.attributes  # empty cell: not set
        exported = ProductResource().export(queryset=Product.objects.filter(pk=product.pk)).dict[0]
        assert exported["highlights"] == "Pure | Rich aroma"
        assert exported["fssai_license_no"] == "10012345678901"

    def test_reimport_changing_only_a_label_column_is_saved(self, world):
        """The catalog-data workflow: export, fix one label cell, import again. The changed
        label must not be skipped as "unchanged"."""
        queryset = Product.objects.filter(pk=world.canola.pk)
        exported = ProductResource().export(queryset=queryset)
        row = exported.dict[0]
        row["shelf_life"] = "18 months"
        data = dataset(PRODUCT_COLUMNS, [row[column] for column in PRODUCT_COLUMNS])
        result = ProductResource().import_data(data)
        assert not result.has_errors()
        assert not result.has_validation_errors(), [r.error_dict for r in result.invalid_rows]
        assert result.totals["update"] == 1
        world.canola.refresh_from_db()
        assert world.canola.attributes["shelf_life"] == "18 months"
        assert world.canola.attributes["ingredients"] == "Cold pressed canola oil (100%)."

    def test_reimport_of_an_unchanged_export_is_skipped(self, world):
        exported = ProductResource().export(queryset=Product.objects.filter(pk=world.canola.pk))
        result = ProductResource().import_data(exported)
        assert result.totals["skip"] == 1

    def test_product_with_bad_label_data_is_refused(self, world):
        row = dict.fromkeys(PRODUCT_COLUMNS, "")
        row.update(
            {
                "slug": "bad-label",
                "name": "Bad",
                "category_slug": world.oils.slug,
                "gst_rate": "5.00",
                "fssai_license_no": "123",
                "nutrition": "{not json",
            }
        )
        data = dataset(PRODUCT_COLUMNS, [row[column] for column in PRODUCT_COLUMNS])
        result = ProductResource().import_data(data, dry_run=True)
        assert result.has_validation_errors()
        assert "nutrition is not valid JSON." in str(result.invalid_rows[0].error_dict)


# --------------------------------------------------------------------------- product form


class TestProductForm:
    def test_label_fields_are_saved_into_attributes(self, client, world):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        url = reverse("admin:catalog_product_change", args=[world.canola.pk])
        data = admin_form_data(client.get(url))
        data.update(
            {
                "highlights_text": "Rich in omega-3\nCold pressed",
                "shelf_life": "12 months",
                "fssai_license_no": "10012345678901",
            }
        )
        response = client.post(url, data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        world.canola.refresh_from_db()
        assert world.canola.highlights == ["Rich in omega-3", "Cold pressed"]
        assert world.canola.attributes["shelf_life"] == "12 months"
        assert world.canola.attributes["ingredients"] == "Cold pressed canola oil (100%)."

    def test_invalid_fssai_number_is_shown_on_its_field(self, client, world):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        url = reverse("admin:catalog_product_change", args=[world.canola.pk])
        data = admin_form_data(client.get(url))
        data["fssai_license_no"] = "12AB"
        response = client.post(url, data)
        assert response.status_code == 200
        form = response.context["adminform"].form
        assert "fssai_license_no must be 14 digits." in form.errors["fssai_license_no"]

    def test_view_roles_read_the_label_information(self, client, world):
        client.force_login(staff_in_role(roles.SUPPORT))
        html = client.get(
            reverse("admin:catalog_product_change", args=[world.canola.pk])
        ).content.decode()
        assert "Cold pressed canola oil (100%)." in html
        assert 'name="ingredients"' not in html


# --------------------------------------------------------------------------- collections, banners


class TestCollectionCap:
    def collection_with(self, count: int) -> Collection:
        collection = Collection.objects.create(name="Big", slug="big")
        product = ProductFactory()
        CollectionItem.objects.bulk_create(
            CollectionItem(
                collection=collection, variant=VariantFactory(product=product), sort_order=i
            )
            for i in range(count)
        )
        return collection

    def post_new_items(self, client, collection, new: int):
        url = reverse("admin:catalog_collection_change", args=[collection.pk])
        data = admin_form_data(client.get(url))
        prefix = "items"
        start = int(data[f"{prefix}-TOTAL_FORMS"])
        for index in range(start, start + new):
            data[f"{prefix}-{index}-variant"] = str(VariantFactory().pk)
            data[f"{prefix}-{index}-sort_order"] = str(index)
            data[f"{prefix}-{index}-collection"] = str(collection.pk)
        data[f"{prefix}-TOTAL_FORMS"] = str(start + new)
        return client.post(url, data)

    def test_adding_past_the_cap_in_one_save_is_refused(self, client):
        collection = self.collection_with(MAX_COLLECTION_ITEMS - 1)
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        response = self.post_new_items(client, collection, 2)
        assert response.status_code == 200
        assert f"at most {MAX_COLLECTION_ITEMS} items" in response.content.decode()
        assert collection.items.count() == MAX_COLLECTION_ITEMS - 1

    def test_filling_up_to_the_cap_is_fine(self, client):
        collection = self.collection_with(MAX_COLLECTION_ITEMS - 1)
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        response = self.post_new_items(client, collection, 1)
        assert response.status_code == 302
        assert collection.items.count() == MAX_COLLECTION_ITEMS


class TestBanners:
    def test_state_badges(self, client, world):
        client.force_login(staff_in_role(roles.OPS))
        html = client.get(reverse("admin:catalog_banner_changelist")).content.decode()
        assert "Live" in html

    def test_link_rules_come_from_the_model(self, client):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        url = reverse("admin:catalog_banner_add")
        data = admin_form_data(client.get(url))
        data.update(
            {
                "title": "Diwali",
                "image": image_upload(1080, 480),
                "link_type": "url",
                "link_value": "http://jivo.in",
                "sort_order": "0",
                "is_active": "on",
            }
        )
        response = client.post(url, data)
        assert response.status_code == 200
        assert "Enter an https:// URL." in response.content.decode()
        assert not Banner.objects.filter(title="Diwali").exists()

    def test_time_zone_is_named_on_the_form(self, client):
        client.force_login(SuperUserFactory())
        html = client.get(reverse("admin:catalog_banner_add")).content.decode()
        assert "Time zone: UTC." in html or "Time zone: Asia/Kolkata." in html


# --------------------------------------------------------------------------- query counts


def _queries(client, url) -> int:
    with CaptureQueriesContext(connection) as queries:
        assert client.get(url).status_code == 200
    return len(queries)


@pytest.mark.parametrize(
    "url_name",
    [
        "admin:catalog_product_changelist",
        "admin:catalog_productvariant_changelist",
        "admin:catalog_category_changelist",
        "admin:catalog_collection_changelist",
        "admin:catalog_banner_changelist",
    ],
)
def test_list_queries_do_not_grow(client, world, url_name):
    client.force_login(staff_in_role(roles.CATALOG_MANAGER))
    url = reverse(url_name)
    few = _queries(client, url)
    for index in range(10):
        product = ProductFactory(category=world.canola_cat)
        VariantFactory(product=product)
        Collection.objects.create(name=f"C{index}", slug=f"c-{index}")
    assert _queries(client, url) == few
