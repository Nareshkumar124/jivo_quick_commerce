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
from apps.catalog.serializers import PriceTierSerializer, VariantSummarySerializer, money
from apps.orders.choices import FreeSource, PaymentMethod
from apps.promotions.choices import CouponSource, DiscountType
from apps.stores.serializers import StoreStatusSerializer

# Request sanity bound; the real limits are the variant's min/max per order.
MAX_LINE_QUANTITY = 1000
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
        "`product_discount` + `coupon_discount` + `free_items_value`: the highlighted 'You "
        "save' amount."
    )
    free_items_value = money(
        "ADR 0002: the MRP value of the free cartons (MRP x free quantity; the volume offer and "
        "a free-carton reward). They cost ₹0: not part of `item_total`, the fees, the coupon "
        'minimum, the COD limit or `grand_total`. "0.00" when there are none.'
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
    price_per_unit = money(
        "The price each unit of this line is billed at (show it, e.g. '₹85/box'): the volume "
        "tier's price when `price_tier` is set, else `variant.selling_price`."
    )
    previous_selling_price = money_or_null(
        "Display only, never billed (API request #56): the store's selling price when the "
        "customer last set this line's quantity, when it differs from today's "
        "`variant.selling_price` (show 'Price changed from ₹X'). Both are the store's price "
        "before volume tiers, so a tier reached by the cart's own units is not a price change "
        "(see `price_tier`). Null when the price is unchanged, or for lines added before this "
        "field existed. Clears on the next quantity set for the line (`POST /cart/items/` or "
        "`PATCH /cart/items/{id}/`, the same quantity included, which is how the app "
        "acknowledges it). Not a checkout blocker: the bill already uses today's price."
    )
    price_tier = PriceTierSerializer(
        allow_null=True,
        help_text=(
            "The volume tier applied to this line (ADR 0001): reached by the units of all "
            "tiered items in the cart together. Null when the normal price applies."
        ),
    )
    next_tier_price = money_or_null(
        "This line's lower unit price once the cart reaches `thresholds.next_price_tier`; null "
        "when that tier does not lower this line's price (or there is no next tier)."
    )
    line_mrp_total = money("`variant.mrp` x `quantity`.")
    line_total = money("`price_per_unit` x `quantity`.")
    issue = CartLineIssueSerializer(
        allow_null=True,
        help_text=(
            "Set when the line cannot be ordered as it is: quantity above "
            "`variant.orderable_quantity` (which is 0 when out of stock or no longer sold), or "
            "below `variant.min_qty_per_order` (`MIN_QTY_REQUIRED`, e.g. the minimum was raised "
            "after the line was added). Fix: set the quantity to `variant.orderable_quantity` "
            "(for `MIN_QTY_REQUIRED`, to `variant.min_qty_per_order`), or remove the line when "
            "`orderable_quantity` is 0. Null when the line is fine."
        ),
    )


class AppliedCouponSerializer(serializers.Serializer):
    code = serializers.CharField()
    title = serializers.CharField(help_text='e.g. "Flat ₹50 off".')
    discount_type = serializers.ChoiceField(
        choices=DiscountType.choices,
        help_text=(
            "FREE_UNIT: a free-carton reward (ADR 0002). It gives no money off (`discount` is "
            '"0.00"); its carton is in `free_lines` with `source` REWARD.'
        ),
    )
    source = serializers.ChoiceField(
        choices=CouponSource.choices,
        help_text="Why the coupon exists: WELCOME / REFERRAL_* rewards, NONE for staff coupons.",
    )
    free_variant_id = serializers.IntegerField(
        allow_null=True,
        help_text=(
            "FREE_UNIT only: the size of the free cartons (`VariantSummary.id`). ADR 0003: when "
            "the store has a fixed free size (`free_offer.free_variant`), it is that size; else "
            "the size the customer picked (ADR 0002). Null for other coupons."
        ),
    )
    free_quantity = serializers.IntegerField(
        allow_null=True,
        min_value=1,
        help_text=(
            "ADR 0003: FREE_UNIT only, the number of free cartons the reward gives (e.g. 2). "
            "Null for other coupons."
        ),
    )
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


class FreeVariantSerializer(serializers.Serializer):
    """ADR 0003: the size every free carton uses at the store (e.g. "Jivo Water", "1 L x 12")."""

    id = serializers.IntegerField(help_text="`VariantSummary.id`.")
    name = serializers.CharField(help_text='The size, e.g. "1 L x 12".')
    product_name = serializers.CharField(help_text='The product, e.g. "Jivo Water".')


class FreeLineSerializer(serializers.Serializer):
    """ADR 0002: a free carton on the cart (₹0). Computed by the server on every cart read:
    never add, remove or price these in the app."""

    product = CartProductSerializer()
    variant = VariantSummarySerializer(
        help_text="The free carton's size (same shape as the catalog)."
    )
    quantity = serializers.IntegerField(min_value=1, help_text="Free cartons of this size.")
    mrp = money("Unit MRP of the free carton.")
    value = money("`mrp` x `quantity`: what the customer saves (part of `bill.free_items_value`).")
    source = serializers.ChoiceField(
        choices=FreeSource.choices,
        help_text=(
            "VOLUME_OFFER: 1 free for every `free_offer.every` paid cartons (the store's fixed "
            "free size `free_offer.free_variant` when set, ADR 0003; else the cheapest size in "
            "the cart). REWARD: the free-carton reward applied as the cart's coupon."
        ),
    )


class FreeOfferSerializer(serializers.Serializer):
    """ADR 0002 §3: the store's volume offer, "1 free carton for every `every` paid cartons".
    Paid cartons are counted like `thresholds.min_order_units` (each line counts
    min(`quantity`, `orderable_quantity`)); free cartons never count."""

    every = serializers.IntegerField(
        min_value=1, help_text="Paid cartons per free carton (e.g. 10)."
    )
    paid_units = serializers.IntegerField(min_value=0, help_text="Paid cartons counted now.")
    free_units = serializers.IntegerField(
        min_value=0,
        help_text=(
            "Free cartons earned: `paid_units` // `every`. The ones the store can supply are in "
            "`free_lines` (VOLUME_OFFER); see `notice` when they cannot be supplied."
        ),
    )
    units_to_next_free = serializers.IntegerField(
        min_value=1, help_text="Paid cartons still to add for one more free carton."
    )
    message = serializers.CharField(
        help_text='Ready-made nudge, e.g. "Add 8 more cartons to get 1 more free".'
    )
    notice = serializers.CharField(
        allow_null=True,
        help_text=(
            "Set when a free carton was earned but the store cannot supply it (the fixed free "
            "size has no stock, ADR 0003; or no size in the cart has the stock, ADR 0002): no "
            "free carton is given. Show it as a notice; it does not block checkout. Null "
            "otherwise."
        ),
    )
    free_variant = FreeVariantSerializer(
        allow_null=True,
        help_text=(
            "ADR 0003: the store's fixed free size; every free carton (this offer and rewards) "
            'is this size, e.g. "Jivo Water 1 L x 12". Shown also before a free carton is '
            "earned. Null when the store has none: the free cartons are then the cheapest size "
            "in the cart (ADR 0002)."
        ),
    )


class NextPriceTierSerializer(serializers.Serializer):
    min_order_units = serializers.IntegerField(
        min_value=1, help_text="The tier units the next lower prices start at."
    )
    units_to_next_tier = serializers.IntegerField(
        min_value=1, help_text="Units still to add (any tiered item) to reach it."
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
    min_order_units = serializers.IntegerField(
        min_value=0,
        help_text=(
            "Fewest units one order must have, any mix of items (e.g. 5 cartons); 0 = no "
            "minimum. Not compared with `bill.item_total`: units are counted per line as "
            "min(`quantity`, `variant.orderable_quantity`), so an out-of-stock line counts 0."
        ),
    )
    units_to_min_order = serializers.IntegerField(
        allow_null=True,
        min_value=1,
        help_text=(
            "Units still needed ('Add 2 more cartons'); null when the minimum is met or there is "
            "none. While set, checkout is blocked with `MIN_UNITS_NOT_MET`."
        ),
    )
    tier_units = serializers.IntegerField(
        min_value=0,
        help_text=(
            "Units that choose the volume price tier (ADR 0001): every line whose variant has "
            "`price_tiers`, any mix, each counting min(`quantity`, `orderable_quantity`). 0 when "
            "no line has tiers."
        ),
    )
    next_price_tier = NextPriceTierSerializer(
        allow_null=True,
        help_text=(
            "The nudge 'Add 3 more boxes to get ₹87/box': the next tier at which a line's price "
            "drops (each line's new price is its `next_tier_price`). Null at the top tier or "
            "when no line has tiers."
        ),
    )
    order_unit_label = serializers.CharField(
        help_text='What a unit is called, in the plural, e.g. "cartons" ("items" by default).'
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
    free_lines = FreeLineSerializer(
        many=True,
        help_text=(
            "ADR 0002: free cartons (₹0), volume offer first, then the reward. [] when none. "
            "Placing the order adds them as order lines with `is_free: true`."
        ),
    )
    free_offer = FreeOfferSerializer(
        allow_null=True, help_text="The store's volume offer; null when the store has none."
    )
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
    free_variant_id = serializers.IntegerField(
        required=False,
        allow_null=True,
        min_value=1,
        help_text=(
            "For a free-carton reward (`discount_type` FREE_UNIT). ADR 0003: when the store in "
            "`X-Store-Id` has a fixed free size (`free_offer.free_variant`), leave it out (or "
            "send that size's id): the server uses the fixed size; any other id is 422 "
            "`COUPON_NOT_ELIGIBLE` (FREE_VARIANT_UNAVAILABLE). Otherwise (ADR 0002) it is "
            "required: the size the customer picked (`VariantSummary.id`), sold at the store, of "
            "the same product category as a paid line in the cart (a water reward goes on a "
            "water order) and with the stock. Ignored for other coupons."
        ),
    )
