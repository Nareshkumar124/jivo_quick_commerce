"""Store context: the `X-Store-Id` request header (02 §5, 06 §2.4).

Catalog endpoints (and the cart from Phase 3) are per store, because stock and prices are per
store. The app takes the store id from `GET /serviceability/` and sends it on every catalog call.

Rules (the contract; documented on every operation that takes the header):
- Missing or blank header -> 400 `VALIDATION_ERROR`, `details: {"X-Store-Id": [HEADER_REQUIRED]}`.
- Not a positive integer -> 400 `VALIDATION_ERROR`, `details: {"X-Store-Id": [HEADER_INVALID]}`.
- No such store, or the store is deactivated -> 404 `STORE_NOT_FOUND`: the app drops its saved
  store and re-runs the serviceability check for the current location.
- A store that is closed (outside its hours or not accepting orders) is still browsable.
"""

import re

from rest_framework.exceptions import ValidationError
from rest_framework.request import Request

STORE_HEADER = "X-Store-Id"
HEADER_REQUIRED = "This header is required."
HEADER_INVALID = "A valid store id is required."

_STORE_ID_RE = re.compile(r"^[0-9]{1,18}$")


def store_id_from_header(request: Request) -> int:
    """The store id sent in `X-Store-Id`, or a 400 `VALIDATION_ERROR` (format only)."""
    raw = (request.headers.get(STORE_HEADER) or "").strip()
    if not raw:
        raise ValidationError({STORE_HEADER: [HEADER_REQUIRED]})
    if not _STORE_ID_RE.match(raw) or int(raw) < 1:
        raise ValidationError({STORE_HEADER: [HEADER_INVALID]})
    return int(raw)


def get_store(request: Request):
    """The active store in `X-Store-Id` (a cached `StoreArea`: id, name, hours; no database
    query when warm): 400 for a missing or malformed header, 404 `STORE_NOT_FOUND` for an
    unknown or deactivated store."""
    from apps.stores.services import active_store

    return active_store(store_id_from_header(request))
