"""Server-side data tables for the Ops Console: search, filters and pagination from GET
parameters, rendered by `templates/ops/components/data_table.html`.

The filter form is never swapped while the user types: HTMX replaces only the results region
(`data_table_results.html`), so focus and caret stay put. Invalid filter values are ignored and
shown as field errors; the rest of the query still applies.
"""

from collections.abc import Callable, Sequence
from dataclasses import dataclass
from typing import Any

from django import forms
from django.core.paginator import Paginator
from django.db.models import Q, QuerySet
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldAdminTextInputWidget

SEARCH_PARAM = "q"
PAGE_PARAM = "page"


@dataclass(frozen=True)
class Column:
    title: str
    cell: Callable[[Any], Any]  # row -> str / SafeString / number
    css: str = ""


@dataclass(frozen=True)
class Filter:
    name: str
    label: str
    choices: Sequence[tuple[str, str]]
    apply: Callable[[QuerySet, str], QuerySet]


class DataTable:
    def __init__(
        self,
        request,
        queryset: QuerySet,
        *,
        table_id: str,
        url: str,
        columns: Sequence[Column],
        search_fields: Sequence[str] = (),
        search_placeholder: str = "Search",
        filters: Sequence[Filter] = (),
        per_page: int = 10,
        empty_title: str = "No results",
        empty_message: str = "",
    ):
        self.request = request
        self.queryset = queryset
        self.table_id = table_id
        self.url = url
        self.columns = list(columns)
        self.search_fields = tuple(search_fields)
        self.search_placeholder = search_placeholder
        self.filters = list(filters)
        self.per_page = per_page
        self.empty_title = empty_title
        self.empty_message = empty_message

    def _form(self) -> forms.Form:
        fields: dict[str, forms.Field] = {}
        if self.search_fields:
            fields[SEARCH_PARAM] = forms.CharField(
                label="Search",
                required=False,
                max_length=100,
                widget=UnfoldAdminTextInputWidget(
                    attrs={"type": "search", "placeholder": self.search_placeholder}
                ),
            )
        for table_filter in self.filters:
            fields[table_filter.name] = forms.ChoiceField(
                label=table_filter.label,
                required=False,
                choices=[("", "All"), *table_filter.choices],
                widget=UnfoldAdminSelectWidget,
            )
        form_class = type("DataTableFilterForm", (forms.Form,), fields)
        return form_class(self.request.GET or None, auto_id=f"{self.table_id}-%s")

    def _filtered(self, form: forms.Form) -> tuple[QuerySet, bool]:
        queryset = self.queryset
        if not form.is_bound:
            return queryset, False
        form.is_valid()  # populate cleaned_data and errors; valid fields still apply
        data = form.cleaned_data
        applied = False
        term = (data.get(SEARCH_PARAM) or "").strip()
        if term and self.search_fields:
            query = Q()
            for field in self.search_fields:
                query |= Q(**{f"{field}__icontains": term})
            queryset = queryset.filter(query)
            applied = True
        for table_filter in self.filters:
            value = data.get(table_filter.name)
            if value:
                queryset = table_filter.apply(queryset, value)
                applied = True
        return queryset, applied

    def context(self) -> dict:
        form = self._form()
        queryset, applied = self._filtered(form)
        paginator = Paginator(queryset, self.per_page)
        page = paginator.get_page(self.request.GET.get(PAGE_PARAM))
        rows = [
            [{"value": column.cell(row), "css": column.css} for column in self.columns]
            for row in page.object_list
        ]
        return {
            "id": self.table_id,
            "results_id": f"{self.table_id}-results",
            "url": self.url,
            "form": form,
            "columns": self.columns,
            "rows": rows,
            "page": page,
            "paginator": paginator,
            "page_range": paginator.get_elided_page_range(page.number, on_each_side=1, on_ends=1),
            "filters_applied": applied,
            "empty_title": self.empty_title,
            "empty_message": self.empty_message,
        }
