"""Inventory services (07 §2.4, 08 §6.1). The only code that changes stock.

Rules:
- Every `on_hand` change locks the `StoreInventory` row (`select_for_update`) inside a transaction
  and writes one `StockMovement` with `on_hand_after`, so the ledger always sums to `on_hand`.
- Rows are created at zero (`ensure_inventory`); opening stock is an INWARD movement.
- Manual adjustments (admin, CSV) use INWARD, DAMAGE or AUDIT_ADJUSTMENT. SALE/RETURN/TRANSFER
  are written by the order and transfer flows (Phase 3+).
- `on_hand` can never drop below `reserved` (stock held by placed orders).
- Errors are `django.core.exceptions.ValidationError` with a field -> message dict, so the admin
  shows them on the form and the API renders `VALIDATION_ERROR`.
- `on_hand`/`reserved` writes happen only inside `stock_write()` (the model refuses them
  elsewhere, review #4). Quantities are bounded (`MAX_QUANTITY`, `MAX_ON_HAND`).
- Catalog caches for the store are invalidated after commit by the `StoreInventory` post-save
  signal (`apps.catalog.apps`), only when what the catalog publishes changes (stock status,
  orderable quantity, units left, availability switch, price override). Every write here goes
  through `save()`/`create()`. A future `update()`/`bulk_*` path must call
  `apps.catalog.cache.invalidate_store_on_commit()`.

Permission and store-scope checks belong to the caller (admin/ops views): use
`can_adjust_stock(user, store)` before calling these.
"""

import logging
from collections.abc import Iterable
from dataclasses import dataclass
from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import transaction

from apps.catalog.models import ProductVariant
from apps.inventory.models import MovementType, StockMovement, StoreInventory, stock_write
from apps.stores.models import DarkStore

logger = logging.getLogger(__name__)

MANUAL_TYPES = frozenset({MovementType.INWARD, MovementType.DAMAGE, MovementType.AUDIT_ADJUSTMENT})
MAX_REASON = 255
# Bounds (review #5): a typo such as 10000000000 is a form error, never a database error (500).
MAX_QUANTITY = 1_000_000  # one adjustment, one CSV line, or one audit count
MAX_ON_HAND = 100_000_000  # far below the integer column's limit
MSG_TOO_LARGE = f"At most {MAX_QUANTITY:,} units at a time."


def ensure_inventory(store: DarkStore, variant: ProductVariant) -> StoreInventory:
    """The (store, variant) row, created at zero stock if missing. Does not lock."""
    inventory, _ = StoreInventory.objects.get_or_create(store=store, variant=variant)
    return inventory


def _lock(store: DarkStore, variant: ProductVariant) -> StoreInventory:
    ensure_inventory(store, variant)
    inventory = StoreInventory.objects.select_for_update().get(store=store, variant=variant)
    inventory.variant = variant  # already loaded: the catalog cache signal reads it
    return inventory


def _is_quantity(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _check_manual(delta: int, movement_type: str, reason: str, *, bounded: bool = True) -> None:
    if movement_type not in MANUAL_TYPES:
        raise ValidationError({"type": "Use inward, damage or audit correction."})
    if not _is_quantity(delta):
        raise ValidationError({"delta": "The quantity must be a whole number."})
    if delta == 0:
        raise ValidationError({"delta": "The quantity cannot be zero."})
    if bounded and abs(delta) > MAX_QUANTITY:
        raise ValidationError({"delta": MSG_TOO_LARGE})
    if movement_type == MovementType.INWARD and delta < 0:
        raise ValidationError({"delta": "Inward stock must be a positive quantity."})
    if movement_type == MovementType.DAMAGE and delta > 0:
        raise ValidationError({"delta": "Damage must be a negative quantity."})
    if not reason.strip():
        raise ValidationError({"reason": "Give a reason for the adjustment."})
    if len(reason) > MAX_REASON:
        raise ValidationError({"reason": f"At most {MAX_REASON} characters."})


def _apply(inventory: StoreInventory, delta: int, movement_type: str, reason: str, actor):
    new_on_hand = inventory.on_hand + delta
    if new_on_hand < inventory.reserved:
        raise ValidationError(
            {
                "delta": (
                    f"Only {inventory.available} units are free ({inventory.reserved} are held "
                    "by orders); on hand cannot go below that."
                )
            }
        )
    if new_on_hand > MAX_ON_HAND:
        raise ValidationError({"delta": f"On hand cannot exceed {MAX_ON_HAND:,} units."})
    inventory.on_hand = new_on_hand
    with stock_write():
        inventory.save(update_fields=["on_hand", "updated_at"])
    movement = StockMovement.objects.create(
        store_id=inventory.store_id,
        variant_id=inventory.variant_id,
        delta=delta,
        type=movement_type,
        reason=reason.strip(),
        created_by=actor if getattr(actor, "is_authenticated", False) else None,
        on_hand_after=new_on_hand,
    )
    if inventory.available < inventory.low_stock_threshold:
        from apps.inventory.tasks import low_stock_alert

        store_id, variant_id = inventory.store_id, inventory.variant_id
        transaction.on_commit(lambda: low_stock_alert.delay(store_id, variant_id))
    return movement


def adjust_stock(
    *,
    store: DarkStore,
    variant: ProductVariant,
    delta: int,
    movement_type: str,
    reason: str,
    actor=None,
) -> StockMovement:
    """Change `on_hand` by `delta` (INWARD > 0, DAMAGE < 0, AUDIT_ADJUSTMENT either way)."""
    _check_manual(delta, movement_type, reason)
    with transaction.atomic():
        return _apply(_lock(store, variant), delta, movement_type, reason, actor)


def set_counted_stock(
    *, store: DarkStore, variant: ProductVariant, counted: int, reason: str, actor=None
) -> StockMovement | None:
    """Audit count: set `on_hand` to `counted` with an AUDIT_ADJUSTMENT. None if unchanged."""
    if not _is_quantity(counted):
        raise ValidationError({"counted": "The count must be a whole number."})
    if counted < 0:
        raise ValidationError({"counted": "The count cannot be negative."})
    if counted > MAX_QUANTITY:
        raise ValidationError({"counted": MSG_TOO_LARGE})
    if not reason.strip():
        raise ValidationError({"reason": "Give a reason for the adjustment."})
    with transaction.atomic():
        inventory = _lock(store, variant)
        delta = counted - inventory.on_hand
        if delta == 0:
            return None
        # The count itself is bounded above; the correction may be any size.
        _check_manual(delta, MovementType.AUDIT_ADJUSTMENT, reason, bounded=False)
        return _apply(inventory, delta, MovementType.AUDIT_ADJUSTMENT, reason, actor)


@dataclass(frozen=True, slots=True)
class InwardRow:
    """One CSV line: the variant's SKU (or SAP item code) and a positive quantity."""

    sku: str
    quantity: int


def apply_inward_batch(
    *, store: DarkStore, rows: Iterable[InwardRow], reason: str, actor=None
) -> list[StockMovement]:
    """Bulk inward (CSV, D-17): all rows or none. Unknown SKUs and bad quantities are reported
    together as `{"rows": ["line 3: unknown SKU ...", ...]}` (1-based data lines)."""
    rows = list(rows)
    if not rows:
        raise ValidationError({"rows": ["The file has no rows."]})
    if not reason.strip():
        raise ValidationError({"reason": "Give a reason for the adjustment."})
    codes = {row.sku.strip() for row in rows}
    # SKU first: a SAP item code only matches a code that is no variant's SKU (review #5).
    variants = {v.sap_item_code: v for v in ProductVariant.objects.filter(sap_item_code__in=codes)}
    variants.update({v.sku: v for v in ProductVariant.objects.filter(sku__in=codes)})
    errors = []
    for line, row in enumerate(rows, start=1):
        if row.sku.strip() not in variants:
            errors.append(f"line {line}: unknown SKU {row.sku.strip()!r}.")
        elif not _is_quantity(row.quantity) or row.quantity <= 0:
            errors.append(f"line {line}: the quantity must be a whole number above 0.")
        elif row.quantity > MAX_QUANTITY:
            errors.append(f"line {line}: {MSG_TOO_LARGE}")
    if errors:
        raise ValidationError({"rows": errors})
    with transaction.atomic():
        # Lock in variant-id order (deadlock-free, like reservations).
        ordered = sorted(rows, key=lambda r: variants[r.sku.strip()].pk)
        return [
            _apply(
                _lock(store, variants[row.sku.strip()]),
                row.quantity,
                MovementType.INWARD,
                reason,
                actor,
            )
            for row in ordered
        ]


def update_inventory_settings(
    inventory: StoreInventory,
    *,
    low_stock_threshold: int | None = None,
    rack_location: str | None = None,
) -> StoreInventory:
    """Non-stock fields a store manager may edit. Stock goes through `adjust_stock`."""
    fields = []
    if low_stock_threshold is not None:
        if low_stock_threshold < 0:
            raise ValidationError({"low_stock_threshold": "Cannot be negative."})
        inventory.low_stock_threshold = low_stock_threshold
        fields.append("low_stock_threshold")
    if rack_location is not None:
        inventory.rack_location = rack_location.strip()[:30]
        fields.append("rack_location")
    if fields:
        inventory.save(update_fields=[*fields, "updated_at"])
    return inventory


def set_availability(inventory: StoreInventory, *, is_available: bool) -> StoreInventory:
    """Manual kill switch: off shows the item as out of stock at this store."""
    if inventory.is_available != is_available:
        inventory.is_available = is_available
        inventory.save(update_fields=["is_available", "updated_at"])
    return inventory


def set_price_override(inventory: StoreInventory, price: Decimal | None) -> StoreInventory:
    """Store selling price instead of the variant's (Super Admin / Catalog Manager only).
    Must be above 0 and at most the variant's MRP; None removes it."""
    if price is not None:
        price = Decimal(price).quantize(Decimal("0.01"))
        if price <= 0:
            raise ValidationError({"price_override": "Must be above 0."})
        if price > inventory.variant.mrp:
            raise ValidationError(
                {"price_override": f"Cannot be above the MRP ({inventory.variant.mrp})."}
            )
    inventory.price_override = price
    inventory.save(update_fields=["price_override", "updated_at"])
    return inventory


# --------------------------------------------------------------------------- availability helpers


@dataclass(frozen=True, slots=True)
class Availability:
    """What the catalog publishes for one variant at one store (06 §2.4, DL-26)."""

    stock_status: str
    orderable_quantity: int
    units_left: int | None


def availability(
    *,
    on_hand: int,
    reserved: int,
    is_available: bool,
    max_qty_per_order: int,
    sellable: bool = True,
) -> Availability:
    """`orderable_quantity` = min(available, max per order); LOW_STOCK when 1 <= available <=
    CATALOG_LOW_STOCK_UNITS (then `units_left` = available). Exact stock is never published."""
    from apps.catalog.choices import StockStatus

    available = max(on_hand - reserved, 0) if (is_available and sellable) else 0
    if available == 0:
        return Availability(StockStatus.OUT_OF_STOCK, 0, None)
    orderable = min(available, max_qty_per_order)
    if available <= settings.CATALOG_LOW_STOCK_UNITS:
        return Availability(StockStatus.LOW_STOCK, orderable, available)
    return Availability(StockStatus.IN_STOCK, orderable, None)


def override_applies(price_override: Decimal | None, mrp: Decimal) -> bool:
    """A store override counts only when set, above 0 and at most the MRP. One left above the
    MRP (the MRP was cut after the override was set) is ignored, never sold above MRP."""
    return price_override is not None and Decimal(0) < price_override <= mrp


def effective_price(inventory: StoreInventory | None, variant: ProductVariant) -> Decimal:
    """The selling price at a store: the store override when it applies, else the variant's.
    Python twin of `apps.catalog.services.effective_price_expression` (the catalog's SQL);
    `cart.services.compute_bill()` uses this from Phase 3."""
    if inventory is not None and override_applies(inventory.price_override, variant.mrp):
        return inventory.price_override
    return variant.selling_price


def can_adjust_stock(user, store: DarkStore) -> bool:
    """05 §3: `inventory.adjust_stock` and (for store-scoped roles) access to this store."""
    from apps.stores.services import stores_for

    if not (user and user.is_active and user.has_perm("inventory.adjust_stock")):
        return False
    return stores_for(user).filter(pk=store.pk).exists()


# --------------------------------------------------------------------------- reservations (P3)


@dataclass(frozen=True, slots=True)
class ReservationLine:
    variant_id: int
    quantity: int
    max_qty_per_order: int


def reserve(order, store_id: int, lines: Iterable[ReservationLine], *, expires_at=None) -> None:
    """08 §6.1 (T1/T2): hold stock for an order's lines. Locks the `StoreInventory` rows in
    variant-id order (one order for every path, so two placements never deadlock), re-checks
    what is available under the lock, then adds to `reserved` and writes one `StockReservation`
    per line. Any line short of stock: 409 `STOCK_UNAVAILABLE` listing every short line with its
    `orderable_quantity`, and nothing is reserved. Must run inside the placement transaction."""
    from django.db import connection

    from apps.core.errors import ErrorCode
    from apps.core.exceptions import ApiError
    from apps.inventory.models import StockReservation

    if not connection.in_atomic_block:
        raise RuntimeError("Stock is reserved only inside the order-placement transaction.")
    lines = sorted(lines, key=lambda line: line.variant_id)
    rows = {
        row.variant_id: row
        for row in StoreInventory.objects.select_for_update()
        .filter(store_id=store_id, variant_id__in=[line.variant_id for line in lines])
        .order_by("variant_id")
    }
    short = []
    for line in lines:
        row = rows.get(line.variant_id)
        available = max(row.available, 0) if row is not None and row.is_available else 0
        if line.quantity > available:
            short.append(
                {
                    "variant_id": line.variant_id,
                    "requested_quantity": line.quantity,
                    "orderable_quantity": min(available, line.max_qty_per_order),
                }
            )
    if short:
        raise ApiError(ErrorCode.STOCK_UNAVAILABLE, details={"items": short})
    with stock_write():
        for line in lines:
            row = rows[line.variant_id]
            row.reserved += line.quantity
            row.save(update_fields=["reserved", "updated_at"])
    StockReservation.objects.bulk_create(
        StockReservation(
            order=order,
            store_id=store_id,
            variant_id=line.variant_id,
            quantity=line.quantity,
            expires_at=expires_at,
        )
        for line in lines
    )


def release_reservations(order) -> int:
    """08 §6.1: payment failed / cancelled before pickup. Gives the order's ACTIVE reservations
    back (`reserved -= quantity`, rows locked in variant-id order) and marks them RELEASED.
    Idempotent: returns how many were released (0 the second time)."""
    from apps.inventory.models import ReservationStatus, StockReservation

    with transaction.atomic():
        active = list(
            StockReservation.objects.select_for_update()
            .filter(order=order, status=ReservationStatus.ACTIVE)
            .order_by("variant_id")
        )
        if not active:
            return 0
        rows = {
            row.variant_id: row
            for row in StoreInventory.objects.select_for_update()
            .filter(store_id=active[0].store_id, variant_id__in=[r.variant_id for r in active])
            .order_by("variant_id")
        }
        with stock_write():
            for reservation in active:
                row = rows[reservation.variant_id]
                row.reserved = max(row.reserved - reservation.quantity, 0)
                row.save(update_fields=["reserved", "updated_at"])
        StockReservation.objects.filter(pk__in=[r.pk for r in active]).update(
            status=ReservationStatus.RELEASED
        )
        return len(active)


def clear_reservation_expiry(order) -> int:
    """08 T3: the payment is captured, so the reservation no longer expires (it stays ACTIVE
    until pickup commits it, T9)."""
    from apps.inventory.models import ReservationStatus, StockReservation

    return StockReservation.objects.filter(order=order, status=ReservationStatus.ACTIVE).update(
        expires_at=None
    )


def release_units(order, variant_id: int, quantity: int) -> int:
    """08 §6.1 / T8a: `quantity` units of one line were found unavailable before packing ended.
    Gives them back (`reserved -= quantity`) and shrinks the line's ACTIVE reservation (RELEASED
    when nothing is left). Locks the reservation, then the stock row. Returns the units
    released (never more than still reserved for the line)."""
    from apps.inventory.models import ReservationStatus, StockReservation

    if quantity <= 0:
        return 0
    with transaction.atomic():
        reservation = (
            StockReservation.objects.select_for_update()
            .filter(order=order, variant_id=variant_id, status=ReservationStatus.ACTIVE)
            .first()
        )
        if reservation is None:
            return 0
        units = min(quantity, reservation.quantity)
        row = StoreInventory.objects.select_for_update().get(
            store_id=reservation.store_id, variant_id=variant_id
        )
        with stock_write():
            row.reserved = max(row.reserved - units, 0)
            row.save(update_fields=["reserved", "updated_at"])
        reservation.quantity -= units
        if reservation.quantity == 0:
            reservation.quantity = units  # keep the row's history; the status says it ended
            reservation.status = ReservationStatus.RELEASED
        reservation.save(update_fields=["quantity", "status", "updated_at"])
        return units


# ----------------------------------------------------------------------- pickup and returns (P5)


def commit_reservations(order, actor=None) -> int:
    """08 T9 / §6.1 "Picked up": for every ACTIVE reservation of the order, `on_hand -= qty`
    and `reserved -= qty` with a `StockMovement(SALE)` linked to the order; the reservation
    becomes COMMITTED. Rows are locked in variant-id order. Idempotent (0 the second time).
    Must run inside the pickup transaction (the order row is locked by the caller)."""
    from django.db import connection

    from apps.inventory.models import ReservationStatus, StockReservation

    if not connection.in_atomic_block:
        raise RuntimeError("Stock is committed only inside the pickup transaction.")
    active = list(
        StockReservation.objects.select_for_update()
        .filter(order=order, status=ReservationStatus.ACTIVE)
        .order_by("variant_id")
    )
    if not active:
        return 0
    rows = {
        row.variant_id: row
        for row in StoreInventory.objects.select_for_update()
        .filter(store_id=active[0].store_id, variant_id__in=[r.variant_id for r in active])
        .order_by("variant_id")
    }
    reason = f"Order {order.order_number} picked up"
    for reservation in active:
        row = rows[reservation.variant_id]
        quantity = reservation.quantity
        with stock_write():
            row.on_hand -= quantity
            row.reserved = max(row.reserved - quantity, 0)
            row.save(update_fields=["on_hand", "reserved", "updated_at"])
        StockMovement.objects.create(
            store_id=row.store_id,
            variant_id=row.variant_id,
            delta=-quantity,
            type=MovementType.SALE,
            reason=reason,
            created_by=actor if getattr(actor, "is_authenticated", False) else None,
            on_hand_after=row.on_hand,
            order=order,
        )
    StockReservation.objects.filter(pk__in=[r.pk for r in active]).update(
        status=ReservationStatus.COMMITTED
    )
    return len(active)


def receive_returned_units(order, returns: list[tuple[int, int, int]], actor=None) -> None:
    """08 T14 / §6.1: items of a failed delivery are back at the store. `returns` lists
    `(variant_id, good, damaged)` units. Good units: `on_hand += good`, `StockMovement(RETURN)`.
    Damaged units are recorded but never go back on the shelf: a RETURN of `damaged` followed
    by a DAMAGE of `-damaged` (net `on_hand` unchanged; the ledger refuses a zero-delta row).
    Rows are locked in variant-id order. The caller holds the order row lock."""
    returns = sorted((r for r in returns if r[1] or r[2]), key=lambda r: r[0])
    if not returns:
        return
    rows = {
        row.variant_id: row
        for row in StoreInventory.objects.select_for_update()
        .filter(store_id=order.store_id, variant_id__in=[r[0] for r in returns])
        .order_by("variant_id")
    }
    reason = f"Order {order.order_number} returned"
    created_by = actor if getattr(actor, "is_authenticated", False) else None
    for variant_id, good, damaged in returns:
        row = rows[variant_id]  # committed at T9, so the row exists
        for delta, kind in ((good + damaged, MovementType.RETURN), (-damaged, MovementType.DAMAGE)):
            if not delta:
                continue
            with stock_write():
                row.on_hand += delta
                row.save(update_fields=["on_hand", "updated_at"])
            StockMovement.objects.create(
                store_id=row.store_id,
                variant_id=variant_id,
                delta=delta,
                type=kind,
                reason=reason if kind == MovementType.RETURN else f"{reason}: damaged",
                created_by=created_by,
                on_hand_after=row.on_hand,
                order=order,
            )
