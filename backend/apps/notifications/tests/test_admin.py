"""Notifications admin (05 §2 "Notifications", P6): read-only notifications with masked
recipients and no push/SMS text (they can hold an OTP), store scoping for store roles, and the
template admin (DLT id for SMS, audit log on every change)."""

import pytest
from django.contrib.auth.models import Permission
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory
from apps.core.models import AuditLog
from apps.notifications.choices import Channel, DeliveryStatus, NotificationCategory
from apps.notifications.models import Notification, NotificationTemplate
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    NON_STAFF,
    PRINCIPALS,
    STORE_SCOPED,
    login_as,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import make_order
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

PHONE = "+919811122233"
OTP_TEXT = "Your delivery OTP is 4321"
INBOX_OTP = "Share OTP 8765 with the rider"
LIST = "admin:notifications_notification_changelist"
TEMPLATES = "admin:notifications_notificationtemplate_changelist"


@pytest.fixture(autouse=True)
def _roles_synced(db):
    roles.sync_roles()


def make_notification(user, *, order=None, event="order.placed", **kwargs):
    defaults = {
        "app": "customer",
        "category": NotificationCategory.ORDER,
        "title": "Order placed",
        "body": INBOX_OTP,
        "push_status": DeliveryStatus.SENDING,
        "push_title": "Order placed",
        "push_body": OTP_TEXT,
        "sms_status": DeliveryStatus.FAILED,
        "sms_body": OTP_TEXT,
    }
    defaults.update(kwargs)
    return Notification.objects.create(
        user=user,
        event=event,
        order_id=order.pk if order else None,
        dedupe_key=f"{event}:{user.pk}:{order.pk if order else 0}:{Notification.objects.count()}",
        **defaults,
    )


def grant(user, *codenames):
    user.user_permissions.add(
        *Permission.objects.filter(content_type__app_label="notifications", codename__in=codenames)
    )
    # Drop the per-user permission cache.
    for attr in ("_perm_cache", "_user_perm_cache", "_group_perm_cache"):
        user.__dict__.pop(attr, None)


@pytest.fixture
def superuser():
    return SuperUserFactory()


@pytest.fixture
def records():
    own = DarkStoreFactory(code="GGN-01")
    other = DarkStoreFactory(code="NOI-18")
    own_order = make_order(own, order_number="JV-NOTIF-0001")
    other_order = make_order(other, order_number="JV-NOTIF-0002")
    customer = own_order.user
    customer.phone = PHONE
    customer.save(update_fields=["phone"])
    return {
        "own": own,
        "own_note": make_notification(customer, order=own_order),
        "other_note": make_notification(other_order.user, order=other_order),
        "account_note": make_notification(customer, event="account.welcome", order=None),
    }


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_notification_list_follows_view_permission(client, principal, records):
    user = login_as(client, principal)
    response = client.get(reverse(LIST))
    if principal in (NON_STAFF, ANONYMOUS):
        assert response.status_code == 302
        return
    allowed = user.has_perm("notifications.view_notification")
    assert response.status_code == (200 if allowed else 403)


def test_list_and_detail_mask_phone_and_hide_push_sms_text(client, superuser, records):
    client.force_login(superuser)
    listing = client.get(reverse(LIST)).content.decode()
    assert "+91 XXXXXX2233" in listing
    assert PHONE not in listing
    detail = client.get(
        reverse("admin:notifications_notification_change", args=[records["own_note"].pk])
    ).content.decode()
    assert "+91 XXXXXX2233" in detail
    assert PHONE not in detail
    assert OTP_TEXT not in detail
    assert INBOX_OTP not in detail  # inbox body hidden too: title only
    assert "Order placed" in detail
    assert INBOX_OTP not in listing
    assert "Sending" in detail
    assert "Failed" in detail


def test_notifications_are_read_only_even_for_superusers(client, superuser, records):
    client.force_login(superuser)
    pk = records["own_note"].pk
    assert client.get(reverse("admin:notifications_notification_add")).status_code == 403
    assert (
        client.get(reverse("admin:notifications_notification_delete", args=[pk])).status_code == 403
    )
    response = client.post(
        reverse("admin:notifications_notification_change", args=[pk]), {"title": "changed"}
    )
    assert response.status_code == 403
    records["own_note"].refresh_from_db()
    assert records["own_note"].title == "Order placed"
    listing = client.get(reverse(LIST)).content.decode()
    assert 'name="action"' not in listing  # no bulk delete or any other action


def test_attention_filter(client, superuser, records):
    client.force_login(superuser)
    make_notification(
        records["own_note"].user,
        event="order.delivered",
        push_status=DeliveryStatus.SENT,
        sms_status=DeliveryStatus.NONE,
    )
    response = client.get(reverse(LIST), {"attention": "failed"})
    assert response.status_code == 200
    events = {row.event for row in response.context["cl"].result_list}
    assert "order.delivered" not in events
    assert len(response.context["cl"].result_list) == 3


@pytest.mark.parametrize("role", sorted(STORE_SCOPED))
def test_store_roles_see_only_their_stores_order_notifications(client, role, records):
    user = staff_in_role(role)
    grant_store_access(user, records["own"])
    grant(user, "view_notification")
    client.force_login(user)
    response = client.get(reverse(LIST))
    assert response.status_code == 200
    shown = {row.pk for row in response.context["cl"].result_list}
    assert shown == {records["own_note"].pk}
    for hidden in ("other_note", "account_note"):
        url = reverse("admin:notifications_notification_change", args=[records[hidden].pk])
        assert client.get(url).status_code in (302, 404)  # never shown


def test_list_query_count_is_flat(client, superuser, records, django_assert_max_num_queries):
    client.force_login(superuser)
    for _ in range(20):
        make_notification(records["own_note"].user)
    with django_assert_max_num_queries(12):
        assert client.get(reverse(LIST)).status_code == 200


# --------------------------------------------------------------------------- templates


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_template_list_follows_view_permission(client, principal):
    user = login_as(client, principal)
    response = client.get(reverse(TEMPLATES))
    if principal in (NON_STAFF, ANONYMOUS):
        assert response.status_code == 302
        return
    allowed = user.has_perm("notifications.view_notificationtemplate")
    assert response.status_code == (200 if allowed else 403)


def _template_data(**overrides):
    data = {
        "event": "order.placed",
        "channel": Channel.SMS,
        "app": "customer",
        "title": "",
        "body": "Your Jivo order {{order_number}} is placed.",
        "dlt_template_id": "",
        "is_active": "on",
    }
    data.update(overrides)
    return data


def test_sms_template_needs_dlt_id(client, superuser):
    client.force_login(superuser)
    response = client.post(
        reverse("admin:notifications_notificationtemplate_add"), _template_data()
    )
    assert response.status_code == 200
    assert "DLT template id" in response.content.decode()
    assert not NotificationTemplate.objects.exists()


def test_template_event_must_be_in_the_catalog(client, superuser):
    client.force_login(superuser)
    response = client.post(
        reverse("admin:notifications_notificationtemplate_add"),
        _template_data(event="made.up", dlt_template_id="1107"),
    )
    assert response.status_code == 200
    assert not NotificationTemplate.objects.exists()


def test_template_add_change_delete_are_audited(client, superuser):
    client.force_login(superuser)
    add = reverse("admin:notifications_notificationtemplate_add")
    response = client.post(add, _template_data(dlt_template_id="1107161234567890"))
    assert response.status_code == 302, response.content.decode()[:2000]
    template = NotificationTemplate.objects.get()
    entry = AuditLog.objects.get(action="notification_template.add")
    assert entry.actor == superuser
    assert entry.object_id == str(template.pk)
    # Field names only, never the text.
    assert "body" in entry.changes["fields"]
    assert "Jivo order" not in str(entry.changes)

    change = reverse("admin:notifications_notificationtemplate_change", args=[template.pk])
    response = client.post(change, _template_data(dlt_template_id="1107161234567890", is_active=""))
    assert response.status_code == 302
    entry = AuditLog.objects.get(action="notification_template.change")
    assert entry.changes == {"fields": ["is_active"], "is_active": False}

    delete = reverse("admin:notifications_notificationtemplate_delete", args=[template.pk])
    assert client.post(delete, {"post": "yes"}).status_code == 302
    assert not NotificationTemplate.objects.exists()
    assert AuditLog.objects.filter(action="notification_template.delete").count() == 1


def test_template_change_page_shows_built_in_text(client, superuser):
    client.force_login(superuser)
    template = NotificationTemplate.objects.create(
        event="order.placed", channel=Channel.PUSH, app="customer", title="T", body="B"
    )
    page = client.get(
        reverse("admin:notifications_notificationtemplate_change", args=[template.pk])
    ).content.decode()
    assert "Built-in text" in page
    assert "Order placed" in page
