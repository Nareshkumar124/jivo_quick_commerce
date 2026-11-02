"""OpenAPI helpers: error-envelope responses with complete examples.

The Flutter apps build fakes from these examples, so every documented error carries an example
whose body is exactly what the server sends (see ``apps.core.errors.error_payload``).
"""

from collections.abc import Mapping
from typing import Any

from drf_spectacular.utils import OpenApiExample, OpenApiResponse

from apps.core.errors import ErrorCode, error_payload
from apps.core.serializers import ErrorEnvelopeSerializer


def error_example(
    code: ErrorCode,
    message: str | None = None,
    details: Mapping[str, Any] | None = None,
    *,
    name: str | None = None,
    summary: str | None = None,
) -> OpenApiExample:
    return OpenApiExample(
        name or code.value,
        value=error_payload(code, message, details),
        summary=summary,
        response_only=True,
    )


def error_response(description: str, *examples: OpenApiExample) -> OpenApiResponse:
    return OpenApiResponse(
        ErrorEnvelopeSerializer, description=description, examples=list(examples)
    )


def validation_error(details: Mapping[str, Any], *, name: str | None = None) -> OpenApiExample:
    return error_example(ErrorCode.VALIDATION_ERROR, details=details, name=name)


UNAUTHORIZED = error_response(
    "No access token (`AUTH_REQUIRED`), or the token is invalid, expired or revoked "
    "(`TOKEN_INVALID`). On `TOKEN_INVALID`, refresh once and retry.",
    error_example(ErrorCode.AUTH_REQUIRED, summary="No Authorization header"),
    error_example(
        ErrorCode.TOKEN_INVALID, "Given token not valid for any token type", summary="Expired token"
    ),
)

NOT_FOUND = error_response(
    "The object does not exist or does not belong to the caller.",
    error_example(ErrorCode.NOT_FOUND),
)

APP_UPDATE_REQUIRED = error_response(
    "Force update. Sent only when the request carries `X-App-Name`, `X-Platform` and "
    "`X-App-Version`, and the version is below `min_supported_version` for that app and platform. "
    "Requests without these headers never get 426.",
    error_example(
        ErrorCode.APP_UPDATE_REQUIRED,
        details={
            "min_supported_version": "1.2.0",
            "latest_version": "1.4.0",
            "store_url": "https://play.google.com/store/apps/details?id=in.jivo.quick",
        },
    ),
)

MAINTENANCE = error_response(
    "Maintenance mode is on (`/api/v1/config/app/` returns `maintenance: true`). "
    "`message` is the text to show.",
    error_example(
        ErrorCode.MAINTENANCE, "Jivo is down for scheduled maintenance. We will be back by 6:00 AM."
    ),
)


def app_responses(responses: Mapping[int, Any]) -> dict[int, Any]:
    """``responses`` plus the force-update (426) and maintenance (503) errors of app endpoints."""
    result = dict(responses)
    result.setdefault(426, APP_UPDATE_REQUIRED)
    result.setdefault(503, MAINTENANCE)
    return result
