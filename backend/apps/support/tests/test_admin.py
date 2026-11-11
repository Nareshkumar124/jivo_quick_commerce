"""P7 support ticket records in the admin (05 §2 Support): read-only for Super Admin, Ops and
Support; changes happen only in the Ops support console through apps.support.services.

Test cases (qa/docs/02-test-case-repository.md): P7-TC-40 (admin P7 screens: the ticket
records, role matrix enforced), P7-TC-18 (Finance and the other roles refused)."""

import pytest
from django.contrib.auth.models import Permission
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.ops_console.tests.helpers import PRINCIPALS, SUPERUSER, expected_status, login_as
from apps.support.choices import TicketCategory, TicketStatus
from apps.support.models import SupportTicket, TicketMessage

pytestmark = pytest.mark.django_db

VIEW_ROLES = frozenset({roles.SUPER_ADMIN, SUPERUSER, roles.OPS, roles.SUPPORT})


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def ticket():
    customer = UserFactory(phone="+919811122233")
    ticket = SupportTicket.objects.create(
        user=customer,
        category=TicketCategory.OTHER,
        subject="Other",
        last_activity_at=timezone.now(),
    )
    TicketMessage.objects.create(ticket=ticket, sender=customer, is_staff=False, body="Help me")
    return ticket


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_view_matrix(client, principal, ticket):
    """P7-TC-40, P7-TC-18: 05 §3 "Support tickets" (Super Admin, Ops, Support); every other
    role, a customer and a visitor are refused."""
    login_as(client, principal)
    expected = expected_status(principal, VIEW_ROLES)
    assert client.get(reverse("admin:support_supportticket_changelist")).status_code == expected
    response = client.get(reverse("admin:support_supportticket_change", args=[ticket.pk]))
    assert response.status_code == expected
    if expected == 200:
        html = response.content.decode()
        assert "Help me" in html
        assert "+919811122233" not in html  # customer shown by id only
        assert reverse("ops:support-ticket", args=[ticket.pk]) in html
        # These roles also hold `accounts.view_customer` (05 §3 "Customers (PII)").
        assert reverse("admin:accounts_customer_change", args=[ticket.user_id]) in html


def test_customer_link_needs_customer_view(client, ticket):
    """P7-TC-40 (review fix, T-716): the customer is linked to the Customers admin only for
    staff who may open it (`accounts.view_customer`); anyone else sees plain text."""
    user = StaffUserFactory()
    user.user_permissions.add(
        *Permission.objects.filter(
            content_type__app_label="support",
            codename__in=("view_supportticket", "view_ticketmessage"),
        )
    )
    client.force_login(user)
    response = client.get(reverse("admin:support_supportticket_change", args=[ticket.pk]))
    assert response.status_code == 200
    html = response.content.decode()
    assert f"Customer {ticket.user_id}" in html
    assert reverse("admin:accounts_customer_change", args=[ticket.user_id]) not in html
    assert "+919811122233" not in html


def test_customer_link_uses_the_customers_admin_rule(client, ticket, monkeypatch):
    """P7-TC-40 (review minor, P8): the link uses the Customers admin's own view check
    (`can_view_full_phone` and the view permission), so it can never point at a page that
    answers 403. A viewer who holds `accounts.view_customer` but fails `can_view_full_phone`
    sees plain text."""
    user = login_as(client, roles.SUPPORT)
    ticket_url = reverse("admin:support_supportticket_change", args=[ticket.pk])
    customer_url = reverse("admin:accounts_customer_change", args=[ticket.user_id])
    # Normal case: the link is shown and it opens.
    assert customer_url in client.get(ticket_url).content.decode()
    assert client.get(customer_url).status_code == 200
    # The PII rule gets stricter than the permission (e.g. a future condition).
    monkeypatch.setattr("apps.accounts.admin.can_view_full_phone", lambda viewer: False)
    assert user.has_perm("accounts.view_customer")
    html = client.get(ticket_url).content.decode()
    assert f"Customer {ticket.user_id}" in html
    assert customer_url not in html
    assert client.get(customer_url).status_code == 403


@pytest.mark.parametrize("principal", [roles.SUPER_ADMIN, SUPERUSER, roles.SUPPORT])
def test_read_only_even_for_superusers(client, principal, ticket):
    """P7-TC-40: no add, change or delete in the admin, even for a superuser; replies and
    status changes go through the support console and `apps.support.services`."""
    login_as(client, principal)
    url = reverse("admin:support_supportticket_change", args=[ticket.pk])
    response = client.post(url, {"status": TicketStatus.CLOSED})
    assert response.status_code == 403
    ticket.refresh_from_db()
    assert ticket.status == TicketStatus.OPEN
    assert client.get(reverse("admin:support_supportticket_add")).status_code == 403
    delete = reverse("admin:support_supportticket_delete", args=[ticket.pk])
    assert client.post(delete, {"post": "yes"}).status_code == 403
    assert SupportTicket.objects.filter(pk=ticket.pk).exists()


def test_search_by_order_number_and_id(client, ticket):
    """P7-TC-40: search by ticket id or order number only (no message bodies)."""
    login_as(client, roles.SUPPORT)
    url = reverse("admin:support_supportticket_changelist")
    assert client.get(url, {"q": str(ticket.pk)}).status_code == 200
    assert client.get(url, {"q": "JV-NOPE"}).status_code == 200
