"""Phase 5 contract (T-511): every rider route exists, needs a token and a rider profile, validates
its request, and the operations of later slices answer 503 until they land. Also the customer
`GET /orders/{id}/track/`."""

import pytest
from django.urls import reverse

from apps.accounts.tests.factories import UserFactory
from apps.delivery.tests.factories import RiderFactory, active_rider
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory

pytestmark = pytest.mark.django_db

# (method, path, valid body, multipart)
STUBS = [
    ("get", "/api/v1/rider/offers/current/", None, False),
    ("post", "/api/v1/rider/offers/1/accept/", None, False),
    ("post", "/api/v1/rider/offers/1/reject/", {"reason": "TOO_FAR"}, False),
    ("get", "/api/v1/rider/tasks/current/", None, False),
    ("post", "/api/v1/rider/tasks/1/arrived-store/", {"lat": 28.45, "lng": 77.05}, False),
    ("post", "/api/v1/rider/tasks/1/pickup/", {"order_code": "K7QX"}, False),
    ("post", "/api/v1/rider/tasks/1/arrived-customer/", {"lat": 28.45, "lng": 77.05}, False),
    ("post", "/api/v1/rider/tasks/1/cod-qr/", None, False),
    ("post", "/api/v1/rider/tasks/1/deliver/", {"otp": "4821"}, False),
    ("post", "/api/v1/rider/tasks/1/fail/", {"reason": "WRONG_ADDRESS"}, True),
]
RECORDS = [
    "/api/v1/rider/tasks/history/",
    "/api/v1/rider/earnings/",
    "/api/v1/rider/cash/ledger/",
    "/api/v1/rider/payouts/",
]
ALL = (
    [(m, p) for m, p, _, _ in STUBS]
    + [("get", p) for p in RECORDS]
    + [
        ("post", "/api/v1/rider/shift/start/"),
        ("post", "/api/v1/rider/shift/end/"),
        ("post", "/api/v1/rider/locations/"),
        ("post", "/api/v1/rider/heartbeat/"),
    ]
)


@pytest.mark.parametrize(("method", "path"), [*ALL, ("get", "/api/v1/orders/1/track/")])
def test_requires_a_token(api_client, method, path):
    response = getattr(api_client, method)(path)
    assert response.status_code == 401


@pytest.mark.parametrize(("method", "path"), ALL)
def test_non_rider_is_403(make_auth_client, method, path):
    response = getattr(make_auth_client(UserFactory(), "rider"), method)(path)
    assert response.status_code == 403
    assert response.json()["error"]["details"]["rider_status"] == "NONE"


@pytest.mark.parametrize(("method", "path", "body", "multipart"), STUBS)
def test_later_slices_answer_503(make_auth_client, method, path, body, multipart):
    client = make_auth_client(active_rider().user, "rider")
    response = getattr(client, method)(path, body, format="multipart" if multipart else "json")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"


@pytest.mark.parametrize("path", [p for m, p, _, _ in STUBS])
def test_pending_rider_cannot_use_task_endpoints(make_auth_client, path):
    method = next(m for m, p, _, _ in STUBS if p == path)
    response = getattr(make_auth_client(RiderFactory().user, "rider"), method)(path)
    assert response.status_code == 403
    assert response.json()["error"]["details"]["reason"] == "RIDER_NOT_ACTIVE"


@pytest.mark.parametrize("path", RECORDS)
def test_records_are_open_to_any_rider_status(make_auth_client, path):
    response = make_auth_client(RiderFactory().user, "rider").get(path)
    assert response.status_code == 503


@pytest.mark.parametrize(
    ("method", "path", "body", "field"),
    [
        ("post", "/api/v1/rider/tasks/1/deliver/", {"otp": "12"}, "otp"),
        ("post", "/api/v1/rider/tasks/1/pickup/", {}, "order_code"),
        ("post", "/api/v1/rider/offers/1/reject/", {"reason": "BORED"}, "reason"),
        ("post", "/api/v1/rider/tasks/1/arrived-store/", {"lat": 91, "lng": 0}, "lat"),
    ],
)
def test_stub_requests_are_validated(make_auth_client, method, path, body, field):
    client = make_auth_client(active_rider().user, "rider")
    response = getattr(client, method)(path, body, format="json")
    assert response.status_code == 400
    assert field in response.json()["error"]["details"]


def test_fail_validation(make_auth_client):
    client = make_auth_client(active_rider().user, "rider")
    url = "/api/v1/rider/tasks/1/fail/"
    other = client.post(url, {"reason": "OTHER"}, format="multipart")
    assert "note" in other.json()["error"]["details"]
    calls = client.post(
        url, {"reason": "CUSTOMER_NOT_REACHABLE", "call_attempts": 1}, format="multipart"
    )
    assert "call_attempts" in calls.json()["error"]["details"]


@pytest.mark.parametrize(
    ("query", "field"),
    [("from=2026-11-10&to=2026-11-01", "to"), ("from=2025-01-01&to=2026-11-01", "to")],
)
def test_earnings_range_validation(make_auth_client, query, field):
    client = make_auth_client(RiderFactory().user, "rider")
    response = client.get(f"/api/v1/rider/earnings/?{query}")
    assert response.status_code == 400
    assert field in response.json()["error"]["details"]


def test_history_validation(make_auth_client):
    client = make_auth_client(RiderFactory().user, "rider")
    response = client.get("/api/v1/rider/tasks/history/?from=2026-11-10&to=2026-11-01")
    assert response.status_code == 400
    assert client.get("/api/v1/rider/cash/ledger/?before_id=0").status_code == 400


def test_routes():
    assert reverse("rider-task-deliver", args=[5]) == "/api/v1/rider/tasks/5/deliver/"
    assert reverse("order-track", args=[5]) == "/api/v1/orders/5/track/"


# --------------------------------------------------------------------------- track


def test_track_owner(make_auth_client):
    order = OrderFactory(status=OrderStatus.ACCEPTED)
    response = make_auth_client(order.user).get(f"/api/v1/orders/{order.pk}/track/")
    assert response.status_code == 200
    body = response.json()
    assert body["order_number"] == order.order_number
    assert body["status"] == "ACCEPTED"
    assert body["store"]["id"] == order.store_id
    assert body["destination"] == {"lat": 28.45, "lng": 77.05}
    assert body["rider"] is None
    assert body["delivery_otp"] is None


def test_track_other_users_order_is_404(make_auth_client):
    """IDOR."""
    order = OrderFactory()
    response = make_auth_client(UserFactory()).get(f"/api/v1/orders/{order.pk}/track/")
    assert response.status_code == 404


def test_track_finished_order_has_no_eta(make_auth_client):
    from django.utils import timezone

    order = OrderFactory(status=OrderStatus.CANCELLED, eta_at=timezone.now())
    body = make_auth_client(order.user).get(f"/api/v1/orders/{order.pk}/track/").json()
    assert body["eta_at"] is None
