"""Status badges: one label and colour (tone) per state, used by every panel screen.

Order, delivery-task and payment states are the codes of 08 §1, §3 and §4. Their models arrive
in Phases 3 to 5; when they land, their `choices` must cover exactly these codes (a test pins
the Phase 3 ones: `Order.status`, `Order.payment_status`, `Payment.status`, `Refund.status`,
`CouponRedemption.status`). Unknown codes render as a neutral badge with the raw code, never as
an error. Labels are unique within a kind: unfold's `@display(label=...)` maps label -> tone.
"""

from dataclasses import dataclass

SUCCESS = "success"
WARNING = "warning"
DANGER = "danger"
INFO = "info"
PRIMARY = "primary"
NEUTRAL = "neutral"


@dataclass(frozen=True)
class Badge:
    label: str
    tone: str


CUSTOMER = "customer"
ORDER = "order"
TASK = "task"
PAYMENT = "payment"
ORDER_PAYMENT = "order_payment"  # Order.payment_status (07 §2.6)
REFUND = "refund"
REDEMPTION = "redemption"  # CouponRedemption.status (07 §2.5)
COUPON = "coupon"  # derived: coupon_state()
COD = "cod"  # User.cod_blocked
TICKET = "ticket"  # SupportTicket.status (P7)
TICKET_PRIORITY = "ticket_priority"  # SupportTicket.priority (P7)
TICKET_SLA = "ticket_sla"  # support.services.with_sla (P7)

BADGES: dict[str, dict[str, Badge]] = {
    CUSTOMER: {
        "active": Badge("Active", SUCCESS),
        "blocked": Badge("Blocked", DANGER),
        "deletion_requested": Badge("Deletion requested", WARNING),
        "anonymised": Badge("Anonymised", NEUTRAL),
    },
    # 08 §1
    ORDER: {
        "PAYMENT_PENDING": Badge("Payment pending", WARNING),
        "PLACED": Badge("Placed", INFO),
        "ACCEPTED": Badge("Accepted", INFO),
        "PACKING": Badge("Packing", PRIMARY),
        "PACKED": Badge("Packed", PRIMARY),
        "OUT_FOR_DELIVERY": Badge("Out for delivery", PRIMARY),
        "DELIVERED": Badge("Delivered", SUCCESS),
        "CANCELLED": Badge("Cancelled", NEUTRAL),
        "PAYMENT_FAILED": Badge("Payment failed", DANGER),
        "DELIVERY_FAILED": Badge("Delivery failed", DANGER),
        "RETURNED": Badge("Returned", NEUTRAL),
    },
    # 08 §3
    TASK: {
        "SEARCHING": Badge("Searching", WARNING),
        "OFFERED": Badge("Offered", WARNING),
        "ASSIGNED": Badge("Assigned", INFO),
        "AT_STORE": Badge("At store", INFO),
        "PICKED_UP": Badge("Picked up", PRIMARY),
        "AT_CUSTOMER": Badge("At customer", PRIMARY),
        "DELIVERED": Badge("Delivered", SUCCESS),
        "FAILED": Badge("Failed", DANGER),
        "RETURNING": Badge("Returning", WARNING),
        "RETURNED": Badge("Returned", NEUTRAL),
        "UNASSIGNED": Badge("Unassigned", DANGER),
        "CANCELLED": Badge("Cancelled", NEUTRAL),
    },
    # 08 §4
    PAYMENT: {
        "CREATED": Badge("Created", NEUTRAL),
        "AUTHORIZED": Badge("Authorised", INFO),
        "CAPTURED": Badge("Captured", SUCCESS),
        "FAILED": Badge("Failed", DANGER),
    },
    # 07 §2.6 Order.payment_status (staff wording; the apps use their own texts)
    ORDER_PAYMENT: {
        "PENDING": Badge("Awaiting payment", WARNING),
        "PAID": Badge("Paid", SUCCESS),
        "FAILED": Badge("Not paid", DANGER),
        "REFUND_PENDING": Badge("Refund pending", WARNING),
        "REFUNDED": Badge("Refunded", NEUTRAL),
        "PARTIALLY_REFUNDED": Badge("Partly refunded", INFO),
        "COD_PENDING": Badge("COD due", INFO),
        "COD_COLLECTED": Badge("COD collected", SUCCESS),
    },
    # 07 §2.7 Refund.status
    REFUND: {
        "PENDING": Badge("Pending", WARNING),
        "PROCESSED": Badge("Processed", SUCCESS),
        "FAILED": Badge("Failed", DANGER),
    },
    # 07 §2.5 CouponRedemption.status
    REDEMPTION: {
        "HELD": Badge("Held", WARNING),
        "APPLIED": Badge("Applied", SUCCESS),
        "RELEASED": Badge("Released", NEUTRAL),
        "REVERSED": Badge("Reversed", NEUTRAL),
    },
    COUPON: {
        "live": Badge("Live", SUCCESS),
        "scheduled": Badge("Scheduled", INFO),
        "expired": Badge("Expired", NEUTRAL),
        "inactive": Badge("Switched off", NEUTRAL),
    },
    COD: {
        "allowed": Badge("COD allowed", SUCCESS),
        "blocked": Badge("COD blocked", DANGER),
    },
    TICKET: {
        "OPEN": Badge("Open", WARNING),
        "IN_PROGRESS": Badge("In progress", INFO),
        "RESOLVED": Badge("Resolved", SUCCESS),
        "CLOSED": Badge("Closed", NEUTRAL),
    },
    TICKET_SLA: {"breached": Badge("SLA breached", DANGER)},
    TICKET_PRIORITY: {
        "LOW": Badge("Low", NEUTRAL),
        "NORMAL": Badge("Normal", INFO),
        "HIGH": Badge("High", WARNING),
        "URGENT": Badge("Urgent", DANGER),
    },
}


def badge_for(kind: str, code: str | None) -> Badge:
    if not code:
        return Badge("-", NEUTRAL)
    return BADGES.get(kind, {}).get(code) or Badge(str(code), NEUTRAL)


def label_tones(kind: str) -> dict[str, str]:
    """For unfold's `@display(label=...)`: badge label -> tone. The display method returns
    `badge_for(kind, code).label`."""
    return {badge.label: badge.tone for badge in BADGES[kind].values()}


def coupon_state(coupon, now) -> str:
    """Precedence: switched off > expired > scheduled > live. Uses the coupon rules of
    `apps.promotions.services` (is_live / is_expired), so the panel and the app agree."""
    from apps.promotions.services import is_expired, is_live

    if not coupon.is_active:
        return "inactive"
    if is_expired(coupon, now):
        return "expired"
    if not is_live(coupon, now):
        return "scheduled"
    return "live"


def customer_status(user) -> str:
    """Precedence: anonymised > deletion requested > blocked > active."""
    if user.anonymised_at is not None:
        return "anonymised"
    if user.deleted_at is not None:
        return "deletion_requested"
    if not user.is_active:
        return "blocked"
    return "active"
