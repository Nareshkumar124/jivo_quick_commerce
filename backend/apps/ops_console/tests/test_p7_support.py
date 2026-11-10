"""P7 support ticket console (05 §2 Support; §3 "Support tickets": Super Admin, Ops, Support).
Every action goes through `apps.support.services`; other roles get 403 and change nothing."""

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.core.models import AuditLog
from apps.ops_console.tests.helpers import (
    PRINCIPALS,
    SUPERUSER,
    expected_status,
    login_as,
    staff_in_role,
)
from apps.support.choices import TicketCategory, TicketPriority, TicketStatus
from apps.support.models import SupportTicket, TicketMessage

pytestmark = pytest.mark.django_db

SUPPORT_ROLES = frozenset({roles.SUPER_ADMIN, SUPERUSER, roles.OPS, roles.SUPPORT})


def make_ticket(status=TicketStatus.OPEN, **kwargs):
    customer = kwargs.pop("user", None) or UserFactory(name="Asha Verma")
    ticket = SupportTicket.objects.create(
        user=customer,
        category=TicketCategory.OTHER,
        subject="Other",
        status=status,
        last_activity_at=timezone.now(),
        **kwargs,
    )
    TicketMessage.objects.create(
        ticket=ticket, sender=customer, is_staff=False, body="Where is my refund please?"
    )
    return ticket


def action_url(ticket, action):
    return reverse("ops:support-ticket-action", args=[ticket.pk, action])


class TestRoleMatrix:
    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_list_and_detail(self, client, principal):
        ticket = make_ticket()
        login_as(client, principal)
        expected = expected_status(principal, SUPPORT_ROLES)
        assert client.get(reverse("ops:support")).status_code == expected
        assert client.get(reverse("ops:support-tickets"), HTTP_HX_REQUEST="true").status_code == (
            401 if expected == 302 else expected
        )
        response = client.get(reverse("ops:support-ticket", args=[ticket.pk]))
        assert response.status_code == expected
        if expected == 200:
            assert "Where is my refund please?" in response.content.decode()

    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_reply_refused_for_other_roles(self, client, principal):
        ticket = make_ticket()
        login_as(client, principal)
        response = client.post(action_url(ticket, "reply"), {"body": "Refund is on its way."})
        if principal in SUPPORT_ROLES:
            assert response.status_code == 302
            assert ticket.messages.filter(is_staff=True).count() == 1
        else:
            assert response.status_code == expected_status(principal, SUPPORT_ROLES)
            assert ticket.messages.filter(is_staff=True).count() == 0

    def test_unknown_ticket_is_404(self, client):
        login_as(client, roles.SUPPORT)
        assert client.get(reverse("ops:support-ticket", args=[999999])).status_code == 404
        assert (
            client.post(
                reverse("ops:support-ticket-action", args=[999999, "status"]),
                {"status": "RESOLVED"},
            ).status_code
            == 404
        )

    def test_get_on_action_is_refused(self, client):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        assert client.get(action_url(ticket, "status")).status_code == 405

    def test_unknown_action_is_404(self, client):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        assert client.post(action_url(ticket, "delete"), {}).status_code == 404


class TestActions:
    def test_reply_moves_open_to_in_progress_and_audits(self, client):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        response = client.post(action_url(ticket, "reply"), {"body": "Looking into it."})
        assert response.status_code == 302
        ticket.refresh_from_db()
        assert ticket.status == TicketStatus.IN_PROGRESS
        assert AuditLog.objects.filter(action="support.reply").count() == 1

    def test_reply_and_resolve(self, client):
        ticket = make_ticket()
        login_as(client, roles.OPS)
        client.post(action_url(ticket, "reply"), {"body": "Done.", "status": "RESOLVED"})
        ticket.refresh_from_db()
        assert ticket.status == TicketStatus.RESOLVED

    def test_closed_ticket_reply_is_refused(self, client):
        ticket = make_ticket(status=TicketStatus.CLOSED)
        login_as(client, roles.SUPPORT)
        response = client.post(action_url(ticket, "reply"), {"body": "Hello"}, follow=True)
        assert ticket.messages.filter(is_staff=True).count() == 0
        assert "closed" in response.content.decode().lower()

    def test_invalid_transition_shows_error(self, client):
        ticket = make_ticket(status=TicketStatus.CLOSED)
        login_as(client, roles.SUPPORT)
        client.post(action_url(ticket, "status"), {"status": "OPEN"})
        ticket.refresh_from_db()
        assert ticket.status == TicketStatus.CLOSED

    def test_priority(self, client):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        client.post(action_url(ticket, "priority"), {"priority": TicketPriority.URGENT})
        ticket.refresh_from_db()
        assert ticket.priority == TicketPriority.URGENT

    def test_assign_only_to_handlers(self, client):
        ticket = make_ticket()
        handler = staff_in_role(roles.SUPPORT)
        finance = staff_in_role(roles.FINANCE)
        login_as(client, roles.OPS)
        client.post(action_url(ticket, "assign"), {"assignee": finance.pk})
        ticket.refresh_from_db()
        assert ticket.assigned_to is None  # not a choice
        client.post(action_url(ticket, "assign"), {"assignee": handler.pk})
        ticket.refresh_from_db()
        assert ticket.assigned_to == handler
        client.post(action_url(ticket, "assign"), {"assignee": ""})
        ticket.refresh_from_db()
        assert ticket.assigned_to is None

    def test_empty_reply_is_refused(self, client):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        client.post(action_url(ticket, "reply"), {"body": ""})
        assert ticket.messages.count() == 1


class TestList:
    def test_filters_and_search(self, client):
        mine = make_ticket(priority=TicketPriority.HIGH)
        other = make_ticket(status=TicketStatus.RESOLVED)
        user = login_as(client, roles.SUPPORT)
        SupportTicket.objects.filter(pk=mine.pk).update(assigned_to=user)
        url = reverse("ops:support-tickets")
        body = client.get(url, {"assigned": "me"}, HTTP_HX_REQUEST="true").content.decode()
        assert mine.number in body
        assert other.number not in body
        body = client.get(url, {"status": "RESOLVED"}, HTTP_HX_REQUEST="true").content.decode()
        assert other.number in body
        assert mine.number not in body

    def test_query_count_does_not_grow(self, client, django_assert_max_num_queries):
        for _ in range(3):
            make_ticket()
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-tickets")
        from django.db import connection
        from django.test.utils import CaptureQueriesContext

        with CaptureQueriesContext(connection) as few:
            client.get(url, HTTP_HX_REQUEST="true")
        for _ in range(12):
            make_ticket()
        with CaptureQueriesContext(connection) as many:
            client.get(url, HTTP_HX_REQUEST="true")
        assert len(many) == len(few)

    def test_full_phone_for_support(self, client):
        ticket = make_ticket(user=UserFactory(name="Asha Verma", phone="+919811122233"))
        login_as(client, roles.SUPPORT)
        body = client.get(reverse("ops:support-ticket", args=[ticket.pk])).content.decode()
        assert "+919811122233" in body


def test_ratings_admin_is_registered():
    from django.contrib import admin

    from apps.ops_console import ratings_admin
    from apps.orders.models import Rating

    assert admin.site.is_registered(Rating)
    assert ratings_admin.register() is False  # idempotent
