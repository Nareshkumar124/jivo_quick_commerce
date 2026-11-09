"""Reports pages (05 §4): an index, one page per report with date range + store filters, a
paginated table (HTMX swaps the results only), a CSV download and async exports.

All data comes from the backend's `apps.reports.services` (the 12 reports of backend/phase-7):
`available_reports`, `run_report`, `report_csv`, `filename`, `request_export`, `user_exports`,
`export_download_url`. The service checks the report permission and the store scope again
(`PermissionDenied` -> 403) and validates dates and the sync row cap (`ValidationError`: the
error state on the page, a 400 with the message for a CSV download). Its rows are display
strings already (money "249.00"); the panel never recomputes them.

Access: staff only (`ops_view`), then the report's own permission. An unknown key is a 404, a
report the role may not open a 403. The store filter offers only `stores_for(user)`.
"""

import re

from django.contrib import messages
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.paginator import Paginator
from django.http import Http404, HttpResponse
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from apps.ops_console.access import forbidden, is_htmx, ops_view
from apps.ops_console.report_filters import Params, ReportFilterForm
from apps.ops_console.views import ops_context
from apps.reports import services
from apps.reports.registry import REPORTS

PER_PAGE = 50
RECENT_EXPORTS = 10
NUMERIC = re.compile(r"^-?\d+(\.\d+)?$")

# Column headings: the service's snake_case keys, humanised; acronyms kept upper case.
ACRONYMS = {"gmv": "GMV", "aov": "AOV", "sku": "SKU", "hsn": "HSN", "gst": "GST", "cod": "COD"}
ACRONYMS |= {"cgst": "CGST", "sgst": "SGST", "igst": "IGST", "id": "ID", "otp": "OTP"}
# Sales summary definitions (backend registry doc, docs/05 §4, DL-65), shown under the table.
COLUMN_HELP = {
    "uncollected_cod": (
        "Order value of cash-on-delivery orders that ended failed or returned: no cash was "
        "collected. They stay in GMV and are deducted from net revenue (DL-65)."
    ),
    "unavailable_refunds": (
        "Refunds for items the store could not supply (T8a). The reduced order total already "
        "reflects them, so they are not deducted again from net revenue."
    ),
    "cancelled_refunds": (
        "Refunds of cancelled orders. Cancelled orders are not in GMV, so these refunds are "
        "shown apart and are not part of net revenue."
    ),
}
# Shown for reconciliation only: not part of net revenue.
NOT_IN_NET = frozenset({"unavailable_refunds", "cancelled_refunds"})


def column_title(key: str) -> str:
    words = [ACRONYMS.get(word, word) for word in key.split("_")]
    title = " ".join(words)
    title = title[:1].upper() + title[1:]
    return f"{title} (not in net)" if key in NOT_IN_NET else title


def _query(request, **extra) -> str:
    query = request.GET.copy()
    query.pop("page", None)
    for key, value in extra.items():
        query[key] = value
    return query.urlencode()


def _first_error(form) -> str:
    errors = [error for field_errors in form.errors.values() for error in field_errors]
    return errors[0] if errors else "Choose valid dates and a store."


def _message(error: ValidationError, default: str = "Check the filters.") -> str:
    return error.messages[0] if error.messages else default


def _numeric_columns(rows) -> set[int]:
    """Right-align columns whose every non-empty cell is a number (money strings included)."""
    if not rows:
        return set()
    numeric = set(range(len(rows[0])))
    for row in rows:
        for i, value in enumerate(row):
            if i in numeric and value != "" and not NUMERIC.match(str(value)):
                numeric.discard(i)
    return numeric


def _table(slug, columns, rows, request) -> dict:
    paginator = Paginator(rows, PER_PAGE)
    page = paginator.get_page(request.GET.get("page"))
    numeric = _numeric_columns(page.object_list)
    return {
        "id": "report",
        "results_id": "report-results",
        "url": reverse("ops:report", args=[slug]),
        "columns": [
            {"key": key, "title": column_title(key), "help": COLUMN_HELP.get(key, "")}
            for key in columns
        ],
        "column_notes": [
            {"title": column_title(key), "help": COLUMN_HELP[key]}
            for key in columns
            if key in COLUMN_HELP
        ],
        "rows": [
            [
                {
                    "value": "-" if value == "" else value,
                    "css": "text-right whitespace-nowrap" if i in numeric else "",
                }
                for i, value in enumerate(row)
            ]
            for row in page.object_list
        ],
        "page": page,
        "paginator": paginator,
        "page_range": paginator.get_elided_page_range(page.number, on_each_side=1, on_ends=1),
        "filters_applied": True,
        "empty_title": "No data for these filters",
        "empty_message": "Try a longer period or another store.",
    }


def _render(request, title, context, status=200):
    if is_htmx(request):
        return render(request, "ops/reports/results.html", context, status=status)
    return render(
        request,
        "ops/reports/report.html",
        ops_context(request, title=title, **context),
        status=status,
    )


# --------------------------------------------------------------------------- index


@ops_view()
def index(request):
    visible = [
        {"slug": spec.key, "title": spec.title, "description": spec.description}
        for spec in services.available_reports(request.user)
    ]
    if not visible:
        return forbidden(request)
    return render(
        request, "ops/reports/index.html", ops_context(request, title="Reports", reports=visible)
    )


# --------------------------------------------------------------------------- one report


def _spec(user, slug):
    """The report's spec when `user` may open it; None for a known report they may not; 404
    for an unknown key."""
    if slug not in REPORTS:
        raise Http404("No such report.")
    for spec in services.available_reports(user):
        if spec.key == slug:
            return spec
    return None


@ops_view()
def report(request, slug: str):
    user = request.user
    spec = _spec(user, slug)
    if spec is None:
        return forbidden(request)
    form = ReportFilterForm(request.GET, user=user)
    wants_csv = request.GET.get("export") == "csv"
    context = {
        "report": {"slug": spec.key, "title": spec.title, "description": spec.description},
        "form": form,
        "table": None,
        "dated": spec.dated,
        "exports": _recent_exports(user, spec.key),
    }
    if not form.is_valid():
        context["filter_error"] = _first_error(form)
        return _render(request, spec.title, context, status=400 if wants_csv else 200)
    params = Params(
        start=form.cleaned_data["date_from"],
        end=form.cleaned_data["date_to"],
        store_id=form.cleaned_data.get("store"),
    )
    kwargs = {"start": params.start, "end": params.end, "store_id": params.store_id}
    try:
        if wants_csv:
            content = services.report_csv(user, spec.key, **kwargs)
            response = HttpResponse(content, content_type="text/csv; charset=utf-8")
            name = services.filename(spec.key, params.start, params.end)
            response["Content-Disposition"] = f'attachment; filename="{name}"'
            response["X-Content-Type-Options"] = "nosniff"
            return response
        result = services.run_report(user, spec.key, **kwargs)
    except PermissionDenied:
        return forbidden(request)
    except ValidationError as error:
        context["filter_error"] = _message(error)
        return _render(request, spec.title, context, status=400 if wants_csv else 200)
    context.update(
        table=_table(spec.key, spec.columns, result.rows, request),
        params=params,
        too_many=result.truncated,
        export_query=_query(request, export="csv"),
        export_form_query=_query(request),
    )
    return _render(request, spec.title, context)


def _recent_exports(user, key):
    return list(services.user_exports(user).filter(report=key).order_by("-pk")[:RECENT_EXPORTS])


@require_POST
@ops_view()
def report_export(request, slug: str):
    """Queue the backend's async CSV export (Celery, private bucket)."""
    user = request.user
    spec = _spec(user, slug)
    if spec is None:
        return forbidden(request)
    form = ReportFilterForm(request.POST, user=user)
    target = f"{reverse('ops:report', args=[slug])}?{request.POST.get('query', '')}"
    if not form.is_valid():
        messages.error(request, _first_error(form))
        return redirect(target)
    try:
        services.request_export(
            user,
            spec.key,
            start=form.cleaned_data["date_from"],
            end=form.cleaned_data["date_to"],
            store_id=form.cleaned_data.get("store"),
        )
    except PermissionDenied:
        return forbidden(request)
    except ValidationError as error:
        messages.error(request, _message(error))
        return redirect(target)
    messages.success(request, "Export queued. It appears below when it is ready.")
    return redirect(target)


@ops_view()
def export_download(request, export_id: int):
    """The requester's own finished export, through a short-lived signed URL."""
    try:
        url = services.export_download_url(request.user, export_id)
    except PermissionDenied:
        return forbidden(request)
    except ValidationError:
        raise Http404("Export not found or not ready.") from None
    return redirect(url)
