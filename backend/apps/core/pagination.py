from collections.abc import Mapping
from urllib.parse import urlencode

from rest_framework.pagination import PageNumberPagination
from rest_framework.utils.urls import remove_query_param, replace_query_param


class StandardPagination(PageNumberPagination):
    """02 §5: `?page=&page_size=`, default 20, max 100. Body: {count, next, previous, results}.

    An out-of-range page returns 404 NOT_FOUND. An invalid or zero `page_size` falls back to 20.
    """

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class CanonicalPagination(StandardPagination):
    """`StandardPagination` whose `next`/`previous` links are built only from `params` (the
    validated query, plus `page_size` when sent), sorted, never from the raw query string.

    For shared cached bodies (catalog): the cache key is the same canonical query, so junk or
    reordered parameters neither create new cache entries nor end up in a body served to others.
    """

    def __init__(self, params: Mapping[str, str]) -> None:
        self.params = dict(params)

    def _base_url(self) -> str:
        url = self.request.build_absolute_uri(self.request.path)
        query = urlencode(sorted(self.params.items()))
        return f"{url}?{query}" if query else url

    def get_next_link(self) -> str | None:
        if not self.page.has_next():
            return None
        return replace_query_param(
            self._base_url(), self.page_query_param, self.page.next_page_number()
        )

    def get_previous_link(self) -> str | None:
        if not self.page.has_previous():
            return None
        number = self.page.previous_page_number()
        if number == 1:
            return remove_query_param(self._base_url(), self.page_query_param)
        return replace_query_param(self._base_url(), self.page_query_param, number)


def canonical_page_query(request, params: Mapping[str, object]) -> tuple[dict, str]:
    """`(link_params, page)` for `CanonicalPagination` and the cache key: the validated
    `params` (blank values dropped) plus the effective `page_size` when one was sent, and the
    requested page (ASCII digits normalised, e.g. "01" -> "1"; anything else is passed through
    and answered 404 by the paginator, which is never cached)."""
    link_params = {key: str(value) for key, value in params.items() if value not in (None, "")}
    if request.query_params.get(StandardPagination.page_size_query_param):
        link_params[StandardPagination.page_size_query_param] = str(
            StandardPagination().get_page_size(request)
        )
    page = (request.query_params.get(StandardPagination.page_query_param) or "1").strip()
    if page.isascii() and page.isdigit():
        page = str(int(page))
    return link_params, page
