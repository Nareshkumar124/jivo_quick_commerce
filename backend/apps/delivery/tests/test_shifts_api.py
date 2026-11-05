"""Slice 5.2 (T-513): shifts and guards, location ingestion, heartbeat, auto-offline."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.cache import cache
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.choices import RiderStatus
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.exceptions import ApiError
from apps.delivery.choices import DocumentStatus, ShiftEndReason
from apps.delivery.models import Rider, RiderLocation, RiderShift
from apps.delivery.services import shifts
from apps.delivery.tasks import rider_heartbeat_check
from apps.delivery.tests.factories import RiderFactory, active_rider

pytestmark = pytest.mark.django_db

START = "/api/v1/rider/shift/start/"
END = "/api/v1/rider/shift/end/"
LOC = "/api/v1/rider/locations/"
BEAT = "/api/v1/rider/heartbeat/"
AT_STORE = {"lat": 28.4501, "lng": 77.0501}  # the factory store is at (28.45, 77.05)


@pytest.fixture
def rider():
    return active_rider()


@pytest.fixture
def client(rider, make_auth_client):
    return make_auth_client(rider.user, "rider")


def point(seconds_ago=5, **extra):
    data = {
        "lat": 28.4502,
        "lng": 77.0503,
        "accuracy": 8.0,
        "speed": 5.0,
        "heading": 90.0,
        "recorded_at": (timezone.now() - timedelta(seconds=seconds_ago)).isoformat(),
    }
    data.update(extra)
    return data


# --------------------------------------------------------------------------- start


def test_go_online(client, rider):
    response = client.post(START, AT_STORE, format="json")
    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["is_online"] is True
    assert body["prepaid_only"] is False
    assert body["shift"]["ended_at"] is None
    assert body["shift"]["ended_by"] is None
    assert body["location"]["max_batch"] == 50
    rider.refresh_from_db()
    assert rider.is_online
    assert rider.last_location_at
    assert cache.get(shifts.location_cache_key(rider.pk))["lat"] == AT_STORE["lat"]
    # Idempotent: the same open shift.
    again = client.post(START, AT_STORE, format="json")
    assert again.json()["shift"]["id"] == body["shift"]["id"]
    assert RiderShift.objects.filter(rider=rider).count() == 1


def test_cash_over_limit_is_prepaid_only(client, rider):
    Rider.objects.filter(pk=rider.pk).update(cash_in_hand=Decimal("5000.00"))
    body = client.post(START, AT_STORE, format="json").json()
    assert body["prepaid_only"] is True
    assert body["cash"] == {
        "cash_in_hand": "5000.00",
        "cash_limit": "5000.00",
        "limit_reached": True,
    }


def test_too_far_from_store(client):
    response = client.post(START, {"lat": 28.48, "lng": 77.05}, format="json")
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "OUTSIDE_GEOFENCE"
    assert error["details"]["reason"] == "TOO_FAR_FROM_STORE"
    assert error["details"]["radius_m"] == 2000
    assert 3000 < error["details"]["distance_m"] < 3600


def test_rejected_document_blocks_going_online(client, rider):
    rider.documents.filter(doc_type="DL").update(status=DocumentStatus.REJECTED)
    response = client.post(START, AT_STORE, format="json")
    assert response.status_code == 409
    assert response.json()["error"]["details"] == {
        "reason": "DOCUMENTS_NOT_APPROVED",
        "doc_types": ["DL"],
    }
    rider.documents.filter(doc_type="DL").update(status=DocumentStatus.PENDING)
    assert client.post(START, AT_STORE, format="json").status_code == 409


@pytest.mark.parametrize("status", [RiderStatus.PENDING_KYC, RiderStatus.SUSPENDED])
def test_not_active_cannot_go_online(make_auth_client, status):
    rider = RiderFactory(status=status)
    response = make_auth_client(rider.user, "rider").post(START, AT_STORE, format="json")
    assert response.status_code == 403
    assert response.json()["error"]["details"] == {
        "reason": "RIDER_NOT_ACTIVE",
        "rider_status": status,
    }


def test_start_validation(client):
    response = client.post(START, {"lat": 100}, format="json")
    assert response.status_code == 400
    assert {"lat", "lng"} <= set(response.json()["error"]["details"])


# --------------------------------------------------------------------------- end


def test_go_offline_and_idempotent(client, rider):
    client.post(START, AT_STORE, format="json")
    response = client.post(END)
    assert response.status_code == 200
    body = response.json()
    assert body["is_online"] is False
    assert body["shift"]["end_reason"] == "MANUAL"
    assert body["shift"]["ended_by"] == "rider"
    again = client.post(END)
    assert again.status_code == 200
    assert again.json()["shift"]["id"] == body["shift"]["id"]


def test_offline_refused_during_a_task(client, monkeypatch):
    client.post(START, AT_STORE, format="json")
    monkeypatch.setattr(shifts, "has_active_task", lambda rider: True)
    response = client.post(END)
    assert response.status_code == 409
    assert response.json()["error"]["details"] == {"reason": "ACTIVE_TASK"}


def test_has_active_task_is_false_before_tasks_exist(rider):
    assert shifts.has_active_task(rider) is False


# --------------------------------------------------------------------------- locations


def test_locations_stored_deduplicated_and_rejected(client, rider):
    client.post(START, AT_STORE, format="json")
    # The shift-start position is "now"; make the buffered points below newer than it.
    Rider.objects.filter(pk=rider.pk).update(last_location_at=timezone.now() - timedelta(minutes=1))
    good, older = point(5), point(15, lat=28.4510)
    batch = {"points": [older, good, good, point(48 * 3600), point(-600)]}
    response = client.post(LOC, batch, format="json")
    assert response.status_code == 200, response.json()
    body = response.json()
    assert (body["accepted"], body["duplicates"], body["rejected"]) == (2, 1, 2)
    resent = client.post(LOC, {"points": [older, good]}, format="json").json()
    assert (resent["accepted"], resent["duplicates"]) == (0, 2)
    assert RiderLocation.objects.filter(rider=rider).count() == 2
    rider.refresh_from_db()
    assert rider.current_location.y == pytest.approx(good["lat"])  # the newest point wins
    location = shifts.latest_location(rider)
    assert location["lat"] == pytest.approx(good["lat"])
    # An older batch arriving late does not move the rider back.
    client.post(LOC, {"points": [point(60, lat=28.46)]}, format="json")
    rider.refresh_from_db()
    assert rider.current_location.y == pytest.approx(good["lat"])


def test_locations_when_offline_is_409_rider_offline(client):
    response = client.post(LOC, {"points": [point()]}, format="json")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "RIDER_OFFLINE"


def test_locations_batch_limit(client):
    client.post(START, AT_STORE, format="json")
    response = client.post(LOC, {"points": [point(i + 1) for i in range(51)]}, format="json")
    assert response.status_code == 400
    assert client.post(LOC, {"points": []}, format="json").status_code == 400


def test_mocked_points_are_kept_and_flagged(client, rider):
    client.post(START, AT_STORE, format="json")
    client.post(LOC, {"points": [point(is_mocked=True)]}, format="json")
    assert RiderLocation.objects.get(rider=rider).is_mocked is True


def test_latest_location_falls_back_to_the_row(rider):
    assert shifts.latest_location(rider) is None
    from django.contrib.gis.geos import Point

    Rider.objects.filter(pk=rider.pk).update(
        current_location=Point(77.05, 28.45, srid=4326), last_location_at=timezone.now()
    )
    rider.refresh_from_db()
    assert shifts.latest_location(rider)["lat"] == pytest.approx(28.45)


# --------------------------------------------------------------------------- heartbeat


def test_heartbeat(client, rider):
    body = client.post(BEAT).json()
    assert body["is_online"] is False
    assert body["shift"] is None
    client.post(START, AT_STORE, format="json")
    body = client.post(BEAT).json()
    assert body["is_online"] is True
    assert body["pending_offer_id"] is None
    assert body["active_task_id"] is None
    rider.refresh_from_db()
    assert rider.last_heartbeat_at is not None


# --------------------------------------------------------------------------- auto-offline


def test_auto_offline_after_ten_minutes_without_location(client, rider):
    client.post(START, AT_STORE, format="json")
    assert rider_heartbeat_check() == {"offline": 0, "on_task": 0}
    with freeze_time(timezone.now() + timedelta(minutes=11)):
        assert rider_heartbeat_check() == {"offline": 1, "on_task": 0}
        body = client.post(BEAT).json()
    assert body["is_online"] is False
    assert body["shift"]["end_reason"] == "AUTO_OFFLINE"
    assert body["shift"]["ended_by"] == "system"
    assert rider_heartbeat_check() == {"offline": 0, "on_task": 0}  # idempotent


def test_auto_offline_skips_riders_on_a_task(client, monkeypatch):
    client.post(START, AT_STORE, format="json")
    monkeypatch.setattr(shifts, "has_active_task", lambda rider: True)
    with freeze_time(timezone.now() + timedelta(minutes=11)):
        assert shifts.auto_offline_stale() == {"offline": 0, "on_task": 1}


def test_recent_location_keeps_the_rider_online(client):
    client.post(START, AT_STORE, format="json")
    with freeze_time(timezone.now() + timedelta(minutes=9)):
        client.post(LOC, {"points": [point(1)]}, format="json")
    with freeze_time(timezone.now() + timedelta(minutes=15)):
        assert shifts.auto_offline_stale()["offline"] == 0


# --------------------------------------------------------------------------- ops


def test_force_offline(client, rider):
    roles.sync_roles()
    from django.contrib.auth.models import Group

    ops = StaffUserFactory()
    ops.groups.add(Group.objects.get(name=roles.OPS))
    assert shifts.force_offline(rider.pk, by=ops).is_online is False  # already offline: no-op
    client.post(START, AT_STORE, format="json")
    shifts.force_offline(rider.pk, by=ops)
    shift = RiderShift.objects.get(rider=rider)
    assert shift.end_reason == ShiftEndReason.ADMIN
    assert shift.ended_by == ops
    client.post(START, AT_STORE, format="json")
    from unittest import mock

    with (
        mock.patch.object(shifts, "has_active_task", return_value=True),
        pytest.raises(ApiError),
    ):
        shifts.force_offline(rider.pk, by=ops)


def test_today_counts_online_time(client, rider):
    from apps.delivery.services import summary

    start = timezone.now()
    with freeze_time(start):
        client.post(START, AT_STORE, format="json")
    with freeze_time(start + timedelta(minutes=30)):
        today = summary.today(rider, timezone.now())
    assert 1790 <= today["online_seconds"] <= 1810


def test_simulate_rider_command(rider):
    from io import StringIO

    from django.core.management import CommandError, call_command

    out = StringIO()
    call_command(
        "simulate_rider",
        phone=rider.user.phone,
        to="28.4560,77.0560",
        steps=3,
        interval=0,
        go_online=True,
        stdout=out,
    )
    assert "done" in out.getvalue()
    assert RiderLocation.objects.filter(rider=rider).count() == 3
    with pytest.raises(CommandError):
        call_command("simulate_rider", phone="+919999999999", to="1,2", stdout=out)
    with pytest.raises(CommandError):
        call_command("simulate_rider", phone=rider.user.phone, to="bad", stdout=out)


def test_new_position_is_published_through_the_p6_hook(
    client, rider, monkeypatch, django_capture_on_commit_callbacks
):
    from apps.delivery import hooks

    calls = []
    monkeypatch.setattr(hooks, "publish_rider_location", lambda *args: calls.append(args))
    client.post(START, AT_STORE, format="json")
    Rider.objects.filter(pk=rider.pk).update(last_location_at=timezone.now() - timedelta(minutes=1))
    with django_capture_on_commit_callbacks(execute=True):
        client.post(LOC, {"points": [point(1)]}, format="json")
    assert len(calls) == 1
    assert calls[0][0] == rider.pk


def test_hook_stubs_do_not_raise(rider):
    from apps.delivery import hooks

    hooks.send_push(rider.user, "rider.offer", {})
    hooks.publish_rider_location(rider.pk, 28.45, 77.05, timezone.now())
    hooks.publish_offer(rider.pk, {"id": 1})


# --------------------------------------------------------------------------- #42 presence


def _online(client, rider, location_age_min, heartbeat_age_min=None):
    client.post(START, AT_STORE, format="json")
    now = timezone.now()
    Rider.objects.filter(pk=rider.pk).update(
        last_location_received_at=now - timedelta(minutes=location_age_min),
        last_heartbeat_at=(
            now - timedelta(minutes=heartbeat_age_min) if heartbeat_age_min is not None else None
        ),
    )


@pytest.mark.parametrize(
    ("location_age", "heartbeat_age", "offline"),
    [
        (5, None, 0),  # recent point
        (11, None, 1),  # no point for 10 min, no heartbeat
        (11, 2, 0),  # heartbeat keeps a rider without a fix online...
        (25, 2, 0),
        (31, 2, 1),  # ...but not when the last point is older than 30 min
        (11, 12, 1),  # heartbeat too old
    ],
)
def test_heartbeat_presence_rule(client, rider, location_age, heartbeat_age, offline):
    """api-requests #42 (PM default)."""
    _online(client, rider, location_age, heartbeat_age)
    assert shifts.auto_offline_stale()["offline"] == offline


def test_heartbeat_endpoint_keeps_an_indoor_rider_online(client, rider):
    _online(client, rider, 15)
    client.post(BEAT)
    assert shifts.auto_offline_stale()["offline"] == 0
    rider.refresh_from_db()
    assert rider.is_online


def test_cache_outage_is_tolerated(client, rider, monkeypatch):
    def boom(*args, **kwargs):
        import redis

        raise redis.ConnectionError("redis down")

    monkeypatch.setattr(shifts.cache, "set", boom)
    monkeypatch.setattr(shifts.cache, "get", boom)
    assert client.post(START, AT_STORE, format="json").status_code == 200
    rider.refresh_from_db()
    assert shifts.latest_location(rider)["lat"] == pytest.approx(AT_STORE["lat"])


def test_has_active_task_with_a_real_task(rider):
    """Slice 5.3: a busy task (ASSIGNED..RETURNING) makes the rider busy; ended ones do not."""
    from decimal import Decimal

    from apps.delivery.models import DeliveryTask
    from apps.orders.tests.factories import OrderFactory

    task = DeliveryTask.objects.create(
        order=OrderFactory(store=rider.home_store),
        store=rider.home_store,
        rider=rider,
        status="RETURNING",
        search_started_at=timezone.now(),
        distance_km=Decimal("1.00"),
        payout_amount=Decimal("35.00"),
    )
    assert shifts.has_active_task(rider) is True
    DeliveryTask.objects.filter(pk=task.pk).update(status="RETURNED")
    assert shifts.has_active_task(rider) is False


def test_presence_uses_server_receipt_time_not_the_device_clock(client, rider):
    """A phone clock 20 minutes behind: its fresh points still keep the rider online."""
    client.post(START, AT_STORE, format="json")
    # 12 minutes later (the 15-minute access token is still valid), a point stamped 20 minutes
    # ago by the phone: by the device clock the rider looks stale, by receipt time not.
    with freeze_time(timezone.now() + timedelta(minutes=12)):
        response = client.post(LOC, {"points": [point(20 * 60)]}, format="json")
        assert response.status_code == 200, response.json()
        assert response.json()["accepted"] == 1
        assert shifts.auto_offline_stale()["offline"] == 0
    rider.refresh_from_db()
    assert rider.last_location_received_at > rider.last_location_at


def test_a_clock_running_ahead_never_moves_the_position_time_past_now(client, rider):
    client.post(START, AT_STORE, format="json")
    Rider.objects.filter(pk=rider.pk).update(last_location_at=timezone.now() - timedelta(minutes=1))
    before = timezone.now()
    body = client.post(LOC, {"points": [point(-90)]}, format="json").json()  # 90 s ahead
    assert body["accepted"] == 1
    rider.refresh_from_db()
    assert rider.last_location_at <= timezone.now()
    assert rider.last_location_at >= before


def test_on_task_warning_is_throttled(client, monkeypatch, caplog):
    client.post(START, AT_STORE, format="json")
    monkeypatch.setattr(shifts, "has_active_task", lambda rider: True)
    with freeze_time(timezone.now() + timedelta(minutes=11)):
        shifts.auto_offline_stale()
        shifts.auto_offline_stale()
    assert sum("is on a task" in r.message for r in caplog.records) == 1


# --------------------------------------------------------------------------- rate limits (review)


@pytest.mark.parametrize(
    ("throttle", "scope", "method", "path", "body"),
    [
        ("RiderHeartbeatThrottle", "rider_heartbeat", "post", BEAT, None),
        ("RiderLocationsThrottle", "rider_locations", "post", LOC, {"points": []}),
    ],
)
def test_rider_rate_limits(client, monkeypatch, throttle, scope, method, path, body):
    from apps.delivery import throttling

    monkeypatch.setattr(getattr(throttling, throttle), "THROTTLE_RATES", {scope: "1/min"})
    getattr(client, method)(path, body, format="json")
    response = getattr(client, method)(path, body, format="json")
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "RATE_LIMITED"
    assert "retry_after_seconds" in response.json()["error"]["details"]


def test_rate_limits_fail_open(client, monkeypatch):
    from apps.delivery import throttling

    def boom(*args, **kwargs):
        import redis

        raise redis.ConnectionError("redis down")

    monkeypatch.setattr(
        throttling.RiderHeartbeatThrottle, "THROTTLE_RATES", {"rider_heartbeat": "1/min"}
    )
    monkeypatch.setattr(throttling.RiderHeartbeatThrottle.cache, "get", boom)
    assert client.post(BEAT).status_code == 200
    assert client.post(BEAT).status_code == 200
