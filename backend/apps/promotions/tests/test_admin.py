"""Coupons admin (05 §2 "Coupons", 05 §3 "Coupons"; DL-45, DL-46; T-304).

- Role matrix: Super Admin and Catalog Manager manage; Support and Finance view; others 403.
- Validation on the server: no negative or zero values, percent at most 100, a cap for percent
  coupons and none for flat ones, end after start, codes unique ignoring case.
- History (django-simple-history) records who changed a coupon; it is view-only.
- Redemptions: read-only list per coupon; customers per the PII policy.
"""

from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory, UserFactory
from apps.catalog.tests.factories import CategoryFactory
from apps.ops_console.tests.helpers import (
    COUPON_EDIT_ROLES,
    COUPON_VIEW_ROLES,
    FULL_PII_ROLES,
    PRINCIPALS,
    expected_status,
    login_as,
    staff_in_role,
)
from apps.orders.tests.factories import OrderFactory
from apps.promotions.admin import MSG_CAP_REQUIRED, MSG_CODE_TAKEN, MSG_NO_CAP_ON_FLAT
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

ADD = "admin:promotions_coupon_add"
LIST = "admin:promotions_coupon_changelist"
REDEMPTIONS = "admin:promotions_couponredemption_changelist"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def coupon():
    return Coupon.objects.create(
        code="JIVO50",
        title="Flat ₹50 off",
        discount_type="FLAT",
        value=Decimal("50.00"),
        min_order_value=Decimal("299.00"),
    )


@pytest.fixture
def redemption(coupon):
    customer = UserFactory(name="Asha Verma", phone="+919811122233")
    order = OrderFactory(
        user=customer,
        order_number="JV-ADMIN-000101",
        coupon=coupon,
        coupon_code=coupon.code,
        coupon_discount=Decimal("50.00"),
        grand_total=Decimal("250.00"),
    )
    return CouponRedemption.objects.create(
        coupon=coupon,
        user=customer,
        order=order,
        discount_amount=Decimal("50.00"),
        status=RedemptionStatus.APPLIED,
    )


def form_data(**overrides) -> dict:
    data = {
        "code": "save20",
        "title": "20% off",
        "description": "",
        "discount_type": "PERCENT",
        "value": "20",
        "max_discount": "100.00",
        "min_order_value": "0",
        "starts_at_0": "",
        "starts_at_1": "",
        "ends_at_0": "",
        "ends_at_1": "",
        "usage_limit_total": "",
        "usage_limit_per_user": "1",
        "is_active": "on",
        "is_visible": "on",
        "_save": "Save",
    }
    data.update(overrides)
    return {key: value for key, value in data.items() if value is not None}


# --------------------------------------------------------------------------- role matrix

PAGES = {
    "changelist": (COUPON_VIEW_ROLES, False),
    "change": (COUPON_VIEW_ROLES, True),
    "history": (COUPON_VIEW_ROLES, True),
    "add": (COUPON_EDIT_ROLES, False),
}


@pytest.mark.parametrize("page", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_coupon_page_matrix(client, coupon, principal, page):
    allowed, with_obj = PAGES[page]
    login_as(client, principal)
    args = [coupon.pk] if with_obj else []
    response = client.get(reverse(f"admin:promotions_coupon_{page}", args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, page)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_redemption_list_matrix(client, redemption, principal):
    login_as(client, principal)
    response = client.get(reverse(REDEMPTIONS))
    assert response.status_code == expected_status(principal, COUPON_VIEW_ROLES)


@pytest.mark.parametrize("principal", sorted(COUPON_VIEW_ROLES))
def test_edit_only_for_coupon_managers(client, coupon, principal):
    login_as(client, principal)
    url = reverse("admin:promotions_coupon_change", args=[coupon.pk])
    html = client.get(url).content.decode()
    can_edit = principal in COUPON_EDIT_ROLES
    assert ('name="_save"' in html) is can_edit
    response = client.post(url, form_data(code="JIVO50", title="Changed"))
    coupon.refresh_from_db()
    if can_edit:
        assert response.status_code == 302, response.content
        assert coupon.title == "Changed"
    else:
        assert response.status_code == 403
        assert coupon.title == "Flat ₹50 off"


# --------------------------------------------------------------------------- create and validate


class TestCreate:
    @pytest.fixture
    def manager(self, client):
        user = staff_in_role(roles.CATALOG_MANAGER)
        client.force_login(user)
        return user

    def post(self, client, **overrides):
        return client.post(reverse(ADD), form_data(**overrides))

    def test_percent_with_cap_categories_and_stores(self, client, manager):
        oils = CategoryFactory(name="Edible Oils", slug="edible-oils")
        store = DarkStoreFactory()
        response = self.post(
            client,
            code=" oils15 ",
            value="15",
            max_discount="150.00",
            categories=[oils.pk],
            stores=[store.pk],
            first_order_only="on",
            is_visible=None,
            starts_at_0="2026-11-10",
            starts_at_1="09:00:00",
            ends_at_0="2026-11-30",
            ends_at_1="23:59:00",
        )
        assert response.status_code == 302, response.context["adminform"].form.errors
        coupon = Coupon.objects.get()
        assert coupon.code == "OILS15"
        assert coupon.first_order_only is True
        assert coupon.is_visible is False  # hidden code
        assert list(coupon.categories.all()) == [oils]
        assert list(coupon.stores.all()) == [store]
        # Admin times are IST (staff time zone): 09:00 IST is 03:30 UTC.
        assert coupon.starts_at.isoformat() == "2026-11-10T03:30:00+00:00"
        assert coupon.usage_limit_per_user == 1

    def test_flat_coupon_and_default_per_user_limit(self, client, manager):
        response = self.post(
            client, code="FLAT40", discount_type="FLAT", value="40.00", max_discount=""
        )
        assert response.status_code == 302
        coupon = Coupon.objects.get(code="FLAT40")
        assert coupon.max_discount is None
        assert coupon.usage_limit_per_user == 1

    def test_add_page_defaults_per_user_limit_to_one(self, client, manager):
        form = client.get(reverse(ADD)).context["adminform"].form
        assert form["usage_limit_per_user"].value() == 1

    @pytest.mark.parametrize(
        ("overrides", "field", "message"),
        [
            ({"value": "150"}, "value", "A percent coupon is at most 100."),
            ({"value": "0"}, "value", None),
            ({"value": "-5"}, "value", None),
            ({"max_discount": ""}, "max_discount", MSG_CAP_REQUIRED),
            ({"max_discount": "-1"}, "max_discount", None),
            ({"min_order_value": "-1"}, "min_order_value", None),
            (
                {"discount_type": "FLAT", "value": "50", "max_discount": "20"},
                "max_discount",
                MSG_NO_CAP_ON_FLAT,
            ),
            ({"usage_limit_total": "-1"}, "usage_limit_total", None),
            ({"usage_limit_per_user": "-1"}, "usage_limit_per_user", None),
            (
                {
                    "starts_at_0": "2026-11-30",
                    "starts_at_1": "10:00:00",
                    "ends_at_0": "2026-11-01",
                    "ends_at_1": "10:00:00",
                },
                "ends_at",
                "Must be after the start.",
            ),
            ({"code": "SAVE 20"}, "code", None),
            ({"code": "   "}, "code", None),
        ],
    )
    def test_invalid_values_are_form_errors(self, client, manager, overrides, field, message):
        response = self.post(client, **overrides)
        assert response.status_code == 200
        errors = response.context["adminform"].form.errors
        assert field in errors, errors
        if message:
            assert message in errors[field]
        assert not Coupon.objects.exists()

    def test_code_is_unique_ignoring_case(self, client, manager, coupon):
        response = self.post(client, code="jivo50", discount_type="FLAT", max_discount="")
        assert response.status_code == 200
        assert MSG_CODE_TAKEN in response.context["adminform"].form.errors["code"]
        assert Coupon.objects.count() == 1

    def test_saving_a_coupon_keeps_its_own_code(self, client, manager, coupon):
        url = reverse("admin:promotions_coupon_change", args=[coupon.pk])
        response = client.post(
            url, form_data(code="jivo50", discount_type="FLAT", value="60", max_discount="")
        )
        assert response.status_code == 302
        coupon.refresh_from_db()
        assert coupon.value == Decimal("60.00")

    @pytest.mark.parametrize("principal", [roles.SUPPORT, roles.FINANCE, roles.OPS])
    def test_others_cannot_add(self, client, principal):
        client.force_login(staff_in_role(principal))
        assert client.post(reverse(ADD), form_data()).status_code == 403
        assert not Coupon.objects.exists()


# --------------------------------------------------------------------------- history, delete


class TestHistoryAndDelete:
    def test_changes_record_who_made_them(self, client, coupon):
        manager = staff_in_role(roles.CATALOG_MANAGER, name="Kiran Catalog")
        client.force_login(manager)
        url = reverse("admin:promotions_coupon_change", args=[coupon.pk])
        client.post(
            url, form_data(code="JIVO50", discount_type="FLAT", value="75", max_discount="")
        )
        latest = coupon.history.latest()
        assert latest.history_user == manager
        assert latest.value == Decimal("75.00")
        client.force_login(staff_in_role(roles.FINANCE))
        history = client.get(reverse("admin:promotions_coupon_history", args=[coupon.pk]))
        assert history.status_code == 200
        version = reverse("admin:promotions_coupon_simple_history", args=[coupon.pk, latest.pk])
        assert client.post(version, {"_save": "Revert"}).status_code == 403

    def test_unused_coupon_can_be_deleted(self, client, coupon):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        url = reverse("admin:promotions_coupon_delete", args=[coupon.pk])
        assert client.post(url, {"post": "yes"}).status_code == 302
        assert not Coupon.objects.exists()

    def test_used_coupon_cannot_be_deleted(self, client, coupon, redemption):
        client.force_login(SuperUserFactory())
        url = reverse("admin:promotions_coupon_delete", args=[coupon.pk])
        assert client.get(url).status_code == 403
        assert client.post(url, {"post": "yes"}).status_code == 403
        assert Coupon.objects.filter(pk=coupon.pk).exists()

    def test_no_bulk_delete(self, client, coupon):
        client.force_login(SuperUserFactory())
        html = client.get(reverse(LIST)).content.decode()
        assert "delete_selected" not in html


# --------------------------------------------------------------------------- list, redemptions


class TestListAndRedemptions:
    def test_list_columns(self, client, coupon, redemption):
        Coupon.objects.create(
            code="JIVO10",
            title="10% off",
            discount_type="PERCENT",
            value=Decimal("10.00"),
            max_discount=Decimal("100.00"),
            is_visible=False,
            first_order_only=True,
        )
        client.force_login(staff_in_role(roles.SUPPORT))
        html = client.get(reverse(LIST)).content.decode()
        assert "₹50.00 off" in html
        assert "10% off, up to ₹100.00" in html
        assert "First order, Hidden code" in html
        assert "1 / no limit" in html  # one applied use
        assert "Live" in html

    @pytest.mark.parametrize(
        ("state", "shown"),
        [("live", "JIVO50"), ("inactive", "OFF1"), ("expired", "OLD1")],
    )
    def test_state_filter(self, client, coupon, state, shown):
        from django.utils import timezone

        now = timezone.now()
        Coupon.objects.create(
            code="OFF1", title="Off", discount_type="FLAT", value=Decimal("5"), is_active=False
        )
        Coupon.objects.create(
            code="OLD1",
            title="Old",
            discount_type="FLAT",
            value=Decimal("5"),
            starts_at=now - timezone.timedelta(days=10),
            ends_at=now - timezone.timedelta(days=1),
        )
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(reverse(LIST), {"state": state})
        assert [c.code for c in response.context["cl"].result_list] == [shown]

    def test_coupon_page_links_to_its_redemptions(self, client, coupon, redemption):
        other = Coupon.objects.create(
            code="OTHER", title="Other", discount_type="FLAT", value=Decimal("10")
        )
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        html = client.get(
            reverse("admin:promotions_coupon_change", args=[coupon.pk])
        ).content.decode()
        link = f"{reverse(REDEMPTIONS)}?coupon={coupon.pk}"
        assert link in html
        assert "Applied: 1" in html
        assert [r.pk for r in client.get(link).context["cl"].result_list] == [redemption.pk]
        other_link = f"{reverse(REDEMPTIONS)}?coupon={other.pk}"
        assert list(client.get(other_link).context["cl"].result_list) == []

    @pytest.mark.parametrize("principal", sorted(COUPON_VIEW_ROLES))
    def test_redemption_customer_per_pii_policy(self, client, redemption, principal):
        login_as(client, principal)
        html = client.get(reverse(REDEMPTIONS)).content.decode()
        assert "JV-ADMIN-000101" in html
        assert "₹50.00" in html
        assert "Asha Verma" in html
        if principal in FULL_PII_ROLES:
            assert "+919811122233" in html
        else:
            assert "+919811122233" not in html
            assert "+91 XXXXXX2233" in html

    def test_redemptions_are_read_only(self, client, redemption):
        client.force_login(SuperUserFactory())
        change = reverse("admin:promotions_couponredemption_change", args=[redemption.pk])
        assert 'name="_save"' not in client.get(change).content.decode()
        assert client.post(change, {"status": "REVERSED"}).status_code == 403
        assert client.get(reverse("admin:promotions_couponredemption_add")).status_code == 403
        delete = reverse("admin:promotions_couponredemption_delete", args=[redemption.pk])
        assert client.get(delete).status_code == 403
        redemption.refresh_from_db()
        assert redemption.status == RedemptionStatus.APPLIED


class TestRedemptionScopeAndQueries:
    def test_other_store_redemptions_are_not_reachable(self, client, coupon, redemption):
        """No store role holds redemption permissions (DL-46); if one is ever granted, rows
        stay limited to the user's stores (through the order)."""
        from django.contrib.auth.models import Permission

        from apps.stores.services import grant_store_access

        own = redemption.order.store
        other_order = OrderFactory(order_number="JV-ADMIN-000909", coupon=coupon)
        other = CouponRedemption.objects.create(
            coupon=coupon,
            user=other_order.user,
            order=other_order,
            discount_amount=Decimal("50.00"),
            status=RedemptionStatus.APPLIED,
        )
        manager = staff_in_role(roles.STORE_MANAGER)
        grant_store_access(manager, own)
        manager.user_permissions.add(Permission.objects.get(codename="view_couponredemption"))
        client.force_login(manager)
        response = client.get(reverse(REDEMPTIONS))
        assert [r.pk for r in response.context["cl"].result_list] == [redemption.pk]
        assert other_order.store.code not in response.content.decode()
        change = reverse("admin:promotions_couponredemption_change", args=[other.pk])
        assert client.get(change).status_code == 404

    def test_list_queries_do_not_grow_with_rows(
        self, client, coupon, django_assert_max_num_queries
    ):
        from django.db import connection
        from django.test.utils import CaptureQueriesContext

        client.force_login(staff_in_role(roles.SUPPORT))

        def count(rows):
            for _ in range(rows):
                order = OrderFactory(coupon=coupon)
                CouponRedemption.objects.create(
                    coupon=coupon,
                    user=order.user,
                    order=order,
                    discount_amount=Decimal("50.00"),
                    status=RedemptionStatus.APPLIED,
                )
            with CaptureQueriesContext(connection) as queries:
                assert client.get(reverse(REDEMPTIONS)).status_code == 200
            return len(queries)

        assert count(3) == count(30)
        with django_assert_max_num_queries(15):
            client.get(reverse(REDEMPTIONS))

    def test_coupon_list_queries_do_not_grow_with_rows(self, client, django_assert_max_num_queries):
        from django.db import connection
        from django.test.utils import CaptureQueriesContext

        client.force_login(staff_in_role(roles.FINANCE))
        oils = CategoryFactory()

        def count(rows):
            for _ in range(rows):
                made = Coupon.objects.create(
                    code=f"C{Coupon.objects.count() + 1:04d}",
                    title="T",
                    discount_type="FLAT",
                    value=Decimal("5"),
                )
                made.categories.add(oils)
            with CaptureQueriesContext(connection) as queries:
                assert client.get(reverse(LIST)).status_code == 200
            return len(queries)

        assert count(3) == count(30)
