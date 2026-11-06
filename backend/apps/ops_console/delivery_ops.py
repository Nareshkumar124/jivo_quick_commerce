"""Ops delivery actions, cash deposits and payouts (05 §1.4, §1.5, §2 "Rider earnings & payouts";
DL-61; slice 5.4).

SLICE 5.4 DEPENDENCY. Everything in this module calls backend services that land with slice 5.4
(`.worktrees/backend5`, not merged into this branch yet), except `force_offline`, which already
exists in `delivery.services.shifts` (its permission moves from `review_rider` to
`dispatch_order` with 5.4, DL-61 a). A service that is not on the branch makes `available()`
False: the button renders disabled and a crafted POST gets 501, exactly like `order_actions`.
After the 5.4 merge nothing here needs changing; the gated tests in
`tests/test_delivery_ops.py` stop skipping.

Signatures (read from the slice 5.4 services, 2026-11-06):

    delivery.services.ops.unlock_pickup(order_id, *, by, ip=None) -> DeliveryTask
    delivery.services.ops.unlock_delivery_otp(order_id, *, by, ip=None) -> DeliveryTask
    delivery.services.ops.fail_delivery(order_id, *, reason, note, by, ip=None) -> DeliveryTask
    delivery.services.shifts.force_offline(rider_id, *, by, ip=None) -> Rider
    delivery.services.cash.record_deposit(rider_id, amount, *, by, store_id=None, note="",
                                          idempotency_key="", ip=None) -> RiderCashLedger
    delivery.services.cash.staff_cash_riders(user, store_id=None) -> QuerySet[Rider]
    delivery.services.cash.store_day_report(user, store_id, day) -> dict
    delivery.services.payouts.create_payouts_for_period(start, end, *, by, ip=None) -> [Payout]
    delivery.services.payouts.mark_paid(payout_id, *, reference, by, paid_at=None, ip=None)
    delivery.services.payouts.void_payout(payout_id, *, by, ip=None) -> None

The services check the permission, scope the rider / order to the caller's stores, lock and
audit; the panel scopes first anyway (another store's rider or task is a 404 before any call).
Amounts are passed through as the staff typed them (a 2-decimal rupee string); the service
validates and rounds. Nothing here computes money.
"""

from apps.ops_console.order_actions import ActionUnavailable, _lookup, refusal

DELIVERY_OPS = "apps.delivery.services.ops"
CASH = "apps.delivery.services.cash"
PAYOUTS = "apps.delivery.services.payouts"
SHIFTS = "apps.delivery.services.shifts"

UNLOCK_PICKUP = "unlock_pickup"
UNLOCK_OTP = "unlock_otp"
FAIL_DELIVERY = "fail_delivery"
FORCE_OFFLINE = "force_offline"
RECORD_DEPOSIT = "record_deposit"
CASH_RIDERS = "cash_riders"
DAY_REPORT = "day_report"
CREATE_PAYOUTS = "create_payouts"
MARK_PAID = "mark_paid"
VOID_PAYOUT = "void_payout"

SERVICES: dict[str, tuple[str, str]] = {
    UNLOCK_PICKUP: (DELIVERY_OPS, "unlock_pickup"),
    UNLOCK_OTP: (DELIVERY_OPS, "unlock_delivery_otp"),
    FAIL_DELIVERY: (DELIVERY_OPS, "fail_delivery"),
    FORCE_OFFLINE: (SHIFTS, "force_offline"),
    RECORD_DEPOSIT: (CASH, "record_deposit"),
    CASH_RIDERS: (CASH, "staff_cash_riders"),
    DAY_REPORT: (CASH, "store_day_report"),
    CREATE_PAYOUTS: (PAYOUTS, "create_payouts_for_period"),
    MARK_PAID: (PAYOUTS, "mark_paid"),
    VOID_PAYOUT: (PAYOUTS, "void_payout"),
}

# The fail reasons are the backend's enum (`DeliveryFailReason`, already on this branch).
FAIL_REASONS = ("apps.delivery.choices", "DeliveryFailReason")


def available(action: str) -> bool:
    return callable(_lookup(*SERVICES[action]))


def availability() -> dict[str, bool]:
    return {action: available(action) for action in SERVICES}


def fail_reasons() -> list[tuple[str, str]]:
    enum = _lookup(*FAIL_REASONS)
    return list(enum.choices) if enum is not None else []


def _service(action: str):
    function = _lookup(*SERVICES[action])
    if not callable(function):
        module, name = SERVICES[action]
        raise ActionUnavailable(f"{module}.{name} does not exist yet.")
    return function


def _call(action: str, *args, **kwargs):
    from django.core.exceptions import PermissionDenied
    from django.core.exceptions import ValidationError as DjangoValidationError
    from rest_framework.exceptions import APIException

    function = _service(action)
    try:
        return function(*args, **kwargs)
    except (APIException, DjangoValidationError, PermissionDenied) as error:
        raise refusal(error) from error


# --------------------------------------------------------------------------- delivery (05 §1.4)


def unlock_pickup(order_id: int, *, actor, ip: str | None = None):
    return _call(UNLOCK_PICKUP, order_id, by=actor, ip=ip)


def unlock_otp(order_id: int, *, actor, ip: str | None = None):
    return _call(UNLOCK_OTP, order_id, by=actor, ip=ip)


def fail_delivery(order_id: int, *, reason: str, note: str, actor, ip: str | None = None):
    return _call(FAIL_DELIVERY, order_id, reason=reason, note=note, by=actor, ip=ip)


def force_offline(rider_id: int, *, actor, ip: str | None = None):
    return _call(FORCE_OFFLINE, rider_id, by=actor, ip=ip)


# --------------------------------------------------------------------------- cash (05 §1.5)


def cash_riders(user, store_id: int | None = None):
    """Riders whose cash `user` may see (the service scopes to the user's stores)."""
    return _service(CASH_RIDERS)(user, store_id)


def day_report(user, store_id: int, day) -> dict:
    return _call(DAY_REPORT, user, store_id, day)


def record_deposit(
    rider_id: int, amount, *, actor, store_id=None, note="", key="", ip: str | None = None
):
    return _call(
        RECORD_DEPOSIT,
        rider_id,
        amount,
        by=actor,
        store_id=store_id,
        note=note,
        idempotency_key=key,
        ip=ip,
    )


# --------------------------------------------------------------------------- payouts (D-16)


def create_payouts(start, end, *, actor, ip: str | None = None):
    return _call(CREATE_PAYOUTS, start, end, by=actor, ip=ip)


def mark_paid(payout_id: int, *, reference: str, actor, ip: str | None = None):
    return _call(MARK_PAID, payout_id, reference=reference, by=actor, ip=ip)


def void_payout(payout_id: int, *, actor, ip: str | None = None):
    return _call(VOID_PAYOUT, payout_id, by=actor, ip=ip)
