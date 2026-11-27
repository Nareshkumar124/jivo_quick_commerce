"""The server cart and the pricing engine (06 §2.5, 08 §6.2).

`compute_bill()` is the only function that computes money: the cart, order placement and the
partial-unavailability recalculation (Phase 4) all call it. Amounts are `Decimal`, rounded
half-up to the paisa; the API sends 2-decimal strings.

The cart follows the store in `X-Store-Id`: lines keep their quantities and take that store's
prices and stock on every read. It never reserves stock (08 §6.1). A line above what the store
can supply is flagged (`issue`) and blocks checkout; the server never changes the cart silently.

Free cartons (ADR 0002) are computed here too, next to `load_lines()`, and passed into
`compute_bill()`: the store's volume offer (1 free carton for every `free_unit_every` paid ones)
and a free-carton reward applied as the cart's coupon (`value` cartons, ADR 0003). Their size is
the store's fixed free size (`PricingConfig.free_unit_variant`, ADR 0003) when it has one; else
the volume offer uses the cheapest size in the cart and the reward the size the customer picked
(ADR 0002). They cost ₹0: never part of `item_total`, the fees, the coupon minimum or the COD
limit; their MRP value is `free_items_value` (part of `total_savings`). Free cartons never count
as paid units.

Every cart and coupon operation goes through this module. Callers pass the store as resolved from
`X-Store-Id` (`apps.stores.services.StoreArea`: id, name, hours and service area, no query).
"""

from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.db.models import F, FilteredRelation, Prefetch, Q, Value
from django.db.models.functions import Coalesce
from django.db.models.query import prefetch_related_objects
from rest_framework.exceptions import NotFound, ValidationError

from apps.accounts.models import Address
from apps.accounts.serializers import AddressSerializer
from apps.accounts.services.addresses import live_addresses
from apps.cart.choices import CartLineIssueCode, CheckoutBlockerCode, PaymentUnavailableReason
from apps.cart.models import Cart, CartItem, empty_instructions
from apps.catalog.models import ProductImage, ProductVariant
from apps.catalog.services import (
    effective_price_expression,
    tier_prefetch,
    variant_summary,
    variant_tiers,
)
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import ZERO, money_str, round_money, rupees
from apps.inventory.services import availability
from apps.orders.choices import FreeSource, PaymentMethod
from apps.payments.switch import MSG_ONLINE_DISABLED, online_payments_enabled
from apps.promotions import services as promotions
from apps.promotions.choices import CouponIneligibleReason
from apps.stores.models import PricingConfig
from apps.stores.services import StoreArea, status_message, store_status

MSG_LINE_NOT_FOUND = "Cart item not found."
MSG_ADDRESS_NOT_FOUND = "Address not found."
MSG_ADDRESS_NOT_SERVED = "We do not deliver to this address from this store."
MSG_STOCK_BLOCKER = (
    "Some items are out of stock or not available in the quantity you chose. Update them to "
    "continue."
)
MSG_MIN_QTY_BLOCKER = (
    "Some items are below their minimum quantity per order. Increase them or remove them to "
    "continue."
)

# --------------------------------------------------------------------------- pricing rules


@dataclass(frozen=True, slots=True)
class PricingRules:
    """A store's `PricingConfig` values (08 §6.2, D-09)."""

    min_order_value: Decimal
    delivery_fee: Decimal
    free_delivery_threshold: Decimal
    small_cart_fee: Decimal
    small_cart_threshold: Decimal
    handling_fee: Decimal
    cod_enabled: bool
    cod_max_order_value: Decimal
    min_order_units: int = 0  # 0 = no minimum
    order_unit_label: str = "items"
    free_unit_every: int = 0  # ADR 0002 volume offer: 1 free per this many paid; 0 = off
    free_unit_variant_id: int | None = None  # ADR 0003: the size of every free carton; None =
    # the ADR 0002 rules (cheapest size in the cart; the customer picks a reward's size)

    @classmethod
    def from_config(cls, config: PricingConfig) -> "PricingRules":
        return cls(
            min_order_value=config.min_order_value,
            delivery_fee=config.delivery_fee,
            free_delivery_threshold=config.free_delivery_threshold,
            small_cart_fee=config.small_cart_fee,
            small_cart_threshold=config.small_cart_threshold,
            handling_fee=config.handling_fee,
            cod_enabled=config.cod_enabled,
            cod_max_order_value=config.cod_max_order_value,
            min_order_units=config.min_order_units,
            order_unit_label=config.order_unit_label,
            free_unit_every=config.free_unit_every,
            free_unit_variant_id=config.free_unit_variant_id,
        )


def pricing_rules(store_id: int) -> PricingRules:
    """The store's pricing config; a store without one is billed with the model defaults
    (the D-09 values)."""
    config = PricingConfig.objects.filter(store_id=store_id).first() or PricingConfig()
    return PricingRules.from_config(config)


# --------------------------------------------------------------------------- the bill


@dataclass(frozen=True, slots=True)
class BillLine:
    variant_id: int
    category_id: int
    mrp: Decimal
    selling_price: Decimal
    quantity: int

    @property
    def line_total(self) -> Decimal:
        return self.selling_price * self.quantity

    @property
    def line_mrp_total(self) -> Decimal:
        return self.mrp * self.quantity


@dataclass(frozen=True, slots=True)
class Bill:
    mrp_total: Decimal = ZERO
    item_total: Decimal = ZERO
    product_discount: Decimal = ZERO
    coupon_discount: Decimal = ZERO
    delivery_fee: Decimal = ZERO
    small_cart_fee: Decimal = ZERO
    handling_fee: Decimal = ZERO
    tip: Decimal = ZERO
    grand_total: Decimal = ZERO
    total_savings: Decimal = ZERO
    free_items_value: Decimal = ZERO  # ADR 0002: MRP x quantity of the free cartons

    FIELDS = (
        "mrp_total",
        "item_total",
        "product_discount",
        "coupon_discount",
        "delivery_fee",
        "small_cart_fee",
        "handling_fee",
        "tip",
        "grand_total",
        "total_savings",
        "free_items_value",
    )

    def as_dict(self) -> dict:
        """The API `Bill`: every amount a 2-decimal string."""
        return {name: money_str(getattr(self, name)) for name in self.FIELDS}


EMPTY_BILL = Bill()


def item_total(lines: Sequence[BillLine]) -> Decimal:
    """Σ selling price x quantity, rounded (08 §6.2): the base of every fee threshold and of the
    coupon's minimum order. The only place it is computed (code review F6)."""
    return round_money(sum((line.line_total for line in lines), ZERO))


def clamp_tip(tip) -> Decimal:
    """The tip billed: rounded, never negative and never above `CART_MAX_TIP` (code review F1:
    the cap is enforced here, in the money function, not only by the API serializer)."""
    return min(max(round_money(tip), ZERO), round_money(settings.CART_MAX_TIP))


def free_items_value(free_lines: Sequence[BillLine]) -> Decimal:
    """ADR 0002: what the free cartons are worth, MRP x quantity (they are billed at ₹0)."""
    return round_money(sum((line.line_mrp_total for line in free_lines), ZERO))


def compute_bill(
    lines: Sequence[BillLine],
    rules: PricingRules,
    *,
    coupon=None,
    tip: Decimal = ZERO,
    fixed_coupon_discount: Decimal | None = None,
    fee_caps: Bill | None = None,
    free_lines: Sequence[BillLine] = (),
) -> Bill:
    """08 §6.2. `coupon` is a coupon already found applicable (promotions.check_coupon), or
    None. Fee thresholds compare against `item_total`, before the coupon (D-09). An empty cart's
    bill is all zeros (no fees, no tip).

    Recalculation after items were found unavailable (08 §6.3, T8a): `fixed_coupon_discount` is
    the order's original coupon discount, kept but capped at the new `item_total`, and
    `fee_caps` is the order's bill before the change: each fee is recalculated but never above
    what it was, so the amount payable never increases."""
    if not lines:
        return EMPTY_BILL
    mrp_total = round_money(sum((line.line_mrp_total for line in lines), ZERO))
    items_total = item_total(lines)
    coupon_discount = ZERO
    if fixed_coupon_discount is not None:
        coupon_discount = min(fixed_coupon_discount, items_total)
    elif coupon is not None:
        coupon_discount = min(promotions.coupon_discount(coupon, lines), items_total)
    delivery_fee = ZERO if items_total >= rules.free_delivery_threshold else rules.delivery_fee
    small_cart_fee = rules.small_cart_fee if items_total < rules.small_cart_threshold else ZERO
    handling_fee = rules.handling_fee
    if fee_caps is not None:
        delivery_fee = min(delivery_fee, fee_caps.delivery_fee)
        small_cart_fee = min(small_cart_fee, fee_caps.small_cart_fee)
        handling_fee = min(handling_fee, fee_caps.handling_fee)
    tip = clamp_tip(tip)
    product_discount = mrp_total - items_total
    grand_total = items_total - coupon_discount + delivery_fee + small_cart_fee + handling_fee + tip
    free_value = free_items_value(free_lines)
    return Bill(
        mrp_total=mrp_total,
        item_total=items_total,
        product_discount=product_discount,
        coupon_discount=round_money(coupon_discount),
        delivery_fee=round_money(delivery_fee),
        small_cart_fee=round_money(small_cart_fee),
        handling_fee=round_money(handling_fee),
        tip=tip,
        grand_total=round_money(grand_total),
        total_savings=round_money(product_discount + coupon_discount + free_value),
        free_items_value=free_value,
    )


def ensure_expected_total(bill: Bill, expected: Decimal) -> None:
    """08 T1 guard: the bill must equal the total the customer saw, else 409 `PRICE_CHANGED`
    (the app reloads the cart and shows the new bill)."""
    if round_money(expected) != bill.grand_total:
        raise ApiError(
            ErrorCode.PRICE_CHANGED,
            details={
                "expected_grand_total": money_str(expected),
                "grand_total": money_str(bill.grand_total),
            },
        )


# --------------------------------------------------------------------------- cart lines


def store_variants(
    store_id: int, variant_ids: Sequence[int], *, with_images: bool = True
) -> dict[int, ProductVariant]:
    """Variants by id with their price and stock at the store (`inv_*`, as the catalog
    annotates them), including variants the store does not sell (no stock, no override)."""
    queryset = (
        ProductVariant.objects.filter(pk__in=variant_ids)
        .annotate(
            store_inv=FilteredRelation("inventory", condition=Q(inventory__store_id=store_id))
        )
        .annotate(
            inv_id=F("store_inv__id"),
            inv_on_hand=Coalesce(F("store_inv__on_hand"), Value(0)),
            inv_reserved=Coalesce(F("store_inv__reserved"), Value(0)),
            inv_is_available=Coalesce(F("store_inv__is_available"), Value(False)),
            inv_price=effective_price_expression("store_inv__price_override"),
        )
        .select_related("product__category__parent")
    )
    if with_images:  # the full summary (cart lines): images and price tiers too
        ordered_images = ProductImage.objects.order_by("sort_order", "id")
        queryset = queryset.prefetch_related(
            Prefetch("images", queryset=ordered_images, to_attr="own_images"),
            Prefetch(
                "product__images",
                queryset=ordered_images.filter(variant__isnull=True),
                to_attr="shared_images",
            ),
            tier_prefetch(),
        )
    variants = {variant.pk: variant for variant in queryset}
    for variant in variants.values():
        # Not sold here (no stock row) or not visible any more: never orderable.
        variant.inv_is_available = bool(variant.inv_is_available) and is_sellable(variant)
    return variants


def is_sellable(variant: ProductVariant) -> bool:
    product, category = variant.product, variant.product.category
    parent_ok = category.parent_id is None or category.parent.is_active
    return (
        variant.inv_id is not None
        and variant.is_active
        and product.is_active
        and category.is_active
        and parent_ok
    )


@dataclass(slots=True)
class CartLine:
    item: CartItem
    variant: ProductVariant
    summary: dict
    issue: dict | None
    # The unit price billed, fixed by `load_lines()` (`apply_price_tiers()`): the volume tier
    # reached, else the store's price. None (a line built elsewhere): the store's price.
    price: Decimal | None = None
    tier: object | None = None  # the `VariantPriceTier` applied, if any
    next_price: Decimal | None = None  # this line's lower price at the next tier (the nudge)

    @property
    def unit_price(self) -> Decimal:
        # `inv_price` is the store's normal price (override or `selling_price`), the price a
        # line has when no tier applies. A line built outside `load_lines()` (price None) is
        # billed at it, exactly as before tiers existed; `price_at()` starts from it for the
        # same reason, so a tier can only ever lower it.
        return self.price if self.price is not None else self.variant.inv_price

    @property
    def previous_selling_price(self) -> Decimal | None:
        """API request #56 (display only, never billed): the store's selling price when the
        customer last set this line's quantity, when it differs from today's
        (`variant.selling_price`, the store's price before volume tiers). Tier moves caused by
        the cart's own units are not price changes (they show in `price_tier`). Null for lines
        stored before the snapshot existed."""
        seen = self.item.seen_selling_price
        return seen if seen is not None and seen != self.variant.inv_price else None

    @property
    def has_stock_issue(self) -> bool:
        """The store cannot supply the line as it is (out of stock or above what it can)."""
        return self.issue is not None and not self.below_minimum

    @property
    def below_minimum(self) -> bool:
        """The line is under the variant's minimum per order (e.g. the minimum was raised)."""
        return self.issue is not None and self.issue["code"] == CartLineIssueCode.MIN_QTY_REQUIRED

    @property
    def bill_line(self) -> BillLine:
        return BillLine(
            variant_id=self.variant.pk,
            category_id=self.variant.product.category_id,
            mrp=self.variant.mrp,
            selling_price=self.unit_price,
            quantity=self.item.quantity,
        )

    def as_dict(self) -> dict:
        product, line = self.variant.product, self.bill_line
        return {
            "id": self.item.pk,
            "product": {
                "id": product.pk,
                "slug": product.slug,
                "name": product.name,
                "brand": product.brand,
                "is_veg": product.is_veg,
            },
            "variant": self.summary,
            "quantity": self.item.quantity,
            "price_per_unit": money_str(self.unit_price),
            "previous_selling_price": (
                money_str(self.previous_selling_price)
                if self.previous_selling_price is not None
                else None
            ),
            "price_tier": (
                {"min_order_units": self.tier.min_order_units, "price": money_str(self.tier.price)}
                if self.tier is not None
                else None
            ),
            "next_tier_price": (
                money_str(self.next_price) if self.next_price is not None else None
            ),
            "line_mrp_total": money_str(line.line_mrp_total),
            "line_total": money_str(line.line_total),
            "issue": self.issue,
        }


def line_issue(quantity: int, summary: dict) -> dict | None:
    """Why a line cannot be ordered as it is; null when it can. A stock problem comes first; a
    line the store can supply but below the variant's minimum is MIN_QTY_REQUIRED (`orderable`
    is 0 or at least the minimum, so raising the line to the minimum is always possible)."""
    orderable, limit = summary["orderable_quantity"], summary["max_qty_per_order"]
    minimum = summary["min_qty_per_order"]
    if quantity <= orderable:
        if quantity < minimum:
            return {
                "code": CartLineIssueCode.MIN_QTY_REQUIRED,
                "message": (
                    f"At least {minimum} per order. Increase the quantity to {minimum} or remove "
                    "it."
                ),
            }
        return None
    if orderable == 0:
        return {
            "code": CartLineIssueCode.OUT_OF_STOCK,
            "message": "Out of stock. Remove it to continue.",
        }
    if quantity > limit and orderable == limit:
        message = f"At most {limit} per order. Reduce the quantity to {limit}."
    else:
        message = f"Only {orderable} left. Reduce the quantity to {orderable}."
    return {"code": CartLineIssueCode.QUANTITY_UNAVAILABLE, "message": message}


def load_lines(cart: Cart, store_id: int) -> list[CartLine]:
    """The cart's lines priced and checked at `store_id` (a fixed number of queries). An
    unsaved cart (a reader with no cart yet) has none."""
    items = list(cart.items.all()) if cart.pk is not None else []
    variants = store_variants(store_id, [item.variant_id for item in items])
    lines = []
    for item in items:
        variant = variants[item.variant_id]
        summary = variant_summary(variant, variant.product)
        lines.append(
            CartLine(item, variant, summary, line_issue(item.quantity, summary), variant.inv_price)
        )
    apply_price_tiers(lines)
    return lines


def tier_units(lines: Sequence[CartLine]) -> int:
    """Units that choose the volume tier (ADR 0001): every line whose variant has price tiers,
    any mix, each counting min(quantity, orderable_quantity) as for `order_units` (units the
    store cannot supply do not count)."""
    return sum(
        min(line.item.quantity, line.summary["orderable_quantity"])
        for line in lines
        if variant_tiers(line.variant)
    )


def reached_tier(tiers, units: int):
    """The highest tier with `min_order_units` <= `units` (tiers lowest first), else None."""
    reached = None
    for tier in tiers:
        if tier.min_order_units <= units:
            reached = tier
    return reached


def apply_price_tiers(lines: Sequence[CartLine]) -> None:
    """08 §6.2 / ADR 0001: fix each tiered line's unit price before `compute_bill()`. One tier
    for the whole cart, chosen by `tier_units()`; each variant then takes its own price at that
    tier. A tier never raises a price: when the store's price is lower (an override), it stays.
    Lines of variants without tiers keep the store's price."""
    units = tier_units(lines)
    for line in lines:
        tier = reached_tier(variant_tiers(line.variant), units)
        if tier is not None and tier.price <= line.unit_price:
            line.price, line.tier = tier.price, tier
    found = next_tier(lines, units)
    for line in lines:
        line.next_price = found[1].get(line.item.pk) if found is not None else None


def price_at(line: CartLine, units: int) -> Decimal:
    """This line's unit price if the cart had `units` tier units (a tier never raises the
    store's price)."""
    base = line.variant.inv_price  # the normal price (see `CartLine.unit_price`)
    tier = reached_tier(variant_tiers(line.variant), units)
    return tier.price if tier is not None and tier.price <= base else base


def next_tier(lines: Sequence[CartLine], units: int) -> tuple[int, dict[int, Decimal]] | None:
    """The nudge "Add N more to get ₹X": the lowest tier threshold above `units` at which at
    least one line's price drops, with the lower price per line (by cart item id). None at the
    top tier or when no line has tiers. The app never computes these prices."""
    thresholds = sorted(
        {
            tier.min_order_units
            for line in lines
            for tier in variant_tiers(line.variant)
            if tier.min_order_units > units
        }
    )
    for threshold in thresholds:
        lower = {}
        for line in lines:
            price = price_at(line, threshold)
            if price < line.unit_price:
                lower[line.item.pk] = price
        if lower:
            return threshold, lower
    return None


# ------------------------------------------------------------------- free cartons (ADR 0002)

MSG_FREE_NO_STOCK = "Your free carton is out of stock right now, so it is not added."
MSG_FREE_VARIANT_REQUIRED = "Choose a size for your free carton."
MSG_FREE_VARIANT_UNAVAILABLE = (
    "This size is not available for your free carton here. Choose another size."
)


@dataclass(slots=True)
class FreeLine:
    """Free cartons of one size (₹0): the volume offer or a reward."""

    variant: ProductVariant  # from `store_variants()` (store price and stock annotations)
    summary: dict  # `variant_summary()`
    quantity: int
    source: str  # FreeSource

    @property
    def bill_line(self) -> BillLine:
        return BillLine(
            variant_id=self.variant.pk,
            category_id=self.variant.product.category_id,
            mrp=self.variant.mrp,
            selling_price=ZERO,
            quantity=self.quantity,
        )

    def as_dict(self) -> dict:
        product = self.variant.product
        return {
            "product": {
                "id": product.pk,
                "slug": product.slug,
                "name": product.name,
                "brand": product.brand,
                "is_veg": product.is_veg,
            },
            "variant": self.summary,
            "quantity": self.quantity,
            "mrp": money_str(self.variant.mrp),
            "value": money_str(self.bill_line.line_mrp_total),
            "source": self.source,
        }


def counted_units(line: CartLine) -> int:
    """Paid units a line counts for the minimum and the volume offer: min(quantity, orderable),
    so units the store cannot supply do not count."""
    return min(line.item.quantity, line.summary["orderable_quantity"])


def paid_units(lines: Sequence[CartLine]) -> int:
    """Paid units of the cart (free cartons never count, ADR 0002 §2)."""
    return sum(counted_units(line) for line in lines)


def stock_units(variant: ProductVariant) -> int:
    """Units the store can give now for this variant (on hand - reserved), ignoring the
    per-order limits: free cartons are not limited by them. 0 when not sold here."""
    if not variant.inv_is_available:
        return 0
    return max(variant.inv_on_hand - variant.inv_reserved, 0)


def _paid_of(lines: Sequence[CartLine], variant_id: int) -> int:
    return sum(counted_units(line) for line in lines if line.variant.pk == variant_id)


def reward_size_ok(
    variant: ProductVariant | None,
    lines: Sequence[CartLine],
    quantity: int = 1,
    *,
    fixed: bool = False,
) -> bool:
    """A reward's size can be given: sold at the store, with the stock for the cart's paid
    units of that size plus the reward's `quantity` cartons (ADR 0003: `value` cartons). The
    size the customer picked (ADR 0002 §9) must also be of the same product category as at
    least one paid line of the cart (a water reward goes on a water order; PM, 2026-11-25); the
    store's fixed free size (`fixed`, ADR 0003) skips that check."""
    if variant is None or not variant.inv_is_available:
        return False
    if not fixed:
        paid_categories = {
            line.variant.product.category_id for line in lines if counted_units(line) > 0
        }
        if variant.product.category_id not in paid_categories:
            return False
    return _paid_of(lines, variant.pk) + quantity <= stock_units(variant)


def free_variant_body(variant: ProductVariant | None) -> dict | None:
    """ADR 0003: the API `FreeVariant` {id, name, product_name}, or None."""
    if variant is None:
        return None
    return {"id": variant.pk, "name": variant.name, "product_name": variant.product.name}


def fixed_free_variant(
    store_id: int, rules: PricingRules, lines: Sequence[CartLine], *, full: bool = True
) -> ProductVariant | None:
    """ADR 0003: the store's fixed free size with its store price and stock (the cart line's
    variant when the cart has it, else one more read), or None when the store has none. `full`
    also loads the images.

    Pass `full=True` wherever a free line of it may be rendered (`FreeLine.as_dict()` ->
    `variant_summary()`): without the image prefetch the line silently has no image. `full=False`
    is only for stock checks and `free_variant_body()`. A switched-off size (`inv_is_available`
    false) has 0 `stock_units()`, so it never gets a free line."""
    variant_id = rules.free_unit_variant_id
    if variant_id is None:
        return None
    for line in lines:
        if line.variant.pk == variant_id:
            return line.variant
    return store_variants(store_id, [variant_id], with_images=full).get(variant_id)


def fixed_free_variant_body(store_id: int | None) -> dict | None:
    """ADR 0003 (`GET /account/rewards/`): the `FreeVariant` of the store's fixed free size, or
    None when the store has none (one query)."""
    if store_id is None:
        return None
    config = (
        PricingConfig.objects.select_related("free_unit_variant__product")
        .filter(store_id=store_id)
        .first()
    )
    return free_variant_body(config.free_unit_variant if config is not None else None)


def _summary_of(variant: ProductVariant, lines: Sequence[CartLine]) -> dict:
    for line in lines:
        if line.variant.pk == variant.pk:
            return line.summary
    return variant_summary(variant, variant.product)


def volume_offer(
    lines: Sequence[CartLine],
    rules: PricingRules,
    *,
    extra: dict[int, int] | None = None,
    available: dict[int, int] | None = None,
    fixed: ProductVariant | None = None,
) -> tuple[FreeLine | None, dict | None]:
    """ADR 0002 §3: `paid // every` free cartons.

    - ADR 0003: when the store has a fixed free size (`rules.free_unit_variant_id`; `fixed` is
      that variant from `fixed_free_variant()`), they are always that size, whatever the paid
      sizes: no cheapest-size rule and no fallback.
    - Else (ADR 0002) the cheapest size in the cart (lowest unit price among the paid lines; a
      tie goes to the size with more paid units, then the lowest variant id), or the
      next-cheapest that has the stock.

    The size must have the stock for its paid units, any other free carton of it (`extra`, e.g.
    a reward) and these free ones. When it cannot, no free carton and a `notice`. Returns (the
    free line or None, the API `free_offer` or None when the store has no offer). `available`
    (variant id -> units) is the stock read under the placement's row locks; by default, the
    stock the cart read."""
    every = rules.free_unit_every
    if not every:
        return None, None
    extra = extra or {}
    paid = paid_units(lines)
    free = paid // every
    chosen, notice = None, None
    if free:
        if rules.free_unit_variant_id is not None:
            candidates = [fixed] if fixed is not None else []
        else:
            candidates = [
                line.variant
                for line in sorted(
                    (line for line in lines if counted_units(line) > 0),
                    key=lambda line: (line.unit_price, -counted_units(line), line.variant.pk),
                )
            ]
        for variant in candidates:
            need = _paid_of(lines, variant.pk) + extra.get(variant.pk, 0) + free
            stock = available.get(variant.pk, 0) if available is not None else stock_units(variant)
            if need <= stock:
                summary = _summary_of(variant, lines)
                chosen = FreeLine(variant, summary, free, FreeSource.VOLUME_OFFER)
                break
        if chosen is None:
            notice = MSG_FREE_NO_STOCK
    to_next = every - paid % every
    more = " more" if free else ""
    offer = {
        "every": every,
        "paid_units": paid,
        "free_units": free,
        "units_to_next_free": to_next,
        "message": f"Add {to_next} more {rules.order_unit_label} to get 1{more} free",
        "notice": notice,
        "free_variant": (
            free_variant_body(fixed) if rules.free_unit_variant_id is not None else None
        ),
    }
    return chosen, offer


# --------------------------------------------------------------------------- the cart


def read_cart(user, store: StoreArea) -> Cart:
    """For reads (`GET /cart/`, the coupon sheet): the user's cart priced at `store`, without
    writing (code review F5). A user with no cart gets an unsaved empty one; the store binding is
    saved by the next change."""
    cart = Cart.objects.select_related("coupon", "address").filter(user=user).first()
    if cart is None:
        return Cart(user=user, store_id=store.pk, instructions=empty_instructions())
    cart.store_id = store.pk  # priced at the requested store; persisted only by changes
    return cart


def get_cart(user, store: StoreArea) -> Cart:
    """For changes: the user's cart (created empty on first use), bound to `store` (the cart
    follows the store in X-Store-Id). `store` is an active store: `get_store()` answers 404
    `STORE_NOT_FOUND` for an unknown or deactivated one before any cart call."""
    cart, _ = Cart.objects.select_related("coupon", "address").get_or_create(
        user=user, defaults={"store_id": store.pk, "instructions": empty_instructions()}
    )
    if cart.store_id != store.pk:
        cart.store_id = store.pk
        cart.save(update_fields=["store", "updated_at"])
    return cart


def resolve_address(user, address_id: int) -> Address:
    """One of the user's live addresses, or 400 (unknown and other users' ids look the same)."""
    address = live_addresses(user).filter(pk=address_id).first()
    if address is None:
        raise ValidationError({"address_id": [MSG_ADDRESS_NOT_FOUND]})
    return address


def serves(store: StoreArea, address: Address) -> bool:
    """True when this store delivers to the address (no query): its pin is inside the store's
    service area or, for a store in pincode mode (ADR 0004), its pincode is an active delivery
    pincode of the store (`StoreArea.delivers_to`)."""
    return store.delivers_to(address.lat, address.lng, address.pincode)


def not_served_message(store: StoreArea, address: Address, default: str) -> str:
    """The `NOT_SERVICEABLE` message for an address `serves()` refused: for a store in pincode
    mode, the ADR 0004 message naming its active pincodes; else `default`."""
    return store.not_delivered_message() or default


def _cart_address(cart: Cart, user) -> Address | None:
    address = cart.address
    if address is None or address.is_deleted or address.user_id != user.pk:
        return None
    return address


@dataclass(slots=True)
class CartState:
    """Everything the cart body and order placement (R2b) need, computed once."""

    lines: list[CartLine]
    rules: PricingRules
    coupon_check: "promotions.CouponCheck | None"
    bill: Bill
    # ADR 0002: free cartons (volume offer first, then the reward) and the volume offer body
    free_lines: list[FreeLine] = field(default_factory=list)
    free_offer: dict | None = None
    # ADR 0003: the store's fixed free size (None: the ADR 0002 rules) and the size of a
    # free-carton reward on the cart (the fixed size, else the one the customer picked)
    fixed_free_variant: ProductVariant | None = None
    reward_variant_id: int | None = None

    @property
    def bill_lines(self) -> list[BillLine]:
        return [line.bill_line for line in self.lines]

    @property
    def item_total(self) -> Decimal:
        return self.bill.item_total if self.lines else ZERO

    @property
    def order_units(self) -> int:
        """Units for the store's minimum units per order: what would be ordered once the lines'
        stock fixes are made, min(quantity, orderable_quantity) per line (an out-of-stock line
        counts 0). Any mix of items counts together. Free cartons never count (ADR 0002)."""
        return paid_units(self.lines)

    @property
    def units_to_min_order(self) -> int | None:
        """Units still needed for `min_order_units`; None when it is met or the rule is off."""
        missing = self.rules.min_order_units - self.order_units
        return missing if self.rules.min_order_units and missing > 0 else None


def min_units_message(rules: PricingRules, missing: int) -> str:
    label = rules.order_unit_label
    return (
        f"Add {missing} more {label} to place your order (minimum {rules.min_order_units} {label})."
    )


def check_cart_coupon(
    coupon, lines: Sequence[CartLine], rules: PricingRules, *, user, store_id: int, now=None
):
    """`promotions.check_coupon` with the cart's paid units (ADR 0002 rewards)."""
    bill_lines = [line.bill_line for line in lines]
    return promotions.check_coupon(
        coupon,
        user=user,
        store_id=store_id,
        lines=bill_lines,
        item_total=item_total(bill_lines),
        now=now,
        paid_units=paid_units(lines),
        min_units=rules.min_order_units,
        unit_label=rules.order_unit_label,
    )


def reward_variant(
    store_id: int, variant_id: int | None, lines: Sequence[CartLine]
) -> ProductVariant | None:
    """The size picked for a free-carton reward, with its store price and stock: the cart
    line's variant when the cart has it, else one more read."""
    if variant_id is None:
        return None
    for line in lines:
        if line.variant.pk == variant_id:
            return line.variant
    return store_variants(store_id, [variant_id]).get(variant_id)


def free_cartons(
    lines: Sequence[CartLine],
    rules: PricingRules,
    *,
    reward: ProductVariant | None = None,
    reward_units: int = 1,
    fixed: ProductVariant | None = None,
) -> tuple[list[FreeLine], dict | None]:
    """ADR 0002: the cart's free lines (the volume offer, then the reward's `reward_units`
    cartons when `reward` is the size of an applicable reward) and the API `free_offer`.
    `fixed` is the store's fixed free size (ADR 0003), or None."""
    extra = {reward.pk: reward_units} if reward is not None else {}
    volume, offer = volume_offer(lines, rules, extra=extra, fixed=fixed)
    free = [volume] if volume is not None else []
    if reward is not None:
        free.append(FreeLine(reward, _summary_of(reward, lines), reward_units, FreeSource.REWARD))
    return free, offer


def _no_stock_message(rules: PricingRules) -> str:
    """The FREE_VARIANT_UNAVAILABLE message when the reward's size cannot be given: with a
    fixed free size the customer cannot choose another one (ADR 0003)."""
    if rules.free_unit_variant_id is not None:
        return promotions.MSG_FREE_VARIANT_NO_STOCK
    return promotions.MSG_FREE_VARIANT


def reward_size_id(cart: Cart, rules: PricingRules) -> int | None:
    """The size of a free-carton reward on the cart: the store's fixed free size (ADR 0003),
    else the size the customer picked (ADR 0002)."""
    if rules.free_unit_variant_id is not None:
        return rules.free_unit_variant_id
    return cart.free_variant_id


def evaluate(cart: Cart, store: StoreArea, user, *, now: datetime | None = None) -> CartState:
    lines = load_lines(cart, store.pk)
    rules = pricing_rules(store.pk)
    bill_lines = [line.bill_line for line in lines]
    is_reward = promotions.is_free_unit(cart.coupon)
    # A free line of the fixed size is possible only with a reward or a free carton earned:
    # load its images only then (one light read otherwise, for `free_offer.free_variant`).
    earned = bool(rules.free_unit_every) and paid_units(lines) >= rules.free_unit_every
    fixed = fixed_free_variant(store.pk, rules, lines, full=is_reward or earned)
    size_id = reward_size_id(cart, rules) if is_reward else None
    check, reward, units = None, None, 0
    if cart.coupon is not None:
        prefetch_related_objects([cart.coupon], "stores", "categories__children")
        check = check_cart_coupon(cart.coupon, lines, rules, user=user, store_id=store.pk, now=now)
        if check.ok and is_reward:
            units = cart.coupon.free_units
            reward = fixed if fixed is not None else reward_variant(store.pk, size_id, lines)
            if not reward_size_ok(reward, lines, units, fixed=fixed is not None):
                check = promotions.free_variant_check(
                    cart.coupon, size_id, _no_stock_message(rules)
                )
                reward = None
    coupon = cart.coupon if check is not None and check.ok else None
    free_lines, offer = free_cartons(lines, rules, reward=reward, reward_units=units, fixed=fixed)
    bill = compute_bill(
        bill_lines,
        rules,
        coupon=coupon,
        tip=cart.tip,
        free_lines=[line.bill_line for line in free_lines],
    )
    return CartState(lines, rules, check, bill, free_lines, offer, fixed, size_id)


def _thresholds(state: CartState) -> dict:
    rules, item_total = state.rules, state.item_total
    to_min = rules.min_order_value - item_total
    charges_delivery = rules.delivery_fee > 0
    to_free = rules.free_delivery_threshold - item_total
    return {
        "min_order_value": money_str(rules.min_order_value),
        "amount_to_min_order": money_str(to_min) if to_min > 0 else None,
        "free_delivery_threshold": (
            money_str(rules.free_delivery_threshold) if charges_delivery else None
        ),
        "amount_to_free_delivery": money_str(to_free) if charges_delivery and to_free > 0 else None,
        "min_order_units": rules.min_order_units,
        "units_to_min_order": state.units_to_min_order,
        "order_unit_label": rules.order_unit_label,
        **_tier_nudge(state.lines),
    }


def _tier_nudge(lines: Sequence[CartLine]) -> dict:
    units = tier_units(lines)
    found = next_tier(lines, units)
    return {
        "tier_units": units,
        "next_price_tier": (
            {"min_order_units": found[0], "units_to_next_tier": found[0] - units}
            if found is not None
            else None
        ),
    }


def cod_unavailable(rules: PricingRules, user, grand_total: Decimal):
    """(reason, message) when COD cannot be used (08 T2), else None."""
    if not rules.cod_enabled:
        return PaymentUnavailableReason.COD_DISABLED, "This store does not offer cash on delivery."
    if user.cod_blocked:
        return (
            PaymentUnavailableReason.NOT_ALLOWED,
            "Cash on delivery is not available for your account.",
        )
    if grand_total > rules.cod_max_order_value:
        return (
            PaymentUnavailableReason.ABOVE_LIMIT,
            f"Cash on delivery is available on orders up to {rupees(rules.cod_max_order_value)}.",
        )
    return None


def _payment_methods(state: CartState, user) -> list[dict]:
    cod = cod_unavailable(state.rules, user, state.bill.grand_total)
    online = online_payments_enabled()
    return [
        {
            "method": PaymentMethod.ONLINE,
            "is_available": online,
            "unavailable_reason": None if online else PaymentUnavailableReason.ONLINE_DISABLED,
            "message": None if online else MSG_ONLINE_DISABLED,
        },
        {
            "method": PaymentMethod.COD,
            "is_available": cod is None,
            "unavailable_reason": cod[0] if cod else None,
            "message": cod[1] if cod else None,
        },
    ]


def _coupon_body(state: CartState, cart: Cart) -> dict | None:
    check = state.coupon_check
    if check is None:
        return None
    coupon = check.coupon
    return {
        "code": coupon.code,
        "title": coupon.title,
        "discount_type": coupon.discount_type,
        "source": coupon.source,
        "free_variant_id": state.reward_variant_id,
        "free_quantity": coupon.free_units if promotions.is_free_unit(coupon) else None,
        "discount": money_str(state.bill.coupon_discount),
        "is_applicable": check.ok,
        "message": check.message,
        "amount_to_unlock": (
            money_str(check.amount_to_unlock) if check.amount_to_unlock is not None else None
        ),
    }


def _coupon_blocker(check) -> dict:
    if check.reason == CouponIneligibleReason.MIN_ORDER_VALUE:
        message = (
            f"Add items worth {rupees(check.amount_to_unlock)} more to use {check.coupon.code}, "
            "or remove the coupon."
        )
    elif check.reason == CouponIneligibleReason.FREE_VARIANT_UNAVAILABLE:
        # "Choose another size. Or remove ..." (ADR 0002); a fixed size cannot be changed.
        joiner = "Or remove" if check.message == promotions.MSG_FREE_VARIANT else "Remove"
        message = f"{check.message} {joiner} the reward to continue."
    else:
        message = f"{check.message} Remove it to continue."
    return {"code": check.error.value, "message": message}


def blockers(state: CartState, *, status, store: StoreArea, address: Address | None) -> list[dict]:
    """What stops the order now, most important first. An empty cart has only CART_EMPTY."""
    if not state.lines:
        return [
            {
                "code": CheckoutBlockerCode.CART_EMPTY,
                "message": CheckoutBlockerCode.CART_EMPTY.label,
            }
        ]
    found = []
    if not status.is_open:
        found.append({"code": CheckoutBlockerCode.STORE_CLOSED, "message": status_message(status)})
    if any(line.has_stock_issue for line in state.lines):
        found.append({"code": CheckoutBlockerCode.STOCK_UNAVAILABLE, "message": MSG_STOCK_BLOCKER})
    if any(line.below_minimum for line in state.lines):
        found.append({"code": CheckoutBlockerCode.MIN_QTY_REQUIRED, "message": MSG_MIN_QTY_BLOCKER})
    to_min = state.rules.min_order_value - state.item_total
    if to_min > 0:
        found.append(
            {
                "code": CheckoutBlockerCode.MIN_ORDER_NOT_MET,
                "message": (
                    f"Add items worth {rupees(to_min)} more to place your order "
                    f"(minimum {rupees(state.rules.min_order_value)})."
                ),
            }
        )
    if state.units_to_min_order is not None:
        found.append(
            {
                "code": CheckoutBlockerCode.MIN_UNITS_NOT_MET,
                "message": min_units_message(state.rules, state.units_to_min_order),
            }
        )
    check = state.coupon_check
    # A reward below the minimum paid cartons is covered by MIN_UNITS_NOT_MET (ADR 0002): it
    # stays on the cart and applies once the minimum is reached.
    if (
        check is not None
        and not check.ok
        and check.reason != CouponIneligibleReason.MIN_ORDER_UNITS
    ):
        found.append(_coupon_blocker(check))
    if address is None:
        found.append(
            {
                "code": CheckoutBlockerCode.ADDRESS_REQUIRED,
                "message": CheckoutBlockerCode.ADDRESS_REQUIRED.label,
            }
        )
    elif not serves(store, address):
        found.append(
            {
                "code": CheckoutBlockerCode.NOT_SERVICEABLE,
                "message": not_served_message(
                    store,
                    address,
                    f"{store.name} does not deliver to this address. Choose another address.",
                ),
            }
        )
    return found


def cart_body(
    cart: Cart,
    store: StoreArea,
    user,
    *,
    address: Address | None = None,
    now: datetime | None = None,
) -> dict:
    """The API `Cart`. `address` overrides the cart's own (`GET /cart/?address_id=`)."""
    state = evaluate(cart, store, user, now=now)
    status = store_status(store, now)
    address = address or _cart_address(cart, user)
    found = blockers(state, status=status, store=store, address=address)
    instructions = cart.instructions or empty_instructions()
    return {
        "store": status.as_dict(),
        "items": [line.as_dict() for line in state.lines],
        "item_count": sum(line.item.quantity for line in state.lines),
        "coupon": _coupon_body(state, cart),
        "tip": money_str(cart.tip),
        "instructions": {
            "chips": list(instructions.get("chips", [])),
            "note": instructions.get("note", ""),
        },
        "address": AddressSerializer(address).data if address is not None else None,
        "bill": state.bill.as_dict(),
        "free_lines": [line.as_dict() for line in state.free_lines],
        "free_offer": state.free_offer,
        "thresholds": _thresholds(state),
        "payment_methods": _payment_methods(state, user),
        "checkout": {"can_place_order": not found, "blockers": found},
    }


def coupon_list_body(cart: Cart, store: StoreArea, user, *, now: datetime | None = None) -> dict:
    lines = load_lines(cart, store.pk)
    rules = pricing_rules(store.pk)
    bill_lines = [line.bill_line for line in lines]
    offers = promotions.coupon_offers(
        user=user,
        store_id=store.pk,
        lines=bill_lines,
        item_total=item_total(bill_lines),
        applied=cart.coupon,
        now=now,
        paid_units=paid_units(lines),
        min_units=rules.min_order_units,
        unit_label=rules.order_unit_label,
        free_variant_id=cart.free_variant_id,
        fixed_free_variant_id=rules.free_unit_variant_id,
    )
    return {"results": offers}


# --------------------------------------------------------------------------- changes


def _locked(cart: Cart) -> Cart:
    return Cart.objects.select_for_update().get(pk=cart.pk)


def _stock_error(variant_id: int, requested: int, orderable: int) -> ApiError:
    message = f"Only {orderable} left." if orderable else "This item is out of stock."
    return ApiError(
        ErrorCode.STOCK_UNAVAILABLE,
        message,
        details={
            "items": [
                {
                    "variant_id": variant_id,
                    "requested_quantity": requested,
                    "orderable_quantity": orderable,
                }
            ]
        },
    )


def min_qty_error(variant_id: int, minimum: int, item_name: str = "this item") -> ApiError:
    """422 `MIN_QTY_REQUIRED`: a line of 1 to `minimum` - 1 units (the cart and placement)."""
    return ApiError(
        ErrorCode.MIN_QTY_REQUIRED,
        f"You need to order at least {minimum} of {item_name}.",
        details={"variant_id": variant_id, "min_qty_per_order": minimum},
    )


def check_minimum(variant_id: int, quantity: int, minimum: int) -> None:
    """A line quantity from 1 to `minimum` - 1 is refused, up or down (0 removes the line and is
    always allowed): 422 `MIN_QTY_REQUIRED`."""
    if 0 < quantity < minimum:
        raise min_qty_error(variant_id, minimum)


def check_increase(store_id: int, variant_id: int, quantity: int) -> ProductVariant:
    """An increase must be within the variant's per-order limits (422 `MAX_QTY_EXCEEDED`, 422
    `MIN_QTY_REQUIRED`) and the store's stock (409 `STOCK_UNAVAILABLE`; a variant the store does
    not sell has 0, and so does one with fewer free units than its minimum). Returns the variant
    with its store price (`inv_price`)."""
    variant = store_variants(store_id, [variant_id], with_images=False).get(variant_id)
    if variant is None or not variant.inv_is_available:
        raise _stock_error(variant_id, quantity, 0)
    if quantity > variant.max_qty_per_order:
        raise ApiError(
            ErrorCode.MAX_QTY_EXCEEDED,
            f"You can order at most {variant.max_qty_per_order} of this item.",
            details={"variant_id": variant_id, "max_qty_per_order": variant.max_qty_per_order},
        )
    check_minimum(variant_id, quantity, variant.min_qty_per_order)
    stock = availability(
        on_hand=variant.inv_on_hand,
        reserved=variant.inv_reserved,
        is_available=variant.inv_is_available,
        max_qty_per_order=variant.max_qty_per_order,
        min_qty_per_order=variant.min_qty_per_order,
    )
    if quantity > stock.orderable_quantity:
        raise _stock_error(variant_id, quantity, stock.orderable_quantity)
    return variant


def store_price(store_id: int, variant_id: int) -> Decimal:
    """The store's selling price of a variant now (override applied, before volume tiers): the
    `variant.selling_price` the cart line shows."""
    return store_variants(store_id, [variant_id], with_images=False)[variant_id].inv_price


def set_quantity(cart: Cart, store: StoreArea, variant_id: int, quantity: int) -> None:
    """`POST /cart/items/`: set the line for `variant_id` to `quantity` (0 removes it). An
    increase is checked against the limits and stock; a decrease only against the variant's
    minimum per order, so a customer can always step down a line with a stock issue (or remove
    it with 0).

    Every successful set (the same quantity included) records the store's price now as the
    line's `seen_selling_price`: the customer has seen it, so `previous_selling_price` clears
    (API request #56). Re-setting the same quantity is how the app acknowledges a change."""
    with transaction.atomic():
        _locked(cart)
        item = cart.items.select_related("variant").filter(variant_id=variant_id).first()
        current = item.quantity if item is not None else 0
        if quantity == 0:
            if item is not None:
                item.delete()
            return
        if quantity > current:
            price = check_increase(store.pk, variant_id, quantity).inv_price
        else:
            if quantity < current:
                check_minimum(variant_id, quantity, item.variant.min_qty_per_order)
            price = store_price(store.pk, variant_id)
        if item is None:
            CartItem.objects.create(
                cart=cart, variant_id=variant_id, quantity=quantity, seen_selling_price=price
            )
        elif item.quantity != quantity or item.seen_selling_price != price:
            item.quantity, item.seen_selling_price = quantity, price
            item.save(update_fields=["quantity", "seen_selling_price", "updated_at"])


def own_line(cart: Cart, line_id: int) -> CartItem:
    """A line of this cart; any other id (another user's included) is a 404."""
    item = cart.items.filter(pk=line_id).first()
    if item is None:
        raise NotFound(MSG_LINE_NOT_FOUND)
    return item


def update_line(cart: Cart, store: StoreArea, line_id: int, quantity: int) -> None:
    set_quantity(cart, store, own_line(cart, line_id).variant_id, quantity)


def delete_line(cart: Cart, line_id: int) -> None:
    own_line(cart, line_id).delete()


def clear_cart(cart: Cart) -> None:
    """Remove the lines, the coupon and the tip; keep the address and instructions."""
    with transaction.atomic():
        _locked(cart)
        cart.items.all().delete()
        cart.coupon = None
        cart.free_variant = None
        cart.tip = ZERO
        cart.save(update_fields=["coupon", "free_variant", "tip", "updated_at"])


def update_cart(cart: Cart, store: StoreArea, user, data: dict) -> None:
    """`PATCH /cart/`: tip, instructions (replaced whole) and/or the delivery address, which
    must be inside the store's service area (422 `NOT_SERVICEABLE`, nothing saved)."""
    fields = []
    if "address_id" in data:
        address = resolve_address(user, data["address_id"])
        if not serves(store, address):
            raise ApiError(
                ErrorCode.NOT_SERVICEABLE,
                not_served_message(store, address, MSG_ADDRESS_NOT_SERVED),
                details={"address_id": address.pk},
            )
        cart.address = address
        fields.append("address")
    if "tip" in data:
        cart.tip = round_money(data["tip"])
        fields.append("tip")
    if "instructions" in data:
        cart.instructions = {
            "chips": list(data["instructions"].get("chips", [])),
            "note": data["instructions"].get("note", ""),
        }
        fields.append("instructions")
    if fields:
        cart.save(update_fields=[*fields, "updated_at"])


def apply_coupon(
    cart: Cart,
    store: StoreArea,
    user,
    code: str,
    *,
    free_variant_id: int | None = None,
    now=None,
) -> None:
    """`POST /cart/coupon/`: apply `code` (replacing any coupon) if the cart qualifies now;
    otherwise 422 with the reason and nothing changes.

    A free-carton reward (FREE_UNIT, `value` cartons) gets its size checked after the coupon's
    own rules (so another customer's code still looks unknown):
    - ADR 0003, the store has a fixed free size: `free_variant_id` may be left out (the fixed
      size is used); any other id is 422 `COUPON_NOT_ELIGIBLE` (FREE_VARIANT_UNAVAILABLE). The
      category rule does not apply to the fixed size.
    - ADR 0002, no fixed size: `free_variant_id` is the size the customer picked (400 when
      missing). It must be sold at this store and be of the same product category as a paid
      line of the cart (422 FREE_VARIANT_UNAVAILABLE).
    Either way the size needs the stock for the cart's paid units of it plus the reward's
    cartons (422 FREE_VARIANT_UNAVAILABLE). The reward needs the store's minimum paid cartons
    (422 MIN_ORDER_UNITS). It takes the cart's single coupon slot."""
    coupon = promotions.find_coupon(code)
    if coupon is None:
        raise ApiError(
            ErrorCode.COUPON_INVALID,
            promotions.MSG_INVALID,
            details={"code": promotions.normalise_code(code)},
        )
    lines = load_lines(cart, store.pk)
    rules = pricing_rules(store.pk)
    check = check_cart_coupon(coupon, lines, rules, user=user, store_id=store.pk, now=now)
    if not check.ok:
        raise check.as_error()
    size = None
    if promotions.is_free_unit(coupon):
        fixed_id = rules.free_unit_variant_id
        if fixed_id is not None:
            if free_variant_id is not None and free_variant_id != fixed_id:
                raise promotions.free_variant_check(
                    coupon, free_variant_id, promotions.MSG_FREE_VARIANT_NOT_FIXED
                ).as_error()
            size = fixed_id
        elif free_variant_id is None:
            raise ValidationError({"free_variant_id": [MSG_FREE_VARIANT_REQUIRED]})
        else:
            size = free_variant_id
        variant = (
            fixed_free_variant(store.pk, rules, lines, full=False)
            if fixed_id is not None
            else reward_variant(store.pk, size, lines)
        )
        if not reward_size_ok(variant, lines, coupon.free_units, fixed=fixed_id is not None):
            raise promotions.free_variant_check(coupon, size, _no_stock_message(rules)).as_error()
    cart.coupon, cart.free_variant_id = coupon, size
    cart.save(update_fields=["coupon", "free_variant", "updated_at"])


def remove_coupon(cart: Cart) -> None:
    if cart.coupon_id is not None or cart.free_variant_id is not None:
        cart.coupon, cart.free_variant = None, None
        cart.save(update_fields=["coupon", "free_variant", "updated_at"])
