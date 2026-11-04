"""Payments admin, read-only (05 §2 "Payments & refunds", 05 §3 "Refund"; DL-46; T-304).

- Role matrix: payments and refunds for Super Admin, Support and Finance; webhook events for
  Super Admin and Finance only.
- Gateway data: the customer's contact, email, UPI id (VPA) and card details in `Payment.raw` and
  the webhook payload are never rendered, even for superusers.
- Read-only for everyone; scoped to the user's stores through the order (fail-closed defence).
"""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Permission
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    PAYMENT_VIEW_ROLES,
    PRINCIPALS,
    WEBHOOK_ROLES,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, PaymentWebhookEvent, Refund
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

# Gateway data that must never reach the page.
SECRETS = ("asha@okaxis", "asha@example.com", "+919811122233", "card_SECRET42", "4242")


def razorpay_payment(payment_id: str) -> dict:
    return {
        "id": payment_id,
        "entity": "payment",
        "amount": 30000,
        "currency": "INR",
        "status": "captured",
        "order_id": "order_GW1",
        "method": "upi",
        "vpa": "asha@okaxis",
        "email": "asha@example.com",
        "contact": "+919811122233",
        "card_id": "card_SECRET42",
        "card": {"last4": "4242", "network": "Visa"},
        "notes": {"phone": "+919811122233"},
    }


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def data():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    customer = UserFactory(name="Asha Verma", phone="+919811122233")
    order = OrderFactory(store=own, user=customer, order_number="JV-ADMIN-000101")
    other_order = OrderFactory(store=other, order_number="JV-ADMIN-000202")
    payment = Payment.objects.create(
        order=order,
        gateway="RAZORPAY",
        gateway_order_id="order_GW1",
        gateway_payment_id="pay_GW1",
        amount=Decimal("300.00"),
        status="CAPTURED",
        method="upi",
        raw=razorpay_payment("pay_GW1"),
    )
    other_payment = Payment.objects.create(
        order=other_order,
        gateway="RAZORPAY",
        gateway_order_id="order_GW2",
        amount=Decimal("300.00"),
        status="CREATED",
    )
    refund = Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("50.00"),
        reason="Duplicate capture",
        idempotency_key="t3a:1",
        gateway_refund_id="rfnd_GW1",
    )
    event = PaymentWebhookEvent.objects.create(
        event_id="evt_GW1",
        event_type="payment.captured",
        payload={
            "entity": "event",
            "event": "payment.captured",
            "payload": {"payment": {"entity": razorpay_payment("pay_GW1")}},
        },
    )
    return {
        "own": own,
        "other": other,
        "order": order,
        "payment": payment,
        "other_payment": other_payment,
        "refund": refund,
        "event": event,
    }


PAGES = {
    # url name -> (allowed, object key or None)
    "admin:payments_payment_changelist": (PAYMENT_VIEW_ROLES, None),
    "admin:payments_payment_change": (PAYMENT_VIEW_ROLES, "payment"),
    "admin:payments_refund_changelist": (PAYMENT_VIEW_ROLES, None),
    "admin:payments_refund_change": (PAYMENT_VIEW_ROLES, "refund"),
    "admin:payments_paymentwebhookevent_changelist": (WEBHOOK_ROLES, None),
    "admin:payments_paymentwebhookevent_change": (WEBHOOK_ROLES, "event"),
}


@pytest.mark.parametrize("url_name", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, data, principal, url_name):
    allowed, key = PAGES[url_name]
    login_with_stores(client, principal, data["own"])
    args = [data[key].pk] if key else []
    response = client.get(reverse(url_name, args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


@pytest.mark.parametrize("model", ["payment", "refund", "paymentwebhookevent"])
def test_read_only_even_for_superusers(client, data, model):
    client.force_login(SuperUserFactory())
    key = {"payment": "payment", "refund": "refund", "paymentwebhookevent": "event"}[model]
    obj = data[key]
    change = reverse(f"admin:payments_{model}_change", args=[obj.pk])
    html = client.get(change).content.decode()
    assert 'name="_save"' not in html
    assert client.post(change, {"_save": "Save"}).status_code == 403
    assert client.get(reverse(f"admin:payments_{model}_add")).status_code == 403
    assert client.get(reverse(f"admin:payments_{model}_delete", args=[obj.pk])).status_code == 403
    changelist = client.get(reverse(f"admin:payments_{model}_changelist")).content.decode()
    assert 'name="action"' not in changelist


class TestGatewayData:
    @pytest.mark.parametrize("principal", [roles.FINANCE, roles.SUPPORT, roles.SUPER_ADMIN])
    def test_payment_page_hides_contact_vpa_and_card(self, client, data, principal):
        client.force_login(staff_in_role(principal))
        html = client.get(
            reverse("admin:payments_payment_change", args=[data["payment"].pk])
        ).content.decode()
        assert "pay_GW1" in html
        assert "₹300.00" in html
        assert "captured" in html  # from the allow-listed gateway summary
        for secret in SECRETS:
            assert secret not in html, secret

    def test_webhook_page_hides_contact_vpa_and_card(self, client, data):
        client.force_login(SuperUserFactory())
        html = client.get(
            reverse("admin:payments_paymentwebhookevent_change", args=[data["event"].pk])
        ).content.decode()
        assert "evt_GW1" in html
        assert "pay_GW1" in html
        for secret in SECRETS:
            assert secret not in html, secret

    def test_lists_never_show_gateway_data(self, client, data):
        client.force_login(SuperUserFactory())
        for model in ("payment", "refund", "paymentwebhookevent"):
            html = client.get(reverse(f"admin:payments_{model}_changelist")).content.decode()
            for secret in SECRETS:
                assert secret not in html, (model, secret)


class TestContent:
    def test_payment_list_search_and_filters(self, client, data):
        client.force_login(staff_in_role(roles.FINANCE))
        url = reverse("admin:payments_payment_changelist")

        def ids(params):
            return [p.pk for p in client.get(url, params).context["cl"].result_list]

        assert ids({"q": "JV-ADMIN-000101"}) == [data["payment"].pk]
        assert ids({"q": "pay_GW1"}) == [data["payment"].pk]
        assert ids({"status__exact": "CREATED"}) == [data["other_payment"].pk]
        assert ids({"store": data["other"].pk}) == [data["other_payment"].pk]

    def test_refund_shows_who_started_it(self, client, data):
        staff = staff_in_role(roles.FINANCE, name="Meera Finance")
        Refund.objects.create(
            payment=data["payment"],
            order=data["order"],
            amount=Decimal("20.00"),
            reason="Item missing",
            idempotency_key="manual:1",
            initiated_by=staff,
        )
        client.force_login(staff)
        html = client.get(reverse("admin:payments_refund_changelist")).content.decode()
        assert "Meera Finance" in html
        assert "Automatic" in html
        assert "₹50.00" in html
        assert "₹20.00" in html

    def test_webhook_filters(self, client, data):
        PaymentWebhookEvent.objects.create(
            event_id="evt_GW2", event_type="refund.processed", payload={}, error="Unknown order"
        )
        client.force_login(staff_in_role(roles.FINANCE))
        url = reverse("admin:payments_paymentwebhookevent_changelist")

        def ids(params):
            return [e.event_id for e in client.get(url, params).context["cl"].result_list]

        assert ids({"processing": "error"}) == ["evt_GW2"]
        assert ids({"q": "evt_GW1"}) == ["evt_GW1"]


class TestStoreScoping:
    """No store role holds payment permissions (DL-46); if one is ever granted, the rows are
    still limited to the user's stores."""

    @pytest.fixture
    def manager(self, data):
        user = staff_in_role(roles.STORE_MANAGER)
        grant_store_access(user, data["own"])
        for codename in ("view_payment", "view_refund"):
            user.user_permissions.add(Permission.objects.get(codename=codename))
        return user

    def test_payments_limited_to_own_store(self, client, data, manager):
        client.force_login(manager)
        response = client.get(reverse("admin:payments_payment_changelist"))
        assert [p.pk for p in response.context["cl"].result_list] == [data["payment"].pk]
        assert "NOI-18" not in response.content.decode()
        other = reverse("admin:payments_payment_change", args=[data["other_payment"].pk])
        assert client.get(other).status_code == 404

    def test_refunds_limited_to_own_store(self, client, data, manager):
        other_refund = Refund.objects.create(
            payment=data["other_payment"],
            order=data["other_payment"].order,
            amount=Decimal("10.00"),
            reason="Test",
            idempotency_key="t3a:2",
        )
        client.force_login(manager)
        response = client.get(reverse("admin:payments_refund_changelist"))
        assert [r.pk for r in response.context["cl"].result_list] == [data["refund"].pk]
        other = reverse("admin:payments_refund_change", args=[other_refund.pk])
        assert client.get(other).status_code == 404


@pytest.mark.parametrize("model", ["payment", "refund"])
def test_list_queries_do_not_grow_with_rows(client, data, model, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.FINANCE))
    url = reverse(f"admin:payments_{model}_changelist")
    serial = iter(range(10_000))

    def count(rows):
        for _ in range(rows):
            n = next(serial)
            order = OrderFactory(store=data["own"])
            payment = Payment.objects.create(
                order=order,
                gateway="RAZORPAY",
                gateway_order_id=f"order_Q{n}",
                amount=Decimal("300.00"),
                status="CAPTURED",
            )
            Refund.objects.create(
                payment=payment,
                order=order,
                amount=Decimal("10.00"),
                reason="Test",
                idempotency_key=f"q:{n}",
                initiated_by=staff_in_role(roles.FINANCE),
            )
        from django.db import connection
        from django.test.utils import CaptureQueriesContext

        with CaptureQueriesContext(connection) as queries:
            assert client.get(url).status_code == 200
        return len(queries)

    assert count(3) == count(30)
    with django_assert_max_num_queries(15):
        client.get(url)
