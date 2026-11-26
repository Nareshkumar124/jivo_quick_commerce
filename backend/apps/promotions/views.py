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
from apps.stores.context import optional_store_id
from apps.stores.schema import OPTIONAL_STORE_ID_PARAMETER


class RewardsView(APIView):
    http_method_names = ["get", "options"]

    @extend_schema(
        operation_id="account_rewards_retrieve",
        tags=["account"],
        summary="My free-carton rewards",
        description=(
            "ADR 0002/0003: the caller's free-carton rewards (welcome and referral) and their "
            "history. A reward is a personal coupon with `discount_type` FREE_UNIT giving "
            "`quantity` free cartons. Tap **Use**: when `free_variant` is set (the store's fixed "
            "free size, ADR 0003) send `POST /cart/coupon/` with `code` only; else let the "
            "customer pick a size and send `code` and `free_variant_id`. One reward or one "
            "coupon per order; the order still needs the store's minimum paid cartons. USED and "
            "EXPIRED rewards are only in `history`."
        ),
        parameters=[OPTIONAL_STORE_ID_PARAMETER],
        responses=app_responses(
            {
                200: ok_response(
                    RewardsSerializer,
                    "The caller's rewards.",
                    ("Rewards", ex.REWARDS),
                    ("Store without a fixed free size", ex.REWARDS_NO_FIXED_SIZE),
                    ("No rewards", ex.REWARDS_EMPTY),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        store_id = rewards.store_for_rewards(request.user, optional_store_id(request))
        return Response(
            RewardsSerializer(rewards.rewards_body(request.user, store_id=store_id)).data
        )
