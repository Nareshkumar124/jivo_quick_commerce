"""API error codes (06 §6) and the error envelope.

Every error response body is ``{"error": {"code": ..., "message": ..., "details": {...}}}``.
The apps map ``code`` to user-facing text in one place, so codes are a stable contract: add new
ones, never rename or remove. The label of each code is its default human-readable message.
"""

from collections.abc import Mapping
from typing import Any

from django.db import models


class ErrorCode(models.TextChoices):
    # --- 06 §6, initial set ---------------------------------------------------------------
    VALIDATION_ERROR = "VALIDATION_ERROR", "Some fields are invalid."
    OTP_INVALID = "OTP_INVALID", "The OTP is incorrect."
    OTP_EXPIRED = "OTP_EXPIRED", "The OTP has expired."
    OTP_RATE_LIMITED = "OTP_RATE_LIMITED", "Too many OTP requests. Try again later."
    AUTH_REQUIRED = "AUTH_REQUIRED", "Authentication is required."
    TOKEN_INVALID = "TOKEN_INVALID", "The access token is invalid or expired."
    PERMISSION_DENIED = "PERMISSION_DENIED", "You do not have permission to do this."
    NOT_FOUND = "NOT_FOUND", "Not found."
    APP_UPDATE_REQUIRED = "APP_UPDATE_REQUIRED", "Please update the app to continue."
    NOT_SERVICEABLE = "NOT_SERVICEABLE", "We do not deliver to this location yet."
    STORE_CLOSED = "STORE_CLOSED", "The store is not accepting orders right now."
    STOCK_UNAVAILABLE = "STOCK_UNAVAILABLE", "Some items are out of stock."
    MAX_QTY_EXCEEDED = "MAX_QTY_EXCEEDED", "The maximum quantity for this item is exceeded."
    MIN_ORDER_NOT_MET = "MIN_ORDER_NOT_MET", "The minimum order value is not met."
    COUPON_INVALID = "COUPON_INVALID", "The coupon is not valid."
    COUPON_EXPIRED = "COUPON_EXPIRED", "The coupon has expired."
    COUPON_NOT_ELIGIBLE = "COUPON_NOT_ELIGIBLE", "This cart is not eligible for the coupon."
    COUPON_USAGE_EXCEEDED = "COUPON_USAGE_EXCEEDED", "The coupon usage limit is reached."
    COD_NOT_AVAILABLE = "COD_NOT_AVAILABLE", "Cash on delivery is not available for this order."
    PRICE_CHANGED = "PRICE_CHANGED", "The bill has changed. Refresh the cart."
    PAYMENT_VERIFICATION_FAILED = (
        "PAYMENT_VERIFICATION_FAILED",
        "The payment could not be verified.",
    )
    INVALID_STATE_TRANSITION = "INVALID_STATE_TRANSITION", "This action is not allowed right now."
    OFFER_EXPIRED = "OFFER_EXPIRED", "The offer has expired."
    OFFER_TAKEN = "OFFER_TAKEN", "The offer was taken by another rider."
    OUTSIDE_GEOFENCE = "OUTSIDE_GEOFENCE", "You are too far from the location."
    DELIVERY_OTP_INVALID = "DELIVERY_OTP_INVALID", "The delivery OTP is incorrect."
    DELIVERY_OTP_LOCKED = "DELIVERY_OTP_LOCKED", "Too many wrong delivery OTP attempts."
    CASH_LIMIT_EXCEEDED = "CASH_LIMIT_EXCEEDED", "The cash-in-hand limit is exceeded."
    MAINTENANCE = "MAINTENANCE", "The service is under maintenance."
    # --- Added in Phase 0: generic HTTP-level errors (06 §6 updated) -----------------------
    METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED", "This HTTP method is not allowed here."
    NOT_ACCEPTABLE = "NOT_ACCEPTABLE", "The requested response format is not available."
    UNSUPPORTED_MEDIA_TYPE = "UNSUPPORTED_MEDIA_TYPE", "The request body format is not supported."
    RATE_LIMITED = "RATE_LIMITED", "Too many requests. Try again later."
    SERVER_ERROR = "SERVER_ERROR", "Something went wrong. Please try again."
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE", "The service is temporarily unavailable."


ERROR_HTTP_STATUS: dict[ErrorCode, int] = {
    ErrorCode.VALIDATION_ERROR: 400,
    ErrorCode.OTP_INVALID: 400,
    ErrorCode.OTP_EXPIRED: 400,
    ErrorCode.OTP_RATE_LIMITED: 429,
    ErrorCode.AUTH_REQUIRED: 401,
    ErrorCode.TOKEN_INVALID: 401,
    ErrorCode.PERMISSION_DENIED: 403,
    ErrorCode.NOT_FOUND: 404,
    ErrorCode.APP_UPDATE_REQUIRED: 426,
    ErrorCode.NOT_SERVICEABLE: 422,
    ErrorCode.STORE_CLOSED: 422,
    ErrorCode.STOCK_UNAVAILABLE: 409,
    ErrorCode.MAX_QTY_EXCEEDED: 422,
    ErrorCode.MIN_ORDER_NOT_MET: 422,
    ErrorCode.COUPON_INVALID: 422,
    ErrorCode.COUPON_EXPIRED: 422,
    ErrorCode.COUPON_NOT_ELIGIBLE: 422,
    ErrorCode.COUPON_USAGE_EXCEEDED: 422,
    ErrorCode.COD_NOT_AVAILABLE: 422,
    ErrorCode.PRICE_CHANGED: 409,
    ErrorCode.PAYMENT_VERIFICATION_FAILED: 400,
    ErrorCode.INVALID_STATE_TRANSITION: 409,
    ErrorCode.OFFER_EXPIRED: 409,
    ErrorCode.OFFER_TAKEN: 409,
    ErrorCode.OUTSIDE_GEOFENCE: 422,
    ErrorCode.DELIVERY_OTP_INVALID: 400,
    ErrorCode.DELIVERY_OTP_LOCKED: 423,
    ErrorCode.CASH_LIMIT_EXCEEDED: 422,
    ErrorCode.MAINTENANCE: 503,
    ErrorCode.METHOD_NOT_ALLOWED: 405,
    ErrorCode.NOT_ACCEPTABLE: 406,
    ErrorCode.UNSUPPORTED_MEDIA_TYPE: 415,
    ErrorCode.RATE_LIMITED: 429,
    ErrorCode.SERVER_ERROR: 500,
    ErrorCode.SERVICE_UNAVAILABLE: 503,
}


def error_payload(
    code: ErrorCode | str,
    message: str | None = None,
    details: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Build the error envelope body. ``details`` is always an object (possibly empty)."""
    code = ErrorCode(code)
    return {
        "error": {
            "code": code.value,
            "message": message or str(code.label),
            "details": dict(details or {}),
        }
    }
