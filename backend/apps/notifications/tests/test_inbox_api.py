"""Inbox endpoints (api-requests #29): list, mark one read, mark all read. Scoped to the caller
and the token's app; another user's id is a 404 (IDOR)."""

from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts.tests.factories import UserFactory
from apps.notifications.models import Notification

pytestmark = pytest.mark.django_db

LIST = "/api/v1/me/notifications/"
READ_ALL = "/api/v1/me/notifications/read-all/"


def read_url(pk: int) -> str:
    return f"/api/v1/me/notifications/{pk}/read/"


_seq = iter(range(1, 1_000_000))


def entry(user, *, app="customer", in_inbox=True, read=False, link="jivo://orders/7", **kw):
    n = next(_seq)
    return Notification.objects.create(
        user=user,
        app=app,
        event=kw.pop("event", "order.placed"),
        category="order",
        title=kw.pop("title", f"Title {n}"),
        body="Body",
        data={"type": "order", "order_id": "7", "link": link} if link else {},
        dedupe_key=f"test:{n}",
        in_inbox=in_inbox,
        read_at=timezone.now() if read else None,
        **kw,
    )


def test_list_is_newest_first_and_only_mine(user, auth_client):
    with freeze_time(timezone.now() - timedelta(minutes=5)):
        older = entry(user, read=True)
    newer = entry(user, link="")
    entry(user, in_inbox=False)  # push-only (e.g. "rider arrived"): not in the inbox
    entry(user, app="rider")  # the rider app's inbox
    entry(UserFactory())  # someone else's
    response = auth_client.get(LIST)
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 2
    assert body["next"] is None
    assert [item["id"] for item in body["results"]] == [newer.pk, older.pk]
    assert body["results"][0] == {
        "id": newer.pk,
        "title": newer.title,
        "body": "Body",
        "category": "order",
        "link": None,
        "read": False,
        "created_at": body["results"][0]["created_at"],
    }
    assert body["results"][1]["link"] == "jivo://orders/7"
    assert body["results"][1]["read"] is True
    assert body["results"][1]["created_at"].endswith("Z")


def test_list_is_paginated_with_a_constant_number_of_queries(user, auth_client):
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    entry(user)
    auth_client.get(LIST)  # warm the per-process caches (app config)
    with CaptureQueriesContext(connection) as few:
        auth_client.get(LIST)
    for _ in range(2):
        entry(user)
    with CaptureQueriesContext(connection) as more:
        response = auth_client.get(LIST, {"page_size": 2})
    assert len(more) == len(few)  # not one query per entry
    # Session-less JWT request: the user, the page count and the page itself.
    assert len(more) <= 3, [q["sql"] for q in more.captured_queries]
    assert response.json()["count"] == 3
    assert len(response.json()["results"]) == 2
    assert "page=2" in response.json()["next"]
    assert auth_client.get(LIST, {"page": 9}).json()["error"]["code"] == "NOT_FOUND"


def test_rider_token_sees_the_rider_inbox(user, make_auth_client):
    entry(user, app="customer")
    mine = entry(user, app="rider")
    body = make_auth_client(user, "rider").get(LIST).json()
    assert [item["id"] for item in body["results"]] == [mine.pk]


def test_mark_read_is_idempotent(user, auth_client):
    item = entry(user)
    first = auth_client.post(read_url(item.pk))
    assert first.status_code == 200
    assert first.json()["read"] is True
    read_at = Notification.objects.get(pk=item.pk).read_at
    assert read_at is not None
    assert auth_client.post(read_url(item.pk)).status_code == 200
    assert Notification.objects.get(pk=item.pk).read_at == read_at


def test_mark_read_of_another_users_entry_is_404(user, auth_client):
    """IDOR: another user's notification id is "not found", and stays unread."""
    theirs = entry(UserFactory())
    response = auth_client.post(read_url(theirs.pk))
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"
    assert Notification.objects.get(pk=theirs.pk).read_at is None


def test_mark_read_of_another_apps_or_push_only_entry_is_404(user, auth_client):
    for item in (entry(user, app="rider"), entry(user, in_inbox=False)):
        assert auth_client.post(read_url(item.pk)).status_code == 404


def test_read_all(user, auth_client):
    entry(user)
    entry(user)
    entry(user, read=True)
    theirs = entry(UserFactory())
    rider = entry(user, app="rider")
    response = auth_client.post(READ_ALL)
    assert response.status_code == 200
    assert response.json() == {"updated": 2}
    assert auth_client.post(READ_ALL).json() == {"updated": 0}
    assert Notification.objects.get(pk=theirs.pk).read_at is None
    assert Notification.objects.get(pk=rider.pk).read_at is None


@pytest.mark.parametrize(
    ("method", "url"), [("get", LIST), ("post", READ_ALL), ("post", read_url(1))]
)
def test_unauthenticated(api_client, method, url):
    response = getattr(api_client, method)(url)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


def test_wrong_method(auth_client):
    assert auth_client.post(LIST).status_code == 405
    assert auth_client.get(READ_ALL).status_code == 405
