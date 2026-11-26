"""Pricing config admin (05 §2 "Pricing config", 05 §3: Super Admin edits, Finance views; DL-43;
T-304).

- Role matrix for the list, change, history and add pages.
- Edits keep history with the staff user; history is view-only; no delete.
- Values are shown in rupees; negative amounts are refused by the model validation.
- Stores without a row are listed with the defaults they are billed with.
"""

from decimal import Decimal

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
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


class TestFreeCartonOffer:
    """ADR 0002: `free_unit_every` (1 free carton per N paid; 0 = off) on the pricing pages."""

    def test_edit_form_has_the_field_with_its_label_and_help(self, client, pricing):
        from apps.stores.admin import FREE_OFFER_HELP, FREE_OFFER_LABEL

        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        response = client.get(change_url(pricing))
        assert response.status_code == 200
        field = response.context["adminform"].form.fields["free_unit_every"]
        assert field.label == FREE_OFFER_LABEL
        assert field.help_text == FREE_OFFER_HELP == "1 free carton per N paid cartons; 0 = off."
        html = response.content.decode()
        assert "Free cartons (volume offer and rewards)" in html  # ADR 0003 title
        assert 'name="free_unit_every"' in html

    def test_super_admin_turns_the_offer_on_and_history_keeps_it(self, client, pricing):
        admin_user = staff_in_role(roles.SUPER_ADMIN)
        client.force_login(admin_user)
        data = admin_form_data(client.get(change_url(pricing)))
        assert data["free_unit_every"] == "0"  # model default: off
        data["free_unit_every"] = "10"
        response = client.post(change_url(pricing), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.free_unit_every == 10
        latest = pricing.history.latest()
        assert (latest.history_user, latest.free_unit_every) == (admin_user, 10)

    def test_negative_is_refused(self, client, pricing):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        data = admin_form_data(client.get(change_url(pricing)))
        data["free_unit_every"] = "-1"
        response = client.post(change_url(pricing), data)
        assert response.status_code == 200
        assert "free_unit_every" in response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.free_unit_every == 0

    def test_finance_sees_it_in_words_and_cannot_change_it(self, client, pricing):
        pricing.free_unit_every = 10
        pricing.order_unit_label = "cartons"
        pricing.save()
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(change_url(pricing))
        html = response.content.decode()
        assert response.status_code == 200
        assert "1 free per 10 paid cartons" in html
        assert 'name="free_unit_every"' not in html
        data = {"free_unit_every": "0", "_save": "Save"}
        assert client.post(change_url(pricing), data).status_code == 403
        pricing.refresh_from_db()
        assert pricing.free_unit_every == 10

    def test_list_column_and_defaults_note(self, client, pricing):
        other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
        PricingConfig.objects.create(store=other, free_unit_every=10, order_unit_label="cartons")
        from apps.stores.admin import FREE_OFFER_LABEL

        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(reverse(LIST))
        html = response.content.decode()
        assert FREE_OFFER_LABEL in html  # the column header and the defaults note
        assert "1 free per 10 paid cartons" in html
        changelist = response.context["cl"]
        shown = {
            row.store.code: changelist.model_admin.free_offer(row) for row in changelist.result_list
        }
        assert shown == {"GGN-01": "Off", "NOI-18": "1 free per 10 paid cartons"}
        assert (FREE_OFFER_LABEL, "Off") in response.context["pricing_defaults"]


class TestFreeCartonSize:
    """ADR 0003: `free_unit_variant` ("Free carton size") on the pricing pages: every free
    carton (volume offer and rewards) is that variant; empty = the ADR 0002 rule."""

    AUTOCOMPLETE = {
        "app_label": "stores",
        "model_name": "pricingconfig",
        "field_name": "free_unit_variant",
    }

    @staticmethod
    def sold_at(store, **kwargs):
        """A variant with a stock row at `store` (the model only accepts a size sold there; out
        of stock is fine)."""
        from apps.catalog.tests.factories import VariantFactory
        from apps.inventory.models import StoreInventory

        variant = VariantFactory(product__name="Jivo Packaged Water", **kwargs)
        StoreInventory.objects.create(store=store, variant=variant)
        return variant

    @pytest.fixture
    def one_litre(self, store):
        return self.sold_at(store, sku="JV-WTR-1L-12", name="1 L x 12")

    @pytest.fixture
    def retired(self, store):
        return self.sold_at(store, sku="JV-WTR-2L-6", name="2 L x 6", is_active=False)

    def test_editor_gets_an_autocomplete_with_label_and_model_help(self, client, pricing):
        from apps.stores.admin import FREE_SIZE_LABEL

        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        response = client.get(change_url(pricing))
        assert response.status_code == 200
        field = response.context["adminform"].form.fields["free_unit_variant"]
        assert field.label == FREE_SIZE_LABEL == "Free carton size"
        model_help = PricingConfig._meta.get_field("free_unit_variant").help_text
        assert field.help_text == model_help
        assert field.required is False  # empty = the ADR 0002 rule
        html = response.content.decode()
        assert "Free cartons (volume offer and rewards)" in html
        assert 'name="free_unit_variant"' in html
        assert "admin-autocomplete" in html

    def test_super_admin_sets_the_size_and_history_keeps_it(self, client, pricing, one_litre):
        admin_user = staff_in_role(roles.SUPER_ADMIN)
        client.force_login(admin_user)
        data = admin_form_data(client.get(change_url(pricing)))
        assert data["free_unit_variant"] == ""  # model default: not fixed
        data.update({"free_unit_variant": str(one_litre.pk), "free_unit_every": "10"})
        response = client.post(change_url(pricing), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.free_unit_variant == one_litre
        latest = pricing.history.latest()
        assert (latest.history_user, latest.free_unit_variant_id) == (admin_user, one_litre.pk)
        # Cleared again: back to the cheapest size in the order.
        data["free_unit_variant"] = ""
        response = client.post(change_url(pricing), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.free_unit_variant is None

    def test_an_inactive_variant_is_refused(self, client, pricing, retired):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        data = admin_form_data(client.get(change_url(pricing)))
        data["free_unit_variant"] = str(retired.pk)
        response = client.post(change_url(pricing), data)
        assert response.status_code == 200
        assert "free_unit_variant" in response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert pricing.free_unit_variant_id is None

    def test_a_size_not_sold_at_the_store_shows_the_model_error(self, client, pricing):
        from apps.catalog.tests.factories import VariantFactory

        elsewhere = VariantFactory(name="1 L x 12")  # active, but no stock row at GGN-01
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        data = admin_form_data(client.get(change_url(pricing)))
        data["free_unit_variant"] = str(elsewhere.pk)
        response = client.post(change_url(pricing), data)
        assert response.status_code == 200
        errors = response.context["adminform"].form.errors["free_unit_variant"]
        assert errors == ["This size is not sold at this store. Choose one it sells."]
        pricing.refresh_from_db()
        assert pricing.free_unit_variant_id is None

    def test_a_saved_size_deactivated_later_never_blocks_other_edits(
        self, client, pricing, retired
    ):
        PricingConfig.objects.filter(pk=pricing.pk).update(free_unit_variant=retired)
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        data = admin_form_data(client.get(change_url(pricing)))
        assert data["free_unit_variant"] == str(retired.pk)
        data["handling_fee"] = "4.00"
        response = client.post(change_url(pricing), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        pricing.refresh_from_db()
        assert (pricing.free_unit_variant_id, pricing.handling_fee) == (retired.pk, Decimal("4"))

    def test_autocomplete_offers_active_variants_only(self, client, pricing, one_litre, retired):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        url = reverse("admin:autocomplete")
        response = client.get(url, {**self.AUTOCOMPLETE, "term": "Packaged Water"})
        assert response.status_code == 200
        assert [row["id"] for row in response.json()["results"]] == [str(one_litre.pk)]
        # The variants list itself still finds both.
        variants = client.get(
            reverse("admin:catalog_productvariant_changelist"), {"q": "Packaged Water"}
        )
        assert {v.pk for v in variants.context["cl"].result_list} == {one_litre.pk, retired.pk}

    def test_finance_sees_the_size_in_words_and_cannot_change_it(self, client, pricing, one_litre):
        PricingConfig.objects.filter(pk=pricing.pk).update(
            free_unit_every=10, order_unit_label="cartons", free_unit_variant=one_litre
        )
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(change_url(pricing))
        html = response.content.decode()
        assert response.status_code == 200
        assert "1 free 1 L x 12 per 10 paid cartons" in html
        assert "Free carton size" in html
        assert "Jivo Packaged Water 1 L x 12 (JV-WTR-1L-12)" in html
        assert 'name="free_unit_variant"' not in html
        response = client.post(change_url(pricing), {"free_unit_variant": "", "_save": "Save"})
        assert response.status_code == 403
        pricing.refresh_from_db()
        assert pricing.free_unit_variant_id == one_litre.pk

    def test_finance_sees_not_fixed_when_empty(self, client, pricing):
        from apps.stores.admin import FREE_SIZE_NOT_FIXED

        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(change_url(pricing)).content.decode()
        assert FREE_SIZE_NOT_FIXED in html

    def test_list_column_defaults_note_and_queries(self, client, pricing, one_litre):
        from apps.catalog.tests.factories import VariantFactory
        from apps.stores.admin import FREE_SIZE_LABEL, FREE_SIZE_NOT_FIXED

        PricingConfig.objects.filter(pk=pricing.pk).update(
            free_unit_every=10, order_unit_label="cartons", free_unit_variant=one_litre
        )
        client.force_login(staff_in_role(roles.FINANCE))
        client.get(reverse(LIST))  # warm-up (first-request caches)
        with CaptureQueriesContext(connection) as few:
            response = client.get(reverse(LIST))
        assert response.status_code == 200
        assert "1 free 1 L x 12 per 10 paid cartons" in response.content.decode()
        defaults = response.context["pricing_defaults"]
        assert (FREE_SIZE_LABEL, FREE_SIZE_NOT_FIXED) in defaults
        assert ("Min order units", "Off") in defaults  # 0 = no minimum
        assert ("Order unit label", "items") in defaults  # the label itself, not "On"
        for code in ("NOI-18", "FBD-02", "DEL-03"):
            PricingConfig.objects.create(  # .create() skips clean(): no stock row needed
                store=DarkStoreFactory(code=code),
                free_unit_every=10,
                free_unit_variant=VariantFactory(),
            )
        with CaptureQueriesContext(connection) as many:
            assert client.get(reverse(LIST)).status_code == 200
        assert len(many) == len(few)
