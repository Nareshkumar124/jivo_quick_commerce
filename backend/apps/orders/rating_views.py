"""Phase 7 rating endpoints (06 §2.6 `POST /orders/{id}/rating/`; the rider's own summary).

Thin views: validate, call `apps.orders.ratings`, render. The order is looked up in the caller's
own orders (another user's order is 404); the rider summary is always the caller's own.
"""

from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
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
from apps.orders import examples as ex
from apps.orders import ratings
from apps.orders.serializers import (
    OrderRatingCreateSerializer,
    OrderRatingSerializer,
    RiderRatingsPageSerializer,
)
from apps.orders.views import ORDER_ID, ORDER_NOT_FOUND

RATING_NOT_FOUND = error_response(
    "The order does not exist, is not the caller's, or has not been rated.",
    error_example(ErrorCode.NOT_FOUND, ratings.MSG_NOT_RATED, name="NOT_RATED"),
    error_example(ErrorCode.NOT_FOUND, "Order not found.", name="ORDER_NOT_FOUND"),
)


class RiderRatingsQuerySerializer(serializers.Serializer):
    before_id = serializers.IntegerField(required=False, min_value=1)


class OrderRatingView(APIView):
    @extend_schema(
        operation_id="orders_rating_retrieve",
        tags=["orders"],
        summary="My rating of an order",
        description=(
            "Phase 7 (api-requests #34). The caller's rating of their order, or 404 when it is "
            "not rated yet (or not the caller's order). The order detail carries the same data "
            "in `rating`."
        ),
        parameters=[ORDER_ID],
        responses=app_responses(
            {
                200: ok_response(
                    OrderRatingSerializer,
                    "The rating.",
                    ("Order and rider", ex.RATING),
                    ("Order only", ex.RATING_ORDER_ONLY),
                ),
                401: UNAUTHORIZED,
                404: RATING_NOT_FOUND,
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        return Response(ratings.own_rating(request.user, id))

    @extend_schema(
        operation_id="orders_rating_create",
        tags=["orders"],
        summary="Rate my delivered order",
        description=(
            "Phase 7 (api-requests #34). Once the order is DELIVERED (`can_rate`), the customer "
            "rates the order (`order_stars` 1-5) and optionally the rider who delivered it "
            "(`rider_stars`), with tags and a comment (at most 500 characters). One rating per "
            "order; it cannot be changed. An order not DELIVERED or already rated is 400 "
            "`VALIDATION_ERROR` with `details.order` and `details.reason` (NOT_DELIVERED / "
            "ALREADY_RATED). POLITE_RIDER / RUDE_RIDER need `rider_stars`; `rider_stars` on an "
            "order without a rider is 400. The order detail then shows it in `rating`."
        ),
        parameters=[ORDER_ID],
        request=OrderRatingCreateSerializer,
        examples=request_examples(
            ("Order and rider", ex.RATING_REQUEST),
            ("Order only", ex.RATING_ORDER_ONLY_REQUEST),
        ),
        responses=app_responses(
            {
                201: ok_response(
                    OrderRatingSerializer,
                    "The rating as stored.",
                    ("Order and rider", ex.RATING),
                    ("Order only", ex.RATING_ORDER_ONLY),
                ),
                400: error_response(
                    "Invalid stars, unknown tag, comment too long, rider tags without "
                    "`rider_stars`, `rider_stars` for an order without a rider, an order that "
                    "is not DELIVERED, or one already rated.",
                    validation_error(
                        {"order_stars": ["Ensure this value is less than or equal to 5."]},
                        name="Stars out of range",
                    ),
                    validation_error({"tags": [ratings.MSG_RIDER_TAGS]}, name="Rider tags"),
                    validation_error({"rider_stars": [ratings.MSG_NO_RIDER]}, name="No rider"),
                    error_example(
                        ErrorCode.VALIDATION_ERROR,
                        ratings.MSG_NOT_DELIVERED,
                        {
                            "order": [ratings.MSG_NOT_DELIVERED],
                            "reason": "NOT_DELIVERED",
                            "status": "OUT_FOR_DELIVERY",
                        },
                        name="NOT_DELIVERED",
                    ),
                    error_example(
                        ErrorCode.VALIDATION_ERROR,
                        ratings.MSG_ALREADY_RATED,
                        {"order": [ratings.MSG_ALREADY_RATED], "reason": "ALREADY_RATED"},
                        name="ALREADY_RATED",
                    ),
                ),
                401: UNAUTHORIZED,
                404: ORDER_NOT_FOUND,
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        data = OrderRatingCreateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        ratings.rate_order(
            request.user,
            id,
            order_stars=values["order_stars"],
            rider_stars=values.get("rider_stars"),
            tags=values.get("tags", []),
            comment=values.get("comment", ""),
        )
        return Response(ratings.own_rating(request.user, id), status=201)


RIDER_RATINGS_PARAMETERS = [
    OpenApiParameter(
        "before_id",
        int,
        description="Return ratings older than this rating id (from `next`).",
        required=False,
    ),
    OpenApiParameter(
        "page_size", int, description="Items per page: default 20, max 100.", required=False
    ),
]


class RiderRatingsView(APIView):
    @extend_schema(
        operation_id="rider_ratings_list",
        tags=["rider"],
        summary="My ratings",
        description=(
            "Phase 7 (rider app request). The caller's average rating (`rating_avg`, also in "
            "`GET /rider/me/`), the number of ratings, the tags customers chose for the rider "
            "(ON_TIME, POLITE_RIDER, LATE_DELIVERY, RUDE_RIDER) and the ratings themselves, newest "
            "first, paged by `before_id` (follow `next`). Customer names, phones, addresses and "
            "comments are never shown to riders. Any rider status."
        ),
        parameters=RIDER_RATINGS_PARAMETERS,
        responses=app_responses(
            {
                200: ok_response(
                    RiderRatingsPageSerializer,
                    "A page.",
                    ("Rated", ex.RIDER_RATINGS),
                    ("No ratings yet", ex.RIDER_RATINGS_EMPTY),
                ),
                400: error_response(
                    "Invalid `before_id`.",
                    validation_error({"before_id": ["A valid integer is required."]}),
                ),
                401: UNAUTHORIZED,
                403: error_response(
                    "The caller has no rider profile (`details.rider_status` = NONE).",
                    error_example(
                        ErrorCode.PERMISSION_DENIED,
                        "Register as a rider first.",
                        {"rider_status": "NONE"},
                        name="NOT_A_RIDER",
                    ),
                ),
            }
        ),
    )
    def get(self, request: Request) -> Response:
        from rest_framework.utils.urls import replace_query_param

        from apps.core.pagination import StandardPagination
        from apps.delivery.services import riders

        rider = riders.require_rider(request.user)
        query = RiderRatingsQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        before_id = query.validated_data.get("before_id")
        size = StandardPagination().get_page_size(request)
        rows = ratings.rider_rating_rows(rider.pk)
        if before_id:
            rows = rows.filter(pk__lt=before_id)
        page = list(rows[: size + 1])
        more, page = len(page) > size, page[:size]
        summary = ratings.rider_summary(rider.pk)
        return Response(
            {
                "rating_avg": summary["rating_avg"],
                "ratings_count": summary["ratings_count"],
                "tag_counts": summary["tag_counts"],
                "results": [ratings.rider_rating_item(row) for row in page],
                "next": replace_query_param(request.build_absolute_uri(), "before_id", page[-1].pk)
                if more and page
                else None,
            }
        )
