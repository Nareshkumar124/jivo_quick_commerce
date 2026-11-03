"""Stores admin (05 §2 "Dark stores", "Serviceability requests"; 05 §3 "Stores & service areas":
Super Admin edits, Ops views, Store Manager views own; notify-me leads for Super Admin and Ops)."""

import pytest
from django.contrib.auth.models import Permission
from django.contrib.gis.geos import Point
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    LEADS_ROLES,
    PRINCIPALS,
    STORE_EDIT_ROLES,
    STORE_VIEW_ROLES,
    admin_form_data,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.stores.models import DarkStore, ServiceabilityRequest
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def stores():
    return {
        "own": DarkStoreFactory(code="GGN-01", name="Jivo Sector 14"),
        "other": DarkStoreFactory(code="NOI-18", name="Jivo Noida 18"),
    }


@pytest.fixture
def lead():
    customer = UserFactory(name="Asha Lead", phone="+919811122233")
    return ServiceabilityRequest.objects.create(
        location=Point(77.2, 28.6, srid=4326),
        user=customer,
        phone=customer.phone,
        address_text="Sector 62, Noida",
    )


PAGES = {
    "admin:stores_darkstore_changelist": (STORE_VIEW_ROLES, None),
    "admin:stores_darkstore_change": (STORE_VIEW_ROLES, "store"),
    "admin:stores_darkstore_add": (STORE_EDIT_ROLES, None),
    "admin:stores_serviceabilityrequest_changelist": (LEADS_ROLES, None),
    "admin:stores_serviceabilityrequest_change": (LEADS_ROLES, "lead"),
}


@pytest.mark.parametrize("url_name", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, stores, lead, principal, url_name):
    allowed, arg = PAGES[url_name]
    login_with_stores(client, principal, stores["own"])
    args = {None: [], "store": [stores["own"].pk], "lead": [lead.pk]}[arg]
    response = client.get(reverse(url_name, args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


class TestStoreScoping:
    def test_store_manager_sees_only_own_stores(self, client, stores):
        manager = staff_in_role(roles.STORE_MANAGER)
        grant_store_access(manager, stores["own"])
        client.force_login(manager)
        response = client.get(reverse("admin:stores_darkstore_changelist"))
        assert [store.pk for store in response.context["cl"].result_list] == [stores["own"].pk]
        assert "Jivo Noida 18" not in response.content.decode()
        other_pk = stores["other"].pk
        other = client.get(reverse("admin:stores_darkstore_change", args=[other_pk]))
        assert other.status_code == 404
        history = client.get(reverse("admin:stores_darkstore_history", args=[other_pk]))
        assert history.status_code == 404

    def test_store_manager_without_access_sees_nothing(self, client, stores):
        client.force_login(staff_in_role(roles.STORE_MANAGER))
        response = client.get(reverse("admin:stores_darkstore_changelist"))
        assert list(response.context["cl"].result_list) == []

    def test_ops_sees_every_store(self, client, stores):
        client.force_login(staff_in_role(roles.OPS))
        response = client.get(reverse("admin:stores_darkstore_changelist"))
        assert len(response.context["cl"].result_list) == 2


class TestStorePages:
    def test_editor_gets_the_map_editor_served_locally(self, client, stores):
        client.force_login(SuperUserFactory())
        html = client.get(
            reverse("admin:stores_darkstore_change", args=[stores["own"].pk])
        ).content.decode()
        assert "ops/vendor/ol-7.2.2.min.js" in html
        assert "gis/js/OLMapWidget.js" in html
        assert "cdn.jsdelivr.net" not in html  # no CDN at runtime (arch doc §6)
        assert 'name="service_area"' in html
        assert 'name="location"' in html

    def test_view_only_roles_get_read_only_maps(self, client, stores):
        manager = staff_in_role(roles.STORE_MANAGER)
        grant_store_access(manager, stores["own"])
        client.force_login(manager)
        html = client.get(
            reverse("admin:stores_darkstore_change", args=[stores["own"].pk])
        ).content.decode()
        assert 'name="service_area"' not in html
        assert "data-ops-geo-map=" in html
        assert '"kind": "area"' in html
        assert "SRID=4326" not in html  # never raw coordinates
        assert "cdn.jsdelivr.net" not in html

    def test_super_admin_saves_a_store_with_hours(self, client, stores):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        url = reverse("admin:stores_darkstore_change", args=[stores["own"].pk])
        data = admin_form_data(client.get(url))
        data.update(
            {
                "avg_prep_minutes": "12",
                "service_area": "SRID=4326;MULTIPOLYGON (((77 28.4, 77.2 28.4, 77.2 28.6, "
                "77 28.6, 77 28.4)))",
            }
        )
        response = client.post(url, data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        store = DarkStore.objects.get(pk=stores["own"].pk)
        assert store.avg_prep_minutes == 12
        assert store.service_area.contains(Point(77.15, 28.55, srid=4326))
        assert store.timings.count() == 7  # the inline came back unchanged

    def test_ops_cannot_save(self, client, stores):
        client.force_login(staff_in_role(roles.OPS))
        url = reverse("admin:stores_darkstore_change", args=[stores["own"].pk])
        response = client.post(url, {"name": "Renamed", "_save": "Save"})
        assert response.status_code == 403
        stores["own"].refresh_from_db()
        assert stores["own"].name == "Jivo Sector 14"

    def test_stores_are_never_deleted(self, client, stores):
        client.force_login(SuperUserFactory())
        url = reverse("admin:stores_darkstore_delete", args=[stores["own"].pk])
        assert client.get(url).status_code == 403

    def test_pause_and_resume_orders(self, client, stores):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        url = reverse("admin:stores_darkstore_changelist")
        client.post(url, {"action": "pause_orders", "_selected_action": [stores["own"].pk]})
        stores["own"].refresh_from_db()
        assert stores["own"].is_accepting_orders is False
        html = client.get(url).content.decode()
        assert "Paused" in html
        client.post(url, {"action": "resume_orders", "_selected_action": [stores["own"].pk]})
        stores["own"].refresh_from_db()
        assert stores["own"].is_accepting_orders is True

    @pytest.mark.parametrize("role", [roles.OPS, roles.STORE_MANAGER])
    def test_view_roles_cannot_pause(self, client, stores, role):
        user = staff_in_role(role)
        grant_store_access(user, stores["own"])
        client.force_login(user)
        response = client.post(
            reverse("admin:stores_darkstore_changelist"),
            {"action": "pause_orders", "_selected_action": [stores["own"].pk]},
        )
        assert response.status_code == 200  # no actions for the role: just the list again
        stores["own"].refresh_from_db()
        assert stores["own"].is_accepting_orders is True

    def test_list_queries_do_not_grow(self, client, stores):
        client.force_login(staff_in_role(roles.OPS))
        url = reverse("admin:stores_darkstore_changelist")

        def count():
            with CaptureQueriesContext(connection) as queries:
                assert client.get(url).status_code == 200
            return len(queries)

        few = count()
        for _ in range(15):
            DarkStoreFactory()
        assert count() == few


class TestLeads:
    URL = "admin:stores_serviceabilityrequest_changelist"

    def test_full_phone_and_customer_link_for_ops(self, client, lead):
        client.force_login(staff_in_role(roles.OPS))
        html = client.get(reverse(self.URL)).content.decode()
        assert "+919811122233" in html
        assert reverse("admin:accounts_customer_change", args=[lead.user_id]) in html
        assert 'data-testid="leads-map"' in html
        assert '"kind": "lead"' in html

    def test_phone_is_masked_without_full_pii(self, client, lead):
        """A role allowed to see leads but not customers in full (05 §3 "limited")."""
        viewer = StaffUserFactory()
        viewer.user_permissions.add(Permission.objects.get(codename="view_serviceabilityrequest"))
        client.force_login(viewer)
        html = client.get(reverse(self.URL)).content.decode()
        assert "+919811122233" not in html
        assert "+91 XXXXXX2233" in html
        assert reverse("admin:accounts_customer_change", args=[lead.user_id]) not in html

    def test_leads_are_read_only(self, client, lead):
        client.force_login(staff_in_role(roles.OPS))
        assert client.get(reverse("admin:stores_serviceabilityrequest_add")).status_code == 403
        change = reverse("admin:stores_serviceabilityrequest_change", args=[lead.pk])
        assert client.post(change, {"address_text": "x", "_save": "Save"}).status_code == 403
        lead.refresh_from_db()
        assert lead.address_text == "Sector 62, Noida"

    def test_list_queries_do_not_grow(self, client, lead):
        client.force_login(staff_in_role(roles.OPS))
        url = reverse(self.URL)

        def count():
            with CaptureQueriesContext(connection) as queries:
                assert client.get(url).status_code == 200
            return len(queries)

        few = count()
        for index in range(20):
            ServiceabilityRequest.objects.create(
                location=Point(77 + index / 100, 28.5, srid=4326),
                user=UserFactory(),
                phone=f"+9198000000{index:02d}",
            )
        assert count() == few
