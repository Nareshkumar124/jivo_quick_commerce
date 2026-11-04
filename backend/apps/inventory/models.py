"""Per-store stock (07 §2.4, 08 §6.1).

`available = on_hand - reserved`. Database check constraints keep `on_hand >= 0`,
`reserved >= 0` and `reserved <= on_hand`. `on_hand` changes only through
`apps.inventory.services`, which locks the row and writes a `StockMovement` for every change, so
the sum of a row's movement deltas always equals its `on_hand`.

`StockReservation` (Phase 3): one row per order line while the order holds stock (08 §6.1). Its
quantity is part of `StoreInventory.reserved`; the reservation services change both together.
"""

import contextvars
from collections.abc import Iterator
from contextlib import contextmanager

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from simple_history.models import HistoricalRecords

from apps.core.models import TimeStampedModel

STOCK_FIELDS = ("on_hand", "reserved")
# Fields whose change can change what the catalog publishes (see apps.catalog.apps).
TRACKED_FIELDS = (*STOCK_FIELDS, "is_available", "price_override")
MSG_STOCK_GUARD = (
    "on_hand and reserved change only through apps.inventory.services (every on_hand change "
    "writes a StockMovement)."
)
_stock_write_allowed = contextvars.ContextVar("inventory_stock_write_allowed", default=False)


@contextmanager
def stock_write() -> Iterator[None]:
    """Allow writes to `on_hand`/`reserved` inside the block. Only `apps.inventory.services`
    (and the order/reservation services from Phase 3) open it; tests use the factories."""
    token = _stock_write_allowed.set(True)
    try:
        yield
    finally:
        _stock_write_allowed.reset(token)


class StoreInventoryQuerySet(models.QuerySet):
    def update(self, **kwargs):
        if set(STOCK_FIELDS) & kwargs.keys() and not _stock_write_allowed.get():
            raise ValidationError(MSG_STOCK_GUARD)
        return super().update(**kwargs)


class StoreInventory(TimeStampedModel):
    store = models.ForeignKey(
        "stores.DarkStore", on_delete=models.PROTECT, related_name="inventory"
    )
    variant = models.ForeignKey(
        "catalog.ProductVariant", on_delete=models.PROTECT, related_name="inventory"
    )
    on_hand = models.IntegerField(default=0, help_text="Physically in the store. Read-only.")
    reserved = models.IntegerField(
        default=0, help_text="Held by placed orders not yet picked up. Read-only."
    )
    low_stock_threshold = models.PositiveIntegerField(
        default=5, help_text="Alert the store manager when available falls below this."
    )
    is_available = models.BooleanField(
        default=True, help_text="Manual kill switch: off shows the item as out of stock."
    )
    price_override = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Store selling price instead of the variant's (above 0, at most the MRP).",
    )
    rack_location = models.CharField(max_length=30, blank=True)
    history = HistoricalRecords()

    objects = StoreInventoryQuerySet.as_manager()

    class Meta:
        verbose_name_plural = "store inventory"
        constraints = [
            models.UniqueConstraint(fields=["store", "variant"], name="storeinventory_unique"),
            models.CheckConstraint(
                condition=models.Q(on_hand__gte=0), name="storeinventory_on_hand_not_negative"
            ),
            models.CheckConstraint(
                condition=models.Q(reserved__gte=0), name="storeinventory_reserved_not_negative"
            ),
            models.CheckConstraint(
                condition=models.Q(reserved__lte=models.F("on_hand")),
                name="storeinventory_reserved_within_on_hand",
            ),
            models.CheckConstraint(
                condition=models.Q(price_override__isnull=True) | models.Q(price_override__gt=0),
                name="storeinventory_price_override_positive",
            ),
        ]
        permissions = [
            ("adjust_stock", "Can adjust stock (inward, damage, audit count)"),
            ("toggle_availability", "Can switch an item on or off at a store"),
        ]

    def __str__(self) -> str:
        return f"{self.store_id}/{self.variant_id}: {self.on_hand} on hand"

    @property
    def available(self) -> int:
        return self.on_hand - self.reserved

    # --- direct-write guard (review #4) and change tracking (catalog cache, review #6) --------

    @classmethod
    def from_db(cls, db, field_names, values):
        instance = super().from_db(db, field_names, values)
        instance._remember_loaded()
        return instance

    def refresh_from_db(self, *args, **kwargs) -> None:
        super().refresh_from_db(*args, **kwargs)
        self._remember_loaded()

    def _remember_loaded(self) -> None:
        self._loaded = {name: self.__dict__.get(name) for name in TRACKED_FIELDS}

    @property
    def loaded_values(self) -> dict:
        """The tracked fields as last read from or written to the database (a new row: its
        defaults, i.e. zero stock)."""
        loaded = getattr(self, "_loaded", None)
        if loaded is None:
            return {"on_hand": 0, "reserved": 0, "is_available": True, "price_override": None}
        return loaded

    def save(self, *args, **kwargs) -> None:
        if not _stock_write_allowed.get():
            update_fields = kwargs.get("update_fields")
            for name in STOCK_FIELDS:
                if update_fields is not None and name not in update_fields:
                    continue
                if self.__dict__.get(name) != self.loaded_values[name]:
                    raise ValidationError({name: MSG_STOCK_GUARD})
        super().save(*args, **kwargs)
        self._remember_loaded()

    def clean(self) -> None:
        super().clean()
        if self.price_override is not None:
            if self.price_override <= 0:
                raise ValidationError({"price_override": "Must be above 0."})
            if self.variant_id is not None and self.price_override > self.variant.mrp:
                raise ValidationError(
                    {"price_override": f"Cannot be above the MRP ({self.variant.mrp})."}
                )


class MovementType(models.TextChoices):
    INWARD = "INWARD", "Inward (received)"
    SALE = "SALE", "Sale (picked up)"
    RETURN = "RETURN", "Return (good, back on the shelf)"
    DAMAGE = "DAMAGE", "Damage / expiry"
    AUDIT_ADJUSTMENT = "AUDIT_ADJUSTMENT", "Audit correction"
    TRANSFER_IN = "TRANSFER_IN", "Transfer in"
    TRANSFER_OUT = "TRANSFER_OUT", "Transfer out"


class StockMovementQuerySet(models.QuerySet):
    """Append-only: no bulk update or delete either (review #4). Django's SET_NULL on
    `created_by` when a user is deleted runs as a direct SQL update, so it still works."""

    def update(self, **kwargs):
        raise ValidationError("Stock movements are append-only.")

    def delete(self):
        raise ValidationError("Stock movements are append-only.")


class StockMovement(models.Model):
    """Append-only stock ledger: one row per `on_hand` change. Never updated or deleted."""

    store = models.ForeignKey(
        "stores.DarkStore", on_delete=models.PROTECT, related_name="stock_movements"
    )
    variant = models.ForeignKey(
        "catalog.ProductVariant", on_delete=models.PROTECT, related_name="stock_movements"
    )
    delta = models.IntegerField(help_text="Change to on_hand (+ in, - out).")
    type = models.CharField(max_length=20, choices=MovementType.choices)
    reason = models.CharField(max_length=255, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="stock_movements",
    )
    on_hand_after = models.IntegerField()
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="stock_movements",
        help_text="The order behind a SALE or RETURN (Phase 3+).",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    objects = StockMovementQuerySet.as_manager()

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.CheckConstraint(
                condition=~models.Q(delta=0), name="stockmovement_delta_not_zero"
            ),
            models.CheckConstraint(
                condition=models.Q(on_hand_after__gte=0), name="stockmovement_on_hand_after_ok"
            ),
        ]
        indexes = [
            models.Index(
                fields=["store", "variant", "-created_at"], name="stockmovement_ledger_idx"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.type} {self.delta:+d} ({self.store_id}/{self.variant_id})"

    def save(self, *args, **kwargs):
        if self.pk is not None:
            raise ValidationError("Stock movements are append-only.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValidationError("Stock movements are append-only.")


class ReservationStatus(models.TextChoices):
    ACTIVE = "ACTIVE", "Active (stock held)"
    COMMITTED = "COMMITTED", "Committed (picked up: sold)"
    RELEASED = "RELEASED", "Released (payment failed, cancelled or unavailable)"


class StockReservation(TimeStampedModel):
    """Stock held for one order line (08 §6.1). ACTIVE reservations of a (store, variant) sum to
    `StoreInventory.reserved`. Placement creates them (rows locked in variant-id order); payment
    failure, cancellation and unavailability release them; pickup commits them (SALE)."""

    order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="reservations")
    store = models.ForeignKey(
        "stores.DarkStore", on_delete=models.PROTECT, related_name="stock_reservations"
    )
    variant = models.ForeignKey(
        "catalog.ProductVariant", on_delete=models.PROTECT, related_name="stock_reservations"
    )
    quantity = models.PositiveIntegerField()
    status = models.CharField(
        max_length=10, choices=ReservationStatus.choices, default=ReservationStatus.ACTIVE
    )
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Online orders: the payment window end. Empty for COD (no expiry).",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["order", "variant"], name="stockreservation_order_variant_unique"
            ),
            models.CheckConstraint(
                condition=models.Q(quantity__gte=1), name="stockreservation_quantity_positive"
            ),
        ]
        indexes = [
            models.Index(fields=["status", "expires_at"], name="reservation_status_exp_idx"),
            models.Index(fields=["store", "variant", "status"], name="reservation_stock_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.quantity} x variant {self.variant_id} for order {self.order_id}"
