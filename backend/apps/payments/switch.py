"""The "cash on delivery only" switch (`ONLINE_PAYMENTS_ENABLED`, DL-85, 2026-11-26).

Off: production runs without Razorpay live keys (no FSSAI licence yet for the live KYC). Online
checkout, payment retry, verify and the COD UPI QR are refused with 503 `SERVICE_UNAVAILABLE`
(`details.reason` = `ONLINE_PAYMENTS_DISABLED`) before any gateway call; the cart reports ONLINE
as unavailable (`ONLINE_DISABLED`); `payments.E003` (missing Razorpay keys) is not raised. COD
works as before. On (the default everywhere): nothing changes.
"""

from django.conf import settings

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

REASON = "ONLINE_PAYMENTS_DISABLED"
MSG_ONLINE_DISABLED = "Online payment is not available yet. Please choose cash on delivery."


def online_payments_enabled() -> bool:
    return bool(getattr(settings, "ONLINE_PAYMENTS_ENABLED", True))


def ensure_online_payments_enabled(message: str = MSG_ONLINE_DISABLED) -> None:
    """503 `SERVICE_UNAVAILABLE` (reason `ONLINE_PAYMENTS_DISABLED`) when the switch is off."""
    if not online_payments_enabled():
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, message, details={"reason": REASON})
