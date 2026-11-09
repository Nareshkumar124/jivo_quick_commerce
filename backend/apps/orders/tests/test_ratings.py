"""Phase 7 ratings: `POST/GET /orders/{id}/rating/` (api-requests #34), the order detail's
`rating` / `can_rate`, the rider average, `GET /rider/ratings/` and the staff services.

Test cases: P7-TC-01 (rate a delivered order and its rider), P7-TC-02 (one rating per order,
not before DELIVERED), P7-TC-03 (IDOR: another customer's order is 404), P7-TC-04 (rider average
and the rider's own summary), P7-TC-05 (staff ratings: permission and store scope).
"""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.delivery.models import DeliveryTask, Rider
from apps.delivery.tests.factories import RiderFactory
from apps.orders import ratings
from apps.orders.choices import OrderStatus, PaymentStatus, RatingTarget
from apps.orders.models import Rating
from apps.orders.tests.factories import OrderFactory
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

FULL = {
    "order_stars": 5,
    "rider_stars": 4,
    "tags": ["ON_TIME", "POLITE_RIDER"],
    "comment": "  Great service  ",
}


def url(order_id: int) -> str:
    return f"/api/v1/orders/{order_id}/rating/"


def delivered(user, *, rider=None, store=None):
    now = timezone.now()
    kwargs = {"store": store} if store is not None else {}
    order = OrderFactory(
        user=user,
        status=OrderStatus.DELIVERED,
        payment_status=PaymentStatus.COD_COLLECTED,
        delivered_at=now,
        **kwargs,
    )
    if rider is not None:
        DeliveryTask.objects.create(
            order=order,
            store=order.store,
            status="DELIVERED",
            rider=rider,
            search_started_at=now - timedelta(minutes=20),
            assigned_at=now - timedelta(minutes=19),
            delivered_at=now,
            distance_km=Decimal("2.40"),
            payout_amount=Decimal("35.00"),
        )
    return order


@pytest.fixture
def rider(db):
    rider = RiderFactory()
    rider.home_store = rider.preferred_store
    rider.save()
    return rider


class TestRateApi:
    def test_rate_order_and_rider(self, auth_client, user, rider):
        """P7-TC-01: both rows are stored, tags split, comment trimmed; 201 with the shape."""
        order = delivered(user, rider=rider)
        response = auth_client.post(url(order.pk), FULL, format="json")
        assert response.status_code == 201, response.content
        body = response.json()
        assert body["order_stars"] == 5
        assert body["rider_stars"] == 4
        assert body["tags"] == ["ON_TIME", "POLITE_RIDER"]
        assert body["comment"] == "Great service"
        rows = {r.target: r for r in Rating.objects.filter(order=order)}
        assert rows[RatingTarget.ORDER].tags == ["ON_TIME"]
        assert rows[RatingTarget.RIDER].tags == ["ON_TIME", "POLITE_RIDER"]
        assert rows[RatingTarget.RIDER].rider_id == rider.pk
        rider.refresh_from_db()
        assert rider.rating_avg == Decimal("4.0")

    def test_order_only(self, auth_client, user):
        order = delivered(user)
        response = auth_client.post(url(order.pk), {"order_stars": 2}, format="json")
        assert response.status_code == 201
        assert response.json() == {
            "order_stars": 2,
            "rider_stars": None,
            "tags": [],
            "comment": "",
            "created_at": response.json()["created_at"],
        }

    def test_get_rating_and_order_detail(self, auth_client, user, rider):
        """P7-TC-01: GET returns the rating; the order detail shows it and can_rate flips."""
        order = delivered(user, rider=rider)
        assert auth_client.get(url(order.pk)).status_code == 404  # not rated yet
        detail = auth_client.get(f"/api/v1/orders/{order.pk}/").json()
        assert detail["can_rate"] is True
        assert detail["rating"] is None
        auth_client.post(url(order.pk), FULL, format="json")
        got = auth_client.get(url(order.pk))
        assert got.status_code == 200
        assert got.json()["rider_stars"] == 4
        detail = auth_client.get(f"/api/v1/orders/{order.pk}/").json()
        assert detail["can_rate"] is False
        assert detail["rating"]["order_stars"] == 5

    def test_already_rated(self, auth_client, user):
        """P7-TC-02: one rating per order: 400 VALIDATION_ERROR, reason ALREADY_RATED."""
        order = delivered(user)
        assert auth_client.post(url(order.pk), {"order_stars": 4}, format="json").status_code == 201
        response = auth_client.post(url(order.pk), {"order_stars": 1}, format="json")
        assert response.status_code == 400
        error = response.json()["error"]
        assert error["code"] == "VALIDATION_ERROR"
        assert error["details"]["reason"] == "ALREADY_RATED"
        assert Rating.objects.get(order=order).stars == 4

    @pytest.mark.parametrize(
        "status", [OrderStatus.PLACED, OrderStatus.OUT_FOR_DELIVERY, OrderStatus.CANCELLED]
    )
    def test_not_delivered(self, auth_client, user, status):
        """P7-TC-02: only DELIVERED orders can be rated."""
        order = OrderFactory(user=user, status=status)
        response = auth_client.post(url(order.pk), {"order_stars": 5}, format="json")
        assert response.status_code == 400
        details = response.json()["error"]["details"]
        assert details["reason"] == "NOT_DELIVERED"
        assert details["status"] == status
        assert auth_client.get(f"/api/v1/orders/{order.pk}/").json()["can_rate"] is False

    @pytest.mark.parametrize(
        ("payload", "field"),
        [
            ({"order_stars": 6}, "order_stars"),
            ({"order_stars": 0}, "order_stars"),
            ({}, "order_stars"),
            ({"order_stars": 5, "tags": ["GREAT"]}, "tags"),
            ({"order_stars": 5, "comment": "x" * 501}, "comment"),
            ({"order_stars": 5, "rider_stars": 9}, "rider_stars"),
            ({"order_stars": 5, "tags": ["RUDE_RIDER"]}, "tags"),
        ],
    )
    def test_validation(self, auth_client, user, payload, field):
        order = delivered(user)
        response = auth_client.post(url(order.pk), payload, format="json")
        assert response.status_code == 400
        assert field in response.json()["error"]["details"]
        assert not Rating.objects.exists()

    def test_rider_stars_without_rider(self, auth_client, user):
        order = delivered(user)
        response = auth_client.post(url(order.pk), {"order_stars": 5, "rider_stars": 5})
        assert response.status_code == 400
        assert response.json()["error"]["details"]["rider_stars"] == [ratings.MSG_NO_RIDER]

    def test_idor(self, make_auth_client, user):
        """P7-TC-03: another customer's order is 404 for POST and GET; nothing stored."""
        order = delivered(user)
        Rating.objects.create(order=order, user=user, target=RatingTarget.ORDER, stars=5)
        other = make_auth_client(UserFactory())
        assert other.post(url(order.pk), {"order_stars": 1}).status_code == 404
        assert other.get(url(order.pk)).status_code == 404
        assert Rating.objects.filter(order=order).count() == 1

    def test_unknown_order_and_unauthenticated(self, auth_client, api_client):
        assert auth_client.post(url(999999), {"order_stars": 1}).status_code == 404
        assert api_client.post(url(1), {"order_stars": 1}).status_code == 401
        assert api_client.get(url(1)).status_code == 401


class TestRiderRatings:
    def test_average_and_page(self, make_auth_client, rider):
        """P7-TC-04: the average is the mean of the rider's stars (half up, 1 decimal); the
        rider sees counts, tags and their ratings without customer details or comments."""
        for stars, tags in ((5, ["POLITE_RIDER", "ON_TIME"]), (4, []), (4, ["POLITE_RIDER"])):
            customer = UserFactory()
            order = delivered(customer, rider=rider)
            ratings.rate_order(
                customer, order.pk, order_stars=5, rider_stars=stars, tags=tags, comment="hi"
            )
        rider.refresh_from_db()
        assert rider.rating_avg == Decimal("4.3")
        client = make_auth_client(rider.user, "rider")
        body = client.get("/api/v1/rider/ratings/").json()
        assert body["rating_avg"] == "4.3"
        assert body["ratings_count"] == 3
        assert body["tag_counts"] == [
            {"tag": "POLITE_RIDER", "count": 2},
            {"tag": "ON_TIME", "count": 1},
        ]
        assert len(body["results"]) == 3
        assert body["next"] is None
        first = body["results"][0]
        assert set(first) == {"id", "stars", "tags", "rated_at", "order_number"}
        assert first["stars"] == 4  # newest first
        oldest = body["results"][-1]
        assert oldest["tags"] == ["POLITE_RIDER", "ON_TIME"]
        page = client.get("/api/v1/rider/ratings/?page_size=2").json()
        assert len(page["results"]) == 2
        assert "before_id=" in page["next"]
        rest = client.get(page["next"]).json()
        assert [r["id"] for r in rest["results"]] == [oldest["id"]]
        assert client.get("/api/v1/rider/ratings/?before_id=x").status_code == 400

    def test_scoped_to_the_rider(self, make_auth_client, rider):
        """P7-TC-03: another rider never sees these ratings."""
        customer = UserFactory()
        ratings.rate_order(
            customer, delivered(customer, rider=rider).pk, order_stars=5, rider_stars=5
        )
        other = RiderFactory()
        body = make_auth_client(other.user, "rider").get("/api/v1/rider/ratings/").json()
        assert body["ratings_count"] == 0
        assert body["results"] == []

    def test_empty_and_not_a_rider(self, make_auth_client, rider, auth_client):
        body = make_auth_client(rider.user, "rider").get("/api/v1/rider/ratings/").json()
        assert body["rating_avg"] is None
        assert body["ratings_count"] == 0
        assert auth_client.get("/api/v1/rider/ratings/").status_code == 403

    def test_refresh_of_an_unknown_rider(self):
        assert ratings.refresh_rider_average(999_999_999) is None

    def test_anonymisation_erases_the_comment(self, rider):
        """DPDP (09, DL-60): an anonymised customer's rating comment is erased; stars, tags and
        the rider average stay. Another customer's comment is untouched."""
        from apps.accounts.services import auth

        customer, other = UserFactory(), UserFactory()
        ratings.rate_order(
            customer,
            delivered(customer, rider=rider).pk,
            order_stars=4,
            rider_stars=2,
            tags=["LATE_DELIVERY"],
            comment="Call me on 98100 00000",
        )
        ratings.rate_order(other, delivered(other).pk, order_stars=5, comment="Lovely")
        customer.deleted_at = timezone.now() - timedelta(days=60)
        customer.save(update_fields=["deleted_at"])
        assert auth.anonymise_user(customer.pk)
        rows = {r.target: r for r in Rating.objects.filter(user=customer)}
        assert rows[RatingTarget.ORDER].comment == auth.ERASED_TEXT
        assert rows[RatingTarget.ORDER].stars == 4
        assert rows[RatingTarget.RIDER].comment == ""  # rider rows carry no comment
        assert rows[RatingTarget.RIDER].tags == ["LATE_DELIVERY"]
        assert Rating.objects.get(user=other).comment == "Lovely"
        rider.refresh_from_db()
        assert rider.rating_avg == Decimal("2.0")

    def test_refresh_without_ratings(self, rider):
        Rider.objects.filter(pk=rider.pk).update(rating_avg=Decimal("4.0"))
        assert ratings.refresh_rider_average(rider.pk) is None
        rider.refresh_from_db()
        assert rider.rating_avg is None


@pytest.fixture
def make_staff(db):
    def make(role, *stores):
        staff = StaffUserFactory()
        staff.groups.add(Group.objects.get(name=role))
        for store in stores:
            grant_store_access(staff, store)
        return staff

    return make


class TestStaffRatings:
    @pytest.mark.parametrize(
        ("role", "allowed"),
        [
            (roles.SUPER_ADMIN, True),
            (roles.OPS, True),
            (roles.SUPPORT, True),
            (roles.STORE_MANAGER, True),
            (roles.STORE_STAFF, False),
            (roles.CATALOG_MANAGER, False),
            (roles.FINANCE, False),
        ],
    )
    def test_role_matrix(self, make_staff, role, allowed):
        """P7-TC-05: `orders.view_rating` (⚠ PM default)."""
        staff = make_staff(role)
        if allowed:
            ratings.staff_ratings(staff)
        else:
            with pytest.raises(PermissionDenied):
                ratings.staff_ratings(staff)

    def test_store_scope_and_filters(self, make_staff, rider):
        """P7-TC-05: a store manager sees only their stores; low-rating filter."""
        own, other = DarkStoreFactory(), DarkStoreFactory()
        for store, stars in ((own, 1), (own, 5), (other, 2)):
            customer = UserFactory()
            order = delivered(customer, store=store)
            ratings.rate_order(customer, order.pk, order_stars=stars)
        manager = make_staff(roles.STORE_MANAGER, own)
        assert sorted(r.stars for r in ratings.staff_ratings(manager)) == [1, 5]
        assert [r.stars for r in ratings.staff_ratings(manager, low_only=True)] == [1]
        ops = make_staff(roles.OPS)
        assert ratings.staff_ratings(ops, store_id=other.pk).count() == 1
        assert ratings.staff_ratings(ops, target=RatingTarget.RIDER).count() == 0
        with pytest.raises(PermissionDenied):
            ratings.staff_ratings(UserFactory())

    def test_staff_rider_summary(self, make_staff, rider):
        ops = make_staff(roles.OPS)
        assert ratings.staff_rider_summary(ops, rider.pk)["ratings_count"] == 0
        # global roles are not store-filtered (a rider of any store, home store or not)
        applicant = RiderFactory()
        assert applicant.home_store_id is None
        assert ratings.staff_rider_summary(ops, applicant.pk)["ratings_count"] == 0
        own = make_staff(roles.STORE_MANAGER, applicant.preferred_store)
        assert ratings.staff_rider_summary(own, applicant.pk)["ratings_count"] == 0
        stranger = make_staff(roles.STORE_MANAGER, DarkStoreFactory())
        with pytest.raises(PermissionDenied):
            ratings.staff_rider_summary(stranger, rider.pk)
        assert ratings.staff_ratings(ops, rider_id=rider.pk).count() == 0
