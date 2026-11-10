"""P7 reports (05 §4) and dashboard order section (05 §1.1) on the backend's reports and
dashboard services: role matrix (05 §3 "Reports"), store scoping, CSV errors, column headings
(sales summary refund columns), HTMX partials. More report/export/dashboard cases are in
test_p7_bound.py."""

import csv
import io
from decimal import Decimal

import pytest
from django.urls import reverse
from freezegun import freeze_time

from apps.accounts import roles
from apps.ops_console import capabilities
from apps.ops_console.report_views import column_title
from apps.ops_console.tests.helpers import (
    PRINCIPALS,
    STAFF_PRINCIPALS,
    login_with_stores,
)
from apps.ops_console.tests.orders_support import make_order
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod
from apps.orders.models import Order
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

NOON_IST = "2026-11-03T06:30:00Z"
TODAY = "2026-11-03"

REPORT_ROLES = frozenset(
    {roles.SUPER_ADMIN, "superuser flag", roles.OPS, roles.STORE_MANAGER, roles.FINANCE}
)


def priced(store, status, total: str, **kwargs):
    """An order whose bill snapshot is consistent (the model's formula constraints)."""
    amount = Decimal(total)
    return make_order(
        store,
        status,
        mrp_total=amount + Decimal("50.00"),
        item_total=amount,
        product_discount=Decimal("50.00"),
        grand_total=amount,
        **kwargs,
    )


@pytest.fixture
def stores():
    """Store A: one delivered, one placed and one cancelled (refunded) order; store B: one."""
    with freeze_time(NOON_IST):
        a = DarkStoreFactory(code="AAA-01")
        b = DarkStoreFactory(code="BBB-01")
        priced(a, OrderStatus.DELIVERED, "300.00")
        priced(a, OrderStatus.PLACED, "199.50")
        cancelled = priced(
            a,
            OrderStatus.CANCELLED,
            "1000.00",
            cancelled_by_type=ActorType.CUSTOMER,
            cancel_reason="CHANGED_MIND",
        )
        Order.objects.filter(pk=cancelled.pk).update(
            amount_paid=Decimal("1000.00"), amount_refunded=Decimal("1000.00")
        )
        priced(b, OrderStatus.DELIVERED, "777.00")
    return a, b


def parse_csv(response) -> list[list[str]]:
    return list(csv.reader(io.StringIO(response.content.decode("utf-8-sig"))))


def sales(client, **params):
    return client.get(
        reverse("ops:report", args=["sales_summary"]),
        {"date_from": TODAY, "date_to": TODAY, **params},
    )


@freeze_time(NOON_IST)
class TestSalesSummary:
    def test_csv_is_scoped_with_refund_columns(self, client, stores):
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        response = sales(client, export="csv")
        assert response.status_code == 200
        assert response["Content-Type"].startswith("text/csv")
        rows = parse_csv(response)
        header = rows[0]
        assert header[-3:] == ["unavailable_refunds", "cancelled_refunds", "uncollected_cod"]
        assert len(rows) == 2  # header + store A only
        row = dict(zip(header, rows[1], strict=True))
        assert row["store"] == "AAA-01"
        assert row["gmv"] == "499.50"  # cancelled order excluded
        assert row["cancelled_refunds"] == "1000.00"  # shown apart, not in net
        assert row["refunded"] == "0.00"
        assert row["uncollected_cod"] == "0.00"
        assert row["net_revenue"] == "499.50"
        assert "BBB-01" not in response.content.decode()

    def test_uncollected_cod_is_shown_and_deducted_from_net(self, client, stores):
        """DL-65: a failed COD order stays in GMV; the service deducts it from net revenue."""
        priced(
            stores[1],
            OrderStatus.DELIVERY_FAILED,
            "50.00",
            payment_method=PaymentMethod.COD,
            age_minutes=30,
        )
        login_with_stores(client, roles.FINANCE)
        rows = parse_csv(sales(client, export="csv", store=stores[1].pk))
        row = dict(zip(rows[0], rows[1], strict=True))
        assert row["gmv"] == "827.00"
        assert row["uncollected_cod"] == "50.00"
        assert row["net_revenue"] == "777.00"

    def test_page_shows_the_refund_columns_and_notes(self, client, stores):
        login_with_stores(client, roles.FINANCE)
        response = client.get(
            reverse("ops:report", args=["sales_summary"]),
            {"date_from": TODAY, "date_to": TODAY, "store": stores[0].pk},
            HTTP_HX_REQUEST="true",
        )
        assert response.status_code == 200
        body = response.content.decode()
        assert "<html" not in body
        assert 'id="report-region"' in body
        assert "Unavailable refunds (not in net)" in body
        assert "Cancelled refunds (not in net)" in body
        assert "Uncollected COD" in body
        assert "Uncollected COD (not in net)" not in body  # DL-65: deducted from net
        assert 'data-testid="report-column-notes"' in body
        assert "1000.00" in body
        titles = [column["title"] for column in response.context["table"]["columns"]]
        assert titles[:3] == ["Day", "Store", "Orders"]
        assert "GMV" in titles
        assert "AOV" in titles

    def test_global_role_sees_all_stores_and_filters(self, client, stores):
        login_with_stores(client, roles.FINANCE)
        codes = {row[1] for row in parse_csv(sales(client, export="csv"))[1:]}
        assert codes == {"AAA-01", "BBB-01"}
        response = sales(client, export="csv", store=stores[1].pk)
        assert {row[1] for row in parse_csv(response)[1:]} == {"BBB-01"}

    def test_other_store_filter_is_a_form_error(self, client, stores):
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        response = sales(client, store=stores[1].pk)
        assert response.status_code == 200
        assert response.context["table"] is None
        assert b"BBB-01" not in response.content

    @pytest.mark.parametrize(
        "params",
        [
            {"date_from": "2026-11-03", "date_to": "2026-11-01"},
            {"date_from": "2025-01-01", "date_to": "2026-11-03"},
            {"date_from": "2026-11-03", "date_to": "2026-11-04"},
            {"date_from": "bad", "date_to": "2026-11-03"},
        ],
    )
    def test_invalid_ranges(self, client, stores, params):
        login_with_stores(client, roles.OPS)
        url = reverse("ops:report", args=["sales_summary"])
        page = client.get(url, params)
        assert page.status_code == 200
        assert page.context["table"] is None
        download = client.get(url, {**params, "export": "csv"})
        assert download.status_code == 400
        assert "text/csv" not in download["Content-Type"]
        assert download.context["filter_error"]

    def test_row_cap_csv_is_400_with_the_message(self, client, stores, settings):
        settings.REPORT_SYNC_MAX_ROWS = 1
        login_with_stores(client, roles.OPS)
        page = sales(client)
        assert page.context["too_many"] is True
        response = sales(client, export="csv")
        assert response.status_code == 400
        assert "text/csv" not in response["Content-Type"]
        assert "request an export" in response.context["filter_error"]
        assert "request an export" in response.content.decode()

    @pytest.mark.parametrize("principal", sorted(STAFF_PRINCIPALS))
    def test_csv_refused_for_other_roles(self, client, principal, stores):
        login_with_stores(client, principal, stores[0])
        response = sales(client, export="csv")
        assert response.status_code == (200 if principal in REPORT_ROLES else 403)
        if response.status_code == 403:
            assert b"AAA-01" not in response.content


def test_column_titles():
    assert column_title("net_revenue") == "Net revenue"
    assert column_title("gmv") == "GMV"
    assert column_title("hsn_code") == "HSN code"
    assert column_title("cancelled_refunds") == "Cancelled refunds (not in net)"
    assert column_title("uncollected_cod") == "Uncollected COD"


@freeze_time(NOON_IST)
class TestDashboardOrders:
    @pytest.mark.parametrize("principal", PRINCIPALS)
    def test_section_per_role(self, client, principal, stores):
        login_with_stores(client, principal, stores[0])
        response = client.get(reverse("ops:dashboard"))
        if principal not in STAFF_PRINCIPALS:
            assert response.status_code == 302
            return
        assert response.status_code == 200
        assert ("orders_section" in response.context) is (principal in REPORT_ROLES)
        partial = client.get(reverse("ops:dashboard-orders"), HTTP_HX_REQUEST="true")
        assert partial.status_code == (200 if principal in REPORT_ROLES else 403)

    def test_kpis_scoped_to_store_manager(self, client, stores):
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        kpis = client.get(reverse("ops:dashboard")).context["orders_section"]["kpis"]
        assert kpis["orders"] == 3
        assert kpis["gmv"] == "499.50"
        assert kpis["delivered"] == 1
        assert kpis["cancelled"] == 1

    def test_other_store_filter_is_an_error(self, client, stores):
        login_with_stores(client, roles.STORE_MANAGER, stores[0])
        response = client.get(
            reverse("ops:dashboard-orders"), {"store": stores[1].pk}, HTTP_HX_REQUEST="true"
        )
        assert response.status_code == 200
        assert response.context["orders_section"].get("order_errors")
        assert "kpis" not in response.context["orders_section"]

    def test_global_store_filter_and_alerts(self, client, stores):
        make_order(stores[1], OrderStatus.PLACED, age_minutes=60)
        login_with_stores(client, roles.OPS)
        response = client.get(
            reverse("ops:dashboard-orders"), {"store": stores[1].pk}, HTTP_HX_REQUEST="true"
        )
        section = response.context["orders_section"]
        assert section["kpis"]["orders"] == 2
        alerts = {alert["key"]: alert["count"] for alert in section["alert_rows"]}
        assert alerts["acceptance"] == 1
        assert 'data-alert="acceptance"' in response.content.decode()

    def test_future_day_refused(self, client, stores):
        login_with_stores(client, roles.OPS)
        response = client.get(
            reverse("ops:dashboard-orders"), {"day": "2026-11-04"}, HTTP_HX_REQUEST="true"
        )
        assert response.context["orders_section"].get("order_errors")

    def test_query_count_is_bounded(self, client, stores, django_assert_max_num_queries):
        for _ in range(10):
            make_order(stores[0], OrderStatus.DELIVERED, lines=3)
        login_with_stores(client, roles.OPS)
        with django_assert_max_num_queries(31):  # 30 + the low-ratings alert's items query
            client.get(reverse("ops:dashboard-orders"), HTTP_HX_REQUEST="true")

    def test_capability_rows(self):
        assert capabilities.DEDICATED[capabilities.REPORTS] == (("reports.view_reports",),)
        assert capabilities.SUPPORT_TICKETS in capabilities.DEDICATED
