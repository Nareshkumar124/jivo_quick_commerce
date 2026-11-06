from django.db import models


class TicketCategory(models.TextChoices):
    """What the customer needs help with (03 §2.11; codes from api-requests #36)."""

    MISSING_ITEMS = "MISSING_ITEMS", "Missing items"
    DAMAGED_ITEMS = "DAMAGED_ITEMS", "Damaged items"
    WRONG_ITEMS = "WRONG_ITEMS", "Wrong items"
    LATE_DELIVERY = "LATE_DELIVERY", "Late delivery"
    PAYMENT_REFUND = "PAYMENT_REFUND", "Payment or refund"
    ACCOUNT = "ACCOUNT", "Account"
    OTHER = "OTHER", "Other"


# These are about one order: a ticket in one of them must name the customer's order.
ORDER_REQUIRED_CATEGORIES = frozenset(
    {
        TicketCategory.MISSING_ITEMS,
        TicketCategory.DAMAGED_ITEMS,
        TicketCategory.WRONG_ITEMS,
        TicketCategory.LATE_DELIVERY,
    }
)


class TicketStatus(models.TextChoices):
    OPEN = "OPEN", "Open"
    IN_PROGRESS = "IN_PROGRESS", "In progress"
    RESOLVED = "RESOLVED", "Resolved"
    CLOSED = "CLOSED", "Closed"


class TicketPriority(models.TextChoices):
    LOW = "LOW", "Low"
    NORMAL = "NORMAL", "Normal"
    HIGH = "HIGH", "High"
    URGENT = "URGENT", "Urgent"
