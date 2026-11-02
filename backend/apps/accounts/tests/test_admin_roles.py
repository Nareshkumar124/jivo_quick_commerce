"""Phase 1 admin screens per role (05 §2, §3): Users & roles, Customers, admin settings.

Allowed: 200. Staff without the permission: 403. Not staff or signed out: 302 to the admin login.
"""

import pytest
from django.contrib.auth.models import Group, Permission
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.models import Address, Customer, Device, User
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    ADMIN_SETTINGS_ROLES,
    ANONYMOUS,
    CUSTOMER_ROLES,
    NON_STAFF,
    PRINCIPALS,
    STAFF_PRINCIPALS,
    login_as,
    staff_in_role,
)

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def customer():
    customer = UserFactory(phone="+919811122233", name="Ravi Customer")
    Address.objects.create(
        user=customer,
        label="home",
        receiver_name="Ravi",
        receiver_phone=customer.phone,
        house="12",
        building_street="MG Road",
        city="Gurugram",
        state="Haryana",
        pincode="122001",
        lat=1,
        lng=1,
        is_default=True,
    )
    return customer


def expected_status(principal, allowed) -> int:
    if principal in allowed:
        return 200
    if principal in (NON_STAFF, ANONYMOUS):
        return 302
    return 403


ADMIN_PAGES = {
    "admin:index": (STAFF_PRINCIPALS, None),
    "admin:accounts_customer_changelist": (CUSTOMER_ROLES, None),
    "admin:accounts_customer_change": (CUSTOMER_ROLES, "customer"),
    "admin:accounts_user_changelist": (ADMIN_SETTINGS_ROLES, None),
    "admin:accounts_user_add": (ADMIN_SETTINGS_ROLES, None),
    "admin:accounts_user_change": (ADMIN_SETTINGS_ROLES, "customer"),
    "admin:auth_group_changelist": (ADMIN_SETTINGS_ROLES, None),
    "admin:auth_group_change": (ADMIN_SETTINGS_ROLES, "group"),
    "admin:cms_appconfig_change": (ADMIN_SETTINGS_ROLES, "appconfig"),
    "admin:axes_accessattempt_changelist": (ADMIN_SETTINGS_ROLES, None),
    "admin:django_celery_beat_periodictask_changelist": (ADMIN_SETTINGS_ROLES, None),
}


@pytest.mark.parametrize("url_name", sorted(ADMIN_PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_admin_page_matrix(client, customer, principal, url_name):
    from apps.cms.models import AppConfig

    allowed, arg = ADMIN_PAGES[url_name]
    args = {
        None: [],
        "customer": [customer.pk],
        "group": [Group.objects.get(name=roles.SUPPORT).pk],
        "appconfig": [AppConfig.load().pk],
    }[arg]
    login_as(client, principal)
    response = client.get(reverse(url_name, args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


class TestCustomerAdmin:
    URL = "admin:accounts_customer_changelist"

    def test_list_columns_and_status_badges(self, client, customer):
        UserFactory(name="Blocked Person", is_active=False)
        UserFactory(name="Leaving Person", deleted_at=timezone.now())
        StaffUserFactory(name="Staff Person")
        client.force_login(staff_in_role(roles.SUPPORT))
        html = client.get(reverse(self.URL)).content.decode()
        assert "Ravi Customer" in html
        assert "+919811122233" in html
        assert "Blocked Person" in html
        assert "Deletion requested" in html
        assert "Staff Person" not in html  # staff are not customers

    @pytest.mark.parametrize(
        ("status", "shown", "hidden"),
        [
            ("active", "Ravi Customer", "Blocked Person"),
            ("blocked", "Blocked Person", "Ravi Customer"),
            ("deletion_requested", "Leaving Person", "Ravi Customer"),
        ],
    )
    def test_status_filter(self, client, customer, status, shown, hidden):
        UserFactory(name="Blocked Person", is_active=False)
        UserFactory(name="Leaving Person", deleted_at=timezone.now())
        client.force_login(staff_in_role(roles.OPS))
        html = client.get(reverse(self.URL), {"status": status}).content.decode()
        assert shown in html
        assert hidden not in html

    def test_search_by_partial_phone(self, client, customer):
        UserFactory(name="Someone Else")
        client.force_login(staff_in_role(roles.SUPPORT))
        html = client.get(reverse(self.URL), {"q": "1122233"}).content.decode()
        assert "Ravi Customer" in html
        assert "Someone Else" not in html

    def test_detail_shows_addresses_and_devices_without_push_token(self, client, customer):
        Device.objects.create(
            user=customer,
            app="customer",
            platform="android",
            fcm_token="secret-fcm-token-value",
            app_version="1.3.0",
            last_seen_at=timezone.now(),
        )
        client.force_login(staff_in_role(roles.SUPPORT))
        html = client.get(
            reverse("admin:accounts_customer_change", args=[customer.pk])
        ).content.decode()
        assert "MG Road" in html
        assert "1.3.0" in html
        assert "secret-fcm-token-value" not in html

    def test_list_queries_do_not_grow_with_rows(self, client, django_assert_max_num_queries):
        client.force_login(staff_in_role(roles.OPS))

        def count(rows):
            for index in range(rows):
                person = UserFactory(name=f"Person {index}")
                Address.objects.create(
                    user=person,
                    label="home",
                    receiver_name="R",
                    receiver_phone="+919800000000",
                    house="1",
                    building_street="Street",
                    city="City",
                    state="State",
                    pincode="122001",
                    lat=1,
                    lng=1,
                )
            with CaptureQueriesContext(connection) as queries:
                assert client.get(reverse(self.URL)).status_code == 200
            return len(queries)

        assert count(3) == count(40)
        with django_assert_max_num_queries(12):
            client.get(reverse(self.URL))

    @pytest.mark.parametrize("codename", ["view_customer", "change_customer"])
    def test_limited_roles_never_open_the_customer_screen(self, client, customer, codename):
        """05 §3 "limited" (Store Manager / Staff): `change_customer` alone does not open the
        full-PII screen; it needs `accounts.view_customer`, the full-access permission."""
        limited = staff_in_role(roles.STORE_MANAGER)
        limited.user_permissions.add(
            Permission.objects.get(codename=codename, content_type__app_label="accounts")
        )
        client.force_login(limited)
        status = client.get(reverse(self.URL)).status_code
        assert status == (200 if codename == "view_customer" else 403)

    def test_customers_cannot_be_added_or_deleted(self, client, customer):
        client.force_login(SuperUserFactory())
        assert client.get(reverse("admin:accounts_customer_add")).status_code == 403
        assert (
            client.get(reverse("admin:accounts_customer_delete", args=[customer.pk])).status_code
            == 403
        )

    def test_read_only_roles_cannot_run_actions(self, client, customer):
        viewer = StaffUserFactory()
        viewer.user_permissions.add(
            Permission.objects.get(codename="view_customer", content_type__app_label="accounts")
        )
        client.force_login(viewer)
        response = client.post(
            reverse(self.URL), {"action": "block", "_selected_action": [customer.pk]}
        )
        customer.refresh_from_db()
        assert customer.is_active
        assert response.status_code in (200, 302, 403)


class TestAnonymiseConfirmation:
    def test_first_post_asks_and_changes_nothing(self, client, customer):
        customer.deleted_at = timezone.now()
        customer.save()
        other = UserFactory(name="Not Leaving")
        client.force_login(staff_in_role(roles.SUPPORT))
        response = client.post(
            reverse("admin:accounts_customer_changelist"),
            {"action": "anonymise_now", "_selected_action": [customer.pk, other.pk]},
        )
        assert response.status_code == 200
        html = response.content.decode()
        assert 'data-testid="anonymise-confirmation"' in html
        assert "Anonymise 1 customer now?" in html
        assert "1 selected customer did not request deletion" in html
        customer.refresh_from_db()
        assert customer.anonymised_at is None

    def test_confirmed_post_anonymises_only_deletion_requests(self, client, customer):
        customer.deleted_at = timezone.now()
        customer.save()
        other = UserFactory(name="Not Leaving")
        client.force_login(staff_in_role(roles.SUPPORT))
        response = client.post(
            reverse("admin:accounts_customer_changelist"),
            {
                "action": "anonymise_now",
                "_selected_action": [customer.pk, other.pk],
                "confirm": "yes",
            },
        )
        assert response.status_code == 302
        customer.refresh_from_db()
        other.refresh_from_db()
        assert customer.anonymised_at is not None
        assert customer.phone is None
        assert not Address.objects.filter(user=customer).exists()
        assert other.anonymised_at is None


class TestRolesAdmin:
    def test_managed_role_permissions_are_read_only(self, client):
        client.force_login(SuperUserFactory())
        support = Group.objects.get(name=roles.SUPPORT)
        before = set(support.permissions.values_list("pk", flat=True))
        assert before  # synced by roles.sync_roles()
        url = reverse("admin:auth_group_change", args=[support.pk])
        html = client.get(url).content.decode()
        assert "defined in code" in html
        assert 'name="permissions"' not in html
        assert "Can view customer" in html
        client.post(url, {"name": "Renamed", "permissions": []})
        support.refresh_from_db()
        assert support.name == roles.SUPPORT
        assert set(support.permissions.values_list("pk", flat=True)) == before

    def test_managed_roles_cannot_be_deleted(self, client):
        client.force_login(SuperUserFactory())
        support = Group.objects.get(name=roles.SUPPORT)
        delete_url = reverse("admin:auth_group_delete", args=[support.pk])
        assert client.get(delete_url).status_code == 403
        changelist = client.get(reverse("admin:auth_group_changelist")).content.decode()
        assert "delete_selected" not in changelist

    def test_custom_groups_stay_editable(self, client):
        custom = Group.objects.create(name="Night shift leads")
        client.force_login(SuperUserFactory())
        html = client.get(reverse("admin:auth_group_change", args=[custom.pk])).content.decode()
        assert 'name="permissions"' in html
        assert client.get(reverse("admin:auth_group_delete", args=[custom.pk])).status_code == 200

    def test_list_shows_kind_and_member_counts(self, client):
        staff_in_role(roles.OPS)
        staff_in_role(roles.OPS)
        client.force_login(SuperUserFactory())
        response = client.get(reverse("admin:auth_group_changelist"))
        html = response.content.decode()
        assert "Managed by code" in html
        ops = next(group for group in response.context["cl"].result_list if group.name == roles.OPS)
        assert ops.members == 2
        assert ops.permission_total == Group.objects.get(name=roles.OPS).permissions.count()


class TestStaffUsersAdmin:
    def test_roles_column_without_extra_queries(self, client, django_assert_max_num_queries):
        client.force_login(SuperUserFactory())
        url = reverse("admin:accounts_user_changelist")

        def count(rows):
            for _ in range(rows):
                staff_in_role(roles.SUPPORT)
            with CaptureQueriesContext(connection) as queries:
                assert client.get(url, {"is_staff__exact": "1"}).status_code == 200
            return len(queries)

        assert count(2) == count(25)
        html = client.get(url, {"is_staff__exact": "1"}).content.decode()
        assert roles.SUPPORT in html

    def test_staff_filter_link_lists_only_staff(self, client):
        UserFactory(name="Plain Customer")
        staff_in_role(roles.FINANCE, name="Finance Person")
        client.force_login(SuperUserFactory())
        html = client.get(
            reverse("admin:accounts_user_changelist"), {"is_staff__exact": "1"}
        ).content.decode()
        assert "Finance Person" in html
        assert "Plain Customer" not in html

    def test_group_only_super_admin_can_add_staff(self, client):
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        response = client.post(
            reverse("admin:accounts_user_add"),
            {
                "email": "new.picker@jivo.test",
                "phone": "",
                "name": "New Picker",
                "usable_password": "true",
                "password1": "a-strong-pass-1",
                "password2": "a-strong-pass-1",
            },
        )
        assert response.status_code == 302, response.content
        assert User.objects.filter(email="new.picker@jivo.test").exists()


def test_customer_proxy_excludes_staff():
    UserFactory()
    StaffUserFactory()
    assert Customer.objects.count() == 1
