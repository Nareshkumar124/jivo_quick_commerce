"""Per-store stock (07 §2.4, 08 §6.1).

`available = on_hand - reserved`. Database check constraints keep `on_hand >= 0`,
`reserved >= 0` and `reserved <= on_hand`. `on_hand` changes only through
`apps.inventory.services`, which locks the row and writes a `StockMovement` for every change, so
the sum of a row's movement deltas always equals its `on_hand`. `StockReservation` (and the
movement's `order` link) arrive with orders in Phase 3.
"""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from simple_history.models import HistoricalRecords

from apps.core.models import TimeStampedModel


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


class MovementType(models.TextChoices):
    INWARD = "INWARD", "Inward (received)"
    SALE = "SALE", "Sale (picked up)"
    RETURN = "RETURN", "Return (good, back on the shelf)"
    DAMAGE = "DAMAGE", "Damage / expiry"
    AUDIT_ADJUSTMENT = "AUDIT_ADJUSTMENT", "Audit correction"
    TRANSFER_IN = "TRANSFER_IN", "Transfer in"
    TRANSFER_OUT = "TRANSFER_OUT", "Transfer out"


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
    created_at = models.DateTimeField(auto_now_add=True)

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
