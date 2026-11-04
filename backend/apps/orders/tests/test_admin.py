"""Orders admin, Phase 3 read-only (05 §2 "Orders", 05 §3; T-304).

- Role matrix: the 7 roles, a superuser flag, a non-staff user and an anonymous visitor.
- Store scoping: Store Manager / Store Staff see only their stores; another store's order is
  never listed and its pages are 404.
- PII: full customer and address for `accounts.view_customer` roles; masked phone, locality only
  and no phone search for everyone else.
- Read-only for everyone (superusers included); money exactly as stored.
"""

from datetime import timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from django.contrib.auth.models import Group, Permission
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    FULL_PII_ROLES,
    ORDER_VIEW_ROLES,
    PRINCIPALS,
    STORE_SCOPED,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.models import Order, OrderItem, OrderStatusHistory
from apps.orders.tests.factories import OrderFactory
from apps.payments.models import Payment, Refund
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

PHONE = "+919811122233"
MASKED = "+91 XXXXXX2233"
RECEIVER_PHONE = "+919876543210"  # factories.SNAPSHOT
RECEIVER_MASKED = "+91 XXXXXX3210"
NOTE = "Ring twice, gate code 4455"
IST = ZoneInfo("Asia/Kolkata")


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def shop():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    customer = UserFactory(name="Asha Verma", phone=PHONE)
    own_order = OrderFactory(
        store=own,
        user=customer,
        order_number="JV-ADMIN-000101",
        instructions={"chips": ["Leave at door"], "note": NOTE},
    )
    other_order = OrderFactory(store=other, order_number="JV-ADMIN-000202")
    return {
        "own": own,
        "other": other,
        "customer": customer,
        "order": own_order,
        "other_order": other_order,
    }


def change_url(order) -> str:
    return reverse("admin:orders_order_change", args=[order.pk])


LIST = "admin:orders_order_changelist"


def listed(response) -> list[str]:
    return [order.order_number for order in response.context["cl"].result_list]


# --------------------------------------------------------------------------- role matrix

PAGES = ("changelist", "change", "history")


@pytest.mark.parametrize("page", PAGES)
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, shop, principal, page):
    login_with_stores(client, principal, shop["own"])
    args = [] if page == "changelist" else [shop["order"].pk]
    response = client.get(reverse(f"admin:orders_order_{page}", args=args))
    expected = expected_status(principal, ORDER_VIEW_ROLES)
    assert response.status_code == expected, (principal, page)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


@pytest.mark.parametrize("principal", sorted(ORDER_VIEW_ROLES))
def test_nobody_adds_changes_or_deletes(client, shop, principal):
    """Phase 3 is read-only for every role, superusers included (state changes: P4 services)."""
    login_with_stores(client, principal, shop["own"])
    order = shop["order"]
    html = client.get(change_url(order)).content.decode()
    assert 'name="_save"' not in html
    assert client.get(reverse("admin:orders_order_add")).status_code == 403
    assert client.get(reverse("admin:orders_order_delete", args=[order.pk])).status_code == 403
    response = client.post(change_url(order), {"status": OrderStatus.CANCELLED, "_save": "Save"})
    assert response.status_code == 403
    order.refresh_from_db()
    assert order.status == OrderStatus.PLACED
    changelist = client.get(reverse(LIST))
    assert 'name="action"' not in changelist.content.decode()


# --------------------------------------------------------------------------- store scoping


class TestStoreScoping:
    @pytest.mark.parametrize("role", sorted(STORE_SCOPED))
    def test_list_shows_only_own_store(self, client, shop, role):
        login_with_stores(client, role, shop["own"])
        response = client.get(reverse(LIST))
        assert listed(response) == ["JV-ADMIN-000101"]
        html = response.content.decode()
        assert "NOI-18" not in html  # not even in the store filter
        assert "Jivo Noida 18" not in html

    @pytest.mark.parametrize("role", sorted(STORE_SCOPED))
    def test_other_store_order_is_404(self, client, shop, role):
        login_with_stores(client, role, shop["own"])
        other = shop["other_order"]
        assert client.get(change_url(other)).status_code == 404
        assert client.get(reverse("admin:orders_order_history", args=[other.pk])).status_code == 404

    @pytest.mark.parametrize("role", sorted(STORE_SCOPED))
    def test_store_filter_cannot_reach_another_store(self, client, shop, role):
        login_with_stores(client, role, shop["own"])
        response = client.get(reverse(LIST), {"store": shop["other"].pk})
        assert listed(response) == []

    @pytest.mark.parametrize("role", sorted(STORE_SCOPED))
    def test_search_cannot_reach_another_store(self, client, shop, role):
        login_with_stores(client, role, shop["own"])
        response = client.get(reverse(LIST), {"q": "JV-ADMIN-000202"})
        assert listed(response) == []

    def test_store_role_without_stores_sees_nothing(self, client, shop):
        client.force_login(staff_in_role(roles.STORE_STAFF))
        assert listed(client.get(reverse(LIST))) == []
        assert client.get(change_url(shop["order"])).status_code == 404

    def test_mixed_global_and_store_role_is_still_scoped(self, client, shop):
        """DL-39: the stricter role wins."""
        user = staff_in_role(roles.STORE_MANAGER)
        user.groups.add(Group.objects.get(name=roles.OPS))
        grant_store_access(user, shop["own"])
        client.force_login(user)
        assert listed(client.get(reverse(LIST))) == ["JV-ADMIN-000101"]

    @pytest.mark.parametrize("role", [roles.OPS, roles.SUPPORT, roles.FINANCE, roles.SUPER_ADMIN])
    def test_global_roles_see_every_store(self, client, shop, role):
        client.force_login(staff_in_role(role))
        assert sorted(listed(client.get(reverse(LIST)))) == [
            "JV-ADMIN-000101",
            "JV-ADMIN-000202",
        ]


# --------------------------------------------------------------------------- PII


LIMITED_ORDER_ROLES = sorted(ORDER_VIEW_ROLES - FULL_PII_ROLES)
FULL_ORDER_ROLES = sorted(ORDER_VIEW_ROLES & FULL_PII_ROLES)


class TestPersonalData:
    def test_limited_and_full_roles(self):
        assert set(LIMITED_ORDER_ROLES) == {roles.STORE_MANAGER, roles.STORE_STAFF, roles.FINANCE}
        assert set(FULL_ORDER_ROLES) >= {roles.SUPER_ADMIN, roles.OPS, roles.SUPPORT}

    @pytest.mark.parametrize("principal", LIMITED_ORDER_ROLES)
    def test_limited_roles_see_a_masked_phone_and_the_locality_only(self, client, shop, principal):
        login_with_stores(client, principal, shop["own"])
        OrderStatusHistory.objects.create(
            order=shop["order"],
            from_status="",
            to_status=OrderStatus.PLACED,
            actor=shop["customer"],
            actor_type=ActorType.CUSTOMER,
        )
        for url in (reverse(LIST), change_url(shop["order"])):
            html = client.get(url).content.decode()
            assert MASKED in html
            assert PHONE not in html
            assert "9811122233" not in html
        html = client.get(change_url(shop["order"])).content.decode()
        assert "Asha Verma" in html  # 05 §3 limited: name and masked phone
        assert RECEIVER_MASKED in html
        assert RECEIVER_PHONE not in html
        for street in ("Flat 402", "Sunshine Apartments"):
            assert street not in html
        assert "Sector 14" in html  # area
        assert "Gurugram" in html
        assert NOTE not in html
        assert "Leave at door" in html
        assert reverse("admin:accounts_customer_change", args=[shop["customer"].pk]) not in html

    @pytest.mark.parametrize("principal", FULL_ORDER_ROLES)
    def test_full_roles_see_the_customer_and_address(self, client, shop, principal):
        login_with_stores(client, principal, shop["own"])
        html = client.get(change_url(shop["order"])).content.decode()
        assert PHONE in html
        assert RECEIVER_PHONE in html
        assert "Flat 402" in html
        assert "Sunshine Apartments" in html
        assert NOTE in html
        assert reverse("admin:accounts_customer_change", args=[shop["customer"].pk]) in html

    def test_the_pin_coordinates_and_secrets_are_never_shown(self, client, shop):
        order = shop["order"]
        Order.objects.filter(pk=order.pk).update(
            delivery_otp_hash="otp-hash-secret", request_fingerprint="fingerprint-secret"
        )
        client.force_login(SuperUserFactory())
        html = client.get(change_url(order)).content.decode()
        for secret in ("otp-hash-secret", "fingerprint-secret", order.idempotency_key, "77.05"):
            assert secret not in html

    @pytest.mark.parametrize("principal", LIMITED_ORDER_ROLES)
    def test_limited_roles_cannot_search_by_phone(self, client, shop, principal):
        login_with_stores(client, principal, shop["own"])
        for query in ("9811122233", "2233", "9876543210"):
            assert listed(client.get(reverse(LIST), {"q": query})) == [], query
        assert listed(client.get(reverse(LIST), {"q": "000101"})) == ["JV-ADMIN-000101"]

    @pytest.mark.parametrize("principal", FULL_ORDER_ROLES)
    def test_full_roles_search_by_customer_or_receiver_phone(self, client, shop, principal):
        login_with_stores(client, principal, shop["own"])
        assert listed(client.get(reverse(LIST), {"q": "9811122233"})) == ["JV-ADMIN-000101"]
        assert "JV-ADMIN-000101" in listed(client.get(reverse(LIST), {"q": "9876543210"}))

    def test_customer_actor_and_notes_in_the_timeline_are_masked(self, client, shop):
        order = shop["order"]
        OrderStatusHistory.objects.create(
            order=order,
            from_status=OrderStatus.PLACED,
            to_status=OrderStatus.CANCELLED,
            actor=shop["customer"],
            actor_type=ActorType.CUSTOMER,
            note="Call me on 9811122233 instead",
        )
        OrderStatusHistory.objects.create(
            order=order,
            from_status=OrderStatus.CANCELLED,
            to_status=OrderStatus.CANCELLED,
            actor=None,
            actor_type=ActorType.SYSTEM,
            note="Coupon use reversed",
        )
        Order.objects.filter(pk=order.pk).update(
            status=OrderStatus.CANCELLED,
            cancel_reason="OTHER",
            cancelled_by_type=ActorType.CUSTOMER,
            cancel_note="Wrong address, flat 9B",
        )
        login_with_stores(client, roles.STORE_STAFF, shop["own"])
        html = client.get(change_url(order)).content.decode()
        assert f"Asha Verma, {MASKED}" in html
        assert PHONE not in html
        assert "9811122233" not in html
        assert "flat 9B" not in html
        assert "hidden for your role" in html
        assert "Coupon use reversed" in html  # system notes stay visible
        assert "Other" in html  # the cancel reason itself is not personal data

    def test_full_roles_read_customer_notes(self, client, shop):
        Order.objects.filter(pk=shop["order"].pk).update(
            cancelled_by_type=ActorType.CUSTOMER, cancel_note="Wrong address, flat 9B"
        )
        client.force_login(staff_in_role(roles.SUPPORT))
        assert "flat 9B" in client.get(change_url(shop["order"])).content.decode()


# --------------------------------------------------------------------------- detail content


class TestDetail:
    def test_bill_is_shown_exactly_as_stored(self, client, shop):
        order = OrderFactory(
            store=shop["own"],
            order_number="JV-ADMIN-000303",
            mrp_total=Decimal("1350.00"),
            item_total=Decimal("1229.00"),
            product_discount=Decimal("121.00"),
            coupon_discount=Decimal("100.00"),
            delivery_fee=Decimal("0.00"),
            small_cart_fee=Decimal("0.00"),
            handling_fee=Decimal("5.00"),
            tip=Decimal("20.00"),
            grand_total=Decimal("1154.00"),
            coupon_code="JIVO100",
            payment_method=PaymentMethod.ONLINE,
            payment_status=PaymentStatus.PAID,
        )
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(change_url(order)).content.decode()
        for amount in ("₹1,350.00", "₹1,229.00", "₹121.00", "₹100.00", "₹5.00", "₹20.00"):
            assert amount in html
        assert "₹1,154.00" in html
        assert "Coupon discount (JIVO100)" in html
        assert "Paid" in html

    def test_items_and_status_history(self, client, shop):
        order = shop["order"]
        from apps.catalog.tests.factories import VariantFactory

        variant = VariantFactory(sku="JV-CAN-1L")
        OrderItem.objects.create(
            order=order,
            variant=variant,
            product=variant.product,
            product_name="Jivo Canola Oil",
            variant_name="1 L",
            sku="JV-CAN-1L",
            mrp=Decimal("349.00"),
            selling_price=Decimal("279.00"),
            quantity=2,
            line_total=Decimal("558.00"),
        )
        staff = staff_in_role(roles.OPS, name="Ravi Ops")
        OrderStatusHistory.objects.create(
            order=order,
            from_status=OrderStatus.PAYMENT_PENDING,
            to_status=OrderStatus.PLACED,
            actor=staff,
            actor_type=ActorType.OPS,
        )
        client.force_login(staff)
        html = client.get(change_url(order)).content.decode()
        assert "Jivo Canola Oil" in html
        assert "₹558.00" in html
        assert "Payment pending" in html
        assert "Ravi Ops" in html

    @pytest.mark.parametrize(
        ("principal", "sees_payments"),
        [
            (roles.SUPPORT, True),
            (roles.FINANCE, True),
            (roles.SUPER_ADMIN, True),
            (roles.OPS, False),
            (roles.STORE_MANAGER, False),
            (roles.STORE_STAFF, False),
        ],
    )
    def test_payments_and_refunds_only_for_payment_roles(
        self, client, shop, principal, sees_payments
    ):
        order = shop["order"]
        payment = Payment.objects.create(
            order=order,
            gateway="RAZORPAY",
            gateway_order_id="order_TESTGW1",
            gateway_payment_id="pay_TESTGW1",
            amount=Decimal("300.00"),
            status="CAPTURED",
            method="upi",
        )
        Refund.objects.create(
            payment=payment,
            order=order,
            amount=Decimal("50.00"),
            reason="Duplicate capture",
            idempotency_key="t3a:test",
            gateway_refund_id="rfnd_TESTGW1",
        )
        login_with_stores(client, principal, shop["own"])
        html = client.get(change_url(order)).content.decode()
        assert ("pay_TESTGW1" in html) is sees_payments
        assert ("rfnd_TESTGW1" in html) is sees_payments
        assert ("Automatic" in html) is sees_payments


# --------------------------------------------------------------------------- filters


class TestFilters:
    def test_status_payment_and_store_filters(self, client, shop):
        OrderFactory(
            store=shop["own"],
            order_number="JV-ADMIN-000404",
            status=OrderStatus.PAYMENT_PENDING,
            payment_method=PaymentMethod.ONLINE,
            payment_status=PaymentStatus.PENDING,
            placed_at=None,
        )
        client.force_login(staff_in_role(roles.OPS))
        url = reverse(LIST)
        assert listed(client.get(url, {"status__exact": "PAYMENT_PENDING"})) == ["JV-ADMIN-000404"]
        assert listed(client.get(url, {"payment_method__exact": "ONLINE"})) == ["JV-ADMIN-000404"]
        assert sorted(listed(client.get(url, {"payment_status__exact": "COD_PENDING"}))) == [
            "JV-ADMIN-000101",
            "JV-ADMIN-000202",
        ]
        assert listed(client.get(url, {"store": shop["other"].pk})) == ["JV-ADMIN-000202"]

    def test_today_filter_uses_the_ist_day(self, client, shop):
        """ "Today" starts at midnight IST (18:30 UTC the day before): an order 30 minutes after
        it is today's, one 30 minutes before it is yesterday's, whatever the UTC date says."""
        midnight = timezone.localtime(timezone.now(), IST).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        early = OrderFactory(store=shop["own"], order_number="JV-ADMIN-000505")
        late = OrderFactory(store=shop["own"], order_number="JV-ADMIN-000606")
        Order.objects.filter(pk=early.pk).update(created_at=midnight + timedelta(minutes=1))
        Order.objects.filter(pk=late.pk).update(created_at=midnight - timedelta(minutes=30))
        Order.objects.exclude(pk__in=[early.pk, late.pk]).update(
            created_at=midnight - timedelta(days=40)
        )
        client.force_login(staff_in_role(roles.OPS))
        response = client.get(reverse(LIST))
        spec = next(
            spec for spec in response.context["cl"].filter_specs if spec.title == "order date (IST)"
        )
        today = dict(spec.links)["Today"]
        assert "+05:30" in str(today["created_at__gte"])
        assert listed(client.get(reverse(LIST), today)) == ["JV-ADMIN-000505"]

    def test_direct_permission_without_a_role_sees_no_store(self, client, shop):
        """`view_order` granted directly to staff with no role: the page opens, but
        `stores_for` gives no store (fail closed), so no order is listed or reachable."""
        from apps.accounts.tests.factories import StaffUserFactory

        user = StaffUserFactory()
        user.user_permissions.add(Permission.objects.get(codename="view_order"))
        client.force_login(user)
        assert listed(client.get(reverse(LIST))) == []
        assert client.get(change_url(shop["order"])).status_code == 404


# --------------------------------------------------------------------------- performance


def test_list_queries_do_not_grow_with_rows(client, shop, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.SUPPORT))

    def count(rows):
        for _ in range(rows):
            OrderFactory(store=shop["own"])
        with CaptureQueriesContext(connection) as queries:
            assert client.get(reverse(LIST)).status_code == 200
        return len(queries)

    assert count(3) == count(30)
    with django_assert_max_num_queries(15):
        client.get(reverse(LIST))
