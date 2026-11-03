"""Phase 3 API contract: placing orders, the order shape and the order list (06 §2.6).

Explicit (non-model) serializers: the shapes are the contract, independent of how orders are
stored (Phase 3 R2a). Phase 4 adds the order detail (timeline, invoice) to the same `Order`
shape; additions are backward compatible.
"""

from rest_framework import serializers

from apps.accounts.validators import indian_mobile_validator
from apps.cart.serializers import BillSerializer, DeliveryInstructionsSerializer
from apps.catalog.serializers import ImageSetSerializer, money
from apps.orders.choices import (
    CancelReason,
    OrderListStatus,
    OrderStatus,
    PaymentMethod,
    PaymentStatus,
)

CANCEL_NOTE_MAX_LENGTH = 250


class OrderStoreSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(help_text='e.g. "Jivo Sector 14, Gurugram".')


class OrderAddressSerializer(serializers.Serializer):
    """The delivery address as it was when the order was placed (a snapshot: later edits to the
    saved address do not change it)."""

    label = serializers.CharField(help_text="home / work / other.")
    custom_label = serializers.CharField(allow_blank=True)
    receiver_name = serializers.CharField()
    receiver_phone = serializers.CharField(validators=[indian_mobile_validator])
    house = serializers.CharField()
    building_street = serializers.CharField()
    landmark = serializers.CharField(allow_blank=True)
    area = serializers.CharField(allow_blank=True)
    city = serializers.CharField()
    state = serializers.CharField()
    pincode = serializers.CharField()
    lat = serializers.FloatField()
    lng = serializers.FloatField()


class OrderLineSerializer(serializers.Serializer):
    """An ordered variant, with the names and prices as they were at order time."""

    id = serializers.IntegerField()
    variant_id = serializers.IntegerField()
    product_id = serializers.IntegerField()
    product_name = serializers.CharField()
    variant_name = serializers.CharField(help_text='e.g. "1 L".')
    image = ImageSetSerializer(allow_null=True)
    mrp = money("Unit MRP at order time.")
    selling_price = money("Unit price paid at order time.")
    quantity = serializers.IntegerField(min_value=1)
    line_mrp_total = money("`mrp` x `quantity`.")
    line_total = money("`selling_price` x `quantity`.")


class OrderSerializer(serializers.Serializer):
    """An order with its bill. The bill is a snapshot made by `compute_bill()` at placement."""

    id = serializers.IntegerField()
    order_number = serializers.CharField(
        help_text='Shown to the customer, e.g. "JV-261103-000123".'
    )
    status = serializers.ChoiceField(choices=OrderStatus.choices, help_text="08 §1.")
    payment_method = serializers.ChoiceField(choices=PaymentMethod.choices)
    payment_status = serializers.ChoiceField(choices=PaymentStatus.choices)
    store = OrderStoreSerializer()
    items = OrderLineSerializer(many=True)
    item_count = serializers.IntegerField(min_value=1, help_text="Units (sum of quantities).")
    bill = BillSerializer()
    coupon_code = serializers.CharField(allow_null=True, help_text="Null when none was used.")
    address = OrderAddressSerializer()
    instructions = DeliveryInstructionsSerializer()
    created_at = serializers.DateTimeField()
    placed_at = serializers.DateTimeField(
        allow_null=True,
        help_text="When it reached PLACED (paid online, or confirmed COD); null before.",
    )
    payment_expires_at = serializers.DateTimeField(
        allow_null=True,
        help_text=(
            "PAYMENT_PENDING only: the end of the online payment window (15 minutes from "
            "placement, a server setting). Retrying the payment does not extend it. After it "
            "the order fails and the stock is released. Null in every other state."
        ),
    )
    eta_at = serializers.DateTimeField(
        allow_null=True,
        help_text="Promised delivery time (UTC; show it in IST). Null until PLACED.",
    )
    can_cancel = serializers.BooleanField(
        help_text=(
            "True when `POST /orders/{id}/cancel/` is allowed now (08 §7). Phase 3: only in "
            "PAYMENT_PENDING; from Phase 4 also PLACED and ACCEPTED."
        )
    )
    can_retry_payment = serializers.BooleanField(
        help_text=(
            "True when `POST /orders/{id}/retry-payment/` is allowed now: an ONLINE order in "
            "PAYMENT_PENDING before `payment_expires_at`."
        )
    )


class OrderSummarySerializer(serializers.Serializer):
    """A row of the order list."""

    id = serializers.IntegerField()
    order_number = serializers.CharField()
    status = serializers.ChoiceField(choices=OrderStatus.choices)
    payment_method = serializers.ChoiceField(choices=PaymentMethod.choices)
    payment_status = serializers.ChoiceField(choices=PaymentStatus.choices)
    store = OrderStoreSerializer()
    item_count = serializers.IntegerField(min_value=1)
    images = ImageSetSerializer(
        many=True, help_text="Pictures of up to the first 4 lines, for the row thumbnails."
    )
    grand_total = money("The order's `bill.grand_total`.")
    created_at = serializers.DateTimeField()
    placed_at = serializers.DateTimeField(allow_null=True)
    payment_expires_at = serializers.DateTimeField(
        allow_null=True, help_text="As on `Order`: set only while PAYMENT_PENDING."
    )
    eta_at = serializers.DateTimeField(allow_null=True)
    can_retry_payment = serializers.BooleanField()


class PaginatedOrderSummaryListSerializer(serializers.Serializer):
    """Standard page (02 §5): `?page=&page_size=`, default 20, max 100."""

    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = OrderSummarySerializer(many=True)


class RazorpayPrefillSerializer(serializers.Serializer):
    name = serializers.CharField(allow_blank=True)
    contact = serializers.CharField(help_text="The customer's phone, E.164.")
    email = serializers.CharField(allow_blank=True, help_text='"" when the customer has none.')


class RazorpayCheckoutSerializer(serializers.Serializer):
    """Options for Razorpay checkout (`razorpay_flutter` `open()`), all set by the server: pass
    them through unchanged. The amount is the order's `grand_total` in paise."""

    key_id = serializers.CharField(
        help_text=(
            "Razorpay key id (`key`). Local development only: `rzp_fake_jivo_local` means the "
            "server uses the fake gateway; complete the payment with the dev-only scheme in 06 "
            "§2.6 instead of opening Razorpay."
        )
    )
    order_id = serializers.CharField(help_text='Razorpay order id (`order_id`), "order_...".')
    amount = serializers.IntegerField(
        min_value=100,
        help_text="`grand_total` in paise (`amount`), e.g. 75300 for ₹753.00. Display the "
        "order's `bill.grand_total` instead.",
    )
    currency = serializers.CharField(help_text='Always "INR".')
    name = serializers.CharField(help_text='Merchant name shown in checkout (`name`), "Jivo".')
    description = serializers.CharField(help_text="`description`, e.g. the order number.")
    prefill = RazorpayPrefillSerializer()
    expires_at = serializers.DateTimeField(help_text="Same as the order's `payment_expires_at`.")
    timeout_seconds = serializers.IntegerField(
        min_value=1,
        help_text="Seconds left in the payment window (`timeout`), so checkout closes in time.",
    )


class OrderPlacementSerializer(serializers.Serializer):
    order = OrderSerializer()
    razorpay = RazorpayCheckoutSerializer(
        allow_null=True,
        help_text=(
            "ONLINE orders in PAYMENT_PENDING: open checkout with it, then call "
            "`POST /payments/razorpay/verify/`. Null for COD (and for an online order that is "
            "no longer awaiting payment)."
        ),
    )


# --------------------------------------------------------------------------- requests


class OrderCreateSerializer(serializers.Serializer):
    address_id = serializers.IntegerField(
        min_value=1,
        help_text=(
            "One of the caller's saved addresses, inside the service area of the store in "
            "`X-Store-Id`. Unknown or another user's: 400."
        ),
    )
    payment_method = serializers.ChoiceField(choices=PaymentMethod.choices)
    expected_grand_total = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=0,
        help_text=(
            "The cart's `bill.grand_total` exactly as displayed. If the server's bill differs "
            "(a price, fee or coupon changed), the order is not placed: 409 `PRICE_CHANGED`; "
            "reload the cart and show the new bill."
        ),
    )


class OrderListQuerySerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=OrderListStatus.choices,
        required=False,
        help_text=(
            "`active`: not finished yet, including PAYMENT_PENDING (to recover a payment after "
            "the app was closed). `past`: DELIVERED, CANCELLED, PAYMENT_FAILED, RETURNED. "
            "Omit for all orders, active first."
        ),
    )


class OrderCancelSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=CancelReason.choices)
    note = serializers.CharField(
        max_length=CANCEL_NOTE_MAX_LENGTH,
        required=False,
        allow_blank=True,
        help_text="Optional free text, e.g. for OTHER.",
    )
