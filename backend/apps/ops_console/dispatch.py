"""Read-only selectors for the Ops dispatch screens (05 §1.4, slice 5.3) and the store's returns
page (05 §1.3 "Returns", 08 T14).

Everything starts from the user's stores (`stores_for`), so another store's task, offer, rider or
order simply does not exist here (404, never "found, then refused"). Nothing in this module
writes: assign / unassign / retry and T14 go through `order_actions` -> the backend services.

Codes are never read: the pickup code and the delivery OTP show only as "locked" / attempts left
(`delivery.services.tasks.*_attempts_remaining`), and the encrypted OTP column is never loaded.
"""

from dataclasses import dataclass, field
from datetime import datetime

from django.db.models import Exists, OuterRef, Prefetch, QuerySet
from django.utils import timezone

from apps.accounts.choices import RiderStatus
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import RIDER_BUSY_STATUSES, DeliveryOffer, DeliveryTask, Rider
from apps.orders.choices import OrderStatus, PaymentMethod
from apps.orders.models import Order
from apps.stores.services import haversine_km, stores_for

WAITING = (TS.SEARCHING, TS.OFFERED, TS.UNASSIGNED)
ON_ROAD = (TS.ASSIGNED, TS.AT_STORE, TS.PICKED_UP, TS.AT_CUSTOMER, TS.FAILED, TS.RETURNING)
ASSIGNABLE = frozenset(WAITING)  # dispatch.manual_assign accepts these task states
UNASSIGNABLE = frozenset({TS.ASSIGNED, TS.AT_STORE})  # dispatch.unassign
RETRYABLE = frozenset({TS.UNASSIGNED})  # dispatch.retry_dispatch
DISPATCHABLE_ORDERS = frozenset(
    {OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PACKING, OrderStatus.PACKED}
)
LIST_LIMIT = 100  # per board section; the admin lists hold the rest

# The encrypted delivery OTP never leaves the database on these screens.
TASK_SECRETS = ("delivery_otp_encrypted",)


def scoped_tasks(user) -> QuerySet[DeliveryTask]:
    return DeliveryTask.objects.filter(store__in=stores_for(user)).defer(*TASK_SECRETS)


def _store_filter(queryset: QuerySet, store_id: int | None, field_name: str = "store_id"):
    return queryset.filter(**{field_name: store_id}) if store_id else queryset


def _km(rider: Rider, store) -> float | None:
    if rider.current_location is None or store is None or store.location is None:
        return None
    point = rider.current_location
    return round(haversine_km(point.y, point.x, store.location.y, store.location.x), 2)


def _age_seconds(moment: datetime | None, now: datetime) -> int | None:
    return int((now - moment).total_seconds()) if moment else None


# --------------------------------------------------------------------------- board


@dataclass
class RiderRow:
    rider: Rider
    km: float | None  # straight line to the rider's home store
    ping_age: int | None  # seconds since the last location reached the server
    task: DeliveryTask | None
    pending_offer: bool = False


@dataclass
class Board:
    waiting: list[DeliveryTask]
    offers: list[DeliveryOffer]
    on_road: list[DeliveryTask]
    riders: list[RiderRow]
    generated_at: datetime
    truncated: dict[str, bool] = field(default_factory=dict)
    unassigned: int = 0


def _limited(queryset, name: str, truncated: dict) -> list:
    rows = list(queryset[: LIST_LIMIT + 1])
    truncated[name] = len(rows) > LIST_LIMIT
    return rows[:LIST_LIMIT]


def online_riders(user, store_id: int | None = None, now=None) -> list[RiderRow]:
    now = now or timezone.now()
    riders = _store_filter(
        Rider.objects.filter(is_online=True, home_store__in=stores_for(user)),
        store_id,
        "home_store_id",
    ).select_related("home_store")
    riders = riders.annotate(
        has_offer=Exists(
            DeliveryOffer.objects.filter(rider=OuterRef("pk"), status=OfferStatus.PENDING)
        )
    ).order_by("home_store__code", "full_name", "pk")
    rows = list(riders[: LIST_LIMIT + 1])
    busy = {
        task.rider_id: task
        for task in DeliveryTask.objects.filter(
            rider__in=[r.pk for r in rows], status__in=RIDER_BUSY_STATUSES
        )
        .defer(*TASK_SECRETS)
        .select_related("order")
    }
    return [
        RiderRow(
            rider=rider,
            km=_km(rider, rider.home_store),
            ping_age=_age_seconds(rider.last_location_received_at, now),
            task=busy.get(rider.pk),
            pending_offer=rider.has_offer,
        )
        for rider in rows[:LIST_LIMIT]
    ]


def board(user, store_id: int | None = None, now=None) -> Board:
    now = now or timezone.now()
    tasks = _store_filter(scoped_tasks(user), store_id)
    truncated: dict[str, bool] = {}
    pending = Prefetch(
        "offers",
        queryset=DeliveryOffer.objects.filter(status=OfferStatus.PENDING).select_related("rider"),
        to_attr="pending_offers",
    )
    waiting = _limited(
        tasks.filter(status__in=WAITING)
        .select_related("order", "store")
        .prefetch_related(pending)
        .order_by("search_started_at", "pk"),
        "waiting",
        truncated,
    )
    offers = _limited(
        _store_filter(
            DeliveryOffer.objects.filter(
                status=OfferStatus.PENDING, task__store__in=stores_for(user)
            ),
            store_id,
            "task__store_id",
        )
        .select_related("rider", "task__order", "task__store")
        .defer(*(f"task__{name}" for name in TASK_SECRETS))
        .order_by("expires_at", "pk"),
        "offers",
        truncated,
    )
    on_road = _limited(
        tasks.filter(status__in=ON_ROAD)
        .select_related("order", "store", "rider")
        .order_by("assigned_at", "pk"),
        "on_road",
        truncated,
    )
    riders = online_riders(user, store_id, now)
    return Board(
        waiting=waiting,
        offers=offers,
        on_road=on_road,
        riders=riders,
        generated_at=now,
        truncated=truncated,
        unassigned=sum(1 for task in waiting if task.status == TS.UNASSIGNED),
    )


# --------------------------------------------------------------------------- task detail


@dataclass
class Candidate:
    rider: Rider
    km: float | None
    ping_age: int | None
    within_cash_limit: bool
    pending_offer: bool


@dataclass
class TaskDetail:
    task: DeliveryTask
    order: Order
    timeline: list[tuple[str, datetime]]
    offers: list[DeliveryOffer]
    pickup_locked: bool
    pickup_attempts_left: int | None
    otp_locked: bool
    otp_attempts_left: int | None
    can_assign: bool
    can_unassign: bool
    can_retry: bool
    candidates: list[Candidate]


TIMELINE_FIELDS = (
    ("search_started_at", "Search started (current round)"),
    ("unassigned_at", "No rider found (unassigned)"),
    ("assigned_at", "Rider assigned"),
    ("arrived_store_at", "Rider at the store"),
    ("picked_up_at", "Picked up"),
    ("arrived_customer_at", "Rider at the drop location"),
    ("delivered_at", "Delivered"),
    ("failed_at", "Delivery failed"),
    ("returned_at", "Items returned to the store"),
    ("cancelled_at", "Cancelled"),
)


def _attempts_left(name: str, task: DeliveryTask) -> int | None:
    from apps.delivery.services import tasks as task_services

    function = getattr(task_services, name, None)
    return function(task) if function else None


def candidates(task: DeliveryTask, order: Order, now=None) -> list[Candidate]:
    """Riders ops may pick for a manual assignment (08 §5 step 7), nearest first: ACTIVE, online,
    of the task's store, not on another delivery. COD orders flag riders over the cash limit (the
    service refuses them with CASH_LIMIT_EXCEEDED). The service re-checks everything."""
    now = now or timezone.now()
    busy = DeliveryTask.objects.filter(rider=OuterRef("pk"), status__in=RIDER_BUSY_STATUSES)
    pending = DeliveryOffer.objects.filter(rider=OuterRef("pk"), status=OfferStatus.PENDING)
    riders = (
        Rider.objects.filter(status=RiderStatus.ACTIVE, is_online=True, home_store_id=task.store_id)
        .exclude(Exists(busy))
        .annotate(has_offer=Exists(pending))
        .order_by("pk")[:LIST_LIMIT]
    )
    cod = order.payment_method == PaymentMethod.COD
    rows = [
        Candidate(
            rider=rider,
            km=_km(rider, task.store),
            ping_age=_age_seconds(rider.last_location_received_at, now),
            within_cash_limit=not cod or rider.cash_in_hand + order.grand_total <= rider.cash_limit,
            pending_offer=rider.has_offer,
        )
        for rider in riders
    ]
    return sorted(rows, key=lambda row: (row.km is None, row.km or 0, row.rider.pk))


def task_detail(task: DeliveryTask, now=None) -> TaskDetail:
    order = task.order
    timeline = sorted(
        ((label, getattr(task, name)) for name, label in TIMELINE_FIELDS if getattr(task, name)),
        key=lambda item: item[1],
    )
    offers = list(task.offers.select_related("rider").order_by("-offered_at", "-pk"))
    can_assign = task.status in ASSIGNABLE and order.status in DISPATCHABLE_ORDERS
    return TaskDetail(
        task=task,
        order=order,
        timeline=timeline,
        offers=offers,
        pickup_locked=task.pickup_locked_at is not None,
        pickup_attempts_left=_attempts_left("pickup_attempts_remaining", task),
        otp_locked=task.otp_locked_at is not None,
        otp_attempts_left=_attempts_left("otp_attempts_remaining", task),
        can_assign=can_assign,
        can_unassign=task.status in UNASSIGNABLE,
        can_retry=task.status in RETRYABLE,
        candidates=candidates(task, order, now) if can_assign else [],
    )


def task_for(user, task_id: int) -> DeliveryTask | None:
    return (
        scoped_tasks(user)
        .select_related("order", "store", "rider__user")
        .filter(pk=task_id)
        .first()
    )


# --------------------------------------------------------------------------- returns (T14)


@dataclass
class ReturnLine:
    item: object
    units: int  # units that went out with the rider (ordered - unavailable)


@dataclass
class ReturnRow:
    order: Order
    task: DeliveryTask | None
    lines: list[ReturnLine]
    ready: bool  # task RETURNING: the service accepts T14 now


def returns(store, order_id: int | None = None) -> list[ReturnRow]:
    """Failed deliveries of `store` (already scoped by the caller) waiting to be received back."""
    orders = returnable_orders(store)
    if order_id is not None:
        orders = orders.filter(pk=order_id)
    orders = (
        orders.select_related("delivery_task__rider")
        .defer(*(f"delivery_task__{name}" for name in TASK_SECRETS))
        .prefetch_related("items")
        .order_by("updated_at", "pk")[:LIST_LIMIT]
    )
    rows = []
    for order in orders:
        task = getattr(order, "delivery_task", None)
        lines = [
            ReturnLine(item=item, units=item.quantity - item.quantity_unavailable)
            for item in order.items.all()
            if item.quantity > item.quantity_unavailable
        ]
        rows.append(
            ReturnRow(
                order=order,
                task=task,
                lines=lines,
                ready=task is not None and task.status == TS.RETURNING,
            )
        )
    return rows


def returnable_orders(store) -> QuerySet[Order]:
    return Order.objects.filter(store=store, status=OrderStatus.DELIVERY_FAILED)
