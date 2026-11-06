"""Phase 2 endpoints: serviceability and notify-me (06 §2.3). Thin views over
`apps.stores.services` (PostGIS point-in-polygon, DL-27)."""

import logging

from drf_spectacular.utils import OpenApiExample, OpenApiResponse, extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.schema import (
    OPTIONAL_AUTH_UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    validation_error,
)
from apps.core.throttling import ServiceabilityThrottle
from apps.stores import examples as ex
from apps.stores import services
from apps.stores.serializers import (
    NotifyMeSerializer,
    ServiceabilityQuerySerializer,
    ServiceabilitySerializer,
)

logger = logging.getLogger(__name__)


class NotifyMeThrottle(UserRateThrottle):
    """Per user, or per IP when anonymous (rate: DEFAULT_THROTTLE_RATES["notify_me"]).
    Fails open when Redis is down: losing a demand-signal limit is better than losing leads."""

    scope = "notify_me"

    def allow_request(self, request, view) -> bool:
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning("notify-me throttle unavailable; allowing the request", exc_info=True)
            return True


def _ok(serializer, description: str, *examples: tuple[str, dict]) -> OpenApiResponse:
    return OpenApiResponse(
        serializer,
        description=description,
        examples=[
            OpenApiExample(name, value=value, response_only=True) for name, value in examples
        ],
    )


class ServiceabilityView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes = [ServiceabilityThrottle]  # T-814 (H3): per IP

    @extend_schema(
        operation_id="serviceability_check",
        tags=["serviceability"],
        summary="Is this location serviceable, and by which store?",
        description=(
            "Call it after the user picks a location (GPS or map pin), on app start for the "
            "selected address, and on pull-to-refresh. Save `store.id` and send it as "
            "`X-Store-Id` on catalog calls.\n\n"
            "A valid point **always answers 200**: not serviceable is `serviceable: false` with "
            "`store: null`, and a closed store is `serviceable: true` with `store.is_open: "
            "false` (browsing allowed, checkout disabled). This endpoint never returns "
            "`NOT_SERVICEABLE` or `STORE_CLOSED`; those are 422 errors of the actions that "
            "need an open store (cart address and order placement, Phase 3).\n\n"
            "When service areas overlap, the nearest open store is chosen (07 §2.2). "
            "`eta_minutes` follows 08 §8."
        ),
        auth=[],
        parameters=[ServiceabilityQuerySerializer],
        responses=app_responses(
            {
                200: _ok(
                    ServiceabilitySerializer,
                    "Serviceability of the point.",
                    ("Serviceable, store open", ex.SERVICEABLE),
                    ("Serviceable, store closed for the night", ex.SERVICEABLE_STORE_CLOSED),
                    ("Serviceable, store paused", ex.SERVICEABLE_STORE_PAUSED),
                    ("Not serviceable", ex.NOT_SERVICEABLE),
                ),
                400: error_response(
                    "`lat`/`lng` missing or out of range.",
                    validation_error(
                        {"lat": ["This field is required."], "lng": ["This field is required."]},
                        name="Missing coordinates",
                    ),
                    validation_error(
                        {"lat": ["Ensure this value is less than or equal to 90."]},
                        name="Latitude out of range",
                    ),
                ),
            }
        ),
    )
    def get(self, request: Request) -> Response:
        query = ServiceabilityQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        body = services.check_serviceability(
            query.validated_data["lat"], query.validated_data["lng"]
        )
        return Response(ServiceabilitySerializer(body).data)


class NotifyMeView(APIView):
    """Public, optionally authenticated: a sent token is checked (links the request to the user)."""

    permission_classes = [AllowAny]
    throttle_classes = [NotifyMeThrottle]

    @extend_schema(
        operation_id="serviceability_notify_me",
        tags=["serviceability"],
        summary="Notify me when you deliver here",
        description=(
            "Saves interest in an unserviced location (the 'Notify me' button on the not "
            "serviceable screen). Works signed in or anonymous: send the token when signed in, "
            "so the request is linked to the user and `phone` defaults to theirs.\n\n"
            "Always 201 for a valid request; repeating it is harmless (the server may merge "
            "duplicates). Rate-limited per user and IP (429 `RATE_LIMITED`)."
        ),
        request=NotifyMeSerializer,
        examples=[
            OpenApiExample("Signed in", value=ex.NOTIFY_ME_REQUEST, request_only=True),
            OpenApiExample(
                "Anonymous with phone", value=ex.NOTIFY_ME_ANONYMOUS_REQUEST, request_only=True
            ),
        ],
        responses=app_responses(
            {
                201: _ok(NotifyMeSerializer, "Interest saved.", ("Saved", ex.NOTIFY_ME)),
                400: error_response(
                    "Invalid fields.",
                    validation_error(
                        {
                            "lat": ["This field is required."],
                            "phone": [
                                "Enter a 10-digit Indian mobile number in the form +919876543210."
                            ],
                        }
                    ),
                ),
                401: OPTIONAL_AUTH_UNAUTHORIZED,
                429: error_response(
                    "Too many requests. Wait `details.retry_after_seconds` (also `Retry-After`).",
                    error_example(
                        ErrorCode.RATE_LIMITED,
                        "Request was throttled. Expected available in 1800 seconds.",
                        {"retry_after_seconds": 1800},
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = NotifyMeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        lead = services.record_notify_me(
            lat=data["lat"],
            lng=data["lng"],
            phone=data.get("phone"),
            address_text=data.get("address_text", ""),
            user=request.user if request.user.is_authenticated else None,
        )
        body = services.notify_me_body(
            lead,
            lat=data["lat"],
            lng=data["lng"],
            phone=data.get("phone"),
            address_text=data.get("address_text", ""),
        )
        return Response(NotifyMeSerializer(body).data, status=201)
