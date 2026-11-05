"""Slice 5.3 fixtures: a real order placed through the API (cart -> order, stock reserved), the
store's actions through `store_ops`, and online riders of the order's store."""

from datetime import timedelta

import pytest
from django.contrib.gis.geos import Point
from django.utils import timezone

from apps.cart.tests.conftest import address, shop  # noqa: F401 - shared fixtures
from apps.delivery.models import Rider, RiderShift
from apps.delivery.tests.factories import active_rider
from apps.orders.models import Order
from apps.orders.tests.conftest import Checkout

STORE_POINT = (28.45, 77.05)  # the factory store's location (lat, lng)


@pytest.fixture
def admin(db):
    from apps.accounts.tests.factories import SuperUserFactory

    return SuperUserFactory()


@pytest.fixture
def place(auth_client, shop, address):  # noqa: F811
    """`place(method="COD", lines=None) -> Order` through the real API."""

    def make(method="COD", lines=None):
        checkout = Checkout(auth_client, shop, address)
        checkout.fill(*(lines or [(shop.canola_1l, 2)]))
        body = checkout.place(method)
        order = Order.objects.get(pk=body["order"]["id"])
        if method == "ONLINE":
            checkout.verify(body)
            order.refresh_from_db()
        return order

    return make


@pytest.fixture
def store_steps(admin):
    """The store's moves: accept (T6), pack (T7+T8)."""
    from apps.orders import store_ops

    class Steps:
        @staticmethod
        def accept(order):
            return store_ops.accept_order(order.pk, by=admin)

        @staticmethod
        def pack(order):
            order.refresh_from_db()
            if order.status == "PLACED":
                store_ops.accept_order(order.pk, by=admin)
            store_ops.start_packing(order.pk, by=admin)
            return store_ops.mark_packed(order.pk, by=admin)

    return Steps()


def put_online(rider: Rider, lat_lng=STORE_POINT, *, ago_seconds=0) -> Rider:
    lat, lng = lat_lng
    now = timezone.now() - timedelta(seconds=ago_seconds)
    point = Point(lng, lat, srid=4326)
    RiderShift.objects.create(rider=rider, started_at=now, start_location=point)
    Rider.objects.filter(pk=rider.pk).update(
        is_online=True,
        current_location=point,
        last_location_at=now,
        last_location_received_at=now,
    )
    rider.refresh_from_db()
    return rider


@pytest.fixture
def make_rider(shop):  # noqa: F811
    """`make_rider(lat_lng=STORE_POINT, online=True, **kwargs)`: an ACTIVE rider of the shop's
    store."""

    def make(lat_lng=STORE_POINT, online=True, **kwargs):
        rider = active_rider(preferred_store=shop.store_model, **kwargs)
        return put_online(rider, lat_lng) if online else rider

    return make


@pytest.fixture
def rider_client(make_auth_client):
    return lambda rider: make_auth_client(rider.user, "rider")
