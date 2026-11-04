"""SLA timers for the live order board and the packing console (05 §1.2, §1.3).

Each active order has one **deadline** that its card counts against:
- `PAYMENT_PENDING`: the end of the payment window (`payment_expires_at`).
- `PLACED`: the store-acceptance SLA, `placed_at + STORE_ACCEPTANCE_SLA_SECONDS` (the backend's
  setting for its acceptance SLA alert, default 60 s), so the console and the alert agree.
- `ACCEPTED` to `OUT_FOR_DELIVERY`: the delivery time promised to the customer (`eta_at`).
- `DELIVERY_FAILED`: none; the exceptions lane is already an alert.

Tone: `danger` once the deadline has passed, `warning` in the last `OPS_SLA_WARNING_FRACTION`
of the time between the start (placed, or created for unpaid orders) and the deadline,
otherwise `success`. The page's script (`ops/js/orders.js`) recomputes the tone every second from
the same `data-*` timestamps, so a card turns amber or red between polls.

Thresholds are settings, never constants in templates.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta

from django.conf import settings
from django.db.models import Q
from django.utils import timezone

from apps.orders.choices import OrderStatus

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
    return timedelta(seconds=int(settings.STORE_ACCEPTANCE_SLA_SECONDS))


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


# --------------------------------------------------------------------------- time text
# design/system/components/ops-alert-banner-and-sla-badges.md B3. The page's script applies the
# same rules every second (`orders.js` `timeText`); the server renders the first value.

BADGE_LABELS = {OK: "", WARNING: "DUE SOON", BREACHED: "LATE"}
BADGE_ICONS = {OK: "timer", WARNING: "schedule", BREACHED: "alarm"}


def duration_text(seconds: float) -> str:
    total = max(int(seconds), 0)
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    if hours:
        return f"{hours}h {minutes:02d}m"
    if minutes >= 2:
        return f"{minutes}m"
    if minutes:
        return f"{minutes}m {secs:02d}s"
    return f"{secs}s"


def time_text(timer: Timer, now: datetime | None = None) -> str:
    """ "12m left", "3m late", or "Waiting 14m" when there is no deadline."""
    now = now or timezone.now()
    if timer.deadline is None:
        age = (now - timer.start).total_seconds() if timer.start else 0
        return f"Waiting {duration_text(age)}"
    seconds = (timer.deadline - now).total_seconds()
    if seconds >= 0:
        return f"{duration_text(seconds)} left"
    return f"{duration_text(-seconds)} late"


def aria_text(timer: Timer, now: datetime | None = None) -> str:
    """For the badge group's aria-label (refreshed per poll, never per second)."""
    from django.utils import timezone as tz

    from apps.ops_console.dates import DISPLAY_TZ

    now = now or timezone.now()
    if timer.deadline is None:
        return time_text(timer, now)
    when = tz.localtime(timer.deadline, DISPLAY_TZ).strftime("%H:%M")
    seconds = (timer.deadline - now).total_seconds()
    minutes = max(int(abs(seconds) // 60), 1)
    state = f"Late by {minutes} minutes" if seconds < 0 else f"{minutes} minutes left"
    if timer.tone == WARNING:
        state = f"Due soon, {state.lower()}"
    return f"{state}, {timer.label.lower()} {when}"
