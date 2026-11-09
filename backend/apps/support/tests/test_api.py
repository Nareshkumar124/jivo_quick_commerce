"""T-711 (P7 lookahead): customer support ticket API (06 §2.7; api-requests #36).

No phase-7 plan file exists yet, so tests cite T-711 / #36 instead of P7-TC ids.
"""

import logging
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.orders.tests.factories import OrderFactory
from apps.support.choices import TicketStatus
from apps.support.models import SupportTicket, TicketMessage

TICKETS = "/api/v1/support/tickets/"
MESSAGE = "The oil bottle cap was broken when it arrived."


def detail(ticket_id):
    return f"{TICKETS}{ticket_id}/"


def messages(ticket_id):
    return f"{TICKETS}{ticket_id}/messages/"


@pytest.fixture
def order(user):
    return OrderFactory(user=user)


@pytest.fixture
def other_user(db):
    return UserFactory()


@pytest.fixture
def other_client(other_user, make_auth_client):
    return make_auth_client(other_user)


def create(client, **body):
    body.setdefault("category", "OTHER")
    body.setdefault("message", MESSAGE)
    return client.post(TICKETS, body)


# --------------------------------------------------------------------------- create


@pytest.mark.django_db
class TestCreate:
    def test_without_order(self, auth_client, user):
        """T-711 #36: create returns 201 with the ticket and its first message."""
        response = create(auth_client, category="ACCOUNT", message="  How do I change my number? ")
        assert response.status_code == 201, response.content
        body = response.json()
        ticket = SupportTicket.objects.get(pk=body["id"])
        assert ticket.user == user
        assert ticket.app == "customer"
        assert body["number"] == f"TK-{ticket.pk:06d}"
        assert body["category"] == "ACCOUNT"
        assert body["status"] == "OPEN"
        assert body["order_id"] is None
        assert body["order_number"] is None
        assert body["can_reply"] is True
        assert body["last_message"] == "How do I change my number?"
        assert [m["body"] for m in body["messages"]] == ["How do I change my number?"]
        assert body["messages"][0]["from_support"] is False
        assert body["updated_at"]

    @pytest.mark.parametrize(
        "category", ["MISSING_ITEMS", "DAMAGED_ITEMS", "WRONG_ITEMS", "LATE_DELIVERY"]
    )
    def test_order_categories_need_an_order(self, auth_client, order, category):
        response = create(auth_client, category=category)
        assert response.status_code == 400
        assert response.json()["error"]["details"] == {
            "order_id": ["Choose the order this is about."]
        }
        response = create(auth_client, category=category, order_id=order.pk)
        assert response.status_code == 201
        body = response.json()
        assert body["order_id"] == order.pk
        assert body["order_number"] == order.order_number
        assert SupportTicket.objects.get(pk=body["id"]).subject.endswith(order.order_number)

    def test_optional_order_on_other_categories(self, auth_client, order):
        response = create(auth_client, category="PAYMENT_REFUND", order_id=order.pk)
        assert response.status_code == 201
        assert response.json()["order_id"] == order.pk

    def test_another_users_order_is_refused_as_not_found(self, auth_client, other_user):
        """IDOR: the order of another customer is indistinguishable from a missing one."""
        theirs = OrderFactory(user=other_user)
        for order_id in (theirs.pk, theirs.pk + 100000):
            response = create(auth_client, category="DAMAGED_ITEMS", order_id=order_id)
            assert response.status_code == 400
            assert response.json()["error"]["details"] == {"order_id": ["Order not found."]}
        assert not SupportTicket.objects.exists()

    @pytest.mark.parametrize(
        ("message", "ok"),
        [("x" * 9, False), ("x" * 10, True), ("x" * 1000, True), ("x" * 1001, False)],
    )
    def test_message_length(self, auth_client, message, ok):
        response = create(auth_client, message=message)
        assert response.status_code == (201 if ok else 400)
        if not ok:
            assert "message" in response.json()["error"]["details"]

    def test_short_after_trimming(self, auth_client):
        assert create(auth_client, message="   short    ").status_code == 400

    @pytest.mark.parametrize(
        "body",
        [
            {"category": "BOGUS", "message": MESSAGE},
            {"message": MESSAGE},
            {"category": "OTHER"},
            {"category": "OTHER", "message": MESSAGE, "order_id": "abc"},
        ],
    )
    def test_validation(self, auth_client, body):
        response = auth_client.post(TICKETS, body)
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_unauthenticated(self, api_client, db):
        response = create(api_client)
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "AUTH_REQUIRED"

    def test_rider_session_records_the_app(self, user, make_auth_client):
        client = make_auth_client(user, "rider")
        response = create(client)
        assert response.status_code == 201
        assert SupportTicket.objects.get(pk=response.json()["id"]).app == "rider"

    def test_rate_limited(self, auth_client, monkeypatch):
        """Per-user limit on opening tickets (SUPPORT_TICKETS_CREATE_RATE)."""
        from apps.support.throttling import TicketCreateThrottle

        monkeypatch.setattr(TicketCreateThrottle, "rate", "2/hour", raising=False)
        assert create(auth_client).status_code == 201
        assert create(auth_client).status_code == 201
        response = create(auth_client)
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        # Reading is not limited.
        assert auth_client.get(TICKETS).status_code == 200

    def test_no_pii_in_logs(self, auth_client, user, caplog, django_capture_on_commit_callbacks):
        """09: the body, phone and name never reach the logs."""
        caplog.set_level(logging.DEBUG)
        with django_capture_on_commit_callbacks(execute=True):
            ticket_id = create(auth_client).json()["id"]
            auth_client.post(messages(ticket_id), {"message": "Secret reply text here"})
        text = caplog.text
        assert "support event support.ticket_created" in text
        for secret in (MESSAGE, "Secret reply text here", user.phone, user.name):
            if secret:
                assert secret not in text


# --------------------------------------------------------------------------- list / detail


@pytest.mark.django_db
class TestListAndDetail:
    def test_newest_activity_first_and_scoped(self, auth_client, other_client):
        first = create(auth_client, message="First ticket message").json()["id"]
        second = create(auth_client, message="Second ticket message").json()["id"]
        now = timezone.now()
        SupportTicket.objects.filter(pk=first).update(last_activity_at=now - timedelta(hours=2))
        SupportTicket.objects.filter(pk=second).update(last_activity_at=now - timedelta(hours=1))
        create(other_client, message="Somebody else's ticket")
        assert [t["id"] for t in auth_client.get(TICKETS).json()["results"]] == [second, first]
        # A reply on the older ticket moves it to the top.
        auth_client.post(messages(first), {"message": "Any update?"})
        body = auth_client.get(TICKETS).json()
        assert body["count"] == 2
        assert [t["id"] for t in body["results"]] == [first, second]
        assert body["results"][0]["last_message"] == "Any update?"
        assert "messages" not in body["results"][0]

    def test_preview_is_cut(self, auth_client):
        create(auth_client, message="y" * 600)
        assert len(auth_client.get(TICKETS).json()["results"][0]["last_message"]) == 140

    def test_paged(self, auth_client):
        for n in range(3):
            create(auth_client, message=f"Ticket number {n} message")
        body = auth_client.get(TICKETS, {"page_size": 2}).json()
        assert body["count"] == 3
        assert len(body["results"]) == 2
        assert body["next"]
        assert auth_client.get(TICKETS, {"page": 9}).status_code == 404

    def test_list_query_count(self, auth_client, user, order, django_assert_max_num_queries):
        for _ in range(5):
            create(auth_client, category="DAMAGED_ITEMS", order_id=order.pk)
        with django_assert_max_num_queries(4):  # user, count, page (+ app config if uncached)
            assert len(auth_client.get(TICKETS).json()["results"]) == 5

    def test_detail_messages_oldest_first(self, auth_client, user):
        ticket_id = create(auth_client).json()["id"]
        staff = UserFactory(is_staff=True)
        TicketMessage.objects.create(
            ticket_id=ticket_id, sender=staff, is_staff=True, body="We are on it."
        )
        body = auth_client.get(detail(ticket_id)).json()
        assert [(m["body"], m["from_support"]) for m in body["messages"]] == [
            (MESSAGE, False),
            ("We are on it.", True),
        ]
        assert set(body["messages"][0]) == {
            "id",
            "body",
            "from_support",
            "created_at",
            "attachments",
        }

    def test_detail_query_count(self, auth_client, django_assert_max_num_queries):
        ticket_id = create(auth_client).json()["id"]
        with django_assert_max_num_queries(4):  # user, ticket, messages, attachments (P7)
            auth_client.get(detail(ticket_id))

    def test_idor_detail_is_404(self, auth_client, other_client):
        """IDOR: another user's ticket is 404, like a missing one."""
        ticket_id = create(auth_client).json()["id"]
        for client, ticket in ((other_client, ticket_id), (auth_client, ticket_id + 100000)):
            response = client.get(detail(ticket))
            assert response.status_code == 404
            assert response.json()["error"] == {
                "code": "NOT_FOUND",
                "message": "Ticket not found.",
                "details": {},
            }

    def test_unauthenticated(self, api_client, db):
        assert api_client.get(TICKETS).status_code == 401
        assert api_client.get(detail(1)).status_code == 401


# --------------------------------------------------------------------------- reply


@pytest.mark.django_db
class TestReply:
    def test_reply(self, auth_client):
        ticket_id = create(auth_client).json()["id"]
        response = auth_client.post(messages(ticket_id), {"message": "Thanks"})
        assert response.status_code == 201
        body = response.json()
        assert body["status"] == "OPEN"
        assert [m["body"] for m in body["messages"]][-1] == "Thanks"

    def test_in_progress_stays(self, auth_client):
        ticket_id = create(auth_client).json()["id"]
        SupportTicket.objects.filter(pk=ticket_id).update(status=TicketStatus.IN_PROGRESS)
        response = auth_client.post(messages(ticket_id), {"message": "Any news?"})
        assert response.json()["status"] == "IN_PROGRESS"

    def test_reply_reopens_resolved(self, auth_client):
        """PM default: a customer reply on RESOLVED reopens the ticket."""
        ticket_id = create(auth_client).json()["id"]
        SupportTicket.objects.filter(pk=ticket_id).update(
            status=TicketStatus.RESOLVED, resolved_at=timezone.now()
        )
        response = auth_client.post(messages(ticket_id), {"message": "Still broken."})
        assert response.status_code == 201
        assert response.json()["status"] == "OPEN"
        assert SupportTicket.objects.get(pk=ticket_id).resolved_at is None

    def test_closed_refuses(self, auth_client):
        ticket_id = create(auth_client).json()["id"]
        SupportTicket.objects.filter(pk=ticket_id).update(status=TicketStatus.CLOSED)
        assert auth_client.get(detail(ticket_id)).json()["can_reply"] is False
        response = auth_client.post(messages(ticket_id), {"message": "Hello again"})
        assert response.status_code == 400
        error = response.json()["error"]
        assert error["code"] == "VALIDATION_ERROR"
        assert "ticket" in error["details"]
        assert TicketMessage.objects.filter(ticket_id=ticket_id).count() == 1

    @pytest.mark.parametrize("message", ["", "   ", "z" * 1001])
    def test_length(self, auth_client, message):
        ticket_id = create(auth_client).json()["id"]
        response = auth_client.post(messages(ticket_id), {"message": message})
        assert response.status_code == 400
        assert "message" in response.json()["error"]["details"]

    def test_idor_reply_is_404(self, auth_client, other_client):
        ticket_id = create(auth_client).json()["id"]
        response = other_client.post(messages(ticket_id), {"message": "Not mine"})
        assert response.status_code == 404
        assert TicketMessage.objects.filter(ticket_id=ticket_id).count() == 1

    def test_unauthenticated(self, api_client, db):
        assert api_client.post(messages(1), {"message": "hi"}).status_code == 401


# --------------------------------------------------------------------------- no staff actions


@pytest.mark.django_db
class TestNoStaffActionsThroughTheApi:
    """Review fix 2: the app API exposes no staff action. A customer (or rider) token cannot
    change status, priority, assignee or post as support."""

    @pytest.mark.parametrize("app", ["customer", "rider"])
    def test_write_methods_on_ticket_refused(self, user, make_auth_client, app):
        client = make_auth_client(user, app)
        ticket_id = create(client).json()["id"]
        change = {"status": "CLOSED", "priority": "URGENT", "assigned_to": user.pk}
        for method in ("put", "patch", "delete"):
            assert getattr(client, method)(detail(ticket_id), change).status_code == 405
        assert client.post(detail(ticket_id), change).status_code == 405
        ticket = SupportTicket.objects.get(pk=ticket_id)
        assert ticket.status == TicketStatus.OPEN
        assert ticket.priority == "NORMAL"
        assert ticket.assigned_to is None

    def test_extra_fields_on_reply_and_create_are_ignored(self, auth_client):
        response = create(auth_client, status="RESOLVED", priority="URGENT", from_support=True)
        assert response.status_code == 201
        ticket_id = response.json()["id"]
        response = auth_client.post(
            messages(ticket_id),
            {"message": "Close it please", "status": "CLOSED", "is_staff": True},
        )
        assert response.status_code == 201
        assert response.json()["status"] == "OPEN"
        assert not TicketMessage.objects.filter(ticket_id=ticket_id, is_staff=True).exists()

    def test_admin_and_ops_need_a_staff_session(self, auth_client):
        for path in ("/admin/support/supportticket/", "/ops/"):
            response = auth_client.get(path)
            assert response.status_code in (302, 403, 404)
            if response.status_code == 302:
                assert "login" in response["Location"]
