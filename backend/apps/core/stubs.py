"""Contract-first stubs (Phase 3 R1): the operations exist with their full schema and request
validation, and answer 503 until their internals land in Phase 3 R2. Delete this module when no
view uses it any more."""

from typing import NoReturn

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

NOT_AVAILABLE_YET = "This feature is not available yet (Phase 3 R2)."


def not_available_yet() -> NoReturn:
    raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, NOT_AVAILABLE_YET)
