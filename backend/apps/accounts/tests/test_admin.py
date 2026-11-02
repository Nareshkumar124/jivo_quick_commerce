"""Django Admin with django-unfold: the custom User admin renders and saves."""

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse

from apps.accounts.tests.factories import UserFactory

User = get_user_model()

pytestmark = pytest.mark.django_db


@pytest.fixture
def admin_client(client, superuser):
    client.force_login(superuser)
    return client


@pytest.mark.parametrize(
    "url_name",
    [
        "admin:index",
        "admin:accounts_user_changelist",
        "admin:accounts_user_add",
        "admin:auth_group_changelist",
        "admin:auth_group_add",
        "admin:django_celery_beat_periodictask_changelist",
    ],
)
def test_admin_pages_render(admin_client, url_name):
    response = admin_client.get(reverse(url_name))
    assert response.status_code == 200


def test_user_change_page_and_search(admin_client):
    customer = UserFactory(phone="+919811122233")
    assert (
        admin_client.get(reverse("admin:accounts_user_change", args=[customer.pk])).status_code
        == 200
    )
    response = admin_client.get(reverse("admin:accounts_user_changelist"), {"q": "9811122233"})
    assert response.status_code == 200
    assert b"+919811122233" in response.content


def test_add_customer_without_password(admin_client):
    response = admin_client.post(
        reverse("admin:accounts_user_add"),
        {"phone": "+919800000001", "email": "", "name": "Asha", "usable_password": "false"},
    )
    assert response.status_code == 302, response.content
    user = User.objects.get(phone="+919800000001")
    assert user.email is None
    assert not user.has_usable_password()


def test_add_staff_with_password(admin_client):
    response = admin_client.post(
        reverse("admin:accounts_user_add"),
        {
            "email": "Picker@Jivo.test",
            "phone": "",
            "name": "Picker",
            "usable_password": "true",
            "password1": "a-strong-pass-1",
            "password2": "a-strong-pass-1",
        },
    )
    assert response.status_code == 302, response.content
    user = User.objects.get(email="picker@jivo.test")
    assert user.phone is None
    assert user.check_password("a-strong-pass-1")


def test_add_requires_phone_or_email(admin_client):
    response = admin_client.post(
        reverse("admin:accounts_user_add"),
        {"phone": "", "email": "", "name": "Nobody", "usable_password": "false"},
    )
    assert response.status_code == 200
    assert b"Enter an email address or a phone number." in response.content
    assert not User.objects.filter(name="Nobody").exists()


def test_non_staff_is_redirected_to_login(client, user):
    client.force_login(user)
    response = client.get(reverse("admin:index"))
    assert response.status_code == 302
    assert reverse("admin:login") in response["Location"]
