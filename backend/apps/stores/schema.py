"""OpenAPI pieces for store-scoped endpoints: the `X-Store-Id` header and its errors.

Every operation that takes the header documents the same three errors (see
`apps.stores.context`): 400 `VALIDATION_ERROR` (missing or malformed header) and 404
`STORE_NOT_FOUND` (unknown or deactivated store), in addition to its own.
"""

from collections.abc import Mapping
from typing import Any

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter

from apps.core.errors import ErrorCode
from apps.core.schema import app_responses, error_example, error_response, validation_error
from apps.stores.context import HEADER_INVALID, HEADER_REQUIRED, STORE_HEADER

STORE_ID_PARAMETER = OpenApiParameter(
    STORE_HEADER,
    OpenApiTypes.INT,
    OpenApiParameter.HEADER,
    required=True,
    description=(
        "The store id from `GET /serviceability/` (`store.id`) for the selected location. "
        "Missing or not a positive integer: 400 `VALIDATION_ERROR` with "
        '`details: {"X-Store-Id": [...]}`. Unknown or deactivated store: 404 '
        "`STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed "
        "store is still browsable."
    ),
)

STORE_HEADER_MISSING = validation_error(
    {STORE_HEADER: [HEADER_REQUIRED]}, name="X_STORE_ID_MISSING"
)
STORE_HEADER_INVALID = validation_error({STORE_HEADER: [HEADER_INVALID]}, name="X_STORE_ID_INVALID")
STORE_NOT_FOUND = error_example(
    ErrorCode.STORE_NOT_FOUND,
    details={"store_id": 7},
    summary="Unknown or deactivated store: check serviceability again",
)


def store_responses(
    responses: Mapping[int, Any],
    *,
    bad_request: tuple[OpenApiExample, ...] = (),
    not_found: tuple[OpenApiExample, ...] = (),
) -> dict[int, Any]:
    """`responses` plus the `X-Store-Id` errors (400/404, merged with the operation's own
    examples) and the app guards (426/503)."""
    result = dict(responses)
    result[400] = error_response(
        "Invalid request: the `X-Store-Id` header is missing or malformed"
        + (", or a query parameter is invalid." if bad_request else "."),
        STORE_HEADER_MISSING,
        STORE_HEADER_INVALID,
        *bad_request,
    )
    result[404] = error_response(
        "`STORE_NOT_FOUND`: the store in `X-Store-Id` does not exist or was deactivated."
        + (" `NOT_FOUND`: the requested object or page does not exist." if not_found else ""),
        STORE_NOT_FOUND,
        *not_found,
    )
    return app_responses(result)
