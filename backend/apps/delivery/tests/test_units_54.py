"""Slice 5.4 units: the Razorpay QR Codes calls (no network), the fake gateway, the dev command
`fake_cod_qr_payment`, earnings truncation and the 5.4 role permissions."""

from decimal import Decimal
from io import StringIO

import pytest
from django.contrib.auth.models import Group
from django.core.management import CommandError, call_command

from apps.accounts import roles
from apps.delivery.choices import CodQrStatus
from apps.delivery.models import CodQr
from apps.delivery.services import earnings
from apps.payments.gateways import (
    FakeRazorpayGateway,
    PaymentGatewayRejected,
    RazorpayGateway,
)


@pytest.fixture
def razorpay(settings, monkeypatch):
    settings.RAZORPAY_KEY_ID = "rzp_test_key"
    settings.RAZORPAY_KEY_SECRET = "secret"
    settings.RAZORPAY_WEBHOOK_SECRET = "hook"
    calls = []
    answers = {}

    def call(self, method, path, body=None):
        calls.append((method, path, body))
        answer = answers.get((method, path), {})
        if isinstance(answer, Exception):
            raise answer
        return answer

    monkeypatch.setattr(RazorpayGateway, "_call", call)
    return RazorpayGateway(), calls, answers


def test_razorpay_create_qr(razorpay):
    gateway, calls, answers = razorpay
    answers[("POST", "/payments/qr_codes")] = {
        "id": "qr_Abc1234567890X",
        "image_url": "https://rzp.io/i/qr.png",
        "payment_amount": 34900,
        "status": "active",
    }
    qr = gateway.create_qr_code(
        amount_paise=34900, close_by=1_900_000_000, description="Jivo order X", notes={"a": "1"}
    )
    assert qr.id == "qr_Abc1234567890X"
    assert qr.amount_paise == 34900
    _method, _path, body = calls[0]
    assert body["usage"] == "single_use"
    assert body["fixed_amount"] is True
    assert body["payment_amount"] == 34900
    assert body["type"] == "upi_qr"
    assert gateway.qr_available is True


def test_razorpay_close_and_fetch(razorpay, settings):
    gateway, _calls, answers = razorpay
    path = "/payments/qr_codes/qr_Abc1234567890X/close"
    answers[("POST", path)] = PaymentGatewayRejected("x", description="QR code is already closed")
    gateway.close_qr_code("qr_Abc1234567890X")  # already closed: fine
    answers[("POST", path)] = PaymentGatewayRejected("x", description="bad request")
    with pytest.raises(PaymentGatewayRejected):
        gateway.close_qr_code("qr_Abc1234567890X")
    answers[("GET", "/payments/qr_codes/qr_Abc1234567890X/payments")] = {
        "items": [{"id": "pay_Q1234567890ab", "amount": 34900, "status": "captured"}]
    }
    payments = gateway.fetch_qr_payments("qr_Abc1234567890X")
    assert payments[0].id == "pay_Q1234567890ab"
    assert payments[0].amount_paise == 34900
    settings.RAZORPAY_KEY_SECRET = ""
    assert gateway.qr_available is False


def test_fake_gateway_qr(db):
    gateway = FakeRazorpayGateway()
    qr = gateway.create_qr_code(amount_paise=100, close_by=0, description="x", notes={})
    assert qr.id.startswith("qr_")
    assert qr.image_url.startswith("https://")
    gateway.close_qr_code(qr.id)
    assert gateway.fetch_qr_payments(qr.id) == []


# --------------------------------------------------------------------------- dev command


@pytest.fixture
def open_qr(place, store_steps, make_rider, rider_client):
    from apps.delivery.tests.test_task_flow import Flow

    order = place()
    store_steps.accept(order)
    rider = make_rider()
    f = Flow(order, rider, rider_client(rider), store_steps)
    f.to_customer()
    body = f.client.post(f.url("cod-qr")).json()
    return f, body


@pytest.mark.django_db
def test_fake_cod_qr_payment_command(open_qr, settings):
    f, qr = open_qr
    out = StringIO()
    call_command("fake_cod_qr_payment", f.order.order_number, stdout=out)
    assert "PAID" in out.getvalue()
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.PAID
    with pytest.raises(CommandError, match="No open UPI QR"):
        call_command("fake_cod_qr_payment", f.order.order_number)
    settings.PAYMENT_GATEWAY = "apps.payments.gateways.RazorpayGateway"
    with pytest.raises(CommandError, match="fake payment gateway"):
        call_command("fake_cod_qr_payment", f.order.order_number)


@pytest.mark.django_db
def test_fake_cod_qr_payment_wrong_amount_is_refunded(open_qr):
    f, qr = open_qr
    out = StringIO()
    call_command("fake_cod_qr_payment", f.order.order_number, "--amount", "1.00", stdout=out)
    assert CodQr.objects.get(gateway_qr_id=qr["qr_id"]).status == CodQrStatus.CANCELLED


# --------------------------------------------------------------------------- earnings / roles


@pytest.mark.django_db
def test_earnings_orders_are_truncated(monkeypatch, place, store_steps, make_rider, rider_client):
    from apps.delivery.tests.test_task_flow import Flow

    order = place()
    store_steps.accept(order)
    rider = make_rider()
    f = Flow(order, rider, rider_client(rider), store_steps)
    f.to_customer()
    assert f.deliver().status_code == 200
    monkeypatch.setattr(earnings, "MAX_ORDERS", 0)
    body = f.client.get("/api/v1/rider/earnings/").json()
    assert body["orders"] == []
    assert body["orders_truncated"] is True
    assert body["orders_count"] == 1
    assert Decimal(body["total"]) > 0


@pytest.mark.django_db
def test_slice_54_role_permissions():
    """05 §3 / DL-61: cash deposits (Super Admin, Ops, Store Manager, Finance); ops delivery
    actions not for Support or Store Staff; COD block lift (Super Admin, Ops); Payouts (Super
    Admin, Finance); cash adjustments Super Admin only (PM default)."""
    roles.sync_roles()

    def perms(role):
        group = Group.objects.get(name=role)
        return {f"{p.content_type.app_label}.{p.codename}" for p in group.permissions.all()}

    assert "delivery.record_cash_deposit" in perms(roles.STORE_MANAGER)
    assert "delivery.record_cash_deposit" in perms(roles.FINANCE)  # DL-61 (a)
    assert "delivery.record_cash_deposit" in perms(roles.OPS)
    assert "delivery.lift_cod_block" in perms(roles.OPS)
    for role in (roles.STORE_MANAGER, roles.FINANCE, roles.SUPPORT, roles.STORE_STAFF):
        assert "delivery.lift_cod_block" not in perms(role)
    for role in (roles.SUPPORT, roles.STORE_STAFF):
        assert not {"delivery.record_cash_deposit", "delivery.dispatch_order"} & perms(role)
    assert "delivery.view_ridercashledger" in perms(roles.FINANCE)
    assert "delivery.manage_payouts" in perms(roles.FINANCE)
    assert "delivery.manage_payouts" not in perms(roles.OPS)
    assert "delivery.view_rider" not in perms(roles.FINANCE)
    for role in (roles.OPS, roles.STORE_MANAGER, roles.FINANCE, roles.SUPPORT):
        assert "delivery.adjust_cash" not in perms(role)
        assert "delivery.change_earningrule" not in perms(role)
    admin = perms(roles.SUPER_ADMIN)
    assert {"delivery.adjust_cash", "delivery.add_earningrule", "delivery.manage_payouts"} <= admin
