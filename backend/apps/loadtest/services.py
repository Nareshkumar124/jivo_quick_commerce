"""Load-test data (T-812, Phase 8): seed and clean up the data the Locust harness in the
top-level `loadtest/` project uses on staging.

Tagging: every load-test customer has a phone in the dedicated range `+919000000200` to
`+919000000299` (`+9190000002xx`, never used by people, the QA range `…1xx` or the fixed demo
numbers `…001-003`), so cleanup finds everything through the phone. Stock top-ups are tagged by
their ledger reason.

Guard: both commands run only when `LOADTEST_DATA_ALLOWED` is true, and never when
`APP_ENVIRONMENT` is production (also refused at startup by production.py and the system check
`loadtest.E001`).

Stock and orders change only through the owning services: top-ups and their reversal are
`inventory.services.adjust_stock` ledger movements; open orders are cancelled with
`orders.services.cancel_order` (T5 / T11), which releases their reservations, before anything is
deleted. Orders whose stock was committed (any StockMovement points at them), that have an
invoice, a refund still in flight or another protected row are kept and reported, never forced.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal

from django.conf import settings
from django.contrib.gis.geos import Point
from django.db import transaction
from django.db.models import ProtectedError, Sum

from apps.accounts.choices import AddressLabel
from apps.accounts.models import Address, OTPRequest, User
from apps.accounts.services.addresses import create_address
from apps.core.exceptions import ApiError
from apps.inventory.models import (
    MovementType,
    ReservationStatus,
    StockMovement,
    StockReservation,
    StoreInventory,
)
from apps.inventory.services import MAX_QUANTITY, adjust_stock
from apps.orders.choices import ACTIVE_STATUSES, CancelReason
from apps.orders.models import Order
from apps.payments.models import Payment, Refund, RefundStatus
from apps.promotions.models import CouponRedemption
from apps.stores.models import DarkStore

PHONE_PREFIX = "+919000000"
PHONE_FIRST = 200
MAX_USERS = 100
PHONES: tuple[str, ...] = tuple(f"{PHONE_PREFIX}{PHONE_FIRST + i}" for i in range(MAX_USERS))
NAME_PREFIX = "Loadtest"
ADDRESS_LABEL = "loadtest"
REASON_TOPUP = "loadtest: seed top-up"
REASON_REVERSAL = "loadtest: cleanup reversal"
CLEANUP_NOTE = "loadtest cleanup"
DEFAULT_OTP = "123456"


class LoadtestRefused(Exception):
    """The environment does not allow load-test data (rendered as a CommandError)."""


def ensure_allowed() -> None:
    if settings.APP_ENVIRONMENT == "production":
        raise LoadtestRefused("Load-test data is never allowed in production.")
    if not getattr(settings, "LOADTEST_DATA_ALLOWED", False):
        raise LoadtestRefused(
            "Load-test data is disabled here. Set LOADTEST_DATA_ALLOWED=true (staging only) "
            "to allow loadtest_seed and loadtest_cleanup."
        )


def phones(count: int = MAX_USERS) -> list[str]:
    if not 1 <= count <= MAX_USERS:
        raise ValueError(f"Between 1 and {MAX_USERS} load-test users.")
    return list(PHONES[:count])


def loadtest_users():
    return User.objects.filter(phone__in=PHONES)


def otp_env_value(count: int = MAX_USERS, code: str = DEFAULT_OTP) -> str:
    """The OTP_TEST_NUMBERS value (`phone:code,...`) with the configured numbers kept and the
    load-test numbers added, for the staging environment file."""
    merged = dict(settings.OTP_TEST_NUMBERS)
    for phone in phones(count):
        merged.setdefault(phone, code)
    return ",".join(f"{phone}:{value}" for phone, value in merged.items())


def missing_otp_numbers(count: int = MAX_USERS) -> list[str]:
    return [phone for phone in phones(count) if phone not in settings.OTP_TEST_NUMBERS]


# --------------------------------------------------------------------------- seed


@dataclass
class SeedResult:
    users_created: int = 0
    users_existing: int = 0
    addresses_created: int = 0
    stock_rows_topped_up: int = 0
    units_added: int = 0
    point_in_store_area: bool = True
    missing_otp_numbers: list[str] = field(default_factory=list)


def _address_data(lat: Decimal, lng: Decimal, index: int) -> dict:
    return {
        "label": AddressLabel.OTHER,
        "custom_label": ADDRESS_LABEL,
        "house": f"Load test {index:03d}",
        "building_street": "Load test street",
        "area": "",
        "landmark": "",
        "city": "Gurugram",
        "state": "Haryana",
        "pincode": "122001",
        "lat": lat,
        "lng": lng,
    }


def seed(
    *,
    store: DarkStore,
    users: int = MAX_USERS,
    lat: Decimal | None = None,
    lng: Decimal | None = None,
    stock_floor: int = 5000,
) -> SeedResult:
    """Idempotent. Creates the load-test customers (named, each with one default address at
    `lat`/`lng`, default: the store's own location) and tops every sellable stock row of the
    store up to `stock_floor` free units with a tagged INWARD movement."""
    ensure_allowed()
    if not 0 <= stock_floor <= MAX_QUANTITY:
        raise ValueError(f"stock_floor must be between 0 and {MAX_QUANTITY}.")
    lat = Decimal(str(store.location.y if lat is None else lat)).quantize(Decimal("0.000001"))
    lng = Decimal(str(store.location.x if lng is None else lng)).quantize(Decimal("0.000001"))
    result = SeedResult()
    result.point_in_store_area = bool(
        store.service_area and store.service_area.contains(Point(float(lng), float(lat)))
    )
    with transaction.atomic():
        for index, phone in enumerate(phones(users)):
            user, created = User.objects.get_or_create(
                phone=phone, defaults={"name": f"{NAME_PREFIX} {PHONE_FIRST + index}"}
            )
            if user.is_staff:
                raise LoadtestRefused(f"{phone[:6]}... belongs to a staff user; not touching it.")
            if created:
                user.set_unusable_password()
                user.save(update_fields=["password"])
                result.users_created += 1
            else:
                result.users_existing += 1
            if not Address.objects.filter(user=user, is_deleted=False).exists():
                create_address(user, _address_data(lat, lng, PHONE_FIRST + index))
                result.addresses_created += 1

        rows = (
            StoreInventory.objects.filter(store=store, is_available=True)
            .select_related("variant")
            .order_by("variant_id")
        )
        for row in rows:
            missing = stock_floor - row.available
            if missing <= 0:
                continue
            adjust_stock(
                store=store,
                variant=row.variant,
                delta=missing,
                movement_type=MovementType.INWARD,
                reason=REASON_TOPUP,
            )
            result.stock_rows_topped_up += 1
            result.units_added += missing
    result.missing_otp_numbers = missing_otp_numbers(users)
    return result


# --------------------------------------------------------------------------- cleanup


@dataclass
class CleanupResult:
    executed: bool = False
    users_found: int = 0
    users_deleted: int = 0
    orders_found: int = 0
    orders_cancelled: int = 0
    orders_deleted: int = 0
    otp_requests_deleted: int = 0
    stock_rows_reversed: int = 0
    units_reversed: int = 0
    kept_orders: dict[str, str] = field(default_factory=dict)  # order number -> reason
    kept_users: dict[str, str] = field(default_factory=dict)  # masked phone -> reason


def _mask(phone: str) -> str:
    return f"{phone[:6]}...{phone[-3:]}"


def _keep_reason(order: Order, *, ignore_status: bool = False) -> str | None:
    """Why an order cannot be deleted, or None. `ignore_status`: the dry run assumes an open
    order would be cancelled first."""
    if order.status in ACTIVE_STATUSES and not ignore_status:
        return f"still {order.status} (could not be cancelled)"
    if StockMovement.objects.filter(order=order).exists():
        return "stock was committed (ledger rows point at it)"
    if hasattr(order, "invoice"):
        return "has an invoice"
    if Refund.objects.filter(order=order, status=RefundStatus.PENDING).exists():
        return "a refund is still in flight (re-run cleanup later)"
    return None


def _cancel_if_open(order: Order) -> bool:
    """Cancel an open load-test order through the customer cancel service (T5 / T11), which
    releases its reservation and coupon hold. False when the order cannot be cancelled."""
    from apps.orders.services import cancel_order

    try:
        cancel_order(order.user, order.pk, reason=CancelReason.OTHER, note=CLEANUP_NOTE)
    except ApiError:
        return False
    return True


def _delete_order(order: Order) -> None:
    with transaction.atomic():
        StockReservation.objects.filter(order=order).exclude(
            status=ReservationStatus.ACTIVE
        ).delete()
        CouponRedemption.objects.filter(order=order).delete()
        Refund.objects.filter(order=order).delete()
        Payment.objects.filter(order=order).delete()
        order.delete()


def _reverse_topups(result: CleanupResult, execute: bool) -> None:
    tagged = (
        StockMovement.objects.filter(reason__in=(REASON_TOPUP, REASON_REVERSAL))
        .values("store_id", "variant_id")
        .annotate(net=Sum("delta"))
        .filter(net__gt=0)
        .order_by("store_id", "variant_id")
    )
    for entry in tagged:
        row = (
            StoreInventory.objects.filter(
                store_id=entry["store_id"], variant_id=entry["variant_id"]
            )
            .select_related("store", "variant")
            .first()
        )
        if row is None:
            continue
        units = min(entry["net"], row.available, MAX_QUANTITY)
        if units <= 0:
            continue
        result.stock_rows_reversed += 1
        result.units_reversed += units
        if execute:
            adjust_stock(
                store=row.store,
                variant=row.variant,
                delta=-units,
                movement_type=MovementType.AUDIT_ADJUSTMENT,
                reason=REASON_REVERSAL,
            )


def cleanup(*, execute: bool = False, reverse_stock: bool = True) -> CleanupResult:
    """Remove the load-test customers and everything they created. Without `execute` it only
    reports what it would do (nothing is changed). Re-runnable: kept rows are retried."""
    ensure_allowed()
    result = CleanupResult(executed=execute)
    users = list(loadtest_users().order_by("pk"))
    result.users_found = len(users)
    orders = list(Order.objects.filter(user__in=users).select_related("user").order_by("pk"))
    result.orders_found = len(orders)

    for order in orders:
        if order.status in ACTIVE_STATUSES:
            if not execute:
                result.orders_cancelled += 1  # would be cancelled first
            elif _cancel_if_open(order):
                result.orders_cancelled += 1
                order.refresh_from_db()
        reason = _keep_reason(order, ignore_status=not execute)
        if reason is not None:
            result.kept_orders[order.order_number] = reason
            continue
        if not execute:
            result.orders_deleted += 1  # would be deleted
            continue
        try:
            _delete_order(order)
        except ProtectedError as exc:
            result.kept_orders[order.order_number] = _protected(exc)
            continue
        result.orders_deleted += 1

    kept_numbers = set(result.kept_orders)
    for user in users:
        if any(o.user_id == user.pk and o.order_number in kept_numbers for o in orders):
            result.kept_users[_mask(user.phone)] = "has orders that were kept"
            continue
        if not execute:
            result.users_deleted += 1  # would be deleted
            continue
        try:
            with transaction.atomic():
                user.delete()
        except ProtectedError as exc:
            result.kept_users[_mask(user.phone)] = _protected(exc)
            continue
        result.users_deleted += 1

    otp = OTPRequest.objects.filter(phone__in=PHONES)
    result.otp_requests_deleted = otp.delete()[0] if execute else otp.count()

    if reverse_stock:
        _reverse_topups(result, execute)
    return result


def _protected(exc: ProtectedError) -> str:
    names = sorted({obj._meta.label for obj in exc.protected_objects})
    return f"protected by {', '.join(names)}"
