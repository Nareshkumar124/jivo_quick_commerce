"""Per-user rate limits for app endpoints that create things (DRF scoped throttles, Redis).

`FailOpenUserThrottle` fails **open** when Redis is down: a lost limit is better than refusing
orders or payment confirmations (09 §2: Redis loss must not lose orders). OTP limits are the
opposite and fail closed (DL-13); they do not use this class.
"""

import logging

from rest_framework.throttling import UserRateThrottle

from apps.core.errors import ErrorCode
from apps.core.schema import error_example, error_response

logger = logging.getLogger(__name__)


class FailOpenUserThrottle(UserRateThrottle):
    """Per user (per IP when anonymous); the rate is DEFAULT_THROTTLE_RATES[scope]."""

    def allow_request(self, request, view) -> bool:
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning(
                "%s throttle unavailable; allowing the request", self.scope, exc_info=True
            )
            return True


class OrderPlacementThrottle(FailOpenUserThrottle):
    scope = "orders_create"


class PaymentThrottle(FailOpenUserThrottle):
    """Payment verify and retry-payment."""

    scope = "payments"


RATE_LIMITED = error_response(
    "Too many requests from this account. Wait `details.retry_after_seconds` (also in "
    "`Retry-After`), then try again with the same request.",
    error_example(
        ErrorCode.RATE_LIMITED,
        "Request was throttled. Expected available in 120 seconds.",
        {"retry_after_seconds": 120},
    ),
)
