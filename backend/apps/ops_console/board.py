"""Live order board (05 §1.2): read-only queries and the column model. Nothing here writes.

- Store-scoped: `stores_for(user)` first (Store Manager sees only their stores, Ops and Support
  all of them); the store filter can only narrow that further.
- Columns: Placed -> Accepted -> Packing -> Packed -> Out for delivery, plus an exceptions lane
  (payment pending, delivery failed). "Unassigned rider" joins the lane with delivery tasks
  (Phase 5); the card's rider line arrives then too.
- Each column shows its oldest `COLUMN_LIMIT` orders (the most urgent) and the full count, so a
  busy store never renders thousands of cards. Two queries in all: counts, then cards (a window
  function ranks orders inside each status), whatever the number of orders.
- Cards carry no customer data (05 §1.2 card: order no., store, age, items, payment type,
  rider), so the board is the same for full-PII and limited roles.
"""

from dataclasses import dataclass, field
from datetime import datetime

from django import forms
from django.db.models import Count, F, IntegerField, OuterRef, Subquery, Sum, Value, Window
from django.db.models.functions import Coalesce, RowNumber
from django.utils import timezone
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldBooleanWidget

from apps.ops_console import sla
from apps.ops_console.scoping import is_store_scoped, scope_to_stores, visible_stores
from apps.orders.choices import OrderStatus, PaymentMethod
from apps.orders.models import Order, OrderItem

COLUMN_LIMIT = 50

COLUMNS = (
    (OrderStatus.PLACED, "Placed"),
    (OrderStatus.ACCEPTED, "Accepted"),
    (OrderStatus.PACKING, "Packing"),
    (OrderStatus.PACKED, "Packed"),
    (OrderStatus.OUT_FOR_DELIVERY, "Out for delivery"),
)
EXCEPTIONS = (
    (OrderStatus.PAYMENT_PENDING, "Payment pending"),
    (OrderStatus.DELIVERY_FAILED, "Delivery failed"),
)
BOARD_STATUSES = tuple(code for code, _ in (*COLUMNS, *EXCEPTIONS))

# 08 T12: store manager / ops / support may cancel before pickup.
CANCELLABLE_STATUSES = frozenset(
    {OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PACKING, OrderStatus.PACKED}
)

CARD_FIELDS = (
    "id",
    "order_number",
    "pickup_code",
    "status",
    "payment_method",
    "payment_status",
    "store_id",
    "store__code",
    "store__name",
    "created_at",
    "placed_at",
    "eta_at",
    "payment_expires_at",
    "grand_total",
)


class BoardFilterForm(forms.Form):
    store = forms.ChoiceField(label="Store", required=False, widget=UnfoldAdminSelectWidget)
    payment = forms.ChoiceField(
        label="Payment",
        required=False,
        choices=[("", "All"), *PaymentMethod.choices],
        widget=UnfoldAdminSelectWidget,
    )
    breached = forms.BooleanField(
        label="SLA breached only", required=False, widget=UnfoldBooleanWidget
    )

    def __init__(self, *args, stores=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["store"].choices = [("", "All my stores")] + [
            (str(store.pk), f"{store.code} {store.name}") for store in stores
        ]


def units_subquery():
    """Units still in the order (ordered less unavailable), as a correlated subquery so the
    card query needs no GROUP BY."""
    units = (
        OrderItem.objects.filter(order=OuterRef("pk"))
        .order_by()
        .values("order")
        .annotate(units=Sum(F("quantity") - F("quantity_unavailable")))
        .values("units")
    )
    return Coalesce(Subquery(units, output_field=IntegerField()), Value(0))


@dataclass
class Card:
    order: Order
    timer: sla.Timer
    units: int
    cancellable: bool


@dataclass
class Column:
    code: str
    title: str
    count: int = 0
    cards: list[Card] = field(default_factory=list)

    @property
    def hidden(self) -> int:
        return max(self.count - len(self.cards), 0)


@dataclass
class Board:
    columns: list[Column]
    exceptions: list[Column]
    total: int
    breached: int
    scoped: bool
    generated_at: datetime


def base_queryset(user):
    return scope_to_stores(Order.objects.filter(status__in=BOARD_STATUSES), user)


def filtered(user, data) -> tuple[BoardFilterForm, object]:
    """The filter form (bound to `data`) and the scoped, filtered queryset. Invalid values are
    ignored (shown as field errors), like the data tables."""
    stores = list(visible_stores(user).only("pk", "code", "name").order_by("code"))
    form = BoardFilterForm(data or None, stores=stores)
    queryset = base_queryset(user)
    if form.is_bound:
        form.is_valid()
        cleaned = getattr(form, "cleaned_data", {})
        if cleaned.get("store"):
            queryset = queryset.filter(store_id=int(cleaned["store"]))
        if cleaned.get("payment"):
            queryset = queryset.filter(payment_method=cleaned["payment"])
        if cleaned.get("breached"):
            queryset = queryset.filter(sla.breached_q())
    return form, queryset


def build(user, queryset, now: datetime | None = None, limit: int = COLUMN_LIMIT) -> Board:
    now = now or timezone.now()
    counts = dict(
        queryset.order_by()
        .values_list("status")
        .annotate(total=Count("pk"))
        .values_list("status", "total")
    )
    ranked = (
        queryset.annotate(
            units=units_subquery(),
            rank=Window(
                RowNumber(),
                partition_by=[F("status")],
                order_by=[F("placed_at").asc(nulls_last=True), F("created_at").asc()],
            ),
        )
        .filter(rank__lte=limit)
        .select_related("store")
        .only(*CARD_FIELDS)
        .order_by("placed_at", "created_at", "pk")
    )
    by_status: dict[str, list[Card]] = {code: [] for code in BOARD_STATUSES}
    breached = 0
    for order in ranked:
        card = Card(
            order=order,
            timer=sla.timer_for(order, now),
            units=order.units,
            cancellable=order.status in CANCELLABLE_STATUSES,
        )
        breached += card.timer.breached
        by_status[order.status].append(card)

    def column(code, title) -> Column:
        return Column(code, title, counts.get(code, 0), by_status[code])

    return Board(
        columns=[column(code, title) for code, title in COLUMNS],
        exceptions=[column(code, title) for code, title in EXCEPTIONS],
        total=sum(counts.values()),
        breached=breached,
        scoped=is_store_scoped(user),
        generated_at=now,
    )
