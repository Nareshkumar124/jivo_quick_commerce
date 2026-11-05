"""Load-test data (T-812, Phase 8): seed and clean up the data the Locust harness in the
top-level `loadtest/` project uses on staging.

Tagging: load-test accounts live in two dedicated phone ranges that no person, the QA range
(`…1xx`) or the fixed demo numbers (`…001-003`) use:
- customers `+919000000200` to `+919000000299` (`+9190000002xx`);
- riders `+919000000300` to `+919000000399` (`+9190000003xx`).
Each account is also named exactly `Loadtest NNN` (the last three digits of its phone). An
account in a range is only ever touched when it carries that name and is not staff or a
superuser; a customer-range account with a rider profile is never touched either. Anything
else in a range is reported and left alone. Stock top-ups are tagged by their ledger reason.

Guard: both commands run only when `LOADTEST_DATA_ALLOWED` is true, and never when
`APP_ENVIRONMENT` is production (also refused at startup by production.py and the system check
`loadtest.E001`).

Every change goes through the owning services:
- stock: top-ups and their reversal are `inventory.services.adjust_stock` ledger movements;
- orders: open orders are cancelled with `orders.services.cancel_order` (T5 / T11), which
  releases their reservations, before anything is deleted. Orders whose stock was committed
  (any StockMovement points at them), that have an invoice, a refund still in flight or another
  protected row are kept and reported, never forced;
- riders: registered, given documents and bank details, and approved through
  `apps.delivery.services` (`register`, `upload_document`, `set_bank_account`,
  `approve_document`, `approve_rider`), by a named staff approver, so the KYC audit trail shows
  who approved them.
"""

from __future__ import annotations

import io
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

from django.conf import settings
from django.contrib.gis.geos import Point
from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import IntegrityError, transaction
from django.db.models import ProtectedError, Sum
from PIL import Image

from apps.accounts.choices import AddressLabel, RiderStatus
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
RIDER_PHONE_FIRST = 300
MAX_RIDERS = 100
RIDER_PHONES: tuple[str, ...] = tuple(
    f"{PHONE_PREFIX}{RIDER_PHONE_FIRST + i}" for i in range(MAX_RIDERS)
)
NAME_PREFIX = "Loadtest"
ADDRESS_LABEL = "loadtest"
REASON_TOPUP = "loadtest: seed top-up"
REASON_REVERSAL = "loadtest: cleanup reversal"
CLEANUP_NOTE = "loadtest cleanup"
DEFAULT_OTP = "123456"
# Well-formed fakes (the demo seed's): the Aadhaar number passes the Verhoeff check.
RIDER_DOCUMENT_NUMBERS = {"AADHAAR_FRONT": "234123412346", "PAN": "ABCDE1234F"}
RIDER_BANK = {"account_number": "50100123456789", "ifsc": "HDFC0001234"}
RIDER_EMERGENCY_PHONE = "+919812345670"


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


def rider_phones(count: int) -> list[str]:
    if not 0 <= count <= MAX_RIDERS:
        raise ValueError(f"Between 0 and {MAX_RIDERS} load-test riders.")
    return list(RIDER_PHONES[:count])


def tag_name(phone: str) -> str:
    """The exact name every load-test account carries: `Loadtest 200` for +919000000200."""
    return f"{NAME_PREFIX} {phone[-3:]}"


def loadtest_users():
    """Every account in the customer range (tagged or not; see `untouchable`)."""
    return User.objects.filter(phone__in=PHONES)


def loadtest_rider_users():
    return User.objects.filter(phone__in=RIDER_PHONES)


def mask(phone: str) -> str:
    return f"{phone[:6]}...{phone[-3:]}"


def untouchable(user: User, *, rider_range: bool = False) -> str | None:
    """Why an account in a load-test range must not be touched, or None when it is a tagged
    load-test account. Staff and superusers are never touched; neither is an account that is
    not named `Loadtest NNN`, nor a customer-range account with a rider profile."""
    from apps.delivery.models import Rider

    if user.is_staff or user.is_superuser:
        return "staff or superuser account"
    if user.name != tag_name(user.phone or ""):
        return f"not named {tag_name(user.phone or '')!r}"
    if not rider_range and Rider.objects.filter(user=user).exists():
        return "has a rider profile"
    return None


def otp_env_value(count: int = MAX_USERS, code: str = DEFAULT_OTP, riders: int = 0) -> str:
    """The OTP_TEST_NUMBERS value (`phone:code,...`) with the configured numbers kept and the
    load-test numbers added, for the staging environment file."""
    merged = dict(settings.OTP_TEST_NUMBERS)
    for phone in (*phones(count), *rider_phones(riders)):
        merged.setdefault(phone, code)
    return ",".join(f"{phone}:{value}" for phone, value in merged.items())


def missing_otp_numbers(count: int = MAX_USERS, riders: int = 0) -> list[str]:
    numbers = (*phones(count), *rider_phones(riders))
    return [phone for phone in numbers if phone not in settings.OTP_TEST_NUMBERS]


# --------------------------------------------------------------------------- seed


@dataclass
class SeedResult:
    users_created: int = 0
    users_existing: int = 0
    addresses_created: int = 0
    stock_rows_topped_up: int = 0
    units_added: int = 0
    point_in_store_area: bool = True
    riders_created: int = 0
    riders_existing: int = 0
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


def _tagged_account(phone: str, *, rider_range: bool) -> tuple[User, bool]:
    user, created = User.objects.get_or_create(phone=phone, defaults={"name": tag_name(phone)})
    reason = untouchable(user, rider_range=rider_range)
    if reason is not None:
        raise LoadtestRefused(
            f"{mask(phone)} is not a load-test account ({reason}); not touching it."
        )
    if created:
        user.set_unusable_password()
        user.save(update_fields=["password"])
    return user, created


def resolve_approver(email: str | None) -> User:
    """The staff user who approves the load-test riders' KYC (and is named in its audit log).
    Must be allowed to review riders at the store; the approve services check that again."""
    from apps.delivery.services.kyc import can_review

    if not email:
        raise LoadtestRefused("Seeding riders needs --approver <email of a staff KYC reviewer>.")
    approver = User.objects.filter(email__iexact=email).first()
    if approver is None or not can_review(approver):
        raise LoadtestRefused(f"{email} is not an active staff user allowed to review riders.")
    return approver


def seed(
    *,
    store: DarkStore,
    users: int = MAX_USERS,
    lat: Decimal | None = None,
    lng: Decimal | None = None,
    stock_floor: int = 5000,
    riders: int = 0,
    approver: User | None = None,
) -> SeedResult:
    """Idempotent. Creates the load-test customers (each with one default address at
    `lat`/`lng`, default: the store's own location), tops every sellable stock row of the
    store up to `stock_floor` free units with a tagged INWARD movement, and makes `riders`
    ACTIVE load-test riders with `store` as their home store."""
    ensure_allowed()
    if not 0 <= stock_floor <= MAX_QUANTITY:
        raise ValueError(f"stock_floor must be between 0 and {MAX_QUANTITY}.")
    rider_list = rider_phones(riders)
    if rider_list and approver is None:
        raise LoadtestRefused("Seeding riders needs --approver <email of a staff KYC reviewer>.")
    lat = Decimal(str(store.location.y if lat is None else lat)).quantize(Decimal("0.000001"))
    lng = Decimal(str(store.location.x if lng is None else lng)).quantize(Decimal("0.000001"))
    result = SeedResult()
    result.point_in_store_area = bool(
        store.service_area and store.service_area.contains(Point(float(lng), float(lat)))
    )
    with transaction.atomic():
        for index, phone in enumerate(phones(users)):
            user, created = _tagged_account(phone, rider_range=False)
            if created:
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

    # One rider at a time: KYC files are written to storage by upload_document itself.
    for phone in rider_list:
        if _seed_rider(phone, store, approver):
            result.riders_created += 1
        else:
            result.riders_existing += 1
    result.missing_otp_numbers = missing_otp_numbers(users, riders)
    return result


def _jpeg(index: int) -> SimpleUploadedFile:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 64), (40 + 30 * index, 120, 160)).save(buffer, "JPEG")
    return SimpleUploadedFile("loadtest.jpg", buffer.getvalue(), content_type="image/jpeg")


def _seed_rider(phone: str, store: DarkStore, approver: User) -> bool:
    """An ACTIVE bicycle rider (photo, Aadhaar front and back, PAN; no DL/RC) whose home store
    is `store`. True when it was made ACTIVE now, False when it already was."""
    from apps.delivery.choices import DocumentStatus, VehicleType
    from apps.delivery.models import RiderDocument
    from apps.delivery.services import kyc, riders

    with transaction.atomic():
        user, _ = _tagged_account(phone, rider_range=True)
        rider = riders.rider_for(user)
        if rider is None:
            rider = riders.register(
                user,
                {
                    "preferred_store_id": store.pk,
                    "full_name": tag_name(phone),
                    "dob": date(1996, 1, 15),
                    "emergency_contact_name": "Loadtest Contact",
                    "emergency_contact_phone": RIDER_EMERGENCY_PHONE,
                    "vehicle_type": VehicleType.BICYCLE,
                    "vehicle_number": "",
                },
            )
    if rider.status == RiderStatus.ACTIVE:
        return False
    if rider.status != RiderStatus.PENDING_KYC:
        raise LoadtestRefused(f"Load-test rider {mask(phone)} is {rider.status}; fix it by hand.")
    for index, doc_type in enumerate(rider.required_documents):
        document = RiderDocument.objects.filter(rider=rider, doc_type=doc_type).first()
        if document is None or document.status == DocumentStatus.REJECTED:
            document = riders.upload_document(
                user,
                doc_type=doc_type,
                upload=_jpeg(index),
                number=RIDER_DOCUMENT_NUMBERS.get(doc_type, ""),
            )
        if document.status != DocumentStatus.APPROVED:
            kyc.approve_document(document.pk, by=approver)
    rider.refresh_from_db()
    if not rider.has_bank_account:
        riders.set_bank_account(
            user,
            holder_name=tag_name(phone),
            account_number=RIDER_BANK["account_number"],
            ifsc=RIDER_BANK["ifsc"],
        )
    kyc.approve_rider(rider.pk, by=approver, home_store_id=store.pk)
    return True


# --------------------------------------------------------------------------- cleanup


@dataclass
class CleanupResult:
    executed: bool = False
    users_found: int = 0
    users_deleted: int = 0
    riders_found: int = 0
    riders_deleted: int = 0
    orders_found: int = 0
    orders_cancelled: int = 0
    orders_deleted: int = 0
    otp_requests_deleted: int = 0
    stock_rows_reversed: int = 0
    units_reversed: int = 0
    kept_orders: dict[str, str] = field(default_factory=dict)  # order number -> reason
    kept_users: dict[str, str] = field(default_factory=dict)  # masked phone -> reason
    kept_stock: dict[str, str] = field(default_factory=dict)  # "store/variant" -> reason


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


def _protected(exc: ProtectedError) -> str:
    names = sorted({obj._meta.label for obj in exc.protected_objects})
    return f"protected by {', '.join(names)}"


def _reverse_topups(result: CleanupResult, execute: bool) -> None:
    tagged = (
        StockMovement.objects.filter(reason__in=(REASON_TOPUP, REASON_REVERSAL))
        .values("store_id", "variant_id")
        .annotate(net=Sum("delta"))
        .filter(net__gt=0)
        .order_by("store_id", "variant_id")
    )
    for entry in tagged:
        key = f"{entry['store_id']}/{entry['variant_id']}"
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
        if execute:
            # `available` was read without a lock: an order placed meanwhile can hold the units.
            # adjust_stock re-checks under the row lock; losing that race keeps the row.
            try:
                with transaction.atomic():
                    adjust_stock(
                        store=row.store,
                        variant=row.variant,
                        delta=-units,
                        movement_type=MovementType.AUDIT_ADJUSTMENT,
                        reason=REASON_REVERSAL,
                    )
            except (IntegrityError, ValidationError):
                result.kept_stock[key] = "stock changed meanwhile (re-run cleanup later)"
                continue
        result.stock_rows_reversed += 1
        result.units_reversed += units


def _cleanup_orders(result: CleanupResult, users: list[User], execute: bool) -> set[int]:
    """Cancel and delete the orders of `users`; the ids of users with an order kept."""
    orders = list(Order.objects.filter(user__in=users).select_related("user").order_by("pk"))
    result.orders_found = len(orders)
    blocked: set[int] = set()
    for order in orders:
        if order.status in ACTIVE_STATUSES:
            if not execute:
                result.orders_cancelled += 1  # would be cancelled first
            elif _cancel_if_open(order):
                result.orders_cancelled += 1
                order.refresh_from_db()
        reason = _keep_reason(order, ignore_status=not execute)
        if reason is None and execute:
            try:
                _delete_order(order)
            except ProtectedError as exc:
                reason = _protected(exc)
        if reason is not None:
            result.kept_orders[order.order_number] = reason
            blocked.add(order.user_id)
            continue
        result.orders_deleted += 1
    return blocked


def _delete_rider_user(user: User) -> None:
    """Remove a load-test rider: end any open shift, drop its history rows (they hold the fake
    bank details), delete the profile (documents, shifts, locations cascade), its KYC files
    after commit, then the account."""
    from apps.delivery.choices import ShiftEndReason
    from apps.delivery.models import Rider
    from apps.delivery.services import shifts
    from apps.delivery.services.riders import _delete_file

    with transaction.atomic():
        rider = Rider.objects.select_for_update().filter(user=user).first()
        if rider is not None:
            shifts.end_open_shift(rider, reason=ShiftEndReason.ADMIN)
            files = [d.file.name for d in rider.documents.all() if d.file]
            rider.history.all().delete()
            rider.delete()
            transaction.on_commit(lambda: [_delete_file(name) for name in files])
        user.delete()


def cleanup(*, execute: bool = False, reverse_stock: bool = True) -> CleanupResult:
    """Remove the load-test customers and riders and everything they created. Without `execute`
    it only reports what it would do (nothing is changed). Re-runnable: kept rows are retried.
    Accounts in the ranges that are not tagged load-test accounts (`untouchable`) are never
    touched, nor are their orders."""
    ensure_allowed()
    result = CleanupResult(executed=execute)

    customers, rider_users = [], []
    for user in loadtest_users().order_by("pk"):
        reason = untouchable(user)
        if reason is not None:
            result.kept_users[mask(user.phone)] = reason
        else:
            customers.append(user)
    for user in loadtest_rider_users().order_by("pk"):
        reason = untouchable(user, rider_range=True)
        if reason is not None:
            result.kept_users[mask(user.phone)] = reason
        else:
            rider_users.append(user)
    result.users_found = len(customers)
    result.riders_found = len(rider_users)

    blocked = _cleanup_orders(result, customers + rider_users, execute)

    for user, is_rider in [(u, False) for u in customers] + [(u, True) for u in rider_users]:
        if user.pk in blocked:
            result.kept_users[mask(user.phone)] = "has orders that were kept"
            continue
        if execute:
            try:
                if is_rider:
                    _delete_rider_user(user)
                else:
                    with transaction.atomic():
                        user.delete()
            except ProtectedError as exc:
                result.kept_users[mask(user.phone)] = _protected(exc)
                continue
        if is_rider:
            result.riders_deleted += 1
        else:
            result.users_deleted += 1

    # OTP requests of every range phone, except those of accounts that are kept.
    kept_phones = {
        u.phone
        for u in User.objects.filter(phone__in=PHONES + RIDER_PHONES)
        if mask(u.phone) in result.kept_users
    }
    otp = OTPRequest.objects.filter(phone__in=set(PHONES + RIDER_PHONES) - kept_phones)
    result.otp_requests_deleted = otp.delete()[0] if execute else otp.count()

    if reverse_stock:
        _reverse_topups(result, execute)
    return result
