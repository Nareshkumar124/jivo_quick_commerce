"""Support tickets (06 §2.7, 07 §2.9, 05 §2 Support): every ticket change goes through here.

**Customer side** (the API): `own_tickets`, `get_own_ticket`, `create_ticket`,
`add_customer_message`. Tickets are always looked up inside the caller's own tickets: another
user's ticket is "not found", never fetched first and checked after.

**Staff side** (the admin / Ops Console, 05 §3 "Support tickets": Super Admin, Ops, Support):
`staff_tickets`, `staff_reply`, `change_status`, `assign`, `set_priority`. Each checks
`support.handle_ticket` and raises `django.core.exceptions.PermissionDenied` without it;
`ValidationError` for bad input (ticket not found, bad assignee); `ApiError`
`INVALID_STATE_TRANSITION` for a status change the table below does not allow. Status changes,
assignment and priority write the audit log (ids and codes only).

**Status rules** (PM default, 2026-11-04):

| From | Customer reply | Staff reply | Staff may set |
|------|----------------|-------------|---------------|
| OPEN | stays OPEN | -> IN_PROGRESS | IN_PROGRESS, RESOLVED, CLOSED |
| IN_PROGRESS | stays | stays | OPEN, RESOLVED, CLOSED |
| RESOLVED | -> OPEN (reopened) | stays | OPEN, IN_PROGRESS, CLOSED |
| CLOSED | refused (400) | refused | nothing (terminal) |

**PII (09):** message bodies are personal data. Logs and audit entries carry ids, codes and
lengths only, never a body, a phone number or a name.
"""

import logging

from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.db.models import OuterRef, Subquery
from django.db.models.functions import Left
from django.utils import timezone

from apps.accounts.choices import AppName
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.support.choices import (
    ORDER_REQUIRED_CATEGORIES,
    TicketCategory,
    TicketPriority,
    TicketStatus,
)
from apps.support.models import MESSAGE_MAX_LENGTH, SupportTicket, TicketMessage

logger = logging.getLogger(__name__)

HANDLE_TICKET = "support.handle_ticket"
CUSTOMER_MESSAGE_MIN_LENGTH = 10  # the first message of a new ticket (api-requests #36)
CUSTOMER_MESSAGE_MAX_LENGTH = 1000
PREVIEW_LENGTH = 140

MSG_TICKET_NOT_FOUND = "Ticket not found."
MSG_TICKET_CLOSED = "This ticket is closed. Open a new ticket if you still need help."
MSG_ORDER_REQUIRED = "Choose the order this is about."
MSG_ORDER_NOT_FOUND = "Order not found."
MSG_NO_PERMISSION = "You do not have permission to do this."

STAFF_TRANSITIONS: dict[str, frozenset[str]] = {
    TicketStatus.OPEN: frozenset(
        {TicketStatus.IN_PROGRESS, TicketStatus.RESOLVED, TicketStatus.CLOSED}
    ),
    TicketStatus.IN_PROGRESS: frozenset(
        {TicketStatus.OPEN, TicketStatus.RESOLVED, TicketStatus.CLOSED}
    ),
    TicketStatus.RESOLVED: frozenset(
        {TicketStatus.OPEN, TicketStatus.IN_PROGRESS, TicketStatus.CLOSED}
    ),
    TicketStatus.CLOSED: frozenset(),
}


# --------------------------------------------------------------------------- helpers


def with_list_relations(queryset):
    """What the ticket list needs in one query: the order number and a preview of the newest
    message."""
    newest = TicketMessage.objects.filter(ticket=OuterRef("pk")).order_by("-created_at", "-id")
    return queryset.select_related("order").annotate(
        last_message_preview=Subquery(newest.values(preview=Left("body", PREVIEW_LENGTH))[:1])
    )


def with_detail_relations(queryset):
    return with_list_relations(queryset).prefetch_related("messages")


def _set_status(ticket: SupportTicket, status: str, now) -> None:
    ticket.status = status
    if status == TicketStatus.RESOLVED:
        ticket.resolved_at = now
    elif status == TicketStatus.CLOSED:
        ticket.closed_at = now
    elif status in (TicketStatus.OPEN, TicketStatus.IN_PROGRESS):
        ticket.resolved_at = None


def _subject(category: str, order) -> str:
    label = TicketCategory(category).label
    return f"{label} - order {order.order_number}" if order is not None else str(label)


def _emit(event: str, ticket: SupportTicket, **extra) -> None:
    """Domain event (logged; push and the support inbox alerts arrive with Phase 6/7 notifications).
    Ids and codes only."""
    fields = {"ticket_id": ticket.pk, "status": ticket.status, **extra}
    transaction.on_commit(lambda: logger.info("support event %s %s", event, fields))


# --------------------------------------------------------------------------- customer side


def own_tickets(user):
    return SupportTicket.objects.filter(user=user)


def get_own_ticket(user, ticket_id: int) -> SupportTicket:
    ticket = with_detail_relations(own_tickets(user)).filter(pk=ticket_id).first()
    if ticket is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TICKET_NOT_FOUND)
    return ticket


def create_ticket(
    user, *, category: str, message: str, order_id: int | None = None, app: str | None = None
) -> SupportTicket:
    """A new OPEN ticket with the customer's first message. `order_id` must be one of the
    customer's own orders (another user's order is "not found"); the order categories need
    one. The serializer has already checked the message length."""
    from apps.orders.services import own_orders

    order = None
    if order_id is not None:
        order = own_orders(user).filter(pk=order_id).first()
        if order is None:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"order_id": [MSG_ORDER_NOT_FOUND]})
    if category in ORDER_REQUIRED_CATEGORIES and order is None:
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"order_id": [MSG_ORDER_REQUIRED]})

    now = timezone.now()
    with transaction.atomic():
        ticket = SupportTicket.objects.create(
            user=user,
            app=app if app in AppName.values else AppName.CUSTOMER,
            order=order,
            category=category,
            subject=_subject(category, order),
            last_activity_at=now,
        )
        TicketMessage.objects.create(ticket=ticket, sender=user, is_staff=False, body=message)
        _emit(
            "support.ticket_created",
            ticket,
            category=category,
            has_order=order is not None,
            length=len(message),
        )
    return ticket


def add_customer_message(user, ticket_id: int, body: str) -> SupportTicket:
    """The customer's reply. CLOSED refuses it (400 VALIDATION_ERROR); RESOLVED reopens the
    ticket (OPEN)."""
    with transaction.atomic():
        ticket = own_tickets(user).select_for_update().filter(pk=ticket_id).first()
        if ticket is None:
            raise ApiError(ErrorCode.NOT_FOUND, MSG_TICKET_NOT_FOUND)
        if ticket.status == TicketStatus.CLOSED:
            raise ApiError(
                ErrorCode.VALIDATION_ERROR,
                MSG_TICKET_CLOSED,
                details={"ticket": [MSG_TICKET_CLOSED]},
            )
        now = timezone.now()
        reopened = ticket.status == TicketStatus.RESOLVED
        if reopened:
            _set_status(ticket, TicketStatus.OPEN, now)
        ticket.last_activity_at = now
        ticket.save(update_fields=["status", "resolved_at", "last_activity_at", "updated_at"])
        TicketMessage.objects.create(ticket=ticket, sender=user, is_staff=False, body=body)
        _emit("support.customer_replied", ticket, reopened=reopened, length=len(body))
    return ticket


# --------------------------------------------------------------------------- staff side


def can_handle_tickets(user) -> bool:
    return bool(
        user is not None
        and user.is_authenticated
        and user.is_active
        and user.is_staff
        and user.has_perm(HANDLE_TICKET)
    )


def _require_handler(user) -> None:
    if not can_handle_tickets(user):
        raise PermissionDenied(MSG_NO_PERMISSION)


def staff_tickets(user):
    """Every ticket, for a user who may handle tickets (support is not store scoped, 05 §3);
    none for anyone else."""
    if not can_handle_tickets(user):
        return SupportTicket.objects.none()
    return SupportTicket.objects.all()


def _locked_ticket(user, ticket_id: int) -> SupportTicket:
    ticket = staff_tickets(user).select_for_update().filter(pk=ticket_id).first()
    if ticket is None:
        raise ValidationError(MSG_TICKET_NOT_FOUND)
    return ticket


def _check_transition(ticket: SupportTicket, status: str) -> None:
    if status not in TicketStatus.values:
        raise ValidationError(f"Unknown status {status!r}.")
    if status not in STAFF_TRANSITIONS[ticket.status]:
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION,
            f"A {TicketStatus(ticket.status).label.lower()} ticket cannot be set to "
            f"{TicketStatus(status).label.lower()}.",
            details={"status": ticket.status, "to": status},
        )


def staff_reply(user, ticket_id: int, body: str, *, status: str | None = None) -> TicketMessage:
    """A reply from support, optionally changing the status in the same step (e.g. reply and
    resolve). Without `status`, an OPEN ticket moves to IN_PROGRESS."""
    _require_handler(user)
    body = (body or "").strip()
    if not body:
        raise ValidationError("Write a reply.")
    if len(body) > MESSAGE_MAX_LENGTH:
        raise ValidationError(f"A reply can be at most {MESSAGE_MAX_LENGTH} characters.")
    with transaction.atomic():
        ticket = _locked_ticket(user, ticket_id)
        if ticket.status == TicketStatus.CLOSED:
            raise ApiError(ErrorCode.INVALID_STATE_TRANSITION, MSG_TICKET_CLOSED)
        before = ticket.status
        if status is None and ticket.status == TicketStatus.OPEN:
            status = TicketStatus.IN_PROGRESS
        if status is not None and status != ticket.status:
            _check_transition(ticket, status)
        now = timezone.now()
        if status is not None and status != ticket.status:
            _set_status(ticket, status, now)
        ticket.last_activity_at = now
        ticket.save()
        message = TicketMessage.objects.create(ticket=ticket, sender=user, is_staff=True, body=body)
        audit.record(
            user,
            "support.reply",
            ticket,
            {"message_id": message.pk, "length": len(body), "from": before, "to": ticket.status},
        )
        _emit("support.staff_replied", ticket, length=len(body))
    return message


def change_status(user, ticket_id: int, status: str) -> SupportTicket:
    _require_handler(user)
    with transaction.atomic():
        ticket = _locked_ticket(user, ticket_id)
        before = ticket.status
        _check_transition(ticket, status)
        now = timezone.now()
        _set_status(ticket, status, now)
        ticket.last_activity_at = now
        ticket.save()
        audit.record(user, "support.status", ticket, {"from": before, "to": status})
        _emit("support.status_changed", ticket, previous=before)
    return ticket


def assign(user, ticket_id: int, assignee) -> SupportTicket:
    """Assign to a staff member who may handle tickets, or unassign with `assignee=None`."""
    _require_handler(user)
    if assignee is not None and not can_handle_tickets(assignee):
        raise ValidationError("Tickets can only be assigned to staff who handle support.")
    with transaction.atomic():
        ticket = _locked_ticket(user, ticket_id)
        if ticket.status == TicketStatus.CLOSED:
            raise ApiError(ErrorCode.INVALID_STATE_TRANSITION, MSG_TICKET_CLOSED)
        before = ticket.assigned_to_id
        ticket.assigned_to = assignee
        ticket.save(update_fields=["assigned_to", "updated_at"])
        audit.record(
            user,
            "support.assign",
            ticket,
            {"from": before, "to": assignee.pk if assignee is not None else None},
        )
    return ticket


def set_priority(user, ticket_id: int, priority: str) -> SupportTicket:
    _require_handler(user)
    if priority not in TicketPriority.values:
        raise ValidationError(f"Unknown priority {priority!r}.")
    with transaction.atomic():
        ticket = _locked_ticket(user, ticket_id)
        before = ticket.priority
        ticket.priority = priority
        ticket.save(update_fields=["priority", "updated_at"])
        audit.record(user, "support.priority", ticket, {"from": before, "to": priority})
    return ticket
