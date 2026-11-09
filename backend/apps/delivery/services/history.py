"""The rider's past tasks (04 §2.8, 06 §3 #22/#24; slice 5.4).

Only the caller's own ended tasks (DELIVERED, RETURNED, CANCELLED with this rider): another
rider's task id is a 404. Paged by `before_id` (newest id first), so new entries never shift a
page. The detail carries no customer personal data (no name, phone or full address once the
task has ended: 09 §3 minimisation): the drop locality only.
"""

from django.db.models import Prefetch, Sum

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import money_str
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryTask, RiderEarning
from apps.delivery.services import earnings
from apps.delivery.services.presenters import _cod_amount, _locality, _payment_type

ENDED = (TS.DELIVERED, TS.RETURNED, TS.CANCELLED)
MSG_NOT_FOUND = "Task not found."


def history(rider, *, start=None, end=None):
    tasks = (
        DeliveryTask.objects.filter(rider=rider, status__in=ENDED, ended_at__isnull=False)
        .select_related("order", "store")
        .annotate(earned=Sum("earnings__amount"))
        .order_by("-pk")
    )
    if start or end:
        since, until = earnings.day_bounds(start or end, end or start)
        if start:
            tasks = tasks.filter(ended_at__gte=since)
        if end:
            tasks = tasks.filter(ended_at__lt=until)
    return tasks


def item_body(task) -> dict:
    earned = task.earned
    return {
        "task_id": task.pk,
        "order_number": task.order.order_number,
        "status": task.status,
        "store_name": task.store.name,
        "drop_locality": _locality(task.order),
        "distance_km": str(task.distance_km) if task.picked_up_at else None,
        "payout": money_str(earned) if earned else None,
        "completed_at": task.ended_at,
    }


def detail(rider, task_id: int) -> dict:
    task = (
        history(rider)
        .prefetch_related(
            "order__items", Prefetch("earnings", queryset=RiderEarning.objects.order_by("pk"))
        )
        .filter(pk=task_id)
        .first()
    )
    if task is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_NOT_FOUND)
    order = task.order
    items = [
        {
            "name": item.product_name,
            "variant": item.variant_name,
            "quantity": item.quantity - item.quantity_unavailable,
        }
        for item in order.items.all()
        if item.quantity > item.quantity_unavailable
    ]
    collected = None
    if task.status == TS.DELIVERED and _cod_amount(order) is not None:
        collected = money_str(order.grand_total)
    return {
        **item_body(task),
        "payment_type": _payment_type(order),
        "cod_collected": collected,
        "items": items,
        "item_count": sum(item["quantity"] for item in items),
        "assigned_at": task.assigned_at,
        "picked_up_at": task.picked_up_at,
        "delivered_at": task.delivered_at,
        "failed_at": task.failed_at,
        "fail_reason": task.fail_reason or None,
        "returned_at": task.returned_at,
        "cancelled_at": task.cancelled_at,
        "earnings": earnings.task_earnings_body(list(task.earnings.all())),
    }
