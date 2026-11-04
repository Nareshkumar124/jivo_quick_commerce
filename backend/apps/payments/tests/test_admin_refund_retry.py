"""Refunds admin: "Retry failed refund" (T-401c, admin half). One call per selected refund to
`payments.order_refunds.retry_refund(refund_id, by=)` through `ops_console.order_actions`; the
service owns role, scope, state, "never twice" and the audit entry. Capability `retry_refund`
(`payments.issue_refund`: Super Admin, Finance, Support)."""

from decimal import Decimal

import pytest
from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME
from django.urls import reverse

from apps.accounts import roles
from apps.ops_console import order_actions
from apps.ops_console.tests.helpers import (
    PAYMENT_VIEW_ROLES,
    RETRY_REFUND_ROLES,
    login_as,
    staff_in_role,
)
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, Refund, RefundStatus

pytestmark = [
    pytest.mark.django_db,
    pytest.mark.skipif(
        not order_actions.available(order_actions.RETRY_REFUND),
        reason="payments.order_refunds.retry_refund is not on this branch yet (backend P4)",
    ),
]

LIST = "admin:payments_refund_changelist"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def failed():
    order = OrderFactory(payment_method="ONLINE", payment_status="PAID")
    payment = Payment.objects.create(
        order=order,
        gateway="RAZORPAY",
        gateway_order_id="order_R1",
        gateway_payment_id="pay_R1",
        amount=Decimal("300.00"),
        status="CAPTURED",
        method="upi",
    )
    return Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("100.00"),
        reason="Order cancelled",
        idempotency_key="t11:1",
        status=RefundStatus.FAILED,
    )


def run_action(client, *refunds):
    return client.post(
        reverse(LIST),
        {"action": "retry_failed", ACTION_CHECKBOX_NAME: [str(r.pk) for r in refunds]},
        follow=True,
    )


def action_names(response) -> list[str]:
    action_form = response.context["action_form"]
    return [name for name, _label in action_form.fields["action"].choices] if action_form else []


@pytest.mark.parametrize("role", sorted(PAYMENT_VIEW_ROLES - {"superuser flag"}))
def test_action_offered_only_to_refund_roles(client, failed, role):
    client.force_login(staff_in_role(role))
    names = action_names(client.get(reverse(LIST)))
    assert ("retry_failed" in names) is (role in RETRY_REFUND_ROLES), role


def test_retry_creates_a_new_refund_once(client, failed):
    staff = login_as(client, roles.FINANCE)
    response = run_action(client, failed)
    assert "Sent 1 refund(s)" in response.content.decode()
    retry = Refund.objects.exclude(pk=failed.pk).get()
    assert retry.amount == failed.amount
    assert retry.initiated_by == staff
    # Retrying the same failed refund again is refused by the service (never twice).
    response = run_action(client, failed)
    assert "Skipped 1 refund(s)" in response.content.decode()
    assert Refund.objects.count() == 2


def test_retry_is_audited(client, failed):
    from apps.core.models import AuditLog

    staff = login_as(client, roles.SUPER_ADMIN)
    run_action(client, failed)
    assert AuditLog.objects.filter(actor=staff, action="refund.retry").exists()


def test_processed_refund_is_skipped_with_the_service_message(client, failed):
    failed.status = RefundStatus.PROCESSED
    failed.save(update_fields=["status"])
    login_as(client, roles.SUPER_ADMIN)
    response = run_action(client, failed)
    assert "can be retried" in response.content.decode()
    assert Refund.objects.count() == 1
