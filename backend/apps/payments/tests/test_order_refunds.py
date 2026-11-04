"""Phase 4 refunds (`apps.payments.order_refunds`): staff refunds with the 05 §3 limits, the cap
on total refunds (T-402c), the ops retry hook (T-401c), `sync_refund_status` (06 §5) and the
fake gateway's "down" switch (P3-TC-63)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.management import call_command
from django.test import override_settings
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.models import AuditLog
from apps.orders.models import Order
from apps.orders.tests.conftest import ORDERS, VERIFY, new_key, sign
from apps.payments import order_refunds
from apps.payments.checks import check_payment_gateway
from apps.payments.gateways import FakeRazorpayGateway, GatewayUnavailable
from apps.payments.models import Refund, RefundStatus

pytestmark = pytest.mark.django_db
D = Decimal


@pytest.fixture
def make_staff():
    def make(role):
        user = StaffUserFactory()
        user.groups.add(Group.objects.get(name=role))
        return user

    return make


@pytest.fixture
def paid(checkout, shop):
    """An online order for 2 x canola 1 L (₹558), paid."""
    checkout.fill((shop.canola_1l, 2))
    placement = checkout.place("ONLINE")
    checkout.verify(placement)
    return Order.objects.get(pk=placement["order"]["id"])


class TestManualRefund:
    def test_finance_refunds_part_then_the_cap_applies(
        self, paid, make_staff, django_capture_on_commit_callbacks
    ):
        finance = make_staff(roles.FINANCE)
        with django_capture_on_commit_callbacks(execute=True):
            refund = order_refunds.manual_refund(paid.pk, D("100"), by=finance, note="Late")
        paid.refresh_from_db()
        assert Refund.objects.get(pk=refund.pk).status == RefundStatus.PROCESSED
        assert paid.payment_status == "PARTIALLY_REFUNDED"
        assert paid.amount_refunded == D("100.00")
        assert order_refunds.refundable(paid) == D("458.00")
        with pytest.raises(ValidationError):  # T-402c: never more than was paid
            order_refunds.manual_refund(paid.pk, D("458.01"), by=finance)
        with django_capture_on_commit_callbacks(execute=True):
            order_refunds.manual_refund(paid.pk, D("458.00"), by=finance)
        paid.refresh_from_db()
        assert paid.payment_status == "REFUNDED"
        assert paid.amount_refunded == D("558.00")
        assert AuditLog.objects.filter(action="refund.issue").count() == 2

    def test_support_limit(self, paid, make_staff, settings):
        support = make_staff(roles.SUPPORT)
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(paid.pk, D("500.01"), by=support)
        settings.SUPPORT_REFUND_LIMIT = D("50.00")
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(paid.pk, D("60"), by=support)
        assert order_refunds.manual_refund(paid.pk, D("50"), by=support).amount == D("50.00")

    @pytest.mark.parametrize("role", [roles.OPS, roles.STORE_MANAGER, roles.CATALOG_MANAGER])
    def test_roles_without_refunds(self, paid, make_staff, role):
        with pytest.raises(PermissionDenied):
            order_refunds.manual_refund(paid.pk, D("10"), by=make_staff(role))

    def test_cod_and_bad_amounts(self, checkout, shop, superuser):
        checkout.fill((shop.canola_1l, 2))
        order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(order.pk, D("10"), by=superuser)
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(order.pk, D("0"), by=superuser)
        with pytest.raises(ValidationError):
            order_refunds.manual_refund(999999, D("10"), by=superuser)


class TestRetryAndSync:
    def failed_refund(self, paid, superuser):
        refund = order_refunds.manual_refund(paid.pk, D("100"), by=superuser)
        Refund.objects.filter(pk=refund.pk).update(status=RefundStatus.FAILED)
        return Refund.objects.get(pk=refund.pk)

    def test_retry_failed_refund(
        self, paid, superuser, make_staff, django_capture_on_commit_callbacks
    ):
        failed = self.failed_refund(paid, superuser)
        assert order_refunds.refundable(paid) == D("458.00")  # a failed refund still counts
        with pytest.raises(PermissionDenied):
            order_refunds.retry_refund(failed.pk, by=make_staff(roles.OPS))
        with django_capture_on_commit_callbacks(execute=True):
            retry = order_refunds.retry_refund(failed.pk, by=make_staff(roles.FINANCE))
        assert retry.pk != failed.pk
        assert retry.idempotency_key == f"{failed.idempotency_key}:retry-1"
        assert Refund.objects.get(pk=retry.pk).status == RefundStatus.PROCESSED
        paid.refresh_from_db()
        assert paid.amount_refunded == D("100.00")  # the failed one is replaced, not added
        assert paid.payment_status == "PARTIALLY_REFUNDED"
        assert order_refunds.refundable(paid) == D("458.00")
        with pytest.raises(ValidationError):  # already retried
            order_refunds.retry_refund(failed.pk, by=superuser)
        public = order_refunds.customer_refunds(list(Refund.objects.filter(order=paid)))
        assert [(r["amount"], r["status"]) for r in public] == [("100.00", "PROCESSED")]

    def test_failed_refund_shows_pending_to_the_customer(self, paid, superuser):
        failed = self.failed_refund(paid, superuser)
        public = order_refunds.customer_refunds([failed])
        assert public[0]["status"] == "PENDING"

    def test_stuck_pending_refund_is_resent(self, paid, superuser):
        refund = order_refunds.manual_refund(paid.pk, D("100"), by=superuser)
        with pytest.raises(ValidationError):  # not stuck yet
            order_refunds.retry_refund(refund.pk, by=superuser)
        Refund.objects.filter(pk=refund.pk).update(
            updated_at=timezone.now() - timedelta(minutes=30)
        )
        assert order_refunds.retry_refund(refund.pk, by=superuser).pk == refund.pk

    def test_sync_refund_status(self, paid, superuser, django_capture_on_commit_callbacks):
        refund = order_refunds.manual_refund(paid.pk, D("100"), by=superuser)
        assert order_refunds.sync_refund_status() == {"waiting": 1}
        # The gateway made the refund but its answer was not recorded as processed yet.
        Refund.objects.filter(pk=refund.pk).update(gateway_refund_id="rfnd_SyncTest000001")
        with django_capture_on_commit_callbacks(execute=True):
            assert order_refunds.sync_refund_status() == {"processed": 1}
        paid.refresh_from_db()
        assert paid.amount_refunded == D("100.00")
        assert order_refunds.sync_refund_status() == {}
        # Stuck without a gateway id: sent again.
        other = order_refunds.manual_refund(paid.pk, D("10"), by=superuser)
        Refund.objects.filter(pk=other.pk).update(updated_at=timezone.now() - timedelta(minutes=30))
        with django_capture_on_commit_callbacks(execute=True):
            assert order_refunds.sync_refund_status() == {"resent": 1}
        assert Refund.objects.get(pk=other.pk).status == RefundStatus.PROCESSED

    def test_sync_with_the_gateway_down(self, paid, superuser):
        refund = order_refunds.manual_refund(paid.pk, D("100"), by=superuser)
        Refund.objects.filter(pk=refund.pk).update(gateway_refund_id="rfnd_SyncTest000002")
        with override_settings(FAKE_GATEWAY_DOWN=True):
            assert order_refunds.sync_refund_status() == {"error": 1}

    def test_failed_delivery_policy(self, paid, settings):
        """08 §6.4 (D-10 default): the delivery fee is kept on customer-fault failures."""
        paid.delivery_fee = D("25.00")
        assert order_refunds.failed_delivery_refund(paid, customer_fault=False) == D("558.00")
        assert order_refunds.failed_delivery_refund(paid, customer_fault=True) == D("533.00")
        settings.REFUND_KEEP_DELIVERY_FEE_ON_CUSTOMER_FAULT = False
        assert order_refunds.failed_delivery_refund(paid, customer_fault=True) == D("558.00")


class TestFakeGatewayDown:
    """P3-TC-63: `FAKE_GATEWAY_DOWN` makes the fake gateway answer like an unreachable Razorpay."""

    def test_every_call_fails(self, settings):
        settings.FAKE_GATEWAY_DOWN = True
        gateway = FakeRazorpayGateway()
        calls = [
            lambda: gateway.create_order(amount_paise=100, receipt="r", notes={}),
            lambda: gateway.fetch_order_payments("order_Abcdefghij1234"),
            lambda: gateway.refund(
                payment_id="pay_Abcdefghij1234", amount_paise=100, notes={}, receipt="r"
            ),
            lambda: gateway.fetch_payment_refunds("pay_Abcdefghij1234"),
            lambda: gateway.verify_payment_signature(
                order_id="order_Abcdefghij1234", payment_id="pay_Abcdefghij1234", signature="x"
            ),
        ]
        for call in calls:
            with pytest.raises(GatewayUnavailable):
                call()

    def test_online_placement_and_verify_answer_503(self, checkout, shop, settings):
        checkout.fill((shop.canola_1l, 2))
        settings.FAKE_GATEWAY_DOWN = True
        response = checkout.client.post(
            ORDERS,
            {
                "address_id": checkout.address.pk,
                "payment_method": "ONLINE",
                "expected_grand_total": checkout.cart()["bill"]["grand_total"],
            },
            headers={**checkout.headers, "Idempotency-Key": new_key()},
        )
        assert response.status_code == 503
        assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"
        assert not Order.objects.exists()
        settings.FAKE_GATEWAY_DOWN = False
        placement = checkout.place("ONLINE")
        settings.FAKE_GATEWAY_DOWN = True
        gateway_order = placement["razorpay"]["order_id"]
        response = checkout.client.post(
            VERIFY,
            {
                "order_id": placement["order"]["id"],
                "razorpay_order_id": gateway_order,
                "razorpay_payment_id": "pay_TestPayment0001",
                "razorpay_signature": sign(gateway_order, "pay_TestPayment0001"),
            },
        )
        assert response.status_code == 503
        assert Order.objects.get().status == "PAYMENT_PENDING"

    def test_expiry_waits_while_down(self, checkout, shop, settings):
        from apps.orders import services

        checkout.fill((shop.canola_1l, 2))
        order_id = checkout.place("ONLINE")["order"]["id"]
        settings.FAKE_GATEWAY_DOWN = True
        later = timezone.now() + timedelta(minutes=20)
        assert services.expire_unpaid_orders(later) == {"error": 1}
        assert Order.objects.get(pk=order_id).status == "PAYMENT_PENDING"

    def test_refused_in_deployed_environments(self, settings):
        settings.FAKE_GATEWAY_DOWN = True
        settings.APP_ENVIRONMENT = "production"
        settings.PAYMENT_GATEWAY = "apps.payments.gateways.RazorpayGateway"
        ids = [error.id for error in check_payment_gateway(None)]
        assert ids == ["payments.E004"]
        settings.APP_ENVIRONMENT = "local"
        assert check_payment_gateway(None) == []

    def test_system_check_command_passes_locally(self):
        call_command("check")


class TestNoDoubleRefund:
    """P4 review: a cancel's refund, then the gateway's `refund.processed` webhook and the
    `sync_refund_status` job, never refund twice or count the money twice."""

    def test_cancel_then_webhook_then_sync(
        self, checkout, paid, api_client, django_capture_on_commit_callbacks
    ):
        from apps.orders.tests.test_lifecycle import webhook

        with django_capture_on_commit_callbacks(execute=True):
            response = checkout.client.post(f"{ORDERS}{paid.pk}/cancel/", {"reason": "OTHER"})
        assert response.status_code == 200
        refund = Refund.objects.get(order=paid)
        assert refund.status == RefundStatus.PROCESSED
        event = {
            "entity": "event",
            "event": "refund.processed",
            "payload": {
                "refund": {
                    "entity": {
                        "id": refund.gateway_refund_id,
                        "payment_id": refund.payment.gateway_payment_id,
                        "amount": 55800,
                        "receipt": refund.idempotency_key,
                        "status": "processed",
                    }
                }
            },
        }
        with django_capture_on_commit_callbacks(execute=True):
            assert webhook(api_client, event, "evt_refund_after_cancel").status_code == 200
            assert order_refunds.sync_refund_status() == {}
        paid.refresh_from_db()
        assert Refund.objects.filter(order=paid).count() == 1
        assert paid.amount_refunded == D("558.00")
        assert paid.payment_status == "REFUNDED"


class TestRefundAlerts:
    """P4 review Minor 2: a paid order cancelled without a refund is never silent."""

    def test_missing_sale_payment_alerts(self, paid, superuser, caplog, monkeypatch):
        from apps.orders import store_ops

        monkeypatch.setattr(order_refunds, "sale_payment", lambda order: None)
        with caplog.at_level("ERROR"):
            store_ops.cancel_by_staff(paid.pk, by=superuser, reason="CUSTOMER_REQUEST")
        assert "No refund made for paid order" in caplog.text
        assert not Refund.objects.filter(order=paid).exists()

    def test_fully_refunded_is_quiet(self, paid, superuser, caplog):
        order_refunds.manual_refund(paid.pk, D("558.00"), by=superuser)
        paid.refresh_from_db()
        with caplog.at_level("ERROR"):
            order_refunds.alert_if_not_refunded(paid, None, context="test")
        assert "No refund made" not in caplog.text


class TestTwoLateCaptures:
    """OBS-P3-05: two late captures (T3a) on one cancelled order are both refunded in full."""

    def place_and_cancel(self, checkout, shop):
        checkout.fill((shop.canola_1l, 2))
        placement = checkout.place("ONLINE")
        order_id = placement["order"]["id"]
        checkout.client.post(f"{ORDERS}{order_id}/cancel/", {"reason": "CHANGE_PAYMENT_METHOD"})
        return order_id, placement["razorpay"]["order_id"]

    def capture_twice(self, order_id, gateway_order_id, capture):
        from apps.orders import services

        with capture(execute=True):
            for payment_id in ("pay_LateCaptureA001", "pay_LateCaptureB001"):
                outcome = services.capture_payment(
                    order_id,
                    gateway_order_id=gateway_order_id,
                    payment_id=payment_id,
                    amount_paise=55800,
                )
                assert outcome.outcome == "late_capture"

    def test_both_are_refunded(self, checkout, shop, django_capture_on_commit_callbacks):
        order_id, gateway_order_id = self.place_and_cancel(checkout, shop)
        self.capture_twice(order_id, gateway_order_id, django_capture_on_commit_callbacks)
        refunds = Refund.objects.filter(order_id=order_id)
        assert sorted(refunds.values_list("amount", "status")) == [
            (D("558.00"), "PROCESSED"),
            (D("558.00"), "PROCESSED"),
        ]
        assert Order.objects.get(pk=order_id).payment_status == "REFUNDED"

    @pytest.mark.xfail(
        strict=True,
        reason=(
            "OBS-P3-05, reported to the PM: amount_refunded is capped at max(amount_paid, "
            "grand_total) by record_refund_status and by the DB constraint "
            "order_refund_within_paid, so two ₹558 late captures show ₹558, not ₹1,116. A fix "
            "needs a captured-total bound (e.g. an amount_captured field) and a constraint change."
        ),
    )
    def test_amount_refunded_counts_both(self, checkout, shop, django_capture_on_commit_callbacks):
        order_id, gateway_order_id = self.place_and_cancel(checkout, shop)
        self.capture_twice(order_id, gateway_order_id, django_capture_on_commit_callbacks)
        assert Order.objects.get(pk=order_id).amount_refunded == D("1116.00")
