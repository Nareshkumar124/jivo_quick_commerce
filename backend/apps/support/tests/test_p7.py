"""Phase 7 support: photo attachments (06 §2.7), SLA due times, the reply notification, canned
replies and rider tickets (TASK / PAYOUT / CASH with task_id / payout_id).

Test cases: P7-TC-10 (attachments: upload, claim, signed URLs, limits, IDOR), P7-TC-11 (SLA),
P7-TC-12 (customer notified of a staff reply), P7-TC-13 (canned replies), P7-TC-14 (rider tickets
and their scoping).
"""

import io
from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from freezegun import freeze_time
from PIL import Image

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core.exceptions import ApiError
from apps.delivery.models import DeliveryTask, Payout
from apps.delivery.tests.factories import RiderFactory
from apps.notifications.models import Notification
from apps.orders.tests.factories import OrderFactory
from apps.support import services
from apps.support.choices import TicketPriority, TicketStatus
from apps.support.models import CannedReply, SupportTicket, TicketAttachment
from apps.support.seed import seed_canned_replies

pytestmark = pytest.mark.django_db
TICKETS = "/api/v1/support/tickets/"


def image_file(fmt="JPEG", size=(300, 200), name="photo.jpg") -> SimpleUploadedFile:
    buffer = io.BytesIO()
    Image.new("RGB", size, (200, 30, 30)).save(buffer, fmt)
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/jpeg")


@pytest.fixture
def ticket(user):
    return services.create_ticket(user, category="OTHER", message="I need help with this.")


@pytest.fixture
def agent(db):
    staff = StaffUserFactory()
    staff.groups.add(Group.objects.get(name=roles.SUPPORT))
    return staff


class TestAttachments:
    def test_upload_and_reply(self, auth_client, ticket):
        """P7-TC-10: upload -> key + signed url; a reply claims it; the thread shows it."""
        response = auth_client.post(
            f"{TICKETS}{ticket.pk}/attachments/", {"file": image_file()}, format="multipart"
        )
        assert response.status_code == 201, response.content
        key = response.json()["key"]
        stored = TicketAttachment.objects.get(key=key)
        assert stored.file.name == f"support/{ticket.pk}/{key}.webp"
        reply = auth_client.post(
            f"{TICKETS}{ticket.pk}/messages/",
            {"message": "Photo attached", "attachment_keys": [key]},
            format="json",
        )
        assert reply.status_code == 201, reply.content
        last = reply.json()["messages"][-1]
        assert [a["key"] for a in last["attachments"]] == [key]
        assert last["attachments"][0]["url"]
        assert reply.json()["messages"][0]["attachments"] == []
        # a key is used once
        again = auth_client.post(
            f"{TICKETS}{ticket.pk}/messages/",
            {"message": "Again", "attachment_keys": [key]},
            format="json",
        )
        assert again.status_code == 400
        assert "attachment_keys" in again.json()["error"]["details"]

    def test_rejects_non_images_and_large_files(self, auth_client, ticket, settings):
        url = f"{TICKETS}{ticket.pk}/attachments/"
        text = SimpleUploadedFile("a.jpg", b"not an image", content_type="image/jpeg")
        assert auth_client.post(url, {"file": text}, format="multipart").status_code == 400
        gif = image_file("GIF", name="a.gif")
        response = auth_client.post(url, {"file": gif}, format="multipart")
        assert response.status_code == 400
        settings.SUPPORT_ATTACHMENT_MAX_BYTES = 100
        response = auth_client.post(url, {"file": image_file()}, format="multipart")
        assert response.status_code == 400
        assert "MB" in response.json()["error"]["details"]["file"][0]

    def test_idor_and_closed(self, make_auth_client, auth_client, ticket, agent):
        """P7-TC-10: another user's ticket is 404; a CLOSED ticket refuses uploads; another
        user's key cannot be claimed."""
        url = f"{TICKETS}{ticket.pk}/attachments/"
        other = make_auth_client(UserFactory())
        assert other.post(url, {"file": image_file()}, format="multipart").status_code == 404
        key = auth_client.post(url, {"file": image_file()}, format="multipart").json()["key"]
        mine = services.create_ticket(
            UserFactory(), category="OTHER", message="Another person's ticket."
        )
        with pytest.raises(ApiError):
            services.add_customer_message(mine.user, mine.pk, "x", attachment_keys=[key])
        services.change_status(agent, ticket.pk, TicketStatus.CLOSED)
        assert auth_client.post(url, {"file": image_file()}, format="multipart").status_code == 400

    def test_expired_and_too_many(self, user, ticket):
        with freeze_time(timezone.now() - timedelta(hours=2)):
            old = services.upload_attachment(user, ticket.pk, image_file())
        with pytest.raises(ApiError):
            services.add_customer_message(user, ticket.pk, "late", attachment_keys=[old.key])
        keys = [services.upload_attachment(user, ticket.pk, image_file()).key for _ in range(4)]
        with pytest.raises(ApiError):
            services.add_customer_message(user, ticket.pk, "many", attachment_keys=keys)

    def test_staff_url(self, user, ticket, agent):
        """P7-TC-10: staff opening a customer's photo is audited (ids only, 09 PII)."""
        from apps.core.models import AuditLog

        key = services.upload_attachment(user, ticket.pk, image_file()).key
        assert services.staff_attachment_url(agent, key, ip="10.0.0.9")
        entry = AuditLog.objects.get(action="support.attachment_view")
        assert entry.actor == agent
        assert entry.object_id == str(ticket.pk)
        assert entry.changes == {"attachment": key, "message_id": None}
        with pytest.raises(ValidationError):
            services.staff_attachment_url(agent, "0" * 32)
        with pytest.raises(PermissionDenied):
            services.staff_attachment_url(user, key)
        assert AuditLog.objects.filter(action="support.attachment_view").count() == 1

    def test_purge_unclaimed(self, user, ticket, settings, django_capture_on_commit_callbacks):
        """P7-TC-10: photos never sent with a reply are deleted (row and file) once the claim
        window has passed; claimed and recent ones stay. Wired into beat."""
        from django.core.files.storage import default_storage

        from apps.support.tasks import purge_unclaimed_attachments

        with freeze_time(timezone.now() - timedelta(hours=2)):
            stale = services.upload_attachment(user, ticket.pk, image_file())
            claimed = services.upload_attachment(user, ticket.pk, image_file())
        TicketAttachment.objects.filter(pk=claimed.pk).update(message=ticket.messages.first())
        fresh = services.upload_attachment(user, ticket.pk, image_file())
        stale_name = stale.file.name
        assert default_storage.exists(stale_name)
        with django_capture_on_commit_callbacks(execute=True):
            assert purge_unclaimed_attachments() == 1
        assert not default_storage.exists(stale_name)
        assert set(TicketAttachment.objects.values_list("pk", flat=True)) == {
            claimed.pk,
            fresh.pk,
        }
        assert services.purge_unclaimed_attachments() == 0  # idempotent
        tasks = {entry["task"] for entry in settings.CELERY_BEAT_SCHEDULE.values()}
        assert "support.purge_unclaimed_attachments" in tasks

    def test_purge_tolerates_a_missing_file(self, user, ticket, monkeypatch, caplog):
        from django.core.files.storage import default_storage

        def broken(name):
            raise OSError("gone")

        monkeypatch.setattr(default_storage, "delete", broken)
        services._delete_file("support/1/x.webp")
        assert "could not delete" in caplog.text

    def test_attachment_cap_covers_the_limit(self, settings):
        """Django's DATA_UPLOAD_MAX_MEMORY_SIZE does not count multipart file data, so the
        5 MB photo limit is enforced by `upload_attachment` itself (above)."""
        assert settings.SUPPORT_ATTACHMENT_MAX_BYTES == 5 * 1024 * 1024


class TestSla:
    def test_due_times_and_breach(self, user, agent, settings):
        """P7-TC-11: due times per priority; late first response and resolution."""
        start = timezone.now() - timedelta(hours=30)
        with freeze_time(start):
            ticket = services.create_ticket(user, category="OTHER", message="Need help please.")
        assert ticket.first_response_due_at == start + timedelta(minutes=60)
        assert ticket.resolution_due_at == start + timedelta(hours=24)
        state = services.sla_state(ticket)
        assert state["first_response_breached"] is True
        assert state["resolution_breached"] is True
        assert list(services.breached_tickets(agent)) == [ticket]
        assert services.with_sla(SupportTicket.objects.filter(pk=ticket.pk)).get().sla_breached
        services.set_priority(agent, ticket.pk, TicketPriority.LOW)
        ticket.refresh_from_db()
        assert ticket.resolution_due_at == start + timedelta(hours=72)
        services.staff_reply(agent, ticket.pk, "Looking into it.")
        ticket.refresh_from_db()
        assert ticket.first_response_at is not None
        assert services.sla_state(ticket)["first_response_breached"] is True  # replied late
        assert list(services.breached_tickets(UserFactory())) == []

    def test_on_time(self, user, agent):
        ticket = services.create_ticket(user, category="OTHER", message="Need help please.")
        services.staff_reply(agent, ticket.pk, "Done.", status=TicketStatus.RESOLVED)
        ticket.refresh_from_db()
        state = services.sla_state(ticket)
        assert state["first_response_breached"] is False
        assert state["resolution_breached"] is False
        assert not services.with_sla(SupportTicket.objects.filter(pk=ticket.pk)).get().sla_breached


class TestReplyNotification:
    def test_customer_notified_once(self, user, agent, ticket, django_capture_on_commit_callbacks):
        """P7-TC-12: push + inbox `support.ticket_replied` with the ticket link, no SMS, never
        the reply text."""
        with django_capture_on_commit_callbacks(execute=True):
            message = services.staff_reply(agent, ticket.pk, "Your refund is on its way.")
        note = Notification.objects.get(user=user, event="support.ticket_replied")
        assert note.data["link"] == f"jivo://support/tickets/{ticket.pk}"
        assert note.data["type"] == "ticket"
        assert note.data["ticket_id"] == str(ticket.pk)
        assert note.category == "support"
        assert "refund" not in note.body
        assert note.sms_status == "NONE"
        from apps.support.notifications import notify_staff_reply

        notify_staff_reply(ticket.pk, message.pk)  # idempotent
        assert Notification.objects.filter(user=user, event="support.ticket_replied").count() == 1

    def test_rider_ticket_uses_rider_event(self, agent, django_capture_on_commit_callbacks):
        rider_user = UserFactory()
        ticket = services.create_ticket(
            rider_user, category="CASH", message="Deposit not shown yet.", app="rider"
        )
        with django_capture_on_commit_callbacks(execute=True):
            services.staff_reply(agent, ticket.pk, "Fixed.")
        note = Notification.objects.get(user=rider_user)
        assert note.event == "support.ticket_replied_rider"
        assert note.app == "rider"
        assert note.data["link"] == f"jivo://rider/help/tickets/{ticket.pk}"


class TestCannedReplies:
    def test_list_and_render(self, agent, user):
        """P7-TC-13."""
        seed_canned_replies(io.StringIO(), {})
        seed_canned_replies(io.StringIO(), {})  # idempotent
        assert CannedReply.objects.count() == 3
        order = OrderFactory(user=user)
        ticket = services.create_ticket(
            user, category="DAMAGED_ITEMS", message="Broken bottle cap.", order_id=order.pk
        )
        titles = [r.title for r in services.canned_replies(agent, "DAMAGED_ITEMS")]
        assert "Sorry about damaged items" in titles
        assert "Refund started" not in titles
        assert len(services.canned_replies(agent)) == 3
        reply = CannedReply.objects.get(title="Sorry about damaged items")
        text = services.render_canned_reply(agent, reply.pk, ticket.pk)
        assert order.order_number in text
        anything = CannedReply.objects.get(title="Anything else?")
        assert ticket.number in services.render_canned_reply(agent, anything.pk, ticket.pk)
        with pytest.raises(ValidationError):
            services.render_canned_reply(agent, 999999, ticket.pk)
        with pytest.raises(PermissionDenied):
            services.canned_replies(user)


@pytest.fixture
def rider_setup(db):
    rider = RiderFactory()
    order = OrderFactory(store=rider.preferred_store)
    task = DeliveryTask.objects.create(
        order=order,
        store=order.store,
        status="DELIVERED",
        rider=rider,
        search_started_at=timezone.now(),
        distance_km=Decimal("1.00"),
        payout_amount=Decimal("30.00"),
    )
    payout = Payout.objects.create(
        rider=rider,
        period_start=timezone.localdate(),
        period_end=timezone.localdate(),
        amount=Decimal("300.00"),
    )
    return rider, task, payout


class TestRiderTickets:
    def test_rider_ticket_with_task_and_payout(self, make_auth_client, rider_setup):
        """P7-TC-14: TASK ticket from the rider app with the rider's own task and payout."""
        rider, task, payout = rider_setup
        client = make_auth_client(rider.user, "rider")
        response = client.post(
            TICKETS,
            {
                "category": "TASK",
                "message": "The customer's gate was locked.",
                "task_id": task.pk,
                "payout_id": payout.pk,
            },
            format="json",
        )
        assert response.status_code == 201, response.content
        body = response.json()
        assert body["task_id"] == task.pk
        assert body["payout_id"] == payout.pk
        assert body["order_number"] == task.order.order_number
        assert body["order_id"] is None
        listed = client.get(TICKETS).json()["results"][0]
        assert listed["task_id"] == task.pk
        assert listed["order_number"] == task.order.order_number

    def test_rider_categories_need_rider_app(self, auth_client):
        response = auth_client.post(
            TICKETS, {"category": "PAYOUT", "message": "Where is my payout?"}, format="json"
        )
        assert response.status_code == 400
        assert "category" in response.json()["error"]["details"]

    def test_other_riders_records_are_not_found(self, make_auth_client, rider_setup):
        """P7-TC-14: another rider's task / payout is 400 not found."""
        _, task, payout = rider_setup
        other = RiderFactory()
        client = make_auth_client(other.user, "rider")
        for field, value in (("task_id", task.pk), ("payout_id", payout.pk)):
            response = client.post(
                TICKETS,
                {"category": "TASK", "message": "Something went wrong.", field: value},
                format="json",
            )
            assert response.status_code == 400
            assert field in response.json()["error"]["details"]


class TestTicketsPerApp:
    """Code review: one person who uses both apps sees customer tickets in the customer app
    and rider tickets in the rider app; a ticket of the other app is 404 everywhere."""

    def test_lists_and_lookups_are_per_app(self, make_auth_client, rider_setup):
        rider, _, _ = rider_setup
        customer_client = make_auth_client(rider.user, "customer")
        rider_client = make_auth_client(rider.user, "rider")
        as_customer = services.create_ticket(
            rider.user, category="OTHER", message="A customer question.", app="customer"
        )
        as_rider = services.create_ticket(
            rider.user, category="CASH", message="Deposit not shown yet.", app="rider"
        )
        listed = [t["id"] for t in customer_client.get(TICKETS).json()["results"]]
        assert listed == [as_customer.pk]
        listed = [t["id"] for t in rider_client.get(TICKETS).json()["results"]]
        assert listed == [as_rider.pk]
        for client, own, foreign in (
            (customer_client, as_customer, as_rider),
            (rider_client, as_rider, as_customer),
        ):
            assert client.get(f"{TICKETS}{own.pk}/").status_code == 200
            assert client.get(f"{TICKETS}{foreign.pk}/").status_code == 404
            reply = client.post(
                f"{TICKETS}{foreign.pk}/messages/", {"message": "Hello"}, format="json"
            )
            assert reply.status_code == 404
            upload = client.post(
                f"{TICKETS}{foreign.pk}/attachments/", {"file": image_file()}, format="multipart"
            )
            assert upload.status_code == 404
        reply = rider_client.post(f"{TICKETS}{as_rider.pk}/messages/", {"message": "Any news?"})
        assert reply.status_code == 201

    def test_service_defaults_to_the_customer_app(self, user):
        ticket = services.create_ticket(user, category="OTHER", message="Unknown app ticket.")
        assert ticket.app == "customer"
        assert list(services.own_tickets(user)) == [ticket]
        assert list(services.own_tickets(user, "rider")) == []
        assert services.ticket_app("something") == "customer"
