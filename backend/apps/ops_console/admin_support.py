"""Shared admin building blocks (docs/admin-panel-architecture.md §4, §5).

- `add_service_errors()`: show a backend service's `ValidationError` (field -> message dict, see
  `apps.inventory.services`) on a form instead of a 500, mapping service argument names to form
  fields.
- `dry_run()`: run a service inside a transaction that is always rolled back, so a form can be
  validated by the service itself (one source of rules) before the real call. `on_commit`
  callbacks registered inside it (alerts, cache bumps) are discarded with the rollback.
- `ReadOnlyHistoryAdmin`: django-simple-history's history pages, read-only and scoped.
  Stock vanilla `SimpleHistoryAdmin` (a) falls back to the historical record when the object is
  outside `get_queryset()`, which would show another store's history, and (b) accepts a POST on
  the version page that saves the old version through `save_model` ("revert") even when revert
  is disabled in the template. Panel changes go through services, so history is view-only.
- `ImportExportPermissionsMixin`: django-import-export lets any staff user import when the
  `IMPORT_EXPORT_IMPORT_PERMISSION_CODE` setting is absent. Import needs add and change on the
  model; export needs view.
- `LimitedImportForm` / `check_import_upload()`: upload limits for admin imports (size, rows,
  UTF-8, readable Excel), checked when the form validates, i.e. before django-import-export
  keeps the file in its temporary storage (Redis) or parses it.
- `SpreadsheetImportMixin`: makes an Excel file read like the equivalent CSV (empty cells are
  empty text, empty rows are dropped) and undoes the export's formula escaping
  (`apps.core.export_formats`), so an exported file imports back unchanged.
"""

import csv
import io
import zipfile
from collections.abc import Callable, Mapping
from typing import Any

from django.contrib.admin.utils import unquote
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.shortcuts import get_object_or_404
from simple_history.admin import SimpleHistoryAdmin
from unfold.contrib.import_export.forms import ImportForm

from apps.core.export_formats import escape_formula

# Upload limits for every admin file import (catalog import, stock inward CSV).
MAX_UPLOAD_BYTES = 1_000_000
MAX_UPLOAD_ROWS = 2000
# An .xlsx file is a zip archive: refuse one whose parts unpack to more than this (a small file
# that expands to gigabytes, "zip bomb"). Real 2000-row catalog sheets unpack to well under 5 MB.
MAX_XLSX_UNPACKED_BYTES = 20_000_000

MSG_TOO_LARGE = "The file is larger than 1 MB; split it into several files."
MSG_NOT_UTF8 = (
    "The file is not UTF-8 text. In Excel use Save as > CSV UTF-8 (Comma delimited), or "
    "choose the xlsx format and upload the Excel file itself."
)
MSG_EXCEL_AS_CSV = (
    "This is an Excel file: choose the xlsx format, or save it as CSV UTF-8 and upload that."
)
MSG_NOT_XLSX = (
    "This is not an Excel (.xlsx) file. Choose the format that matches the file: CSV for a .csv "
    "file, xlsx for an Excel workbook (old .xls files: save them as .xlsx first)."
)
MSG_XLSX_UNREADABLE = "This Excel file could not be read. Save it again as .xlsx and retry."
MSG_XLSX_UNPACKED = "This Excel file is too large once unpacked; split it into several files."
MSG_CSV_UNREADABLE = "This CSV file could not be read: {error}."
MSG_FORMAT = "Files of this format cannot be imported here."


def _too_many_rows(max_rows: int) -> ValidationError:
    return ValidationError(
        f"The file has more than {max_rows} rows; split it into several files.",
        code="too_many_rows",
    )


def _filled(values) -> bool:
    return any(value is not None and str(value).strip() for value in values)


def _csv_data_rows(data: bytes) -> int:
    """Records (not lines: quoted cells may hold line breaks) after the header row."""
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        if data.startswith(b"PK\x03\x04"):
            raise ValidationError(MSG_EXCEL_AS_CSV, code="excel_as_csv") from None
        raise ValidationError(MSG_NOT_UTF8, code="encoding") from None
    try:
        records = sum(1 for row in csv.reader(io.StringIO(text)) if _filled(row))
    except csv.Error as error:
        raise ValidationError(MSG_CSV_UNREADABLE.format(error=error), code="csv") from None
    return max(records - 1, 0)


def _xlsx_data_rows(data: bytes, max_rows: int) -> int:
    """Filled rows after the header on the first (active) sheet, as django-import-export reads
    it. Stops counting once past `max_rows`."""
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            unpacked = sum(info.file_size for info in archive.infolist())
    except zipfile.BadZipFile:
        raise ValidationError(MSG_NOT_XLSX, code="not_xlsx") from None
    if unpacked > MAX_XLSX_UNPACKED_BYTES:
        raise ValidationError(MSG_XLSX_UNPACKED, code="unpacked")
    import openpyxl

    try:
        workbook = openpyxl.load_workbook(io.BytesIO(data), read_only=True, data_only=True)
    except Exception:  # InvalidFileException, KeyError (missing parts), XML errors, ...
        raise ValidationError(MSG_XLSX_UNREADABLE, code="xlsx") from None
    try:
        sheet = workbook.active
        if sheet is None:
            raise ValidationError(MSG_XLSX_UNREADABLE, code="xlsx")
        records = 0
        for row in sheet.iter_rows(values_only=True):
            if _filled(row):
                records += 1
                if records > max_rows + 1:  # header + max_rows
                    break
    except ValidationError:
        raise
    except Exception:
        raise ValidationError(MSG_XLSX_UNREADABLE, code="xlsx") from None
    finally:
        workbook.close()
    return max(records - 1, 0)


def check_import_upload(
    upload,
    input_format,
    *,
    max_bytes: int = MAX_UPLOAD_BYTES,
    max_rows: int = MAX_UPLOAD_ROWS,
) -> None:
    """Raise a `ValidationError` (a message for the import form) unless `upload` is at most
    `max_bytes`, readable in `input_format` (CSV: UTF-8; xlsx: a real, sane workbook) and has at
    most `max_rows` filled rows after its header. Leaves the file at position 0."""
    if upload.size is None or upload.size > max_bytes:
        raise ValidationError(MSG_TOO_LARGE, code="too_large")
    extension = input_format.get_extension()
    if extension not in ("csv", "xlsx"):
        raise ValidationError(MSG_FORMAT, code="format")
    upload.seek(0)
    data = upload.read(max_bytes + 1)
    upload.seek(0)
    if len(data) > max_bytes:
        raise ValidationError(MSG_TOO_LARGE, code="too_large")
    rows = _csv_data_rows(data) if extension == "csv" else _xlsx_data_rows(data, max_rows)
    if rows > max_rows:
        raise _too_many_rows(max_rows)


class LimitedImportForm(ImportForm):
    """unfold's import form plus `check_import_upload()`. django-import-export writes the upload
    to its temporary storage only after this form is valid, so a refused file is never kept."""

    max_bytes = MAX_UPLOAD_BYTES
    max_rows = MAX_UPLOAD_ROWS

    def __init__(self, formats, resources, **kwargs):
        super().__init__(formats, resources, **kwargs)
        self.import_formats = list(formats)
        limits = f"at most 1 MB and {self.max_rows} rows"
        self.fields["import_file"].help_text = f"CSV (UTF-8) or Excel (.xlsx), {limits}."

    def clean(self):
        cleaned = super().clean()
        upload = cleaned.get("import_file")
        index = cleaned.get("format")
        if upload is None or index in (None, ""):
            return cleaned
        try:
            input_format = self.import_formats[int(index)]()
        except (IndexError, TypeError, ValueError):
            self.add_error("format", MSG_FORMAT)
            return cleaned
        try:
            check_import_upload(
                upload, input_format, max_bytes=self.max_bytes, max_rows=self.max_rows
            )
        except ValidationError as error:
            self.add_error("import_file", error)
        return cleaned


def unescape_formula(value):
    """Inverse of `apps.core.export_formats.escape_formula`: `"'=1+1"` -> `"=1+1"`. Only an
    apostrophe the export would have added is removed; `"'quoted'"` stays as it is."""
    if isinstance(value, str) and value.startswith("'"):
        rest = value[1:]
        if escape_formula(rest) != rest:
            return rest
    return value


def _spreadsheet_cell(value):
    # An empty Excel cell arrives as None, an empty CSV cell as "": treat both like the CSV
    # (the resources' widgets turn "" into NULL where a field allows it).
    return "" if value is None else unescape_formula(value)


class SpreadsheetImportMixin:
    """For django-import-export resources. Before an import:
    - rows with no value at all are dropped (Excel keeps formatted empty rows);
    - empty cells are empty text in both formats (Excel gives None, CSV gives "");
    - the export's formula escaping is undone (`unescape_formula`),
    so "export, fix one cell, import again" stores exactly what was exported, in CSV or Excel."""

    def before_import(self, dataset, **kwargs):
        super().before_import(dataset, **kwargs)
        rows = [list(row) for row in dataset]
        while dataset.height:
            dataset.lpop()
        for row in rows:
            if _filled(row):
                dataset.append([_spreadsheet_cell(cell) for cell in row])


def add_service_errors(form, error: ValidationError, field_map: Mapping[str, str] | None = None):
    """Attach `error` to `form`: each service key goes to the mapped form field (or the field of
    the same name); anything else becomes a form-wide error."""
    field_map = field_map or {}
    if not hasattr(error, "error_dict"):
        for message in error.messages:
            form.add_error(None, message)
        return
    for key, messages in error.message_dict.items():
        target = field_map.get(key, key)
        if target not in form.fields:
            target = None
        for message in messages:
            form.add_error(target, message)


def dry_run(service: Callable[..., Any], *args, **kwargs) -> Any:
    """Call `service` and roll everything back. Returns its result or raises its error."""
    with transaction.atomic():
        result = service(*args, **kwargs)
        transaction.set_rollback(True)
    return result


class ReadOnlyHistoryAdmin(SimpleHistoryAdmin):
    """History list and version pages for objects the user can see; never a revert."""

    def _visible_or_404(self, request, object_id):
        return get_object_or_404(self.get_queryset(request), pk=unquote(object_id))

    def history_view(self, request, object_id, extra_context=None):
        self._visible_or_404(request, object_id)
        return super().history_view(request, object_id, extra_context)

    def history_form_view(self, request, object_id, version_id, extra_context=None):
        self._visible_or_404(request, object_id)
        if request.method != "GET":
            raise PermissionDenied  # no revert: changes go through the services
        return super().history_form_view(request, object_id, version_id, extra_context)

    def revert_disabled(self, request, obj=None) -> bool:
        return True


class ImportExportPermissionsMixin:
    """For ImportExportModelAdmin / ExportMixin admins."""

    def has_import_permission(self, request) -> bool:
        return self.has_add_permission(request) and self.has_change_permission(request)

    def has_export_permission(self, request) -> bool:
        return self.has_view_permission(request)
