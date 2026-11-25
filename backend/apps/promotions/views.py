"""Rewards endpoint (ADR 0002, `GET /account/rewards/`). Customer app only (`account/` is an
app-only group in `apps.accounts.app_access`). Thin: the rules live in
`apps.promotions.rewards`, and the call is about the caller only (no ids in the URL)."""

from drf_spectacular.utils import extend_schema
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.schema import UNAUTHORIZED, app_responses, ok_response
from apps.promotions import examples as ex
from apps.promotions import rewards
from apps.promotions.serializers import RewardsSerializer


class RewardsView(APIView):
    http_method_names = ["get", "options"]

    @extend_schema(
        operation_id="account_rewards_retrieve",
        tags=["account"],
        summary="My free-carton rewards",
        description=(
            "ADR 0002: the caller's free-carton rewards (welcome and referral) and their "
            "history. A reward is a personal coupon with `discount_type` FREE_UNIT: tap **Use**, "
            "let the customer pick a size, then `POST /cart/coupon/` with `code` and "
            "`free_variant_id`. One reward or one coupon per order; the order still needs the "
            "store's minimum paid cartons. USED and EXPIRED rewards are only in `history`."
        ),
        responses=app_responses(
            {
                200: ok_response(
                    RewardsSerializer,
                    "The caller's rewards.",
                    ("Rewards", ex.REWARDS),
                    ("No rewards", ex.REWARDS_EMPTY),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        return Response(RewardsSerializer(rewards.rewards_body(request.user)).data)
