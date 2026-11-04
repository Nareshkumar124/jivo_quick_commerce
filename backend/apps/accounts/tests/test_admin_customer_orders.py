"""Customer detail, Phase 4 (05 §2 "Customers": orders; T-413): recent orders scoped to the
viewer's stores and linked to the order pages, refunds for roles that view refunds, the COD
status, and the "See all orders" link (hidden `customer` filter on the orders list)."""

from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.ops_console.tests.helpers import staff_in_role
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, Refund

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def customer():
    user = UserFactory(name="Asha Verma", phone="+919811122233", cod_blocked=True)
    order = OrderFactory(user=user, order_number="JV-CUST-0001", grand_total=Decimal("300.00"))
    OrderFactory(order_number="JV-CUST-OTHER")  # someone else's
    payment = Payment.objects.create(
        order=order,
        gateway="RAZORPAY",
        gateway_order_id="order_C1",
        amount=Decimal("300.00"),
        status="CAPTURED",
    )
    Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("120.00"),
        reason="Item unavailable",
        idempotency_key="t8a:c1",
    )
    return user


def detail(client, user):
    return client.get(reverse("admin:accounts_customer_change", args=[user.pk])).content.decode()


def test_support_sees_orders_refunds_and_cod(client, customer):
    client.force_login(staff_in_role(roles.SUPPORT))
    html = detail(client, customer)
    assert 'data-testid="customer-orders"' in html
    assert "JV-CUST-0001" in html
    assert "JV-CUST-OTHER" not in html
    assert reverse("admin:orders_order_change", args=[customer.orders.get().pk]) in html
    assert "₹300.00" in html
    assert 'data-testid="customer-refunds"' in html
    assert "₹120.00" in html
    assert "Item unavailable" in html
    assert "COD blocked" in html
    assert f"?customer={customer.pk}" in html


def test_ops_sees_orders_but_not_refunds(client, customer):
    client.force_login(staff_in_role(roles.OPS))
    html = detail(client, customer)
    assert "JV-CUST-0001" in html
    assert 'data-testid="customer-refunds"' not in html


def test_limited_roles_cannot_open_the_customer(client, customer):
    for role in (roles.STORE_MANAGER, roles.STORE_STAFF, roles.FINANCE):
        client.force_login(staff_in_role(role))
        url = reverse("admin:accounts_customer_change", args=[customer.pk])
        assert client.get(url).status_code == 403, role


def test_see_all_orders_link_filters_the_list(client, customer):
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse("admin:orders_order_changelist"), {"customer": customer.pk})
    numbers = [order.order_number for order in response.context["cl"].result_list]
    assert numbers == ["JV-CUST-0001"]
    response = client.get(reverse("admin:orders_order_changelist"), {"customer": "x"})
    assert list(response.context["cl"].result_list) == []


def test_customer_without_orders(client):
    user = UserFactory(name="New Person")
    client.force_login(staff_in_role(roles.SUPPORT))
    assert "No orders yet." in detail(client, user)
