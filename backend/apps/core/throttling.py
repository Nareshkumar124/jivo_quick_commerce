"""Per-user rate limits for app endpoints that create things (DRF scoped throttles, Redis).

`FailOpenUserThrottle` fails **open** when Redis is down: a lost limit is better than refusing
orders or payment confirmations (09 §2: Redis loss must not lose orders). OTP limits are the
opposite and fail closed (DL-13); they do not use this class.

CGNAT (T-817): Indian mobile carriers put many customers behind one public IP, so a signed-in
customer is always throttled **per user**, also on public views that authenticate nobody
(`authentication_classes = []`: search, suggest, serviceability, the catalog). There the
throttle reads the identity from the bearer token itself (`throttle_user_id()`): the signature
and expiry are checked, nothing else; the request stays anonymous, so the response (and the
per-store cache) never depends on who asked, and a bad or expired token never gets a 401 from
a public endpoint: it is simply throttled per IP. Anonymous callers stay per IP (`get_ident()`,
which honours NUM_PROXIES / X-Forwarded-For, T-814).

Tokened callers on public views also share one generous **per-IP ceiling**
(`SignedInIpCeiling`, scope `signed_in_ip`, `SIGNED_IN_IP_RATE`, default 1500/min = 5x the
anonymous baseline), so one IP rotating many accounts' tokens is still bounded per IP. Callers
authenticated by the view itself (`request.user`) are not subject to it.
"""

import logging

from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

from apps.core.errors import ErrorCode
from apps.core.schema import error_example, error_response

logger = logging.getLogger(__name__)

_UNSET = object()
_CACHE_ATTR = "_throttle_user_id"


def _token_user_id(request):
    """The user id in a valid bearer access token, or None. No database query."""
    from rest_framework_simplejwt.authentication import JWTAuthentication
    from rest_framework_simplejwt.settings import api_settings

    auth = JWTAuthentication()
    try:
        header = auth.get_header(request)
        raw = auth.get_raw_token(header) if header is not None else None
        if raw is None:
            return None
        token = auth.get_validated_token(raw)  # signature, expiry, token type
        user_id = token.get(api_settings.USER_ID_CLAIM)
    except Exception:  # invalid, expired, malformed: anonymous for throttling
        return None
    return str(user_id) if user_id not in (None, "") else None


def throttle_user_id(request) -> str | None:
    """Who to throttle as: the authenticated user, else the user of a valid bearer token sent to
    a public view, else None (throttle per IP). Computed once per request."""
    user = getattr(request, "user", None)
    if user is not None and user.is_authenticated:
        return str(user.pk)
    cached = getattr(request, _CACHE_ATTR, _UNSET)
    if cached is _UNSET:
        cached = _token_user_id(request)
        setattr(request, _CACHE_ATTR, cached)
    return cached


_CEILING_ATTR = "_signed_in_ip_counted"


def _token_only(request) -> bool:
    """A valid bearer token on a view that did not authenticate the request (public views)."""
    user = getattr(request, "user", None)
    if user is not None and user.is_authenticated:
        return False
    return throttle_user_id(request) is not None


class SignedInIpCeiling(AnonRateThrottle):
    """Per client IP, for callers throttled per user from their token on public views (T-817):
    `DEFAULT_THROTTLE_RATES["signed_in_ip"]`. Counted at most once per request."""

    scope = "signed_in_ip"

    def get_cache_key(self, request, view):
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class FailOpenUserThrottle(UserRateThrottle):
    """Per user (also from a bearer token on public views, under the per-IP
    `SignedInIpCeiling`), per IP when anonymous; the rate is DEFAULT_THROTTLE_RATES[scope]."""

    _ceiling: SignedInIpCeiling | None = None

    def get_cache_key(self, request, view):
        user_id = throttle_user_id(request)
        ident = f"user-{user_id}" if user_id is not None else self.get_ident(request)
        return self.cache_format % {"scope": self.scope, "ident": ident}

    def allow_request(self, request, view) -> bool:
        self._ceiling = None
        try:
            if _token_only(request) and not getattr(request, _CEILING_ATTR, False):
                setattr(request, _CEILING_ATTR, True)
                ceiling = SignedInIpCeiling()
                if not ceiling.allow_request(request, view):
                    self._ceiling = ceiling
                    return False
            return super().allow_request(request, view)
        except Exception:
            logger.warning(
                "%s throttle unavailable; allowing the request", self.scope, exc_info=True
            )
            return True

    def wait(self):
        if self._ceiling is not None:
            return self._ceiling.wait()
        return super().wait()


class BaselineUserThrottle(FailOpenUserThrottle):
    """T-814 (H3), a default throttle class: every authenticated caller, per user
    (`DEFAULT_THROTTLE_RATES["user"]`). Anonymous callers are left to `BaselineAnonThrottle`.

    A view that sets its own `throttle_classes` (a stricter scope, e.g. the rider endpoints)
    replaces the defaults, so nothing is throttled twice; `throttle_classes = []` exempts a view
    (health probes, the gateway webhook)."""

    scope = "user"

    def allow_request(self, request, view) -> bool:
        if throttle_user_id(request) is None:
            return True
        return super().allow_request(request, view)


class BaselineAnonThrottle(AnonRateThrottle):
    """T-814 (H3), a default throttle class: anonymous callers per IP
    (`DEFAULT_THROTTLE_RATES["anon"]`). Generous: many customers can share one carrier IP
    (CGNAT). A caller with a valid bearer token is never counted here, also on public views
    (T-817): `BaselineUserThrottle` counts them per user. Fails open like the per-user
    throttles."""

    scope = "anon"

    def allow_request(self, request, view) -> bool:
        if throttle_user_id(request) is not None:
            return True
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning("anon throttle unavailable; allowing the request", exc_info=True)
            return True


class SearchThrottle(FailOpenUserThrottle):
    """Search and suggestions: per user (from the bearer token, T-817), per IP when anonymous
    (the catalog is public)."""

    scope = "search"


class ServiceabilityThrottle(FailOpenUserThrottle):
    """The public serviceability check: per user when a valid bearer token is sent (T-817; the
    view itself authenticates nobody), per IP when anonymous."""

    scope = "serviceability"


class CouponApplyThrottle(FailOpenUserThrottle):
    """Applying a coupon to the cart: stops guessing coupon codes."""

    scope = "coupon_apply"


class ReferralApplyThrottle(FailOpenUserThrottle):
    """Entering a friend's referral code: stops guessing codes (added 2026-11-13)."""

    scope = "referral_apply"


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
