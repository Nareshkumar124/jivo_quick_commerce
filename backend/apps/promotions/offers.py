"""Offer management for the admin's "Offers" page (ADR 0004 §3, Super Admin only). The page
calls only these; each change is checked against `promotions.manage_offers` and written to the
audit log. Nothing new is stored: they edit the existing models.

- Public coupons (`Coupon` with no owner, source NONE): `create_public_coupon`,
  `update_public_coupon`, `set_public_coupon_active`. They reuse the existing coupon rules:
  `Coupon.full_clean()` (value > 0, PERCENT at most 100, ends after it starts, FREE_UNIT is a
  personal reward only), the panel's cap rules, and `services.save_coupon()` (the edit guards on
  the locked row and a raced code). A disabled or expired coupon is hidden and refused by the
  existing coupon checks.
- Buy-N-get-1 per store (`PricingConfig.free_unit_every` / `free_unit_variant`):
  `set_volume_offer`.
- Rewards (`ReferralSettings.is_enabled`, `welcome_reward_quantity`, `reward_quantity`):
  `set_reward_quantities`.

`free_unit_variant` and the two reward quantities come from ADR 0003.
"""

import re
from datetime import datetime
from decimal import Decimal

from django.core.exceptions import NON_FIELD_ERRORS, PermissionDenied, ValidationError
from django.db import transaction

from apps.core import audit
from apps.promotions.choices import CouponSource, DiscountType
from apps.promotions.models import Coupon
from apps.promotions.services import MSG_CODE_TAKEN, MSG_COUPON_GONE, save_coupon

MANAGE_OFFERS = "promotions.manage_offers"
MSG_NO_PERMISSION = "Only a Super Admin can change offers."
# The coupon panel's own rules (apps/promotions/admin.py), the same words.
MSG_CAP_REQUIRED = "A percent coupon needs a maximum discount (cap) in rupees."
MSG_NO_CAP_ON_FLAT = "A flat coupon has no cap: its value is the discount. Leave this empty."
MSG_CODE_SPACES = "Use letters and numbers without spaces, e.g. JIVO50."
MSG_PERSONAL = "This is a customer's personal reward. It can't be changed here."
MSG_WHOLE_NUMBER = "Enter a whole number, 0 or more, with the digits 0-9."
# Plain ASCII digits only (BUG-0002: never `\d`). `int()` alone would also take "1_000",
# other scripts' digits, "+2" and "-1".
WHOLE_TEXT = re.compile(r"[0-9]+")
ASCII_SPACE = " \t\r\n"  # outer spaces only; a no-break space is refused

# What the page may set on a public coupon. `owner` and `source` are fixed (public, NONE).
COUPON_FIELDS = frozenset(
    {
        "code",
        "title",
        "description",
        "discount_type",
        "value",
        "max_discount",
        "min_order_value",
        "starts_at",
        "ends_at",
        "usage_limit_total",
        "usage_limit_per_user",
        "first_order_only",
        "is_active",
        "is_visible",
    }
)
TEXT_FIELDS = frozenset({"title", "description"})  # free text stays out of the audit log


def can_manage_offers(user) -> bool:
    return bool(user and user.is_active and user.is_staff and user.has_perm(MANAGE_OFFERS))


def _require(actor) -> None:
    if not can_manage_offers(actor):
        raise PermissionDenied(MSG_NO_PERMISSION)


def _plain(value):
    """A JSON-safe audit value."""
    if isinstance(value, Decimal):
        return f"{value:.2f}"
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def _whole(value, field: str) -> int:
    text = "" if value is None or isinstance(value, bool) else str(value).strip(ASCII_SPACE)
    if not WHOLE_TEXT.fullmatch(text):
        raise ValidationError({field: MSG_WHOLE_NUMBER})
    return int(text)


# --------------------------------------------------------------------------- public coupons


def _coupon_fields(data: dict) -> dict:
    unknown = set(data) - COUPON_FIELDS
    if unknown:
        raise ValueError(f"Not a public coupon field: {', '.join(sorted(unknown))}")
    return dict(data)


def _check_coupon(coupon: Coupon) -> None:
    """The coupon rules, all errors at once (a dict of field -> message)."""
    errors: dict[str, list[str]] = {}
    try:
        # Field limits and `Coupon.clean()`; the code's uniqueness is checked below with a
        # clear message (the database constraint would name itself).
        coupon.full_clean(validate_constraints=False)
    except ValidationError as error:
        errors.update(error.message_dict)
    code = coupon.code or ""
    if any(character.isspace() for character in code):
        errors.setdefault("code", []).append(MSG_CODE_SPACES)
    taken = Coupon.objects.filter(code__iexact=code)
    if coupon.pk is not None:
        taken = taken.exclude(pk=coupon.pk)
    if code and taken.exists():
        errors.setdefault("code", []).append(MSG_CODE_TAKEN)
    if coupon.discount_type == DiscountType.PERCENT and coupon.max_discount is None:
        errors.setdefault("max_discount", []).append(MSG_CAP_REQUIRED)
    if coupon.discount_type == DiscountType.FLAT and coupon.max_discount is not None:
        errors.setdefault("max_discount", []).append(MSG_NO_CAP_ON_FLAT)
    if errors:
        raise ValidationError(errors)


def _is_public(coupon: Coupon) -> bool:
    return coupon.owner_id is None and coupon.source == CouponSource.NONE


def create_public_coupon(data: dict, *, actor, stores=(), categories=()) -> Coupon:
    """A new public coupon from the page's fields (`COUPON_FIELDS`). `stores` / `categories`
    limit it (empty = all). Raises `ValidationError` per field and `PermissionDenied`; saves
    nothing then."""
    _require(actor)
    coupon = Coupon(**_coupon_fields(data), owner=None, source=CouponSource.NONE)
    _check_coupon(coupon)
    with transaction.atomic():
        save_coupon(coupon)
        coupon.stores.set(stores)
        coupon.categories.set(categories)
        values = {
            field: _plain(getattr(coupon, field)) for field in sorted(COUPON_FIELDS - TEXT_FIELDS)
        }
        values["store_ids"] = sorted(store.pk for store in coupon.stores.all())
        values["category_ids"] = sorted(category.pk for category in coupon.categories.all())
        audit.record(actor, "coupon.create", coupon, values)
    return coupon


def update_public_coupon(
    coupon: Coupon, data: dict, *, actor, stores=None, categories=None
) -> bool:
    """Edit a public coupon (only the fields in `data`; `stores` / `categories` None = keep),
    e.g. a new end date. Returns whether anything changed. A personal reward is refused."""
    _require(actor)
    data = _coupon_fields(data)
    with transaction.atomic():
        current = Coupon.objects.filter(pk=coupon.pk).first()
        if current is None:
            raise ValidationError({NON_FIELD_ERRORS: [MSG_COUPON_GONE]})
        if not _is_public(current):
            raise ValidationError({NON_FIELD_ERRORS: [MSG_PERSONAL]})
        before = {field: getattr(current, field) for field in data}
        for field, value in data.items():
            setattr(current, field, value)
        _check_coupon(current)  # also normalises the code (capitals)
        changes = {
            field: "changed" if field in TEXT_FIELDS else [_plain(old), _plain(new)]
            for field, old in before.items()
            if (new := getattr(current, field)) != old
        }
        new_stores = None if stores is None else sorted(store.pk for store in stores)
        new_categories = None if categories is None else sorted(c.pk for c in categories)
        old_stores = sorted(current.stores.values_list("pk", flat=True))
        old_categories = sorted(current.categories.values_list("pk", flat=True))
        if new_stores is not None and new_stores != old_stores:
            changes["store_ids"] = [old_stores, new_stores]
        if new_categories is not None and new_categories != old_categories:
            changes["category_ids"] = [old_categories, new_categories]
        if not changes:
            return False
        save_coupon(current)  # the edit guards on the locked row; a raced code is an error
        if "store_ids" in changes:
            current.stores.set(new_stores)
        if "category_ids" in changes:
            current.categories.set(new_categories)
        audit.record(actor, "coupon.update", current, changes)
    return True


def set_public_coupon_active(coupon: Coupon, active: bool, *, actor) -> bool:
    """Enable or disable a public coupon. A disabled coupon is hidden from the app and refused
    at the cart (the existing coupon checks). Returns whether anything changed."""
    _require(actor)
    active = bool(active)
    with transaction.atomic():
        locked = Coupon.objects.select_for_update().filter(pk=coupon.pk).first()
        if locked is None:
            raise ValidationError({NON_FIELD_ERRORS: [MSG_COUPON_GONE]})
        if not _is_public(locked):
            raise ValidationError({NON_FIELD_ERRORS: [MSG_PERSONAL]})
        if locked.is_active == active:
            coupon.is_active = active
            return False
        locked.is_active = active
        locked.save(update_fields=["is_active", "updated_at"])
        audit.record(
            actor, "coupon.enable" if active else "coupon.disable", locked, {"is_active": active}
        )
    coupon.is_active = active
    return True


# --------------------------------------------------------------------------- buy-N-get-1


def set_volume_offer(store, every, variant=None, *, actor) -> bool:
    """Buy-N-get-1 at a store (ADR 0002/0003): 1 free carton for every `every` paid cartons
    (0 = off), the free carton being `variant` (a size this store sells; None = the cheapest
    size in the order). `store` is a DarkStore or its id; its PricingConfig row is created with
    the default rules if missing. Returns whether anything changed. Raises `ValidationError`
    (`free_unit_every`, `free_unit_variant`) and `PermissionDenied`."""
    from apps.stores.models import DarkStore, PricingConfig

    _require(actor)
    every = _whole(every, "free_unit_every")
    store_id = getattr(store, "pk", store)
    variant_id = getattr(variant, "pk", variant)
    with transaction.atomic():
        if not DarkStore.objects.filter(pk=store_id).exists():
            raise ValidationError({"store": "Choose a store."})
        config, _ = PricingConfig.objects.select_for_update().get_or_create(store_id=store_id)
        before = (config.free_unit_every, config.free_unit_variant_id)
        if before == (every, variant_id):
            return False
        config.free_unit_every = every
        config.free_unit_variant_id = variant_id
        config.full_clean()  # field limits; the free size must be sold at this store (ADR 0003)
        config.save(update_fields=["free_unit_every", "free_unit_variant", "updated_at"])
        audit.record(
            actor,
            "offer.volume",
            config,
            {
                "store_id": store_id,
                "free_unit_every": [before[0], every],
                "free_unit_variant_id": [before[1], variant_id],
            },
        )
    return True


# --------------------------------------------------------------------------- rewards


def set_reward_quantities(
    *, actor, welcome_quantity=None, referral_quantity=None, referral_enabled=None
) -> bool:
    """The rewards card: free cartons in the welcome reward and in each referral reward (1 to
    10, ADR 0003; rewards already given keep theirs), and the referral program on/off. None =
    keep. Returns whether anything changed. Raises `ValidationError` per field
    (`welcome_reward_quantity`, `reward_quantity`) and `PermissionDenied`."""
    from apps.referrals.models import SINGLETON_ID, ReferralSettings

    _require(actor)
    wanted = {}
    if welcome_quantity is not None:
        wanted["welcome_reward_quantity"] = _whole(welcome_quantity, "welcome_reward_quantity")
    if referral_quantity is not None:
        wanted["reward_quantity"] = _whole(referral_quantity, "reward_quantity")
    if referral_enabled is not None:
        wanted["is_enabled"] = bool(referral_enabled)
    with transaction.atomic():
        ReferralSettings.load()  # makes sure the single row exists
        config = ReferralSettings.objects.select_for_update().get(pk=SINGLETON_ID)
        changes = {
            field: [getattr(config, field), value]
            for field, value in wanted.items()
            if getattr(config, field) != value
        }
        if not changes:
            return False
        for field, (_old, value) in changes.items():
            setattr(config, field, value)
        config.full_clean()  # 1 to 10 cartons per reward
        config.save(update_fields=[*changes, "updated_at"])
        audit.record(actor, "offer.rewards", config, changes)
    return True
