"""Rider payouts (D-16 default ⚠: weekly bank transfers made offline by Finance and recorded in
the panel; 05 §2 "Rider earnings & payouts", §3 "Payouts": Super Admin, Finance; slice 5.4).

No money moves here: a payout is a record. `create_payout` gathers the rider's unpaid earning
lines earned in the period (IST dates, inclusive) under the rider row lock, so two concurrent
creations never take the same line twice; `amount` is their sum and must be above zero (a
period whose penalties outweigh its pay stays unpaid and rolls into a later payout).
`mark_paid` records the bank reference (UTR); `void_payout` deletes a PENDING payout and frees its
lines. All need `delivery.manage_payouts` and are audited.
"""

from datetime import date
from decimal import Decimal

from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from apps.core import audit
from apps.core.money import money_str
from apps.delivery.choices import PayoutStatus
from apps.delivery.models import Payout, Rider, RiderEarning
from apps.delivery.services.earnings import can_manage, day_bounds

ZERO = Decimal("0.00")
MSG_NO_PERMISSION = "You do not have permission to manage payouts."
MSG_NOT_FOUND = "Payout not found."
MSG_NOTHING = "Nothing to pay for this period."
MSG_PERIOD = "The period must end on or after its start, and not in the future."
MSG_REFERENCE = "Enter the bank transfer reference (UTR)."
MSG_NOT_PENDING = "Only a pending payout can be changed."


def _check(by) -> None:
    if not can_manage(by):
        raise PermissionDenied(MSG_NO_PERMISSION)


def _unpaid_lines(rider_id: int, start: date, end: date):
    since, until = day_bounds(start, end)
    return RiderEarning.objects.filter(
        rider_id=rider_id, payout__isnull=True, earned_at__gte=since, earned_at__lt=until
    )


def create_payout(
    rider_id: int, period_start: date, period_end: date, *, by, ip: str | None = None
) -> Payout:
    _check(by)
    from apps.delivery.services.earnings import ist

    today = timezone.now().astimezone(ist()).date()
    if period_end < period_start or period_end > today:
        raise ValidationError(MSG_PERIOD)
    with transaction.atomic():
        rider = Rider.objects.select_for_update().filter(pk=rider_id).first()
        if rider is None:
            raise ValidationError("Rider not found.")
        lines = list(_unpaid_lines(rider.pk, period_start, period_end).select_for_update())
        amount = sum((line.amount for line in lines), ZERO)
        if amount <= ZERO:
            raise ValidationError(MSG_NOTHING)
        payout = Payout.objects.create(
            rider=rider,
            period_start=period_start,
            period_end=period_end,
            amount=amount,
            created_by=by,
        )
        RiderEarning.objects.filter(pk__in=[line.pk for line in lines]).update(payout=payout)
        audit.record(
            by,
            "delivery.payout_created",
            payout,
            {"rider": rider.pk, "amount": money_str(amount), "lines": len(lines)},
            ip=ip,
        )
    return payout


def create_payouts_for_period(
    period_start: date, period_end: date, *, by, ip: str | None = None
) -> list[Payout]:
    """A payout batch: one payout per rider with a positive unpaid total in the period."""
    _check(by)
    since, until = day_bounds(period_start, period_end)
    rider_ids = (
        RiderEarning.objects.filter(payout__isnull=True, earned_at__gte=since, earned_at__lt=until)
        .values("rider_id")
        .annotate(total=Sum("amount"))
        .filter(total__gt=0)
        .order_by("rider_id")
        .values_list("rider_id", flat=True)
    )
    payouts = []
    for rider_id in list(rider_ids):
        try:
            payouts.append(create_payout(rider_id, period_start, period_end, by=by, ip=ip))
        except ValidationError:
            continue  # paid meanwhile by a concurrent batch
    return payouts


def _locked_payout(payout_id: int) -> Payout:
    payout = Payout.objects.select_for_update().filter(pk=payout_id).first()
    if payout is None:
        raise ValidationError(MSG_NOT_FOUND)
    return payout


def mark_paid(payout_id: int, *, reference: str, by, paid_at=None, ip: str | None = None) -> Payout:
    """Record the offline bank transfer. Repeating it with the same reference is a no-op."""
    _check(by)
    reference = (reference or "").strip()[:64]
    if not reference:
        raise ValidationError(MSG_REFERENCE)
    with transaction.atomic():
        payout = _locked_payout(payout_id)
        if payout.status == PayoutStatus.PAID:
            if payout.reference == reference:
                return payout
            raise ValidationError("This payout is already paid with another reference.")
        payout.status = PayoutStatus.PAID
        payout.reference = reference
        payout.paid_at = paid_at or timezone.now()
        payout.paid_by = by
        payout.save(update_fields=["status", "reference", "paid_at", "paid_by"])
        audit.record(
            by, "delivery.payout_paid", payout, {"amount": money_str(payout.amount)}, ip=ip
        )
    return payout


def void_payout(payout_id: int, *, by, ip: str | None = None) -> None:
    """Delete a PENDING payout created by mistake; its lines become unpaid again."""
    _check(by)
    with transaction.atomic():
        payout = _locked_payout(payout_id)
        if payout.status != PayoutStatus.PENDING:
            raise ValidationError(MSG_NOT_PENDING)
        RiderEarning.objects.filter(payout=payout).update(payout=None)
        audit.record(
            by, "delivery.payout_voided", payout, {"amount": money_str(payout.amount)}, ip=ip
        )
        payout.delete()


def payout_body(payout: Payout) -> dict:
    return {
        "id": payout.pk,
        "period_start": payout.period_start,
        "period_end": payout.period_end,
        "amount": money_str(payout.amount),
        "status": payout.status,
        "reference": payout.reference or None,
        "paid_at": payout.paid_at,
    }


def rider_payouts(rider: Rider):
    return Payout.objects.filter(rider=rider).order_by("-period_end", "-pk")
