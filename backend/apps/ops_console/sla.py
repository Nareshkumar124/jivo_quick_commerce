"""SLA timers for the live order board and the packing console (05 §1.2, §1.3).

Each active order has one **deadline** that its card counts against:
- `PAYMENT_PENDING`: the end of the payment window (`payment_expires_at`).
- `PLACED`: the store-acceptance SLA, `placed_at + ORDER_ACCEPTANCE_SLA_SECONDS` (05 §1.1
  "orders waiting > 2 min for store acceptance").
- `ACCEPTED` to `OUT_FOR_DELIVERY`: the delivery time promised to the customer (`eta_at`).
- `DELIVERY_FAILED`: none; the exceptions lane is already an alert.

Tone: `danger` once the deadline has passed, `warning` in the last `OPS_SLA_WARNING_FRACTION`
of the time between the start (placed, or created for unpaid orders) and the deadline,
otherwise `success`. The page's script (`ops/js/orders.js`) recomputes the tone every second from
the same `data-*` timestamps, so a card turns amber or red between polls.

Thresholds are settings, never constants in templates. `ORDER_ACCEPTANCE_SLA_SECONDS` is the
backend's setting for the acceptance SLA alert (Phase 4); until it exists the 05 §1.1 value
applies (reported under "APIs required").
"""

from dataclasses import dataclass
from datetime import datetime, timedelta

from django.conf import settings
from django.db.models import Q
from django.utils import timezone

from apps.orders.choices import OrderStatus

DEFAULT_ACCEPTANCE_SLA_SECONDS = 120  # 05 §1.1, until the backend setting exists
DEFAULT_WARNING_FRACTION = 0.25

ETA_STATUSES = (
    OrderStatus.ACCEPTED,
    OrderStatus.PACKING,
    OrderStatus.PACKED,
    OrderStatus.OUT_FOR_DELIVERY,
)

OK = "success"
WARNING = "warning"
BREACHED = "danger"


def acceptance_sla() -> timedelta:
    seconds = getattr(settings, "ORDER_ACCEPTANCE_SLA_SECONDS", DEFAULT_ACCEPTANCE_SLA_SECONDS)
    return timedelta(seconds=int(seconds))


def warning_fraction() -> float:
    value = float(getattr(settings, "OPS_SLA_WARNING_FRACTION", DEFAULT_WARNING_FRACTION))
    return min(max(value, 0.0), 1.0)


@dataclass(frozen=True)
class Timer:
    start: datetime | None  # what the age counts from
    deadline: datetime | None
    warn_at: datetime | None
    tone: str
    label: str  # what the deadline is, for the card's tooltip

    @property
    def breached(self) -> bool:
        return self.tone == BREACHED


def start_of(order) -> datetime | None:
    return order.placed_at or order.created_at


def deadline_of(order) -> tuple[datetime | None, str]:
    if order.status == OrderStatus.PAYMENT_PENDING:
        return order.payment_expires_at, "Payment window ends"
    if order.status == OrderStatus.PLACED:
        placed = order.placed_at or order.created_at
        return (placed + acceptance_sla() if placed else None), "Acceptance SLA"
    if order.status in ETA_STATUSES:
        return order.eta_at, "Promised delivery time"
    return None, ""


def timer_for(order, now: datetime | None = None) -> Timer:
    now = now or timezone.now()
    start = start_of(order)
    deadline, label = deadline_of(order)
    if deadline is None:
        tone = BREACHED if order.status == OrderStatus.DELIVERY_FAILED else OK
        return Timer(start, None, None, tone, label)
    warn_at = deadline
    if start is not None and deadline > start:
        warn_at = deadline - (deadline - start) * warning_fraction()
    if now >= deadline:
        tone = BREACHED
    elif now >= warn_at:
        tone = WARNING
    else:
        tone = OK
    return Timer(start, deadline, warn_at, tone, label)


def breached_q(now: datetime | None = None) -> Q:
    """Orders past their deadline (the board's "SLA breached" filter), as a database filter."""
    now = now or timezone.now()
    return (
        Q(status=OrderStatus.PAYMENT_PENDING, payment_expires_at__lte=now)
        | Q(status=OrderStatus.PLACED, placed_at__lte=now - acceptance_sla())
        | Q(status__in=ETA_STATUSES, eta_at__lte=now)
        | Q(status=OrderStatus.DELIVERY_FAILED)
    )
