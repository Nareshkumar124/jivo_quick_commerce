"""Coupons admin: personal coupons (`Coupon.owner`, 07 §2.5; added 2026-11-13).

- The owner is chosen only when a coupon is created (an active customer's id) and is read-only
  afterwards, also against a crafted POST.
- The owner is shown per the PII policy (05 §3 "Customers (PII)"): Finance and Catalog Manager
  see a masked phone; roles with full customer access see it in full. The raw-id input never
  shows `str(user)` (the phone), and its lookup opens the Customers admin only for those roles.
- The list shows the owner and filters personal / public coupons.
"""

from decimal import Decimal

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.ops_console.tests.helpers import admin_form_data, offer_editor, staff_in_role
from apps.promotions import services
from apps.promotions.admin import MSG_OWNER_NOT_CUSTOMER, PUBLIC_COUPON
from apps.promotions.models import Coupon

pytestmark = pytest.mark.django_db

ADD = "admin:promotions_coupon_add"
LIST = "admin:promotions_coupon_changelist"

PHONE = "+919811122233"
MASKED = "+91 XXXXXX2233"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def customer():
    return UserFactory(name="Asha Verma", phone=PHONE)


@pytest.fixture
def public():
    return Coupon.objects.create(
        code="JIVO50", title="Flat ₹50 off", discount_type="FLAT", value=Decimal("50.00")
    )


def personal_for(owner) -> Coupon:
    return services.create_personal_coupon(
        owner,
        amount=Decimal("90.00"),
        valid_days=30,
        min_order_value=Decimal("0.00"),
        title="₹90 off: referral reward",
        now=timezone.now(),
    )


@pytest.fixture
def personal(customer):
    return personal_for(customer)


def login_role(client, role):
    user = staff_in_role(role)
    client.force_login(user)
    return user


def login_editor(client):
    """A coupon editor without full customer access (ADR 0004: a Catalog Manager also
    given `promotions.manage_offers`)."""
    user = offer_editor()
    client.force_login(user)
    return user


def add_data(**overrides) -> dict:
    data = {
        "code": "GOODWILL1",
        "title": "Sorry for the delay",
        "description": "",
        "discount_type": "FLAT",
        "value": "40.00",
        "max_discount": "",
        "min_order_value": "0",
        "starts_at_0": "",
        "starts_at_1": "",
        "ends_at_0": "",
        "ends_at_1": "",
        "usage_limit_total": "1",
        "usage_limit_per_user": "1",
        "is_active": "on",
        "is_visible": "on",
        "owner": "",
        "_save": "Save",
    }
    data.update(overrides)
    return data


# --------------------------------------------------------------------------- list


class TestList:
    @pytest.mark.parametrize(
        ("role", "full"),
        [
            (roles.SUPER_ADMIN, True),
            (roles.SUPPORT, True),
            (roles.CATALOG_MANAGER, False),
            (roles.FINANCE, False),
        ],
    )
    def test_owner_column_per_pii_policy(self, client, public, personal, role, full):
        login_role(client, role)
        response = client.get(reverse(LIST))
        html = response.content.decode()
        assert response.status_code == 200
        assert "Personal for" in html
        assert PUBLIC_COUPON in html
        assert "Asha Verma" in html
        assert (PHONE in html) is full
        assert (MASKED in html) is not full

    def test_audience_says_personal(self, client, personal):
        login_role(client, roles.CATALOG_MANAGER)
        response = client.get(reverse(LIST))
        row = response.context["cl"].result_list[0]
        assert response.context["cl"].model_admin.audience(row) == "Personal"

    @pytest.mark.parametrize(
        ("kind", "expected"), [("personal", "personal"), ("public", "public"), (None, "both")]
    )
    def test_personal_public_filter(self, client, public, personal, kind, expected):
        login_role(client, roles.CATALOG_MANAGER)
        params = {"kind": kind} if kind else {}
        response = client.get(reverse(LIST), params)
        assert response.status_code == 200
        found = set(response.context["cl"].result_list)
        wanted = {"personal": {personal}, "public": {public}, "both": {public, personal}}
        assert found == wanted[expected]
        assert "Personal (one customer)" in response.content.decode()

    def test_list_queries_do_not_grow_with_personal_coupons(self, client, public):
        login_role(client, roles.FINANCE)
        personal_for(UserFactory())
        client.get(reverse(LIST))  # warm-up (first-request caches)
        with CaptureQueriesContext(connection) as few:
            assert client.get(reverse(LIST)).status_code == 200
        for _ in range(4):
            personal_for(UserFactory())
        with CaptureQueriesContext(connection) as many:
            assert client.get(reverse(LIST)).status_code == 200
        assert len(many) == len(few)


# --------------------------------------------------------------------------- create


class TestCreate:
    def test_public_by_default(self, client):
        login_editor(client)
        response = client.post(reverse(ADD), add_data())
        assert response.status_code == 302, response.context["adminform"].form.errors
        assert Coupon.objects.get(code="GOODWILL1").owner is None

    def test_personal_for_a_customer(self, client, customer):
        login_editor(client)
        response = client.post(reverse(ADD), add_data(owner=str(customer.pk)))
        assert response.status_code == 302, response.context["adminform"].form.errors
        assert Coupon.objects.get(code="GOODWILL1").owner == customer

    @pytest.mark.parametrize("who", ["staff", "blocked", "missing", "text"])
    def test_owner_must_be_an_active_customer(self, client, who):
        manager = login_editor(client)
        value = {
            "staff": lambda: str(manager.pk),
            "blocked": lambda: str(UserFactory(is_active=False).pk),
            "missing": lambda: "999999999",
            "text": lambda: "abc",
        }[who]()
        response = client.post(reverse(ADD), add_data(owner=value))
        assert response.status_code == 200
        assert response.context["adminform"].form.errors["owner"] == [MSG_OWNER_NOT_CUSTOMER]
        assert not Coupon.objects.filter(code="GOODWILL1").exists()

    def test_limited_role_gets_a_masked_label_and_no_lookup(self, client, customer):
        login_editor(client)
        html = client.get(reverse(ADD)).content.decode()
        assert 'name="owner"' in html
        assert "lookup_id_owner" not in html
        # A refused save shows the form again with the owner's label: masked.
        response = client.post(reverse(ADD), add_data(owner=str(customer.pk), code=""))
        assert response.status_code == 200
        assert "code" in response.context["adminform"].form.errors
        html = response.content.decode()
        assert f"Asha Verma, {MASKED}" in html
        assert PHONE not in html
        assert reverse("admin:accounts_customer_change", args=[customer.pk]) not in html

    def test_full_pii_role_gets_the_customers_lookup(self, client, customer):
        login_role(client, roles.SUPER_ADMIN)
        html = client.get(reverse(ADD)).content.decode()
        assert "lookup_id_owner" in html
        assert reverse("admin:accounts_customer_changelist") + "?_to_field=id" in html
        response = client.post(reverse(ADD), add_data(owner=str(customer.pk), code=""))
        assert response.status_code == 200
        html = response.content.decode()
        assert f"Asha Verma, {PHONE}" in html
        assert reverse("admin:accounts_customer_change", args=[customer.pk]) in html


# --------------------------------------------------------------------------- existing coupons


class TestOwnerIsReadOnlyOnceSaved:
    @pytest.mark.parametrize("kind", ["personal", "public"])
    def test_crafted_post_cannot_change_the_owner(self, client, customer, public, personal, kind):
        coupon = personal if kind == "personal" else public
        login_editor(client)
        url = reverse("admin:promotions_coupon_change", args=[coupon.pk])
        response = client.get(url)
        assert 'name="owner"' not in response.content.decode()
        data = admin_form_data(response)
        data["title"] = "Edited title"
        data["owner"] = str(UserFactory().pk)
        response = client.post(url, data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        coupon.refresh_from_db()
        assert coupon.title == "Edited title"  # the rest of the form saved
        assert coupon.owner == (customer if kind == "personal" else None)

    @pytest.mark.parametrize(("role", "full"), [(roles.SUPPORT, True), (roles.FINANCE, False)])
    def test_change_page_shows_the_owner_per_pii_policy(self, client, personal, role, full):
        login_role(client, role)
        url = reverse("admin:promotions_coupon_change", args=[personal.pk])
        html = client.get(url).content.decode()
        assert "Who can use it" in html
        assert (f"Asha Verma, {PHONE}" in html) is full
        assert (f"Asha Verma, {MASKED}" in html) is not full

    def test_public_coupon_page_says_public(self, client, public):
        login_role(client, roles.CATALOG_MANAGER)
        url = reverse("admin:promotions_coupon_change", args=[public.pk])
        assert PUBLIC_COUPON in client.get(url).content.decode()

    def test_history_pages_never_show_the_phone(self, client, personal):
        login_role(client, roles.CATALOG_MANAGER)
        history = reverse("admin:promotions_coupon_history", args=[personal.pk])
        assert client.get(history).status_code == 200
        version = personal.history.first()
        url = reverse(
            "admin:promotions_coupon_simple_history", args=[personal.pk, version.history_id]
        )
        response = client.get(url)
        assert response.status_code == 200
        assert PHONE not in response.content.decode()
