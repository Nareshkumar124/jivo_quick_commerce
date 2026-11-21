"""Refund auto-retry (Razorpay test findings 2026-11-21): a 4xx refusal of the refund POST that
may be transient keeps the refund PENDING and `process_refund` tries again later
(`REFUND_REFUSAL_RETRY_DELAYS_SECONDS`), always starting with the lookup by receipt. Only after the
last try, or on a final refusal, is the refund FAILED with the ops alert."""

from datetime import timedelta

import pytest
from django.utils import timezone

from apps.orders.tests.factories import OrderFactory
from apps.payments import order_refunds
from apps.payments.gateways import (
    FakeRazorpayGateway,
    GatewayRefund,
    PaymentGatewayRejected,
    refund_receipt,
)
from apps.payments.models import Payment, Refund
from apps.payments.refunds import LATE_CAPTURE
from apps.payments.tasks import process_refund

pytestmark = pytest.mark.django_db

TRANSIENT = "The request is invalid: invalid request sent"


@pytest.fixture
def refund_row():
    order = OrderFactory(
        status="CANCELLED", payment_method="ONLINE", payment_status="REFUND_PENDING",
        placed_at=None,
    )  # fmt: skip
    payment = Payment.objects.create(
        order=order, gateway="RAZORPAY", gateway_order_id="order_Refusal00001",
        gateway_payment_id="pay_Refusal000001", amount=order.grand_total, status="CAPTURED",
    )  # fmt: skip
    return Refund.objects.create(
        payment=payment, order=order, amount=payment.amount, reason=LATE_CAPTURE,
        idempotency_key="capture:pay_Refusal000001",
    )  # fmt: skip


@pytest.fixture
def scheduled(monkeypatch):
    """The countdowns of the retries `process_refund` schedules (not run)."""
    calls: list[int] = []
    monkeypatch.setattr(
        process_refund, "apply_async", lambda args, countdown: calls.append(countdown)
    )
    return calls


@pytest.fixture
def gateway(monkeypatch):
    """The fake gateway refuses the refund POST while `refusals` holds descriptions."""

    class State:
        refusals: list[str] = []
        posts = 0
        made: list[GatewayRefund] = []

    original = FakeRazorpayGateway.refund

    def refund(self, **kwargs):
        State.posts += 1
        if State.refusals:
            raise PaymentGatewayRejected("HTTP 400", description=State.refusals.pop(0))
        return original(self, **kwargs)

    monkeypatch.setattr(FakeRazorpayGateway, "refund", refund)
    monkeypatch.setattr(FakeRazorpayGateway, "fetch_payment_refunds", lambda self, pid: State.made)
    return State


def due_now(refund: Refund) -> None:
    """Move the scheduled retry into the past, as if its countdown has passed."""
    Refund.objects.filter(pk=refund.pk).update(
        next_attempt_at=timezone.now() - timedelta(seconds=1)
    )


def run(refund, callbacks):
    with callbacks(execute=True):
        return process_refund(refund.pk)


class TestRefusalRetry:
    def test_transient_refusal_then_success(
        self, refund_row, gateway, scheduled, caplog, django_capture_on_commit_callbacks
    ):
        gateway.refusals = [TRANSIENT]
        assert run(refund_row, django_capture_on_commit_callbacks) == "retry_scheduled"
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.gateway_refusals) == ("PENDING", 1)
        assert refund_row.next_attempt_at > timezone.now() + timedelta(seconds=100)
        assert scheduled == [120]
        assert f"refused by the gateway: HTTP 400 ({TRANSIENT})" in caplog.text
        assert "trying again in 120 s" in caplog.text
        assert "Ops alert" not in caplog.text
        # A run before the scheduled time (a redelivery) does nothing.
        assert process_refund(refund_row.pk) == "scheduled"
        assert gateway.posts == 1
        due_now(refund_row)
        assert run(refund_row, django_capture_on_commit_callbacks) == "processed"
        refund_row.refresh_from_db()
        assert refund_row.status == "PROCESSED"
        assert refund_row.order.payment_status == "REFUNDED"
        assert gateway.posts == 2

    def test_refused_on_every_try_fails_once_with_one_alert(
        self, refund_row, gateway, scheduled, settings, caplog, django_capture_on_commit_callbacks
    ):
        settings.REFUND_REFUSAL_RETRY_DELAYS_SECONDS = [60, 300]
        gateway.refusals = [TRANSIENT] * 5
        assert run(refund_row, django_capture_on_commit_callbacks) == "retry_scheduled"
        due_now(refund_row)
        assert run(refund_row, django_capture_on_commit_callbacks) == "retry_scheduled"
        due_now(refund_row)
        assert run(refund_row, django_capture_on_commit_callbacks) == "rejected"
        assert scheduled == [60, 300]
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.gateway_refusals) == ("FAILED", 3)
        assert refund_row.next_attempt_at is None
        assert caplog.text.count("Ops alert: payment.refund_failed") == 1
        assert "refusal 3, failing it" in caplog.text
        assert process_refund(refund_row.pk) == "skipped"  # a late scheduled run
        assert gateway.posts == 3

    def test_no_delays_fails_on_the_first_refusal(
        self, refund_row, gateway, scheduled, settings, django_capture_on_commit_callbacks
    ):
        settings.REFUND_REFUSAL_RETRY_DELAYS_SECONDS = []
        gateway.refusals = [TRANSIENT]
        assert run(refund_row, django_capture_on_commit_callbacks) == "rejected"
        assert scheduled == []
        assert Refund.objects.get(pk=refund_row.pk).status == "FAILED"

    @pytest.mark.parametrize(
        "description",
        [
            "The refund amount provided is greater than amount captured",
            "Total refund amount is greater than the refund payment amount",
            "Amount must be at least INR 1.00",
        ],
    )
    def test_permanent_refusal_fails_fast(
        self, refund_row, gateway, scheduled, description, caplog,
        django_capture_on_commit_callbacks,
    ):  # fmt: skip
        gateway.refusals = [description]
        assert run(refund_row, django_capture_on_commit_callbacks) == "rejected"
        assert scheduled == []
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.gateway_refusals) == ("FAILED", 1)
        assert caplog.text.count("Ops alert: payment.refund_failed") == 1

    def test_already_done_not_found_still_fails_fast(
        self, refund_row, gateway, scheduled, django_capture_on_commit_callbacks
    ):
        gateway.refusals = ["Duplicate receipt found"]
        assert run(refund_row, django_capture_on_commit_callbacks) == "rejected"
        assert scheduled == []
        assert Refund.objects.get(pk=refund_row.pk).status == "FAILED"

    def test_already_done_found_is_recorded(
        self, refund_row, gateway, scheduled, monkeypatch, django_capture_on_commit_callbacks
    ):
        receipt = refund_receipt(refund_row.idempotency_key)
        gateway.refusals = ["The payment has been fully refunded already"]
        lookups = []

        def lookup(self, pid):
            lookups.append(pid)
            if len(lookups) == 1:
                return []
            return [GatewayRefund("rfnd_Found0000001", pid, 1, "processed", receipt)]

        monkeypatch.setattr(FakeRazorpayGateway, "fetch_payment_refunds", lookup)
        assert run(refund_row, django_capture_on_commit_callbacks) == "processed"
        assert scheduled == []
        refund_row.refresh_from_db()
        assert (refund_row.gateway_refund_id, refund_row.gateway_refusals) == (
            "rfnd_Found0000001",
            0,
        )

    def test_retry_looks_up_first_and_never_posts_twice(
        self, refund_row, gateway, scheduled, django_capture_on_commit_callbacks
    ):
        """The gateway made the refund between tries (its answer to the refused call was wrong):
        the scheduled run finds it by receipt and records it without a second POST."""
        gateway.refusals = [TRANSIENT]
        assert run(refund_row, django_capture_on_commit_callbacks) == "retry_scheduled"
        gateway.made = [
            GatewayRefund(
                "rfnd_Between00001", "pay_Refusal000001", 1, "processed",
                refund_receipt(refund_row.idempotency_key),
            )
        ]  # fmt: skip
        due_now(refund_row)
        assert run(refund_row, django_capture_on_commit_callbacks) == "processed"
        assert gateway.posts == 1
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.gateway_refund_id) == (
            "PROCESSED",
            "rfnd_Between00001",
        )

    def test_recorded_by_a_webhook_during_the_refused_call(
        self, refund_row, monkeypatch, scheduled, django_capture_on_commit_callbacks
    ):
        def refund(self, **kwargs):
            Refund.objects.filter(pk=refund_row.pk).update(gateway_refund_id="rfnd_Webhook00001")
            raise PaymentGatewayRejected("HTTP 400", description=TRANSIENT)

        monkeypatch.setattr(FakeRazorpayGateway, "refund", refund)
        assert run(refund_row, django_capture_on_commit_callbacks) == "skipped"
        assert scheduled == []
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.gateway_refusals) == ("PENDING", 0)

    def test_scheduled_retry_is_queued_with_its_countdown(
        self, refund_row, gateway, monkeypatch, django_capture_on_commit_callbacks
    ):
        sent = []
        monkeypatch.setattr(
            process_refund, "apply_async", lambda args, countdown: sent.append((args, countdown))
        )
        gateway.refusals = [TRANSIENT]
        with django_capture_on_commit_callbacks(execute=False) as callbacks:
            assert process_refund(refund_row.pk) == "retry_scheduled"
        assert sent == []  # only after commit
        for callback in callbacks:
            callback()
        assert sent == [((refund_row.pk,), 120)]


class TestRefusalRetryWithSyncAndOps:
    def waiting(self, refund_row, *, due_in: timedelta, touched_ago: timedelta) -> None:
        now = timezone.now()
        Refund.objects.filter(pk=refund_row.pk).update(
            gateway_refusals=3, next_attempt_at=now + due_in, updated_at=now - touched_ago
        )

    def test_sync_leaves_a_scheduled_retry_alone(self, refund_row):
        self.waiting(refund_row, due_in=timedelta(minutes=20), touched_ago=timedelta(minutes=15))
        assert order_refunds.sync_refund_status() == {"waiting": 1}

    def test_sync_resends_a_lost_scheduled_retry(
        self, refund_row, django_capture_on_commit_callbacks
    ):
        self.waiting(refund_row, due_in=-timedelta(minutes=11), touched_ago=timedelta(minutes=40))
        with django_capture_on_commit_callbacks(execute=True):
            assert order_refunds.sync_refund_status() == {"resent": 1}
        assert Refund.objects.get(pk=refund_row.pk).status == "PROCESSED"

    def test_ops_retry_sends_a_waiting_refund_now(
        self, refund_row, superuser, django_capture_on_commit_callbacks
    ):
        self.waiting(refund_row, due_in=timedelta(minutes=40), touched_ago=timedelta(minutes=15))
        with django_capture_on_commit_callbacks(execute=True):
            assert order_refunds.retry_refund(refund_row.pk, by=superuser).pk == refund_row.pk
        refund_row.refresh_from_db()
        assert (refund_row.status, refund_row.next_attempt_at) == ("PROCESSED", None)
