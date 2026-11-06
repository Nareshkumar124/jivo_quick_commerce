"""Customer "cash on delivery blocked" flag (DL-43, 08 T2; T-304).

- Who: the customer moderation roles (`accounts.change_customer` with full customer access:
  Super Admin, Ops, Support). Everyone else cannot open the Customers screen at all.
- How: two list actions, one transaction per customer; staff and anonymised accounts refused.
- Audit: an admin LogEntry with the acting staff user and no personal data ("Customer 42").
"""

import pytest
from django.contrib.admin.models import LogEntry
from django.contrib.auth.models import Permission
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.models import User
from apps.accounts.services.customers import LOG_COD_ALLOWED, LOG_COD_BLOCKED, set_cod_blocked
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    CUSTOMER_ROLES,
    PRINCIPALS,
    expected_status,
    login_as,
    staff_in_role,
)

pytestmark = pytest.mark.django_db

LIST = "admin:accounts_customer_changelist"
PHONE = "+919811122233"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def customer():
    return UserFactory(name="Asha Verma", phone=PHONE)


def run(client, action, *customers):
    return client.post(
        reverse(LIST), {"action": action, "_selected_action": [c.pk for c in customers]}
    )


def cod_entries(customer):
    return LogEntry.objects.filter(
        object_id=str(customer.pk), change_message__in=(LOG_COD_BLOCKED, LOG_COD_ALLOWED)
    )


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_block_cod_matrix(client, customer, principal):
    login_as(client, principal)
    response = run(client, "block_cod", customer)
    customer.refresh_from_db()
    if principal in CUSTOMER_ROLES:
        assert response.status_code == 302
        assert customer.cod_blocked is True
    else:
        assert response.status_code == expected_status(principal, CUSTOMER_ROLES)
        assert customer.cod_blocked is False


def test_view_only_customer_access_cannot_change_cod(client, customer):
    viewer = StaffUserFactory()
    viewer.user_permissions.add(
        Permission.objects.get(codename="view_customer", content_type__app_label="accounts")
    )
    client.force_login(viewer)
    html = client.get(reverse(LIST)).content.decode()
    assert "block_cod" not in html
    assert run(client, "block_cod", customer).status_code == 200  # the list again, no action
    customer.refresh_from_db()
    assert customer.cod_blocked is False


@pytest.mark.parametrize("role", [roles.OPS, roles.SUPPORT, roles.SUPER_ADMIN])
def test_block_and_allow_record_the_actor_without_personal_data(client, customer, role):
    staff = staff_in_role(role, name="Ravi Ops")
    client.force_login(staff)
    run(client, "block_cod", customer)
    customer.refresh_from_db()
    assert customer.cod_blocked is True
    run(client, "allow_cod", customer)
    customer.refresh_from_db()
    assert customer.cod_blocked is False
    entries = list(cod_entries(customer).order_by("action_time", "id"))
    assert [e.change_message for e in entries] == [LOG_COD_BLOCKED, LOG_COD_ALLOWED]
    for entry in entries:
        assert entry.user_id == staff.pk
        assert entry.object_repr == f"Customer {customer.pk}"
        assert PHONE not in entry.object_repr
        assert "Asha" not in entry.object_repr


def test_unchanged_customers_are_counted_apart_and_not_logged(client, customer):
    client.force_login(staff_in_role(roles.OPS))
    run(client, "block_cod", customer)
    response = client.post(
        reverse(LIST),
        {"action": "block_cod", "_selected_action": [customer.pk]},
        follow=True,
    )
    texts = [str(m) for m in response.context["messages"]]
    assert "Blocked cash on delivery for 0 customer(s)." in texts
    assert "1 customer(s) already had COD blocked." in texts
    assert cod_entries(customer).count() == 1


def test_anonymised_accounts_are_refused_with_a_message(client, customer):
    User.objects.filter(pk=customer.pk).update(
        deleted_at=timezone.now(), anonymised_at=timezone.now()
    )
    client.force_login(staff_in_role(roles.SUPPORT))
    response = client.post(
        reverse(LIST), {"action": "block_cod", "_selected_action": [customer.pk]}, follow=True
    )
    texts = [str(m) for m in response.context["messages"]]
    assert any(text.startswith("Skipped 1 customer(s):") for text in texts)
    customer.refresh_from_db()
    assert customer.cod_blocked is False
    assert not cod_entries(customer).exists()


def test_the_function_refuses_staff_and_needs_an_actor(customer):
    from django.core.exceptions import ValidationError

    staff = staff_in_role(roles.OPS)
    with pytest.raises(ValidationError):
        set_cod_blocked(staff.pk, True, by=staff)
    with pytest.raises(ValueError, match="acting staff user"):
        set_cod_blocked(customer.pk, True, by=None)
    with pytest.raises(ValidationError):
        set_cod_blocked(10**9, True, by=staff)


def test_detail_shows_the_flag_and_the_last_change(client, customer):
    staff = staff_in_role(roles.SUPPORT, name="Neha Support")
    set_cod_blocked(customer.pk, True, by=staff)
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(reverse("admin:accounts_customer_change", args=[customer.pk])).content
    html = html.decode()
    assert "COD blocked" in html
    assert "By Neha Support" in html


def test_list_filter_and_column(client, customer):
    blocked = UserFactory(name="Blocked Person")
    set_cod_blocked(blocked.pk, True, by=staff_in_role(roles.OPS))
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse(LIST), {"cod_blocked__exact": "1"})
    assert [c.pk for c in response.context["cl"].result_list] == [blocked.pk]
    assert "COD blocked" in response.content.decode()
    response = client.get(reverse(LIST), {"cod_blocked__exact": "0"})
    assert customer.pk in [c.pk for c in response.context["cl"].result_list]


def test_anonymisation_scrubs_still_cover_cod_entries(customer):
    """`auth.anonymise_user()` rewrites the Customer's LogEntry repr; ours is neutral already."""
    from apps.accounts.services.auth import anonymise_user

    staff = staff_in_role(roles.OPS)
    set_cod_blocked(customer.pk, True, by=staff)
    User.objects.filter(pk=customer.pk).update(deleted_at=timezone.now())
    assert anonymise_user(customer.pk)
    entry = cod_entries(customer).get()
    assert entry.object_repr == f"Customer {customer.pk}"
    assert entry.user_id == staff.pk
