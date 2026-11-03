"""Domain exception and the DRF exception handler that renders the error envelope.

Raise :class:`ApiError` from services and views::

    raise ApiError(ErrorCode.STOCK_UNAVAILABLE, details={"items": [...]})

Every exception that reaches DRF (including DRF's own, Django's ``Http404`` /
``PermissionDenied`` / ``ValidationError`` and unexpected errors) is rendered as
``{"error": {"code", "message", "details"}}`` with the matching HTTP status.
"""

import logging
import math
from collections.abc import Mapping
from typing import Any

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.core.exceptions import RequestDataTooBig, SuspiciousOperation
from django.core.exceptions import ValidationError as DjangoValidationError
from django.http import Http404
from rest_framework import exceptions as drf_exceptions
from rest_framework import status
from rest_framework.response import Response
from rest_framework.serializers import as_serializer_error
from rest_framework.views import exception_handler as drf_exception_handler
from rest_framework.views import set_rollback

from apps.core.errors import ERROR_HTTP_STATUS, ErrorCode, error_payload

logger = logging.getLogger(__name__)


class ApiError(drf_exceptions.APIException):
    """An API error with a code from :class:`ErrorCode`.

    The HTTP status defaults to the one listed for the code in 06 §6.
    """

    def __init__(
        self,
        code: ErrorCode | str,
        message: str | None = None,
        *,
        details: Mapping[str, Any] | None = None,
        status_code: int | None = None,
    ) -> None:
        self.error_code = ErrorCode(code)
        self.status_code = status_code or ERROR_HTTP_STATUS[self.error_code]
        self.message = message or str(self.error_code.label)
        self.details = dict(details or {})
        super().__init__(detail=self.message, code=self.error_code.value)


class CodedThrottled(drf_exceptions.Throttled):
    """A throttle rejection with its own error code (DRF sets the `Retry-After` header).

    Raised from a view's ``throttled()`` hook, e.g. the OTP endpoints use ``OTP_RATE_LIMITED``
    instead of the generic ``RATE_LIMITED``.
    """

    error_code = ErrorCode.RATE_LIMITED

    def __init__(self, wait: float | None = None) -> None:
        super().__init__(wait=wait, detail=str(self.error_code.label))


class OtpRateLimited(CodedThrottled):
    error_code = ErrorCode.OTP_RATE_LIMITED


class OtpThrottleMixin:
    """For OTP views: any throttle rejection becomes 429 ``OTP_RATE_LIMITED``."""

    def throttled(self, request, wait: float | None) -> None:
        raise OtpRateLimited(wait)


# Most specific first: AuthenticationFailed covers simplejwt's InvalidToken.
_DRF_EXCEPTION_CODES: tuple[tuple[type[drf_exceptions.APIException], ErrorCode], ...] = (
    (drf_exceptions.ValidationError, ErrorCode.VALIDATION_ERROR),
    (drf_exceptions.ParseError, ErrorCode.VALIDATION_ERROR),
    (drf_exceptions.NotAuthenticated, ErrorCode.AUTH_REQUIRED),
    (drf_exceptions.AuthenticationFailed, ErrorCode.TOKEN_INVALID),
    (drf_exceptions.PermissionDenied, ErrorCode.PERMISSION_DENIED),
    (drf_exceptions.NotFound, ErrorCode.NOT_FOUND),
    (drf_exceptions.MethodNotAllowed, ErrorCode.METHOD_NOT_ALLOWED),
    (drf_exceptions.NotAcceptable, ErrorCode.NOT_ACCEPTABLE),
    (drf_exceptions.UnsupportedMediaType, ErrorCode.UNSUPPORTED_MEDIA_TYPE),
    (drf_exceptions.Throttled, ErrorCode.RATE_LIMITED),
)

_STATUS_FALLBACK_CODES: dict[int, ErrorCode] = {
    400: ErrorCode.VALIDATION_ERROR,
    401: ErrorCode.AUTH_REQUIRED,
    403: ErrorCode.PERMISSION_DENIED,
    404: ErrorCode.NOT_FOUND,
    405: ErrorCode.METHOD_NOT_ALLOWED,
    406: ErrorCode.NOT_ACCEPTABLE,
    415: ErrorCode.UNSUPPORTED_MEDIA_TYPE,
    429: ErrorCode.RATE_LIMITED,
    503: ErrorCode.SERVICE_UNAVAILABLE,
}


def _code_for(exc: drf_exceptions.APIException) -> ErrorCode:
    if isinstance(exc, CodedThrottled):
        return exc.error_code
    for exc_class, code in _DRF_EXCEPTION_CODES:
        if isinstance(exc, exc_class):
            return code
    return _STATUS_FALLBACK_CODES.get(exc.status_code, ErrorCode.SERVER_ERROR)


def _message_for(exc: drf_exceptions.APIException, code: ErrorCode) -> str:
    detail = exc.detail
    # simplejwt puts a dict like {"detail": "...", "code": "token_not_valid", ...} in detail.
    if isinstance(detail, dict) and isinstance(detail.get("detail"), str):
        return str(detail["detail"])
    if isinstance(detail, str):
        return str(detail)
    return str(code.label)


def _validation_details(data: Any) -> dict[str, Any]:
    if isinstance(data, dict):
        return data
    return {"non_field_errors": data if isinstance(data, list) else [data]}


def _normalise(exc: Exception) -> Exception:
    """Convert Django exceptions into their DRF equivalents.

    `SuspiciousOperation` is the client's fault, never a 500 (BUG-0001): a body over
    `DATA_UPLOAD_MAX_MEMORY_SIZE` is 413 `PAYLOAD_TOO_LARGE`; the others (too many fields,
    files, ...) are 400 `VALIDATION_ERROR`, as Django itself answers them. Logged at WARNING on
    the `django.security` loggers, like Django does."""
    if isinstance(exc, SuspiciousOperation):
        logging.getLogger(f"django.security.{type(exc).__name__}").warning("%s", exc)
        if isinstance(exc, RequestDataTooBig):
            return ApiError(ErrorCode.PAYLOAD_TOO_LARGE)
        return ApiError(
            ErrorCode.VALIDATION_ERROR,
            details={"non_field_errors": ["The request could not be processed."]},
        )
    if isinstance(exc, Http404):
        return drf_exceptions.NotFound()
    if isinstance(exc, DjangoPermissionDenied):
        return drf_exceptions.PermissionDenied()
    if isinstance(exc, DjangoValidationError):
        return drf_exceptions.ValidationError(detail=as_serializer_error(exc))
    return exc


def exception_handler(exc: Exception, context: dict[str, Any]) -> Response:
    """DRF ``EXCEPTION_HANDLER``: render every error as the envelope."""
    exc = _normalise(exc)
    # DRF's handler sets WWW-Authenticate / Retry-After headers and rolls back atomic blocks.
    response = drf_exception_handler(exc, context)

    if response is None:
        # Not an API exception: a bug. Log it (Sentry picks up error logs) and hide the details.
        view = context.get("view")
        logger.error(
            "Unhandled exception in %s", type(view).__name__ if view else "API view", exc_info=exc
        )
        set_rollback()
        return Response(
            error_payload(ErrorCode.SERVER_ERROR), status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    assert isinstance(exc, drf_exceptions.APIException)  # noqa: S101 - guaranteed by DRF above
    if isinstance(exc, ApiError):
        response.data = error_payload(exc.error_code, exc.message, exc.details)
        return response

    code = _code_for(exc)
    if code is ErrorCode.VALIDATION_ERROR and isinstance(exc, drf_exceptions.ValidationError):
        details = _validation_details(response.data)
        message = str(code.label)
    else:
        details = {}
        message = _message_for(exc, code)
        if isinstance(exc, drf_exceptions.Throttled) and exc.wait is not None:
            details = {"retry_after_seconds": math.ceil(exc.wait)}
    response.data = error_payload(code, message, details)
    return response
