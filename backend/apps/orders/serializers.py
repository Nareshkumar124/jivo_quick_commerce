"""Phase 3 API contract: placing orders, the order shape and the order list (06 §2.6).

Explicit (non-model) serializers: the shapes are the contract, independent of how orders are
stored (Phase 3 R2a). Phase 4 adds the order detail (timeline, invoice) to the same `Order`
shape; additions are backward compatible.
"""

import copy

from rest_framework import serializers

from apps.accounts.serializers import AddressSerializer
from apps.cart.serializers import (
    BillSerializer,
    CartSerializer,
    DeliveryInstructionsSerializer,
)
from apps.catalog.serializers import ImageSetSerializer, money
from apps.delivery.choices import DeliveryTaskStatus
from apps.orders.choices import (
    ActorType,
    CancelReason,
    OrderCancelReason,
    OrderListStatus,
    OrderRefundReason,
    OrderRefundStatus,
    OrderStatus,
    PaymentMethod,
    PaymentStatus,
    ReorderIssueReason,
)

CANCEL_NOTE_MAX_LENGTH = 250


class OrderStoreSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(help_text='e.g. "Jivo Sector 14, Gurugram".')


# The fields of `AddressSerializer` a delivery address snapshot keeps (07 §2.6): no id, default
# or serviceability flags, no timestamps. Same field definitions, so the snapshot serialises
# exactly like the saved address (types, bounds, 6-decimal coordinates).
ORDER_ADDRESS_FIELDS = (
    "label",
    "custom_label",
    "receiver_name",
    "receiver_phone",
    "house",
    "building_street",
    "landmark",
    "area",
    "city",
    "state",
    "pincode",
    "lat",
    "lng",
)


# The Address help texts of these fields describe editing (reset with ""); a snapshot is final.
SNAPSHOT_HELP = {
    "receiver_name": "Who receives the order, as it was at order time.",
    "receiver_phone": "The receiver's phone at order time (E.164).",
}


class OrderAddressSerializer(serializers.Serializer):
    """The delivery address as it was when the order was placed (a snapshot: later edits to the
    saved address do not change it). Same fields and types as `Address`."""

    def get_fields(self):
        source = AddressSerializer().get_fields()
        fields = {}
        for name in ORDER_ADDRESS_FIELDS:
            field = copy.deepcopy(source[name])
            # A snapshot always has every field (the saved address filled the defaults).
            field.required = True
            field.read_only = False
            if name in SNAPSHOT_HELP:
                field.help_text = SNAPSHOT_HELP[name]
            fields[name] = field
        return fields


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
    quantity = serializers.IntegerField(min_value=1, help_text="Units ordered.")
    quantity_unavailable = serializers.IntegerField(
        min_value=0,
        help_text=(
            "Units the store could not supply (08 T8a, Phase 4): removed from the order and "
            "the bill (refunded if paid online). 0 normally. Units coming = `quantity` - "
            "`quantity_unavailable`; show the removed ones struck through."
        ),
    )
    line_mrp_total = money("`mrp` x the units coming (`quantity` - `quantity_unavailable`).")
    line_total = money("`selling_price` x the units coming (`quantity` - `quantity_unavailable`).")


class OrderTimelineEntrySerializer(serializers.Serializer):
    """A state the order reached (08 §1), oldest first."""

    status = serializers.ChoiceField(choices=OrderStatus.choices)
    title = serializers.CharField(
        help_text='The customer label of the state, e.g. "Order confirmed".'
    )
    at = serializers.DateTimeField()


class OrderCancellationSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=OrderCancelReason.choices)
    message = serializers.CharField(help_text="The reason as text to show.")
    cancelled_by = serializers.ChoiceField(
        choices=ActorType.choices,
        help_text="`customer`, `store`, `ops` (Jivo support) or `system` (payment window).",
    )
    cancelled_at = serializers.DateTimeField()


class OrderRefundSerializer(serializers.Serializer):
    """Money going back to the original payment method (08 §4 rule 4, §6.4)."""

    id = serializers.IntegerField()
    amount = money("Amount refunded.")
    status = serializers.ChoiceField(
        choices=OrderRefundStatus.choices,
        help_text=(
            "PENDING: started; banks usually take 5-7 working days. PROCESSED: the gateway "
            "has sent it. A refund the gateway refused is retried by Jivo's team and stays "
            "PENDING here (never FAILED)."
        ),
    )
    reason = serializers.ChoiceField(choices=OrderRefundReason.choices)
    created_at = serializers.DateTimeField()
    processed_at = serializers.DateTimeField(allow_null=True)


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
            "True when `POST /orders/{id}/cancel/` is allowed now (08 §7): PAYMENT_PENDING, "
            "PLACED or ACCEPTED (from PACKING on, show 'Contact support')."
        )
    )
    can_retry_payment = serializers.BooleanField(
        help_text=(
            "True when `POST /orders/{id}/retry-payment/` is allowed now: an ONLINE order in "
            "PAYMENT_PENDING before `payment_expires_at`."
        )
    )
    # Phase 4 (additive)
    timeline = OrderTimelineEntrySerializer(
        many=True, help_text="Every state reached, oldest first (Phase 4)."
    )
    cancellation = OrderCancellationSerializer(
        allow_null=True, help_text="Set when the order is CANCELLED; null otherwise (Phase 4)."
    )
    amount_refunded = money(
        "Refunded so far (processed refunds), Phase 4. `bill` is always the current bill: "
        "after items were found unavailable it is the reduced one."
    )
    refunds = OrderRefundSerializer(
        many=True, help_text="Refunds of this order, oldest first; [] when none (Phase 4)."
    )
    can_download_invoice = serializers.BooleanField(
        help_text=(
            "True when `GET /orders/{id}/invoice/` has an invoice: DELIVERED orders (Phase 4)."
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


class OrderInvoiceSerializer(serializers.Serializer):
    """`GET /orders/{id}/invoice/`: a short-lived link to the GST invoice PDF."""

    invoice_number = serializers.CharField(help_text='e.g. "GGN01/26-27/000123".')
    issued_at = serializers.DateTimeField()
    url = serializers.URLField(
        help_text="Signed link to the PDF; open or download it before `expires_at`."
    )
    expires_at = serializers.DateTimeField()


class ReorderIssueSerializer(serializers.Serializer):
    variant_id = serializers.IntegerField()
    product_name = serializers.CharField()
    variant_name = serializers.CharField()
    requested_quantity = serializers.IntegerField(
        min_value=1, help_text="Units in the past order (those that were delivered or coming)."
    )
    added_quantity = serializers.IntegerField(
        min_value=0, help_text="Units now in the cart for this variant (0 = not added)."
    )
    reason = serializers.ChoiceField(choices=ReorderIssueReason.choices)


class ReorderResultSerializer(serializers.Serializer):
    cart = CartSerializer(help_text="The whole cart after the items were added.")
    added_count = serializers.IntegerField(
        min_value=0,
        help_text=(
            "How many of the order's lines now have at least one unit in the cart (e.g. for "
            '"3 items added"). 0: nothing could be added.'
        ),
    )
    unavailable = ReorderIssueSerializer(
        many=True,
        help_text="Lines that could not be added in full; [] when everything was added.",
    )


# --------------------------------------------------------------------------- tracking (Phase 5)


class TrackPointSerializer(serializers.Serializer):
    lat = serializers.FloatField(help_text="Latitude (WGS84).")
    lng = serializers.FloatField(help_text="Longitude (WGS84).")


class TrackStoreSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    lat = serializers.FloatField()
    lng = serializers.FloatField()


class TrackRiderSerializer(serializers.Serializer):
    """The assigned rider, shown from assignment until the order ends (08 §9)."""

    name = serializers.CharField(help_text="The rider's first name and last initial.")
    phone = serializers.CharField(
        allow_null=True,
        help_text=(
            "E.164. Only while the order is OUT_FOR_DELIVERY (and only to the order's owner); "
            "null otherwise. Masked/proxy calling is planned."
        ),
    )
    photo = serializers.URLField(
        allow_null=True,
        help_text=(
            "Signed https link to the rider's photo, valid about an hour (re-read `track/` "
            "for a fresh one); null without a photo."
        ),
    )
    lat = serializers.FloatField(allow_null=True, help_text="Last known position; null if none.")
    lng = serializers.FloatField(allow_null=True)
    updated_at = serializers.DateTimeField(
        allow_null=True, help_text="When that position was recorded."
    )


class OrderTrackSerializer(serializers.Serializer):
    """`GET /orders/{id}/track/` (api-requests #28): poll every 10 s while the tracking screen is
    open (WebSocket from Phase 6)."""

    order_id = serializers.IntegerField()
    order_number = serializers.CharField(help_text='e.g. "JV-261110-001203".')
    status = serializers.ChoiceField(choices=OrderStatus.choices)
    eta_at = serializers.DateTimeField(
        allow_null=True, help_text="Promised delivery time (08 §8); null once the order ended."
    )
    store = TrackStoreSerializer()
    destination = TrackPointSerializer(help_text="The delivery pin.")
    rider = TrackRiderSerializer(
        allow_null=True,
        help_text="Null until a rider accepts, and again once the order is finished.",
    )
    delivery_otp = serializers.CharField(
        allow_null=True,
        help_text=(
            "The 4-digit OTP to give the rider, only while OUT_FOR_DELIVERY; null otherwise. "
            "Never share it before the rider arrives."
        ),
    )
    task_status = serializers.ChoiceField(
        choices=DeliveryTaskStatus.choices,
        allow_null=True,
        help_text=(
            "The order's delivery task status (SEARCHING, OFFERED, ASSIGNED, AT_STORE, "
            "PICKED_UP, AT_CUSTOMER, DELIVERED, FAILED, ...); null while no task exists "
            "(before dispatch starts)."
        ),
    )
    server_time = serializers.DateTimeField()
