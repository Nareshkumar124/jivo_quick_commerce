"""Support tickets (06 §2.7, 07 §2.9, 05 §2 Support): every ticket change goes through here.

**Customer side** (the API): `own_tickets`, `get_own_ticket`, `create_ticket`,
`add_customer_message`. Tickets are always looked up inside the caller's own tickets of the
calling app (`app`, from the access token: the rider app sees the rider tickets, the customer
app the customer ones, even for one person who uses both): another user's ticket, or one of the
other app, is "not found", never fetched first and checked after.

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

**Phase 7 additions:** SLA due times per priority (`first_response_due_at`,
`resolution_due_at`; `sla_state`, `with_sla`, `breached_tickets`), the customer's push/inbox
notification on a staff reply (`support.replied`, after commit), image attachments
(`upload_attachment`, `attachment_keys` on replies, signed URLs) and canned replies
(`canned_replies`, `render_canned_reply`).

**PII (09):** message bodies are personal data. Logs and audit entries carry ids, codes and
lengths only, never a body, a phone number or a name.
"""

import io
import logging
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.db.models import BooleanField, Case, F, OuterRef, Q, Subquery, Value, When
from django.db.models.functions import Left
from django.utils import timezone

from apps.accounts.choices import AppName
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.support.choices import (
    ORDER_REQUIRED_CATEGORIES,
    RIDER_CATEGORIES,
    TicketCategory,
    TicketPriority,
    TicketStatus,
)
from apps.support.models import (
    MESSAGE_MAX_LENGTH,
    CannedReply,
    SupportTicket,
    TicketAttachment,
    TicketMessage,
)

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
MSG_RIDER_CATEGORY = "This category is only available in the rider app."
MSG_TASK_NOT_FOUND = "Task not found."
MSG_PAYOUT_NOT_FOUND = "Payout not found."
MSG_ATTACHMENT_NOT_FOUND = "Upload the photo again: it was not found or has expired."
MSG_TOO_MANY_ATTACHMENTS = "Attach at most {limit} photos to one message."
MSG_IMAGE_TYPE = "Upload a JPEG, PNG or WebP image."
MSG_IMAGE_TOO_LARGE = "The image is larger than {limit_mb} MB."

MAX_ATTACHMENTS_PER_MESSAGE = 3
ATTACHMENT_CLAIM_WINDOW = timedelta(hours=1)
ATTACHMENT_MAX_SIDE = 2048
ATTACHMENT_MAX_PIXELS = 40_000_000
ATTACHMENT_FORMATS = {"JPEG", "PNG", "WEBP"}

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
    return queryset.select_related("order", "task__order").annotate(
        last_message_preview=Subquery(newest.values(preview=Left("body", PREVIEW_LENGTH))[:1])
    )


def with_detail_relations(queryset):
    return with_list_relations(queryset).prefetch_related("messages", "messages__attachment_files")


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


def due_times(start, priority: str) -> dict:
    """The SLA targets for a ticket opened at `start` with `priority` (PM default, settings
    `SUPPORT_FIRST_RESPONSE_SLA_MINUTES` / `SUPPORT_RESOLUTION_SLA_HOURS`)."""
    first = settings.SUPPORT_FIRST_RESPONSE_SLA_MINUTES.get(priority, 60)
    resolve = settings.SUPPORT_RESOLUTION_SLA_HOURS.get(priority, 24)
    return {
        "first_response_due_at": start + timedelta(minutes=int(first)),
        "resolution_due_at": start + timedelta(hours=int(resolve)),
    }


def ticket_app(app: str | None) -> str:
    """The ticket app for a session's `app` claim: rider, else customer (as `create_ticket`)."""
    return AppName.RIDER if app == AppName.RIDER else AppName.CUSTOMER


def own_tickets(user, app: str | None = None):
    """The user's tickets raised from `app` (None or unknown: the customer app)."""
    return SupportTicket.objects.filter(user=user, app=ticket_app(app))


def get_own_ticket(user, ticket_id: int, *, app: str | None = None) -> SupportTicket:
    ticket = with_detail_relations(own_tickets(user, app)).filter(pk=ticket_id).first()
    if ticket is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TICKET_NOT_FOUND)
    return ticket


def create_ticket(
    user,
    *,
    category: str,
    message: str,
    order_id: int | None = None,
    app: str | None = None,
    task_id: int | None = None,
    payout_id: int | None = None,
) -> SupportTicket:
    """A new OPEN ticket with the customer's first message. `order_id` must be one of the
    customer's own orders (another user's order is "not found"); the order categories need
    one. The serializer has already checked the message length.

    Rider tickets (Phase 7): the rider categories (TASK, PAYOUT, CASH) need a rider session
    (`app` = rider). `task_id` must be a task the caller (as a rider) was assigned and
    `payout_id` one of their payouts; anything else is "not found" (400)."""
    from apps.orders.services import own_orders

    if category in RIDER_CATEGORIES and app != AppName.RIDER:
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"category": [MSG_RIDER_CATEGORY]})
    task, payout = _rider_records(user, task_id, payout_id)
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
            app=ticket_app(app),
            order=order,
            task=task,
            payout=payout,
            category=category,
            subject=_subject(category, order or (task.order if task else None)),
            last_activity_at=now,
            **due_times(now, TicketPriority.NORMAL),
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


def _rider_records(user, task_id, payout_id):
    """The caller's own task / payout (as a rider), or 400 "not found"."""
    if task_id is None and payout_id is None:
        return None, None
    from apps.delivery.models import DeliveryTask, Payout

    task = payout = None
    if task_id is not None:
        task = (
            DeliveryTask.objects.select_related("order")
            .filter(pk=task_id, rider__user=user)
            .first()
        )
        if task is None:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"task_id": [MSG_TASK_NOT_FOUND]})
    if payout_id is not None:
        payout = Payout.objects.filter(pk=payout_id, rider__user=user).first()
        if payout is None:
            raise ApiError(
                ErrorCode.VALIDATION_ERROR, details={"payout_id": [MSG_PAYOUT_NOT_FOUND]}
            )
    return task, payout


def add_customer_message(
    user,
    ticket_id: int,
    body: str,
    *,
    attachment_keys: list[str] | tuple[str, ...] = (),
    app: str | None = None,
) -> SupportTicket:
    """The customer's reply. CLOSED refuses it (400 VALIDATION_ERROR); RESOLVED reopens the
    ticket (OPEN)."""
    with transaction.atomic():
        ticket = own_tickets(user, app).select_for_update().filter(pk=ticket_id).first()
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
        message = TicketMessage.objects.create(
            ticket=ticket, sender=user, is_staff=False, body=body
        )
        _claim_attachments(user, ticket, message, attachment_keys, now)
        _emit(
            "support.customer_replied",
            ticket,
            reopened=reopened,
            length=len(body),
            attachments=len(attachment_keys),
        )
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
        if ticket.first_response_at is None:
            ticket.first_response_at = now
        ticket.save()
        message = TicketMessage.objects.create(ticket=ticket, sender=user, is_staff=True, body=body)
        _notify_reply(ticket, message)
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
        dues = due_times(ticket.created_at, priority)
        ticket.first_response_due_at = dues["first_response_due_at"]
        ticket.resolution_due_at = dues["resolution_due_at"]
        ticket.save(
            update_fields=["priority", "first_response_due_at", "resolution_due_at", "updated_at"]
        )
        audit.record(user, "support.priority", ticket, {"from": before, "to": priority})
    return ticket


# --------------------------------------------------------------------------- SLA (Phase 7)

OPEN_STATUSES = (TicketStatus.OPEN, TicketStatus.IN_PROGRESS)


def sla_state(ticket: SupportTicket, now=None) -> dict:
    """`{first_response_due_at, first_response_breached, resolution_due_at,
    resolution_breached}` for one ticket. A first response is late when it came (or is still
    missing) after its due time; a resolution is late when the ticket was resolved or closed
    after its due time, or is still open past it."""
    now = now or timezone.now()
    first_due, resolve_due = ticket.first_response_due_at, ticket.resolution_due_at
    done_at = ticket.resolved_at or ticket.closed_at
    first_late = bool(first_due and (ticket.first_response_at or now) > first_due)
    resolve_late = bool(
        resolve_due
        and (
            (done_at is not None and done_at > resolve_due)
            or (ticket.status in OPEN_STATUSES and now > resolve_due)
        )
    )
    return {
        "first_response_due_at": first_due,
        "first_response_breached": first_late,
        "resolution_due_at": resolve_due,
        "resolution_breached": resolve_late,
    }


def _breached_q(now) -> Q:
    first = Q(first_response_due_at__isnull=False) & (
        Q(first_response_at__isnull=True, first_response_due_at__lt=now)
        | Q(first_response_at__gt=F("first_response_due_at"))
    )
    resolution = Q(
        resolution_due_at__isnull=False, status__in=OPEN_STATUSES, resolution_due_at__lt=now
    )
    return first | resolution


def with_sla(queryset, now=None):
    """Annotate `sla_breached` (first response late, or still open past the resolution due
    time) for the staff ticket list."""
    now = now or timezone.now()
    return queryset.annotate(
        sla_breached=Case(
            When(_breached_q(now), then=Value(True)),
            default=Value(False),
            output_field=BooleanField(),
        )
    )


def breached_tickets(user, now=None):
    """Open tickets (OPEN / IN_PROGRESS) past an SLA target, for the support queue and the
    dashboard. Empty for users who may not handle tickets."""
    now = now or timezone.now()
    return staff_tickets(user).filter(status__in=OPEN_STATUSES).filter(_breached_q(now))


# --------------------------------------------------------------------------- notification


def _notify_reply(ticket: SupportTicket, message: TicketMessage) -> None:
    """Push + inbox to the ticket's customer (or rider) after commit (`support.replied`;
    idempotent per message). The text never contains the reply itself."""
    from apps.support.notifications import notify_staff_reply

    ticket_id, message_id = ticket.pk, message.pk
    transaction.on_commit(lambda: notify_staff_reply(ticket_id, message_id))


# --------------------------------------------------------------------------- attachments


def _invalid_file(message: str) -> ApiError:
    return ApiError(ErrorCode.VALIDATION_ERROR, details={"file": [message]})


def _reencode(upload) -> ContentFile:
    from PIL import Image, ImageOps, UnidentifiedImageError

    limit = settings.SUPPORT_ATTACHMENT_MAX_BYTES
    size = getattr(upload, "size", None)
    if size is not None and size > limit:
        raise _invalid_file(MSG_IMAGE_TOO_LARGE.format(limit_mb=limit // (1024 * 1024)))
    try:
        upload.seek(0)
        with Image.open(upload) as probe:
            if probe.format not in ATTACHMENT_FORMATS:
                raise _invalid_file(MSG_IMAGE_TYPE)
            if probe.width * probe.height > ATTACHMENT_MAX_PIXELS:
                raise _invalid_file(MSG_IMAGE_TYPE)
            probe.verify()
        upload.seek(0)
        with Image.open(upload) as opened:
            image = ImageOps.exif_transpose(opened).convert("RGB")
            image.thumbnail((ATTACHMENT_MAX_SIDE, ATTACHMENT_MAX_SIDE), Image.Resampling.LANCZOS)
            buffer = io.BytesIO()
            image.save(buffer, "WEBP", quality=85, method=4)  # no EXIF/ICC: metadata dropped
    except ApiError:
        raise
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise _invalid_file(MSG_IMAGE_TYPE) from exc
    return ContentFile(buffer.getvalue())


def upload_attachment(user, ticket_id: int, upload, *, app: str | None = None) -> TicketAttachment:
    """Store a photo for the caller's own ticket (06 §2.7): JPEG/PNG/WebP, at most
    `SUPPORT_ATTACHMENT_MAX_BYTES`, re-encoded to WebP (EXIF stripped) under
    `support/<ticket id>/<key>.webp` in the private bucket. A CLOSED ticket refuses it.
    A photo no reply claims within `ATTACHMENT_CLAIM_WINDOW` is deleted by
    `purge_unclaimed_attachments`."""
    ticket = own_tickets(user, app).filter(pk=ticket_id).first()
    if ticket is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TICKET_NOT_FOUND)
    if ticket.status == TicketStatus.CLOSED:
        raise ApiError(
            ErrorCode.VALIDATION_ERROR, MSG_TICKET_CLOSED, details={"ticket": [MSG_TICKET_CLOSED]}
        )
    content = _reencode(upload)
    attachment = TicketAttachment(
        key=uuid.uuid4().hex, ticket=ticket, uploaded_by=user, size=content.size
    )
    attachment.file.save("upload.webp", content, save=False)
    attachment.save()
    logger.info(
        "support attachment uploaded ticket=%s key=%s size=%s",
        ticket.pk,
        attachment.key,
        attachment.size,
    )
    return attachment


def _claim_attachments(user, ticket, message, keys, now) -> None:
    keys = list(dict.fromkeys(keys or ()))
    if not keys:
        return
    if len(keys) > MAX_ATTACHMENTS_PER_MESSAGE:
        limit = MAX_ATTACHMENTS_PER_MESSAGE
        raise ApiError(
            ErrorCode.VALIDATION_ERROR,
            details={"attachment_keys": [MSG_TOO_MANY_ATTACHMENTS.format(limit=limit)]},
        )
    found = list(
        TicketAttachment.objects.select_for_update().filter(
            ticket=ticket,
            uploaded_by=user,
            message__isnull=True,
            key__in=keys,
            created_at__gte=now - ATTACHMENT_CLAIM_WINDOW,
        )
    )
    if len(found) != len(keys):
        raise ApiError(
            ErrorCode.VALIDATION_ERROR, details={"attachment_keys": [MSG_ATTACHMENT_NOT_FOUND]}
        )
    TicketAttachment.objects.filter(pk__in=[a.pk for a in found]).update(message=message)
    message.attachments = keys
    message.save(update_fields=["attachments"])


def attachment_url(attachment: TicketAttachment) -> str:
    """A short-lived signed URL (`SUPPORT_ATTACHMENT_URL_SECONDS`)."""
    seconds = settings.SUPPORT_ATTACHMENT_URL_SECONDS
    try:
        return default_storage.url(attachment.file.name, expire=seconds)
    except TypeError:  # local file storage (tests): no expiry argument
        return default_storage.url(attachment.file.name)


def attachment_body(attachment: TicketAttachment) -> dict:
    return {"key": attachment.key, "url": attachment_url(attachment)}


def staff_attachment_url(user, key: str, *, ip: str | None = None) -> str:
    """Signed URL of an attachment for the admin's ticket thread. The photo is the customer's
    personal data, so each opening is audited (`support.attachment_view`: ids only)."""
    _require_handler(user)
    attachment = TicketAttachment.objects.filter(key=key, ticket__in=staff_tickets(user)).first()
    if attachment is None:
        raise ValidationError(MSG_ATTACHMENT_NOT_FOUND)
    url = attachment_url(attachment)
    audit.record(
        user,
        "support.attachment_view",
        attachment.ticket,
        {"attachment": attachment.key, "message_id": attachment.message_id},
        ip=ip,
    )
    return url


def purge_unclaimed_attachments(now=None) -> int:
    """Delete photos (rows and stored files) that no reply claimed within
    `ATTACHMENT_CLAIM_WINDOW` (they can no longer be claimed). Daily beat job; idempotent.
    Returns the number deleted."""
    cutoff = (now or timezone.now()) - ATTACHMENT_CLAIM_WINDOW
    count = 0
    stale = TicketAttachment.objects.filter(message__isnull=True, created_at__lt=cutoff)
    for attachment in stale.iterator():
        with transaction.atomic():
            locked = (
                TicketAttachment.objects.select_for_update(skip_locked=True)
                .filter(pk=attachment.pk, message__isnull=True)
                .first()
            )
            if locked is None:  # claimed meanwhile, or being claimed now
                continue
            name = locked.file.name
            locked.delete()
            transaction.on_commit(lambda name=name: _delete_file(name))
            count += 1
    if count:
        logger.info("support: %s unclaimed attachments purged", count)
    return count


def _delete_file(name: str) -> None:
    try:
        default_storage.delete(name)
    except Exception:  # the row is gone; a stray file is only logged
        logger.warning("support: could not delete attachment file %s", name, exc_info=True)


# --------------------------------------------------------------------------- canned replies


def canned_replies(user, category: str | None = None):
    """Active canned replies (05 §2): for `category`, those of that category or of any."""
    _require_handler(user)
    rows = CannedReply.objects.filter(is_active=True)
    if category:
        rows = rows.filter(Q(category=category) | Q(category=""))
    return rows.order_by("sort_order", "title")


def render_canned_reply(user, reply_id: int, ticket_id: int) -> str:
    """The canned reply's text for a ticket, with `{{ticket_number}}` and `{{order_number}}`
    filled; the agent edits it and sends it with `staff_reply`."""
    _require_handler(user)
    reply = CannedReply.objects.filter(pk=reply_id, is_active=True).first()
    ticket = staff_tickets(user).select_related("order").filter(pk=ticket_id).first()
    if reply is None or ticket is None:
        raise ValidationError("Canned reply or ticket not found.")
    order_number = ticket.order.order_number if ticket.order_id else ""
    return reply.body.replace("{{ticket_number}}", ticket.number).replace(
        "{{order_number}}", order_number
    )
