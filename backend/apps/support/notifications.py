"""Support notifications (Phase 7): the customer (or rider) is told when support replies.

Events (defined in `apps.notifications.catalog`): `support.ticket_replied` (customer app;
category `support`, inbox on, link `jivo://support/tickets/<id>`, FCM data
`{type: "ticket", ticket_id}`) and `support.ticket_replied_rider` (rider app). Push and inbox only,
no SMS. The text never quotes the reply (it can hold personal data).
"""

from apps.accounts.choices import AppName

EVENT_CUSTOMER = "support.ticket_replied"
EVENT_RIDER = "support.ticket_replied_rider"


def notify_staff_reply(ticket_id: int, message_id: int):
    """`notify` the ticket's owner of a staff reply. Idempotent per message (dedupe key)."""
    from apps.notifications.services import notify
    from apps.support.models import SupportTicket

    ticket = SupportTicket.objects.select_related("user").filter(pk=ticket_id).first()
    if ticket is None:  # pragma: no cover - tickets are never deleted
        return None
    event = EVENT_RIDER if ticket.app == AppName.RIDER else EVENT_CUSTOMER
    return notify(
        ticket.user,
        event,
        {"ticket_id": ticket.pk, "ticket_number": ticket.number},
        dedupe_key=f"{event}:{ticket.user_id}:{message_id}",
        sms=False,
    )
