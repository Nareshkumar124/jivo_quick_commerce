"""Test-only URLconf: small views that exercise the exception handler, pagination, auth and the
client-info middleware through the real DRF stack."""

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.core.exceptions import ValidationError as DjangoValidationError
from django.http import Http404
from django.urls import include, path
from rest_framework import exceptions, serializers
from rest_framework.generics import GenericAPIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError, OtpThrottleMixin


class Teapot(exceptions.APIException):
    status_code = 418
    default_detail = "I'm a teapot."


class Unavailable(exceptions.APIException):
    status_code = 503
    default_detail = "Down for a moment."


RAISERS = {
    "api_error": lambda: ApiError(
        ErrorCode.STOCK_UNAVAILABLE, details={"items": [{"variant_id": 7, "available": 0}]}
    ),
    "api_error_custom": lambda: ApiError(ErrorCode.NOT_FOUND, "Order not found.", status_code=410),
    "http404": lambda: Http404("internal detail"),
    "django_permission": lambda: DjangoPermissionDenied("internal detail"),
    "django_validation_dict": lambda: DjangoValidationError({"phone": ["Bad phone."]}),
    "django_validation_plain": lambda: DjangoValidationError("Plain problem."),
    "validation_list": lambda: exceptions.ValidationError(["First.", "Second."]),
    "not_acceptable": lambda: exceptions.NotAcceptable(),
    "permission_dict": lambda: exceptions.PermissionDenied(detail={"store": ["Not yours."]}),
    "throttled": lambda: exceptions.Throttled(wait=12.2),
    "teapot": lambda: Teapot(),
    "unavailable": lambda: Unavailable(),
    "unexpected": lambda: RuntimeError("secret internals"),
}


class _PublicView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]


class RaiseView(_PublicView):
    def get(self, request, kind: str):
        raise RAISERS[kind]()


class EchoSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=5)
    quantity = serializers.IntegerField(min_value=1)


class EchoView(_PublicView):
    def post(self, request):
        serializer = EchoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(serializer.validated_data)


class NumbersView(GenericAPIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def get(self, request):
        page = self.paginate_queryset(list(range(1, 251)))
        return self.get_paginated_response(page)


class WhoAmIView(APIView):
    """Default authentication (JWT, session) and permission (IsAuthenticated)."""

    def get(self, request):
        return Response({"user_id": request.user.pk})


class OncePerMinute(AnonRateThrottle):
    scope = "test-once"
    rate = "1/min"


class ThrottledView(_PublicView):
    throttle_classes = [OncePerMinute]

    def get(self, request):
        return Response({"ok": True})


class OtpThrottledView(OtpThrottleMixin, ThrottledView):
    pass


class ClientInfoView(_PublicView):
    def get(self, request):
        info = request.client_info
        return Response(
            {
                "app_name": info.app_name,
                "app_version": info.app_version,
                "build_number": info.build_number,
                "platform": info.platform,
            }
        )


urlpatterns = [
    path("t/raise/<str:kind>/", RaiseView.as_view()),
    path("t/echo/", EchoView.as_view()),
    path("t/numbers/", NumbersView.as_view()),
    path("t/whoami/", WhoAmIView.as_view()),
    path("t/throttled/", ThrottledView.as_view()),
    path("t/otp-throttled/", OtpThrottledView.as_view()),
    path("t/client-info/", ClientInfoView.as_view()),
    path("", include("config.urls")),
]
