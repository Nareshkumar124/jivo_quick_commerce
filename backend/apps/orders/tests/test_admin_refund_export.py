"""Orders admin, Phase 4 follow-up (QA stage 2):

- BUG-0010 manual refund (05 §2 Orders "refund (full/partial, within role limit)", 05 §3
  Refund): "Issue refund" for `payments.issue_refund` (Super Admin, Finance; Support up to
  `SUPPORT_REFUND_LIMIT`), through `order_refunds.manual_refund` only, posted once (one-time
  token), refusals as form errors, the server's refundable amount shown.
- BUG-0011 export (05 §2 "export CSV"): store-scoped, masked for roles without full PII, money
  as two-decimal numbers, formula escaping from the project's formats.
"""

import csv
import io
from decimal import Decimal

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.core import export_formats
from apps.ops_console import once
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    NON_STAFF,
    PRINCIPALS,
    login_as,
    login_with_stores,
    staff_in_role,
)
from apps.orders.choices import PaymentMethod, PaymentStatus
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, Refund
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

PHONE = "+919811122233"
MASKED = "+91 XXXXXX2233"
_SA = {roles.SUPER_ADMIN, "superuser flag"}
REFUND_ROLES = frozenset({*_SA, roles.SUPPORT, roles.FINANCE})
ORDER_VIEWERS = frozenset(
    {*_SA, roles.OPS, roles.STORE_MANAGER, roles.STORE_STAFF, roles.SUPPORT, roles.FINANCE}
)


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


def paid_order(store=None, total=Decimal("900.00"), **kwargs):
    order = OrderFactory(
        store=store or DarkStoreFactory(),
        user=kwargs.pop("user", None) or UserFactory(name="Asha Verma"),
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PAID,
        mrp_total=total + Decimal("50.00"),
        item_total=total,
        product_discount=Decimal("50.00"),
        grand_total=total,
        amount_paid=total,
        **kwargs,
    )
    Payment.objects.create(
        order=order,
        gateway="RAZORPAY",
        gateway_order_id=f"order_{order.pk}",
        gateway_payment_id=f"pay_{order.pk}",
        amount=total,
        status="CAPTURED",
        method="upi",
        captured_at=timezone.now(),
    )
    return order


def refund_url(order) -> str:
    return reverse("admin:orders_order_issue_refund", args=[order.pk])


def token_for(client, order) -> str:
    return client.get(refund_url(order)).context["form"]["once"].value()


def post_refund(client, order, amount, token=None, note=""):
    return client.post(
        refund_url(order),
        {
            "amount": amount,
            "note": note,
            "once": token if token is not None else token_for(client, order),
        },
    )


# --------------------------------------------------------------------------- BUG-0010


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_refund_page_role_matrix(client, principal):
    order = paid_order()
    login_as(client, principal)
    response = client.get(refund_url(order))
    if principal in REFUND_ROLES:
        assert response.status_code == 200, principal
        assert 'name="amount"' in response.content.decode()
    elif principal in (NON_STAFF, ANONYMOUS):
        assert response.status_code == 302
    else:
        assert response.status_code == 403, principal


@pytest.mark.parametrize("role", [roles.SUPER_ADMIN, roles.FINANCE, roles.SUPPORT, roles.OPS])
def test_order_page_offers_issue_refund_to_refund_roles_only(client, role):
    order = paid_order()
    client.force_login(staff_in_role(role))
    html = client.get(reverse("admin:orders_order_change", args=[order.pk])).content.decode()
    assert (refund_url(order) in html) is (role in REFUND_ROLES), role


def test_refund_page_shows_the_server_refundable_amount(client):
    order = paid_order()
    Refund.objects.create(
        payment=order.payments.get(),
        order=order,
        amount=Decimal("100.00"),
        reason="manual",
        idempotency_key="manual:x:1",
        status="PROCESSED",
    )
    login_as(client, roles.FINANCE)
    html = client.get(refund_url(order)).content.decode()
    assert "₹800.00" in html  # 900 paid, 100 refunded


def test_finance_partial_refund_goes_through_the_service(client):
    order = paid_order()
    staff = login_as(client, roles.FINANCE)
    response = post_refund(client, order, "250.00", note="Damaged bottle")
    assert response.status_code == 302
    assert response["Location"] == reverse("admin:orders_order_change", args=[order.pk])
    refund = Refund.objects.get(order=order)
    assert refund.amount == Decimal("250.00")
    assert refund.initiated_by == staff
    assert refund.reason == "manual"


def test_support_is_held_to_the_limit(client, settings):
    settings.SUPPORT_REFUND_LIMIT = Decimal("500.00")
    order = paid_order()
    login_as(client, roles.SUPPORT)
    response = post_refund(client, order, "600.00")
    assert response.status_code == 200
    assert "at most ₹500.00" in str(response.context["form"].errors)
    assert not Refund.objects.filter(order=order).exists()
    assert post_refund(client, order, "500.00").status_code == 302
    assert Refund.objects.get(order=order).amount == Decimal("500.00")


def test_same_form_twice_makes_one_refund(client):
    """OBS-P4-01 on the manual refund: the second post of one rendered form is refused."""
    order = paid_order()
    login_as(client, roles.SUPER_ADMIN)
    token = token_for(client, order)
    assert post_refund(client, order, "100.00", token=token).status_code == 302
    again = post_refund(client, order, "100.00", token=token)
    assert again.status_code == 200
    assert once.MSG_REUSED in str(again.context["form"].non_field_errors())
    assert Refund.objects.filter(order=order).count() == 1
    assert 'name="once"' in again.content.decode()
    assert again.context["form"]["once"].value() != token  # a fresh token to retry with
    assert "ops/js/submit_once.js" in again.content.decode()


def test_cod_order_is_refused_by_the_service(client):
    order = OrderFactory(payment_method=PaymentMethod.COD, payment_status=PaymentStatus.COD_PENDING)
    login_as(client, roles.FINANCE)
    page = client.get(refund_url(order)).content.decode()
    assert "Cash on delivery orders have no online payment to refund." in page
    response = post_refund(client, order, "10.00")
    assert response.status_code == 200
    errors = str(response.context["form"].errors)
    assert "At most ₹0.00" in errors or "no online payment" in errors
    assert not Refund.objects.filter(order=order).exists()


def test_above_refundable_is_capped(client):
    order = paid_order(total=Decimal("300.00"))
    login_as(client, roles.FINANCE)
    response = post_refund(client, order, "300.01")
    assert response.status_code == 200
    assert "At most ₹300.00" in str(response.context["form"].errors)
    assert not Refund.objects.filter(order=order).exists()


@pytest.mark.parametrize("amount", ["0", "-5", "10.555", "abc"])
def test_amount_validation(client, amount):
    order = paid_order()
    login_as(client, roles.FINANCE)
    response = post_refund(client, order, amount)
    assert response.status_code == 200
    assert response.context["form"].errors.get("amount")
    assert not Refund.objects.filter(order=order).exists()


def test_other_store_order_is_404_for_scoped_roles(client):
    """No store role may refund; the lookup is scoped anyway (a Finance user sees all stores)."""
    own, other = DarkStoreFactory(), DarkStoreFactory()
    order = paid_order(store=other)
    login_with_stores(client, roles.STORE_MANAGER, own)
    assert client.get(refund_url(order)).status_code == 403


# --------------------------------------------------------------------------- BUG-0011


CSV_FORMAT = str(export_formats.FORMATS.index(export_formats.CSV))


def export_rows(client, **filters) -> list[dict]:
    url = reverse("admin:orders_order_export")
    if filters:
        url += "?" + "&".join(f"{key}={value}" for key, value in filters.items())
    response = client.post(url, {"resource": "0", "format": CSV_FORMAT})
    assert response.status_code == 200, response.content[:300]
    return list(csv.DictReader(io.StringIO(response.content.decode("utf-8-sig"))))


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_export_matrix(client, principal):
    paid_order()
    login_as(client, principal)
    response = client.get(reverse("admin:orders_order_export"))
    if principal in ORDER_VIEWERS:
        assert response.status_code == 200, principal
    elif principal in (NON_STAFF, ANONYMOUS):
        assert response.status_code == 302
    else:
        assert response.status_code == 403, principal


def test_order_list_offers_export(client):
    login_as(client, roles.SUPER_ADMIN)
    html = client.get(reverse("admin:orders_order_changelist")).content.decode()
    assert reverse("admin:orders_order_export") in html


def test_export_full_pii_money_and_formula_escape(client):
    store = DarkStoreFactory(code="GGN-01")
    user = UserFactory(name="=HYPERLINK(1)", phone=PHONE)
    order = paid_order(store=store, user=user, total=Decimal("1299.50"))
    login_as(client, roles.SUPER_ADMIN)
    rows = export_rows(client)
    assert rows, "empty export"
    matching = [r for r in rows if r.get("order_number") == order.order_number]
    assert matching, rows[:1]
    row = matching[0]
    assert row["store"] == "GGN-01"
    assert row["customer_phone"] == PHONE
    assert row["delivery_area"] == "Sector 14, Gurugram, 122001"
    assert row["grand_total"] == "1299.50"
    assert row["amount_refunded"] == "0.00"
    assert row["customer_name"] == "'=HYPERLINK(1)"


def test_export_is_masked_and_store_scoped_for_store_roles(client):
    own, other = DarkStoreFactory(code="GGN-01"), DarkStoreFactory(code="NOI-18")
    mine = paid_order(store=own, user=UserFactory(phone=PHONE))
    theirs = paid_order(store=other, user=UserFactory(phone="+919800000000"))
    login_with_stores(client, roles.STORE_MANAGER, own)
    rows = export_rows(client)
    numbers = {r["order_number"] for r in rows}
    assert mine.order_number in numbers
    assert theirs.order_number not in numbers
    row = next(r for r in rows if r["order_number"] == mine.order_number)
    # "+91 XXXX…" is not a plain number, so the project's formula escaping prefixes "'".
    assert row["customer_phone"] == f"'{MASKED}"
    assert row["delivery_area"] == ""


def test_export_is_audited_and_capped(client, settings):
    from apps.core.models import AuditLog

    settings.ORDERS_EXPORT_MAX_ROWS = 2
    for _ in range(3):
        paid_order()
    staff = login_as(client, roles.FINANCE)
    rows = export_rows(client)
    assert len(rows) == 2
    entry = AuditLog.objects.get(actor=staff, action="orders.export")
    assert entry.changes == {"rows": 2, "matched": 3, "capped": True, "full_pii": False}


def test_export_follows_the_list_filters(client):
    first, second = paid_order(), paid_order()
    login_as(client, roles.FINANCE)
    rows = export_rows(client, customer=str(first.user_id))
    assert {r["order_number"] for r in rows} == {first.order_number}
    assert second.order_number not in {r["order_number"] for r in rows}
