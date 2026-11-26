"""Store management pages (ADR 0004 §4): bottle prices, offers and delivery locations.

**Super Admin only** (user decision, 2026-11-26), and Django superusers. Each page needs its own
permission, which `accounts.roles.sync_roles()` gives only to the Super Admin group:

- Bottle prices: `catalog.manage_prices`
- Offers: `promotions.manage_offers`
- Delivery locations: `stores.manage_delivery_pincodes`

Every other role gets 403 on every page and button (GET and POST); there is no view-only role.

The panel changes nothing itself. It calls only these backend services (ADR 0004 §1-§3;
signatures read from the backend on 2026-11-26). Each one checks the permission again,
validates, saves and writes an `AuditLog` entry:

    catalog.services.set_variant_price(variant, price, *, actor) -> bool
    promotions.offers.set_volume_offer(store, every, variant=None, *, actor) -> bool
    promotions.offers.set_reward_quantities(*, actor, welcome_quantity=None,
                                            referral_quantity=None, referral_enabled=None) -> bool
    promotions.offers.create_public_coupon(data, *, actor, stores=(), categories=()) -> Coupon
    promotions.offers.update_public_coupon(coupon, data, *, actor, stores=None,
                                           categories=None) -> bool
    promotions.offers.set_public_coupon_active(coupon, active, *, actor) -> bool
    stores.services.add_delivery_pincode(store, pincode, *, area_name="", is_active=True,
                                         actor) -> DeliveryPincode
    stores.services.update_delivery_pincode(row, *, actor, pincode=None, area_name=None) -> bool
    stores.services.set_delivery_pincode_active(row, active, *, actor) -> bool

A service missing from the branch raises `ActionUnavailable` (the view answers 501 "not
available yet"), never a half-done change. Refusals come back as `Refused`: the plain message
for a toast, plus the per-field messages so a form can show them next to its fields.

The offers page also edits the ADR 0003 fields: `PricingConfig.free_unit_variant` (the size
every free carton uses at a store, for buy-N-get-1 and rewards) and
`ReferralSettings.welcome_reward_quantity` / `reward_quantity`.

Money is display only: prices are the stored values, typed prices go to the service as text.
"""

from dataclasses import dataclass
from decimal import Decimal

from django.core.exceptions import (
    NON_FIELD_ERRORS,
    PermissionDenied,
    ValidationError,
)
from django.db.models import Exists, OuterRef, Prefetch, Q, QuerySet

from apps.ops_console import status
from apps.ops_console.money import _group_indian
from apps.ops_console.order_actions import (
    FORBIDDEN,
    INVALID,
    ActionRefused,
    ActionUnavailable,
    _lookup,
)

MANAGE_PRICES = "catalog.manage_prices"
MANAGE_OFFERS = "promotions.manage_offers"
MANAGE_PINCODES = "stores.manage_delivery_pincodes"

SET_PRICE = "set_price"
SET_VOLUME_OFFER = "set_volume_offer"
SET_REWARDS = "set_rewards"
CREATE_COUPON = "create_coupon"
UPDATE_COUPON = "update_coupon"
SET_COUPON_ACTIVE = "set_coupon_active"
ADD_PINCODE = "add_pincode"
UPDATE_PINCODE = "update_pincode"
SET_PINCODE_ACTIVE = "set_pincode_active"

OFFERS = "apps.promotions.offers"
STORES = "apps.stores.services"
SERVICES: dict[str, tuple[str, str]] = {
    SET_PRICE: ("apps.catalog.services", "set_variant_price"),
    SET_VOLUME_OFFER: (OFFERS, "set_volume_offer"),
    SET_REWARDS: (OFFERS, "set_reward_quantities"),
    CREATE_COUPON: (OFFERS, "create_public_coupon"),
    UPDATE_COUPON: (OFFERS, "update_public_coupon"),
    SET_COUPON_ACTIVE: (OFFERS, "set_public_coupon_active"),
    ADD_PINCODE: (STORES, "add_delivery_pincode"),
    UPDATE_PINCODE: (STORES, "update_delivery_pincode"),
    SET_PINCODE_ACTIVE: (STORES, "set_delivery_pincode_active"),
}

MSG_NO_PERMISSION = "Only a Super Admin can change this."
# The location check (before an address exists) needs the pincode's outline (ADR 0004 §1).
MSG_NO_OUTLINE = (
    "No map outline for this pincode: customers there can't find the store from their location "
    "until an outline is imported."
)


def can_manage_prices(user) -> bool:
    """Also used by the Django admin (catalog and inventory) to lock prices (ADR 0004)."""
    return bool(user and user.has_perm(MANAGE_PRICES))


def can_manage_offers(user) -> bool:
    """Also used by the Django admin (coupons, pricing config, referral settings)."""
    return bool(user and user.has_perm(MANAGE_OFFERS))


def can_manage_pincodes(user) -> bool:
    """Also used by the Django admin (a store's service area)."""
    return bool(user and user.has_perm(MANAGE_PINCODES))


class Refused(ActionRefused):
    """A service refusal. `message` is plain words for a toast; `fields` maps a field name (or
    `NON_FIELD_ERRORS`) to its messages, for a form."""

    def __init__(self, message: str, code: str, fields: dict[str, list[str]] | None = None):
        super().__init__(message, code)
        self.fields = fields or {}


def available(action: str) -> bool:
    return callable(_lookup(*SERVICES[action]))


def _service(action: str):
    function = _lookup(*SERVICES[action])
    if not callable(function):
        module, name = SERVICES[action]
        raise ActionUnavailable(f"{module}.{name} does not exist yet.")
    return function


def plain_message(error: ValidationError) -> str:
    """All of a ValidationError's messages in one line, general ones first, no repeats."""
    if hasattr(error, "error_dict"):
        fields = error.message_dict
        ordered = [*fields.get(NON_FIELD_ERRORS, [])]
        for field, messages in fields.items():
            if field != NON_FIELD_ERRORS:
                ordered.extend(messages)
    else:
        ordered = list(error.messages)
    unique = list(dict.fromkeys(str(message) for message in ordered))
    return " ".join(unique)


def _call(action: str, *args, **kwargs):
    function = _service(action)
    try:
        return function(*args, **kwargs)
    except PermissionDenied as error:
        raise Refused(str(error) or MSG_NO_PERMISSION, FORBIDDEN) from error
    except ValidationError as error:
        fields = error.message_dict if hasattr(error, "error_dict") else {}
        raise Refused(plain_message(error), INVALID, fields) from error


# --------------------------------------------------------------------------- service calls


def set_price(variant, price: str, *, actor) -> bool:
    return _call(SET_PRICE, variant, price, actor=actor)


def set_volume_offer(store, every: int, variant_id: int | None, *, actor) -> bool:
    return _call(SET_VOLUME_OFFER, store, every, variant_id, actor=actor)


def set_rewards(*, actor, referral_enabled: bool, welcome=None, referral=None) -> bool:
    return _call(
        SET_REWARDS,
        actor=actor,
        referral_enabled=referral_enabled,
        welcome_quantity=welcome,
        referral_quantity=referral,
    )


def create_coupon(data: dict, *, actor):
    return _call(CREATE_COUPON, data, actor=actor)


def update_coupon(coupon, data: dict, *, actor) -> bool:
    return _call(UPDATE_COUPON, coupon, data, actor=actor)


def set_coupon_active(coupon, active: bool, *, actor) -> bool:
    return _call(SET_COUPON_ACTIVE, coupon, active, actor=actor)


def add_pincode(store, pincode: str, *, area_name: str, is_active: bool, actor):
    return _call(ADD_PINCODE, store, pincode, area_name=area_name, is_active=is_active, actor=actor)


def update_pincode(row, *, pincode: str, area_name: str, actor) -> bool:
    return _call(UPDATE_PINCODE, row, pincode=pincode, area_name=area_name, actor=actor)


def set_pincode_active(row, active: bool, *, actor) -> bool:
    return _call(SET_PINCODE_ACTIVE, row, active, actor=actor)


# --------------------------------------------------------------------------- display helpers


def short_inr(value) -> str:
    """ "₹110" for whole rupees, "₹110.50" otherwise (display only, like `money.inr`)."""
    if value is None or value == "":
        return "-"
    amount = Decimal(value)
    whole, _, fraction = f"{abs(amount):.2f}".partition(".")
    sign = "-" if amount < 0 else ""
    text = f"{sign}₹{_group_indian(whole)}"
    return text if fraction == "00" else f"{text}.{fraction}"


def number(value) -> str:
    """Decimal("10.00") -> "10", Decimal("12.50") -> "12.50"."""
    text = f"{Decimal(value):.2f}"
    return text[:-3] if text.endswith(".00") else text


def variant_label(variant) -> str:
    return f"{variant.product.name} {variant.name}"


# --------------------------------------------------------------------------- bottle prices


def sellable_variants() -> QuerySet:
    """Sizes customers can buy: active, of an active product."""
    from apps.catalog.models import ProductVariant

    return ProductVariant.objects.filter(is_active=True, product__is_active=True)


def price_rows(query: str = "") -> QuerySet:
    """The price table: product, size, price, store overrides and whether volume prices
    (tiers) block a single price. A fixed number of queries per page."""
    from apps.catalog.models import VariantPriceTier
    from apps.inventory.models import StoreInventory

    overrides = (
        StoreInventory.objects.filter(price_override__isnull=False)
        .select_related("store")
        .only("pk", "variant_id", "price_override", "store__code", "store__name")
        .order_by("store__code")
    )
    rows = (
        sellable_variants()
        .select_related("product")
        .annotate(has_tiers=Exists(VariantPriceTier.objects.filter(variant=OuterRef("pk"))))
        .prefetch_related(Prefetch("inventory", queryset=overrides, to_attr="overrides"))
        .order_by("product__name", "sort_order", "id")
    )
    if query:
        rows = rows.filter(
            Q(product__name__icontains=query) | Q(sku__icontains=query) | Q(name__icontains=query)
        )
    return rows


def price_confirm_template(variant) -> str:
    """The confirm dialog text; the page puts the typed price in place of `{price}`."""
    return (
        f"{short_inr(variant.selling_price)} → ₹{{price}} for {variant_label(variant)}. "
        "Customers will see this at once. Orders already placed keep their price."
    )


# --------------------------------------------------------------------------- offers


@dataclass
class VolumeRow:
    store: object
    every: int
    variant_id: int | None
    sizes: list[tuple[int, str]]

    @property
    def on(self) -> bool:
        return self.every > 0

    @property
    def confirm_on(self) -> str:
        return (
            f"Customers at {self.store.code} get 1 free carton for every {{n}} paid cartons "
            "in one order. Carts show the change at once. The free carton size is also used "
            "for reward cartons at this store."
        )

    @property
    def confirm_off(self) -> str:
        return (
            f"Turn off buy-N-get-1 at {self.store.code}? Carts there stop getting free cartons "
            "from this offer at once. The free carton size is still used for reward cartons."
        )

    @property
    def confirm_now(self) -> str:
        """The text for the values on the page (without the page script)."""
        return self.confirm_on.replace("{n}", str(self.every)) if self.on else self.confirm_off


def _pricing(store):
    from apps.stores.models import PricingConfig

    try:
        return store.pricing
    except PricingConfig.DoesNotExist:
        return None


def store_sizes(store_ids) -> dict[int, list[tuple[int, str]]]:
    """Per store: the sizes it sells (a stock row, active), as (variant id, label). One query."""
    from apps.inventory.models import StoreInventory

    rows = (
        StoreInventory.objects.filter(
            store_id__in=list(store_ids), variant__is_active=True, variant__product__is_active=True
        )
        .select_related("variant__product")
        .order_by("variant__product__name", "variant__sort_order", "variant_id")
    )
    sizes: dict[int, list[tuple[int, str]]] = {}
    for row in rows:
        sizes.setdefault(row.store_id, []).append((row.variant_id, variant_label(row.variant)))
    return sizes


def volume_rows(stores) -> list[VolumeRow]:
    """Buy-N-get-1 per store. A store without a PricingConfig row shows the model default (0 =
    off); the service creates the row on the first save."""
    from apps.stores.models import PricingConfig

    default_every = PricingConfig._meta.get_field("free_unit_every").default
    stores = list(stores.select_related("pricing").order_by("code"))
    sizes = store_sizes(store.pk for store in stores)
    rows = []
    for store in stores:
        config = _pricing(store)
        rows.append(
            VolumeRow(
                store=store,
                every=config.free_unit_every if config else default_every,
                variant_id=config.free_unit_variant_id if config else None,
                sizes=sizes.get(store.pk, []),
            )
        )
    return rows


def referral_settings():
    """The one settings row, or an unsaved one with the defaults (a GET writes nothing)."""
    from apps.referrals.models import SINGLETON_ID, ReferralSettings

    return ReferralSettings.objects.filter(pk=SINGLETON_ID).first() or ReferralSettings()


def reward_limits(field: str) -> tuple[int | None, int | None]:
    """The model's own 1-to-N limits for a reward quantity field (shown and checked)."""
    from django.core.validators import MaxValueValidator, MinValueValidator

    from apps.referrals.models import ReferralSettings

    low = high = None
    for validator in ReferralSettings._meta.get_field(field).validators:
        if isinstance(validator, MinValueValidator):
            low = validator.limit_value
        elif isinstance(validator, MaxValueValidator):
            high = validator.limit_value
    return low, high


def public_coupons() -> QuerySet:
    """Coupons anyone can use: no owner, made by staff (personal rewards are never here)."""
    from apps.promotions.choices import CouponSource
    from apps.promotions.models import Coupon

    return Coupon.objects.filter(owner__isnull=True, source=CouponSource.NONE)


def coupon_list() -> QuerySet:
    return public_coupons().order_by("-is_active", "code")


def coupon_state(coupon, now) -> status.Badge:
    if not coupon.is_active:
        return status.Badge("Disabled", status.NEUTRAL)
    if coupon.ends_at and coupon.ends_at <= now:
        return status.Badge("Expired", status.WARNING)
    if coupon.starts_at and coupon.starts_at > now:
        return status.Badge("Starts later", status.INFO)
    return status.Badge("Active", status.SUCCESS)


def coupon_value(coupon) -> str:
    """ "₹50 off" or "10% off, up to ₹100" (the stored values, display only)."""
    from apps.promotions.choices import DiscountType

    if coupon.discount_type == DiscountType.PERCENT:
        text = f"{number(coupon.value)}% off"
        if coupon.max_discount is not None:
            text += f", up to {short_inr(coupon.max_discount)}"
        return text
    return f"{short_inr(coupon.value)} off"


def coupon_toggle_confirm(coupon) -> str:
    if coupon.is_active:
        return (
            f"Turn off {coupon.code}? Customers can no longer see or use it. Orders already "
            "placed keep their discount."
        )
    return (
        f"Turn on {coupon.code}? Customers can see and use it in the app at once, within its "
        "start and end dates."
    )


# --------------------------------------------------------------------------- delivery pincodes


@dataclass
class StorePincodes:
    store: object
    rows: list

    @property
    def pincode_mode(self) -> bool:
        return bool(self.rows)

    @property
    def active_count(self) -> int:
        return sum(1 for row in self.rows if row.is_active)

    @property
    def missing_outlines(self) -> list:
        return [row for row in self.rows if row.is_active and not row.has_outline]


def pincodes_for(user) -> QuerySet:
    """Delivery pincodes of the user's stores, with "has a map outline"."""
    from apps.stores.models import DeliveryPincode, PincodeBoundary
    from apps.stores.services import stores_for

    return (
        DeliveryPincode.objects.filter(store__in=stores_for(user))
        .select_related("store")
        .annotate(has_outline=Exists(PincodeBoundary.objects.filter(pincode=OuterRef("pincode"))))
    )


def pincode_stores(user) -> list[StorePincodes]:
    """Every store of the user (by code) with its pincodes. Two queries."""
    from apps.stores.services import stores_for

    stores = list(stores_for(user).order_by("code"))
    by_store: dict[int, list] = {}
    for row in pincodes_for(user).order_by("pincode"):
        by_store.setdefault(row.store_id, []).append(row)
    groups = [StorePincodes(store=store, rows=by_store.get(store.pk, [])) for store in stores]
    for group in groups:
        active = group.active_count
        for row in group.rows:
            row.confirm_toggle = pincode_toggle_confirm(
                row, last_active=row.is_active and active == 1
            )
    return groups


def place(row) -> str:
    return f"{row.pincode} ({row.area_name})" if row.area_name else row.pincode


def pincode_toggle_confirm(row, *, last_active: bool = False) -> str:
    code = row.store.code
    if not row.is_active:
        return (
            f"Turn on delivery to {place(row)}? Customers with this pincode can order from "
            f"{code} at once."
        )
    text = (
        f"Turn off delivery to {place(row)}? Customers there will see \"We don't deliver here "
        "yet\" and can't place new orders. Orders already placed are still delivered."
    )
    if last_active:
        text += f" This is the last active pincode of {code}: it will take no new orders at all."
    return text
