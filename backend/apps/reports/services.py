"""Reports for the admin / Ops Console (05 §4, Phase 7). The UI calls only these functions.

- `available_reports(user)`: the `ReportSpec`s the user may run.
- `run_report(user, key, *, start, end, store_id=None, limit=None) -> ReportResult`: rows as
  display strings (money "249.00", times IST), at most `REPORT_SYNC_MAX_ROWS` (`truncated`).
- `report_csv(user, key, ...) -> bytes`: the same as CSV (UTF-8 with BOM for Excel; formula
  cells escaped). Refused (ValidationError) above `REPORT_SYNC_MAX_ROWS`: use an export.
- `request_export(user, key, ...) -> ReportExport`: a Celery CSV export into the private
  bucket (`reports.generate_export`, after commit); `user_exports(user)`;
  `export_download_url(user, export_id)` (a signed URL, own exports only, DONE only).

Access (05 §3 "Reports"): the report's permission (`reports.view_reports`,
`view_catalog_reports`, `view_finance_reports`) else `PermissionDenied`; rows are limited to
`stores_for(user)` (store roles: their stores) and to `store_id` when given (a store outside the
user's scope is `PermissionDenied`). Bad dates, an unknown report or a range over
`REPORT_MAX_RANGE_DAYS` are `ValidationError`.
"""

import csv
import io
import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone

from apps.core import audit
from apps.core.export_formats import escape_formula
from apps.core.money import money_str
from apps.reports.models import ExportStatus, ReportExport
from apps.reports.registry import REPORTS, ReportQuery, ReportSpec

logger = logging.getLogger(__name__)

MSG_NO_PERMISSION = "You do not have permission to see this report."


@dataclass
class ReportResult:
    spec: ReportSpec
    columns: tuple[str, ...]
    rows: list[list[str]]
    truncated: bool


def _is_staff(user) -> bool:
    return bool(user and user.is_authenticated and user.is_active and user.is_staff)


def available_reports(user) -> list[ReportSpec]:
    if not _is_staff(user):
        return []
    return [spec for spec in REPORTS.values() if user.has_perm(spec.permission)]


def get_spec(user, key: str) -> ReportSpec:
    spec = REPORTS.get(key)
    if spec is None:
        raise ValidationError(f"Unknown report {key!r}.")
    if not (_is_staff(user) and user.has_perm(spec.permission)):
        raise PermissionDenied(MSG_NO_PERMISSION)
    return spec


def scoped_stores(user, store_id: int | None = None):
    """The user's stores (`stores_for`), narrowed to `store_id`; a store outside the scope is
    `PermissionDenied` (never an empty report that looks like "no sales")."""
    from apps.stores.services import stores_for

    stores = stores_for(user)
    if store_id is not None:
        stores = stores.filter(pk=store_id)
        if not stores.exists():
            raise PermissionDenied(MSG_NO_PERMISSION)
    return stores


def _dates(start: date | None, end: date | None) -> tuple[date, date]:
    today = timezone.localdate(timezone=ZoneInfo(settings.STORE_TIME_ZONE))
    end = end or today
    start = start or end
    if start > end:
        raise ValidationError("The start date must not be after the end date.")
    if (end - start).days + 1 > settings.REPORT_MAX_RANGE_DAYS:
        raise ValidationError(f"Choose at most {settings.REPORT_MAX_RANGE_DAYS} days.")
    return start, end


def _query(user, key, start, end, store_id) -> tuple[ReportSpec, ReportQuery]:
    spec = get_spec(user, key)
    start, end = _dates(start, end)
    return spec, ReportQuery(stores=scoped_stores(user, store_id), start=start, end=end)


def cell(value) -> str:
    if value is None:
        return ""
    if isinstance(value, Decimal):
        return money_str(value) if value.as_tuple().exponent == -2 else str(value)
    if isinstance(value, datetime):
        return timezone.localtime(value).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def run_report(
    user,
    key: str,
    *,
    start: date | None = None,
    end: date | None = None,
    store_id: int | None = None,
    limit: int | None = None,
) -> ReportResult:
    spec, query = _query(user, key, start, end, store_id)
    cap = min(limit or settings.REPORT_SYNC_MAX_ROWS, settings.REPORT_SYNC_MAX_ROWS)
    rows, truncated = [], False
    for row in spec.build(query):
        if len(rows) >= cap:
            truncated = True
            break
        rows.append([cell(value) for value in row])
    return ReportResult(spec=spec, columns=spec.columns, rows=rows, truncated=truncated)


def _write_csv(columns, rows) -> bytes:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(columns)
    for row in rows:
        writer.writerow([escape_formula(value) for value in row])
    return ("﻿" + buffer.getvalue()).encode("utf-8")


def report_csv(
    user,
    key: str,
    *,
    start: date | None = None,
    end: date | None = None,
    store_id: int | None = None,
) -> bytes:
    result = run_report(user, key, start=start, end=end, store_id=store_id)
    if result.truncated:
        raise ValidationError(
            f"More than {settings.REPORT_SYNC_MAX_ROWS} rows: request an export instead."
        )
    audit.record(
        user,
        "reports.download",
        ("reports.report", key),
        {"report": key, "rows": len(result.rows), "store_id": store_id},
    )
    return _write_csv(result.columns, result.rows)


def filename(key: str, start: date, end: date) -> str:
    return f"{key}_{start.isoformat()}_{end.isoformat()}.csv"


# --------------------------------------------------------------------------- async exports


def request_export(
    user,
    key: str,
    *,
    start: date | None = None,
    end: date | None = None,
    store_id: int | None = None,
) -> ReportExport:
    """Queue a CSV export (checked now and again when it runs)."""
    spec, query = _query(user, key, start, end, store_id)
    with transaction.atomic():
        export = ReportExport.objects.create(
            report=spec.key,
            requested_by=user,
            params={
                "start": query.start.isoformat(),
                "end": query.end.isoformat(),
                "store_id": store_id,
            },
        )
        audit.record(user, "reports.export", export, {"report": spec.key, "store_id": store_id})
        export_id = export.pk

        def queue():
            from apps.reports.tasks import generate_export

            generate_export.delay(export_id)

        transaction.on_commit(queue)
    return export


def generate_export(export_id: int) -> ReportExport:
    """Build the export's CSV into the private bucket. Idempotent: a DONE export is left as
    is. Runs as the requester, so a lost permission or store fails it."""
    with transaction.atomic():
        export = (
            ReportExport.objects.select_for_update()
            .select_related("requested_by")
            .get(pk=export_id)
        )
        if export.status == ExportStatus.DONE:
            return export
        export.status = ExportStatus.RUNNING
        export.save(update_fields=["status"])
    params = export.params
    try:
        _, query = _query(
            export.requested_by,
            export.report,
            date.fromisoformat(params["start"]),
            date.fromisoformat(params["end"]),
            params.get("store_id"),
        )
        spec = REPORTS[export.report]
        rows = ([cell(value) for value in row] for row in spec.build(query))
        counted = []

        def counting():
            for row in rows:
                counted.append(1)
                yield row

        content = _write_csv(spec.columns, counting())
    except (PermissionDenied, ValidationError) as exc:
        export.status = ExportStatus.FAILED
        export.error = str(getattr(exc, "message", exc))[:200]
        export.finished_at = timezone.now()
        export.save(update_fields=["status", "error", "finished_at"])
        logger.warning("report export %s refused: %s", export.pk, export.error)
        return export
    if export.file:
        export.file.delete(save=False)
    export.file.save(f"{export.report}.csv", ContentFile(content), save=False)
    export.status = ExportStatus.DONE
    export.row_count = len(counted)
    export.error = ""
    export.finished_at = timezone.now()
    export.save(update_fields=["file", "status", "row_count", "error", "finished_at"])
    logger.info("report export %s done: %s rows", export.pk, export.row_count)
    return export


def user_exports(user):
    """The user's own exports, newest first."""
    if not _is_staff(user):
        return ReportExport.objects.none()
    return ReportExport.objects.filter(requested_by=user)


def export_download_url(user, export_id: int) -> str:
    export = user_exports(user).filter(pk=export_id, status=ExportStatus.DONE).first()
    if export is None or not export.file:
        raise ValidationError("Export not found or not ready.")
    get_spec(user, export.report)  # still allowed to see this report
    seconds = settings.REPORT_EXPORT_URL_SECONDS
    try:
        return default_storage.url(export.file.name, expire=seconds)
    except TypeError:  # local file storage (tests): no expiry argument
        return default_storage.url(export.file.name)


def purge_old_exports(now=None) -> int:
    """Delete exports (rows and files) older than `REPORT_EXPORT_RETENTION_DAYS`."""
    cutoff = (now or timezone.now()) - timedelta(days=settings.REPORT_EXPORT_RETENTION_DAYS)
    count = 0
    for export in ReportExport.objects.filter(created_at__lt=cutoff).iterator():
        if export.file:
            export.file.delete(save=False)
        export.delete()
        count += 1
    return count
