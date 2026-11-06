"""Support tickets and their message threads (07 §2.9, 06 §2.7, 05 §2 Support).

Every change goes through `apps.support.services` (customer side: create, reply; staff side:
reply, change status, assign, set priority). Message bodies are personal data: they are never
logged and never copied into the audit log (09 PII).
"""

from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.accounts.choices import AppName
from apps.core.models import TimeStampedModel
from apps.support.choices import (
    ORDER_REQUIRED_CATEGORIES,
    TicketCategory,
    TicketPriority,
    TicketStatus,
)

MESSAGE_MAX_LENGTH = 2000  # staff replies; customer messages are limited to 1000 by the API


class SupportTicket(TimeStampedModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="support_tickets"
    )
    app = models.CharField(
        max_length=16,
        choices=AppName.choices,
        default=AppName.CUSTOMER,
        help_text="The app the ticket was raised from (the session's `app`).",
    )
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="support_tickets",
    )
    task = models.ForeignKey(
        "delivery.DeliveryTask",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="support_tickets",
        help_text="Rider tickets: a task the rider was assigned (Phase 7).",
    )
    payout = models.ForeignKey(
        "delivery.Payout",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="support_tickets",
        help_text="Rider tickets: one of the rider's payouts (Phase 7).",
    )
    category = models.CharField(max_length=20, choices=TicketCategory.choices)
    subject = models.CharField(max_length=120, help_text="Built from the category and order.")
    status = models.CharField(
        max_length=12, choices=TicketStatus.choices, default=TicketStatus.OPEN
    )
    priority = models.CharField(
        max_length=8, choices=TicketPriority.choices, default=TicketPriority.NORMAL
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_support_tickets",
        limit_choices_to={"is_staff": True},
    )
    last_activity_at = models.DateTimeField(
        help_text="Last message or status change; the apps sort by it (newest first)."
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    # Phase 7 SLA (05 §2 Support; PM default targets per priority in settings
    # SUPPORT_FIRST_RESPONSE_SLA_MINUTES / SUPPORT_RESOLUTION_SLA_HOURS). Set at creation and
    # again when the priority changes; null on tickets older than Phase 7 R1.
    first_response_at = models.DateTimeField(
        null=True, blank=True, help_text="The first staff reply."
    )
    first_response_due_at = models.DateTimeField(null=True, blank=True)
    resolution_due_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-last_activity_at", "-id"]
        permissions = [
            ("handle_ticket", "Can reply to, assign and change the status of support tickets"),
        ]
        indexes = [
            models.Index(fields=["user", "-last_activity_at"], name="support_ticket_user_act"),
            models.Index(fields=["status", "-last_activity_at"], name="support_ticket_status_act"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=~Q(category__in=sorted(ORDER_REQUIRED_CATEGORIES))
                | Q(order__isnull=False),
                name="support_ticket_order_required",
            ),
        ]

    def __str__(self) -> str:
        return self.number

    @property
    def number(self) -> str:
        """Shown to the customer and to support, e.g. `TK-000123`."""
        return f"TK-{self.pk:06d}" if self.pk else "TK-new"


class TicketMessage(models.Model):
    ticket = models.ForeignKey(SupportTicket, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="support_messages",
    )
    is_staff = models.BooleanField(help_text="Sent by Jivo support, not the customer.")
    body = models.TextField(max_length=MESSAGE_MAX_LENGTH)
    attachments = models.JSONField(
        default=list,
        blank=True,
        help_text="Storage keys of attached images. Not used yet (upload contract: docs/06 §2.7).",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [models.Index(fields=["ticket", "created_at"], name="support_msg_ticket_created")]
        constraints = [
            models.CheckConstraint(condition=~Q(body=""), name="support_message_body_not_empty"),
        ]

    def __str__(self) -> str:
        return f"{self.ticket.number} message {self.pk}"


def attachment_upload_to(instance, filename: str) -> str:
    """Private bucket, random key (06 §2.7): `support/<ticket id>/<uuid>.webp`."""
    return f"support/{instance.ticket_id}/{instance.key}.webp"


class TicketAttachment(models.Model):
    """An image the customer attached to a ticket (06 §2.7). Uploaded first
    (`POST /support/tickets/{id}/attachments/`), then claimed by the next message that names
    its `key` in `attachment_keys`. Stored re-encoded (WebP, EXIF stripped) in the private
    bucket; served only through short-lived signed URLs."""

    key = models.CharField(max_length=32, unique=True, help_text="Random hex id (uuid4).")
    ticket = models.ForeignKey(SupportTicket, on_delete=models.CASCADE, related_name="uploads")
    message = models.ForeignKey(
        TicketMessage,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="attachment_files",
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    file = models.FileField(upload_to=attachment_upload_to, max_length=200)
    size = models.PositiveIntegerField(help_text="Bytes stored (after re-encoding).")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [
            models.Index(fields=["ticket", "uploaded_by", "created_at"], name="support_att_upl")
        ]

    def __str__(self) -> str:
        return f"{self.ticket.number} attachment {self.key}"


class CannedReply(TimeStampedModel):
    """A saved reply support agents can insert (05 §2 Support "canned replies"). Plain text;
    `{{order_number}}` and `{{ticket_number}}` are filled by `services.render_canned_reply`."""

    title = models.CharField(max_length=80, unique=True)
    body = models.TextField(max_length=MESSAGE_MAX_LENGTH)
    category = models.CharField(
        max_length=20,
        choices=TicketCategory.choices,
        blank=True,
        help_text="Suggested for tickets of this category; empty = any.",
    )
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["sort_order", "title"]
        verbose_name_plural = "canned replies"

    def __str__(self) -> str:
        return self.title
