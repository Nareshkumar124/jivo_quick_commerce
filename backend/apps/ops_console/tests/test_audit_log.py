"""Audit log viewer (05 §2 "Audit log", 05 §3: Super Admin, Finance view; T-413): Django's
`LogEntry`, read-only for everyone, people masked for roles without full PII, search by id only.
"""

import pytest
from django.contrib.admin.models import CHANGE, LogEntry
from django.contrib.contenttypes.models import ContentType
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.models import Customer
from apps.accounts.services.customers import block_customer
from apps.accounts.tests.factories import UserFactory
from apps.ops_console.tests.helpers import (
    AUDIT_LOG_ROLES,
    PRINCIPALS,
    expected_status,
    login_as,
    staff_in_role,
)

pytestmark = pytest.mark.django_db

LIST = "admin:admin_logentry_changelist"
PHONE = "+919811122233"


@pytest.fixture
def entries():
    actor = staff_in_role(roles.SUPER_ADMIN, name="Ravi Admin")
    customer = UserFactory(name="Asha Verma", phone=PHONE)
    block_customer(customer.pk, by=actor)
    # An entry written by the stock admin carries str(user): the phone.
    legacy = LogEntry.objects.create(
        user=actor,
        content_type=ContentType.objects.get_for_model(Customer, for_concrete_model=False),
        object_id=str(customer.pk),
        object_repr=PHONE,
        action_flag=CHANGE,
        change_message="Changed name.",
    )
    return {"actor": actor, "customer": customer, "legacy": legacy}


@pytest.mark.parametrize("page", ["list", "detail"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_audit_log_matrix(client, entries, principal, page):
    login_as(client, principal)
    url = (
        reverse(LIST)
        if page == "list"
        else reverse("admin:admin_logentry_change", args=[entries["legacy"].pk])
    )
    response = client.get(url)
    assert response.status_code == expected_status(principal, AUDIT_LOG_ROLES), principal


def test_finance_sees_masked_people(client, entries):
    client.force_login(staff_in_role(roles.FINANCE))
    html = client.get(reverse(LIST)).content.decode()
    assert PHONE not in html
    assert f"Customer {entries['customer'].pk}" in html
    assert "Ravi Admin" in html
    assert "Changed name." in html


def test_super_admin_sees_the_record_text(client, entries):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    assert PHONE in client.get(reverse(LIST)).content.decode()


def test_search_is_by_record_id_only(client, entries):
    client.force_login(staff_in_role(roles.FINANCE))
    response = client.get(reverse(LIST), {"q": "2233"})
    assert list(response.context["cl"].result_list) == []
    response = client.get(reverse(LIST), {"q": str(entries["customer"].pk)})
    assert len(response.context["cl"].result_list) == 2


def test_read_only_for_superusers_too(client, entries):
    login_as(client, "superuser flag")
    assert client.get(reverse("admin:admin_logentry_add")).status_code == 403
    delete = reverse("admin:admin_logentry_delete", args=[entries["legacy"].pk])
    assert client.post(delete, {"post": "yes"}).status_code == 403
    assert LogEntry.objects.filter(pk=entries["legacy"].pk).exists()


def test_actor_filter_lists_staff_only(client, entries):
    client.force_login(staff_in_role(roles.FINANCE))
    response = client.get(reverse(LIST), {"actor": entries["actor"].pk})
    assert len(response.context["cl"].result_list) == 2
    html = response.content.decode()
    assert "Asha Verma" not in html


def test_staff_access_entries_hold_no_pii_for_finance(client):
    """A store-access row added on a staff user's page is logged with `str(StaffStoreAccess)`,
    "<phone or email> @ <store>". Masked for roles without full PII access."""
    import json

    from apps.accounts.models import User
    from apps.stores.models import StaffStoreAccess

    actor = staff_in_role(roles.SUPER_ADMIN, name="Ravi Admin")
    member = staff_in_role(roles.STORE_STAFF, phone="+919822233344", email="meena@jivo.test")
    LogEntry.objects.create(
        user=actor,
        content_type=ContentType.objects.get_for_model(User),
        object_id=str(member.pk),
        object_repr="meena@jivo.test",
        action_flag=CHANGE,
        change_message=json.dumps(
            [{"added": {"name": "store access", "object": "+919822233344 @ GGN-01"}}]
        ),
    )
    LogEntry.objects.create(
        user=actor,
        content_type=ContentType.objects.get_for_model(StaffStoreAccess),
        object_id="9",
        object_repr="+919822233344 @ GGN-01",
        action_flag=CHANGE,
        change_message="",
    )
    client.force_login(staff_in_role(roles.FINANCE))
    html = client.get(reverse(LIST)).content.decode()
    assert "+919822233344" not in html
    assert "meena@jivo.test" not in html
    assert "Added store access." in html
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    assert "+919822233344 @ GGN-01" in client.get(reverse(LIST)).content.decode()


# --------------------------------------------------------------------------- core.AuditLog


@pytest.fixture
def audit_model():
    from django.apps import apps

    try:
        return apps.get_model("core", "AuditLog")
    except LookupError:
        pytest.skip("core.AuditLog is not on this branch yet (backend P4)")


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_core_audit_log_matrix(client, audit_model, principal):
    """`core.view_auditlog`: Super Admin and Finance (05 §3 Audit log)."""
    from apps.core import audit

    actor = staff_in_role(roles.OPS, name="Odin Ops")
    entry = audit.record(actor, "order.cancel", ("orders.order", 41), {"reason": "OTHER_STAFF"})
    login_as(client, principal)
    for url in (
        reverse("admin:core_auditlog_changelist"),
        reverse("admin:core_auditlog_change", args=[entry.pk]),
    ):
        assert client.get(url).status_code == expected_status(principal, AUDIT_LOG_ROLES), url


def test_core_audit_log_is_read_only_and_pii_free(client, audit_model):
    from apps.core import audit

    actor = staff_in_role(roles.OPS, name="Odin Ops")
    customer = UserFactory(name="Asha Verma", phone=PHONE)
    entry = audit.record(
        actor, "order.cancel", ("orders.order", 41), {"reason": "OTHER_STAFF"}, ip="10.1.2.3"
    )
    audit.record(customer, "order.cancel", ("orders.order", 42), {})
    login_as(client, "superuser flag")
    html = client.get(reverse("admin:core_auditlog_changelist")).content.decode()
    assert "Odin Ops" in html
    assert "order.cancel" in html
    assert "reason: OTHER_STAFF" in html
    assert "10.1.2.3" not in html
    assert PHONE not in html
    assert "Asha Verma" not in html
    assert f"Customer {customer.pk}" in html
    assert client.get(reverse("admin:core_auditlog_add")).status_code == 403
    delete = reverse("admin:core_auditlog_delete", args=[entry.pk])
    assert client.post(delete, {"post": "yes"}).status_code == 403
    assert audit_model.objects.filter(pk=entry.pk).exists()
