"""OpenAPI helpers: error-envelope responses with complete examples.

The Flutter apps build fakes from these examples, so every documented error carries an example
whose body is exactly what the server sends (see ``apps.core.errors.error_payload``).
"""

from collections.abc import Mapping
from typing import Any

from drf_spectacular.openapi import AutoSchema
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, OpenApiResponse

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


# Optional authentication (e.g. home, notify-me): anonymous calls are fine, but a token that is
# sent is checked, so an expired one is refreshed instead of silently dropping personal content.
OPTIONAL_AUTH_UNAUTHORIZED = error_response(
    "Only when an `Authorization` header is sent and the token is invalid, expired or revoked. "
    "Anonymous calls (no header) never get 401. Refresh once and retry, or retry without the "
    "header after logout.",
    error_example(
        ErrorCode.TOKEN_INVALID, "Given token not valid for any token type", summary="Expired token"
    ),
)

PAGINATION_PARAMETERS = [
    OpenApiParameter(
        "page", OpenApiTypes.INT, description="Page number (1-based). Default 1.", required=False
    ),
    OpenApiParameter(
        "page_size",
        OpenApiTypes.INT,
        description="Items per page: default 20, max 100.",
        required=False,
    ),
]

PAGE_NOT_FOUND = error_example(
    ErrorCode.NOT_FOUND, "Invalid page.", name="PAGE_NOT_FOUND", summary="Page out of range"
)

INVALID_PAGE = error_response(
    "`page` is not a page of this list: 0, past the last page, or not a number. Go back to page 1.",
    PAGE_NOT_FOUND,
)


def paginated_responses(responses: Mapping[int, Any]) -> dict[int, Any]:
    """`app_responses()` for a paginated list: also documents the invalid-page 404 (BUG-0004),
    unless the operation already documents its own 404 (which must then include
    `PAGE_NOT_FOUND`)."""
    result = app_responses(responses)
    result.setdefault(404, INVALID_PAGE)
    return result


def ok_response(serializer, description: str, *examples: tuple[str, dict]) -> OpenApiResponse:
    """A success response with named examples (`(name, value)` pairs)."""
    return OpenApiResponse(
        serializer,
        description=description,
        examples=[
            OpenApiExample(name, value=value, response_only=True) for name, value in examples
        ],
    )


def request_examples(*examples: tuple[str, dict]) -> list[OpenApiExample]:
    """Named request-body examples (`(name, value)` pairs)."""
    return [OpenApiExample(name, value=value, request_only=True) for name, value in examples]


class BodyOnDeleteSchema(AutoSchema):
    """drf-spectacular publishes no request body for DELETE. Views whose DELETE takes a JSON
    body (e.g. `me_device_unregister {fcm_token}`) use this schema so the declared
    `extend_schema(request=...)` is published and generated clients can send it."""

    def _get_request_body(self, direction="request"):
        if self.method != "DELETE":
            return super()._get_request_body(direction)
        self.method = "POST"
        try:
            return super()._get_request_body(direction)
        finally:
            self.method = "DELETE"
