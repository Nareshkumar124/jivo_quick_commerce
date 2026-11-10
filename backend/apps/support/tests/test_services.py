"""T-711 (P7 lookahead): staff ticket services for the admin / Ops Console (05 §3 "Support
tickets": Super Admin, Ops, Support), the status table, the DB constraints and the seed."""

import io

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, transaction

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.core.exceptions import ApiError
from apps.core.models import AuditLog
from apps.support import services
from apps.support.choices import TicketStatus
from apps.support.models import SupportTicket, TicketMessage
from apps.support.seed import seed_tickets

S = TicketStatus


@pytest.fixture
def make_staff(db):
    def make(role):
        user = StaffUserFactory()
        user.groups.add(Group.objects.get(name=role))
        return user

    return make


@pytest.fixture
def agent(make_staff):
    return make_staff(roles.SUPPORT)


@pytest.fixture
def ticket(user):
    return services.create_ticket(user, category="OTHER", message="I need help with this.")


@pytest.mark.django_db
class TestPermissions:
    @pytest.mark.parametrize(
        ("role", "allowed"),
        [
            (roles.SUPPORT, True),
            (roles.OPS, True),
            (roles.SUPER_ADMIN, True),
            (roles.STORE_MANAGER, False),
            (roles.STORE_STAFF, False),
            (roles.CATALOG_MANAGER, False),
            (roles.FINANCE, False),
        ],
    )
    def test_role_matrix(self, make_staff, ticket, role, allowed):
        """05 §3 "Support tickets" row."""
        staff = make_staff(role)
        assert services.can_handle_tickets(staff) is allowed
        assert services.staff_tickets(staff).filter(pk=ticket.pk).exists() is allowed
        if allowed:
            services.staff_reply(staff, ticket.pk, "Looking into it.")
        else:
            with pytest.raises(PermissionDenied):
                services.staff_reply(staff, ticket.pk, "Looking into it.")
            with pytest.raises(PermissionDenied):
                services.change_status(staff, ticket.pk, S.CLOSED)
            with pytest.raises(PermissionDenied):
                services.assign(staff, ticket.pk, None)
            with pytest.raises(PermissionDenied):
                services.set_priority(staff, ticket.pk, "HIGH")

    @pytest.mark.parametrize(
        "who", [roles.STORE_MANAGER, roles.FINANCE, roles.CATALOG_MANAGER, "rider", "customer"]
    )
    def test_staff_actions_denied(self, make_staff, ticket, agent, who):
        """Review fix 2: staff_reply, change_status and assign refuse everyone outside the
        Support tickets row, including a rider (non-staff app user) and a customer; nothing
        changes."""
        actor = UserFactory() if who in ("rider", "customer") else make_staff(who)
        for call in (
            lambda: services.staff_reply(actor, ticket.pk, "Looking into it."),
            lambda: services.change_status(actor, ticket.pk, S.CLOSED),
            lambda: services.assign(actor, ticket.pk, agent),
            lambda: services.set_priority(actor, ticket.pk, "HIGH"),
        ):
            with pytest.raises(PermissionDenied):
                call()
        ticket.refresh_from_db()
        assert ticket.status == S.OPEN
        assert ticket.assigned_to is None
        assert ticket.messages.count() == 1
        assert not AuditLog.objects.filter(action__startswith="support.").exists()

    def test_customer_owning_the_ticket_is_still_not_staff(self, user, ticket):
        with pytest.raises(PermissionDenied):
            services.change_status(user, ticket.pk, S.RESOLVED)

    def test_superuser(self, ticket):
        assert services.can_handle_tickets(SuperUserFactory())

    def test_customer_and_inactive_staff(self, user, agent, ticket):
        assert not services.can_handle_tickets(user)
        assert not services.can_handle_tickets(None)
        agent.is_active = False
        agent.save()
        with pytest.raises(PermissionDenied):
            services.change_status(agent, ticket.pk, S.CLOSED)

    def test_support_manages_faqs_not_pages(self, agent):
        assert agent.has_perm("cms.change_faq")
        assert not agent.has_perm("cms.change_page")


@pytest.mark.django_db
class TestStaffActions:
    def test_reply_moves_open_to_in_progress(self, agent, ticket, user):
        message = services.staff_reply(agent, ticket.pk, "  We are on it.  ")
        assert message.is_staff
        assert message.sender == agent
        assert message.body == "We are on it."
        ticket.refresh_from_db()
        assert ticket.status == S.IN_PROGRESS
        entry = AuditLog.objects.get(action="support.reply")
        assert entry.changes == {
            "message_id": message.pk,
            "length": len("We are on it."),
            "from": "OPEN",
            "to": "IN_PROGRESS",
        }

    def test_reply_and_resolve(self, agent, ticket):
        services.staff_reply(agent, ticket.pk, "Refund started.", status=S.RESOLVED)
        ticket.refresh_from_db()
        assert ticket.status == S.RESOLVED
        assert ticket.resolved_at is not None

    def test_reply_on_resolved_keeps_status(self, agent, ticket):
        services.change_status(agent, ticket.pk, S.RESOLVED)
        services.staff_reply(agent, ticket.pk, "One more thing.")
        ticket.refresh_from_db()
        assert ticket.status == S.RESOLVED

    def test_reply_on_closed_refused(self, agent, ticket):
        services.change_status(agent, ticket.pk, S.CLOSED)
        with pytest.raises(ApiError) as exc:
            services.staff_reply(agent, ticket.pk, "Hello")
        assert exc.value.error_code == "INVALID_STATE_TRANSITION"

    @pytest.mark.parametrize("body", ["", "   ", "x" * 2001])
    def test_reply_body(self, agent, ticket, body):
        with pytest.raises(ValidationError):
            services.staff_reply(agent, ticket.pk, body)

    def test_unknown_ticket(self, agent):
        with pytest.raises(ValidationError):
            services.change_status(agent, 999999, S.CLOSED)

    @pytest.mark.parametrize(
        ("start", "to"),
        [
            (start, to)
            for start, targets in services.STAFF_TRANSITIONS.items()
            for to in sorted(targets)
        ],
    )
    def test_every_allowed_transition(self, agent, ticket, start, to):
        SupportTicket.objects.filter(pk=ticket.pk).update(status=start)
        result = services.change_status(agent, ticket.pk, to)
        assert result.status == to
        if to == S.CLOSED:
            assert result.closed_at is not None
        if to in (S.OPEN, S.IN_PROGRESS):
            assert result.resolved_at is None
        entry = AuditLog.objects.get(action="support.status")
        assert entry.changes == {"from": start, "to": to}

    @pytest.mark.parametrize(
        ("start", "to"),
        [
            (S.CLOSED, S.OPEN),
            (S.CLOSED, S.IN_PROGRESS),
            (S.CLOSED, S.RESOLVED),
            (S.OPEN, S.OPEN),
            (S.RESOLVED, S.RESOLVED),
        ],
    )
    def test_disallowed_transitions(self, agent, ticket, start, to):
        SupportTicket.objects.filter(pk=ticket.pk).update(status=start)
        with pytest.raises(ApiError) as exc:
            services.change_status(agent, ticket.pk, to)
        assert exc.value.error_code == "INVALID_STATE_TRANSITION"
        assert exc.value.details == {"status": start, "to": to}

    def test_unknown_status(self, agent, ticket):
        with pytest.raises(ValidationError):
            services.change_status(agent, ticket.pk, "DONE")

    def test_assign_and_unassign(self, agent, make_staff, ticket):
        ops = make_staff(roles.OPS)
        services.assign(agent, ticket.pk, ops)
        ticket.refresh_from_db()
        assert ticket.assigned_to == ops
        services.assign(agent, ticket.pk, None)
        ticket.refresh_from_db()
        assert ticket.assigned_to is None
        assert list(
            AuditLog.objects.filter(action="support.assign")
            .order_by("id")
            .values_list("changes", flat=True)
        ) == [{"from": None, "to": ops.pk}, {"from": ops.pk, "to": None}]

    def test_assign_needs_a_ticket_handler(self, agent, make_staff, ticket, user):
        for who in (user, make_staff(roles.FINANCE)):
            with pytest.raises(ValidationError):
                services.assign(agent, ticket.pk, who)

    def test_assign_closed_refused(self, agent, ticket):
        services.change_status(agent, ticket.pk, S.CLOSED)
        with pytest.raises(ApiError):
            services.assign(agent, ticket.pk, agent)

    def test_priority(self, agent, ticket):
        services.set_priority(agent, ticket.pk, "URGENT")
        ticket.refresh_from_db()
        assert ticket.priority == "URGENT"
        with pytest.raises(ValidationError):
            services.set_priority(agent, ticket.pk, "MEGA")

    def test_audit_never_holds_message_text(self, agent, ticket):
        services.staff_reply(agent, ticket.pk, "Private words for the customer")
        for changes in AuditLog.objects.values_list("changes", flat=True):
            assert "Private words" not in str(changes)


@pytest.mark.django_db
class TestModel:
    def test_order_category_needs_order_in_db(self, user):
        from django.utils import timezone

        with pytest.raises(IntegrityError), transaction.atomic():
            SupportTicket.objects.create(
                user=user, category="MISSING_ITEMS", subject="x", last_activity_at=timezone.now()
            )

    def test_empty_message_refused_in_db(self, ticket):
        with pytest.raises(IntegrityError), transaction.atomic():
            TicketMessage.objects.create(ticket=ticket, is_staff=False, body="")

    def test_number_and_str(self, ticket):
        assert str(ticket) == ticket.number == f"TK-{ticket.pk:06d}"
        assert SupportTicket().number == "TK-new"
        assert str(ticket.messages.first()).startswith(ticket.number)


@pytest.mark.django_db
def test_seed_ticket_idempotent():
    from apps.accounts.seed import TEST_CUSTOMER_PHONE

    seed_tickets(io.StringIO(), {})  # no customer yet: skipped
    assert not SupportTicket.objects.exists()
    UserFactory(phone=TEST_CUSTOMER_PHONE)
    seed_tickets(io.StringIO(), {})
    seed_tickets(io.StringIO(), {})
    ticket = SupportTicket.objects.get()
    assert ticket.status == S.RESOLVED
    assert ticket.messages.count() == 2
