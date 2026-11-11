"""Safe parsing of ids and codes that arrive in URLs and query strings (P8 audit m2).

`str.isdigit()` is also true for "²", "①" or "٣", which `int()` then refuses (a 500). A
19-digit number is above PostgreSQL's bigint, and a NUL byte (`%00`) is refused by psycopg. Every
panel view and admin filter that turns a request value into a database lookup goes through here.
"""

import re

from django.http import Http404

# ASCII digits only, at most 18 of them: always inside PostgreSQL's bigint (9.2e18).
_ASCII_ID = re.compile(r"[0-9]{1,18}")


def parse_ascii_id(value) -> int | None:
    """`"42"` -> 42. Anything else (empty, "²", "①", "-1", " 1", "%00", 19+ digits, None) ->
    None, so the caller shows nothing or ignores the filter instead of failing."""
    if not isinstance(value, str) or not _ASCII_ID.fullmatch(value):
        return None
    return int(value)


def has_nul(value: str) -> bool:
    return "\x00" in value


def text_param_or_404(value: str) -> str:
    """A `<str:...>` URL segment used in a lookup: a NUL byte cannot exist in a stored value, and
    PostgreSQL refuses it in a query, so it is simply not found (404), never a 500."""
    if has_nul(value):
        raise Http404("Not found.")
    return value
