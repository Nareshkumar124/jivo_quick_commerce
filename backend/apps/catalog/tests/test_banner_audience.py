"""Home banner audience (new vs returning customers) and the `referral` link type."""

import pytest
from django.core.exceptions import ValidationError
from django.urls import reverse

from apps.accounts import roles
from apps.catalog.models import Banner
from apps.catalog.tests.factories import image_upload
from apps.ops_console.tests.helpers import admin_form_data, staff_in_role
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory

pytestmark = pytest.mark.django_db

HOME = "/api/v1/home/"


@pytest.fixture
def banners(world):
    def make(title, audience, **kw):
        return Banner.objects.create(
            title=title, image=image_upload(1080, 480, "JPEG"), audience=audience, **kw
        )

    make("New only", "NEW_CUSTOMERS", link_type="collection", link_value="offers")
    make("Back only", "RETURNING_CUSTOMERS", link_type="referral")


def titles(client, world):
    body = client.get(HOME, headers={"X-Store-Id": str(world.store.pk)}).json()
    return [b["title"] for b in body["banners"]]


def test_anonymous_counts_as_new(api_client, world, banners):
    """P2-TC-BANNER-01"""
    assert titles(api_client, world) == ["Canola deal", "New only"]


def test_new_signed_in_user_sees_new_banner(make_auth_client, user, world, banners):
    assert titles(make_auth_client(user), world) == ["Canola deal", "New only"]


def test_returning_customer_sees_referral_banner(make_auth_client, user, world, banners):
    OrderFactory(user=user)
    body = make_auth_client(user).get(HOME, headers={"X-Store-Id": str(world.store.pk)}).json()
    assert [b["title"] for b in body["banners"]] == ["Canola deal", "Back only"]
    assert body["banners"][1]["link_type"] == "referral"
    assert "audience" not in body["banners"][1]


def test_unplaced_order_does_not_count(make_auth_client, user, world, banners):
    OrderFactory(user=user, status=OrderStatus.CANCELLED, placed_at=None)
    assert titles(make_auth_client(user), world) == ["Canola deal", "New only"]


def test_cache_does_not_leak_between_users(make_auth_client, api_client, user, world, banners):
    from apps.accounts.tests.factories import UserFactory

    other = UserFactory()
    OrderFactory(user=other)
    assert titles(make_auth_client(other), world) == ["Canola deal", "Back only"]
    assert titles(api_client, world) == ["Canola deal", "New only"]  # warm cache, other view
    assert titles(make_auth_client(user), world) == ["Canola deal", "New only"]
    assert titles(make_auth_client(other), world) == ["Canola deal", "Back only"]


def test_referral_link_must_have_empty_value(world):
    banner = Banner(title="Refer", link_type="referral", link_value="x")
    with pytest.raises(ValidationError) as err:
        banner.clean()
    assert "link_value" in err.value.message_dict
    Banner(title="Refer", link_type="referral", link_value="").clean()


def test_admin_form_saves_audience(client):
    client.force_login(staff_in_role(roles.CATALOG_MANAGER))
    url = reverse("admin:catalog_banner_add")
    data = admin_form_data(client.get(url))
    data.update(
        {
            "title": "Refer",
            "image": image_upload(1080, 480),
            "link_type": "referral",
            "link_value": "",
            "audience": "RETURNING_CUSTOMERS",
            "stores": [],
            "sort_order": "0",
            "is_active": "on",
        }
    )
    response = client.post(url, data)
    errs = response.context_data["adminform"].form.errors if response.status_code == 200 else None
    assert response.status_code == 302, errs
    banner = Banner.objects.get(title="Refer")
    assert (banner.audience, banner.link_type) == ("RETURNING_CUSTOMERS", "referral")


def test_a_body_cached_before_migration_0006_still_works():
    """A home body cached before the deploy has no "audience" key: it counts as ALL, no error."""
    from apps.catalog.services import banners_for_audience

    body = {"banners": [{"id": 1, "title": "Old"}], "sections": []}
    assert banners_for_audience(body, None)["banners"] == [{"id": 1, "title": "Old"}]
