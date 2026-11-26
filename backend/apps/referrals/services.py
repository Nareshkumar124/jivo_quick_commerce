"""The referral program (06 §2.1 "Referral", 07 §2.5a; user decisions, 2026-11-13).

- Every customer has a code (`code_for`), created on their first `GET /account/referral/`.
- A new customer (no order that reached PLACED yet) can enter a friend's code once
  (`apply_code`); not their own, and never again or after their first order.
- When the referred customer's first order is DELIVERED, the order domain event queues
  `referrals.reward_referral` after commit, which calls `reward_for_order`: both customers get a
  free-carton reward (ADR 0002, 2026-11-25: a personal FREE_UNIT coupon from
  `apps.promotions.rewards.create_reward`, sources REFERRAL_REFERRER / REFERRAL_REFERRED; it
  replaced the ₹ FLAT coupon; ADR 0003: `ReferralSettings.reward_quantity` cartons each, read
  at that moment) and the referral becomes REWARDED. The referral row is locked and
  only a PENDING one is rewarded, so the reward is given exactly once per referred customer,
  whatever the retries or later orders. If the program is off at that moment the referral
  becomes VOID (no reward later).

`apply_code` checks, first failure wins: program off (`REFERRAL_NOT_ELIGIBLE` PROGRAM_OFF), a
code already entered (`REFERRAL_ALREADY_APPLIED`), an order already placed
(`REFERRAL_NOT_ELIGIBLE` HAS_ORDERS), unknown code or blocked/deleted owner
(`REFERRAL_CODE_INVALID`), own code (`REFERRAL_SELF`).
"""

import logging
import re
import secrets
from zoneinfo import ZoneInfo

from django.db import IntegrityError, transaction
from django.db.models import Count, Q
from django.utils import timezone

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import money_str
from apps.promotions import rewards
from apps.promotions import services as promotions
from apps.promotions.choices import CouponSource, DiscountType
from apps.referrals.choices import ReferralIneligibleReason, ReferralStatus
from apps.referrals.models import CODE_MAX_LENGTH, Referral, ReferralCode, ReferralSettings

logger = logging.getLogger(__name__)

# Easy to read and type: capitals and digits without I, O, 0 and 1.
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
LONG_CODE_LENGTH = 8  # used only if 6-character codes keep clashing
CODE_ATTEMPTS = 10
CODE_SHAPE = re.compile(r"^[A-Z0-9]{4,12}$")
IST = ZoneInfo("Asia/Kolkata")

REWARD_EVENT = "referral.reward_earned"

MSG_INVALID = "This referral code is not valid. Check it and try again."
MSG_SELF = "You cannot use your own referral code."
MSG_ALREADY = "You have already used a referral code. It cannot be changed."
MSG_HAS_ORDERS = "Referral codes are only for new customers, before their first order."
MSG_PROGRAM_OFF = "The referral program is paused right now."
NOTE_PROGRAM_OFF = "No reward: the referral program was off when the first order was delivered."


# --------------------------------------------------------------------------- codes


def normalise_code(code: str) -> str:
    """What the customer typed, without spaces, in capitals."""
    return re.sub(r"\s+", "", code or "").upper()


def mask_code(code: str) -> str:
    """'K7M2PQ' -> 'K7**PQ': enough to recognise, not the whole code."""
    if len(code) <= 4:
        return code[:1] + "*" * (len(code) - 1)
    return code[:2] + "*" * (len(code) - 4) + code[-2:]


def new_code(length: int = CODE_LENGTH) -> str:
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(length))


def code_for(user) -> ReferralCode:
    """The customer's referral code, created on first use. Safe under concurrent calls: the
    database keeps one code per user and unique codes; a clash is retried with a new code."""
    existing = ReferralCode.objects.filter(user=user).first()
    if existing is not None:
        return existing
    for attempt in range(CODE_ATTEMPTS):
        length = CODE_LENGTH if attempt < CODE_ATTEMPTS - 2 else LONG_CODE_LENGTH
        try:
            with transaction.atomic():
                return ReferralCode.objects.create(user=user, code=new_code(length))
        except IntegrityError:
            existing = ReferralCode.objects.filter(user=user).first()
            if existing is not None:  # a concurrent request created it
                return existing
    raise RuntimeError("Could not generate a unique referral code.")


def can_refer(user) -> bool:
    """A code works only while its owner's account is usable (not blocked or deleted)."""
    return bool(
        user.is_active
        and getattr(user, "deleted_at", None) is None
        and getattr(user, "anonymised_at", None) is None
    )


# --------------------------------------------------------------------------- the screen


def summary(user) -> dict:
    """`GET /account/referral/` (the `Referral` component)."""
    config = ReferralSettings.load()
    own = code_for(user)
    referral = Referral.objects.filter(referred=user).first()
    counts = Referral.objects.filter(referrer=user).aggregate(
        joined=Count("id"), rewarded=Count("id", filter=Q(status=ReferralStatus.REWARDED))
    )
    can_apply = config.is_enabled and referral is None and not promotions.has_placed_order(user)
    label = rewards.carton_label(config.reward_quantity)  # ADR 0003: the setting, e.g. 2
    return {
        "code": own.code,
        "share_message": f"Use my code {own.code} on the Jivo app and we both get {label}.",
        "is_enabled": config.is_enabled,
        "reward_type": DiscountType.FREE_UNIT,
        "reward_quantity": config.reward_quantity,
        "reward_label": label,
        "welcome_reward_quantity": config.welcome_reward_quantity,
        "reward_amount": money_str(config.reward_amount),  # deprecated (ADR 0002)
        "reward_validity_days": config.reward_validity_days,
        "reward_min_order_value": money_str(0),  # deprecated (ADR 0002): not used
        "can_apply_code": can_apply,
        "referred_by": (
            None
            if referral is None
            else {
                "code_masked": mask_code(referral.code),
                "status": referral.status,
                "applied_at": referral.created_at,
            }
        ),
        "friends_joined": counts["joined"] or 0,
        "friends_rewarded": counts["rewarded"] or 0,
    }


# --------------------------------------------------------------------------- entering a code


def _not_eligible(reason: ReferralIneligibleReason, message: str) -> ApiError:
    return ApiError(ErrorCode.REFERRAL_NOT_ELIGIBLE, message, details={"reason": str(reason)})


def apply_code(user, code: str) -> Referral:
    """`POST /account/referral/apply/`: `user` joins with `code` (rules in the module doc)."""
    config = ReferralSettings.load()
    if not config.is_enabled:
        raise _not_eligible(ReferralIneligibleReason.PROGRAM_OFF, MSG_PROGRAM_OFF)
    if Referral.objects.filter(referred=user).exists():
        raise ApiError(ErrorCode.REFERRAL_ALREADY_APPLIED, MSG_ALREADY)
    if promotions.has_placed_order(user):
        raise _not_eligible(ReferralIneligibleReason.HAS_ORDERS, MSG_HAS_ORDERS)
    normalised = normalise_code(code)
    target = None
    if CODE_SHAPE.match(normalised):
        target = ReferralCode.objects.select_related("user").filter(code=normalised).first()
    if target is None or not can_refer(target.user):
        raise ApiError(
            ErrorCode.REFERRAL_CODE_INVALID,
            MSG_INVALID,
            details={"code": normalised[:CODE_MAX_LENGTH]},
        )
    if target.user_id == user.pk:
        raise ApiError(ErrorCode.REFERRAL_SELF, MSG_SELF)
    try:
        with transaction.atomic():
            return Referral.objects.create(
                referrer_id=target.user_id, referred=user, code=target.code
            )
    except IntegrityError as error:  # a concurrent apply by the same customer won
        raise ApiError(ErrorCode.REFERRAL_ALREADY_APPLIED, MSG_ALREADY) from error


# --------------------------------------------------------------------------- the reward


def _expires_on(coupon) -> str:
    local = timezone.localtime(coupon.ends_at, IST)
    return f"{local.day} {local:%b %Y}"


def _notify(referral: Referral) -> None:
    """Inbox + push `referral.reward_earned` to both customers (idempotent per referral and
    customer). Best effort: a failure is logged and never undoes the reward."""
    from apps import notifications

    for user, coupon, reason in (
        (referral.referrer, referral.referrer_coupon, "Your friend's first order was delivered."),
        (referral.referred, referral.referred_coupon, "Thanks for joining with a friend's code."),
    ):
        try:
            with transaction.atomic():  # a failure rolls back only this notification
                notifications.notify(
                    user,
                    REWARD_EVENT,
                    {
                        "reward": rewards.carton_label(coupon.free_units),
                        "reason": reason,
                        "expires_on": _expires_on(coupon),
                        "ref": referral.pk,
                    },
                    dedupe_key=f"{REWARD_EVENT}:{user.pk}:{referral.pk}",
                    sms=False,
                )
        except Exception:
            logger.exception("Referral %s: reward notification to %s failed", referral.pk, user.pk)


def reward_for_order(order_id: int, *, now=None) -> str:
    """Run by `referrals.reward_referral` after an order is DELIVERED (domain event). Rewards the
    order's customer's PENDING referral once (see the module doc). Returns what happened:
    `not_delivered`, `no_referral`, `already_rewarded`, `already_void`, `void` or `rewarded`."""
    from apps.orders.choices import OrderStatus
    from apps.orders.models import Order

    order = Order.objects.filter(pk=order_id).values("user_id", "status").first()
    if order is None or order["status"] != OrderStatus.DELIVERED:
        return "not_delivered"
    with transaction.atomic():
        referral = (
            Referral.objects.select_for_update(of=("self",))
            .select_related("referrer", "referred")
            .filter(referred_id=order["user_id"])
            .first()
        )
        if referral is None:
            return "no_referral"
        if referral.status != ReferralStatus.PENDING:
            return f"already_{referral.status.lower()}"
        config = ReferralSettings.load()
        now = now or timezone.now()
        referral.reward_order_id = order_id
        if not config.is_enabled:
            referral.status = ReferralStatus.VOID
            referral.note = NOTE_PROGRAM_OFF
            referral.save(update_fields=["status", "reward_order", "note", "updated_at"])
            logger.info("Referral %s void (program off), order %s", referral.pk, order_id)
            return "void"
        # ADR 0002: free cartons each (no ₹ amount any more); ADR 0003: `reward_quantity`
        # cartons each, from the settings read now.
        referral.referrer_coupon = rewards.create_reward(
            referral.referrer, source=CouponSource.REFERRAL_REFERRER, now=now, config=config
        )
        referral.referred_coupon = rewards.create_reward(
            referral.referred, source=CouponSource.REFERRAL_REFERRED, now=now, config=config
        )
        referral.status = ReferralStatus.REWARDED
        referral.reward_amount = None
        referral.rewarded_at = now
        referral.save()
        _notify(referral)
    logger.info("Referral %s rewarded, order %s", referral.pk, order_id)
    return "rewarded"


SWEEP_BATCH = 200  # referrals per run; the rest wait for the next hour


def reward_pending_referrals(*, limit: int = SWEEP_BATCH, now=None) -> dict[str, int]:
    """Safety sweep (beat, hourly; `referrals.reward_pending_referrals`): a PENDING referral
    whose customer already has a DELIVERED order (its `order.delivered` event was lost) gets the
    normal path, `reward_for_order()`, for the earliest delivered order. That function locks the
    referral and rewards only a PENDING one, so a referral is never rewarded twice, even when
    the event path runs at the same time. At most `limit` per run, oldest referral first; one
    failing referral is logged and does not stop the others. Returns the outcome counts."""
    from django.db.models import F, OuterRef, Subquery

    from apps.orders.choices import OrderStatus
    from apps.orders.models import Order

    first_delivered = (
        Order.objects.filter(user_id=OuterRef("referred_id"), status=OrderStatus.DELIVERED)
        .order_by(F("delivered_at").asc(nulls_last=True), "pk")
        .values("pk")[:1]
    )
    rows = list(
        Referral.objects.filter(status=ReferralStatus.PENDING)
        .annotate(delivered_order_id=Subquery(first_delivered))
        .filter(delivered_order_id__isnull=False)
        .order_by("created_at", "pk")
        .values_list("pk", "delivered_order_id")[:limit]
    )
    counts: dict[str, int] = {}
    for referral_id, order_id in rows:
        try:
            outcome = reward_for_order(order_id, now=now)
        except Exception:
            logger.exception("Referral sweep: referral %s, order %s failed", referral_id, order_id)
            outcome = "error"
        counts[outcome] = counts.get(outcome, 0) + 1
    if rows:
        logger.info(
            "Referral sweep: %s pending referral(s) with a delivered order: %s", len(rows), counts
        )
    return counts
