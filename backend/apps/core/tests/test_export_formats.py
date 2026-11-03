"""Admin import/export formats (05 §2): CSV and Excel only, with formula-injection escaping,
plus the import preview storage that works across processes and the pytest traceback setting
that keeps DB credentials out of test output."""

import csv
import io
import tomllib
from pathlib import Path

import openpyxl
import pytest
import tablib
from django.conf import settings

from apps.core import export_formats
from apps.core.export_formats import escape_formula

LINK = '=HYPERLINK("http://evil.example")'
DANGEROUS = [LINK, "==1+1", "+cmd|' /C calc'!A0", "-2+3", "@SUM(1)", "\t=1", "\r=1"]
HARMLESS = ["Jivo Canola Oil", "-3", "+919876543210", "12.50", "", "a=b"]


@pytest.mark.parametrize("value", DANGEROUS)
def test_formula_cells_are_escaped(value):
    assert escape_formula(value) == f"'{value}"


@pytest.mark.parametrize("value", [*HARMLESS, None, 7, -3])
def test_harmless_cells_are_unchanged(value):
    assert escape_formula(value) == value


def _dataset():
    data = tablib.Dataset(headers=["name", "qty", "note"])
    data.append([LINK, -3, None])
    data.append(["Canola", 5, "@SUM(1)"])
    return data


def test_csv_export_never_writes_a_formula():
    out = export_formats.CSV().export_data(_dataset())
    rows = list(csv.reader(io.StringIO(out)))
    assert rows[1] == [f"'{LINK}", "-3", ""]
    assert rows[2] == ["Canola", "5", "'@SUM(1)"]


def test_xlsx_export_stores_text_not_formulas():
    content = export_formats.XLSX().export_data(_dataset())
    sheet = openpyxl.load_workbook(io.BytesIO(content)).active
    assert sheet["A2"].data_type == "s"
    assert sheet["A2"].value == f"'{LINK}"
    assert sheet["B2"].value == -3  # numbers keep their type
    assert sheet["C2"].value is None  # not the text "None"


def test_settings():
    assert settings.IMPORT_EXPORT_ESCAPE_FORMULAE_ON_EXPORT is True
    assert settings.IMPORT_EXPORT_FORMATS == [export_formats.CSV, export_formats.XLSX]
    assert settings.IMPORT_EXPORT_TMP_STORAGE_CLASS == "import_export.tmp_storages.CacheStorage"
    apps = settings.INSTALLED_APPS
    assert apps.index("unfold.contrib.import_export") < apps.index("django.contrib.admin")
    assert apps.index("unfold.contrib.simple_history") < apps.index("django.contrib.admin")


def test_import_preview_survives_another_process():
    """CacheStorage keeps the uploaded file in Redis, so the confirm request may land on any
    web process or container."""
    from django.core.cache import cache
    from import_export.tmp_storages import CacheStorage

    content = b"sku,quantity\nJV-CAN-1L,4\n"
    storage = CacheStorage()
    storage.save(content)
    other_process = CacheStorage(name=storage.name)
    assert other_process.read() == content
    other_process.remove()
    assert cache.get(CacheStorage.CACHE_PREFIX + storage.name) is None


def test_pytest_tracebacks_are_short():
    """Long tracebacks print function arguments (a DB conninfo with its password)."""
    config = tomllib.loads((Path(settings.BASE_DIR) / "pyproject.toml").read_text())
    options = config["tool"]["pytest"]["ini_options"]["addopts"].split()
    assert "--tb=short" in options
    assert "--showlocals" not in options
    assert "-l" not in options
