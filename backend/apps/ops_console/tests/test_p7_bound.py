"""P7 screens on the backend's services (backend/phase-7): reports + exports, dashboard,
ratings admin, support SLA / canned replies / attachments, P7 model admins.

Test cases (qa/docs/02-test-case-repository.md): P7-TC-08 (staff ratings: roles and store
scope), P7-TC-15 (ticket photos: signed URL, another ticket's key), P7-TC-21 (report role
matrix, unknown key), P7-TC-22 ("own store" scope), P7-TC-23 (money as the service's strings),
P7-TC-24 (CSV formula escaping), P7-TC-27 (async export, own downloads only), P7-TC-31 /
P7-TC-32 (dashboard KPIs and scope), P7-TC-36 (SLA breached queue), P7-TC-40 (the P7 screens in
the console and admin)."""

import csv
import io
import re
from decimal import Decimal

import pytest
from django.test import Client
from django.urls import reverse
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.core.models import AuditLog
from apps.ops_console.tests.helpers import (
    PRINCIPALS,
    SUPERUSER,
    expected_status,
    login_as,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.test_p7_reports import NOON_IST, TODAY, priced
from apps.orders.choices import OrderStatus
from apps.orders.models import OrderItem
from apps.stores.tests.factories import DarkStoreFactory
from apps.support.choices import TicketCategory, TicketStatus
from apps.support.models import SupportTicket, TicketAttachment, TicketMessage

pytestmark = pytest.mark.django_db

_SA = {roles.SUPER_ADMIN, SUPERUSER}
REPORT_ROLES = frozenset({*_SA, roles.OPS, roles.STORE_MANAGER, roles.FINANCE})
CATALOG_REPORT_ROLES = REPORT_ROLES | {roles.CATALOG_MANAGER}
FINANCE_REPORT_ROLES = frozenset({*_SA, roles.FINANCE})
RATING_ROLES = frozenset({*_SA, roles.OPS, roles.SUPPORT, roles.STORE_MANAGER})
CSRF_FIELD = re.compile(r'name="csrfmiddlewaretoken" value="([^"]+)"')


@pytest.fixture
def stores():
    with freeze_time(NOON_IST):
        a = DarkStoreFactory(code="AAA-01")
        b = DarkStoreFactory(code="BBB-01")
        now = timezone.now()
        priced(a, OrderStatus.DELIVERED, "300.00", delivered_at=now)
        priced(a, OrderStatus.PLACED, "199.50")
        priced(b, OrderStatus.DELIVERED, "777.00", delivered_at=now)
    return a, b


def parse_csv(response) -> list[list[str]]:
    return list(csv.reader(io.StringIO(response.content.decode("utf-8-sig"))))


# --------------------------------------------------------------------------- reports


@freeze_time(NOON_IST)
class TestReports:
    @pytest.mark.parametrize("principal", PRINCIPALS)
    @pytest.mark.parametrize(
        ("key", "allowed"),
        [
            ("sales_summary", REPORT_ROLES),
            ("product_sales", CATALOG_REPORT_ROLES),
            ("gst_invoices", FINANCE_REPORT_ROLES),
        ],
    )
    def test_role_matrix(self, client, principal, key, allowed, stores):
        """P7-TC-21: one report of each permission (sales, catalog, finance) per role."""
        login_with_stores(client, principal, stores[0])
        response = client.get(reverse("ops:report", args=[key]))
        assert response.status_code == expected_status(principal, allowed)

    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_index(self, client, principal, stores):
        """P7-TC-21: the reports index for roles with at least one report."""
        login_with_stores(client, principal, stores[0])
        response = client.get(reverse("ops:reports"))
        assert response.status_code == expected_status(principal, CATALOG_REPORT_ROLES)

    def test_unknown_report_is_404(self, client):
        """P7-TC-21: an unknown report key."""
        login_as(client, SUPERUSER)
        assert client.get(reverse("ops:report", args=["nope"])).status_code == 404

    def test_csv_is_scoped_and_escaped(self, client, stores):
        """P7-TC-22, P7-TC-24: own store only; a formula cell gets an apostrophe."""
        OrderItem.objects.filter(order__store=stores[0]).update(product_name="=cmd()")
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        response = client.get(
            reverse("ops:report", args=["product_sales"]),
            {"date_from": TODAY, "date_to": TODAY, "export": "csv"},
        )
        assert response.status_code == 200
        assert "attachment" in response["Content-Disposition"]
        body = response.content.decode("utf-8-sig")
        assert "'=cmd()" in body
        assert "BBB-01" not in body

    def test_other_store_is_refused(self, client, stores):
        """P7-TC-22: an explicit other store gives no CSV and no data."""
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        response = client.get(
            reverse("ops:report", args=["sales_summary"]),
            {"date_from": TODAY, "date_to": TODAY, "store": stores[1].pk, "export": "csv"},
        )
        assert "text/csv" not in response["Content-Type"]
        assert b"BBB-01" not in response.content

    def test_money_is_the_service_string(self, client, stores):
        """P7-TC-23: money as the service's 2-decimal strings."""
        login_with_stores(client, roles.FINANCE)
        response = client.get(
            reverse("ops:report", args=["sales_summary"]),
            {"date_from": TODAY, "date_to": TODAY, "store": stores[0].pk, "export": "csv"},
        )
        assert "499.50" in response.content.decode("utf-8-sig")

    def test_export_request_and_own_downloads_only(self, client, stores):
        """P7-TC-27: an export is queued; another user's download is a 404."""
        from apps.reports.models import ReportExport

        user = login_with_stores(client, roles.FINANCE)
        response = client.post(
            reverse("ops:report-export", args=["sales_summary"]),
            {"date_from": TODAY, "date_to": TODAY, "store": ""},
        )
        assert response.status_code == 302
        export = ReportExport.objects.get(requested_by=user)
        other = staff_in_role(roles.FINANCE)
        client.force_login(other)
        url = reverse("ops:report-export-download", args=[export.pk])
        assert client.get(url).status_code == 404

    def test_export_refused_for_other_roles(self, client, stores):
        """P7-TC-21, P7-TC-27: a role without the report cannot queue its export."""
        from apps.reports.models import ReportExport

        login_with_stores(client, roles.SUPPORT)
        response = client.post(
            reverse("ops:report-export", args=["sales_summary"]),
            {"date_from": TODAY, "date_to": TODAY},
        )
        assert response.status_code == 403
        assert not ReportExport.objects.exists()

    def test_export_redirect_is_built_from_the_form(self, client, stores):
        """P7-TC-27 (review fix, T-716): the redirect back to the report is built from the
        form's own fields and percent-encoded. A CR/LF in a posted value (or the old hidden
        `query` field) never reaches the Location header, which used to be a 500."""
        login_with_stores(client, roles.FINANCE)
        url = reverse("ops:report-export", args=["sales_summary"])
        report = reverse("ops:report", args=["sales_summary"])
        injected = "x=1\r\nSet-Cookie: owned=1"

        valid = client.post(
            url, {"date_from": TODAY, "date_to": TODAY, "store": stores[0].pk, "query": injected}
        )
        assert valid.status_code == 302
        expected = f"{report}?date_from={TODAY}&date_to={TODAY}&store={stores[0].pk}"
        assert valid["Location"] == expected

        invalid = client.post(url, {"date_from": f"{TODAY}\r\nSet-Cookie: owned=1"})
        assert invalid.status_code == 302
        location = invalid["Location"]
        assert location.startswith(f"{report}?")
        assert "\r" not in location
        assert "\n" not in location
        assert "%0D%0A" in location
        assert "owned" not in invalid.cookies

    def test_export_needs_the_csrf_token(self, stores):
        """P7-TC-27 (review fix, T-716): with CSRF checks on, an export request without the
        token is a 403 from the middleware (not a role refusal) and queues nothing; the same
        POST with the token from the report page is queued."""
        from apps.reports.models import ReportExport

        strict = Client(enforce_csrf_checks=True)
        login_with_stores(strict, roles.FINANCE)
        url = reverse("ops:report-export", args=["sales_summary"])
        data = {"date_from": TODAY, "date_to": TODAY, "store": ""}
        refused = strict.post(url, data)
        assert refused.status_code == 403
        assert "X-Ops-Refused" not in refused
        assert not ReportExport.objects.exists()

        page = strict.get(
            reverse("ops:report", args=["sales_summary"]), {"date_from": TODAY, "date_to": TODAY}
        )
        token = CSRF_FIELD.search(page.content.decode()).group(1)
        queued = strict.post(url, {**data, "csrfmiddlewaretoken": token})
        assert queued.status_code == 302
        assert ReportExport.objects.count() == 1


# --------------------------------------------------------------------------- dashboard


@freeze_time(NOON_IST)
class TestDashboard:
    def test_kpis_from_the_service_scoped(self, client, stores):
        """P7-TC-31, P7-TC-32: KPI cards from the service, own store only."""
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        section = client.get(reverse("ops:dashboard")).context["orders_section"]
        assert section["kpis"]["orders"] == 2
        assert section["kpis"]["gmv"] == "499.50"
        assert Decimal(section["kpis"]["aov"]) == Decimal("249.75")

    def test_alert_links_follow_capabilities(self, client, stores):
        """P7-TC-40: an alert links to a screen only when the role may open it."""
        priced(stores[0], OrderStatus.PLACED, "100.00", age_minutes=60)
        login_with_stores(client, roles.FINANCE)
        section = client.get(reverse("ops:dashboard")).context["orders_section"]
        acceptance = next(a for a in section["alert_rows"] if a["key"] == "acceptance")
        assert acceptance["count"] >= 1
        assert acceptance["href"] == ""  # Finance cannot open the live board
        login_with_stores(client, roles.OPS)
        section = client.get(reverse("ops:dashboard")).context["orders_section"]
        acceptance = next(a for a in section["alert_rows"] if a["key"] == "acceptance")
        assert acceptance["href"].startswith(reverse("ops:live-board"))

    def test_low_rating_alert_scoped_and_linked(self, client, stores):
        """P7-TC-08, P7-TC-40: low ratings of the manager's own store only."""
        with freeze_time(NOON_IST):
            make_rating(stores[0], stars=1)
            make_rating(stores[0], stars=5)
            make_rating(stores[1], stars=1)  # another store: never counted
        with freeze_time(NOON_IST):
            login_with_stores(client, roles.STORE_MANAGER, stores[0])
            section = client.get(reverse("ops:dashboard")).context["orders_section"]
        low = next(a for a in section["alert_rows"] if a["key"] == "low_ratings")
        assert low["count"] == 1
        assert low["href"] == reverse("admin:orders_rating_changelist") + "?low=1"
        assert "BBB-01" not in " ".join(low["items"])

    def test_low_rating_alert_hidden_without_permission(self, client, stores):
        """P7-TC-08: Finance (no `orders.view_rating`) gets no low-ratings alert."""
        with freeze_time(NOON_IST):
            make_rating(stores[0], stars=1)
            login_with_stores(client, roles.FINANCE)
            section = client.get(reverse("ops:dashboard")).context["orders_section"]
        assert all(a["key"] != "low_ratings" for a in section["alert_rows"])

    def test_htmx_partial_refreshes(self, client, stores):
        """P7-TC-40: the order section is an HTMX partial that refreshes itself."""
        with freeze_time(NOON_IST):
            login_with_stores(client, roles.OPS)
            response = client.get(reverse("ops:dashboard-orders"), HTTP_HX_REQUEST="true")
        body = response.content.decode()
        assert response.status_code == 200
        assert "<html" not in body
        assert 'hx-trigger="change, every 60s"' in body


# --------------------------------------------------------------------------- ratings


def make_rating(store, stars=2):
    from apps.orders.choices import RatingTarget
    from apps.orders.models import Rating

    order = priced(store, OrderStatus.DELIVERED, "300.00")
    return Rating.objects.create(
        order=order, user=order.user, target=RatingTarget.ORDER, stars=stars, comment="Cold"
    )


class TestRatingsAdmin:
    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_matrix(self, client, principal):
        """P7-TC-08: SA, Ops, Support and Store Manager see ratings; the rest are refused."""
        store = DarkStoreFactory()
        rating = make_rating(store)
        login_with_stores(client, principal, store)
        expected = expected_status(principal, RATING_ROLES)
        assert client.get(reverse("admin:orders_rating_changelist")).status_code == expected
        response = client.get(reverse("admin:orders_rating_change", args=[rating.pk]))
        assert response.status_code == expected
        if expected == 200:
            assert rating.user.phone not in response.content.decode()

    def test_other_store_is_404_and_read_only(self, client):
        """P7-TC-08: another store's rating is a 404; ratings are read-only."""
        own, other = DarkStoreFactory(), DarkStoreFactory()
        make_rating(own)
        foreign = make_rating(other)
        login_with_stores(client, roles.STORE_MANAGER, own)
        url = reverse("admin:orders_rating_change", args=[foreign.pk])
        assert client.get(url).status_code == 404
        login_as(client, SUPERUSER)
        assert client.post(url, {"stars": 5}).status_code == 403
        foreign.refresh_from_db()
        assert foreign.stars == 2

    def test_low_filter(self, client):
        """P7-TC-40: the ratings list's low-rating filter."""
        store = DarkStoreFactory()
        low, high = make_rating(store, 1), make_rating(store, 5)
        login_as(client, roles.OPS)
        response = client.get(reverse("admin:orders_rating_changelist"), {"low": "1"})
        shown = {row.pk for row in response.context["cl"].result_list}
        assert low.pk in shown
        assert high.pk not in shown


# --------------------------------------------------------------------------- support


def make_ticket(**kwargs):
    customer = UserFactory()
    ticket = SupportTicket.objects.create(
        user=customer,
        category=TicketCategory.OTHER,
        subject="Other",
        status=TicketStatus.OPEN,
        last_activity_at=timezone.now(),
        **kwargs,
    )
    TicketMessage.objects.create(ticket=ticket, sender=customer, is_staff=False, body="Help")
    return ticket


def attach(ticket, key):
    message = ticket.messages.first()
    return TicketAttachment.objects.create(
        key=key,
        ticket=ticket,
        message=message,
        uploaded_by=ticket.user,
        file=f"support/{key}.webp",
        size=10,
    )


class TestSupportP7:
    def test_canned_reply_fills_the_box(self, client):
        """P7-TC-40: a canned reply is filled in and put in the reply box."""
        from apps.support.models import CannedReply

        ticket = make_ticket()
        reply = CannedReply.objects.create(title="Hello", body="Hi about {{ticket_number}}")
        login_as(client, roles.SUPPORT)
        detail = client.get(reverse("ops:support-ticket", args=[ticket.pk]))
        assert 'data-testid="canned-select"' in detail.content.decode()
        response = client.get(
            reverse("ops:support-canned-reply", args=[ticket.pk]),
            {"reply": reply.pk},
            HTTP_HX_REQUEST="true",
        )
        assert response.status_code == 200
        assert f"Hi about {ticket.number}" in response.content.decode()

    @pytest.mark.parametrize("principal", [roles.FINANCE, roles.STORE_MANAGER])
    def test_canned_reply_refused_for_other_roles(self, client, principal):
        """P7-TC-40: canned replies for ticket handlers only."""
        ticket = make_ticket()
        login_as(client, principal)
        url = reverse("ops:support-canned-reply", args=[ticket.pk])
        assert client.get(url, HTTP_HX_REQUEST="true").status_code == 403

    def test_sla_column_and_filter(self, client):
        """P7-TC-36, P7-TC-40: the SLA badge and the breached-queue filter."""
        past = timezone.now() - timezone.timedelta(hours=1)
        late = make_ticket(first_response_due_at=past)
        fine = make_ticket()
        login_as(client, roles.SUPPORT)
        response = client.get(
            reverse("ops:support-tickets"), {"sla": "breached"}, HTTP_HX_REQUEST="true"
        )
        body = response.content.decode()
        assert late.number in body
        assert fine.number not in body
        assert "SLA breached" in body

    def test_unknown_attachment_is_404(self, client):
        """P7-TC-15: an unknown photo key is a 404."""
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-attachment", args=[ticket.pk, "deadbeef"])
        assert client.get(url).status_code == 404

    def test_attachment_opens_signed_url_and_is_audited(self, client):
        """P7-TC-15: a photo opens through a short-lived signed URL; the view is audited."""
        ticket = make_ticket()
        upload = attach(ticket, "a" * 32)
        user = login_as(client, roles.SUPPORT)
        url = reverse("ops:support-attachment", args=[ticket.pk, upload.key])
        response = client.get(url, REMOTE_ADDR="203.0.113.7")
        assert response.status_code == 302
        entry = AuditLog.objects.get(action="support.attachment_view")
        assert entry.actor_id == user.pk
        assert entry.object_id == str(ticket.pk)
        assert entry.ip == "203.0.113.7"
        assert entry.changes["attachment"] == upload.key

    def test_other_tickets_attachment_is_404(self, client):
        """P7-TC-15, IDOR: a valid key of a different ticket than the URL's ticket is a 404
        (and no signed URL, no audit entry)."""
        ticket, other = make_ticket(), make_ticket()
        foreign = attach(other, "b" * 32)
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-attachment", args=[ticket.pk, foreign.key])
        response = client.get(url)
        assert response.status_code == 404
        assert not AuditLog.objects.filter(action="support.attachment_view").exists()

    @pytest.mark.parametrize("principal", [roles.FINANCE, roles.STORE_MANAGER])
    def test_attachment_refused_for_other_roles(self, client, principal):
        """P7-TC-15, P7-TC-40: other roles get a 403 and no audit entry."""
        ticket = make_ticket()
        upload = attach(ticket, "c" * 32)
        login_as(client, principal)
        url = reverse("ops:support-attachment", args=[ticket.pk, upload.key])
        assert client.get(url).status_code == 403
        assert not AuditLog.objects.filter(action="support.attachment_view").exists()

    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_p7_model_admins(self, client, principal):
        """P7-TC-40: canned replies, photo records and report exports: Super Admin only."""
        login_as(client, principal)
        allowed = frozenset(_SA)
        for name in ("support_cannedreply", "support_ticketattachment", "reports_reportexport"):
            response = client.get(reverse(f"admin:{name}_changelist"))
            assert response.status_code == expected_status(principal, allowed), name
