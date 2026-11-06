"""seed_demo step: one answered support ticket for the test customer (manual testing of the
help screens)."""

from apps.accounts.models import User
from apps.accounts.seed import TEST_CUSTOMER_PHONE
from apps.support.choices import TicketCategory, TicketStatus
from apps.support.models import SupportTicket, TicketMessage

SEED_SUBJECT = "Account (demo)"


def seed_tickets(stdout, options) -> None:
    from django.utils import timezone

    customer = User.objects.filter(phone=TEST_CUSTOMER_PHONE).first()
    if customer is None:
        stdout.write("  demo ticket skipped (no test customer)")
        return
    if SupportTicket.objects.filter(user=customer, subject=SEED_SUBJECT).exists():
        stdout.write("  demo ticket already there")
        return
    support = User.objects.filter(email="support@jivo.test").first()
    now = timezone.now()
    ticket = SupportTicket.objects.create(
        user=customer,
        category=TicketCategory.ACCOUNT,
        subject=SEED_SUBJECT,
        status=TicketStatus.RESOLVED,
        resolved_at=now,
        last_activity_at=now,
    )
    TicketMessage.objects.create(
        ticket=ticket,
        sender=customer,
        is_staff=False,
        body="How do I change the phone number on my account?",
    )
    TicketMessage.objects.create(
        ticket=ticket,
        sender=support,
        is_staff=True,
        body="You can log in with the new number and we will move your orders. Anything else?",
    )
    stdout.write(f"  demo ticket {ticket.number}")


CANNED_REPLIES = (
    (
        "Refund started",
        "PAYMENT_REFUND",
        "We have started the refund for order {{order_number}}. It reaches your original "
        "payment method in 5-7 working days.",
    ),
    (
        "Sorry about damaged items",
        "DAMAGED_ITEMS",
        "Sorry that items in order {{order_number}} arrived damaged. Could you share a photo? "
        "We will refund or replace them.",
    ),
    (
        "Anything else?",
        "",
        "Is there anything else we can help you with on ticket {{ticket_number}}?",
    ),
)


def seed_canned_replies(stdout, options) -> None:
    """Phase 7: a few canned replies for the support console (idempotent by title)."""
    from apps.support.models import CannedReply

    for order, (title, category, body) in enumerate(CANNED_REPLIES):
        CannedReply.objects.get_or_create(
            title=title, defaults={"category": category, "body": body, "sort_order": order}
        )
    stdout.write(f"  canned replies: {CannedReply.objects.count()}")
