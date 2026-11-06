"""Rider earnings (07 §2.8, 04 §2.7, D-16 default ⚠ until Jivo Ops/HR decide; slice 5.4).

- **Pay per delivery, earned at pickup** (T9, DL-61 c): BASE = the rule's `base_per_order`;
  DISTANCE = `per_km_rate` x (route distance - `per_km_after`, not below 0), where the route
  distance is the task's server-computed store-to-drop `distance_km`, never the GPS trail (06 §3
  #19). Paid for every picked-up order, delivered or not (failed, returned, cancelled after
  pickup); nothing before pickup. TIP = the order's tip, passed through in full, on delivery
  (T10) only. Rounded half up to the paisa; at most one line of each type per task.
- **Adjustments**: INCENTIVE (positive) and PENALTY (negative) lines added by staff with
  `delivery.manage_payouts` (05 §3 "Payouts": Super Admin, Finance). Audited.
- **The rule in force** (`rule_at`): the newest `EarningRule` with `effective_from` <= the time,
  else the settings `RIDER_PAY_BASE_PER_ORDER` / `RIDER_PAY_PER_KM` (no free km). The offer and
  task `estimated_payout` uses the same function, so the estimate and the pay agree.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.db.models import Max, Sum
from django.utils import timezone

from apps.core import audit
from apps.core.money import money_str, round_money
from apps.delivery.choices import DeliveryTaskStatus, EarningType
from apps.delivery.models import EarningRule, Rider, RiderEarning

ZERO = Decimal("0.00")
MANAGE_PAYOUTS = "delivery.manage_payouts"
MAX_ORDERS = 200  # 06 §3 #19: `orders` holds the newest 200 (`orders_truncated`)
ADJUSTMENT_TYPES = (EarningType.INCENTIVE, EarningType.PENALTY)
TASK_TYPES = (EarningType.BASE, EarningType.DISTANCE, EarningType.TIP)
MSG_NO_PERMISSION = "You do not have permission to manage rider pay."
MSG_RIDER_NOT_FOUND = "Rider not found."


@dataclass(frozen=True)
class Rule:
    base_per_order: Decimal
    per_km_rate: Decimal
    per_km_after: Decimal


def rule_at(at: datetime | None = None) -> Rule:
    at = at or timezone.now()
    row = EarningRule.objects.filter(effective_from__lte=at).order_by("-effective_from").first()
    if row is None:
        return Rule(settings.RIDER_PAY_BASE_PER_ORDER, settings.RIDER_PAY_PER_KM, ZERO)
    return Rule(row.base_per_order, row.per_km_rate, row.per_km_after)


def distance_pay(distance_km: Decimal, rule: Rule) -> Decimal:
    paid_km = max(Decimal(distance_km) - rule.per_km_after, ZERO)
    return round_money(rule.per_km_rate * paid_km)


def estimate(distance_km: Decimal, at: datetime | None = None) -> Decimal:
    """Base + distance pay for a task of this route distance (tips come on delivery)."""
    rule = rule_at(at)
    return round_money(rule.base_per_order + distance_pay(distance_km, rule))


# --------------------------------------------------------------------------- recording


def _record(task, amounts: dict, notes: dict, now: datetime) -> list[RiderEarning]:
    existing = set(RiderEarning.objects.filter(task=task).values_list("type", flat=True))
    lines = [
        RiderEarning(
            rider_id=task.rider_id,
            task=task,
            type=kind,
            amount=amount,
            note=notes.get(kind, ""),
            earned_at=now,
        )
        for kind, amount in amounts.items()
        if amount > ZERO and kind not in existing
    ]
    return RiderEarning.objects.bulk_create(lines)


def record_trip_earnings(task, now: datetime) -> list[RiderEarning]:
    """T9 pickup (DL-61 c): the per-delivery fee, BASE + DISTANCE, is earned once the order is
    picked up, whatever happens next (delivered, failed, returned, cancelled after pickup).
    Nothing before pickup. Inside the T9 transaction; idempotent per task and type."""
    rule = rule_at(now)
    amounts = {
        EarningType.BASE: round_money(rule.base_per_order),
        EarningType.DISTANCE: distance_pay(task.distance_km, rule),
    }
    return _record(task, amounts, {EarningType.DISTANCE: f"{task.distance_km} km"}, now)


def record_tip(task, order, now: datetime) -> list[RiderEarning]:
    """T10: the customer's tip, passed through in full, on delivery only (a failed delivery
    refunds the tip to an online customer, 08 §6.4). Idempotent."""
    return _record(task, {EarningType.TIP: round_money(order.tip or ZERO)}, {}, now)


def can_manage(user) -> bool:
    return bool(user and user.is_active and user.is_staff and user.has_perm(MANAGE_PAYOUTS))


def add_adjustment(
    rider_id: int,
    *,
    type: str,
    amount: Decimal,
    note: str,
    by,
    at: datetime | None = None,
    ip: str | None = None,
) -> RiderEarning:
    """An INCENTIVE (amount > 0) or a PENALTY (amount > 0 entered, stored negative) for a rider,
    with a reason. Staff with `delivery.manage_payouts` (Super Admin, Finance). Audited."""
    if not can_manage(by):
        raise PermissionDenied(MSG_NO_PERMISSION)
    if type not in ADJUSTMENT_TYPES:
        raise ValidationError("Choose an incentive or a penalty.")
    try:
        amount = round_money(amount)
    except (ArithmeticError, TypeError, ValueError):
        raise ValidationError("Enter an amount in rupees.") from None
    if amount <= ZERO:
        raise ValidationError("Enter an amount above zero.")
    note = " ".join((note or "").split())[:200]
    if not note:
        raise ValidationError("Enter a reason.")
    rider = Rider.objects.filter(pk=rider_id).first()
    if rider is None:
        raise ValidationError(MSG_RIDER_NOT_FOUND)
    signed = -amount if type == EarningType.PENALTY else amount
    with transaction.atomic():
        line = RiderEarning.objects.create(
            rider=rider,
            type=type,
            amount=signed,
            note=note,
            earned_at=at or timezone.now(),
            recorded_by=by,
        )
        audit.record(
            by,
            "delivery.earning_adjustment",
            rider,
            {"line": line.pk, "type": type, "amount": str(signed), "note_length": len(note)},
            ip=ip,
        )
    return line


# --------------------------------------------------------------------------- reading


def ist() -> ZoneInfo:
    return ZoneInfo(settings.STORE_TIME_ZONE)


def day_bounds(start: date, end: date) -> tuple[datetime, datetime]:
    """UTC-aware instants for the IST days `start`..`end` inclusive: [from, until)."""
    zone = ist()
    return (
        datetime.combine(start, time.min, tzinfo=zone),
        datetime.combine(end + timedelta(days=1), time.min, tzinfo=zone),
    )


def line_body(line: RiderEarning) -> dict:
    return {"type": line.type, "amount": money_str(line.amount), "note": line.note}


def task_earnings_body(lines) -> dict | None:
    lines = sorted(lines, key=lambda line: (TASK_TYPES.index(line.type), line.pk))
    if not lines:
        return None
    return {
        "total": money_str(sum((line.amount for line in lines), ZERO)),
        "lines": [line_body(line) for line in lines],
    }


def total_for(rider: Rider, since: datetime, until: datetime) -> Decimal:
    value = RiderEarning.objects.filter(
        rider=rider, earned_at__gte=since, earned_at__lt=until
    ).aggregate(total=Sum("amount"))["total"]
    return round_money(value or ZERO)


def summary(rider: Rider, start: date, end: date) -> dict:
    """`GET /rider/earnings/` (06 §3 #19): totals over the whole range; `orders` = the newest
    200 tasks paid in the range (picked up: delivered, failed, returned) with their lines;
    `orders_count` = orders delivered in the range; `adjustments` = lines without a task."""
    since, until = day_bounds(start, end)
    lines = RiderEarning.objects.filter(rider=rider, earned_at__gte=since, earned_at__lt=until)
    by_type = {
        row["type"]: row["total"] for row in lines.values("type").annotate(total=Sum("amount"))
    }
    totals = {kind: money_str(by_type.get(kind) or ZERO) for kind in EarningType.values}
    from apps.delivery.models import DeliveryTask

    orders_count = DeliveryTask.objects.filter(
        rider=rider,
        status=DeliveryTaskStatus.DELIVERED,
        delivered_at__gte=since,
        delivered_at__lt=until,
    ).count()
    # Every task with pay in the range (DL-61 c: picked-up tasks are paid even if they failed),
    # newest first by when the pay was earned.
    task_rows = list(
        lines.filter(task__isnull=False)
        .values("task_id")
        .annotate(last=Max("earned_at"))
        .order_by("-last", "-task_id")[: MAX_ORDERS + 1]
    )
    truncated = len(task_rows) > MAX_ORDERS
    task_rows = task_rows[:MAX_ORDERS]
    tasks = DeliveryTask.objects.select_related("order").in_bulk([r["task_id"] for r in task_rows])
    per_task: dict[int, list[RiderEarning]] = {}
    for line in lines.filter(task_id__in=list(tasks)).order_by("pk"):
        per_task.setdefault(line.task_id, []).append(line)
    orders = []
    for row in task_rows:
        task = tasks[row["task_id"]]
        body = task_earnings_body(per_task.get(task.pk, []))
        orders.append(
            {
                "task_id": task.pk,
                "order_number": task.order.order_number,
                "completed_at": task.delivered_at or task.ended_at or row["last"],
                "total": body["total"] if body else money_str(ZERO),
                "lines": body["lines"] if body else [],
            }
        )
    adjustments = [
        {
            "type": line.type,
            "amount": money_str(line.amount),
            "note": line.note,
            "recorded_at": line.earned_at,
        }
        for line in lines.filter(task__isnull=True).order_by("-earned_at", "-pk")
    ]
    return {
        "from": start,
        "to": end,
        "total": money_str(sum(by_type.values(), ZERO)),
        "orders_count": orders_count,
        "totals_by_type": totals,
        "orders": orders,
        "orders_truncated": truncated,
        "adjustments": adjustments,
    }


def staff_earnings(user):
    """Earning lines a staff user may see (Super Admin, Finance: every rider)."""
    allowed = user and user.is_active and user.is_staff
    if not (allowed and user.has_perm("delivery.view_riderearning")):
        return RiderEarning.objects.none()
    return RiderEarning.objects.select_related("rider", "task__order", "payout")
