"""ADR 0004 (user, 2026-11-26): only a Super Admin changes offers and delivery areas.

In the stores admin, without the permission (even with the model's change permission):
- Pricing config: the volume offer (`free_unit_every`) and the free carton size
  (`free_unit_variant`) need `promotions.manage_offers`; they show in words and a forged POST
  leaves them as they are, while the other rules still save.
- Dark store: the service area needs `stores.manage_delivery_pincodes`; it shows as a read-only
  map and a forged POST leaves it as it is. Adding a store needs it too.
Today only Super Admin holds the change permissions, so the other role is built here from a
view role plus the model's change permission.
"""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Permission
from django.contrib.gis.geos import Point
from django.urls import reverse

from apps.accounts import roles
from apps.catalog.tests.factories import VariantFactory
from apps.inventory.tests.factories import stock
from apps.ops_console.tests.helpers import admin_form_data, staff_in_role
from apps.stores.models import DarkStore, PricingConfig
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

FAR_AREA = "SRID=4326;MULTIPOLYGON (((70 20, 70.1 20, 70.1 20.1, 70 20.1, 70 20)))"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


def with_permission(role: str, codename: str):
    user = staff_in_role(role)
    user.user_permissions.add(Permission.objects.get(codename=codename))
    return user


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")


@pytest.fixture
def pricing(store):
    size = VariantFactory(name="1 L x 12")
    stock(store, size, 1)
    return PricingConfig.objects.create(store=store, free_unit_every=10, free_unit_variant=size)


class TestPricingOffers:
    def url(self, pricing) -> str:
        return reverse("admin:stores_pricingconfig_change", args=[pricing.pk])

    def test_editor_without_offer_permission_keeps_the_offer(self, client, pricing):
        client.force_login(with_permission(roles.FINANCE, "change_pricingconfig"))
        response = client.get(self.url(pricing))
        html = response.content.decode()
        assert 'name="delivery_fee"' in html  # the other rules stay editable
        assert 'name="free_unit_every"' not in html
        assert 'name="free_unit_variant"' not in html
        assert "1 free 1 L x 12 per 10 paid" in html  # shown in words
        data = admin_form_data(response)
        data.update({"delivery_fee": "30.00", "free_unit_every": "0", "free_unit_variant": ""})
        response = client.post(self.url(pricing), data)
        assert response.status_code == 302, response.content.decode()[:2000]
        pricing.refresh_from_db()
        assert pricing.delivery_fee == Decimal("30.00")
        assert (pricing.free_unit_every, pricing.free_unit_variant_id) == (
            10,
            pricing.free_unit_variant_id,
        )
        assert pricing.free_unit_variant_id is not None

    def test_super_admin_changes_the_offer(self, client, pricing):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        response = client.get(self.url(pricing))
        assert 'name="free_unit_every"' in response.content.decode()
        data = admin_form_data(response)
        data.update({"free_unit_every": "12"})
        response = client.post(self.url(pricing), data)
        assert response.status_code == 302, response.content.decode()[:2000]
        pricing.refresh_from_db()
        assert pricing.free_unit_every == 12


class TestServiceArea:
    def url(self, store) -> str:
        return reverse("admin:stores_darkstore_change", args=[store.pk])

    def test_editor_without_pincode_permission_keeps_the_area(self, client, store):
        client.force_login(with_permission(roles.OPS, "change_darkstore"))
        response = client.get(self.url(store))
        html = response.content.decode()
        assert response.status_code == 200
        assert 'name="service_area"' not in html
        assert "data-ops-geo-map=" in html  # the area as a read-only map
        assert 'name="location"' in html  # the rest of the store stays editable
        data = admin_form_data(response)
        data.update({"avg_prep_minutes": "13", "service_area": FAR_AREA})
        response = client.post(self.url(store), data)
        assert response.status_code == 302, response.content.decode()[:2000]
        saved = DarkStore.objects.get(pk=store.pk)
        assert saved.avg_prep_minutes == 13
        assert saved.service_area.contains(Point(77.05, 28.45, srid=4326))  # unchanged

    def test_adding_a_store_needs_the_pincode_permission(self, client):
        client.force_login(with_permission(roles.OPS, "add_darkstore"))
        assert client.get(reverse("admin:stores_darkstore_add")).status_code == 403
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        assert client.get(reverse("admin:stores_darkstore_add")).status_code == 200

    def test_super_admin_changes_the_area(self, client, store):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        response = client.get(self.url(store))
        assert 'name="service_area"' in response.content.decode()
        data = admin_form_data(response)
        data["service_area"] = FAR_AREA
        response = client.post(self.url(store), data)
        assert response.status_code == 302, response.content.decode()[:2000]
        saved = DarkStore.objects.get(pk=store.pk)
        assert saved.service_area.contains(Point(70.05, 20.05, srid=4326))
