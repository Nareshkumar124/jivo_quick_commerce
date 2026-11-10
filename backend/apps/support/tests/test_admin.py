"""P7 support ticket records in the admin (05 §2 Support): read-only for Super Admin, Ops and
Support; changes happen only in the Ops support console through apps.support.services."""

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
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


@pytest.mark.parametrize("principal", [roles.SUPER_ADMIN, SUPERUSER, roles.SUPPORT])
def test_read_only_even_for_superusers(client, principal, ticket):
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
    login_as(client, roles.SUPPORT)
    url = reverse("admin:support_supportticket_changelist")
    assert client.get(url, {"q": str(ticket.pk)}).status_code == 200
    assert client.get(url, {"q": "JV-NOPE"}).status_code == 200
