"""Per-user rate limits for app endpoints that create things (DRF scoped throttles, Redis).

`FailOpenUserThrottle` fails **open** when Redis is down: a lost limit is better than refusing
orders or payment confirmations (09 §2: Redis loss must not lose orders). OTP limits are the
opposite and fail closed (DL-13); they do not use this class.
"""

import logging

from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

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


class BaselineUserThrottle(FailOpenUserThrottle):
    """T-814 (H3), a default throttle class: every authenticated caller, per user
    (`DEFAULT_THROTTLE_RATES["user"]`). Anonymous callers are left to `BaselineAnonThrottle`.

    A view that sets its own `throttle_classes` (a stricter scope, e.g. the rider endpoints)
    replaces the defaults, so nothing is throttled twice; `throttle_classes = []` exempts a view
    (health probes, the gateway webhook)."""

    scope = "user"

    def allow_request(self, request, view) -> bool:
        if not (request.user and request.user.is_authenticated):
            return True
        return super().allow_request(request, view)


class BaselineAnonThrottle(AnonRateThrottle):
    """T-814 (H3), a default throttle class: anonymous callers per IP
    (`DEFAULT_THROTTLE_RATES["anon"]`). Generous: many customers can share one carrier IP
    (CGNAT). Fails open like the per-user throttles."""

    scope = "anon"

    def allow_request(self, request, view) -> bool:
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning("anon throttle unavailable; allowing the request", exc_info=True)
            return True


class SearchThrottle(FailOpenUserThrottle):
    """Search and suggestions: per user, per IP when anonymous (the catalog is public)."""

    scope = "search"


class ServiceabilityThrottle(FailOpenUserThrottle):
    """The public serviceability check: per IP (the view authenticates nobody)."""

    scope = "serviceability"


class CouponApplyThrottle(FailOpenUserThrottle):
    """Applying a coupon to the cart: stops guessing coupon codes."""

    scope = "coupon_apply"


class AddressWriteThrottle(FailOpenUserThrottle):
    """Creating, editing, deleting and defaulting saved addresses."""

    scope = "address_write"


class InvoiceThrottle(FailOpenUserThrottle):
    """Invoice links (each one signs a private-bucket URL and may render a PDF)."""

    scope = "invoice"


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
