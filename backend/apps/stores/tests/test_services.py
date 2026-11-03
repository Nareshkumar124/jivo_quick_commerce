"""Stores (07 §2.2, 06 §2.3): opening status in IST, PostGIS serviceability with the 08 §8 ETA,
notify-me, staff store scoping and the address `is_serviceable` flag."""

from datetime import UTC, datetime, time
from unittest import mock

import pytest
from django.contrib.auth.models import Group
from django.contrib.gis.geos import Point
from django.test import override_settings
from freezegun import freeze_time

from apps.accounts import examples as accounts_ex
from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.stores import services
from apps.stores.models import ServiceabilityRequest, StoreTiming
from apps.stores.services import grant_store_access, revoke_store_access, stores_for
from apps.stores.tests.factories import DarkStoreFactory, square_area

pytestmark = pytest.mark.django_db

INSIDE = (28.4595, 77.0266)  # Sector 14 area, inside SQUARE
OUTSIDE = (28.6692, 77.4538)  # Ghaziabad
# Monday 2 Nov 2026, 10:00 IST = 04:30 UTC
MONDAY_10_IST = datetime(2026, 11, 2, 4, 30, tzinfo=UTC)


def store_with_hours(*windows, **kwargs):
    store = DarkStoreFactory(timings=False, **kwargs)
    for weekday, opens, closes in windows:
        StoreTiming.objects.create(store=store, weekday=weekday, opens_at=opens, closes_at=closes)
    return store


DAILY_7_TO_23 = [(day, time(7), time(23)) for day in range(7)]


class TestStoreStatus:
    def test_open(self):
        store = store_with_hours(*DAILY_7_TO_23)
        status = services.store_status(store, MONDAY_10_IST)
        assert (status.is_open, status.opens_at) == (True, None)
        assert services.status_message(status) is None

    def test_closed_tonight_opens_tomorrow(self):
        store = store_with_hours(*DAILY_7_TO_23)
        late = datetime(2026, 11, 2, 18, 0, tzinfo=UTC)  # 23:30 IST
        status = services.store_status(store, late)
        assert status.is_open is False
        assert status.opens_at == datetime(2026, 11, 3, 1, 30, tzinfo=UTC)  # 07:00 IST
        assert services.status_message(status, late) == (
            "The store is closed now. It opens tomorrow at 7:00 AM."
        )

    def test_before_opening_today(self):
        store = store_with_hours(*DAILY_7_TO_23)
        early = datetime(2026, 11, 2, 0, 0, tzinfo=UTC)  # 05:30 IST
        status = services.store_status(store, early)
        assert services.status_message(status, early) == (
            "The store is closed now. It opens at 7:00 AM."
        )

    def test_split_shift_and_weekday_names(self):
        # Monday 07:00-11:00 and 17:00-22:30 only.
        store = store_with_hours((0, time(7), time(11)), (0, time(17), time(22, 30)))
        lunch = datetime(2026, 11, 2, 7, 0, tzinfo=UTC)  # 12:30 IST
        status = services.store_status(store, lunch)
        assert status.opens_at == datetime(2026, 11, 2, 11, 30, tzinfo=UTC)  # 17:00 IST
        assert services.status_message(status, lunch).endswith("It opens at 5:00 PM.")
        night = datetime(2026, 11, 2, 18, 0, tzinfo=UTC)
        status = services.store_status(store, night)
        assert status.opens_at == datetime(2026, 11, 9, 1, 30, tzinfo=UTC)  # next Monday
        assert services.status_message(status, night).endswith("It opens on Monday at 7:00 AM.")

    def test_window_to_midnight(self):
        store = store_with_hours((0, time(18), time(23, 59)), (1, time(0), time(2)))
        just_before_midnight = datetime(2026, 11, 2, 18, 29, 50, tzinfo=UTC)  # 23:59:50 IST
        assert services.store_status(store, just_before_midnight).is_open
        after_midnight = datetime(2026, 11, 2, 19, 0, tzinfo=UTC)  # Tue 00:30 IST
        assert services.store_status(store, after_midnight).is_open

    def test_paused_and_no_timings(self):
        paused = store_with_hours(*DAILY_7_TO_23, is_accepting_orders=False)
        status = services.store_status(paused, MONDAY_10_IST)
        assert (status.is_open, status.opens_at) == (False, None)
        assert services.status_message(status) == services.MSG_PAUSED
        never = store_with_hours()
        assert services.store_status(never, MONDAY_10_IST).opens_at is None


class TestServiceability:
    def test_inside_open_store(self, api_client):
        store = DarkStoreFactory(name="Jivo Sector 14")
        response = api_client.get("/api/v1/serviceability/", {"lat": INSIDE[0], "lng": INSIDE[1]})
        assert response.status_code == 200
        body = response.json()
        assert body["serviceable"] is True
        assert body["store"] == {
            "id": store.pk,
            "name": "Jivo Sector 14",
            "is_open": True,
            "opens_at": None,
        }
        assert body["message"] is None
        assert 10 <= body["eta_minutes"] <= 30

    def test_outside(self, api_client):
        DarkStoreFactory()
        body = api_client.get("/api/v1/serviceability/", {"lat": OUTSIDE[0], "lng": OUTSIDE[1]})
        assert body.json() == {
            "serviceable": False,
            "store": None,
            "eta_minutes": None,
            "message": services.MSG_NOT_SERVICEABLE,
        }

    @freeze_time("2026-11-02T18:00:00Z")  # 23:30 IST
    def test_closed_store(self, api_client):
        store_with_hours(*DAILY_7_TO_23)
        body = api_client.get(
            "/api/v1/serviceability/", {"lat": INSIDE[0], "lng": INSIDE[1]}
        ).json()
        assert body["serviceable"] is True
        assert body["store"]["is_open"] is False
        assert body["store"]["opens_at"] == "2026-11-03T01:30:00Z"
        assert body["eta_minutes"] is None
        assert body["message"] == "The store is closed now. It opens tomorrow at 7:00 AM."

    def test_inactive_store_is_ignored(self):
        DarkStoreFactory(is_active=False)
        assert services.check_serviceability(*INSIDE)["serviceable"] is False

    def test_overlap_prefers_open_then_nearest_then_priority(self):
        """07 §2.2: nearest open store; tie-break by priority."""
        far_open = DarkStoreFactory(location=Point(77.09, 28.49, srid=4326))
        near_closed = DarkStoreFactory(location=Point(77.027, 28.46, srid=4326), timings=False)
        assert services.check_serviceability(*INSIDE)["store"]["id"] == far_open.pk
        near_open = DarkStoreFactory(location=Point(77.03, 28.46, srid=4326))
        assert services.check_serviceability(*INSIDE)["store"]["id"] == near_open.pk
        twin = DarkStoreFactory(location=Point(77.03, 28.46, srid=4326), priority=1)
        assert services.check_serviceability(*INSIDE)["store"]["id"] == twin.pk
        assert near_closed.pk not in {far_open.pk, near_open.pk}

    def test_only_closed_stores(self):
        closed = DarkStoreFactory(timings=False)
        result = services.check_serviceability(*INSIDE)
        assert result["store"]["id"] == closed.pk
        assert result["message"] == services.MSG_PAUSED  # no timings: no known reopening

    @override_settings(
        ETA_AVG_SPEED_KMPH=20.0, ETA_ROAD_FACTOR=1.3, ETA_BUFFER_MINUTES=2, ETA_RIDER_WAIT_MINUTES=3
    )
    def test_eta_formula(self):
        """08 §8: prep 8 + wait 3 + 2 km x 1.3 / 20 km/h (7.8 min) + buffer 2 = 20.8 -> 21."""
        store = DarkStoreFactory(avg_prep_minutes=8)
        assert services.eta_minutes(store, 2.0) == 21
        assert services.eta_minutes(store, 0) == 13


class TestNotifyMe:
    URL = "/api/v1/serviceability/notify-me/"

    def test_anonymous(self, api_client, conforms_stores):
        response = api_client.post(
            self.URL, {**accounts_ex_point(), "phone": "+919876543210"}, format="json"
        )
        assert response.status_code == 201
        body = response.json()
        conforms_stores(body, "NotifyMe")
        lead = ServiceabilityRequest.objects.get()
        assert (lead.user, lead.phone) == (None, "+919876543210")
        assert (body["lat"], body["lng"]) == (28.6692, 77.4538)

    def test_signed_in_defaults_phone_and_dedupes(self, make_auth_client):
        user = UserFactory(phone="+919811122233")
        client = make_auth_client(user)
        first = client.post(self.URL, accounts_ex_point(), format="json").json()
        again = client.post(
            self.URL, {"lat": 28.6693, "lng": 77.4538, "address_text": "same place"}, format="json"
        ).json()
        assert first["id"] == again["id"]
        assert first["phone"] == "+919811122233"
        lead = ServiceabilityRequest.objects.get()
        assert lead.user == user

    def test_anonymous_phone_dedupe_and_no_phone(self, api_client):
        body = {**accounts_ex_point(), "phone": "+919876543210"}
        assert (
            api_client.post(self.URL, body, format="json").json()["id"]
            == (api_client.post(self.URL, body, format="json").json()["id"])
        )
        api_client.post(self.URL, accounts_ex_point(), format="json")
        api_client.post(self.URL, accounts_ex_point(), format="json")
        assert ServiceabilityRequest.objects.count() == 3  # anonymous without phone: not merged

    def test_bug_0008_two_anonymous_callers_get_only_their_own_data(self, api_client):
        """BUG-0008 (P2-TC-18): an anonymous caller who types someone else's phone near their
        location must never get that person's stored details back."""
        phone = "+919876543210"
        victim = {"lat": 28.6692, "lng": 77.4538, "phone": phone, "address_text": "Flat 9, Tower C"}
        prober = {"lat": 28.6694, "lng": 77.4539, "phone": phone, "address_text": "anything"}
        first = api_client.post(self.URL, victim, format="json").json()
        second = api_client.post(self.URL, prober, format="json").json()
        assert second["address_text"] == "anything"
        assert (second["lat"], second["lng"]) == (28.6694, 77.4539)
        assert "Flat 9" not in str(second)
        assert second["id"] != first["id"]  # never merged into a lead with other details
        assert ServiceabilityRequest.objects.count() == 2

    def test_bug_0008_a_double_tap_is_merged_and_echoes_the_callers_values(self, api_client):
        body = {"lat": 28.6692, "lng": 77.4538, "phone": "+919876543210", "address_text": " A1 "}
        first = api_client.post(self.URL, body, format="json").json()
        nearby = {**body, "lat": 28.6693}
        again = api_client.post(self.URL, nearby, format="json").json()
        assert again["id"] == first["id"]
        assert (again["lat"], again["address_text"]) == (28.6693, "A1")  # the caller's values
        assert ServiceabilityRequest.objects.count() == 1

    def test_throttled(self, api_client):
        from apps.stores.views import NotifyMeThrottle

        with mock.patch.object(NotifyMeThrottle, "THROTTLE_RATES", {"notify_me": "2/hour"}):
            for _ in range(2):
                response = api_client.post(self.URL, accounts_ex_point(), format="json")
                assert response.status_code == 201
            response = api_client.post(self.URL, accounts_ex_point(), format="json")
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        assert response.json()["error"]["details"]["retry_after_seconds"] > 0

    def test_throttle_fails_open(self, api_client):
        with mock.patch(
            "rest_framework.throttling.SimpleRateThrottle.allow_request",
            side_effect=ConnectionError("redis down"),
        ):
            assert api_client.post(self.URL, accounts_ex_point(), format="json").status_code == 201


def accounts_ex_point() -> dict:
    from apps.stores import examples as ex

    return dict(ex.NOTIFY_ME_REQUEST)


@pytest.fixture
def conforms_stores():
    import jsonschema
    from drf_spectacular.generators import SchemaGenerator

    from tests.test_schema_examples import to_json_schema

    components = SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]

    def check(body, component):
        jsonschema.validate(
            body, to_json_schema({"$ref": f"#/components/schemas/{component}"}, components)
        )

    return check


class TestStaffScoping:
    def test_scoping(self):
        roles.sync_roles()
        store, other = DarkStoreFactory(), DarkStoreFactory()
        manager = StaffUserFactory()
        manager.groups.add(Group.objects.get(name=roles.STORE_MANAGER))
        ops = StaffUserFactory()
        ops.groups.add(Group.objects.get(name=roles.OPS))
        no_role = StaffUserFactory()
        assert set(stores_for(SuperUserFactory())) == {store, other}
        assert set(stores_for(ops)) == {store, other}
        assert list(stores_for(manager)) == []
        grant_store_access(manager, store)
        grant_store_access(manager, store)  # idempotent
        assert list(stores_for(manager)) == [store]
        revoke_store_access(manager, store)
        assert list(stores_for(manager)) == []
        assert list(stores_for(no_role)) == []
        assert list(stores_for(UserFactory())) == []  # customers are not staff
        assert list(stores_for(None)) == []


class TestAddressServiceability:
    """03 §2.4: unserviceable addresses can be saved but are flagged."""

    URL = "/api/v1/addresses/"

    def test_flag_on_create_list_and_move(self, make_auth_client, user):
        DarkStoreFactory()
        client = make_auth_client(user)
        inside = {**accounts_ex.ADDRESS_CREATE_REQUEST, "lat": INSIDE[0], "lng": INSIDE[1]}
        created = client.post(self.URL, inside, format="json").json()
        assert created["is_serviceable"] is True
        outside = {**inside, "lat": OUTSIDE[0], "lng": OUTSIDE[1]}
        assert client.post(self.URL, outside, format="json").json()["is_serviceable"] is False
        listed = {a["id"]: a["is_serviceable"] for a in client.get(self.URL).json()["results"]}
        assert listed[created["id"]] is True
        assert False in listed.values()
        moved = client.patch(
            f"{self.URL}{created['id']}/", {"lat": OUTSIDE[0], "lng": OUTSIDE[1]}, format="json"
        ).json()
        assert moved["is_serviceable"] is False
        assert client.get(f"{self.URL}{created['id']}/").json()["is_serviceable"] is False

    def test_location_is_written_with_the_decimals(self, make_auth_client, user):
        from apps.accounts.models import Address

        client = make_auth_client(user)
        client.post(self.URL, accounts_ex.ADDRESS_CREATE_REQUEST, format="json")
        address = Address.objects.get()
        assert (address.location.y, address.location.x) == (
            float(address.lat),
            float(address.lng),
        )

    def test_rows_without_location_fall_back_to_the_decimals(self, make_auth_client, user):
        from apps.accounts.models import Address

        DarkStoreFactory()
        client = make_auth_client(user)
        created = client.post(
            self.URL,
            {**accounts_ex.ADDRESS_CREATE_REQUEST, "lat": INSIDE[0], "lng": INSIDE[1]},
            format="json",
        ).json()
        Address.objects.filter(pk=created["id"]).update(location=None)  # as written before P2
        assert client.get(self.URL).json()["results"][0]["is_serviceable"] is True

    def test_list_query_count_is_constant(
        self, make_auth_client, user, django_assert_max_num_queries
    ):
        from apps.cms.services import get_app_config

        DarkStoreFactory(service_area=square_area())
        client = make_auth_client(user)
        for _ in range(4):
            client.post(self.URL, accounts_ex.ADDRESS_CREATE_REQUEST, format="json")
        get_app_config()
        with django_assert_max_num_queries(4):  # user, count, page (EXISTS inline), +1 slack
            assert client.get(self.URL).status_code == 200

    def test_receiver_reset_to_own(self, make_auth_client):
        """T-205: an empty string resets the receiver to the user's own name and phone."""
        user = UserFactory(name="Asha Verma", phone="+919876543210")
        client = make_auth_client(user)
        created = client.post(
            self.URL,
            {
                **accounts_ex.ADDRESS_CREATE_REQUEST,
                "receiver_name": "Sunita",
                "receiver_phone": "+919812345678",
            },
            format="json",
        ).json()
        assert created["receiver_name"] == "Sunita"
        reset = client.patch(
            f"{self.URL}{created['id']}/",
            {"receiver_name": "", "receiver_phone": ""},
            format="json",
        ).json()
        assert (reset["receiver_name"], reset["receiver_phone"]) == ("Asha Verma", "+919876543210")


class TestServiceabilitySnapshot:
    """09 §1 (p95 < 150 ms): the hot path reads a cached snapshot, never the database."""

    def test_warm_request_does_no_queries(self, api_client, django_assert_num_queries):
        from apps.cms.services import get_app_config

        DarkStoreFactory()
        get_app_config()
        api_client.get("/api/v1/serviceability/", {"lat": INSIDE[0], "lng": INSIDE[1]})
        with django_assert_num_queries(0):
            response = api_client.get(
                "/api/v1/serviceability/", {"lat": INSIDE[0], "lng": INSIDE[1]}
            )
        assert response.json()["serviceable"] is True

    def test_store_and_timing_changes_invalidate(self):
        store = DarkStoreFactory()
        assert services.check_serviceability(*INSIDE)["store"]["is_open"] is True
        store.is_accepting_orders = False
        store.save()
        assert services.check_serviceability(*INSIDE)["store"]["is_open"] is False
        store.is_active = False
        store.save()
        assert services.check_serviceability(*INSIDE)["serviceable"] is False

    def test_redis_down_reads_postgis(self):
        import redis

        DarkStoreFactory()
        down = redis.exceptions.ConnectionError("down")
        with mock.patch("apps.stores.services.cache.get", side_effect=down):
            assert services.check_serviceability(*INSIDE)["serviceable"] is True
        with mock.patch("apps.stores.services.cache.incr", side_effect=down):
            services.bump_stores_version()  # logged, not raised
        with mock.patch("apps.stores.services.cache.set", side_effect=down):
            assert services.is_point_serviceable(*INSIDE) is True

    def test_haversine(self):
        # Sector 14 to Cyber City, Gurugram: about 4.4 km.
        assert 4.0 < services.haversine_km(28.4710, 77.0440, 28.4950, 77.0890) < 5.2
