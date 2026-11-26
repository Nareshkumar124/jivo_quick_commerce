"""ADR 0004 §1: delivery by pincode. The cached snapshot (pincode mode, active pincodes, buffered
outlines), the location check, the customer message, the address list's flag, the audited
services and `import_pincode_boundaries`."""

import json
from io import StringIO
from unittest import mock

import pytest
from django.contrib.auth.models import Group
from django.contrib.gis.geos import MultiPolygon, Point, Polygon
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.management import call_command

from apps.accounts import examples as accounts_ex
from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.core.models import AuditLog
from apps.stores import services
from apps.stores.models import DeliveryPincode, PincodeBoundary
from apps.stores.services import (
    MSG_NOT_SERVICEABLE,
    active_store,
    add_delivery_pincode,
    check_serviceability,
    set_delivery_pincode_active,
    update_delivery_pincode,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

# A 0.02 x 0.02 degree outline (about 2 km) in the middle of the factory store's service area.
OUTLINE_BOX = (77.04, 28.44, 77.06, 28.46)
CENTER = (28.45, 77.05)
NEAR = (28.4613, 77.05)  # about 145 m north of the outline: inside the 250 m buffer
BEYOND = (28.4636, 77.05)  # about 400 m north: outside the buffer
IN_AREA_ONLY = (28.48, 77.08)  # inside the service area, far from the outline
GHAZIABAD = (28.6692, 77.4538)  # outside everything

RAJOURI_GARDEN_METRO = (28.64906, 77.12272)
TAGORE_GARDEN_METRO = (28.64373, 77.11282)
SUBHASH_NAGAR = (28.63635, 77.11521)


def outline(pincode="110027", box=OUTLINE_BOX) -> PincodeBoundary:
    return PincodeBoundary.objects.create(
        pincode=pincode, geom=MultiPolygon(Polygon.from_bbox(box), srid=4326), source="test"
    )


def pin(store, pincode="110027", **kwargs) -> DeliveryPincode:
    return DeliveryPincode.objects.create(store=store, pincode=pincode, **kwargs)


def served(lat_lng) -> bool:
    return check_serviceability(*lat_lng)["serviceable"]


class TestSnapshot:
    def test_a_store_without_pincodes_keeps_the_service_area(self):
        store = DarkStoreFactory()
        area = active_store(store.pk)
        assert (area.pincode_mode, area.pincodes, area.outline) == (False, (), None)
        assert served(IN_AREA_ONLY)
        assert not served(GHAZIABAD)

    def test_pincode_mode_uses_the_buffered_outline_not_the_area(self):
        """P-ADR4: in pincode mode the service area polygon is ignored."""
        store = DarkStoreFactory()
        outline()
        pin(store, area_name="Rajouri Garden")
        area = active_store(store.pk)
        assert area.pincode_mode is True
        assert area.pincodes == ("110027",)
        assert area.places == ("Rajouri Garden (110027)",)
        assert served(CENTER)
        assert served(NEAR)  # the 250 m buffer
        assert not served(BEYOND)
        assert not served(IN_AREA_ONLY)  # inside the polygon, but not in an active pincode

    def test_inactive_pincodes_keep_pincode_mode(self):
        store = DarkStoreFactory()
        outline()
        row = pin(store, is_active=False)
        area = active_store(store.pk)
        assert (area.pincode_mode, area.pincodes, area.outline) == (True, (), None)
        assert not served(CENTER)
        assert not served(IN_AREA_ONLY)
        row.is_active = True
        row.save()  # the signal refreshes the snapshot: served at once
        assert served(CENTER)

    def test_an_active_pincode_without_an_outline_covers_no_location(self):
        store = DarkStoreFactory()
        pin(store, "110064")
        assert active_store(store.pk).outline is None
        assert not served(CENTER)

    def test_outline_changes_reach_the_snapshot(self):
        store = DarkStoreFactory()
        pin(store)
        assert not served(CENTER)
        boundary = outline()  # imported later: served at once
        assert served(CENTER)
        boundary.geom = MultiPolygon(Polygon.from_bbox((77.07, 28.47, 77.09, 28.49)), srid=4326)
        boundary.save()
        assert not served(CENTER)
        assert served(IN_AREA_ONLY)
        boundary.delete()
        assert not served(IN_AREA_ONLY)

    def test_cold_load_query_counts(self, django_assert_num_queries):
        store = DarkStoreFactory()
        with django_assert_num_queries(2):  # stores (with their pincodes), timings
            services._load_snapshot()
        outline()
        pin(store)
        with django_assert_num_queries(3):  # + the buffered outlines
            rows = services._load_snapshot()
        assert rows[0]["outline_wkb"]

    def test_snapshot_cached_before_adr_0004(self):
        """A snapshot written by the previous release (no pincode keys) means no pincode rule."""
        store = DarkStoreFactory()
        keys = ("pincode_mode", "pincodes", "places", "outline_wkb")
        rows = [
            {k: v for k, v in row.items() if k not in keys} for row in services._load_snapshot()
        ]
        with mock.patch("apps.stores.services._snapshot", return_value=rows):
            area = active_store(store.pk)
        assert (area.pincode_mode, area.outline) == (False, None)


class TestMessage:
    def test_names_at_most_three_places(self):
        assert services.not_delivered_message([]) == (
            "We don't deliver here yet. We'll come to your area soon."
        )
        assert services.not_delivered_message(["Rajouri Garden (110027)"]) == (
            "We don't deliver here yet. We deliver in Rajouri Garden (110027). "
            "We'll come to your area soon."
        )
        assert services.not_delivered_message(["110001", "110002", "110003", "110004"]) == (
            "We don't deliver here yet. We deliver in 110001, 110002, 110003 and more. "
            "We'll come to your area soon."
        )

    def test_location_message(self, api_client):
        store = DarkStoreFactory()
        assert check_serviceability(*GHAZIABAD)["message"] == MSG_NOT_SERVICEABLE
        pin(store, area_name="Rajouri Garden")
        pin(store, "110015")
        pin(store, "110018", is_active=False)
        body = api_client.get(
            "/api/v1/serviceability/", {"lat": GHAZIABAD[0], "lng": GHAZIABAD[1]}
        ).json()
        assert body == {
            "serviceable": False,
            "store": None,
            "eta_minutes": None,
            "message": "We don't deliver here yet. We deliver in 110015, Rajouri Garden "
            "(110027). We'll come to your area soon.",
        }


class TestRealOutline:
    def test_bundled_file_puts_rajouri_garden_in_110027(self):
        """ADR 0004 data check: the Delhi file's 110027 outline holds the three landmarks, and
        a store delivering to 110027 serves them (its Gurugram service area is ignored)."""
        call_command("import_pincode_boundaries", "--commit", stdout=StringIO())
        assert PincodeBoundary.objects.count() == 96
        geom = PincodeBoundary.objects.get(pincode="110027").geom
        for lat, lng in (RAJOURI_GARDEN_METRO, TAGORE_GARDEN_METRO, SUBHASH_NAGAR):
            assert geom.contains(Point(lng, lat, srid=4326))
        store = DarkStoreFactory()
        pin(store, area_name="Rajouri Garden / Tagore Garden / Subhash Nagar")
        assert served(RAJOURI_GARDEN_METRO)
        assert served(SUBHASH_NAGAR)
        assert not served(CENTER)  # inside the store's own (Gurugram) area: ignored now
        assert check_serviceability(*RAJOURI_GARDEN_METRO)["store"]["id"] == store.pk


class TestAddressListFlag:
    URL = "/api/v1/addresses/"

    def test_pincode_mode_flags_by_address_pincode(self, make_auth_client, user):
        store = DarkStoreFactory()
        pin(store)
        client = make_auth_client(user)
        base = {**accounts_ex.ADDRESS_CREATE_REQUEST, "lat": CENTER[0], "lng": CENTER[1]}
        ok = client.post(self.URL, {**base, "pincode": "110027"}, format="json").json()
        other = client.post(self.URL, {**base, "pincode": "110064"}, format="json").json()
        assert (ok["is_serviceable"], other["is_serviceable"]) == (True, False)
        listed = {a["id"]: a["is_serviceable"] for a in client.get(self.URL).json()["results"]}
        assert listed == {ok["id"]: True, other["id"]: False}
        DeliveryPincode.objects.update(is_active=False)
        listed = {a["id"]: a["is_serviceable"] for a in client.get(self.URL).json()["results"]}
        assert listed == {ok["id"]: False, other["id"]: False}

    def test_area_stores_still_flag_by_the_pin(self, make_auth_client, user):
        DarkStoreFactory()
        client = make_auth_client(user)
        base = {**accounts_ex.ADDRESS_CREATE_REQUEST, "pincode": "110064"}
        inside = {**base, "lat": IN_AREA_ONLY[0], "lng": IN_AREA_ONLY[1]}
        assert client.post(self.URL, inside, format="json").json()["is_serviceable"] is True
        assert client.get(self.URL).json()["results"][0]["is_serviceable"] is True


@pytest.fixture
def admin_user():
    return SuperUserFactory()


def role_user(role):
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


def audit(action):
    return list(AuditLog.objects.filter(action=action).values_list("changes", flat=True))


class TestServices:
    def test_add(self, admin_user):
        store = DarkStoreFactory()
        row = add_delivery_pincode(
            store, " 110027 ", area_name=" Rajouri  Garden ", actor=admin_user
        )
        assert (row.pincode, row.area_name, row.is_active) == ("110027", "Rajouri Garden", True)
        assert active_store(store.pk).pincodes == ("110027",)  # applies at once
        assert audit("delivery_pincode.add") == [
            {"store_id": store.pk, "pincode": "110027", "is_active": True, "area_name_set": True}
        ]
        assert AuditLog.objects.get(action="delivery_pincode.add").actor == admin_user
        inactive = add_delivery_pincode(store.pk, "110015", is_active=False, actor=admin_user)
        assert inactive.is_active is False

    @pytest.mark.parametrize(
        ("store_ok", "pincode", "area_name", "field"),
        [
            (True, "11002", "", "pincode"),
            (True, "011002", "", "pincode"),
            (True, "abcdef", "", "pincode"),
            (True, "110027", "x" * 81, "area_name"),
            (False, "110027", "", "store"),
        ],
    )
    def test_add_validation(self, admin_user, store_ok, pincode, area_name, field):
        store = DarkStoreFactory() if store_ok else 999_999
        with pytest.raises(ValidationError) as error:
            add_delivery_pincode(store, pincode, area_name=area_name, actor=admin_user)
        assert field in error.value.message_dict
        assert not DeliveryPincode.objects.exists()
        assert not AuditLog.objects.exists()

    def test_add_duplicate(self, admin_user):
        store = DarkStoreFactory()
        add_delivery_pincode(store, "110027", actor=admin_user)
        with pytest.raises(ValidationError) as error:
            add_delivery_pincode(store, "110027", actor=admin_user)
        assert error.value.message_dict == {"pincode": [services.MSG_PINCODE_TAKEN]}
        add_delivery_pincode(DarkStoreFactory(), "110027", actor=admin_user)  # another store
        assert DeliveryPincode.objects.count() == 2

    def test_update(self, admin_user):
        store = DarkStoreFactory()
        row = pin(store, area_name="Old")
        pin(store, "110015")
        assert update_delivery_pincode(row, area_name="Old", actor=admin_user) is False
        with pytest.raises(ValidationError) as error:
            update_delivery_pincode(row, pincode="110015", actor=admin_user)
        assert error.value.message_dict == {"pincode": [services.MSG_PINCODE_TAKEN]}
        with pytest.raises(ValidationError):
            update_delivery_pincode(row, pincode="1", actor=admin_user)
        assert update_delivery_pincode(row, pincode="110018", area_name="New", actor=admin_user)
        row.refresh_from_db()
        assert (row.pincode, row.area_name) == ("110018", "New")
        assert audit("delivery_pincode.update") == [
            {"store_id": store.pk, "pincode": ["110027", "110018"], "area_name_changed": True}
        ]
        assert active_store(store.pk).pincodes == ("110015", "110018")

    def test_set_active(self, admin_user):
        store = DarkStoreFactory()
        row = pin(store)
        assert set_delivery_pincode_active(row, True, actor=admin_user) is False
        assert set_delivery_pincode_active(row, False, actor=admin_user) is True
        assert row.is_active is False
        assert active_store(store.pk).pincodes == ()
        assert set_delivery_pincode_active(row, True, actor=admin_user) is True
        assert active_store(store.pk).pincodes == ("110027",)
        assert list(AuditLog.objects.values_list("action", flat=True)) == [
            "delivery_pincode.activate",
            "delivery_pincode.deactivate",
        ]

    @pytest.mark.parametrize("role", [roles.OPS, roles.CATALOG_MANAGER, roles.STORE_MANAGER])
    def test_other_roles_are_refused(self, role):
        actor = role_user(role)
        store = DarkStoreFactory()
        row = pin(store)
        with pytest.raises(PermissionDenied):
            add_delivery_pincode(store, "110015", actor=actor)
        with pytest.raises(PermissionDenied):
            update_delivery_pincode(row, area_name="x", actor=actor)
        with pytest.raises(PermissionDenied):
            set_delivery_pincode_active(row, False, actor=actor)
        with pytest.raises(PermissionDenied):
            add_delivery_pincode(store, "110015", actor=None)

    def test_super_admin_role_may(self):
        actor = role_user(roles.SUPER_ADMIN)
        assert add_delivery_pincode(DarkStoreFactory(), "110027", actor=actor).pk


def write_geojson(tmp_path, features) -> str:
    path = tmp_path / "pins.geojson"
    path.write_text(
        json.dumps({"type": "FeatureCollection", "features": features}), encoding="utf-8"
    )
    return str(path)


def feature(pincode, box=OUTLINE_BOX, geometry=None, **properties):
    geometry = geometry or {
        "type": "Polygon",
        "coordinates": [list(Polygon.from_bbox(box).coords[0])],
    }
    return {
        "type": "Feature",
        "properties": {"pincode": pincode, **properties},
        "geometry": geometry,
    }


def run(*args) -> str:
    out = StringIO()
    call_command("import_pincode_boundaries", *args, stdout=out)
    return out.getvalue()


class TestImportCommand:
    def test_dry_run_then_commit_then_idempotent(self, tmp_path):
        path = write_geojson(
            tmp_path,
            [
                feature("110027", source="datagov+gsdl"),
                feature("110015", box=(77.07, 28.47, 77.09, 28.49)),
                feature("1100", source="x"),
                feature("110064", geometry={"type": "Point", "coordinates": [77.0, 28.0]}),
            ],
        )
        out = run("--file", path)
        assert "Dry run, nothing saved: 4 features read; would add 2" in out
        assert "skipped 2" in out
        assert "Run again with --commit" in out
        assert not PincodeBoundary.objects.exists()
        out = run("--file", path, "--commit")
        assert "Saved: 4 features read; added 2, updated 0, unchanged 0, skipped 2." in out
        assert dict(PincodeBoundary.objects.values_list("pincode", "source")) == {
            "110027": "datagov+gsdl",
            "110015": "",
        }
        out = run("--file", path, "--commit")
        assert "added 0, updated 0, unchanged 2" in out

    def test_changed_outline_is_updated(self, tmp_path):
        run("--file", write_geojson(tmp_path, [feature("110027")]), "--commit")
        moved = write_geojson(tmp_path, [feature("110027", box=(77.07, 28.47, 77.09, 28.49))])
        assert "would update 1" in run("--file", moved)
        assert "updated 1" in run("--file", moved, "--commit", "--source", "manual")
        boundary = PincodeBoundary.objects.get()
        assert boundary.source == "manual"
        assert boundary.geom.contains(Point(77.08, 28.48, srid=4326))

    def test_two_features_of_one_pincode_are_merged(self, tmp_path):
        path = write_geojson(
            tmp_path,
            [feature("110027"), feature("110027", box=(77.07, 28.47, 77.09, 28.49))],
        )
        run("--file", path, "--commit")
        geom = PincodeBoundary.objects.get().geom
        assert geom.contains(Point(77.05, 28.45, srid=4326))
        assert geom.contains(Point(77.08, 28.48, srid=4326))

    def test_bad_files(self, tmp_path):
        from django.core.management.base import CommandError

        with pytest.raises(CommandError, match="File not found"):
            run("--file", str(tmp_path / "missing.geojson"))
        bad = tmp_path / "bad.geojson"
        bad.write_text(json.dumps({"type": "Feature"}), encoding="utf-8")
        with pytest.raises(CommandError, match="not a GeoJSON FeatureCollection"):
            run("--file", str(bad))
