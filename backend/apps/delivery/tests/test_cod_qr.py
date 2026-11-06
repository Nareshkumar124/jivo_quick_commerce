"""Slice 5.4 (T-514b): COD by UPI QR (06 §3 `cod-qr`, api-requests #16, 08 T10/T13). The amount
always comes from the server-side order; the server confirms payment (signed webhook or gateway
lookup); any credit that is not needed is refunded in full.

Test case IDs are provisional backend IDs (P5-TC-40 to P5-TC-49) until QA's P5 repository
assigns its own."""

import json
from datetime import timedelta
from decimal import Decimal

import pytest
from celery.exceptions import Retry
from django.utils import timezone
from freezegun import freeze_time

from apps.delivery import hooks
from apps.delivery.choices import CodQrStatus
from apps.delivery.models import CodQr, DeliveryTask, RiderCashLedger, RiderEarning
from apps.delivery.services import cod_qr
from apps.delivery.tests.test_task_flow import Flow
from apps.orders.choices import OrderStatus, PaymentStatus
from apps.payments.gateways import (
    FAKE_WEBHOOK_SECRET,
    GatewayPayment,
    GatewayUnavailable,
    razorpay_webhook_signature,
)
from apps.payments.models import Payment, PaymentWebhookEvent, Refund
from apps.payments.refunds import COD_QR_UNUSED

pytestmark = pytest.mark.django_db

WEBHOOK = "/api/v1/payments/razorpay/webhook/"


@pytest.fixture
def flow(place, make_rider, rider_client, store_steps):
    def make(method="COD", rider=None):
        order = place(method)
        store_steps.accept(order)
        rider = rider or make_rider()
        return Flow(order, rider, rider_client(rider), store_steps)

    return make


@pytest.fixture
def at_customer(flow):
    f = flow()
    f.to_customer()
    return f


def qr_url(f) -> str:
    return f.url("cod-qr")


def credit_event(qr_id: str, amount_paise: int, payment_id: str, status="captured") -> dict:
    return {
        "entity": "event",
        "event": "qr_code.credited",
        "payload": {
            "qr_code": {"entity": {"id": qr_id, "status": "closed"}},
            "payment": {
                "entity": {
                    "id": payment_id,
                    "amount": amount_paise,
                    "status": status,
                    "method": "upi",
                    "order_id": None,
                }
            },
        },
    }


def post_event(client, event: dict, event_id: str):
    raw = json.dumps(event).encode()
    return client.generic(
        "POST",
        WEBHOOK,
        raw,
        content_type="application/json",
        headers={
            "X-Razorpay-Signature": razorpay_webhook_signature(FAKE_WEBHOOK_SECRET, raw),
            "X-Razorpay-Event-Id": event_id,
        },
    )


def pay(api_client, qr: dict, payment_id="pay_QrPayment00001", amount=None, event_id="evt_qr_1"):
    paise = int(Decimal(amount or qr["amount"]) * 100)
    return post_event(api_client, credit_event(qr["qr_id"], paise, payment_id), event_id)


# --------------------------------------------------------------------------- the QR


def test_qr_is_for_the_server_amount_and_repeats_return_it(at_customer):
    """P5-TC-40: cod-qr gives one open QR for exactly the order's grand_total; a repeat returns
    the same QR; the task shows it (`cod_qr`) for polling."""
    f = at_customer
    first = f.client.post(qr_url(f))
    assert first.status_code == 200, first.json()
    body = first.json()
    assert body["amount"] == str(f.order.grand_total)
    assert body["status"] == "PENDING"
    assert body["qr_id"].startswith("qr_")
    assert body["image_url"].startswith("https://")
    again = f.client.post(qr_url(f)).json()
    assert again["qr_id"] == body["qr_id"]
    assert CodQr.objects.filter(task_id=f.task_id).count() == 1
    current = f.client.get("/api/v1/rider/tasks/current/").json()["task"]
    assert current["cod_qr"]["qr_id"] == body["qr_id"]
    assert current["cod_qr"]["status"] == "PENDING"


def test_qr_guards(flow, at_customer, make_rider, rider_client, settings):
    """P5-TC-41: prepaid -> 409; before arriving -> 409; another rider's task -> 404 (IDOR);
    switched off or gateway down -> 503 (take cash); a non-ACTIVE caller -> 403."""
    prepaid = flow("ONLINE")
    prepaid.to_customer()
    response = prepaid.client.post(qr_url(prepaid))
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "INVALID_STATE_TRANSITION"

    early = flow()
    early.accept()
    assert early.client.post(qr_url(early)).status_code == 409

    other = rider_client(make_rider((28.4510, 77.05)))
    assert other.post(qr_url(at_customer)).status_code == 404

    settings.COD_UPI_QR_ENABLED = False
    off = at_customer.client.post(qr_url(at_customer))
    assert off.status_code == 503
    assert off.json()["error"]["code"] == "SERVICE_UNAVAILABLE"
    settings.COD_UPI_QR_ENABLED = True
    settings.FAKE_GATEWAY_DOWN = True
    assert at_customer.client.post(qr_url(at_customer)).status_code == 503
    settings.FAKE_GATEWAY_DOWN = False
    assert not CodQr.objects.filter(task_id=at_customer.task_id).exists()


def test_real_gateway_without_keys_is_unavailable(at_customer, settings):
    """Gate on settings: the real gateway with no Razorpay keys answers 503, never a 500."""
    settings.PAYMENT_GATEWAY = "apps.payments.gateways.RazorpayGateway"
    settings.RAZORPAY_KEY_ID = ""
    assert cod_qr.available() is False
    response = at_customer.client.post(qr_url(at_customer))
    assert response.status_code == 503


def test_expired_qr_is_replaced(at_customer, settings):
    settings.COD_QR_EXPIRY_SECONDS = 60  # inside the 15-minute access token
    f = at_customer
    first = f.client.post(qr_url(f)).json()
    later = timezone.now() + timedelta(seconds=settings.COD_QR_EXPIRY_SECONDS + 5)
    current = f.client.get("/api/v1/rider/tasks/current/")
    assert current.json()["task"]["cod_qr"]["status"] == "PENDING"
    with freeze_time(later):
        task = DeliveryTask.objects.get(pk=f.task_id)
        assert cod_qr.display_status(cod_qr.current(task)) == CodQrStatus.EXPIRED
        second = f.client.post(qr_url(f)).json()
    assert second["qr_id"] != first["qr_id"]
    assert CodQr.objects.get(gateway_qr_id=first["qr_id"]).status == CodQrStatus.EXPIRED


# --------------------------------------------------------------------------- UPI delivery


def test_upi_paid_by_webhook_then_delivered(at_customer, api_client):
    """P5-TC-42: the signed `qr_code.credited` webhook marks the QR PAID; `deliver` with upi then
    completes T10: COD_COLLECTED, nothing into the rider's cash, earnings recorded."""
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    response = pay(api_client, qr)
    assert response.status_code == 200, response.content
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.PAID
    assert f.client.get("/api/v1/rider/tasks/current/").json()["task"]["cod_qr"]["status"] == "PAID"
    payment = Payment.objects.get(gateway_payment_id="pay_QrPayment00001")
    assert payment.gateway == "RAZORPAY_QR"
    assert payment.amount == f.order.grand_total
    # A repeat of the event is a no-op.
    assert pay(api_client, qr).status_code == 200
    assert Payment.objects.filter(gateway_payment_id="pay_QrPayment00001").count() == 1

    delivered = f.deliver(cod={"mode": "upi", "amount": qr["amount"]})
    assert delivered.status_code == 200, delivered.json()
    assert delivered.json()["status"] == "DELIVERED"
    f.order.refresh_from_db()
    assert f.order.status == OrderStatus.DELIVERED
    assert f.order.payment_status == PaymentStatus.COD_COLLECTED
    assert not RiderCashLedger.objects.filter(rider=f.rider).exists()
    assert RiderEarning.objects.filter(task_id=f.task_id).exists()
    assert not Refund.objects.filter(payment=payment).exists()


def test_upi_not_paid_uses_no_otp_attempt(at_customer):
    """P5-TC-43: upi before the payment is confirmed -> 400, and no OTP attempt is used."""
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    response = f.deliver(cod={"mode": "upi", "amount": qr["amount"]})
    assert response.status_code == 400
    assert response.json()["error"]["details"]["cod"] == ["The UPI payment is not confirmed yet."]
    assert DeliveryTask.objects.get(pk=f.task_id).otp_attempts == 0
    # Never the client's amount: a different upi amount is refused too.
    wrong = f.deliver(cod={"mode": "upi", "amount": "1.00"})
    assert wrong.status_code == 400
    assert "amount_due" in wrong.json()["error"]["details"]


def test_missed_webhook_is_found_by_the_gateway_lookup(at_customer, monkeypatch):
    """A lost webhook: `deliver` with upi asks the gateway for the QR's payments first."""
    from apps.payments import gateways

    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    paise = int(Decimal(qr["amount"]) * 100)

    def lookup(self, qr_id):
        assert qr_id == qr["qr_id"]
        return [GatewayPayment("pay_QrMissedHook001", "", paise, "captured", "upi")]

    monkeypatch.setattr(gateways.FakeRazorpayGateway, "fetch_qr_payments", lookup)
    response = f.deliver(cod={"mode": "upi", "amount": qr["amount"]})
    assert response.status_code == 200, response.json()
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.PAID


def test_gateway_lookup_failure_is_harmless(at_customer, monkeypatch):
    from apps.payments import gateways

    f = at_customer
    qr = f.client.post(qr_url(f)).json()

    def down(self, qr_id):
        raise GatewayUnavailable("down")

    monkeypatch.setattr(gateways.FakeRazorpayGateway, "fetch_qr_payments", down)
    response = f.deliver(cod={"mode": "upi", "amount": qr["amount"]})
    assert response.status_code == 400
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.PENDING


# --------------------------------------------------------------------------- cash vs QR


def test_cash_closes_the_qr_and_a_late_payment_is_refunded(
    at_customer, api_client, django_capture_on_commit_callbacks, monkeypatch
):
    """P5-TC-44: cash taken while the QR is open closes it (CANCELLED, closed at the gateway
    after commit); a payment that still arrives is refunded in full and ops are alerted."""
    from apps.payments import gateways

    closed, alerts = [], []
    monkeypatch.setattr(
        gateways.FakeRazorpayGateway, "close_qr_code", lambda self, qr_id: closed.append(qr_id)
    )
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    with django_capture_on_commit_callbacks(execute=True):
        assert f.deliver().status_code == 200
    stored = CodQr.objects.get(gateway_qr_id=qr["qr_id"])
    assert stored.status == CodQrStatus.CANCELLED
    assert closed == [qr["qr_id"]]
    assert RiderCashLedger.objects.get(rider=f.rider).amount == f.order.grand_total

    with django_capture_on_commit_callbacks(execute=True):
        response = pay(api_client, qr, payment_id="pay_QrLatePayment01")
    assert response.status_code == 200
    refund = Refund.objects.get(idempotency_key="codqr:pay_QrLatePayment01")
    assert refund.reason == COD_QR_UNUSED
    assert refund.amount == f.order.grand_total
    assert "COD_QR_REFUNDED" in alerts
    f.order.refresh_from_db()
    assert f.order.payment_status == PaymentStatus.COD_COLLECTED  # the cash stands
    # The customer sees it as a payment issue refund, not goodwill.
    body = f.order.refunds.get()
    assert body.reason == COD_QR_UNUSED


def test_cash_refused_once_the_qr_is_paid(at_customer, api_client):
    """P5-TC-45: the customer already paid by UPI: cash is refused (no double collection)."""
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    pay(api_client, qr)
    response = f.deliver()
    assert response.status_code == 400
    assert "already paid by UPI" in response.json()["error"]["details"]["cod"][0]
    assert DeliveryTask.objects.get(pk=f.task_id).otp_attempts == 0


def test_wrong_amount_credit_is_refunded(at_customer, api_client):
    """P5-TC-46: a credit that is not the QR amount never pays the order: refunded in full."""
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    response = pay(api_client, qr, payment_id="pay_QrWrongAmount1", amount="1.00")
    assert response.status_code == 200
    assert Refund.objects.get(idempotency_key="codqr:pay_QrWrongAmount1").amount == Decimal("1.00")
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.CANCELLED
    # A new QR can be made after that.
    assert f.client.post(qr_url(f)).json()["qr_id"] != qr["qr_id"]


def test_failed_delivery_refunds_a_paid_qr(at_customer, api_client, monkeypatch):
    """P5-TC-47: T13 on a COD order whose QR was paid: nothing is due, so the UPI payment is
    refunded in full; COD payment_status FAILED."""
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    pay(api_client, qr)
    response = f.client.post(f.url("fail"), {"reason": "CUSTOMER_REFUSED"}, format="multipart")
    assert response.status_code == 200, response.json()
    refund = Refund.objects.get(idempotency_key="codqr:pay_QrPayment00001")
    assert refund.amount == f.order.grand_total
    f.order.refresh_from_db()
    assert f.order.payment_status == PaymentStatus.FAILED


def test_failed_delivery_closes_a_pending_qr(at_customer):
    f = at_customer
    qr = f.client.post(qr_url(f)).json()
    assert (
        f.client.post(f.url("fail"), {"reason": "WRONG_ADDRESS"}, format="multipart").status_code
        == 200
    )
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.CANCELLED


# --------------------------------------------------------------------------- webhook edges


def test_webhook_edges(api_client, at_customer):
    """P5-TC-48: unknown QR ignored; non-captured ignored; malformed id ignored (no 500); a QR
    payment's `payment.captured` (no order_id) is ignored (handled by `qr_code.credited`)."""
    unknown = post_event(
        api_client, credit_event("qr_Unknown0000001", 100, "pay_X0000000001"), "e1"
    )
    assert unknown.status_code == 200
    assert not Payment.objects.filter(gateway_payment_id="pay_X0000000001").exists()
    qr = at_customer.client.post(qr_url(at_customer)).json()
    failed = credit_event(qr["qr_id"], 100, "pay_X0000000002", status="failed")
    assert post_event(api_client, failed, "e2").status_code == 200
    bad = credit_event("not-a-qr", 100, "pay_X0000000003")
    assert post_event(api_client, bad, "e3").status_code == 200
    assert PaymentWebhookEvent.objects.get(event_id="e3").error.startswith("malformed")
    captured = {
        "entity": "event",
        "event": "payment.captured",
        "payload": {"payment": {"entity": {"id": "pay_X0000000004", "order_id": None}}},
    }
    assert post_event(api_client, captured, "e4").status_code == 200
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.PENDING


def test_record_credit_rejects_a_zero_amount(at_customer):
    qr = at_customer.client.post(qr_url(at_customer)).json()
    with pytest.raises(ValueError, match="positive"):
        cod_qr.record_credit(qr["qr_id"], payment_id="pay_Zero000000001", amount_paise=0)


def test_close_cod_qr_task(monkeypatch):
    """The Celery task is idempotent: closed, refused (logged), or retried when unreachable."""
    from apps.delivery.tasks import close_cod_qr
    from apps.payments import gateways

    assert close_cod_qr.apply(args=["qr_Close000000001"]).get() == "closed"

    def refused(self, qr_id):
        raise gateways.PaymentGatewayRejected("no", status=400, description="bad")

    monkeypatch.setattr(gateways.FakeRazorpayGateway, "close_qr_code", refused)
    assert close_cod_qr.apply(args=["qr_Close000000001"]).get() == "refused"

    def down(self, qr_id):
        raise GatewayUnavailable("down")

    monkeypatch.setattr(gateways.FakeRazorpayGateway, "close_qr_code", down)
    with pytest.raises(Retry):
        close_cod_qr.apply(args=["qr_Close000000001"]).get()
