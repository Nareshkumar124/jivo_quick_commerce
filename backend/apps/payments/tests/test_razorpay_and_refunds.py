"""The real Razorpay gateway's HTTP calls (no network: `urlopen` is patched) and the refund task."""

import base64
import io
import json
import urllib.error
from decimal import Decimal

import pytest

from apps.orders.tests.factories import OrderFactory
from apps.payments import gateways
from apps.payments.gateways import (
    FakeRazorpayGateway,
    PaymentGatewayError,
    RazorpayGateway,
    to_paise,
)
from apps.payments.models import Payment, Refund
from apps.payments.refunds import DUPLICATE_CAPTURE, LATE_CAPTURE, request_refund
from apps.payments.tasks import process_refund


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


@pytest.fixture
def keys(settings):
    settings.RAZORPAY_KEY_ID = "rzp_test_Example0000001"
    settings.RAZORPAY_KEY_SECRET = "test-secret"
    settings.RAZORPAY_WEBHOOK_SECRET = "test-webhook-secret"


@pytest.fixture
def calls(monkeypatch, keys):
    """Records each request and answers with the next queued JSON body."""
    recorded, answers = [], []

    def urlopen(request, timeout):
        recorded.append(
            {
                "method": request.get_method(),
                "url": request.full_url,
                "body": json.loads(request.data) if request.data else None,
                "auth": request.headers["Authorization"],
                "timeout": timeout,
            }
        )
        answer = answers.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return FakeResponse(json.dumps(answer).encode())

    monkeypatch.setattr(gateways.urllib.request, "urlopen", urlopen)
    return recorded, answers


class TestRazorpayGateway:
    def test_create_order(self, calls):
        recorded, answers = calls
        answers.append(
            {"id": "order_Real00000001", "amount": 75300, "currency": "INR", "receipt": "JV-1"}
        )
        order = RazorpayGateway().create_order(amount_paise=75300, receipt="JV-1", notes={"a": "b"})
        assert (order.id, order.amount_paise, order.receipt) == (
            "order_Real00000001",
            75300,
            "JV-1",
        )
        call = recorded[0]
        assert (call["method"], call["url"]) == ("POST", "https://api.razorpay.com/v1/orders")
        assert call["body"] == {
            "amount": 75300,
            "currency": "INR",
            "receipt": "JV-1",
            "notes": {"a": "b"},
        }
        expected = base64.b64encode(b"rzp_test_Example0000001:test-secret").decode()
        assert call["auth"] == f"Basic {expected}"
        assert call["timeout"] == 10.0

    def test_fetch_order_payments(self, calls):
        recorded, answers = calls
        answers.append(
            {
                "items": [
                    {
                        "id": "pay_A",
                        "order_id": "order_X",
                        "amount": 100,
                        "status": "captured",
                        "method": "upi",
                    }
                ]
            }
        )
        payments = RazorpayGateway().fetch_order_payments("order_X")
        assert [(p.id, p.status, p.method, p.amount_paise) for p in payments] == [
            ("pay_A", "captured", "upi", 100)
        ]
        assert recorded[0]["url"] == "https://api.razorpay.com/v1/orders/order_X/payments"

    def test_refund(self, calls):
        recorded, answers = calls
        answers.append(
            {"id": "rfnd_A", "payment_id": "pay_A", "amount": 100, "status": "processed"}
        )
        refund = RazorpayGateway().refund(payment_id="pay_A", amount_paise=100, notes={})
        assert (refund.id, refund.status) == ("rfnd_A", "processed")
        assert recorded[0]["url"] == "https://api.razorpay.com/v1/payments/pay_A/refund"
        assert recorded[0]["body"]["speed"] == "normal"

    @pytest.mark.parametrize(
        "failure",
        [
            urllib.error.HTTPError("u", 502, "Bad Gateway", {}, None),
            urllib.error.URLError("down"),
            TimeoutError(),
        ],
    )
    def test_failures_raise_gateway_errors_without_secrets(self, calls, failure):
        calls[1].append(failure)
        with pytest.raises(PaymentGatewayError) as caught:
            RazorpayGateway().create_order(amount_paise=1, receipt="r", notes={})
        assert "test-secret" not in str(caught.value)

    def test_to_paise(self):
        assert to_paise(Decimal("753.00")) == 75300
        assert to_paise(Decimal("0.01")) == 1


@pytest.mark.django_db
class TestRefundTask:
    @pytest.fixture
    def payment(self):
        order = OrderFactory(
            status="CANCELLED",
            payment_method="ONLINE",
            payment_status="REFUND_PENDING",
            placed_at=None,
        )
        return Payment.objects.create(
            order=order,
            gateway="RAZORPAY",
            gateway_order_id="order_Refund000001",
            gateway_payment_id="pay_Refund0000001",
            amount=order.grand_total,
            status="CAPTURED",
        )

    def test_request_is_idempotent(self, payment, django_capture_on_commit_callbacks):
        with django_capture_on_commit_callbacks(execute=True) as callbacks:
            first = request_refund(
                payment, payment.amount, reason=LATE_CAPTURE, key="capture:pay_R"
            )
            again = request_refund(
                payment, payment.amount, reason=LATE_CAPTURE, key="capture:pay_R"
            )
        assert first.pk == again.pk
        assert len(callbacks) == 1  # one gateway call only
        refund = Refund.objects.get()
        assert (refund.status, refund.order.payment_status) == ("PROCESSED", "REFUNDED")
        assert refund.order.amount_refunded == refund.amount

    def test_task_skips_settled_and_waiting_refunds(self, payment):
        refund = Refund.objects.create(
            payment=payment, order=payment.order, amount=Decimal(1), reason=DUPLICATE_CAPTURE,
            idempotency_key="k1", status="PROCESSED",
        )  # fmt: skip
        assert process_refund(refund.pk) == "skipped"
        refund.status, refund.gateway_refund_id = "PENDING", "rfnd_Already0001"
        refund.save()
        assert process_refund(refund.pk) == "waiting"
        assert process_refund(999999) == "skipped"

    def test_gateway_error_leaves_it_pending_for_a_retry(self, payment, monkeypatch):
        def down(self, **kwargs):
            raise PaymentGatewayError("down")

        monkeypatch.setattr(FakeRazorpayGateway, "refund", down)
        refund = Refund.objects.create(
            payment=payment, order=payment.order, amount=Decimal(1), reason=LATE_CAPTURE,
            idempotency_key="k2",
        )  # fmt: skip
        with pytest.raises(PaymentGatewayError):
            process_refund.run(refund.pk)
        refund.refresh_from_db()
        assert (refund.status, refund.gateway_refund_id) == ("PENDING", "")

    def test_failed_refund_is_logged(self, payment, monkeypatch, caplog):
        from apps.payments.gateways import GatewayRefund

        monkeypatch.setattr(
            FakeRazorpayGateway, "refund",
            lambda self, **kw: GatewayRefund("rfnd_Failed00001", kw["payment_id"], 1, "failed"),
        )  # fmt: skip
        refund = Refund.objects.create(
            payment=payment, order=payment.order, amount=Decimal(1), reason=LATE_CAPTURE,
            idempotency_key="k3",
        )  # fmt: skip
        assert process_refund(refund.pk) == "failed"
        refund.refresh_from_db()
        assert refund.status == "FAILED"
        assert "failed at the gateway" in caplog.text
