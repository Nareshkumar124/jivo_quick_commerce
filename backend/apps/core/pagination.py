from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    """02 §5: `?page=&page_size=`, default 20, max 100. Body: {count, next, previous, results}.

    An out-of-range page returns 404 NOT_FOUND. An invalid or zero `page_size` falls back to 20.
    """

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
