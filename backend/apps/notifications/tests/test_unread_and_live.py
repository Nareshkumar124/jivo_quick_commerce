"""api-requests #45/#50 (unread count) and #47 (`notification.new` on the user's app sockets)."""

import pytest

from apps.accounts.tests.factories import UserFactory
from apps.notifications import services
from apps.notifications.tests.test_inbox_api import LIST, entry
from apps.realtime import services as realtime
from apps.realtime.groups import user_group

pytestmark = pytest.mark.django_db

UNREAD = "/api/v1/me/notifications/unread-count/"


def test_unread_count_is_scoped_to_the_caller_and_the_app(make_auth_client):
    user, other = UserFactory(), UserFactory()
    entry(user)
    entry(user)
    entry(user, read=True)
    entry(user, in_inbox=False)
    entry(user, app="rider")
    entry(other)
    customer = make_auth_client(user, "customer")
    assert customer.get(UNREAD).json() == {"unread": 2}
    page = customer.get(LIST).json()
    assert page["unread_count"] == 2
    assert page["count"] == 3
    assert make_auth_client(user, "rider").get(UNREAD).json() == {"unread": 1}
    assert make_auth_client(other, "customer").get(UNREAD).json() == {"unread": 1}


def test_unread_count_needs_auth(api_client):
    assert api_client.get(UNREAD).status_code == 401


def test_new_inbox_entry_is_announced_to_the_user_app_group(
    monkeypatch, django_capture_on_commit_callbacks
):
    sent = []
    monkeypatch.setattr(realtime, "send_now", lambda groups, body: sent.append((groups, body)))
    user = UserFactory()
    with django_capture_on_commit_callbacks(execute=True):
        services.notify(user, "order.accepted", {"order_id": 7, "order_number": "JV-1"})
        services.notify(user, "order.accepted", {"order_id": 7, "order_number": "JV-1"})  # dup
        services.notify(user, "order.rider_arrived", {"order_id": 7})  # not in the inbox
    news = [(g, b) for g, b in sent if b["type"] == "notification.new"]
    assert len(news) == 1
    groups, body = news[0]
    assert groups == [user_group(user.pk, "customer")]
    assert body["data"]["title"] == "Order confirmed"
    assert body["data"]["unread_count"] == 1
    assert "otp" not in str(body).lower()
    assert realtime.send_notification_new(999_999) is False
