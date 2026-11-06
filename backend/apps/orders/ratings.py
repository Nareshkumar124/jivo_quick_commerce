"""Ratings (Phase 7; 06 §2.6 `POST /orders/{id}/rating/`, 07 §2.6 `Rating`, 05 §2 Ratings).

**Customer** (`rate_order`, `rating_body`): after DELIVERED the customer rates the order
(1-5 stars) and, optionally, the rider who delivered it, with tags and a comment. One rating per
order, written once (06 gives no edit window). Contract api-requests #34: an order that is not
DELIVERED or already rated is 400 `VALIDATION_ERROR` (`details.order`, `details.reason`
NOT_DELIVERED / ALREADY_RATED). The order is looked up
in the caller's own orders (another user's order is 404).

Tags (`RatingTag`): the rider tags (`POLITE_RIDER`, `RUDE_RIDER`) are stored on the RIDER row and
need `rider_stars`; the others on the ORDER row, and `ON_TIME` / `LATE_DELIVERY` also on the RIDER
row when the rider is rated (the rider app shows ON_TIME, POLITE_RIDER, LATE_DELIVERY,
RUDE_RIDER). The API returns them merged, without repeats. The app shows positive tags for
4-5 stars and negative ones for 1-3; the server does not enforce that.

**Rider average**: each rider rating recomputes `Rider.rating_avg` (mean of the rider's stars,
one decimal, half up) in the same transaction.

**Rider** (`rider_summary`, `rider_rating_rows`, `rider_rating_item`): the rider's own average,
count, tag counts and ratings paged by `before_id` (stars, tags, date and order number only: no
customer, no comment).

**Staff** (`staff_ratings`, `rider_summary`): `orders.view_rating` (Super Admin, Ops, Support,
Store Manager: own stores), scoped with `stores_for`. `PermissionDenied` without it.

**PII (09):** comments are personal data: never logged; events carry ids and stars only.
"""

import logging
from decimal import ROUND_HALF_UP, Decimal

from django.core.exceptions import PermissionDenied
from django.db import IntegrityError, transaction
from django.db.models import Avg, Count, Q

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.orders.choices import (
    RIDER_RATING_TAGS,
    SHARED_RATING_TAGS,
    OrderStatus,
    RatingTarget,
)
from apps.orders.models import Order, Rating

logger = logging.getLogger(__name__)

VIEW_RATING = "orders.view_rating"
COMMENT_MAX_LENGTH = 500
LOW_RATING_MAX_STARS = 2  # the admin's "low rating" filter (05 §2 Ratings)

MSG_NOT_FOUND = "Order not found."
MSG_NOT_DELIVERED = "You can rate an order once it is delivered."
MSG_ALREADY_RATED = "You have already rated this order."
MSG_NO_RIDER = "This order has no rider to rate."
MSG_RIDER_TAGS = "Rate the rider to use rider tags."
MSG_NOT_RATED = "This order has not been rated."


def _order_rider_id(order: Order) -> int | None:
    from apps.delivery.models import DeliveryTask

    return (
        DeliveryTask.objects.filter(order=order, rider__isnull=False)
        .values_list("rider_id", flat=True)
        .first()
    )


def _rounded_avg(value) -> Decimal | None:
    if value is None:
        return None
    return Decimal(value).quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)


def refresh_rider_average(rider_id: int) -> Decimal | None:
    """Recompute `Rider.rating_avg` from the rider's RIDER ratings (None when there are none)."""
    from apps.delivery.models import Rider

    avg = Rating.objects.filter(target=RatingTarget.RIDER, rider_id=rider_id).aggregate(
        avg=Avg("stars")
    )["avg"]
    value = _rounded_avg(avg)
    Rider.objects.filter(pk=rider_id).update(rating_avg=value)
    return value


def _refused(message: str, reason: str, **extra) -> ApiError:
    return ApiError(
        ErrorCode.VALIDATION_ERROR,
        message,
        details={"order": [message], "reason": reason, **extra},
    )


def own_rating(user, order_id: int) -> dict:
    """`OrderRating` of the caller's order; 404 when the order is not theirs or not rated."""
    rows = list(Rating.objects.filter(order_id=order_id, order__user=user))
    body = rating_body(rows)
    if body is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_NOT_RATED)
    return body


def rate_order(
    user,
    order_id: int,
    *,
    order_stars: int,
    rider_stars: int | None = None,
    tags: list[str] | tuple[str, ...] = (),
    comment: str = "",
) -> list[Rating]:
    """Store the customer's rating of their delivered order (see the module doc)."""
    from apps.orders.services import own_orders

    tags = list(dict.fromkeys(tags))  # keep order, drop repeats
    rider_tags = [tag for tag in tags if tag in RIDER_RATING_TAGS or tag in SHARED_RATING_TAGS]
    order_tags = [tag for tag in tags if tag not in RIDER_RATING_TAGS]
    comment = (comment or "").strip()
    if rider_stars is None and any(tag in RIDER_RATING_TAGS for tag in tags):
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"tags": [MSG_RIDER_TAGS]})
    with transaction.atomic():
        order = own_orders(user).select_for_update().filter(pk=order_id).first()
        if order is None:
            raise ApiError(ErrorCode.NOT_FOUND, MSG_NOT_FOUND)
        if order.status != OrderStatus.DELIVERED:
            raise _refused(MSG_NOT_DELIVERED, "NOT_DELIVERED", status=order.status)
        if Rating.objects.filter(order=order).exists():
            raise _refused(MSG_ALREADY_RATED, "ALREADY_RATED")
        rider_id = _order_rider_id(order) if rider_stars is not None else None
        if rider_stars is not None and rider_id is None:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"rider_stars": [MSG_NO_RIDER]})
        rows = [
            Rating(
                order=order,
                user=user,
                target=RatingTarget.ORDER,
                stars=order_stars,
                tags=order_tags,
                comment=comment,
            )
        ]
        if rider_id is not None:
            rows.append(
                Rating(
                    order=order,
                    user=user,
                    target=RatingTarget.RIDER,
                    rider_id=rider_id,
                    stars=rider_stars,
                    tags=rider_tags,
                )
            )
        try:
            with transaction.atomic():
                created = Rating.objects.bulk_create(rows)
        except IntegrityError as exc:  # pragma: no cover - the order row lock prevents a race
            raise _refused(MSG_ALREADY_RATED, "ALREADY_RATED") from exc
        if rider_id is not None:
            refresh_rider_average(rider_id)
        fields = {
            "order_id": order.pk,
            "order_stars": order_stars,
            "rider_id": rider_id,
            "rider_stars": rider_stars,
        }
        transaction.on_commit(lambda: logger.info("rating event order.rated %s", fields))
    return created


def rating_body(ratings) -> dict | None:
    """The `OrderRating` shape for an order's rating rows (None when not rated)."""
    by_target = {rating.target: rating for rating in ratings}
    order_row = by_target.get(RatingTarget.ORDER)
    if order_row is None:
        return None
    rider_row = by_target.get(RatingTarget.RIDER)
    return {
        "order_stars": order_row.stars,
        "rider_stars": rider_row.stars if rider_row else None,
        "tags": list(dict.fromkeys([*order_row.tags, *(rider_row.tags if rider_row else [])])),
        "comment": order_row.comment,
        "created_at": order_row.created_at,
    }


def can_rate(order: Order, ratings) -> bool:
    return order.status == OrderStatus.DELIVERED and not list(ratings)


# --------------------------------------------------------------------------- rider and staff


def rider_rating_rows(rider_id: int):
    """The rider's RIDER ratings, newest first (`-id`, for `before_id` paging)."""
    return (
        Rating.objects.filter(target=RatingTarget.RIDER, rider_id=rider_id)
        .select_related("order")
        .order_by("-id")
    )


def rider_rating_item(row: Rating) -> dict:
    """One rating as the rider sees it: no customer, no comment."""
    return {
        "id": row.pk,
        "stars": row.stars,
        "tags": list(row.tags or []),
        "rated_at": row.created_at,
        "order_number": row.order.order_number,
    }


def rider_summary(rider_id: int) -> dict:
    """`{rating_avg, ratings_count, tag_counts, distribution}` of the rider's ratings."""
    rows = Rating.objects.filter(target=RatingTarget.RIDER, rider_id=rider_id)
    stats = rows.aggregate(
        avg=Avg("stars"),
        count=Count("id"),
        **{f"s{n}": Count("id", filter=Q(stars=n)) for n in range(1, 6)},
    )
    tag_counts: dict[str, int] = {}
    for tags in rows.values_list("tags", flat=True):
        for tag in tags or []:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1
    avg = _rounded_avg(stats["avg"])
    return {
        "rating_avg": f"{avg}" if avg is not None else None,
        "ratings_count": stats["count"],
        "tag_counts": [
            {"tag": tag, "count": count}
            for tag, count in sorted(tag_counts.items(), key=lambda item: (-item[1], item[0]))
        ],
        "distribution": {str(n): stats[f"s{n}"] for n in range(1, 6)},
    }


def _require_viewer(user) -> None:
    if not (user and user.is_authenticated and user.is_active and user.is_staff):
        raise PermissionDenied("You do not have permission to do this.")
    if not user.has_perm(VIEW_RATING):
        raise PermissionDenied("You do not have permission to do this.")


def staff_ratings(
    user,
    *,
    store_id: int | None = None,
    target: str | None = None,
    max_stars: int | None = None,
    rider_id: int | None = None,
    low_only: bool = False,
):
    """Ratings the staff user may see (05 §2 Ratings): their stores only (`stores_for`),
    newest first, filterable by store, target, rider and stars (`low_only`: at most
    `LOW_RATING_MAX_STARS`)."""
    from apps.stores.services import stores_for

    _require_viewer(user)
    rows = Rating.objects.filter(order__store__in=stores_for(user)).select_related(
        "order", "order__store", "rider", "user"
    )
    if store_id is not None:
        rows = rows.filter(order__store_id=store_id)
    if target is not None:
        rows = rows.filter(target=target)
    if rider_id is not None:
        rows = rows.filter(rider_id=rider_id)
    if low_only:
        max_stars = min(max_stars or LOW_RATING_MAX_STARS, LOW_RATING_MAX_STARS)
    if max_stars is not None:
        rows = rows.filter(stars__lte=max_stars)
    return rows.order_by("-created_at", "-id")


def staff_rider_summary(user, rider_id: int) -> dict:
    """`rider_summary` for the admin's rider page; the rider must be one the user may see
    (home store in `stores_for`; global roles see every rider)."""
    from apps.delivery.models import Rider
    from apps.stores.services import stores_for

    _require_viewer(user)
    stores = stores_for(user)
    visible = Rider.objects.filter(pk=rider_id).filter(
        Q(home_store__in=stores) | Q(home_store__isnull=True, preferred_store__in=stores)
    )
    if not visible.exists():
        raise PermissionDenied("You do not have permission to do this.")
    return rider_summary(rider_id)
