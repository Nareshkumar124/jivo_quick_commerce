"""Rider cash in hand (08 T10, 04 §2.7, 05 §1.5; slice 5.4).

`RiderCashLedger` is append-only and `Rider.cash_in_hand` is its running balance. Both change
only in `record_cash()`, under the rider row lock (taken last, after any order and task locks),
so concurrent entries never lose an update, and the balance never goes below zero (a DB check).

- COD_COLLECTED (+): T10 with cash (`tasks.deliver`), linked to the order and its store.
- DEPOSIT (-): the rider hands cash in at a store; staff with `delivery.record_cash_deposit`
  (05 §3 "Cash deposit entry": Super Admin ✔, Store Manager own stores) confirm the amount
  received. At most the cash in hand. A repeat with the same `idempotency_key` (the form's
  one-time key) returns the first entry, so a double submit records one deposit.
- ADJUSTMENT (+/-): a correction by staff with `delivery.adjust_cash` (Super Admin only, PM
  default ⚠: no row in 05 §3), with a reason.
- The cash limit (08 §5) only filters COD offers (dispatch) and manual assignment; no rider
  endpoint refuses on it.
"""

from datetime import date
from decimal import Decimal, InvalidOperation

from django.core.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, transaction
from django.db.models import Q, Sum
from django.utils import timezone

from apps.core import audit
from apps.core.money import money_str, round_money
from apps.delivery.choices import CashEntryType
from apps.delivery.models import Rider, RiderCashLedger
from apps.stores.services import stores_for

ZERO = Decimal("0.00")
DEPOSIT_PERMISSION = "delivery.record_cash_deposit"
ADJUST_PERMISSION = "delivery.adjust_cash"
VIEW_PERMISSION = "delivery.view_ridercashledger"
MSG_NO_PERMISSION = "You do not have permission to record rider cash."
MSG_RIDER_NOT_FOUND = "Rider not found."
MSG_AMOUNT = "Enter an amount in rupees above zero."
MSG_ABOVE_IN_HAND = "The rider has only ₹{amount} in hand."
MSG_STORE = "Choose one of your stores."
MSG_REASON = "Enter a reason."
MSG_NEGATIVE = "Cash in hand cannot go below zero (₹{amount} in hand)."
MAX_KEY_LENGTH = 64


def record_cash(
    rider: Rider,
    amount: Decimal,
    entry_type: str,
    *,
    order=None,
    store=None,
    by=None,
    note: str = "",
    idempotency_key: str = "",
) -> RiderCashLedger:
    """One ledger entry and the new `cash_in_hand`, under the rider row lock (in the caller's
    transaction, or its own). Refuses a balance below zero (`ValidationError`)."""
    with transaction.atomic():
        locked = Rider.objects.select_for_update().get(pk=rider.pk)
        balance = locked.cash_in_hand + amount
        if balance < ZERO:
            raise ValidationError(MSG_NEGATIVE.format(amount=money_str(locked.cash_in_hand)))
        changes = {"cash_in_hand": balance, "updated_at": timezone.now()}
        if amount < ZERO:
            changes["cash_skipped_at"] = None  # DL-61 (b): a deposit clears the banner
            rider.cash_skipped_at = None
        Rider.objects.filter(pk=rider.pk).update(**changes)
        rider.cash_in_hand = balance
        entry = RiderCashLedger.objects.create(
            rider=locked,
            entry_type=entry_type,
            amount=amount,
            balance_after=balance,
            order=order,
            store=store if store is not None else getattr(order, "store", None),
            recorded_by=by,
            note=note,
            idempotency_key=idempotency_key,
        )
        # T-612: `cash.updated` on the rider socket; a push for staff entries (the rider made
        # the COD collection themselves and sees it in the delivery response).
        from apps.delivery import hooks

        push_ref = None if entry_type == CashEntryType.COD_COLLECTED else f"cash:{entry.pk}"
        hooks.cash_updated(locked, entry_type, push_ref=push_ref)
        return entry


# --------------------------------------------------------------------------- staff (05 §1.5)


def _allowed(user, permission: str) -> bool:
    return bool(user and user.is_active and user.is_staff and user.has_perm(permission))


def can_record_deposit(user) -> bool:
    return _allowed(user, DEPOSIT_PERMISSION)


def can_adjust(user) -> bool:
    return _allowed(user, ADJUST_PERMISSION)


def staff_cash_riders(user, store_id: int | None = None):
    """Riders whose cash a staff user may see: those whose home store is in `stores_for(user)`
    (deposit staff and Finance, 05 §3 "Cash deposit entry ... view"). Optionally one store."""
    if not (can_record_deposit(user) or _allowed(user, VIEW_PERMISSION) or can_adjust(user)):
        return Rider.objects.none()
    riders = Rider.objects.filter(home_store__in=stores_for(user)).select_related(
        "home_store", "user"
    )
    if store_id is not None:
        riders = riders.filter(home_store_id=store_id)
    return riders.order_by("-cash_in_hand", "pk")


def _amount(value) -> Decimal:
    try:
        amount = round_money(value)
    except (ArithmeticError, InvalidOperation, TypeError, ValueError):
        raise ValidationError(MSG_AMOUNT) from None
    if not amount.is_finite() or amount <= ZERO:
        raise ValidationError(MSG_AMOUNT)
    return amount


def _scoped_rider_id(user, rider_id: int) -> int:
    if not staff_cash_riders(user).filter(pk=rider_id).exists():
        raise ValidationError(MSG_RIDER_NOT_FOUND)
    return rider_id


def record_deposit(
    rider_id: int,
    amount,
    *,
    by,
    store_id: int | None = None,
    note: str = "",
    idempotency_key: str = "",
    ip: str | None = None,
) -> RiderCashLedger:
    """05 §1.5: the store confirms the cash it received from a rider. The rider must be of one of
    the staff user's stores; the deposit is recorded at `store_id` (one of the user's stores,
    default the rider's home store). Amount > 0 and <= cash in hand. Idempotent on
    `idempotency_key`. Audited."""
    if not can_record_deposit(by):
        raise PermissionDenied(MSG_NO_PERMISSION)
    amount = _amount(amount)
    key = (idempotency_key or "").strip()[:MAX_KEY_LENGTH]
    note = " ".join((note or "").split())[:200]
    _scoped_rider_id(by, rider_id)
    stores = stores_for(by)
    try:
        with transaction.atomic():
            rider = (
                Rider.objects.select_for_update(of=("self",))
                .select_related("home_store")
                .get(pk=rider_id)
            )
            if key:
                existing = RiderCashLedger.objects.filter(rider=rider, idempotency_key=key).first()
                if existing is not None:
                    return existing
            store = rider.home_store
            if store_id is not None:
                store = stores.filter(pk=store_id).first()
                if store is None:
                    raise ValidationError(MSG_STORE)
            if amount > rider.cash_in_hand:
                raise ValidationError(
                    MSG_ABOVE_IN_HAND.format(amount=money_str(rider.cash_in_hand))
                )
            entry = record_cash(
                rider,
                -amount,
                CashEntryType.DEPOSIT,
                store=store,
                by=by,
                note=note,
                idempotency_key=key,
            )
            audit.record(
                by,
                "delivery.cash_deposit",
                rider,
                {
                    "entry": entry.pk,
                    "amount": money_str(amount),
                    "store": getattr(store, "pk", None),
                },
                ip=ip,
            )
            return entry
    except IntegrityError:
        # The same key raced in from another request: answer with the entry it recorded.
        existing = RiderCashLedger.objects.filter(rider_id=rider_id, idempotency_key=key).first()
        if key and existing is not None:
            return existing
        raise


def adjust_cash(rider_id: int, amount, *, by, note: str, ip: str | None = None) -> RiderCashLedger:
    """A signed correction of a rider's cash in hand (e.g. a miscounted deposit), with a reason.
    `delivery.adjust_cash`. The balance cannot go below zero. Audited."""
    if not can_adjust(by):
        raise PermissionDenied(MSG_NO_PERMISSION)
    try:
        signed = round_money(amount)
    except (ArithmeticError, InvalidOperation, TypeError, ValueError):
        raise ValidationError("Enter an amount in rupees.") from None
    if not signed.is_finite() or signed == ZERO:
        raise ValidationError("Enter an amount other than zero.")
    note = " ".join((note or "").split())[:200]
    if not note:
        raise ValidationError(MSG_REASON)
    _scoped_rider_id(by, rider_id)
    with transaction.atomic():
        rider = Rider.objects.select_for_update().get(pk=rider_id)
        entry = record_cash(rider, signed, CashEntryType.ADJUSTMENT, by=by, note=note)
        audit.record(
            by,
            "delivery.cash_adjustment",
            rider,
            {"entry": entry.pk, "amount": money_str(signed), "note_length": len(note)},
            ip=ip,
        )
    return entry


def store_day_report(user, store_id: int, day: date) -> dict:
    """05 §1.5 day-end report for one store and IST day: per rider, COD cash collected for the
    store's orders vs cash deposited at the store, and the difference; plus the totals. Riders
    with either amount are listed."""
    from apps.delivery.services.earnings import day_bounds

    if not (can_record_deposit(user) or _allowed(user, VIEW_PERMISSION)):
        raise PermissionDenied(MSG_NO_PERMISSION)
    store = stores_for(user).filter(pk=store_id).first()
    if store is None:
        raise ValidationError(MSG_STORE)
    since, until = day_bounds(day, day)
    rows = (
        RiderCashLedger.objects.filter(
            store=store,
            recorded_at__gte=since,
            recorded_at__lt=until,
            entry_type__in=[CashEntryType.COD_COLLECTED, CashEntryType.DEPOSIT],
        )
        .values("rider_id", "rider__full_name", "rider__cash_in_hand")
        .annotate(
            collected=Sum("amount", filter=Q(entry_type=CashEntryType.COD_COLLECTED)),
            deposited=Sum("amount", filter=Q(entry_type=CashEntryType.DEPOSIT)),
        )
        .order_by("rider__full_name", "rider_id")
    )
    riders = []
    total_collected = total_deposited = ZERO
    for row in rows:
        collected = row["collected"] or ZERO
        deposited = -(row["deposited"] or ZERO)
        total_collected += collected
        total_deposited += deposited
        riders.append(
            {
                "rider_id": row["rider_id"],
                "name": row["rider__full_name"],
                "collected": money_str(collected),
                "deposited": money_str(deposited),
                "difference": money_str(collected - deposited),
                "cash_in_hand": money_str(row["rider__cash_in_hand"]),
            }
        )
    return {
        "store_id": store.pk,
        "store_name": store.name,
        "date": day,
        "collected": money_str(total_collected),
        "deposited": money_str(total_deposited),
        "difference": money_str(total_collected - total_deposited),
        "riders": riders,
    }


# --------------------------------------------------------------------------- rider API


def ledger_entry_body(entry: RiderCashLedger) -> dict:
    return {
        "id": entry.pk,
        "entry_type": entry.entry_type,
        "amount": money_str(entry.amount),
        "balance_after": money_str(entry.balance_after),
        "order_number": entry.order.order_number if entry.order_id else None,
        "note": entry.note,
        "recorded_at": entry.recorded_at,
    }


def rider_ledger(rider: Rider):
    return RiderCashLedger.objects.filter(rider=rider).select_related("order")
