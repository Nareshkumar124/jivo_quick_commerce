from django.conf import settings
from drf_spectacular.utils import OpenApiExample, OpenApiResponse, extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.services.otp import OTP_DIGITS
from apps.cms.serializers import AppConfigSerializer
from apps.cms.services import get_app_config

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
    "rider_location": {"active_interval_seconds": 10, "idle_interval_seconds": 30},
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
            "rider_location": {
                "active_interval_seconds": config.rider_location_active_interval_seconds,
                "idle_interval_seconds": config.rider_location_idle_interval_seconds,
            },
            "feature_flags": config.feature_flags,
        }
        return Response(AppConfigSerializer(data).data)
