"""Status badges: one label and colour (tone) per state, used by every panel screen.

Order, delivery-task and payment states are the codes of 08 §1, §3 and §4. Their models arrive
in Phases 3 to 5; when they land, their `choices` must cover exactly these codes (a test then
pins it). Unknown codes render as a neutral badge with the raw code, never as an error.
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
}


def badge_for(kind: str, code: str | None) -> Badge:
    if not code:
        return Badge("-", NEUTRAL)
    return BADGES.get(kind, {}).get(code) or Badge(str(code), NEUTRAL)


def customer_status(user) -> str:
    """Precedence: anonymised > deletion requested > blocked > active."""
    if user.anonymised_at is not None:
        return "anonymised"
    if user.deleted_at is not None:
        return "deletion_requested"
    if not user.is_active:
        return "blocked"
    return "active"
