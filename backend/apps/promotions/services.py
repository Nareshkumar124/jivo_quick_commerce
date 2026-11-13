"""Coupon rules (07 §2.5, 08 §6.2) and the use of coupons by orders (08 T1-T5).

Checks, in this order (the first failure is the answer):
0. a personal coupon (`owner` set) of another customer -> `COUPON_INVALID`, exactly as an
   unknown code (added 2026-11-13; re-checked on the locked row when an order uses it);
1. inactive or not started -> `COUPON_INVALID`; 2. expired -> `COUPON_EXPIRED`;
3. not offered at this store -> `COUPON_NOT_ELIGIBLE` (STORE);
4. used up overall or by this customer -> `COUPON_USAGE_EXCEEDED` (scope total / per_user);
5. first-order coupon and the customer has an earlier order that reached PLACED ->
   `COUPON_NOT_ELIGIBLE` (FIRST_ORDER_ONLY);
6. item total (before the coupon, D-09) below `min_order_value` -> `COUPON_NOT_ELIGIBLE`
   (MIN_ORDER_VALUE, with the amount still needed);
7. a category coupon with no qualifying item -> `COUPON_NOT_ELIGIBLE` (NO_ELIGIBLE_ITEMS).

Discount (PM decision, Phase 3): FLAT = the value; PERCENT = value % of the eligible subtotal,
rounded half-up to the paisa; capped by `max_discount` and by the eligible subtotal (all items,
or only the coupon's categories), so never above the item total.

Usage limits count HELD and APPLIED redemptions. `hold_coupon()` / `apply_coupon_now()` lock the
coupon row, so two orders racing for a coupon's last use cannot both get it.

Panel edits (T-406c) go through `save_coupon()`: the code is fixed once the coupon is used, the
total limit never goes below the uses already counted (both checked on the locked row), and a
code taken by a concurrent save is a `ValidationError`, not a 500.
"""

import secrets
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Protocol

from django.core.exceptions import NON_FIELD_ERRORS, ValidationError
from django.db import IntegrityError, connection, transaction
from django.db.models import Count, Q, QuerySet
from django.utils import timezone

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import rupees
from apps.promotions.choices import CouponIneligibleReason, DiscountType
from apps.promotions.models import COUNTED_STATUSES, Coupon, CouponRedemption, RedemptionStatus

CENT = Decimal("0.01")
ZERO = Decimal("0.00")

MSG_INVALID = "This coupon code is not valid."
MSG_EXPIRED = "This coupon has expired."
MSG_STORE = "This coupon is not valid at this store."
MSG_USED_BY_YOU = "You have already used this coupon."
MSG_USED_UP = "This coupon has been fully redeemed."
MSG_FIRST_ORDER = "This coupon is only for your first order."
MSG_NO_ITEMS = "No items in your cart qualify for this coupon."


class CouponLine(Protocol):
    """What the coupon rules need from a cart or order line."""

    category_id: int
    line_total: Decimal


def normalise_code(code: str) -> str:
    return (code or "").strip().upper()


def find_coupon(code: str) -> Coupon | None:
    """The coupon with this code (case-insensitive; codes are stored in capitals)."""
    code = normalise_code(code)
    if not code:
        return None
    return Coupon.objects.prefetch_related("categories__children").filter(code=code).first()


# --------------------------------------------------------------------------- discount


def coupon_category_ids(coupon: Coupon) -> set[int]:
    """The coupon's categories plus their sub-categories (empty = the whole cart). Uses the
    `categories__children` prefetch when present."""
    ids: set[int] = set()
    for category in coupon.categories.all():
        ids.add(category.pk)
        ids.update(child.pk for child in category.children.all())
    return ids


def eligible_subtotal(coupon: Coupon, lines: Sequence[CouponLine]) -> Decimal:
    categories = coupon_category_ids(coupon)
    return sum(
        (line.line_total for line in lines if not categories or line.category_id in categories),
        ZERO,
    )


def coupon_discount(coupon: Coupon, lines: Sequence[CouponLine]) -> Decimal:
    """The discount `coupon` gives these lines (eligibility is checked separately)."""
    eligible = eligible_subtotal(coupon, lines)
    value = Decimal(coupon.value)
    if coupon.discount_type == DiscountType.PERCENT:
        amount = (eligible * value / 100).quantize(CENT, rounding=ROUND_HALF_UP)
    else:
        amount = value
    if coupon.max_discount is not None:
        amount = min(amount, Decimal(coupon.max_discount))
    return max(min(amount, eligible), ZERO).quantize(CENT, rounding=ROUND_HALF_UP)


# --------------------------------------------------------------------------- usage


@dataclass(frozen=True, slots=True)
class Usage:
    total: int = 0
    by_user: int = 0


def usage_for(coupons: Iterable[Coupon], user) -> dict[int, Usage]:
    """HELD + APPLIED redemptions per coupon, overall and by `user` (one query)."""
    ids = [coupon.pk for coupon in coupons]
    if not ids:
        return {}
    rows = (
        CouponRedemption.objects.filter(coupon_id__in=ids, status__in=COUNTED_STATUSES)
        .values("coupon_id")
        .annotate(total=Count("id"), by_user=Count("id", filter=Q(user=user)))
    )
    return {row["coupon_id"]: Usage(row["total"], row["by_user"]) for row in rows}


def has_placed_order(user) -> bool:
    """True when `user` has an order that ever reached PLACED (first-order coupons, PM
    decision: a failed or abandoned online payment does not count)."""
    from apps.orders.models import Order

    return Order.objects.filter(user=user, placed_at__isnull=False).exists()


# --------------------------------------------------------------------------- checks


@dataclass(frozen=True, slots=True)
class CouponCheck:
    """Whether a coupon applies to a cart right now, and what it gives."""

    coupon: Coupon
    error: ErrorCode | None = None
    message: str | None = None
    reason: CouponIneligibleReason | None = None
    scope: str | None = None
    amount_to_unlock: Decimal | None = None
    discount: Decimal = ZERO

    @property
    def ok(self) -> bool:
        return self.error is None

    def details(self) -> dict:
        details: dict = {"code": self.coupon.code}
        if self.reason is not None:
            details["reason"] = str(self.reason)
        if self.reason == CouponIneligibleReason.MIN_ORDER_VALUE:
            details["min_order_value"] = _money(self.coupon.min_order_value)
            details["amount_to_unlock"] = _money(self.amount_to_unlock)
        if self.scope is not None:
            details["scope"] = self.scope
        return details

    def as_error(self) -> ApiError:
        return ApiError(self.error, self.message, details=self.details())


def _money(value: Decimal) -> str:
    return str(Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP))


def is_for(coupon: Coupon, user) -> bool:
    """A public coupon is for everyone; a personal one only for its owner."""
    return coupon.owner_id is None or coupon.owner_id == getattr(user, "pk", None)


def is_live(coupon: Coupon, now: datetime) -> bool:
    return coupon.is_active and (coupon.starts_at is None or coupon.starts_at <= now)


def is_expired(coupon: Coupon, now: datetime) -> bool:
    return coupon.ends_at is not None and coupon.ends_at <= now


def offered_at(coupon: Coupon, store_id: int) -> bool:
    store_ids = [store.pk for store in coupon.stores.all()]
    return not store_ids or store_id in store_ids


def check_coupon(
    coupon: Coupon,
    *,
    user,
    store_id: int,
    lines: Sequence[CouponLine],
    item_total: Decimal,
    now: datetime | None = None,
    usage: Usage | None = None,
    placed_before: bool | None = None,
) -> CouponCheck:
    """Apply the rules (module docstring) to the cart's lines. `usage`/`placed_before` may be
    passed in when checking many coupons at once."""
    now = now or timezone.now()
    if not is_for(coupon, user) or not is_live(coupon, now):
        return CouponCheck(coupon, ErrorCode.COUPON_INVALID, MSG_INVALID)
    if is_expired(coupon, now):
        return CouponCheck(coupon, ErrorCode.COUPON_EXPIRED, MSG_EXPIRED)
    if not offered_at(coupon, store_id):
        return CouponCheck(
            coupon, ErrorCode.COUPON_NOT_ELIGIBLE, MSG_STORE, CouponIneligibleReason.STORE
        )
    if usage is None:
        usage = usage_for([coupon], user).get(coupon.pk, Usage())
    if coupon.usage_limit_total is not None and usage.total >= coupon.usage_limit_total:
        return CouponCheck(coupon, ErrorCode.COUPON_USAGE_EXCEEDED, MSG_USED_UP, scope="total")
    if coupon.usage_limit_per_user is not None and usage.by_user >= coupon.usage_limit_per_user:
        return CouponCheck(
            coupon, ErrorCode.COUPON_USAGE_EXCEEDED, MSG_USED_BY_YOU, scope="per_user"
        )
    if coupon.first_order_only:
        if placed_before is None:
            placed_before = has_placed_order(user)
        if placed_before:
            return CouponCheck(
                coupon,
                ErrorCode.COUPON_NOT_ELIGIBLE,
                MSG_FIRST_ORDER,
                CouponIneligibleReason.FIRST_ORDER_ONLY,
            )
    if item_total < coupon.min_order_value:
        missing = coupon.min_order_value - item_total
        return CouponCheck(
            coupon,
            ErrorCode.COUPON_NOT_ELIGIBLE,
            f"Add items worth {rupees(missing)} more to use this coupon.",
            CouponIneligibleReason.MIN_ORDER_VALUE,
            amount_to_unlock=missing,
        )
    if eligible_subtotal(coupon, lines) <= 0:
        return CouponCheck(
            coupon,
            ErrorCode.COUPON_NOT_ELIGIBLE,
            MSG_NO_ITEMS,
            CouponIneligibleReason.NO_ELIGIBLE_ITEMS,
        )
    return CouponCheck(coupon, discount=coupon_discount(coupon, lines))


def listed_coupons(store_id: int, now: datetime, user=None) -> QuerySet[Coupon]:
    """Visible coupons valid at `store_id` now (usage limits are checked per customer): the
    public ones plus `user`'s own personal coupons (never another customer's)."""
    owner = Q(owner__isnull=True)
    if getattr(user, "pk", None) is not None:
        owner |= Q(owner=user)
    return (
        Coupon.objects.filter(is_active=True, is_visible=True)
        .filter(owner)
        .filter(Q(starts_at__isnull=True) | Q(starts_at__lte=now))
        .filter(Q(ends_at__isnull=True) | Q(ends_at__gt=now))
        .filter(Q(stores__isnull=True) | Q(stores=store_id))
        .distinct()
        .prefetch_related("stores", "categories__children")
        .order_by("code")
    )


def coupon_offers(
    *,
    user,
    store_id: int,
    lines: Sequence[CouponLine],
    item_total: Decimal,
    applied: Coupon | None,
    now: datetime | None = None,
) -> list[dict]:
    """The 'Apply coupon' sheet (`CouponOffer` dicts): eligible first by savings, then the
    rest by code. Coupons this customer (or everyone) has used up are left out."""
    now = now or timezone.now()
    coupons = list(listed_coupons(store_id, now, user))
    usages = usage_for(coupons, user)
    placed_before = has_placed_order(user) if any(c.first_order_only for c in coupons) else False
    offers = []
    for coupon in coupons:
        check = check_coupon(
            coupon,
            user=user,
            store_id=store_id,
            lines=lines,
            item_total=item_total,
            now=now,
            usage=usages.get(coupon.pk, Usage()),
            placed_before=placed_before,
        )
        if check.error == ErrorCode.COUPON_USAGE_EXCEEDED:
            continue
        offers.append(offer_body(check, applied=applied is not None and applied.pk == coupon.pk))
    eligible = sorted(
        (offer for offer in offers if offer["is_eligible"]),
        key=lambda offer: (-Decimal(offer["savings"]), offer["code"]),
    )
    return eligible + [offer for offer in offers if not offer["is_eligible"]]


def offer_body(check: CouponCheck, *, applied: bool) -> dict:
    coupon = check.coupon
    message = None
    if not check.ok:
        message = (
            f"Add items worth {rupees(check.amount_to_unlock)} more to unlock."
            if check.reason == CouponIneligibleReason.MIN_ORDER_VALUE
            else check.message
        )
    return {
        "code": coupon.code,
        "title": coupon.title,
        "description": coupon.description,
        "discount_type": coupon.discount_type,
        "value": _money(coupon.value),
        "max_discount": _money(coupon.max_discount) if coupon.max_discount is not None else None,
        "min_order_value": _money(coupon.min_order_value),
        "ends_at": coupon.ends_at,
        "is_applied": applied,
        "is_eligible": check.ok,
        "savings": _money(check.discount) if check.ok else None,
        "ineligible_reason": str(check.reason) if check.reason is not None else None,
        "message": message,
        "amount_to_unlock": (
            _money(check.amount_to_unlock) if check.amount_to_unlock is not None else None
        ),
        "is_personal": coupon.owner_id is not None,
    }


# --------------------------------------------------------------------------- use by orders


def _use(order, coupon: Coupon, discount: Decimal, status: RedemptionStatus) -> CouponRedemption:
    """Count `coupon` against its limits for `order`, re-checked on the **locked** coupon row
    (code review F2). Must run inside the order-placement transaction, so the row lock is held
    until the order commits: two orders racing for a coupon's last use serialise here and the
    second sees the first's redemption. Lock order: see `apps.orders.services` (cart, coupon,
    then stock rows by variant id)."""
    if not connection.in_atomic_block:
        raise RuntimeError("Coupon use must run inside the order-placement transaction.")
    locked = Coupon.objects.select_for_update().get(pk=coupon.pk)
    now = timezone.now()
    if not is_for(locked, order.user) or not is_live(locked, now):
        raise CouponCheck(locked, ErrorCode.COUPON_INVALID, MSG_INVALID).as_error()
    if is_expired(locked, now):
        raise CouponCheck(locked, ErrorCode.COUPON_EXPIRED, MSG_EXPIRED).as_error()
    usage = usage_for([locked], order.user).get(locked.pk, Usage())
    if locked.usage_limit_total is not None and usage.total >= locked.usage_limit_total:
        raise CouponCheck(
            locked, ErrorCode.COUPON_USAGE_EXCEEDED, MSG_USED_UP, scope="total"
        ).as_error()
    if locked.usage_limit_per_user is not None and usage.by_user >= locked.usage_limit_per_user:
        raise CouponCheck(
            locked, ErrorCode.COUPON_USAGE_EXCEEDED, MSG_USED_BY_YOU, scope="per_user"
        ).as_error()
    return CouponRedemption.objects.create(
        coupon=locked, user=order.user, order=order, discount_amount=discount, status=status
    )


def hold_coupon(order, coupon: Coupon, discount: Decimal) -> CouponRedemption:
    """08 T1: an online order awaiting payment holds the coupon (it counts against limits).
    Inside the placement transaction only (see `_use`)."""
    return _use(order, coupon, discount, RedemptionStatus.HELD)


def apply_coupon_now(order, coupon: Coupon, discount: Decimal) -> CouponRedemption:
    """08 T2: a COD order uses the coupon at once. Inside the placement transaction only."""
    return _use(order, coupon, discount, RedemptionStatus.APPLIED)


def _move(order, from_status: RedemptionStatus, to_status: RedemptionStatus) -> bool:
    """Idempotent: True when the order's redemption moved, False when there was none to move."""
    return bool(
        CouponRedemption.objects.filter(order=order, status=from_status).update(
            status=to_status, updated_at=timezone.now()
        )
    )


def confirm_coupon(order) -> bool:
    """08 T3: payment captured, the held coupon is used."""
    return _move(order, RedemptionStatus.HELD, RedemptionStatus.APPLIED)


def release_coupon(order) -> bool:
    """08 T4/T5: no sale, the hold ends and the coupon can be used again."""
    return _move(order, RedemptionStatus.HELD, RedemptionStatus.RELEASED)


def reverse_coupon(order) -> bool:
    """08 T11/T12 (Phase 4): a cancelled order gives the coupon back."""
    return _move(order, RedemptionStatus.APPLIED, RedemptionStatus.REVERSED)


# --------------------------------------------------------------------------- personal coupons

# Generated codes: easy to read aloud (no I, O, 0 or 1).
PERSONAL_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
PERSONAL_CODE_LENGTH = 8
PERSONAL_CODE_ATTEMPTS = 5


def personal_code(prefix: str) -> str:
    random_part = "".join(
        secrets.choice(PERSONAL_CODE_ALPHABET) for _ in range(PERSONAL_CODE_LENGTH)
    )
    return f"{prefix}{random_part}"


def create_personal_coupon(
    owner,
    *,
    amount: Decimal,
    valid_days: int,
    min_order_value: Decimal,
    title: str,
    description: str = "",
    prefix: str = "REF",
    now: datetime | None = None,
) -> Coupon:
    """A FLAT `amount` coupon only `owner` can see and use, once, until `now + valid_days`
    (added 2026-11-13 for referral rewards). Its code is generated (`prefix` + 8 characters); a
    clash with an existing code (any case) is retried with a new code. Runs in the caller's
    transaction (a savepoint per attempt)."""
    now = now or timezone.now()
    for _attempt in range(PERSONAL_CODE_ATTEMPTS):
        coupon = Coupon(
            code=personal_code(prefix),
            title=title[:80],
            description=description[:200],
            discount_type=DiscountType.FLAT,
            value=amount,
            min_order_value=min_order_value,
            starts_at=None,
            ends_at=now + timedelta(days=valid_days),
            usage_limit_total=1,
            usage_limit_per_user=1,
            first_order_only=False,
            is_active=True,
            is_visible=True,
            owner=owner,
        )
        try:
            with transaction.atomic():
                coupon.save()
        except IntegrityError as error:
            if is_code_conflict(error):
                continue
            raise
        return coupon
    raise RuntimeError("Could not generate a unique personal coupon code.")


# --------------------------------------------------------------------------- panel edits (T-406c)

MSG_CODE_TAKEN = "A coupon with this code already exists (codes ignore upper and lower case)."
MSG_CODE_LOCKED = (
    "The code cannot change once the coupon has been used: customers and orders refer to it. "
    "Create a new coupon instead."
)
MSG_LIMIT_BELOW_USES = (
    "This coupon has already been used {uses} time(s) (orders awaiting payment included); the "
    "total limit cannot be lower. Switch the coupon off to stop further use."
)
MSG_COUPON_GONE = "This coupon was deleted meanwhile: nothing was saved. Reload the list."
# The database's case-insensitive uniqueness rule for codes (`Coupon.Meta.constraints`).
CODE_UNIQUE_CONSTRAINT = "coupon_code_unique_ci"


def counted_uses(coupon: Coupon) -> int:
    """Uses that count against the coupon's limits (HELD + APPLIED), as `_use` counts them."""
    if coupon.pk is None:
        return 0
    return CouponRedemption.objects.filter(coupon_id=coupon.pk, status__in=COUNTED_STATUSES).count()


def is_used(coupon: Coupon | None) -> bool:
    """Any redemption (any status) or order refers to the coupon: its code is then fixed."""
    if coupon is None or coupon.pk is None:
        return False
    return coupon.redemptions.exists() or coupon.orders.exists()


def coupon_edit_errors(coupon: Coupon, stored: Coupon | None = None) -> dict[str, str]:
    """T-406c (T-304 review Minors 3-4): why `coupon` (edited, not yet saved) may not replace
    its stored row, as {field: message}; empty when the edit is allowed. A new coupon has none.
    - `code`: cannot change once the coupon is used (customers and orders refer to it);
    - `usage_limit_total`: cannot go below the uses already counted (HELD + APPLIED).
    `stored` is the current row (the caller's locked copy); read from the database if omitted.
    Code uniqueness is the database's rule (`save_coupon` turns its refusal into an error)."""
    if coupon.pk is None:
        return {}
    if stored is None:
        stored = Coupon.objects.filter(pk=coupon.pk).first()
        if stored is None:
            return {}
    errors: dict[str, str] = {}
    if normalise_code(coupon.code) != stored.code and is_used(stored):
        errors["code"] = MSG_CODE_LOCKED
    if coupon.usage_limit_total is not None:
        uses = counted_uses(stored)
        if coupon.usage_limit_total < uses:
            errors["usage_limit_total"] = MSG_LIMIT_BELOW_USES.format(uses=uses)
    return errors


def is_code_conflict(error: IntegrityError) -> bool:
    """The database refused a coupon save because another coupon has the code (any case)."""
    diag = getattr(error.__cause__, "diag", None)
    name = getattr(diag, "constraint_name", None) or ""
    return name == CODE_UNIQUE_CONSTRAINT or CODE_UNIQUE_CONSTRAINT in str(error)


def save_coupon(coupon: Coupon) -> Coupon:
    """The one door for creating or editing a coupon from the panel (T-406c). Raises
    `django.core.exceptions.ValidationError` with a message per field (`code`,
    `usage_limit_total`) and saves nothing when the change is refused:
    - the edit guards of `coupon_edit_errors`, checked on the **locked** coupon row: the lock
      `hold_coupon` / `apply_coupon_now` take before counting a use, so no use can slip in
      between this check and the save (the form's own check can be raced);
    - two staff saving the same code at once: the database refuses the second
      (`coupon_code_unique_ci`) and that becomes an error on `code`, never a 500;
    - a coupon deleted meanwhile (its pk has no row any more) is refused with a form-level
      error (`NON_FIELD_ERRORS`, `MSG_COUPON_GONE`), never inserted again (code review).
    Every refusal is a dict error, so a form takes it whole: `form.add_error(None, error)`.
    Runs in its own transaction (a savepoint inside the caller's, e.g. the admin's request), so
    the caller's transaction stays usable after a refusal. Saves only the row: many-to-many
    fields (`stores`, `categories`) are the caller's to save after it (the admin's
    `save_related`). History is recorded by the model (django-simple-history)."""
    with transaction.atomic():
        if coupon.pk is not None:
            stored = Coupon.objects.select_for_update().filter(pk=coupon.pk).first()
            if stored is None:
                gone = ValidationError(MSG_COUPON_GONE, code="not_found")
                raise ValidationError({NON_FIELD_ERRORS: [gone]})
            errors = coupon_edit_errors(coupon, stored)
            if errors:
                raise ValidationError(errors)
        try:
            with transaction.atomic():
                coupon.save()
        except IntegrityError as error:
            if is_code_conflict(error):
                taken = ValidationError(MSG_CODE_TAKEN, code="code_taken")
                raise ValidationError({"code": [taken]}) from error
            raise
    return coupon
