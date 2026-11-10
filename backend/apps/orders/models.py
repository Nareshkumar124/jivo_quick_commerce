"""Orders (07 §2.6, 08). Status changes only through `apps.orders.services.transition()`
(Phase 3 R2b), which validates the 08 §2 table, sets the timestamp and writes one append-only
`OrderStatusHistory` row.

Money is a snapshot of `cart.services.compute_bill()` at placement. Database check constraints
keep the 08 §6.2 identities, so a row can never hold an inconsistent bill:
`grand_total = item_total - coupon_discount + delivery_fee + small_cart_fee + handling_fee + tip`
and `product_discount = mrp_total - item_total`.
"""

from decimal import Decimal

from django.conf import settings
from django.contrib.gis.db import models as gis_models
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import F, Q
from django.db.models.functions import Greatest

from apps.core.models import TimeStampedModel
from apps.orders.choices import (
    ACTIVE_STATUSES,
    ActorType,
    OrderCancelReason,
    OrderStatus,
    PaymentMethod,
    PaymentStatus,
    RatingTarget,
)

MONEY = {"max_digits": 12, "decimal_places": 2}
BILL_FIELDS = (
    "mrp_total",
    "item_total",
    "product_discount",
    "coupon_discount",
    "delivery_fee",
    "small_cart_fee",
    "handling_fee",
    "tip",
    "grand_total",
)


def _money(**kwargs) -> models.DecimalField:
    return models.DecimalField(**MONEY, default=Decimal("0.00"), **kwargs)


class Order(TimeStampedModel):
    order_number = models.CharField(
        max_length=20, unique=True, help_text='Shown to customers, e.g. "JV-261103-000123".'
    )
    pickup_code = models.CharField(
        max_length=4,
        blank=True,
        help_text="4 characters for rider pickup; unique among the store's active orders.",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="orders"
    )
    store = models.ForeignKey("stores.DarkStore", on_delete=models.PROTECT, related_name="orders")
    address_snapshot = models.JSONField(
        help_text="The delivery address at order time (the Address API fields, no id)."
    )
    delivery_location = gis_models.PointField(srid=4326, help_text="The address pin (WGS84).")
    status = models.CharField(max_length=20, choices=OrderStatus.choices)
    payment_method = models.CharField(max_length=10, choices=PaymentMethod.choices)
    payment_status = models.CharField(max_length=20, choices=PaymentStatus.choices)

    # Bill snapshot (08 §6.2), from compute_bill() at placement.
    mrp_total = _money()
    item_total = _money()
    product_discount = _money()
    coupon_discount = _money()
    delivery_fee = _money()
    small_cart_fee = _money()
    handling_fee = _money()
    tip = _money()
    grand_total = _money(help_text="Amount payable.")
    amount_refunded = _money()
    amount_paid = _money(
        help_text=(
            "ONLINE: what the customer paid for this order (grand_total at capture, T3). "
            "Stays the same when T8a lowers grand_total; refunds are capped by it."
        )
    )
    coupon = models.ForeignKey(
        "promotions.Coupon",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="orders",
    )
    coupon_code = models.CharField(max_length=30, blank=True)

    delivery_otp_hash = models.CharField(max_length=128, blank=True)
    delivery_otp_attempts = models.PositiveSmallIntegerField(default=0)
    instructions = models.JSONField(default=dict)

    payment_expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="PAYMENT_PENDING only: end of the online payment window (AppConfig).",
    )
    eta_at = models.DateTimeField(null=True, blank=True, help_text="Promised delivery time.")
    # One timestamp per state reached (SLA reports); set by transition().
    placed_at = models.DateTimeField(null=True, blank=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    packing_started_at = models.DateTimeField(null=True, blank=True)
    packed_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    payment_failed_at = models.DateTimeField(null=True, blank=True)
    delivery_failed_at = models.DateTimeField(null=True, blank=True)
    returned_at = models.DateTimeField(null=True, blank=True)

    cancel_reason = models.CharField(max_length=30, blank=True, choices=OrderCancelReason.choices)
    cancel_note = models.CharField(max_length=250, blank=True)
    cancelled_by_type = models.CharField(max_length=10, blank=True, choices=ActorType.choices)

    idempotency_key = models.CharField(
        max_length=64, help_text="The app's Idempotency-Key (unique per user)."
    )
    request_fingerprint = models.CharField(
        max_length=64,
        blank=True,
        help_text="Hash of the placement request; a reused key with another body is refused.",
    )
    client_app_version = models.CharField(max_length=32, blank=True)
    client_platform = models.CharField(max_length=16, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "idempotency_key"], name="order_user_idempotency_key_unique"
            ),
            models.UniqueConstraint(
                fields=["store", "pickup_code"],
                condition=Q(status__in=sorted(ACTIVE_STATUSES)) & ~Q(pickup_code=""),
                name="order_active_pickup_code_unique",
            ),
            models.CheckConstraint(
                condition=Q(
                    **{
                        f"{field}__gte": 0
                        for field in (*BILL_FIELDS, "amount_refunded", "amount_paid")
                    }
                ),
                name="order_money_not_negative",
            ),
            models.CheckConstraint(
                condition=Q(
                    grand_total=F("item_total")
                    - F("coupon_discount")
                    + F("delivery_fee")
                    + F("small_cart_fee")
                    + F("handling_fee")
                    + F("tip")
                ),
                name="order_grand_total_formula",
            ),
            models.CheckConstraint(
                condition=Q(product_discount=F("mrp_total") - F("item_total")),
                name="order_product_discount_formula",
            ),
            models.CheckConstraint(
                condition=Q(coupon_discount__lte=F("item_total")),
                name="order_coupon_within_item_total",
            ),
            # Phase 4: T8a lowers grand_total after payment, so refunds are bounded by what was
            # paid (or by grand_total for orders without a recorded payment, T3a).
            models.CheckConstraint(
                condition=Q(amount_refunded__lte=Greatest(F("amount_paid"), F("grand_total"))),
                name="order_refund_within_paid",
            ),
        ]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="order_user_recent_idx"),
            models.Index(fields=["store", "status"], name="order_store_status_idx"),
            models.Index(fields=["status", "placed_at"], name="order_status_placed_idx"),
            models.Index(
                fields=["status", "payment_expires_at"], name="order_status_payment_exp_idx"
            ),
        ]
        permissions = [
            ("process_order", "Can accept and pack orders (packing console)"),
            ("cancel_order", "Can cancel orders as store, ops or support"),
        ]

    def __str__(self) -> str:
        return self.order_number

    @property
    def is_active(self) -> bool:
        return self.status in ACTIVE_STATUSES


class OrderItem(TimeStampedModel):
    """An ordered variant with the names, codes and prices as they were at order time."""

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    variant = models.ForeignKey(
        "catalog.ProductVariant", on_delete=models.PROTECT, related_name="order_items"
    )
    product = models.ForeignKey(
        "catalog.Product", on_delete=models.PROTECT, related_name="order_items"
    )
    product_name = models.CharField(max_length=200)
    variant_name = models.CharField(max_length=100)
    sku = models.CharField(max_length=64)
    hsn_code = models.CharField(max_length=16, blank=True)
    gst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal("0.00"))
    image = models.JSONField(null=True, blank=True, help_text="The ImageSet URLs then.")
    mrp = models.DecimalField(**MONEY)
    selling_price = models.DecimalField(**MONEY)
    quantity = models.PositiveIntegerField()
    quantity_unavailable = models.PositiveIntegerField(
        default=0, help_text="Marked unavailable by the store (08 T8a, Phase 4)."
    )
    line_total = models.DecimalField(**MONEY)
    tax_amount = models.DecimalField(
        **MONEY, default=Decimal("0.00"), help_text="GST included in line_total (Phase 4)."
    )

    class Meta:
        ordering = ["id"]
        constraints = [
            models.UniqueConstraint(fields=["order", "variant"], name="orderitem_unique_variant"),
            models.CheckConstraint(
                condition=Q(quantity__gte=1), name="orderitem_quantity_positive"
            ),
            models.CheckConstraint(
                condition=Q(quantity_unavailable__lte=F("quantity")),
                name="orderitem_unavailable_within_quantity",
            ),
            models.CheckConstraint(
                condition=Q(mrp__gte=0) & Q(selling_price__gte=0) & Q(line_total__gte=0),
                name="orderitem_money_not_negative",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.quantity} x {self.sku}"


class OrderStatusHistoryQuerySet(models.QuerySet):
    def update(self, **kwargs):
        raise ValidationError("Order status history is append-only.")

    def delete(self):
        raise ValidationError("Order status history is append-only.")


class OrderStatusHistory(models.Model):
    """Append-only: one row per order state change (and one for the order's creation)."""

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="status_history")
    from_status = models.CharField(
        max_length=20, blank=True, choices=OrderStatus.choices, help_text='"" at creation.'
    )
    to_status = models.CharField(max_length=20, choices=OrderStatus.choices)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="order_status_changes",
    )
    actor_type = models.CharField(max_length=10, choices=ActorType.choices)
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = OrderStatusHistoryQuerySet.as_manager()

    class Meta:
        ordering = ["created_at", "id"]
        verbose_name_plural = "order status history"
        indexes = [models.Index(fields=["order", "created_at"], name="orderhistory_order_idx")]

    def __str__(self) -> str:
        return f"{self.order_id}: {self.from_status or 'new'} -> {self.to_status}"

    def save(self, *args, **kwargs):
        if self.pk is not None:
            raise ValidationError("Order status history is append-only.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValidationError("Order status history is append-only.")


def invoice_upload_to(instance, filename: str) -> str:
    return f"invoices/{instance.order.store_id}/{instance.invoice_number.replace('/', '-')}.pdf"


class Invoice(TimeStampedModel):
    """The GST tax invoice of a delivered order (07 §2.6, 09 §4). Amounts are GST-inclusive
    splits of the order's final bill. `is_placeholder` marks invoices made with the placeholder
    seller GST data of settings (D-12 not decided): never a valid tax invoice."""

    order = models.OneToOneField(Order, on_delete=models.PROTECT, related_name="invoice")
    invoice_number = models.CharField(max_length=40, unique=True)
    issued_at = models.DateTimeField()
    seller_gstin = models.CharField(max_length=15)
    is_placeholder = models.BooleanField(default=True)
    taxable_value = models.DecimalField(**MONEY)
    cgst = models.DecimalField(**MONEY)
    sgst = models.DecimalField(**MONEY)
    igst = models.DecimalField(**MONEY)
    total = models.DecimalField(**MONEY)
    pdf = models.FileField(upload_to=invoice_upload_to, blank=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=Q(total=F("taxable_value") + F("cgst") + F("sgst") + F("igst")),
                name="invoice_total_formula",
            ),
        ]

    def __str__(self) -> str:
        return self.invoice_number


class InvoiceSequence(models.Model):
    """The next invoice number per store and financial year (07 §2.6: `DEL01/26-27/000123`)."""

    store = models.ForeignKey("stores.DarkStore", on_delete=models.PROTECT)
    financial_year = models.CharField(max_length=5, help_text='e.g. "26-27".')
    last_number = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["store", "financial_year"], name="invoicesequence_unique"
            )
        ]

    def __str__(self) -> str:
        return f"{self.store_id} {self.financial_year}: {self.last_number}"


class Rating(TimeStampedModel):
    """A customer's rating of a delivered order (07 §2.6, 06 §2.6 `POST /orders/{id}/rating/`,
    Phase 7): one ORDER row and, when the rider was rated, one RIDER row. Written once (not
    editable); only through `apps.orders.ratings.rate_order`. `comment` is personal data: never
    logged or audited."""

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="ratings")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="ratings"
    )
    target = models.CharField(max_length=5, choices=RatingTarget.choices)
    rider = models.ForeignKey(
        "delivery.Rider",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="ratings",
        help_text="The rider who delivered the order (RIDER ratings only).",
    )
    stars = models.PositiveSmallIntegerField()
    tags = models.JSONField(default=list, blank=True)
    comment = models.TextField(max_length=500, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.UniqueConstraint(fields=["order", "target"], name="rating_unique_order_target"),
            models.CheckConstraint(
                condition=Q(stars__gte=1) & Q(stars__lte=5), name="rating_stars_1_to_5"
            ),
            models.CheckConstraint(
                condition=Q(target=RatingTarget.ORDER, rider__isnull=True)
                | Q(target=RatingTarget.RIDER, rider__isnull=False),
                name="rating_rider_iff_rider_target",
            ),
        ]
        indexes = [
            models.Index(fields=["rider", "-created_at"], name="rating_rider_created"),
            models.Index(fields=["target", "stars", "-created_at"], name="rating_target_stars"),
        ]

    def __str__(self) -> str:
        return f"{self.target} rating {self.stars} for order {self.order_id}"
