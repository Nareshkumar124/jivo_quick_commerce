from django.conf import settings
from drf_spectacular.utils import (
    OpenApiExample,
    OpenApiParameter,
    OpenApiResponse,
    extend_schema,
)
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.services.otp import OTP_DIGITS
from apps.cms.serializers import (
    AppConfigSerializer,
    FaqQuerySerializer,
    FaqSerializer,
    PageSerializer,
)
from apps.cms.services import faq_list, get_app_config, page_body, rider_location_settings
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.schema import (
    app_responses,
    error_example,
    error_response,
    ok_response,
    validation_error,
)

APP_CONFIG_EXAMPLE = {
    "min_supported_version": "1.0.0",
    "latest_version": "1.2.0",
    "store_url": "https://play.google.com/store/apps/details?id=in.jivo.quick",
    "maintenance": False,
    "maintenance_message": "",
    "support": {"phone": "+911800123456", "email": "support@jivo.in"},
    "policy_urls": {
        "terms": "https://jivo.in/terms",
        "privacy": "https://jivo.in/privacy",
        "refund": "https://jivo.in/refund-policy",
    },
    "terms_version": "2026-11-01",
    "otp": {"length": 6, "resend_after_seconds": 30},
    "rider_location": {
        "active_interval_seconds": 10,
        "idle_interval_seconds": 30,
        "active_sample_seconds": 5,
        "idle_sample_seconds": 30,
        "max_batch": 50,
    },
    "feature_flags": {},
}


class AppConfigView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="config_app",
        tags=["config"],
        summary="App configuration (splash)",
        description=(
            "Called on every app start. Versions and `store_url` are for the app and platform "
            "given by the `X-App-Name` and `X-Platform` headers (null without them). Never "
            "returns 426 or 503: during maintenance it answers 200 with `maintenance: true`."
        ),
        auth=[],
        responses={
            200: OpenApiResponse(
                AppConfigSerializer,
                description="Configuration.",
                examples=[
                    OpenApiExample("Normal", value=APP_CONFIG_EXAMPLE, response_only=True),
                    OpenApiExample(
                        "Maintenance",
                        value={
                            **APP_CONFIG_EXAMPLE,
                            "maintenance": True,
                            "maintenance_message": (
                                "Jivo is down for scheduled maintenance. "
                                "We will be back by 6:00 AM."
                            ),
                        },
                        response_only=True,
                    ),
                    OpenApiExample(
                        "No app headers",
                        value={
                            **APP_CONFIG_EXAMPLE,
                            "min_supported_version": None,
                            "latest_version": None,
                            "store_url": None,
                        },
                        response_only=True,
                    ),
                ],
            )
        },
    )
    def get(self, request: Request) -> Response:
        config = get_app_config()
        info = request.client_info
        policy = config.version_policy(info.app_name, info.platform)
        data = {
            "min_supported_version": policy.min_supported_version if policy else None,
            "latest_version": policy.latest_version if policy else None,
            "store_url": policy.store_url if policy else None,
            "maintenance": config.maintenance,
            "maintenance_message": config.maintenance_message,
            "support": {"phone": config.support_phone, "email": config.support_email},
            "policy_urls": {
                "terms": config.terms_url,
                "privacy": config.privacy_url,
                "refund": config.refund_url,
            },
            "terms_version": config.terms_version,
            "otp": {
                "length": OTP_DIGITS,
                "resend_after_seconds": settings.OTP_RESEND_AFTER_SECONDS,
            },
            "rider_location": rider_location_settings(config),
            "feature_flags": config.feature_flags,
        }
        return Response(AppConfigSerializer(data).data)


# --------------------------------------------------------------------------- P7: pages and FAQs

PAGE_EXAMPLE = {
    "slug": "refund-policy",
    "title": "Refund Policy",
    "html": (
        "<h1>Refund Policy</h1><p>Refunds go back to the original payment method within 5 to 7 "
        'working days.</p><p>Questions? Write to <a href="mailto:support@jivo.in">'
        "support@jivo.in</a>.</p>"
    ),
    "updated_at": "2026-11-04T06:30:00Z",
}
FAQS_EXAMPLE = [
    {
        "id": 1,
        "category": "Orders",
        "question": "How long does delivery take?",
        "answer": "Most orders arrive in 10 to 30 minutes.",
    },
    {
        "id": 2,
        "category": "Orders",
        "question": "Can I cancel my order?",
        "answer": "Yes, until the store starts packing it. Open the order and tap Cancel order.",
    },
    {
        "id": 5,
        "category": "Payments & refunds",
        "question": "When will I get my refund?",
        "answer": "Refunds reach the original payment method within 5 to 7 working days.",
    },
]
CONTENT_CACHE_CONTROL = "public, max-age=300"


class PageView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="pages_retrieve",
        tags=["cms"],
        summary="Static page (About, Terms, Privacy, Refund policy)",
        description=(
            "Public. Slugs the apps use: `about`, `terms`, `privacy`, `refund-policy` and, in the "
            "rider app, `rider-agreement` and `rider-location-disclosure`. The HTML "
            "is sanitised server-side to a small allow-list (see `html`). An unknown or "
            "unpublished slug is 404 `NOT_FOUND`: fall back to the policy URL from "
            "`GET /config/app/`. Cached for up to 5 minutes."
        ),
        auth=[],
        parameters=[
            OpenApiParameter("slug", str, OpenApiParameter.PATH, description="`Page.slug`.")
        ],
        responses=app_responses(
            {
                200: ok_response(PageSerializer, "The page.", ("Refund policy", PAGE_EXAMPLE)),
                404: error_response(
                    "No published page with this slug.",
                    error_example(ErrorCode.NOT_FOUND, "Page not found."),
                ),
            }
        ),
    )
    def get(self, request: Request, slug: str) -> Response:
        body = page_body(slug)
        if body is None:
            raise ApiError(ErrorCode.NOT_FOUND, "Page not found.")
        response = Response(PageSerializer(body).data)
        response["Cache-Control"] = CONTENT_CACHE_CONTROL
        return response


class FaqListView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="faqs_list",
        tags=["cms"],
        summary="FAQs for an app's help screen",
        description=(
            "Public, not paginated. Active FAQs of the app in display order, grouped by "
            "`category`: entries of one category are consecutive, so start a new heading "
            "whenever `category` changes. Answers are plain text. Cached for up to 5 minutes."
        ),
        auth=[],
        parameters=[FaqQuerySerializer],
        responses=app_responses(
            {
                200: ok_response(
                    FaqSerializer(many=True),
                    "The FAQs (may be empty). The example shows one entry of the list.",
                    ("Customer app", FAQS_EXAMPLE[0]),
                ),
                400: error_response(
                    "`app` is missing or not customer/rider.",
                    validation_error(
                        {"app": ['"shop" is not a valid choice.']}, name="Invalid app"
                    ),
                ),
            }
        ),
    )
    def get(self, request: Request) -> Response:
        query = FaqQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        response = Response(FaqSerializer(faq_list(query.validated_data["app"]), many=True).data)
        response["Cache-Control"] = CONTENT_CACHE_CONTROL
        return response
