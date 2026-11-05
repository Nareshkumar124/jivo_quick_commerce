"""Contract-first stubs (Phase 5, T-511): operations whose slice has not landed exist with their
full schema and request validation and answer 503 `SERVICE_UNAVAILABLE`. Remove each call as its
slice is implemented; delete this module when none is left."""

from typing import NoReturn

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError


def not_available_yet(slice_name: str) -> NoReturn:
    raise ApiError(
        ErrorCode.SERVICE_UNAVAILABLE,
        f"This feature is not available yet (Phase 5 slice {slice_name}).",
    )
