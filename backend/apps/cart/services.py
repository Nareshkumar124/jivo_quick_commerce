"""The server cart and the pricing engine (06 §2.5, 08 §6.2).

`compute_bill()` is the only function that computes money: the cart, order placement and the
partial-unavailability recalculation (Phase 4) all call it. Amounts are `Decimal`, rounded
half-up to the paisa; the API sends 2-decimal strings.

The cart follows the store in `X-Store-Id`: lines keep their quantities and take that store's
prices and stock on every read. It never reserves stock (08 §6.1). A line above what the store
can supply is flagged (`issue`) and blocks checkout; the server never changes the cart silently.

Every cart and coupon operation goes through this module. Callers pass the store as resolved from
`X-Store-Id` (`apps.stores.services.StoreArea`: id, name, hours and service area, no query).
"""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from django.contrib.gis.geos import Point
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
from apps.catalog.services import effective_price_expression, variant_summary
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import ZERO, money_str, round_money, rupees
from apps.inventory.services import availability
from apps.orders.choices import PaymentMethod
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
    )

    def as_dict(self) -> dict:
        """The API `Bill`: every amount a 2-decimal string."""
        return {name: money_str(getattr(self, name)) for name in self.FIELDS}


EMPTY_BILL = Bill()


def compute_bill(
    lines: Sequence[BillLine],
    rules: PricingRules,
    *,
    coupon=None,
    tip: Decimal = ZERO,
) -> Bill:
    """08 §6.2. `coupon` is a coupon already found applicable (promotions.check_coupon), or
    None. Fee thresholds compare against `item_total`, before the coupon (D-09). An empty cart's
    bill is all zeros (no fees, no tip)."""
    if not lines:
        return EMPTY_BILL
    mrp_total = round_money(sum((line.line_mrp_total for line in lines), ZERO))
    item_total = round_money(sum((line.line_total for line in lines), ZERO))
    coupon_discount = ZERO
    if coupon is not None:
        coupon_discount = min(promotions.coupon_discount(coupon, lines), item_total)
    delivery_fee = ZERO if item_total >= rules.free_delivery_threshold else rules.delivery_fee
    small_cart_fee = rules.small_cart_fee if item_total < rules.small_cart_threshold else ZERO
    handling_fee = rules.handling_fee
    tip = round_money(tip)
    product_discount = mrp_total - item_total
    grand_total = item_total - coupon_discount + delivery_fee + small_cart_fee + handling_fee + tip
    return Bill(
        mrp_total=mrp_total,
        item_total=item_total,
        product_discount=product_discount,
        coupon_discount=round_money(coupon_discount),
        delivery_fee=round_money(delivery_fee),
        small_cart_fee=round_money(small_cart_fee),
        handling_fee=round_money(handling_fee),
        tip=tip,
        grand_total=round_money(grand_total),
        total_savings=round_money(product_discount + coupon_discount),
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
    if with_images:
        ordered_images = ProductImage.objects.order_by("sort_order", "id")
        queryset = queryset.prefetch_related(
            Prefetch("images", queryset=ordered_images, to_attr="own_images"),
            Prefetch(
                "product__images",
                queryset=ordered_images.filter(variant__isnull=True),
                to_attr="shared_images",
            ),
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

    @property
    def bill_line(self) -> BillLine:
        return BillLine(
            variant_id=self.variant.pk,
            category_id=self.variant.product.category_id,
            mrp=self.variant.mrp,
            selling_price=self.variant.inv_price,
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
            "line_mrp_total": money_str(line.line_mrp_total),
            "line_total": money_str(line.line_total),
            "issue": self.issue,
        }


def line_issue(quantity: int, summary: dict) -> dict | None:
    """Why a line cannot be ordered as it is; null when it can."""
    orderable, limit = summary["orderable_quantity"], summary["max_qty_per_order"]
    if quantity <= orderable:
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
    """The cart's lines priced and checked at `store_id` (a fixed number of queries)."""
    items = list(cart.items.all())
    variants = store_variants(store_id, [item.variant_id for item in items])
    lines = []
    for item in items:
        variant = variants[item.variant_id]
        summary = variant_summary(variant, variant.product)
        lines.append(CartLine(item, variant, summary, line_issue(item.quantity, summary)))
    return lines


# --------------------------------------------------------------------------- the cart


def get_cart(user, store: StoreArea) -> Cart:
    """The user's cart (created empty on first use), bound to `store` (08: the cart follows
    the store in X-Store-Id)."""
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
    """True when the address pin is inside this store's service area (no query)."""
    return store.area.contains(Point(float(address.lng), float(address.lat), srid=4326))


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

    @property
    def bill_lines(self) -> list[BillLine]:
        return [line.bill_line for line in self.lines]

    @property
    def item_total(self) -> Decimal:
        return self.bill.item_total if self.lines else ZERO


def evaluate(cart: Cart, store: StoreArea, user, *, now: datetime | None = None) -> CartState:
    lines = load_lines(cart, store.pk)
    rules = pricing_rules(store.pk)
    bill_lines = [line.bill_line for line in lines]
    item_total = round_money(sum((line.line_total for line in bill_lines), ZERO))
    check = None
    if cart.coupon is not None:
        prefetch_related_objects([cart.coupon], "stores", "categories__children")
        check = promotions.check_coupon(
            cart.coupon,
            user=user,
            store_id=store.pk,
            lines=bill_lines,
            item_total=item_total,
            now=now,
        )
    coupon = cart.coupon if check is not None and check.ok else None
    bill = compute_bill(bill_lines, rules, coupon=coupon, tip=cart.tip)
    return CartState(lines, rules, check, bill)


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
    return [
        {
            "method": PaymentMethod.ONLINE,
            "is_available": True,
            "unavailable_reason": None,
            "message": None,
        },
        {
            "method": PaymentMethod.COD,
            "is_available": cod is None,
            "unavailable_reason": cod[0] if cod else None,
            "message": cod[1] if cod else None,
        },
    ]


def _coupon_body(state: CartState) -> dict | None:
    check = state.coupon_check
    if check is None:
        return None
    return {
        "code": check.coupon.code,
        "title": check.coupon.title,
        "discount": money_str(state.bill.coupon_discount),
        "is_applicable": check.ok,
        "message": check.message,
    }


def _coupon_blocker(check) -> dict:
    if check.reason == CouponIneligibleReason.MIN_ORDER_VALUE:
        message = (
            f"Add items worth {rupees(check.amount_to_unlock)} more to use {check.coupon.code}, "
            "or remove the coupon."
        )
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
    if any(line.issue for line in state.lines):
        found.append({"code": CheckoutBlockerCode.STOCK_UNAVAILABLE, "message": MSG_STOCK_BLOCKER})
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
    if state.coupon_check is not None and not state.coupon_check.ok:
        found.append(_coupon_blocker(state.coupon_check))
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
                "message": (
                    f"{store.name} does not deliver to this address. Choose another address."
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
        "coupon": _coupon_body(state),
        "tip": money_str(cart.tip),
        "instructions": {
            "chips": list(instructions.get("chips", [])),
            "note": instructions.get("note", ""),
        },
        "address": AddressSerializer(address).data if address is not None else None,
        "bill": state.bill.as_dict(),
        "thresholds": _thresholds(state),
        "payment_methods": _payment_methods(state, user),
        "checkout": {"can_place_order": not found, "blockers": found},
    }


def coupon_list_body(cart: Cart, store: StoreArea, user, *, now: datetime | None = None) -> dict:
    lines = load_lines(cart, store.pk)
    bill_lines = [line.bill_line for line in lines]
    item_total = round_money(sum((line.line_total for line in bill_lines), ZERO))
    offers = promotions.coupon_offers(
        user=user,
        store_id=store.pk,
        lines=bill_lines,
        item_total=item_total,
        applied=cart.coupon,
        now=now,
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


def check_increase(store_id: int, variant_id: int, quantity: int) -> None:
    """An increase must be within the variant's per-order limit (422 `MAX_QTY_EXCEEDED`) and
    the store's stock (409 `STOCK_UNAVAILABLE`; a variant the store does not sell has 0)."""
    variant = store_variants(store_id, [variant_id], with_images=False).get(variant_id)
    if variant is None or not variant.inv_is_available:
        raise _stock_error(variant_id, quantity, 0)
    if quantity > variant.max_qty_per_order:
        raise ApiError(
            ErrorCode.MAX_QTY_EXCEEDED,
            f"You can order at most {variant.max_qty_per_order} of this item.",
            details={"variant_id": variant_id, "max_qty_per_order": variant.max_qty_per_order},
        )
    stock = availability(
        on_hand=variant.inv_on_hand,
        reserved=variant.inv_reserved,
        is_available=variant.inv_is_available,
        max_qty_per_order=variant.max_qty_per_order,
    )
    if quantity > stock.orderable_quantity:
        raise _stock_error(variant_id, quantity, stock.orderable_quantity)


def set_quantity(cart: Cart, store: StoreArea, variant_id: int, quantity: int) -> None:
    """`POST /cart/items/`: set the line for `variant_id` to `quantity` (0 removes it). Only an
    increase is checked, so a customer can always step down a line with an issue."""
    with transaction.atomic():
        _locked(cart)
        item = cart.items.filter(variant_id=variant_id).first()
        current = item.quantity if item is not None else 0
        if quantity == 0:
            if item is not None:
                item.delete()
            return
        if quantity > current:
            check_increase(store.pk, variant_id, quantity)
        if item is None:
            CartItem.objects.create(cart=cart, variant_id=variant_id, quantity=quantity)
        elif item.quantity != quantity:
            item.quantity = quantity
            item.save(update_fields=["quantity", "updated_at"])


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
        cart.tip = ZERO
        cart.save(update_fields=["coupon", "tip", "updated_at"])


def update_cart(cart: Cart, store: StoreArea, user, data: dict) -> None:
    """`PATCH /cart/`: tip, instructions (replaced whole) and/or the delivery address, which
    must be inside the store's service area (422 `NOT_SERVICEABLE`, nothing saved)."""
    fields = []
    if "address_id" in data:
        address = resolve_address(user, data["address_id"])
        if not serves(store, address):
            raise ApiError(
                ErrorCode.NOT_SERVICEABLE,
                MSG_ADDRESS_NOT_SERVED,
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


def apply_coupon(cart: Cart, store: StoreArea, user, code: str, *, now=None) -> None:
    """`POST /cart/coupon/`: apply `code` (replacing any coupon) if the cart qualifies now;
    otherwise 422 with the reason and nothing changes."""
    coupon = promotions.find_coupon(code)
    if coupon is None:
        raise ApiError(
            ErrorCode.COUPON_INVALID,
            promotions.MSG_INVALID,
            details={"code": promotions.normalise_code(code)},
        )
    bill_lines = [line.bill_line for line in load_lines(cart, store.pk)]
    item_total = round_money(sum((line.line_total for line in bill_lines), ZERO))
    check = promotions.check_coupon(
        coupon, user=user, store_id=store.pk, lines=bill_lines, item_total=item_total, now=now
    )
    if not check.ok:
        raise check.as_error()
    cart.coupon = coupon
    cart.save(update_fields=["coupon", "updated_at"])


def remove_coupon(cart: Cart) -> None:
    if cart.coupon_id is not None:
        cart.coupon = None
        cart.save(update_fields=["coupon", "updated_at"])
