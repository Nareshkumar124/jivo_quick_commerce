"""Health probes (09 §2) and the JSON 404/500 handlers."""

import logging

import redis
from django.conf import settings
from django.db import connection
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.utils.decorators import method_decorator
from django.views import defaults
from django.views.decorators.cache import never_cache
from drf_spectacular.utils import OpenApiExample, OpenApiResponse, extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.errors import ErrorCode, error_payload
from apps.core.exceptions import ApiError
from apps.core.serializers import (
    ErrorEnvelopeSerializer,
    HealthCheckStatus,
    HealthLiveSerializer,
    HealthReadySerializer,
    HealthStatus,
)

logger = logging.getLogger(__name__)

_JSON_PATH_PREFIXES = ("/api/", "/health/")


def check_database() -> bool:
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception:
        # Server-side log only; the response never carries driver messages (host, user).
        logger.exception("Readiness check failed: database")
        return False
    return True


def check_redis() -> bool:
    client = redis.Redis.from_url(settings.REDIS_URL, socket_connect_timeout=2, socket_timeout=2)
    try:
        return bool(client.ping())
    except redis.RedisError:
        logger.exception("Readiness check failed: redis")
        return False
    finally:
        client.close()


class _ProbeView(APIView):
    # Probes must answer without credentials, CSRF or throttling, from load balancers and the apps.
    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes: list = []


@method_decorator(never_cache, name="dispatch")
class HealthLiveView(_ProbeView):
    @extend_schema(
        operation_id="health_live",
        tags=["health"],
        summary="Liveness probe",
        description=(
            "Returns 200 while the process can serve requests. Checks no dependencies. "
            "The apps call this until `/api/v1/config/app/` exists (Phase 1)."
        ),
        auth=[],
        responses={
            200: OpenApiResponse(
                HealthLiveSerializer,
                description="The process is alive.",
                examples=[OpenApiExample("Alive", value={"status": "ok"})],
            ),
        },
    )
    def get(self, request: Request) -> Response:
        return Response({"status": HealthStatus.OK})


@method_decorator(never_cache, name="dispatch")
class HealthReadyView(_ProbeView):
    @extend_schema(
        operation_id="health_ready",
        tags=["health"],
        summary="Readiness probe",
        description=(
            "Checks PostgreSQL (`SELECT 1`) and Redis (`PING`). Returns 200 when both answer, "
            "otherwise 503 `SERVICE_UNAVAILABLE` with the per-check result in `details.checks`."
        ),
        auth=[],
        responses={
            200: OpenApiResponse(
                HealthReadySerializer,
                description="Database and Redis are reachable.",
                examples=[
                    OpenApiExample(
                        "Ready",
                        value={"status": "ok", "checks": {"database": "ok", "redis": "ok"}},
                    )
                ],
            ),
            503: OpenApiResponse(
                ErrorEnvelopeSerializer,
                description="A dependency is unreachable.",
                examples=[
                    OpenApiExample(
                        "Redis down",
                        value=error_payload(
                            ErrorCode.SERVICE_UNAVAILABLE,
                            "Service is not ready.",
                            {"checks": {"database": "ok", "redis": "error"}},
                        ),
                    )
                ],
            ),
        },
    )
    def get(self, request: Request) -> Response:
        checks = {
            "database": HealthCheckStatus.OK if check_database() else HealthCheckStatus.ERROR,
            "redis": HealthCheckStatus.OK if check_redis() else HealthCheckStatus.ERROR,
        }
        if any(result != HealthCheckStatus.OK for result in checks.values()):
            raise ApiError(
                ErrorCode.SERVICE_UNAVAILABLE,
                "Service is not ready.",
                details={"checks": {name: str(result) for name, result in checks.items()}},
            )
        return Response({"status": HealthStatus.OK, "checks": checks})


def _wants_json(request: HttpRequest) -> bool:
    return request.path.startswith(_JSON_PATH_PREFIXES)


def handler404(request: HttpRequest, exception: Exception) -> HttpResponse:
    """Unmatched URL (DEBUG off): JSON envelope for API paths, Django's page otherwise."""
    if _wants_json(request):
        return JsonResponse(error_payload(ErrorCode.NOT_FOUND), status=404)
    return defaults.page_not_found(request, exception)


def handler500(request: HttpRequest) -> HttpResponse:
    """Error outside DRF (DEBUG off): JSON envelope for API paths, Django's page otherwise."""
    if _wants_json(request):
        return JsonResponse(error_payload(ErrorCode.SERVER_ERROR), status=500)
    return defaults.server_error(request)
