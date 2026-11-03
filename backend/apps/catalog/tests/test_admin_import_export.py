"""Catalog import/export through the admin (docs/admin-panel-architecture.md §10).

- Every import/export admin uses the project's formats (`apps.core.export_formats`: CSV and
  Excel with formula escaping); none falls back to django-import-export's stock CSV.
- Export escapes spreadsheet formulas (`= + - @`), keeps plain numbers, and the exported file
  imports back unchanged (the import removes exactly the added apostrophe).
- Upload limits (`ops_console.admin_support.LimitedImportForm`): 1 MB, 2000 rows, UTF-8 CSV or
  a readable .xlsx, refused before django-import-export stores or parses the file.
- The import/export and history screens use unfold's contrib templates.
"""

import csv
import io
import zipfile

import openpyxl
import pytest
from django.contrib import admin
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from import_export.admin import ImportMixin
from openpyxl.styles import Font

from apps.accounts import roles
from apps.catalog.admin.resources import CATEGORY_COLUMNS
from apps.catalog.models import Category, Product, ProductVariant
from apps.catalog.tests.factories import ProductFactory
from apps.core import export_formats
from apps.ops_console import admin_support
from apps.ops_console.admin_support import (
    MAX_UPLOAD_BYTES,
    MAX_UPLOAD_ROWS,
    MSG_EXCEL_AS_CSV,
    MSG_NOT_UTF8,
    MSG_NOT_XLSX,
    MSG_TOO_LARGE,
    MSG_XLSX_UNPACKED,
    MSG_XLSX_UNREADABLE,
    LimitedImportForm,
    check_import_upload,
    unescape_formula,
)
from apps.ops_console.tests.helpers import staff_in_role

pytestmark = pytest.mark.django_db

CSV_FORMAT = str(export_formats.FORMATS.index(export_formats.CSV))
XLSX_FORMAT = str(export_formats.FORMATS.index(export_formats.XLSX))
FORMULA_NAMES = ["=1+1", "+cmd", "@x", "-2+3"]
CATEGORY_HEADER = ",".join(CATEGORY_COLUMNS)


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def catalog_manager(client):
    client.force_login(staff_in_role(roles.CATALOG_MANAGER))
    return client


@pytest.fixture
def risky_products(world):
    """Products a spreadsheet would evaluate, and one with a negative number."""
    products = {name: ProductFactory(name=name, category=world.oils) for name in FORMULA_NAMES}
    negative = ProductFactory(name="Negative sort", category=world.oils, sort_order=-3)
    return products, negative


def export(client, model: str, fmt: str):
    return client.post(reverse(f"admin:catalog_{model}_export"), {"resource": "0", "format": fmt})


def csv_rows(response) -> dict[str, dict]:
    text = response.content.decode("utf-8-sig")
    return {row["slug"]: row for row in csv.DictReader(io.StringIO(text))}


def xlsx_rows(response) -> dict[str, dict]:
    sheet = openpyxl.load_workbook(io.BytesIO(response.content)).active
    rows = sheet.iter_rows()
    header = [cell.value for cell in next(rows)]
    by_slug = {}
    for row in rows:
        cells = dict(zip(header, row, strict=True))
        by_slug[cells["slug"].value] = cells
    return by_slug


def upload(name: str, content: bytes, content_type="text/csv") -> SimpleUploadedFile:
    return SimpleUploadedFile(name, content, content_type=content_type)


def xlsx_bytes(rows, *, styled_blank_rows: int = 0) -> bytes:
    workbook = openpyxl.Workbook()
    sheet = workbook.active
    for row in rows:
        sheet.append(row)
    for offset in range(styled_blank_rows):  # Excel keeps formatted empty rows
        sheet.cell(row=sheet.max_row + 1 + offset, column=1).font = Font(bold=True)
    buffer = io.BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def post_import(client, file, fmt=CSV_FORMAT, model="category"):
    return client.post(
        reverse(f"admin:catalog_{model}_import"),
        {"resource": "0", "format": fmt, "import_file": file},
    )


def import_errors(response) -> list[str]:
    return response.context["form"].errors.get("import_file", [])


# --------------------------------------------------------------------------- formats


def test_every_import_export_admin_uses_the_project_formats():
    """Guard: no admin overrides the formats back to django-import-export's stock CSV (which
    does not escape formulas), and every import is limited."""
    checked = 0
    for model_admin in admin.site._registry.values():
        if hasattr(model_admin, "get_export_formats"):
            assert model_admin.get_export_formats() == export_formats.FORMATS, model_admin
            checked += 1
        if isinstance(model_admin, ImportMixin):
            assert model_admin.get_import_formats() == export_formats.FORMATS, model_admin
            assert issubclass(model_admin.import_form_class, LimitedImportForm), model_admin
    assert checked >= 3  # categories, products, variants


class TestExportEscaping:
    def test_csv_cells_that_start_a_formula_are_escaped(self, catalog_manager, risky_products):
        products, negative = risky_products
        response = export(catalog_manager, "product", CSV_FORMAT)
        assert response.status_code == 200
        assert response["Content-Type"].startswith("text/csv")
        rows = csv_rows(response)
        for name, product in products.items():
            assert rows[product.slug]["name"] == f"'{name}"
        assert rows[negative.slug]["sort_order"] == "-3"  # a plain number is left alone

    def test_view_roles_get_the_escaped_file_too(self, client, risky_products):
        products, _negative = risky_products
        client.force_login(staff_in_role(roles.OPS))
        rows = csv_rows(export(client, "product", CSV_FORMAT))
        assert rows[products["=1+1"].slug]["name"] == "'=1+1"

    def test_xlsx_cells_are_text_never_formulas(self, catalog_manager, risky_products):
        products, _negative = risky_products
        response = export(catalog_manager, "product", XLSX_FORMAT)
        assert response.status_code == 200
        rows = xlsx_rows(response)
        for name, product in products.items():
            cell = rows[product.slug]["name"]
            assert cell.data_type == "s"
            assert cell.value == f"'{name}"

    @pytest.mark.xfail(
        strict=True,
        reason=(
            "Backend gap: django-import-export's ExportMixin.get_export_data() sends native "
            "types only when `type(file_format) in BINARY_FORMATS`, an exact-type test that the "
            "project's XLSX subclass (apps.core.export_formats.XLSX) fails, so admin Excel "
            "exports write numbers as text. Remove this marker once fixed."
        ),
    )
    def test_xlsx_numbers_stay_numbers(self, catalog_manager, risky_products):
        _products, negative = risky_products
        rows = xlsx_rows(export(catalog_manager, "product", XLSX_FORMAT))
        cell = rows[negative.slug]["sort_order"]
        assert cell.data_type == "n"
        assert cell.value == -3

    def test_exported_csv_imports_back_unchanged(self, catalog_manager, risky_products):
        """§10's workflow (export, fix a cell, import again) must not store the apostrophes
        the export added."""
        products, _negative = risky_products
        product = products["=1+1"]
        product.short_description = "+ Cold pressed"
        product.description = "- Cold pressed\n\n- Rich in omega-3"
        product.attributes = {"importer": "", "ingredients": "=canola"}  # as seed_demo stores
        product.save()
        exported = export(catalog_manager, "product", CSV_FORMAT).content
        response = post_import(catalog_manager, upload("products.csv", exported), model="product")
        result = response.context["result"]
        assert not result.has_errors()
        assert not result.has_validation_errors()
        assert result.totals["skip"] == Product.objects.count()
        assert result.totals["update"] == result.totals["new"] == 0

    @pytest.mark.parametrize("model", ["category", "product", "productvariant"])
    def test_exported_xlsx_imports_back_unchanged(self, catalog_manager, risky_products, model):
        """The same round trip in Excel: values come back as Excel gives them (empty cells as
        None, numbers as numbers or text) and every row is unchanged."""
        products, _negative = risky_products
        product = products["=1+1"]
        product.description = "- Cold pressed\n\n- Rich in omega-3"
        product.save()
        exported = export(catalog_manager, model, XLSX_FORMAT).content
        response = post_import(
            catalog_manager,
            upload(f"{model}.xlsx", exported, content_type="application/octet-stream"),
            fmt=XLSX_FORMAT,
            model=model,
        )
        result = response.context["result"]
        assert not result.has_errors(), [
            (n, [e.error for e in errs]) for n, errs in result.row_errors()
        ]
        assert not result.has_validation_errors(), [
            (row.number, row.error.message_dict) for row in result.invalid_rows
        ]
        model_class = {"category": Category, "product": Product, "productvariant": ProductVariant}
        assert result.totals["skip"] == model_class[model].objects.count()
        assert result.totals["update"] == result.totals["new"] == 0

    def test_an_edited_escaped_cell_is_stored_without_the_apostrophe(self, catalog_manager):
        content = f"{CATEGORY_HEADER}\nnew-cat,'=Odd name,,1,1\nquoted,'Quoted',,2,1\n"
        response = post_import(catalog_manager, upload("categories.csv", content.encode()))
        confirm = response.context["confirm_form"]
        catalog_manager.post(
            reverse("admin:catalog_category_process_import"),
            {name: confirm[name].value() for name in confirm.fields},
        )
        assert Category.objects.get(slug="new-cat").name == "=Odd name"
        assert Category.objects.get(slug="quoted").name == "'Quoted'"  # not an escape


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("'=1+1", "=1+1"),
        ("'+cmd", "+cmd"),
        ("'@x", "@x"),
        ("'-2+3", "-2+3"),
        ("'\t=1", "\t=1"),
        ("'-3", "'-3"),  # the export never escapes a number
        ("'Quoted'", "'Quoted'"),
        ("plain", "plain"),
        (None, None),
        (7, 7),
    ],
)
def test_unescape_is_the_inverse_of_the_export_escape(value, expected):
    assert unescape_formula(value) == expected
    if isinstance(expected, str):
        assert unescape_formula(export_formats.escape_formula(expected)) == expected


# --------------------------------------------------------------------------- upload limits


@pytest.fixture
def nothing_is_stored(monkeypatch):
    """A refused file never reaches django-import-export's temporary storage (Redis)."""

    def refuse(*args, **kwargs):
        raise AssertionError("a refused upload was written to the import storage")

    monkeypatch.setattr(ImportMixin, "write_to_tmp_storage", refuse)


@pytest.mark.usefixtures("nothing_is_stored")
class TestRefusedUploads:
    def test_file_over_1_mb(self, catalog_manager):
        content = f"{CATEGORY_HEADER}\n".encode() + b"x" * MAX_UPLOAD_BYTES
        response = post_import(catalog_manager, upload("big.csv", content))
        assert response.status_code == 200
        assert import_errors(response) == [MSG_TOO_LARGE]
        assert response.context.get("confirm_form") is None

    def test_csv_over_2000_rows(self, catalog_manager):
        lines = [f"cat-{n},Cat {n},,{n},1" for n in range(MAX_UPLOAD_ROWS + 1)]
        content = "\n".join([CATEGORY_HEADER, *lines]).encode()
        response = post_import(catalog_manager, upload("many.csv", content))
        assert import_errors(response) == [
            f"The file has more than {MAX_UPLOAD_ROWS} rows; split it into several files."
        ]
        assert not Category.objects.filter(slug__startswith="cat-").exists()

    def test_csv_that_is_not_utf8(self, catalog_manager):
        content = f"{CATEGORY_HEADER}\ncafe,Café,,1,1\n".encode("latin-1")
        response = post_import(catalog_manager, upload("latin1.csv", content))
        assert import_errors(response) == [MSG_NOT_UTF8]

    def test_excel_file_sent_as_csv(self, catalog_manager):
        content = xlsx_bytes([list(CATEGORY_COLUMNS), ["xl", "XL", None, 1, 1]])
        response = post_import(catalog_manager, upload("cats.xlsx", content))
        assert import_errors(response) == [MSG_EXCEL_AS_CSV]

    def test_csv_file_sent_as_excel(self, catalog_manager):
        content = f"{CATEGORY_HEADER}\nx,X,,1,1\n".encode()
        response = post_import(catalog_manager, upload("cats.csv", content), fmt=XLSX_FORMAT)
        assert import_errors(response) == [MSG_NOT_XLSX]

    def test_xlsx_over_2000_rows(self, catalog_manager):
        rows = [[f"cat-{n}", f"Cat {n}", None, n, 1] for n in range(MAX_UPLOAD_ROWS + 1)]
        content = xlsx_bytes([list(CATEGORY_COLUMNS), *rows])
        response = post_import(catalog_manager, upload("many.xlsx", content), fmt=XLSX_FORMAT)
        assert import_errors(response) == [
            f"The file has more than {MAX_UPLOAD_ROWS} rows; split it into several files."
        ]

    def test_xlsx_that_unpacks_to_too_much(self, catalog_manager):
        """A small file that expands enormously (zip bomb) is refused before it is parsed."""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(
                "xl/worksheets/sheet1.xml", b"0" * (admin_support.MAX_XLSX_UNPACKED_BYTES + 1)
            )
        content = buffer.getvalue()
        assert len(content) < MAX_UPLOAD_BYTES
        response = post_import(catalog_manager, upload("bomb.xlsx", content), fmt=XLSX_FORMAT)
        assert import_errors(response) == [MSG_XLSX_UNPACKED]

    def test_zip_that_is_not_a_workbook(self, catalog_manager):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("hello.txt", "not a workbook")
        response = post_import(
            catalog_manager, upload("fake.xlsx", buffer.getvalue()), fmt=XLSX_FORMAT
        )
        assert import_errors(response) == [MSG_XLSX_UNREADABLE]


class TestAcceptedUploads:
    def test_xlsx_import_previews_then_saves(self, catalog_manager):
        """Excel works end to end (preview, confirm); formatted empty rows are ignored and an
        escaped cell is stored without its apostrophe."""
        content = xlsx_bytes(
            [
                list(CATEGORY_COLUMNS),
                ["xl-oils", "'+ Excel oils", None, 4, 1],
                ["xl-seeds", "Excel seeds", None, 5, 0],
            ],
            styled_blank_rows=3,
        )
        response = post_import(catalog_manager, upload("cats.xlsx", content), fmt=XLSX_FORMAT)
        assert response.status_code == 200
        result = response.context["result"]
        assert not result.has_errors()
        assert not result.has_validation_errors()
        assert result.totals["new"] == 2
        assert not Category.objects.filter(slug__startswith="xl-").exists()  # dry run
        confirm = response.context["confirm_form"]
        response = catalog_manager.post(
            reverse("admin:catalog_category_process_import"),
            {name: confirm[name].value() for name in confirm.fields},
        )
        assert response.status_code == 302
        oils = Category.objects.get(slug="xl-oils")
        assert (oils.name, oils.sort_order, oils.is_active) == ("+ Excel oils", 4, True)
        assert Category.objects.get(slug="xl-seeds").is_active is False

    def test_exactly_2000_rows_pass_the_limit(self):
        lines = [f"cat-{n},Cat {n},,{n},1" for n in range(MAX_UPLOAD_ROWS)]
        content = "\n".join([CATEGORY_HEADER, *lines]).encode()
        check_import_upload(upload("max.csv", content), export_formats.CSV())

    def test_records_are_counted_not_lines(self):
        """Descriptions hold quoted paragraphs: a record with line breaks is one row."""
        record = 'p-{n},"First paragraph\n\nSecond paragraph"'
        content = "\n".join(["slug,description", *(record.format(n=n) for n in range(3))])
        check_import_upload(upload("p.csv", content.encode()), export_formats.CSV(), max_rows=3)
        with pytest.raises(Exception, match="more than 2 rows"):
            check_import_upload(upload("p.csv", content.encode()), export_formats.CSV(), max_rows=2)

    def test_utf8_with_bom_and_the_file_position_is_kept(self):
        file = upload("bom.csv", f"{CATEGORY_HEADER}\nx,Café,,1,1\n".encode("utf-8-sig"))
        check_import_upload(file, export_formats.CSV())
        assert file.tell() == 0  # django-import-export reads it next


# --------------------------------------------------------------------------- unfold templates


def template_origins(response) -> set[str]:
    return {template.origin.name for template in response.templates if template.origin}


def test_import_export_screens_use_unfold_templates(catalog_manager):
    changelist = catalog_manager.get(reverse("admin:catalog_product_changelist"))
    origins = template_origins(changelist)
    for item in ("change_list_import_item.html", "change_list_export_item.html"):
        assert any(
            name.endswith(f"unfold/contrib/import_export/templates/admin/import_export/{item}")
            for name in origins
        ), item
    for url_name in ("admin:catalog_product_import", "admin:catalog_product_export"):
        response = catalog_manager.get(reverse(url_name))
        assert response.status_code == 200
        assert any(
            "unfold/contrib/import_export/templates" in name for name in template_origins(response)
        ), url_name


def test_history_screens_use_unfold_templates_and_never_offer_revert(client, world):
    from apps.accounts.tests.factories import SuperUserFactory

    client.force_login(SuperUserFactory())
    variant = world.canola_1l
    history = client.get(reverse("admin:catalog_productvariant_history", args=[variant.pk]))
    assert history.status_code == 200
    assert any(
        "unfold/contrib/simple_history/templates" in name for name in template_origins(history)
    )
    version = variant.history.earliest().history_id
    page = client.get(
        reverse("admin:catalog_productvariant_simple_history", args=[variant.pk, version])
    )
    assert page.status_code == 200
    assert any("unfold/contrib/simple_history/templates" in n for n in template_origins(page))
    html = page.content.decode()
    assert ">Revert<" not in html.replace(" ", "").replace("\n", "")
    assert "revert to this version" not in html
