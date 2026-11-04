"""Store packing console (05 §1.3, returns excepted): read-only queries. Nothing here writes;
the buttons go through `order_actions`.

- One store per screen. The store is looked up inside `stores_for(user)` (another store is a
  404), and every order inside that store's queryset (another store's order is a 404 too).
- Queues: New (PLACED, countdown to the acceptance SLA), Accepted, Packing (pick list), Packed
  (waiting for the rider). Each queue shows its oldest `QUEUE_LIMIT` orders and its count.
- Pick list lines: product, variant, SKU, quantity, units already marked unavailable and the
  rack location of the store's stock row (`StoreInventory.rack_location`, when set).
- The packing screen never shows the customer's phone or address: the slip carries the order
  number, the 4-character pickup code, a QR code of that code and the item count (05 §1.3
  "Print").
"""

from dataclasses import dataclass, field
from datetime import datetime

from django.db.models import OuterRef, Prefetch, Subquery
from django.shortcuts import get_object_or_404
from django.utils import timezone

from apps.inventory.models import StoreInventory
from apps.ops_console import sla
from apps.ops_console.board import CANCELLABLE_STATUSES, units_subquery
from apps.ops_console.scoping import visible_stores
from apps.orders.choices import OrderStatus
from apps.orders.models import Order, OrderItem

QUEUE_LIMIT = 30

QUEUES = (
    (OrderStatus.PLACED, "New orders"),
    (OrderStatus.ACCEPTED, "Accepted: to pack"),
    (OrderStatus.PACKING, "Packing"),
    (OrderStatus.PACKED, "Packed: waiting for the rider"),
)
QUEUE_STATUSES = tuple(code for code, _ in QUEUES)
# 08 T8a: items can be marked unavailable while ACCEPTED or PACKING (before PACKED).
ADJUSTABLE_STATUSES = frozenset({OrderStatus.ACCEPTED, OrderStatus.PACKING})
PRINTABLE_STATUSES = frozenset({OrderStatus.PACKING, OrderStatus.PACKED})


def store_for(user, code: str):
    """The user's store with this code, or 404 (never fetch, then check)."""
    return get_object_or_404(visible_stores(user), code=code)


def store_orders(store):
    return Order.objects.filter(store=store)


def order_for(store, order_id: int, statuses=QUEUE_STATUSES) -> Order:
    return get_object_or_404(store_orders(store).filter(status__in=statuses), pk=order_id)


def lines_queryset(store):
    rack = StoreInventory.objects.filter(store=store, variant=OuterRef("variant_id")).values(
        "rack_location"
    )[:1]
    return (
        OrderItem.objects.annotate(rack=Subquery(rack))
        .only(
            "id",
            "order_id",
            "variant_id",
            "product_name",
            "variant_name",
            "sku",
            "quantity",
            "quantity_unavailable",
        )
        .order_by("rack", "product_name", "id")
    )


@dataclass
class Ticket:
    order: Order
    timer: sla.Timer
    units: int
    lines: list[OrderItem]
    adjustable: bool
    cancellable: bool
    printable: bool

    @property
    def pick_ids(self) -> list[str]:
        """Lines with units left to pick (fully unavailable lines need no tick)."""
        return [str(line.pk) for line in self.lines if line.quantity > line.quantity_unavailable]


@dataclass
class Queue:
    code: str
    title: str
    count: int = 0
    tickets: list[Ticket] = field(default_factory=list)

    @property
    def hidden(self) -> int:
        return max(self.count - len(self.tickets), 0)


@dataclass
class Console:
    store: object
    queues: list[Queue]
    generated_at: datetime

    @property
    def new_order_ids(self) -> list[int]:
        return [ticket.order.pk for ticket in self.queues[0].tickets]


def build(store, now: datetime | None = None, limit: int = QUEUE_LIMIT) -> Console:
    """Four queries in all: counts, orders (ranked per queue), their lines (with rack)."""
    from django.db.models import Count, F, Window
    from django.db.models.functions import RowNumber

    now = now or timezone.now()
    base = store_orders(store).filter(status__in=QUEUE_STATUSES)
    counts = dict(
        base.order_by()
        .values_list("status")
        .annotate(total=Count("pk"))
        .values_list("status", "total")
    )
    orders = (
        base.annotate(
            units=units_subquery(),
            rank=Window(
                RowNumber(),
                partition_by=[F("status")],
                order_by=[F("placed_at").asc(nulls_last=True), F("created_at").asc()],
            ),
        )
        .filter(rank__lte=limit)
        .prefetch_related(Prefetch("items", queryset=lines_queryset(store), to_attr="lines"))
        .order_by("placed_at", "created_at", "pk")
    )
    by_status: dict[str, list[Ticket]] = {code: [] for code in QUEUE_STATUSES}
    for order in orders:
        by_status[order.status].append(
            Ticket(
                order=order,
                timer=sla.timer_for(order, now),
                units=order.units,
                lines=order.lines,
                adjustable=order.status in ADJUSTABLE_STATUSES,
                cancellable=order.status in CANCELLABLE_STATUSES,
                printable=order.status in PRINTABLE_STATUSES,
            )
        )
    return Console(
        store=store,
        queues=[Queue(code, title, counts.get(code, 0), by_status[code]) for code, title in QUEUES],
        generated_at=now,
    )


def slip(store, order_id: int) -> Order:
    """The order for the printed slip / bag label (PACKING or PACKED), with its lines."""
    return (
        store_orders(store)
        .filter(status__in=PRINTABLE_STATUSES)
        .annotate(units=units_subquery())
        .select_related("store")
        .prefetch_related(Prefetch("items", queryset=lines_queryset(store), to_attr="lines"))
        .filter(pk=order_id)
        .first()
    )


def low_stock_count(store) -> int:
    """Stock alerts for the store switch area (05 §1.3): on-sale rows below their threshold,
    as the dashboard counts them (`selectors.stock_stats`)."""
    from apps.ops_console.selectors import stock_stats
    from apps.stores.models import DarkStore

    return stock_stats(DarkStore.objects.filter(pk=store.pk)).low
