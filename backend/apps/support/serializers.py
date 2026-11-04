from rest_framework import serializers

from apps.support.choices import TicketCategory, TicketStatus
from apps.support.services import (
    CUSTOMER_MESSAGE_MAX_LENGTH,
    CUSTOMER_MESSAGE_MIN_LENGTH,
)


class TicketSummarySerializer(serializers.Serializer):
    """One row of "My tickets"."""

    id = serializers.IntegerField()
    number = serializers.CharField(help_text='Shown to the customer and support, e.g. "TK-000123".')
    category = serializers.ChoiceField(choices=TicketCategory.choices)
    status = serializers.ChoiceField(
        choices=TicketStatus.choices,
        help_text="The customer can reply unless CLOSED; a reply to RESOLVED reopens it (OPEN).",
    )
    order_id = serializers.IntegerField(allow_null=True)
    order_number = serializers.CharField(allow_null=True, source="order.order_number")
    last_message = serializers.CharField(
        allow_null=True,
        source="last_message_preview",
        help_text="The newest message, cut to 140 characters (plain text).",
    )
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField(
        source="last_activity_at",
        help_text="Last message or status change; the list is sorted by it, newest first.",
    )


class TicketMessageSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    body = serializers.CharField(help_text="Plain text; show as text, never as HTML.")
    from_support = serializers.BooleanField(
        source="is_staff", help_text="Sent by Jivo support, not the customer."
    )
    created_at = serializers.DateTimeField()


class TicketSerializer(TicketSummarySerializer):
    """A ticket with its whole thread, oldest message first."""

    can_reply = serializers.SerializerMethodField(
        help_text="False once the ticket is CLOSED: hide the reply box and offer a new ticket."
    )
    messages = TicketMessageSerializer(many=True, source="messages.all")

    def get_can_reply(self, ticket) -> bool:
        return ticket.status != TicketStatus.CLOSED


class PaginatedTicketSummaryListSerializer(serializers.Serializer):
    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = TicketSummarySerializer(many=True)


def _message_field(min_length: int) -> serializers.CharField:
    return serializers.CharField(
        min_length=min_length,
        max_length=CUSTOMER_MESSAGE_MAX_LENGTH,
        trim_whitespace=True,
        help_text=f"Plain text, {min_length} to {CUSTOMER_MESSAGE_MAX_LENGTH} characters after "
        "trimming.",
    )


class TicketCreateSerializer(serializers.Serializer):
    category = serializers.ChoiceField(
        choices=TicketCategory.choices,
        help_text="MISSING_ITEMS, DAMAGED_ITEMS, WRONG_ITEMS and LATE_DELIVERY need `order_id`.",
    )
    message = _message_field(CUSTOMER_MESSAGE_MIN_LENGTH)
    order_id = serializers.IntegerField(
        required=False,
        allow_null=True,
        min_value=1,
        help_text="One of the caller's orders (another user's order is refused as not found).",
    )


class TicketReplySerializer(serializers.Serializer):
    message = _message_field(1)
