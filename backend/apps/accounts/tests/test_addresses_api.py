"""Saved addresses (06 §2.2, 03 §2.4): CRUD, default rules, requester scoping (IDOR)."""

from decimal import Decimal

import pytest
from django.db import IntegrityError

from apps.accounts import examples as ex
from apps.accounts.models import Address
from apps.accounts.tests.factories import UserFactory
from apps.cms.services import get_app_config

pytestmark = pytest.mark.django_db

URL = "/api/v1/addresses/"


def detail(address_id):
    return f"{URL}{address_id}/"


def create(client, **overrides):
    response = client.post(URL, {**ex.ADDRESS_CREATE_REQUEST, **overrides}, format="json")
    assert response.status_code == 201, response.content
    return response.json()


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


class TestCreate:
    def test_first_address_is_default_and_receiver_defaults_to_user(self, auth_client, user):
        request = {
            k: v
            for k, v in ex.ADDRESS_CREATE_REQUEST.items()
            if k not in {"receiver_name", "receiver_phone"}
        }
        response = auth_client.post(URL, {**request, "lat": 28.45951234, "lng": 77.02669999})
        assert response.status_code == 201
        body = response.json()
        assert body["is_default"] is True
        assert body["receiver_name"] == user.name
        assert body["receiver_phone"] == user.phone
        assert body["lat"] == 28.459512
        assert body["lng"] == 77.0267
        address = Address.objects.get(pk=body["id"])
        assert (address.lat, address.lng) == (Decimal("28.459512"), Decimal("77.026700"))
        assert set(body) == set(ex.ADDRESS)

    def test_second_address_is_not_default(self, auth_client):
        create(auth_client)
        assert create(auth_client)["is_default"] is False

    def test_map_pin_and_pincode_are_validated(self, auth_client):
        request = {k: v for k, v in ex.ADDRESS_CREATE_REQUEST.items() if k not in {"lat", "lng"}}
        err = error(auth_client.post(URL, {**request, "pincode": "012345"}), 400)
        assert err["details"] == {
            "pincode": ["Enter a 6-digit PIN code."],
            "lat": ["This field is required."],
            "lng": ["This field is required."],
        }
        err = error(auth_client.post(URL, {**ex.ADDRESS_CREATE_REQUEST, "lat": 91}), 400)
        assert "lat" in err["details"]

    def test_requires_auth(self, api_client):
        assert error(api_client.post(URL, ex.ADDRESS_CREATE_REQUEST), 401)["code"] == (
            "AUTH_REQUIRED"
        )


class TestList:
    def test_own_live_addresses_default_first_then_newest(
        self, auth_client, make_auth_client, django_assert_max_num_queries
    ):
        first = create(auth_client, house="first")
        second = create(auth_client, house="second")
        deleted = create(auth_client, house="deleted")
        auth_client.delete(detail(deleted["id"]))
        create(make_auth_client(UserFactory()), house="someone else's")

        get_app_config()  # warm the guard's config cache
        with django_assert_max_num_queries(3):  # auth user, count, page
            body = auth_client.get(URL).json()
        assert body["count"] == 2
        assert [item["house"] for item in body["results"]] == ["first", "second"]
        assert body["results"][0]["id"] == first["id"]
        assert body["results"][1]["id"] == second["id"]
        assert body["next"] is None

    def test_paginates(self, auth_client):
        for i in range(3):
            create(auth_client, house=f"h{i}")
        body = auth_client.get(URL, {"page_size": 2}).json()
        assert body["count"] == 3
        assert len(body["results"]) == 2
        assert "page=2" in body["next"]

    def test_requires_auth(self, api_client):
        assert error(api_client.get(URL), 401)["code"] == "AUTH_REQUIRED"


class TestDetail:
    def test_retrieve_and_update(self, auth_client):
        address = create(auth_client)
        assert auth_client.get(detail(address["id"])).json() == address
        response = auth_client.patch(
            detail(address["id"]),
            {"landmark": "Behind Galleria Market", "lat": 28.1234567},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["landmark"] == "Behind Galleria Market"
        assert response.json()["lat"] == 28.123457
        assert response.json()["house"] == address["house"]

    def test_update_validation(self, auth_client):
        address = create(auth_client)
        err = error(auth_client.patch(detail(address["id"]), {"label": "office"}), 400)
        assert "label" in err["details"]

    def test_deleted_address_is_gone(self, auth_client):
        address = create(auth_client)
        assert auth_client.delete(detail(address["id"])).status_code == 204
        assert error(auth_client.get(detail(address["id"])), 404)["code"] == "NOT_FOUND"
        assert Address.objects.filter(pk=address["id"], is_deleted=True).exists()

    @pytest.mark.parametrize(
        ("method", "suffix"),
        [("get", ""), ("patch", ""), ("delete", ""), ("post", "set-default/")],
    )
    def test_another_users_address_is_not_found(
        self, auth_client, make_auth_client, method, suffix
    ):
        """IDOR: another user's address id answers 404 for every route."""
        theirs = create(make_auth_client(UserFactory()))
        response = getattr(auth_client, method)(
            detail(theirs["id"]) + suffix, {"landmark": "x"}, format="json"
        )
        assert error(response, 404)["code"] == "NOT_FOUND"
        assert Address.objects.get(pk=theirs["id"]).landmark != "x"
        assert not Address.objects.get(pk=theirs["id"]).is_deleted

    @pytest.mark.parametrize(("method", "suffix"), [("get", ""), ("post", "set-default/")])
    def test_requires_auth(self, api_client, method, suffix):
        response = getattr(api_client, method)(detail(1) + suffix)
        assert error(response, 401)["code"] == "AUTH_REQUIRED"


class TestDefaultRules:
    def test_set_default_moves_it(self, auth_client):
        first = create(auth_client)
        second = create(auth_client)
        response = auth_client.post(detail(second["id"]) + "set-default/")
        assert response.status_code == 200
        assert response.json()["is_default"] is True
        assert auth_client.get(detail(first["id"])).json()["is_default"] is False
        # Idempotent
        assert auth_client.post(detail(second["id"]) + "set-default/").json()["is_default"]

    def test_deleting_the_default_promotes_the_most_recently_updated(self, auth_client):
        default = create(auth_client, house="default")
        older = create(auth_client, house="older")
        newer = create(auth_client, house="newer")
        auth_client.patch(detail(older["id"]), {"landmark": "touched"}, format="json")
        auth_client.delete(detail(default["id"]))
        assert auth_client.get(detail(older["id"])).json()["is_default"] is True
        assert auth_client.get(detail(newer["id"])).json()["is_default"] is False

    def test_deleting_a_non_default_keeps_the_default(self, auth_client):
        default = create(auth_client)
        other = create(auth_client)
        auth_client.delete(detail(other["id"]))
        assert auth_client.get(detail(default["id"])).json()["is_default"] is True

    def test_deleting_the_last_address(self, auth_client):
        only = create(auth_client)
        assert auth_client.delete(detail(only["id"])).status_code == 204
        assert auth_client.get(URL).json()["count"] == 0

    def test_database_allows_one_default_per_user(self, user):
        fields = {
            "user": user,
            "label": "home",
            "receiver_name": "A",
            "receiver_phone": "+919876543210",
            "house": "1",
            "building_street": "S",
            "city": "C",
            "state": "S",
            "pincode": "122001",
            "lat": 1,
            "lng": 1,
            "is_default": True,
        }
        Address.objects.create(**fields)
        Address.objects.create(**{**fields, "is_deleted": True})  # deleted ones don't count
        with pytest.raises(IntegrityError):
            Address.objects.create(**fields)
