"""Force update (426 APP_UPDATE_REQUIRED) and maintenance (503 MAINTENANCE) for the app API.

Applies to /api/v1/ except the splash config and token refresh (sessions survive maintenance
and force updates) and the payment gateway's webhook (server to server: a payment event must
never be refused during maintenance). 426 is sent only when the request names its app, platform
and version (X-App-Name, X-Platform, X-App-Version) and that version is below the configured
minimum.
Runs after client_info_middleware.
"""

from asgiref.sync import iscoroutinefunction, sync_to_async
from django.http import JsonResponse
from django.utils.decorators import sync_and_async_middleware

from apps.cms.services import get_app_config, parse_version
from apps.core.errors import ErrorCode, error_payload

API_PREFIX = "/api/v1/"
EXEMPT_PATHS = frozenset(
    {
        "/api/v1/config/app/",
        "/api/v1/auth/token/refresh/",
        "/api/v1/payments/razorpay/webhook/",
    }
)


def guard_response(request) -> JsonResponse | None:
    if not request.path.startswith(API_PREFIX) or request.path in EXEMPT_PATHS:
        return None
    config = get_app_config()
    if config.maintenance:
        return JsonResponse(
            error_payload(ErrorCode.MAINTENANCE, config.maintenance_message or None), status=503
        )
    info = getattr(request, "client_info", None)
    if info is None or info.version_tuple is None:
        return None
    policy = config.version_policy(info.app_name, info.platform)
    if policy is None:
        return None
    if parse_version(info.app_version) < parse_version(policy.min_supported_version):
        return JsonResponse(
            error_payload(
                ErrorCode.APP_UPDATE_REQUIRED,
                details={
                    "min_supported_version": policy.min_supported_version,
                    "latest_version": policy.latest_version,
                    "store_url": policy.store_url,
                },
            ),
            status=426,
        )
    return None


@sync_and_async_middleware
def app_guard_middleware(get_response):
    if iscoroutinefunction(get_response):

        async def async_middleware(request):
            blocked = await sync_to_async(guard_response)(request)
            return blocked or await get_response(request)

        return async_middleware

    def middleware(request):
        return guard_response(request) or get_response(request)

    return middleware
