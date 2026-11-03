"""The `Idempotency-Key` request header (02 §5), on `POST /orders/` and
`POST /orders/{id}/retry-payment/`.

The app makes one key per checkout attempt (a UUID is recommended) and sends the same key again
when it retries after a timeout or a lost response. A repeat with the same key returns the
original result instead of placing a second order or creating a second payment.

Rules (the contract; documented on every operation that takes the header):
- Missing or blank -> 400 `VALIDATION_ERROR`, `details: {"Idempotency-Key": [KEY_REQUIRED]}`.
- Not 8-64 characters of letters, digits, `-` or `_` -> 400 `VALIDATION_ERROR` with
  `details: {"Idempotency-Key": [KEY_INVALID]}`.
- Only a successful result is remembered (per user): a request that failed (e.g. 409
  `STOCK_UNAVAILABLE`) did nothing and may be retried with the same key.
- The same key with a different request body -> 400 `VALIDATION_ERROR` with
  `details: {"Idempotency-Key": [KEY_REUSED]}`.
"""

import re

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request

from apps.core.schema import validation_error

IDEMPOTENCY_HEADER = "Idempotency-Key"
KEY_REQUIRED = "This header is required."
KEY_INVALID = "Use 8-64 letters, digits, hyphens or underscores (a UUID is recommended)."
KEY_REUSED = "This key was already used for a different request. Use a new key."

KEY_PATTERN = r"^[A-Za-z0-9_-]{8,64}$"  # published; checked with fullmatch (no "$" newline gap)
_KEY_RE = re.compile(r"[A-Za-z0-9_-]{8,64}")


def idempotency_key_from_header(request: Request) -> str:
    """The `Idempotency-Key` header, or a 400 `VALIDATION_ERROR` (format only)."""
    raw = (request.headers.get(IDEMPOTENCY_HEADER) or "").strip()
    if not raw:
        raise ValidationError({IDEMPOTENCY_HEADER: [KEY_REQUIRED]})
    if not _KEY_RE.fullmatch(raw):
        raise ValidationError({IDEMPOTENCY_HEADER: [KEY_INVALID]})
    return raw


IDEMPOTENCY_KEY_PARAMETER = OpenApiParameter(
    IDEMPOTENCY_HEADER,
    OpenApiTypes.STR,
    OpenApiParameter.HEADER,
    required=True,
    pattern=KEY_PATTERN,
    description=(
        "One key per attempt (a UUID v4 is recommended), 8-64 letters, digits, `-` or `_`. "
        "Send the **same** key again when retrying after a timeout or a lost response: the "
        "original result is returned and nothing is done twice. Only a successful result is "
        "remembered, so a failed attempt may be retried with the same key. The same key with a "
        "different body is a 400. Missing or malformed: 400 `VALIDATION_ERROR` with "
        '`details: {"Idempotency-Key": [...]}`.'
    ),
)

IDEMPOTENCY_KEY_MISSING = validation_error(
    {IDEMPOTENCY_HEADER: [KEY_REQUIRED]}, name="IDEMPOTENCY_KEY_MISSING"
)
IDEMPOTENCY_KEY_INVALID = validation_error(
    {IDEMPOTENCY_HEADER: [KEY_INVALID]}, name="IDEMPOTENCY_KEY_INVALID"
)
IDEMPOTENCY_KEY_REUSED = validation_error(
    {IDEMPOTENCY_HEADER: [KEY_REUSED]}, name="IDEMPOTENCY_KEY_REUSED"
)
