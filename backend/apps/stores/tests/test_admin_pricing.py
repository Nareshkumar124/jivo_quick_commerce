"""Pricing config admin (05 §2 "Pricing config", 05 §3: Super Admin edits, Finance views; DL-43;
T-304).

- Role matrix for the list, change, history and add pages.
- Edits keep history with the staff user; history is view-only; no delete.
- Values are shown in rupees; negative amounts are refused by the model validation.
- Stores without a row are listed with the defaults they are billed with.
"""

from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory
from apps.ops_console.tests.helpers import (
    PRICING_EDIT_ROLES,
    PRICING_VIEW_ROLES,
    PRINCIPALS,
    admin_form_data,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.stores.models import PricingConfig
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

LIST = "admin:stores_pricingconfig_changelist"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")


@pytest.fixture
def pricing(store):
    return PricingConfig.objects.create(store=store)  # D-09 model defaults


def change_url(pricing) -> str:
    return reverse("admin:stores_pricingconfig_change", args=[pricing.pk])


PAGES = {
    "changelist": (PRICING_VIEW_ROLES, False),
    "change": (PRICING_VIEW_ROLES, True),
    "history": (PRICING_VIEW_ROLES, True),
    "add": (PRICING_EDIT_ROLES, False),
}


@pytest.mark.parametrize("page", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, store, pricing, principal, page):
    allowed, with_obj = PAGES[page]
    login_with_stores(client, principal, store)
    args = [pricing.pk] if with_obj else []
    response = client.get(reverse(f"admin:stores_pricingconfig_{page}", args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, page)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


class TestEdit:
    def test_super_admin_edits_and_history_records_who(self, client, pricing):
        admin_user = staff_in_role(roles.SUPER_ADMIN, name="Sana Admin")
        client.force_login(admin_user)
        data = admin_form_data(client.get(change_url(pricing)))
        data.update({"delivery_fee": "30.00", "cod_max_order_value": "1500.00"})
        response = client.post(change_url(pricing), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.delivery_fee == Decimal("30.00")
        assert pricing.cod_max_order_value == Decimal("1500.00")
        latest = pricing.history.latest()
        assert latest.history_user == admin_user
        assert latest.delivery_fee == Decimal("30.00")
        history = client.get(reverse("admin:stores_pricingconfig_history", args=[pricing.pk]))
        assert history.status_code == 200

    @pytest.mark.parametrize("field", ["delivery_fee", "min_order_value", "cod_max_order_value"])
    def test_negative_amounts_are_refused(self, client, pricing, field):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        data = admin_form_data(client.get(change_url(pricing)))
        data[field] = "-1.00"
        response = client.post(change_url(pricing), data)
        assert response.status_code == 200
        assert field in response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert getattr(pricing, field) >= 0

    def test_finance_views_in_rupees_and_cannot_save(self, client, pricing):
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(change_url(pricing)).content.decode()
        assert 'name="_save"' not in html
        for amount in ("₹99.00", "₹25.00", "₹299.00", "₹15.00", "₹149.00", "₹2,000.00"):
            assert amount in html
        data = {"delivery_fee": "0.00", "_save": "Save"}
        assert client.post(change_url(pricing), data).status_code == 403
        pricing.refresh_from_db()
        assert pricing.delivery_fee == Decimal("25.00")

    def test_history_is_view_only(self, client, pricing):
        client.force_login(SuperUserFactory())
        version = pricing.history.latest()
        url = reverse("admin:stores_pricingconfig_simple_history", args=[pricing.pk, version.pk])
        assert client.get(url).status_code == 200
        assert client.post(url, {"_save": "Revert"}).status_code == 403

    def test_nobody_deletes_a_pricing_row(self, client, pricing):
        client.force_login(SuperUserFactory())
        url = reverse("admin:stores_pricingconfig_delete", args=[pricing.pk])
        assert client.get(url).status_code == 403
        assert client.post(url, {"post": "yes"}).status_code == 403
        assert PricingConfig.objects.filter(pk=pricing.pk).exists()

    def test_store_is_fixed_after_creation(self, client, pricing):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        form = client.get(change_url(pricing)).context["adminform"].form
        assert "store" not in form.fields


class TestListAndAdd:
    def test_list_in_rupees_and_stores_billed_with_defaults(self, client, pricing):
        DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(reverse(LIST)).content.decode()
        assert "₹25.00, free from ₹299.00" in html
        assert "₹15.00 below ₹149.00" in html
        assert "Up to ₹2,000.00" in html
        assert 'data-testid="pricing-defaults"' in html
        assert "NOI-18 Jivo Noida 18" in html  # no row: billed with the defaults
        assert "GGN-01 Jivo Sector 14;" not in html

    def test_add_lists_only_stores_without_a_row(self, client, pricing):
        free = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        form = client.get(reverse("admin:stores_pricingconfig_add")).context["adminform"].form
        assert list(form.fields["store"].queryset) == [free]
        data = admin_form_data(client.get(reverse("admin:stores_pricingconfig_add")))
        data.update({"store": str(free.pk), "handling_fee": "4.00"})
        response = client.post(reverse("admin:stores_pricingconfig_add"), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        assert PricingConfig.objects.get(store=free).handling_fee == Decimal("4.00")


def test_other_store_pricing_is_not_reachable(client, store, pricing):
    """Pricing is global for its roles (Super Admin, Finance); if a store role is ever granted
    the view permission, rows stay limited to its stores."""
    from django.contrib.auth.models import Permission

    from apps.stores.services import grant_store_access

    other_store = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    other = PricingConfig.objects.create(store=other_store)
    DarkStoreFactory(code="FBD-02", name="Jivo Faridabad")  # no row, not the user's store
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, store)
    manager.user_permissions.add(Permission.objects.get(codename="view_pricingconfig"))
    client.force_login(manager)
    response = client.get(reverse(LIST))
    assert [row.pk for row in response.context["cl"].result_list] == [pricing.pk]
    html = response.content.decode()
    assert "NOI-18" not in html
    assert "FBD-02" not in html  # nor in the "billed with the defaults" note
    assert client.get(change_url(other)).status_code == 404
    history = reverse("admin:stores_pricingconfig_history", args=[other.pk])
    assert client.get(history).status_code == 404
