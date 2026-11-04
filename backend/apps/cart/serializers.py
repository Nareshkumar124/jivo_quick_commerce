"""Phase 3 API contract: the server cart and its bill (06 §2.5, 08 §6.2).

Explicit (non-model) serializers: the shapes are the contract, independent of how carts are
stored (Phase 3 R2a). Every amount is computed by the server (`cart.services.compute_bill`); the
app renders it and never adds anything up itself.
"""

from django.conf import settings
from rest_framework import serializers

from apps.accounts.serializers import AddressSerializer
from apps.cart.choices import (
    CartLineIssueCode,
    CheckoutBlockerCode,
    DeliveryInstructionChip,
    PaymentUnavailableReason,
)
from apps.catalog.serializers import VariantSummarySerializer, money
from apps.orders.choices import PaymentMethod
from apps.stores.serializers import StoreStatusSerializer

MAX_LINE_QUANTITY = 1000  # request sanity bound; the real limit is the variant's max_qty_per_order
INSTRUCTIONS_NOTE_MAX_LENGTH = 200


def money_or_null(help_text: str) -> serializers.DecimalField:
    """A 2-decimal money string, or null."""
    return serializers.DecimalField(
        max_digits=12, decimal_places=2, allow_null=True, help_text=help_text
    )


class BillSerializer(serializers.Serializer):
    """The bill (08 §6.2), from `cart.services.compute_bill()`: the same function prices the
    cart, places the order and recalculates it. Every amount is a 2-decimal string, rounded
    half-up. Fee thresholds compare against `item_total` (before the coupon, D-09).

    `grand_total = item_total - coupon_discount + delivery_fee + small_cart_fee + handling_fee
    + tip`. An empty cart's bill is all zeros."""

    mrp_total = money("Sum of MRP x quantity. The struck-out 'Item total (MRP)'.")
    item_total = money("Sum of the store selling price x quantity (store price override applied).")
    product_discount = money("`mrp_total` - `item_total`.")
    coupon_discount = money(
        "Discount of the applied coupon, capped by its `max_discount` and by `item_total`. "
        '"0.00" without a coupon or when the coupon does not apply.'
    )
    delivery_fee = money(
        'Store delivery fee, "0.00" when `item_total` >= the free-delivery threshold: show '
        '"FREE" when "0.00".'
    )
    small_cart_fee = money(
        'Charged when `item_total` is below the store\'s small-cart threshold, else "0.00".'
    )
    handling_fee = money('Store handling fee ("0.00" by default).')
    tip = money('Rider tip chosen by the customer ("0.00" when none). Goes fully to the rider.')
    grand_total = money("**To pay.** Not rounded to the rupee in v1.")
    total_savings = money(
        "`product_discount` + `coupon_discount`: the highlighted 'You save' amount."
    )


class DeliveryInstructionsSerializer(serializers.Serializer):
    """03 §2.8: chips plus free text, shown to the rider."""

    chips = serializers.ListField(
        child=serializers.ChoiceField(choices=DeliveryInstructionChip.choices),
        max_length=len(DeliveryInstructionChip.choices),
        help_text="Selected chips, each at most once (order kept).",
    )
    note = serializers.CharField(
        max_length=INSTRUCTIONS_NOTE_MAX_LENGTH,
        allow_blank=True,
        trim_whitespace=True,
        help_text='Free text for the rider ("" when none).',
    )

    def validate_chips(self, value: list[str]) -> list[str]:
        if len(set(value)) != len(value):
            raise serializers.ValidationError("Each chip can be selected once.")
        return value


class CartProductSerializer(serializers.Serializer):
    """The product a cart line belongs to (for the line title and the product link)."""

    id = serializers.IntegerField()
    slug = serializers.SlugField(help_text="`GET /products/{slug}/`.")
    name = serializers.CharField()
    brand = serializers.CharField()
    is_veg = serializers.BooleanField()


class CartLineIssueSerializer(serializers.Serializer):
    code = serializers.ChoiceField(choices=CartLineIssueCode.choices)
    message = serializers.CharField(help_text="Display text, e.g. 'Only 2 left'.")


class CartLineSerializer(serializers.Serializer):
    """One variant in the cart, priced and checked against stock at the store right now."""

    id = serializers.IntegerField(help_text="Line id for `PATCH`/`DELETE /cart/items/{id}/`.")
    product = CartProductSerializer()
    variant = VariantSummarySerializer(
        help_text=(
            "The variant with its current price and stock at this store (same shape as the "
            "catalog). Cap the stepper at `orderable_quantity`."
        )
    )
    quantity = serializers.IntegerField(min_value=1)
    line_mrp_total = money("`variant.mrp` x `quantity`.")
    line_total = money("`variant.selling_price` x `quantity`.")
    issue = CartLineIssueSerializer(
        allow_null=True,
        help_text=(
            "Set when the line cannot be ordered as it is (quantity above "
            "`variant.orderable_quantity`, which is 0 when out of stock or no longer sold). "
            "Fix: set the quantity to `variant.orderable_quantity`, or remove the line when it "
            "is 0. Null when the line is fine."
        ),
    )


class AppliedCouponSerializer(serializers.Serializer):
    code = serializers.CharField()
    title = serializers.CharField(help_text='e.g. "Flat ₹50 off".')
    discount = money('The discount it gives this cart now ("0.00" when it does not apply).')
    is_applicable = serializers.BooleanField(
        help_text=(
            "False when the cart no longer qualifies (e.g. items removed): the coupon stays "
            "applied but gives nothing, and checkout is blocked until it is removed or the cart "
            "qualifies again (see `checkout.blockers`)."
        )
    )
    message = serializers.CharField(
        allow_null=True,
        help_text="Why it does not apply (e.g. 'Add items worth ₹74 more'); null when it does.",
    )
    amount_to_unlock = money_or_null(
        "When it does not apply because the item total is below its minimum: the item value "
        "still needed (for the app's own 'Add items worth ₹X more'). Null otherwise. Added in "
        "Phase 3 R2b, like `CouponOffer.amount_to_unlock`."
    )


class CartThresholdsSerializer(serializers.Serializer):
    """The store's thresholds and how far the cart is from them (computed by the server, so the
    app never subtracts money). All compare against `bill.item_total`."""

    min_order_value = money("Minimum item total to place an order.")
    amount_to_min_order = money_or_null(
        "Item value still needed to reach the minimum; null when it is reached."
    )
    free_delivery_threshold = money_or_null(
        "Item total from which delivery is free; null when the store charges no delivery fee."
    )
    amount_to_free_delivery = money_or_null(
        "For the nudge 'Add ₹X more for free delivery'; null when delivery is already free."
    )


class PaymentOptionSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=PaymentMethod.choices)
    is_available = serializers.BooleanField(
        help_text="Show the method only when true (03 §2.9: COD is shown only if eligible)."
    )
    unavailable_reason = serializers.ChoiceField(
        choices=PaymentUnavailableReason.choices, allow_null=True
    )
    message = serializers.CharField(
        allow_null=True, help_text="Display text when not available; null when available."
    )


class CheckoutBlockerSerializer(serializers.Serializer):
    code = serializers.ChoiceField(choices=CheckoutBlockerCode.choices)
    message = serializers.CharField(help_text="Display text with the fix, in English.")


class CheckoutStatusSerializer(serializers.Serializer):
    can_place_order = serializers.BooleanField(
        help_text="Enable the checkout button only when true (no blockers)."
    )
    blockers = CheckoutBlockerSerializer(
        many=True, help_text="Everything that stops the order now, most important first."
    )


class CartSerializer(serializers.Serializer):
    """The customer's cart at the store in `X-Store-Id` (one cart per user)."""

    store = StoreStatusSerializer(help_text="The store pricing this cart, and whether it is open.")
    items = CartLineSerializer(many=True, help_text="Lines in the order they were added.")
    item_count = serializers.IntegerField(
        min_value=0, help_text="Units in the cart (sum of quantities), for the cart badge."
    )
    coupon = AppliedCouponSerializer(allow_null=True, help_text="Null when no coupon is applied.")
    tip = money("The chosen rider tip (kept while the cart is empty; billed only with items).")
    instructions = DeliveryInstructionsSerializer()
    address = AddressSerializer(
        allow_null=True,
        read_only=True,
        help_text=(
            "The delivery address the cart is checked against: `?address_id=` when sent, else "
            "the one saved with `PATCH /cart/`. Null when none is selected."
        ),
    )
    bill = BillSerializer()
    thresholds = CartThresholdsSerializer()
    payment_methods = PaymentOptionSerializer(
        many=True, help_text="ONLINE then COD, each with its availability for this cart."
    )
    checkout = CheckoutStatusSerializer()


# --------------------------------------------------------------------------- requests


class CartQuerySerializer(serializers.Serializer):
    address_id = serializers.IntegerField(
        required=False,
        min_value=1,
        help_text=(
            "Check the cart against this saved address (not saved to the cart). Default: the "
            "cart's address. Unknown or another user's address: 400."
        ),
    )


class CartUpdateSerializer(serializers.Serializer):
    """Partial update: send only the fields that change."""

    tip = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=0,
        max_value=settings.CART_MAX_TIP,
        required=False,
        # Fixed text: the published contract must not depend on the environment's setting.
        help_text=(
            'Rider tip, e.g. "20.00"; "0.00" removes it. At most the server\'s tip limit '
            "(`CART_MAX_TIP`, ₹500 by default)."
        ),
    )
    instructions = DeliveryInstructionsSerializer(
        required=False, help_text="Replaces the instructions (chips and note) as a whole."
    )
    address_id = serializers.IntegerField(
        required=False,
        min_value=1,
        help_text=(
            "One of the caller's saved addresses. It must be inside the service area of the "
            "store in `X-Store-Id`, else 422 `NOT_SERVICEABLE` and nothing is saved."
        ),
    )


class CartItemAddSerializer(serializers.Serializer):
    variant_id = serializers.IntegerField(min_value=1, help_text="`VariantSummary.id`.")
    quantity = serializers.IntegerField(
        min_value=0,
        max_value=MAX_LINE_QUANTITY,
        help_text=(
            "The line's **new** quantity for this variant (not an increment), so a retried "
            "request does not add twice. 0 removes the line."
        ),
    )


class CartItemUpdateSerializer(serializers.Serializer):
    """The new quantity of a cart line (`quantity` is required)."""

    # Never partial, although it is a PATCH body: DRF and drf-spectacular set `partial` for PATCH,
    # which would publish `quantity` as optional (a `Patched...` component).
    @property
    def partial(self) -> bool:
        return False

    @partial.setter
    def partial(self, value: bool) -> None:
        pass  # DRF and drf-spectacular set it for PATCH; this body is complete by design

    quantity = serializers.IntegerField(
        min_value=1,
        max_value=MAX_LINE_QUANTITY,
        help_text="The line's new quantity. Use `DELETE` to remove the line.",
    )


class CouponApplySerializer(serializers.Serializer):
    code = serializers.CharField(
        max_length=30,
        trim_whitespace=True,
        help_text="Coupon code as typed; case-insensitive.",
    )
