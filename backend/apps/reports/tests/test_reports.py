"""Phase 7 reports (05 §4), the ops dashboard (05 §1.1) and the report jobs (06 §5).

Test cases: P7-TC-20 (sales summary and orders: definitions), P7-TC-21 (product, inventory and
stock movement reports), P7-TC-22 (GST by invoice and HSN), P7-TC-23 (rider earnings, payouts,
COD reconciliation, refunds, cancellations), P7-TC-24 (role matrix and store scope), P7-TC-25
(CSV: formula escaping, row cap; async export with signed download), P7-TC-26 (dashboard KPIs,
charts and alerts, store-scoped), P7-TC-27 (daily summary email).
"""

import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from celery.exceptions import Retry
from django.contrib.auth.models import Group
from django.core import mail
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import Q
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.catalog.tests.factories import VariantFactory
from apps.delivery.models import DeliveryTask, Payout, RiderCashLedger, RiderEarning
from apps.delivery.tests.factories import RiderFactory
from apps.inventory.tests.factories import stock
from apps.orders.choices import OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.invoices import ensure_invoice
from apps.orders.models import OrderItem
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, Refund
from apps.reports import dashboard, services
from apps.reports.models import ExportStatus, ReportExport
from apps.reports.tasks import daily_reports_email
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db
IST = ZoneInfo("Asia/Kolkata")
DAY = date(2026, 11, 1)


def at(hour: int, minute: int = 0, day: date = DAY) -> datetime:
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=IST)


def staff(role, *stores):
    user = StaffUserFactory(email=f"{uuid.uuid4().hex[:12]}@jivo.test")
    user.groups.add(Group.objects.get(name=role))
    for store in stores:
        grant_store_access(user, store)
    return user


def add_line(order, variant, quantity=2, price=Decimal("150.00"), unavailable=0):
    return OrderItem.objects.create(
        order=order,
        variant=variant,
        product=variant.product,
        product_name=variant.product.name,
        variant_name=variant.name,
        sku=variant.sku,
        hsn_code="15099090",
        gst_rate=Decimal("5.00"),
        mrp=Decimal("175.00"),
        selling_price=price,
        quantity=quantity,
        quantity_unavailable=unavailable,
        line_total=price * quantity,
    )


@pytest.fixture
def shop(db):
    """Two stores; at store A on DAY: one delivered order (COD, tip 20), one cancelled, one
    still packing (ONLINE); one delivered order at store B."""
    a, b = DarkStoreFactory(), DarkStoreFactory(state="Delhi")
    variant = VariantFactory()
    delivered = OrderFactory(
        store=a,
        status=OrderStatus.DELIVERED,
        payment_status=PaymentStatus.COD_COLLECTED,
        placed_at=at(10),
        accepted_at=at(10, 1),
        delivered_at=at(10, 20),
        eta_at=at(10, 15),
        tip=Decimal("20.00"),
        grand_total=Decimal("320.00"),
    )
    add_line(delivered, variant)
    cancelled = OrderFactory(
        store=a,
        status=OrderStatus.CANCELLED,
        placed_at=at(11),
        cancelled_at=at(11, 5),
        cancel_reason="CHANGED_MIND",
        cancelled_by_type="customer",
    )
    packing = OrderFactory(
        store=a,
        status=OrderStatus.PACKING,
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PAID,
        placed_at=at(12),
        accepted_at=at(12, 3),
        coupon_code="=HYPERLINK(1)",
    )
    other = OrderFactory(
        store=b,
        status=OrderStatus.DELIVERED,
        payment_status=PaymentStatus.COD_COLLECTED,
        placed_at=at(13),
        delivered_at=at(13, 10),
    )
    add_line(other, variant, quantity=1, price=Decimal("300.00"))
    return {
        "a": a,
        "b": b,
        "variant": variant,
        "delivered": delivered,
        "cancelled": cancelled,
        "packing": packing,
        "other": other,
    }


def run(user, key, **kwargs):
    kwargs.setdefault("start", DAY)
    kwargs.setdefault("end", DAY)
    result = services.run_report(user, key, **kwargs)
    return [dict(zip(result.columns, row, strict=True)) for row in result.rows]


class TestSales:
    def test_sales_summary(self, shop, superuser):
        """P7-TC-20: per day and store; GMV excludes cancelled; net = GMV - refunds - tips."""
        rows = {r["store"]: r for r in run(superuser, "sales_summary")}
        a = rows[shop["a"].code]
        assert a["day"] == DAY.isoformat()
        assert (a["orders"], a["delivered"], a["cancelled"]) == ("3", "1", "1")
        assert a["gmv"] == "620.00"  # 320 delivered + 300 packing
        assert a["tips"] == "20.00"
        assert a["net_revenue"] == "600.00"
        assert a["aov"] == "310.00"
        assert rows[shop["b"].code]["gmv"] == "300.00"

    def test_orders_report(self, shop, superuser):
        rows = run(superuser, "orders")
        assert [r["order_number"] for r in rows] == [
            shop[k].order_number for k in ("delivered", "cancelled", "packing", "other")
        ]
        first = rows[0]
        assert first["placed_at"] == "2026-11-01 10:00"
        assert first["delivery_minutes"] == "20.0"
        assert "phone" not in " ".join(services.REPORTS["orders"].columns)

    def test_cancellations(self, shop, superuser):
        rows = run(superuser, "cancellations")
        assert rows == [
            {
                "store": shop["a"].code,
                "reason": "CHANGED_MIND",
                "cancelled_by": "customer",
                "orders": "1",
                "order_value": "300.00",
            }
        ]


class TestCatalogReports:
    def test_product_sales_and_stock(self, shop, superuser):
        """P7-TC-21."""
        rows = run(superuser, "product_sales", store_id=shop["a"].pk)
        assert rows == [
            {
                "store": shop["a"].code,
                "sku": shop["variant"].sku,
                "product": shop["variant"].product.name,
                "variant": shop["variant"].name,
                "orders": "1",
                "units": "2",
                "revenue": "300.00",
            }
        ]
        stock(shop["a"], shop["variant"], 3, reserved=1)
        snapshot = run(superuser, "inventory_stock", store_id=shop["a"].pk)
        assert snapshot[0]["available"] == "2"
        assert snapshot[0]["low_stock"] == "yes"
        moves = run(
            superuser, "inventory_movements", start=timezone.localdate(), end=timezone.localdate()
        )
        assert [m["type"] for m in moves] == ["INWARD"]
        assert moves[0]["delta"] == "3"


class TestGst:
    def test_invoice_and_hsn(self, shop, superuser):
        """P7-TC-22: tax split matches the invoice; intra-state CGST + SGST, else IGST."""
        invoice = ensure_invoice(shop["delivered"].pk)
        ensure_invoice(shop["other"].pk)
        rows = run(superuser, "gst_invoices")
        mine = [r for r in rows if r["invoice_number"] == invoice.invoice_number]
        assert len(mine) == 1  # one HSN line (no fees on the factory order)
        line = mine[0]
        assert line["hsn_sac"] == "15099090"
        assert line["gst_rate"] == "5.00"
        assert line["taxable_value"] == "285.71"
        assert Decimal(line["cgst"]) + Decimal(line["sgst"]) == Decimal("14.29")
        assert line["igst"] == "0.00"
        assert line["taxable_value"] == f"{invoice.taxable_value}"
        summary = run(superuser, "gst_hsn_summary")
        assert len(summary) == 1
        assert summary[0]["quantity"] == "3"
        assert Decimal(summary[0]["total_value"]) == Decimal("600.00")


class TestFinanceAndCash:
    def test_rider_reports_and_cash(self, shop, superuser):
        """P7-TC-23."""
        rider = RiderFactory(preferred_store=shop["a"])
        rider.home_store = shop["a"]
        rider.save()
        task = DeliveryTask.objects.create(
            order=shop["delivered"],
            store=shop["a"],
            status="DELIVERED",
            rider=rider,
            search_started_at=at(10),
            distance_km=Decimal("2.00"),
            payout_amount=Decimal("40.00"),
        )
        payout = Payout.objects.create(
            rider=rider,
            period_start=DAY,
            period_end=DAY,
            amount=Decimal("30.00"),
            status="PAID",
            reference="UTR1",
            paid_at=at(18),
        )
        for kind, amount, paid in (("BASE", "30.00", payout), ("DISTANCE", "10.00", None)):
            RiderEarning.objects.create(
                rider=rider,
                task=task,
                type=kind,
                amount=Decimal(amount),
                earned_at=at(10, 20),
                payout=paid,
            )
        earnings = run(superuser, "rider_earnings")
        assert earnings[0]["deliveries"] == "1"
        assert (earnings[0]["total"], earnings[0]["paid"], earnings[0]["unpaid"]) == (
            "40.00",
            "30.00",
            "10.00",
        )
        assert run(superuser, "payouts")[0]["reference"] == "UTR1"
        for kind, amount, balance, hour in (
            ("COD_COLLECTED", "300.00", "300.00", 10),
            ("DEPOSIT", "-250.00", "50.00", 18),
        ):
            with freeze_time(at(hour)):
                RiderCashLedger.objects.create(
                    rider=rider,
                    entry_type=kind,
                    amount=Decimal(amount),
                    balance_after=Decimal(balance),
                    store=shop["a"],
                )
        cod = run(superuser, "cod_reconciliation")
        assert (cod[0]["collected"], cod[0]["deposited"], cod[0]["difference"]) == (
            "300.00",
            "250.00",
            "50.00",
        )

    def test_refunds(self, shop, superuser):
        payment = Payment.objects.create(
            order=shop["packing"], gateway="razorpay", amount=Decimal("300.00"), status="CAPTURED"
        )
        refund = Refund.objects.create(
            payment=payment,
            order=shop["packing"],
            amount=Decimal("50.00"),
            reason="items_unavailable",
            idempotency_key="r1",
        )
        rows = run(superuser, "refunds", start=timezone.localdate(), end=timezone.localdate())
        assert rows[0]["refund_id"] == str(refund.pk)
        assert rows[0]["initiated_by"] == "system"


class TestAccess:
    @pytest.mark.parametrize(
        ("role", "expected"),
        [
            (roles.OPS, {"sales_summary", "product_sales", "refunds"}),
            (roles.STORE_MANAGER, {"sales_summary", "inventory_stock", "cod_reconciliation"}),
            (roles.CATALOG_MANAGER, {"product_sales", "inventory_stock", "inventory_movements"}),
            (roles.FINANCE, {"gst_invoices", "payouts", "sales_summary", "product_sales"}),
        ],
    )
    def test_role_matrix(self, db, role, expected):
        """P7-TC-24: 05 §3 Reports row (⚠ PM default split)."""
        keys = {spec.key for spec in services.available_reports(staff(role))}
        assert expected <= keys
        finance_only = {"gst_invoices", "gst_hsn_summary", "rider_earnings", "payouts"}
        if role != roles.FINANCE:
            assert not keys & finance_only
        if role == roles.CATALOG_MANAGER:
            assert "sales_summary" not in keys

    @pytest.mark.parametrize("role", [roles.SUPPORT, roles.STORE_STAFF])
    def test_no_reports(self, db, role):
        user = staff(role)
        assert services.available_reports(user) == []
        with pytest.raises(PermissionDenied):
            services.run_report(user, "sales_summary")
        with pytest.raises(PermissionDenied):
            dashboard.kpis(user)

    def test_store_scope(self, shop):
        """P7-TC-24: a store manager sees only their stores; another store is refused."""
        manager = staff(roles.STORE_MANAGER, shop["a"])
        stores = {r["store"] for r in run(manager, "sales_summary")}
        assert stores == {shop["a"].code}
        with pytest.raises(PermissionDenied):
            run(manager, "sales_summary", store_id=shop["b"].pk)
        assert services.available_reports(UserFactory()) == []

    def test_bad_input(self, superuser, settings):
        with pytest.raises(ValidationError):
            services.run_report(superuser, "nope")
        with pytest.raises(ValidationError):
            services.run_report(superuser, "orders", start=DAY, end=DAY - timedelta(days=1))
        settings.REPORT_MAX_RANGE_DAYS = 3
        with pytest.raises(ValidationError):
            services.run_report(superuser, "orders", start=DAY, end=DAY + timedelta(days=5))
        assert services.run_report(superuser, "orders").rows == []  # today: nothing


class TestCsvAndExports:
    def test_csv_escapes_formulas_and_caps(self, shop, superuser, settings):
        """P7-TC-25: formula cells get an apostrophe; above the cap a CSV is refused."""
        content = services.report_csv(superuser, "orders", start=DAY, end=DAY).decode("utf-8")
        assert content.startswith("﻿order_number,")
        assert "'=HYPERLINK(1)" in content
        settings.REPORT_SYNC_MAX_ROWS = 2
        result = services.run_report(superuser, "orders", start=DAY, end=DAY)
        assert result.truncated
        assert len(result.rows) == 2
        with pytest.raises(ValidationError):
            services.report_csv(superuser, "orders", start=DAY, end=DAY)
        assert services.filename("orders", DAY, DAY) == "orders_2026-11-01_2026-11-01.csv"

    def test_async_export(self, shop, django_capture_on_commit_callbacks):
        """P7-TC-25: queued, built by the task (eager), downloadable by the requester only."""
        finance = staff(roles.FINANCE)
        with django_capture_on_commit_callbacks(execute=True):
            export = services.request_export(finance, "orders", start=DAY, end=DAY)
        export.refresh_from_db()
        assert export.status == ExportStatus.DONE
        assert export.row_count == 4
        assert export.file.name.startswith(f"reports/{finance.pk}/")
        assert services.export_download_url(finance, export.pk)
        assert services.generate_export(export.pk).status == ExportStatus.DONE  # idempotent
        with pytest.raises(ValidationError):
            services.export_download_url(staff(roles.FINANCE), export.pk)
        assert list(services.user_exports(finance)) == [export]
        assert services.user_exports(UserFactory()).count() == 0

    def test_export_refused_when_permission_lost(self, shop):
        ops = staff(roles.OPS)
        export = ReportExport.objects.create(
            report="orders", requested_by=ops, params={"start": "2026-11-01", "end": "2026-11-01"}
        )
        ops.groups.clear()
        ops = type(ops).objects.get(pk=ops.pk)
        result = services.generate_export(export.pk)
        assert result.status == ExportStatus.FAILED

    def test_purge(self, shop, superuser):
        export = services.request_export(superuser, "orders", start=DAY, end=DAY)
        services.generate_export(export.pk)
        assert services.purge_old_exports(timezone.now() + timedelta(days=30)) == 1
        assert not ReportExport.objects.exists()


class TestDashboard:
    def test_kpis(self, shop, superuser):
        """P7-TC-26."""
        stock(shop["a"], shop["variant"], 0)
        k = dashboard.kpis(superuser, store_id=shop["a"].pk, day=DAY, now=at(23))
        assert k["orders"] == 3
        assert k["gmv"] == "620.00"
        assert k["aov"] == "310.00"
        assert k["cancelled_pct"] == 33.3
        assert k["avg_delivery_minutes"] == 20.0
        assert k["avg_acceptance_seconds"] == 120.0
        assert k["sla_breaches"]["late_deliveries"] == 1
        # 60 s SLA: 10:01 is on time (exactly 60 s), 12:03 is late
        assert k["sla_breaches"]["late_acceptances"] == 1
        assert k["active_orders"] == 1
        assert k["stock_outs"] == 1
        empty = dashboard.kpis(superuser, store_id=shop["a"].pk, day=DAY - timedelta(days=3))
        assert empty["orders"] == 0
        assert empty["avg_delivery_minutes"] is None
        assert empty["aov"] == "0.00"

    def test_charts(self, shop, superuser):
        c = dashboard.charts(superuser, day=DAY, trend_days=3)
        assert c["orders_per_hour"][10] == {"hour": 10, "orders": 1}
        assert sum(h["orders"] for h in c["orders_per_hour"]) == 4
        assert [t["day"] for t in c["gmv_trend"]] == [
            DAY - timedelta(days=2),
            DAY - timedelta(days=1),
            DAY,
        ]
        assert c["gmv_trend"][-1]["gmv"] == "920.00"
        assert c["top_products"][0]["units"] == 3
        split = {s["payment_method"]: s for s in c["payment_split"]}
        assert split["ONLINE"]["orders"] == 1
        assert split["COD"]["orders"] == 2

    def test_alerts_and_scope(self, shop):
        now = timezone.now()
        waiting = OrderFactory(store=shop["a"], placed_at=now - timedelta(minutes=5))
        OrderFactory(store=shop["a"], placed_at=now)  # not yet late
        failed = OrderFactory(
            store=shop["a"], status=OrderStatus.DELIVERY_FAILED, delivery_failed_at=now
        )
        DeliveryTask.objects.create(
            order=waiting,
            store=shop["a"],
            status="SEARCHING",
            search_started_at=now - timedelta(minutes=10),
            distance_km=Decimal("1.00"),
            payout_amount=Decimal("30.00"),
        )
        stock(shop["a"], shop["variant"], 2)
        rider = RiderFactory(preferred_store=shop["a"])
        rider.home_store = shop["a"]
        rider.cash_in_hand = Decimal("6000.00")
        rider.save()
        manager = staff(roles.STORE_MANAGER, shop["a"])
        alerts = dashboard.alerts(manager, now=now)
        assert [i["order_id"] for i in alerts["awaiting_acceptance"]["items"]] == [waiting.pk]
        assert alerts["no_rider"]["count"] == 1
        assert alerts["low_stock"]["items"][0]["available"] == 2
        assert alerts["riders_over_cash_limit"]["items"][0]["cash_in_hand"] == "6000.00"
        assert [i["order_id"] for i in alerts["failed_deliveries"]["items"]] == [failed.pk]
        other_manager = staff(roles.STORE_MANAGER, shop["b"])
        assert dashboard.alerts(other_manager, now=now)["awaiting_acceptance"]["count"] == 0
        with pytest.raises(PermissionDenied):
            dashboard.alerts(other_manager, store_id=shop["a"].pk)


class TestDailyEmail:
    def test_sends_store_summary_to_managers(self, shop, settings):
        """P7-TC-27."""
        manager = staff(roles.STORE_MANAGER, shop["a"])
        staff(roles.OPS)  # not a store manager: no mail
        assert daily_reports_email(DAY.isoformat()) == 1
        assert mail.outbox[0].to == [manager.email]
        assert shop["a"].code in mail.outbox[0].body
        assert shop["b"].code not in mail.outbox[0].body
        settings.DAILY_REPORTS_EMAIL_ENABLED = False
        assert daily_reports_email() == 0


# --------------------------------------------------------------------------- code review fixes


def paid_order(store, hour, *, status, refunds=(), **fields):
    """An ONLINE order at `store` on DAY with its capture and PROCESSED order refunds (the
    refund signal settles `amount_refunded`)."""
    fields.setdefault("amount_paid", fields.get("grand_total", Decimal("300.00")))
    order = OrderFactory(
        store=store,
        status=status,
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PAID,
        placed_at=at(hour),
        **fields,
    )
    payment = Payment.objects.create(
        order=order, gateway="razorpay", amount=order.amount_paid, status="CAPTURED"
    )
    for index, (reason, amount) in enumerate(refunds):
        Refund.objects.create(
            payment=payment,
            order=order,
            amount=Decimal(amount),
            reason=reason,
            status="PROCESSED",
            processed_at=at(hour, 30),
            idempotency_key=f"{reason}:{order.pk}:{index}",
        )
    order.refresh_from_db()
    return order


class TestNetRevenue:
    """Code review (docs/05 §4): T8a refunds are already in the reduced `grand_total`; refunds of
    cancelled orders are not in GMV; the tip of a failed delivery is inside its refund."""

    @pytest.fixture
    def store(self, db):
        store = DarkStoreFactory()
        paid_order(  # delivered, tip 20
            store,
            9,
            status=OrderStatus.DELIVERED,
            tip=Decimal("20.00"),
            grand_total=Decimal("320.00"),
        )
        partial = paid_order(  # paid 300; T8a cut 100 (grand_total 200), then a manual 30
            store,
            10,
            status=OrderStatus.DELIVERED,
            mrp_total=Decimal("250.00"),
            item_total=Decimal("200.00"),
            grand_total=Decimal("200.00"),
            amount_paid=Decimal("300.00"),
            refunds=(("item_unavailable", "100.00"), ("manual", "30.00")),
        )
        assert partial.amount_refunded == Decimal("130.00")
        paid_order(  # cancelled and refunded in full: not in GMV, shown apart
            store,
            11,
            status=OrderStatus.CANCELLED,
            cancelled_at=at(11, 5),
            refunds=(("customer_cancel", "300.00"),),
        )
        paid_order(  # delivery failed (customer fault): 350 paid, 320 back, delivery fee kept
            store,
            12,
            status=OrderStatus.DELIVERY_FAILED,
            item_total=Decimal("300.00"),
            delivery_fee=Decimal("30.00"),
            tip=Decimal("20.00"),
            grand_total=Decimal("350.00"),
            refunds=(("delivery_failed", "320.00"),),
        )
        return store

    def test_definitions(self, store, superuser):
        """P7-TC-20: GMV 320 + 200 + 350; tips 20 (the failed delivery tip was refunded);
        refunded 130 + 320 - 100 (T8a); net 500 = 300 + 170 + 30 kept."""
        [row] = run(superuser, "sales_summary", store_id=store.pk)
        assert (row["orders"], row["delivered"], row["cancelled"]) == ("4", "2", "1")
        assert row["gmv"] == "870.00"
        assert row["tips"] == "20.00"
        assert row["refunded"] == "350.00"
        assert row["net_revenue"] == "500.00"
        assert row["unavailable_refunds"] == "100.00"
        assert row["cancelled_refunds"] == "300.00"
        assert row["aov"] == "290.00"

    def test_only_cancelled_refunds(self, superuser):
        store = DarkStoreFactory()
        paid_order(
            store,
            9,
            status=OrderStatus.CANCELLED,
            cancelled_at=at(9, 5),
            refunds=(("staff_cancel", "300.00"),),
        )
        [row] = run(superuser, "sales_summary", store_id=store.pk)
        assert (row["gmv"], row["refunded"], row["net_revenue"]) == ("0.00", "0.00", "0.00")
        assert row["cancelled_refunds"] == "300.00"
        assert row["aov"] == "0.00"


class TestRiderScope:
    def test_all_store_queries_are_not_store_filtered(self, shop, superuser):
        """Code review: global roles (no store_id) are not filtered by the store of a rider; a
        store_id or a store role is."""
        from apps.reports.registry import _rider_store_q

        _, query = services._query(superuser, "rider_earnings", DAY, DAY, None)
        assert query.all_stores
        assert _rider_store_q(query) == Q()
        _, query = services._query(superuser, "rider_earnings", DAY, DAY, shop["a"].pk)
        assert not query.all_stores
        manager = staff(roles.STORE_MANAGER, shop["a"])
        _, query = services._query(manager, "sales_summary", DAY, DAY, None)
        assert not query.all_stores
        finance = staff(roles.FINANCE)
        rider = RiderFactory()  # an applicant: no home store yet
        task = DeliveryTask.objects.create(
            order=shop["delivered"],
            store=shop["a"],
            status="DELIVERED",
            rider=rider,
            search_started_at=at(10),
            distance_km=Decimal("1.00"),
            payout_amount=Decimal("30.00"),
        )
        RiderEarning.objects.create(
            rider=rider, task=task, type="BASE", amount=Decimal("25.00"), earned_at=at(10, 20)
        )
        rows = run(finance, "rider_earnings")
        assert [r["rider_id"] for r in rows] == [str(rider.pk)]


class TestExportRobustness:
    def make(self, user, **fields):
        return ReportExport.objects.create(
            report="orders",
            requested_by=user,
            params={"start": DAY.isoformat(), "end": DAY.isoformat(), "store_id": None},
            **fields,
        )

    def test_deleted_export_is_a_no_op(self, db):
        from apps.reports.tasks import generate_export

        assert services.generate_export(999_999_999) is None
        assert generate_export.apply(args=(999_999_999,)).get() == "missing"

    def test_unexpected_error_fails_on_the_last_attempt(self, shop, superuser, monkeypatch):
        """An unexpected error never leaves the export RUNNING: not final -> PENDING and
        raised (the task retries); final -> FAILED with a generic message."""

        def boom(export):
            raise RuntimeError("storage down")

        monkeypatch.setattr(services, "_build_export", boom)
        export = self.make(superuser)
        with pytest.raises(RuntimeError):
            services.generate_export(export.pk, final_attempt=False)
        export.refresh_from_db()
        assert (export.status, export.started_at) == (ExportStatus.PENDING, None)
        result = services.generate_export(export.pk)
        assert result.status == ExportStatus.FAILED
        assert result.error == services.MSG_EXPORT_FAILED
        assert "storage" not in result.error
        export.refresh_from_db()
        assert export.status == ExportStatus.FAILED
        assert export.finished_at is not None

    def test_task_retries_then_fails(self, shop, superuser, monkeypatch):
        from apps.reports.tasks import generate_export

        calls = []

        def boom(export):
            calls.append(export.pk)
            raise RuntimeError("storage down")

        monkeypatch.setattr(services, "_build_export", boom)
        export = self.make(superuser)
        with pytest.raises(Retry):  # not the last attempt: retried, back to PENDING
            generate_export.apply(args=(export.pk,))
        export.refresh_from_db()
        assert export.status == ExportStatus.PENDING
        last = generate_export.max_retries
        result = generate_export.apply(args=(export.pk,), retries=last, throw=False)
        assert result.get() == ExportStatus.FAILED
        assert len(calls) == 2
        export.refresh_from_db()
        assert export.status == ExportStatus.FAILED

    def test_deleted_while_running(self, shop, superuser, monkeypatch):
        def vanish(export):
            ReportExport.objects.filter(pk=export.pk).delete()
            raise RuntimeError("gone")

        monkeypatch.setattr(services, "_build_export", vanish)
        export = self.make(superuser)
        assert services.generate_export(export.pk) is None

    def test_running_is_skipped_unless_stale(self, shop, superuser, settings):
        settings.REPORT_EXPORT_STALE_MINUTES = 15
        now = timezone.now()
        busy = self.make(superuser, status=ExportStatus.RUNNING, started_at=now)
        result = services.generate_export(busy.pk)
        assert result.status == ExportStatus.RUNNING
        assert not result.file
        stale = self.make(
            superuser, status=ExportStatus.RUNNING, started_at=now - timedelta(minutes=16)
        )
        assert services.generate_export(stale.pk).status == ExportStatus.DONE

    def test_stuck_exports_fail_in_the_daily_purge(self, shop, superuser):
        from apps.reports.tasks import purge_old_exports

        stuck = self.make(superuser)
        ReportExport.objects.filter(pk=stuck.pk).update(
            created_at=timezone.now() - timedelta(days=2)
        )
        fresh = self.make(superuser)
        purge_old_exports()
        stuck.refresh_from_db()
        fresh.refresh_from_db()
        assert stuck.status == ExportStatus.FAILED
        assert fresh.status == ExportStatus.PENDING

    def test_download_is_audited(self, shop, django_capture_on_commit_callbacks):
        """Code review: like `reports.download` and `reports.export`."""
        from apps.core.models import AuditLog

        finance = staff(roles.FINANCE)
        with django_capture_on_commit_callbacks(execute=True):
            export = services.request_export(finance, "orders", start=DAY, end=DAY)
        services.export_download_url(finance, export.pk)
        entry = AuditLog.objects.get(action="reports.export_download")
        assert entry.actor == finance
        assert entry.object_id == str(export.pk)
        assert entry.changes == {"report": "orders", "rows": 4}


class TestDailyEmailPerManager:
    def test_fans_out_one_task_per_manager(self, shop, monkeypatch):
        from apps.reports import tasks

        first = staff(roles.STORE_MANAGER, shop["a"])
        second = staff(roles.STORE_MANAGER, shop["b"])
        queued = []
        monkeypatch.setattr(tasks.daily_report_mail, "delay", lambda *args: queued.append(args))
        assert tasks.daily_reports_email(DAY.isoformat()) == 2
        assert sorted(queued) == sorted([(first.pk, DAY.isoformat()), (second.pk, DAY.isoformat())])

    def test_one_failure_does_not_stop_the_others_and_no_double_send(self, shop, monkeypatch):
        """Code review: an SMTP error affects (and retries) that manager only; a sent mail is
        not sent again by a redelivered task."""
        from apps.reports import tasks

        failing = staff(roles.STORE_MANAGER, shop["a"])
        fine = staff(roles.STORE_MANAGER, shop["b"])
        real_send = tasks.send_mail

        def send(subject, body, sender, to):
            if to == [failing.email]:
                raise OSError("SMTP down")
            return real_send(subject, body, sender, to)

        monkeypatch.setattr(tasks, "send_mail", send)
        day = DAY.isoformat()
        with pytest.raises(Retry):
            tasks.daily_report_mail.apply(args=(failing.pk, day))
        last = tasks.daily_report_mail.max_retries
        result = tasks.daily_report_mail.apply(args=(failing.pk, day), retries=last, throw=False)
        assert result.failed()
        assert tasks.daily_report_mail.apply(args=(fine.pk, day)).get() == "sent"
        assert [m.to for m in mail.outbox] == [[fine.email]]
        assert tasks.daily_report_mail.apply(args=(fine.pk, day)).get() == "already_sent"
        assert len(mail.outbox) == 1
        ops = staff(roles.OPS)
        assert tasks.daily_report_mail.apply(args=(ops.pk, day)).get() == "skipped"
        assert tasks.daily_report_mail.apply(args=(999_999_999, day)).get() == "skipped"

    def test_disabled(self, shop, settings):
        from apps.reports import tasks

        manager = staff(roles.STORE_MANAGER, shop["a"])
        settings.DAILY_REPORTS_EMAIL_ENABLED = False
        result = tasks.daily_report_mail.apply(args=(manager.pk, DAY.isoformat())).get()
        assert result == "disabled"
