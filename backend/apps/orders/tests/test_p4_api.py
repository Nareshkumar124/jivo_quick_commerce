"""Phase 4: order detail additions, reorder, invoices (WeasyPrint on demand, placeholder GST
data, D-12), the T-403c expiry changes, set_cod_blocked (T-405c), PricingConfig sanity bounds
(T-406c) and the seed (P3-TC-26)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.gis.geos import Point
from django.core.exceptions import ValidationError
from django.core.management import call_command
from django.utils import timezone

from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core.models import AuditLog
from apps.inventory.models import StoreInventory, stock_write
from apps.orders import invoices, services
from apps.orders.models import Invoice, Order
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db
D = Decimal


def place(checkout, shop, *lines, method="COD"):
    checkout.fill(*(lines or [(shop.canola_1l, 2)]))
    return Order.objects.get(pk=checkout.place(method)["order"]["id"])


def deliver(order):
    Order.objects.filter(pk=order.pk).update(status="DELIVERED", delivered_at=timezone.now())
    order.refresh_from_db()
    return order


def weasyprint_available() -> bool:
    try:
        import weasyprint  # noqa: F401
    except (ImportError, OSError):
        return False
    return True


NO_WEASYPRINT = "WeasyPrint native libraries (Pango/GTK) are not installed on this host"


class TestDetail:
    def test_new_fields(self, checkout, shop):
        order = place(checkout, shop)
        body = checkout.client.get(f"/api/v1/orders/{order.pk}/").json()
        assert body["timeline"][0]["status"] == "PLACED"
        assert body["timeline"][0]["title"] == "Order placed"
        assert body["cancellation"] is None
        assert body["refunds"] == []
        assert body["amount_refunded"] == "0.00"
        assert body["can_download_invoice"] is False
        assert body["can_cancel"] is True
        assert body["items"][0]["quantity_unavailable"] == 0

    def test_detail_query_count_is_fixed(self, checkout, shop, django_assert_max_num_queries):
        order = place(checkout, shop, (shop.canola_1l, 1), (shop.chia, 1), (shop.flax, 1))
        with django_assert_max_num_queries(12):
            assert checkout.client.get(f"/api/v1/orders/{order.pk}/").status_code == 200


class TestReorder:
    URL = "/api/v1/orders/{}/reorder/"

    def test_reorder_is_idempotent_and_capped(self, checkout, shop):
        order = place(checkout, shop, (shop.canola_1l, 2), (shop.chia, 3), (shop.flax, 1))
        # Stock changes after the order: chia sold out, flax no longer sold here.
        StoreInventory.objects.filter(store=shop.store_model, variant=shop.chia).update(
            is_available=False
        )
        StoreInventory.objects.filter(store=shop.store_model, variant=shop.flax).delete()
        response = checkout.client.post(self.URL.format(order.pk), headers=checkout.headers)
        assert response.status_code == 200, response.content
        body = response.json()
        quantities = {line["variant"]["id"]: line["quantity"] for line in body["cart"]["items"]}
        assert quantities == {shop.canola_1l.pk: 2}
        reasons = {row["variant_id"]: row["reason"] for row in body["unavailable"]}
        assert reasons == {shop.chia.pk: "OUT_OF_STOCK", shop.flax.pk: "NOT_AVAILABLE"}
        assert body["added_count"] == 1
        again = checkout.client.post(self.URL.format(order.pk), headers=checkout.headers).json()
        assert again["cart"]["items"][0]["quantity"] == 2  # set, never added on top

    def test_limited_stock(self, checkout, shop):
        order = place(checkout, shop, (shop.canola_1l, 5))
        with stock_write():  # 10 on hand, 5 for the order, 2 more held elsewhere: 3 left
            StoreInventory.objects.filter(store=shop.store_model, variant=shop.canola_1l).update(
                reserved=7
            )
        body = checkout.client.post(self.URL.format(order.pk), headers=checkout.headers).json()
        assert body["unavailable"] == [
            {
                "variant_id": shop.canola_1l.pk,
                "product_name": "Jivo Cold Pressed Canola Oil",
                "variant_name": "1 L",
                "requested_quantity": 5,
                "added_quantity": 3,
                "reason": "LIMITED_STOCK",
            }
        ]

    def test_another_users_order(self, checkout, shop, make_auth_client):
        order = place(checkout, shop)
        other = make_auth_client(UserFactory())
        response = other.post(self.URL.format(order.pk), headers=checkout.headers)
        assert response.status_code == 404


class TestInvoice:
    URL = "/api/v1/orders/{}/invoice/"

    def test_only_delivered_orders(self, checkout, shop):
        order = place(checkout, shop)
        response = checkout.client.get(self.URL.format(order.pk))
        assert response.status_code == 409
        assert response.json()["error"]["details"] == {"status": "PLACED"}

    def test_another_users_invoice(self, checkout, shop, make_auth_client):
        order = deliver(place(checkout, shop))
        other = make_auth_client(UserFactory())
        assert other.get(self.URL.format(order.pk)).status_code == 404

    def test_numbers_and_gst_split(self, checkout, shop):
        """Intra-state (Haryana store, Haryana address): CGST + SGST; prices GST-inclusive."""
        order = deliver(place(checkout, shop, (shop.canola_1l, 2), (shop.chia, 1)))
        invoice = invoices.ensure_invoice(order.pk)
        assert invoices.ensure_invoice(order.pk) == invoice  # idempotent
        year = invoices.financial_year(order.delivered_at)
        prefix = shop.store_model.invoice_prefix
        assert invoice.invoice_number == f"{prefix}/{year}/000001"
        assert invoice.total == order.grand_total - order.tip
        assert invoice.igst == 0
        assert invoice.cgst + invoice.sgst + invoice.taxable_value == invoice.total
        assert invoice.is_placeholder  # no store GSTIN (D-12)
        assert invoice.seller_gstin == "GSTIN-NOT-SET"
        second = deliver(place(checkout, shop, (shop.flax, 2)))
        assert invoices.ensure_invoice(second.pk).invoice_number.endswith("/000002")

    def test_inter_state_and_coupon_share(self, checkout, shop):
        order = deliver(place(checkout, shop, (shop.canola_1l, 2), (shop.chia, 1)))
        Order.objects.filter(pk=order.pk).update(
            address_snapshot={**order.address_snapshot, "state": "Delhi"},
            coupon_discount=D("50.00"),
            grand_total=order.grand_total - D("50.00"),
        )
        order.refresh_from_db()
        lines = invoices.tax_lines(order)
        assert sum(line.gross for line in lines) == order.item_total - D("50.00")
        invoice = invoices.ensure_invoice(order.pk)
        assert invoice.cgst == invoice.sgst == 0
        assert invoice.igst > 0

    def test_financial_year(self):
        from datetime import UTC, datetime

        assert invoices.financial_year(datetime(2026, 3, 31, 18, 29, tzinfo=UTC)) == "25-26"
        assert invoices.financial_year(datetime(2026, 3, 31, 18, 30, tzinfo=UTC)) == "26-27"

    def test_html_marks_placeholders(self, checkout, shop):
        order = deliver(place(checkout, shop))
        html = invoices.invoice_html(invoices.ensure_invoice(order.pk))
        assert "NOT A VALID TAX INVOICE" in html
        assert order.order_number in html

    def test_unavailable_renderer_answers_503(self, checkout, shop, monkeypatch):
        order = deliver(place(checkout, shop))

        def broken(invoice):
            raise invoices.InvoiceRenderingUnavailable("no pango")

        monkeypatch.setattr(invoices, "render_pdf", broken)
        response = checkout.client.get(self.URL.format(order.pk))
        assert response.status_code == 503
        assert Invoice.objects.filter(order=order).exists()  # numbered anyway

    def test_link_with_a_stored_pdf(self, checkout, shop, monkeypatch):
        order = deliver(place(checkout, shop))
        monkeypatch.setattr(invoices, "render_pdf", lambda invoice: b"%PDF-1.7 test")
        body = checkout.client.get(self.URL.format(order.pk)).json()
        invoice = Invoice.objects.get(order=order)
        assert body["invoice_number"] == invoice.invoice_number
        assert invoice.pdf.name.endswith(".pdf")
        assert body["url"]
        assert body["expires_at"]

    def test_generate_invoice_task(self, checkout, shop, monkeypatch):
        from apps.orders.tasks import generate_invoice

        order = place(checkout, shop)
        assert generate_invoice(order.pk) == "skipped"
        deliver(order)
        monkeypatch.setattr(invoices, "render_pdf", lambda invoice: b"%PDF-1.7 test")
        assert generate_invoice(order.pk) == "done"

    @pytest.mark.skipif(not weasyprint_available(), reason=NO_WEASYPRINT)
    def test_weasyprint_renders_a_pdf(self, checkout, shop):
        order = deliver(place(checkout, shop))
        pdf = invoices.render_pdf(invoices.ensure_invoice(order.pk))
        assert pdf.startswith(b"%PDF")


class TestExpiry:
    """T-403c: one expiry run at a time; orders locked elsewhere are skipped, not waited on."""

    def test_run_lock(self, checkout, shop):
        from django.core.cache import cache

        checkout.fill((shop.canola_1l, 2))
        checkout.place("ONLINE")
        later = timezone.now() + timedelta(minutes=20)
        cache.add("orders:expire_unpaid_orders", "1", 60)
        assert services.expire_unpaid_orders(later) == {"locked": 1}
        cache.delete("orders:expire_unpaid_orders")
        assert services.expire_unpaid_orders(later) == {"failed": 1}


class TestCodBlocked:
    def test_service(self):
        customer, staff = UserFactory(), StaffUserFactory()
        from apps.accounts.services.customers import set_cod_blocked

        assert set_cod_blocked(customer.pk, True, by=staff) is True
        assert set_cod_blocked(customer.pk, True, by=staff) is False
        customer.refresh_from_db()
        assert customer.cod_blocked is True
        assert set_cod_blocked(customer.pk, False, by=staff) is True
        with pytest.raises(ValidationError):
            set_cod_blocked(staff.pk, True, by=staff)
        with pytest.raises(ValidationError):
            set_cod_blocked(999999, True, by=staff)
        with pytest.raises(ValueError, match="acting staff user"):
            set_cod_blocked(customer.pk, True, by=None)


class TestPricingBounds:
    def test_clean(self, shop):
        config = PricingConfig(store=shop.store_model)
        config.full_clean(exclude=["store"])
        config.delivery_fee = D("2500.00")
        config.cod_max_order_value = D("50.00")
        with pytest.raises(ValidationError) as exc:
            config.full_clean(exclude=["store"])
        assert set(exc.value.message_dict) == {"delivery_fee", "cod_max_order_value"}
        config = PricingConfig(store=shop.store_model, small_cart_threshold=D("0"))
        with pytest.raises(ValidationError):
            config.full_clean(exclude=["store"])


class TestAudit:
    def test_append_only(self):
        from apps.core import audit

        entry = audit.record(None, "test.action", ("orders.order", 1), {"a": 1})
        with pytest.raises(ValidationError):
            entry.save()
        with pytest.raises(ValidationError):
            AuditLog.objects.update(action="x")
        assert str(entry) == "test.action orders.order:1"


def test_seed_demo_phase4(settings):
    """P3-TC-26 (sachet below the ₹99 minimum) and the delivered demo order; idempotent."""
    from apps.catalog.models import ProductVariant

    call_command("seed_demo")
    call_command("seed_demo")
    sachet = ProductVariant.objects.get(sku="JV-WG-PW-10S")
    assert sachet.selling_price < D("99.00")
    assert StoreInventory.objects.filter(variant=sachet, store__code="GGN-01").exists()
    delivered = Order.objects.filter(idempotency_key="seed-demo-delivered-1")
    assert delivered.count() == 1
    order = delivered.get()
    assert order.status == "DELIVERED"
    assert order.status_history.count() == 6
    assert isinstance(order.delivery_location, Point)


class TestReviewFixes:
    def test_reorder_skips_a_line_the_store_could_not_supply(self, checkout, shop):
        from django.contrib.auth.models import Group

        from apps.accounts import roles
        from apps.orders import store_ops

        order = place(checkout, shop, (shop.canola_1l, 2), (shop.chia, 1))
        staff = StaffUserFactory()
        staff.groups.add(Group.objects.get(name=roles.OPS))
        store_ops.accept_order(order.pk, by=staff)
        line = order.items.get(variant=shop.chia)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        with pytest.raises(ValidationError):  # a bool is not a number of units
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=True, by=staff)
        body = checkout.client.post(
            f"/api/v1/orders/{order.pk}/reorder/", headers=checkout.headers
        ).json()
        assert {line["variant"]["id"] for line in body["cart"]["items"]} == {shop.canola_1l.pk}
        assert body["unavailable"] == []
        assert body["added_count"] == 1

    def test_audit_changes_hold_no_personal_data(self, checkout, shop):
        from django.contrib.auth.models import Group

        from apps.accounts import roles
        from apps.orders import store_ops

        order = place(checkout, shop)
        manager = StaffUserFactory()
        manager.groups.add(Group.objects.get(name=roles.OPS))
        store_ops.cancel_by_staff(
            order.pk, by=manager, reason="ADDRESS_ISSUE", note="Customer Asha +919876543210"
        )
        entry = AuditLog.objects.get(action="order.cancel")
        text = str(entry.changes)
        assert entry.changes["note_length"] == len("Customer Asha +919876543210")
        for value in ("Asha", "9876543210", order.user.phone, order.user.name):
            assert not value or value not in text
        with pytest.raises(ValidationError):
            entry.delete()
        with pytest.raises(ValidationError):
            AuditLog.objects.all().delete()
        with pytest.raises(ValidationError):
            AuditLog.objects.bulk_update([entry], ["action"])

    def test_super_admin_only_views_the_audit_log(self):
        from django.contrib.auth.models import Group

        from apps.accounts import roles

        codenames = set(
            Group.objects.get(name=roles.SUPER_ADMIN)
            .permissions.filter(content_type__app_label="core")
            .values_list("codename", flat=True)
        )
        assert codenames == {"view_auditlog"}

    def test_cod_invoice_says_amount_due(self, checkout, shop):
        order = deliver(place(checkout, shop))
        html = invoices.invoice_html(invoices.ensure_invoice(order.pk))
        assert "Amount due (cash on delivery)" in html

    def test_backfill_amount_paid(self, checkout, shop):
        import importlib

        from django.apps import apps as registry

        checkout.fill((shop.canola_1l, 2))
        placement = checkout.place("ONLINE")
        checkout.verify(placement)
        Order.objects.update(amount_paid=0)
        migration = importlib.import_module("apps.orders.migrations.0004_backfill_amount_paid")
        migration.backfill(registry, None)
        order = Order.objects.get()
        assert order.amount_paid == order.grand_total == D("558.00")
