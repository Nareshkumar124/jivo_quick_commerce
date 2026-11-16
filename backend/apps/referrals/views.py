"""Referral endpoints (06 §2.1 "Referral", added 2026-11-13). Customer app only
(`account/` is an app-only group in `apps.accounts.app_access`). Thin: the rules live in
`apps.referrals.services`, and every call is about the caller only (no ids in the URL)."""

from drf_spectacular.utils import extend_schema
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.schema import (
    UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    ok_response,
    request_examples,
    validation_error,
)
from apps.core.throttling import ReferralApplyThrottle
from apps.referrals import examples as ex
from apps.referrals import services
from apps.referrals.choices import ReferralIneligibleReason
from apps.referrals.serializers import ReferralApplySerializer, ReferralSerializer

TAGS = ["account"]


def _body(user) -> dict:
    return ReferralSerializer(services.summary(user)).data


class ReferralView(APIView):
    http_method_names = ["get", "options"]

    @extend_schema(
        operation_id="account_referral_retrieve",
        tags=TAGS,
        summary="My referral code and status",
        description=(
            "The caller's own referral code (created on the first call, never changed), a "
            "ready-made share message, the reward terms (current admin settings), whether the "
            "caller joined with a friend's code, and how many friends joined with theirs.\n\n"
            "When a referred customer's first order is delivered, **both** customers get a "
            "personal coupon (FLAT `reward_amount` off, valid `reward_validity_days` days, one "
            "use, only for them). It appears in `GET /cart/coupons/` with `is_personal: true`."
        ),
        responses=app_responses(
            {
                200: ok_response(
                    ReferralSerializer,
                    "The caller's referral screen.",
                    ("New customer", ex.NEW_CUSTOMER),
                    ("Joined with a code, reward pending", ex.JOINED_PENDING),
                    ("Referrer with friends", ex.REFERRER_WITH_FRIENDS),
                    ("Program paused", ex.PAUSED),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        return Response(_body(request.user))


class ReferralApplyView(APIView):
    http_method_names = ["post", "options"]
    throttle_classes = [ReferralApplyThrottle]

    @extend_schema(
        operation_id="account_referral_apply",
        tags=TAGS,
        summary="Enter a friend's referral code",
        description=(
            "Once per customer, before their first order (an order that reached PLACED; a "
            "failed or abandoned online payment does not count). The code cannot be changed "
            "later. Case and spaces are ignored. Returns the referral screen. Checks, first "
            "failure wins: program off, code already entered, order already placed, unknown "
            "code, own code. Limited to `REFERRAL_APPLY_RATE` per user (default 10 an hour)."
        ),
        request=ReferralApplySerializer,
        examples=request_examples(("Apply", ex.APPLY_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    ReferralSerializer, "Code applied.", ("Applied", ex.JOINED_PENDING)
                ),
                400: error_response(
                    "Missing or blank `code`.",
                    validation_error({"code": ["This field may not be blank."]}),
                ),
                401: UNAUTHORIZED,
                422: error_response(
                    "The code was not applied; nothing changed. `REFERRAL_CODE_INVALID`: unknown "
                    "code, or its owner's account is blocked or deleted. `REFERRAL_SELF`: the "
                    "caller's own code. `REFERRAL_ALREADY_APPLIED`: a code was entered before. "
                    "`REFERRAL_NOT_ELIGIBLE`: `details.reason` is `HAS_ORDERS` (an order was "
                    "already placed) or `PROGRAM_OFF` (the program is paused).",
                    error_example(
                        ErrorCode.REFERRAL_CODE_INVALID,
                        services.MSG_INVALID,
                        {"code": "ZZZZ99"},
                    ),
                    error_example(ErrorCode.REFERRAL_SELF, services.MSG_SELF),
                    error_example(ErrorCode.REFERRAL_ALREADY_APPLIED, services.MSG_ALREADY),
                    error_example(
                        ErrorCode.REFERRAL_NOT_ELIGIBLE,
                        services.MSG_HAS_ORDERS,
                        {"reason": ReferralIneligibleReason.HAS_ORDERS.value},
                        name="REFERRAL_NOT_ELIGIBLE_HAS_ORDERS",
                    ),
                    error_example(
                        ErrorCode.REFERRAL_NOT_ELIGIBLE,
                        services.MSG_PROGRAM_OFF,
                        {"reason": ReferralIneligibleReason.PROGRAM_OFF.value},
                        name="REFERRAL_NOT_ELIGIBLE_PROGRAM_OFF",
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = ReferralApplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.apply_code(request.user, serializer.validated_data["code"])
        return Response(_body(request.user))
