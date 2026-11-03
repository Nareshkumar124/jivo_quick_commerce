"""The server cart (07 §2.5): one per user, priced at the store of the last cart call
(`X-Store-Id`). The cart never reserves stock (08 §6.1) and holds no money: every amount is
computed on read by `apps.cart.services.compute_bill()`. Changes go through `apps.cart.services`.
"""

from decimal import Decimal

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import Q

from apps.core.models import TimeStampedModel


def empty_instructions() -> dict:
    return {"chips": [], "note": ""}


class Cart(TimeStampedModel):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="cart"
    )
    store = models.ForeignKey(
        "stores.DarkStore",
        on_delete=models.PROTECT,
        related_name="carts",
        help_text="The store the cart was last priced at (the X-Store-Id of the last call).",
    )
    coupon = models.ForeignKey(
        "promotions.Coupon",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="carts",
    )
    address = models.ForeignKey(
        "accounts.Address",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="carts",
        help_text="Delivery address chosen for checkout (ignored once soft-deleted).",
    )
    tip = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        validators=[MinValueValidator(Decimal("0.00"))],
    )
    instructions = models.JSONField(
        default=empty_instructions, help_text='{"chips": [...], "note": "..."} (03 §2.8).'
    )

    class Meta:
        constraints = [
            models.CheckConstraint(condition=Q(tip__gte=0), name="cart_tip_not_negative")
        ]

    def __str__(self) -> str:
        return f"Cart of user {self.user_id}"


class CartItem(TimeStampedModel):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name="items")
    variant = models.ForeignKey(
        "catalog.ProductVariant", on_delete=models.CASCADE, related_name="cart_items"
    )
    quantity = models.PositiveIntegerField()

    class Meta:
        ordering = ["created_at", "id"]
        constraints = [
            models.UniqueConstraint(fields=["cart", "variant"], name="cartitem_unique_variant"),
            models.CheckConstraint(condition=Q(quantity__gte=1), name="cartitem_quantity_positive"),
        ]

    def __str__(self) -> str:
        return f"{self.quantity} x variant {self.variant_id}"
