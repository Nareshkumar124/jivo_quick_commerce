"""Shifts and location (slice 5.2; 04 §2.3, §3; 06 §3, §5).

- Going online (`start_shift`): guards in 04 §2.3. Refusals carry a reason code in
  `details.reason` (api-requests, PM UX audit): 403 `PERMISSION_DENIED` (not ACTIVE,
  `details.rider_status`), 409 `INVALID_STATE_TRANSITION` `DOCUMENTS_NOT_APPROVED`
  (`details.doc_types`), 422 `OUTSIDE_GEOFENCE` `TOO_FAR_FROM_STORE` (`distance_m`,
  `radius_m`). Cash at or over the limit does not refuse: the rider is online for prepaid offers
  only (`prepaid_only`, with `cash_in_hand`/`cash_limit`). Already online: the open shift is
  returned (idempotent).
- Going offline (`end_shift`): refused during an active task (409 `ACTIVE_TASK`).
- Location (`ingest_locations`): de-duplicated on (rider, recorded_at); points older than
  `RIDER_LOCATION_MAX_AGE_HOURS` or too far in the future are counted as `rejected`. The latest
  point is mirrored on the rider row (for dispatch, PostGIS) and in Redis (for the live map and
  tracking; best effort). An offline rider gets 409 `RIDER_OFFLINE` (api-requests #4).
- Auto-offline (`auto_offline_stale`, beat `rider_heartbeat_check` every 2 minutes): riders
  online with no location for `RIDER_AUTO_OFFLINE_MINUTES` (10) are set offline (end reason
  AUTO_OFFLINE), unless they are on a task (ops are alerted instead) or a heartbeat came in
  that window while their last point is at most 30 minutes old (`stale_riders_filter`).
"""

import logging
from datetime import datetime, timedelta

from django.conf import settings
from django.contrib.gis.geos import Point
from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.delivery.choices import ShiftEndReason
from apps.delivery.models import Rider, RiderLocation, RiderShift
from apps.delivery.services.riders import require_rider
from apps.stores.services import haversine_km

__all__ = ["ShiftEndReason"]

logger = logging.getLogger(__name__)

MSG_DOCUMENTS = "A document needs a new approved copy before you can go online."
MSG_TOO_FAR = "Go to your store to go online."
MSG_ACTIVE_TASK = "Finish your delivery before going offline."
MSG_OFFLINE = "You are offline. Go online again to continue."
LOCATION_CACHE_SECONDS = 60 * 60


def _record(ip, *args):
    """`audit.record` with the request IP the panel passes (`ip=`)."""
    return audit.record(*args, ip=ip)


def location_cache_key(rider_id: int) -> str:
    return f"delivery:rider-location:{rider_id}"


def has_active_task(rider: Rider) -> bool:
    """True while the rider has a delivery task in progress (including RETURNING)."""
    from apps.delivery.models import RIDER_BUSY_STATUSES, DeliveryTask

    return DeliveryTask.objects.filter(rider=rider, status__in=RIDER_BUSY_STATUSES).exists()


def distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    return round(haversine_km(lat1, lng1, lat2, lng2) * 1000)


def open_shift(rider: Rider) -> RiderShift | None:
    return RiderShift.objects.filter(rider=rider, ended_at__isnull=True).first()


def last_shift(rider: Rider) -> RiderShift | None:
    return RiderShift.objects.filter(rider=rider).order_by("-started_at", "-id").first()


def _remember_location(rider_id: int, lat: float, lng: float, recorded_at, accuracy) -> None:
    try:
        cache.set(
            location_cache_key(rider_id),
            {
                "lat": lat,
                "lng": lng,
                "accuracy": accuracy,
                "recorded_at": recorded_at.isoformat(),
            },
            LOCATION_CACHE_SECONDS,
        )
    except Exception:  # Redis is a cache here (09 §2): the DB row is the source of truth
        logger.warning("Could not cache rider %s location", rider_id, exc_info=True)


def latest_location(rider: Rider) -> dict | None:
    """`{lat, lng, accuracy, recorded_at}` of the rider's last point: Redis, else the row."""
    try:
        cached = cache.get(location_cache_key(rider.pk))
    except Exception:
        cached = None
    if cached:
        return {**cached, "recorded_at": datetime.fromisoformat(cached["recorded_at"])}
    if rider.current_location is None or rider.last_location_at is None:
        return None
    return {
        "lat": rider.current_location.y,
        "lng": rider.current_location.x,
        "accuracy": None,
        "recorded_at": rider.last_location_at,
    }


# --------------------------------------------------------------------------- online / offline


def start_shift(user, *, lat: float, lng: float, accuracy: float | None = None):
    """`POST /rider/shift/start/`. Returns `(rider, shift)`."""
    from apps.delivery.services.kyc import online_blockers
    from apps.delivery.services.riders import missing_documents

    now = timezone.now()
    with transaction.atomic():
        rider = require_rider(user, lock=True, active=True)
        if rider.is_online:
            shift = open_shift(rider)
            if shift is not None:
                return rider, shift
        if "DOCUMENTS_NOT_APPROVED" in online_blockers(rider):
            pending = sorted(
                set(missing_documents(rider))
                | set(
                    rider.documents.filter(doc_type__in=rider.required_documents)
                    .exclude(status="APPROVED")
                    .values_list("doc_type", flat=True)
                )
            )
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                MSG_DOCUMENTS,
                details={"reason": "DOCUMENTS_NOT_APPROVED", "doc_types": pending},
            )
        store = rider.home_store
        radius = settings.RIDER_SHIFT_START_RADIUS_M
        distance = distance_m(lat, lng, store.location.y, store.location.x)
        if distance > radius:
            raise ApiError(
                ErrorCode.OUTSIDE_GEOFENCE,
                MSG_TOO_FAR,
                details={
                    "reason": "TOO_FAR_FROM_STORE",
                    "distance_m": distance,
                    "radius_m": radius,
                },
            )
        point = Point(lng, lat, srid=4326)
        shift = RiderShift.objects.create(rider=rider, started_at=now, start_location=point)
        Rider.objects.filter(pk=rider.pk).update(
            is_online=True,
            current_location=point,
            last_location_at=now,
            last_location_received_at=now,
            updated_at=now,
        )
        rider.is_online = True
        rider.current_location = point
        rider.last_location_at = now
        from apps.delivery import hooks

        hooks.rider_presence(rider.pk)  # T-612: `rider.status` to ops
    _remember_location(rider.pk, lat, lng, now, accuracy)
    logger.info("Rider %s online (shift %s)", rider.pk, shift.pk)
    return rider, shift


def _close(rider: Rider, shift: RiderShift | None, reason: str, now, by=None) -> RiderShift | None:
    if shift is not None and shift.ended_at is None:
        shift.ended_at = max(now, shift.started_at)
        shift.end_reason = reason
        shift.ended_by = by
        shift.save(update_fields=["ended_at", "end_reason", "ended_by"])
    Rider.objects.filter(pk=rider.pk).update(is_online=False, updated_at=now)
    rider.is_online = False
    from apps.delivery import hooks

    hooks.rider_presence(rider.pk)  # T-612: `rider.status` to ops
    return shift


def end_open_shift(rider: Rider, *, reason: str, by=None, now=None) -> RiderShift | None:
    """Close the rider's open shift (if any) and set them offline. The caller holds the lock.
    After commit, the rider's pending offers are withdrawn (in the dispatch lock order) and
    their orders offered to someone else."""
    rider_id = rider.pk

    def withdraw() -> None:
        from apps.delivery.services.dispatch import withdraw_rider_offers

        withdraw_rider_offers(rider_id)

    transaction.on_commit(withdraw)
    return _close(rider, open_shift(rider), reason, now or timezone.now(), by)


def end_shift(user):
    """`POST /rider/shift/end/`. Returns `(rider, shift)`; idempotent when already offline."""
    now = timezone.now()
    with transaction.atomic():
        rider = require_rider(user, lock=True)
        if not rider.is_online:
            return rider, last_shift(rider)
        if has_active_task(rider):
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                MSG_ACTIVE_TASK,
                details={"reason": "ACTIVE_TASK"},
            )
        shift = end_open_shift(rider, reason=ShiftEndReason.MANUAL, now=now)
    logger.info("Rider %s offline (manual)", rider.pk)
    return rider, shift


def force_offline(rider_id: int, *, by, ip: str | None = None) -> Rider:
    """Ops "force a rider offline" (05 §1.4): DL-61 (a) Super Admin, Ops, Store Manager for
    riders of their own stores (`delivery.dispatch_order`); refused during a task. Audited."""
    from apps.delivery.services import kyc

    with transaction.atomic():
        rider = kyc._locked(by, rider_id, kyc.OPS_DELIVERY)
        if not rider.is_online:
            return rider
        if has_active_task(rider):
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                "The rider is on a delivery. Reassign it first.",
                details={"reason": "ACTIVE_TASK"},
            )
        end_open_shift(rider, reason=ShiftEndReason.ADMIN, by=by)
        _record(ip, by, "rider.force_offline", rider, {})
    return rider


# --------------------------------------------------------------------------- location


def ingest_locations(user, points: list[dict], now=None) -> dict:
    """`POST /rider/locations/`. Returns `{accepted, duplicates, rejected}`."""
    now = now or timezone.now()
    rider = require_rider(user, active=True)
    # Unlocked read on purpose: ingestion is frequent and must not queue behind shift changes.
    # A batch racing an auto-offline may still be stored (harmless history); the rider's position
    # is only moved by the conditional update below.
    if not rider.is_online:
        raise ApiError(ErrorCode.RIDER_OFFLINE, MSG_OFFLINE)
    oldest = now - timedelta(hours=settings.RIDER_LOCATION_MAX_AGE_HOURS)
    newest_allowed = now + timedelta(seconds=settings.RIDER_LOCATION_MAX_FUTURE_SECONDS)
    valid: dict = {}
    rejected = 0
    duplicates = 0
    for point in points:
        recorded_at = point["recorded_at"]
        if recorded_at < oldest or recorded_at > newest_allowed:
            rejected += 1
        elif recorded_at in valid:
            duplicates += 1
        else:
            valid[recorded_at] = point
    if valid:
        known = set(
            RiderLocation.objects.filter(rider=rider, recorded_at__in=list(valid)).values_list(
                "recorded_at", flat=True
            )
        )
        duplicates += len(known)
        fresh = [p for t, p in sorted(valid.items()) if t not in known]
    else:
        fresh = []
    shift = open_shift(rider)
    from apps.delivery.services.tasks import active_task

    task = active_task(rider)
    RiderLocation.objects.bulk_create(
        [
            RiderLocation(
                rider=rider,
                point=Point(p["lng"], p["lat"], srid=4326),
                accuracy_m=p["accuracy"],
                speed=p.get("speed"),
                heading=p.get("heading"),
                recorded_at=p["recorded_at"],
                is_mocked=p.get("is_mocked", False),
                shift=shift,
                task=task,
            )
            for p in fresh
        ],
        ignore_conflicts=True,  # a concurrent resend of the same batch
    )
    if fresh:
        # Presence (auto-offline) uses the server's receipt time, never the device clock.
        Rider.objects.filter(pk=rider.pk).update(last_location_received_at=now)
        latest = fresh[-1]
        # The device clock may run ahead (points up to 2 min in the future are accepted):
        # never record a position time later than the server's now.
        latest_at = min(latest["recorded_at"], now)
        updated = Rider.objects.filter(
            Q(last_location_at__isnull=True) | Q(last_location_at__lt=latest_at),
            pk=rider.pk,
        ).update(
            current_location=Point(latest["lng"], latest["lat"], srid=4326),
            last_location_at=latest_at,
        )
        if updated:
            from apps.delivery import hooks

            transaction.on_commit(
                lambda: hooks.publish_rider_location(
                    rider.pk, latest["lat"], latest["lng"], latest_at
                )
            )
            _remember_location(
                rider.pk,
                latest["lat"],
                latest["lng"],
                latest_at,
                latest["accuracy"],
            )
        if any(p.get("is_mocked") for p in fresh):
            _mocked_location_alert(rider.pk, task.pk if task else None)
    return {"accepted": len(fresh), "duplicates": duplicates, "rejected": rejected}


MOCKED_ALERT_SECONDS = 30 * 60


def _mocked_location_alert(rider_id: int, task_id: int | None) -> None:
    """Mock locations are flagged to ops (at most once per rider per 30 minutes) and stored
    with `is_mocked`; nothing is blocked yet (policy to be decided with Jivo)."""
    from apps.delivery import hooks

    try:
        first = cache.add(f"delivery:mocked-alert:{rider_id}", "1", MOCKED_ALERT_SECONDS)
    except Exception:
        first = True
    if first:
        hooks.ops_alert("MOCKED_LOCATION", {"rider_id": rider_id, "task_id": task_id})


def heartbeat(user, now=None) -> tuple[Rider, int | None, int | None]:
    """`POST /rider/heartbeat/`: records that the app is alive (ops "last seen") and returns
    the rider with the pending offer and active task ids. It
    keeps an online rider online only while a location point arrived in the last 30 minutes
    (`stale_riders_filter`)."""
    now = now or timezone.now()
    rider = require_rider(user)
    Rider.objects.filter(pk=rider.pk).update(last_heartbeat_at=now)
    rider.last_heartbeat_at = now
    from apps.delivery.services.dispatch import current_offer
    from apps.delivery.services.tasks import active_task

    offer = current_offer(rider, now)
    task = active_task(rider)
    return rider, offer.pk if offer else None, task.pk if task else None


# --------------------------------------------------------------------------- auto-offline


def stale_riders_filter(now) -> Q:
    """Online riders to set offline (04 §2.3, api-requests #42, PM default ⚠): no
    location point for `RIDER_AUTO_OFFLINE_MINUTES`, unless a heartbeat came within that
    window **and** the last point is at most
    `RIDER_HEARTBEAT_PRESENCE_MAX_LOCATION_AGE_MINUTES` old: a rider waiting indoors without
    a GPS fix stays online, but not for ever."""
    cutoff = now - timedelta(minutes=settings.RIDER_AUTO_OFFLINE_MINUTES)
    presence = now - timedelta(minutes=settings.RIDER_HEARTBEAT_PRESENCE_MAX_LOCATION_AGE_MINUTES)
    # Server receipt times only (a phone clock running behind or ahead cannot keep a rider
    # online or knock them offline).
    no_recent_location = Q(last_location_received_at__isnull=True) | Q(
        last_location_received_at__lt=cutoff
    )
    heartbeat_presence = Q(last_heartbeat_at__gte=cutoff, last_location_received_at__gte=presence)
    return no_recent_location & ~heartbeat_presence


ON_TASK_WARNING_SECONDS = 30 * 60


def _warn_on_task_once(rider_id: int) -> None:
    """A rider on a task with no location: one warning per rider per 30 minutes (the beat job
    runs every 2 minutes), as an ops alert."""
    from apps.delivery import hooks

    try:
        first = cache.add(f"delivery:on-task-stale:{rider_id}", "1", ON_TASK_WARNING_SECONDS)
    except Exception:
        first = True
    if first:
        logger.warning("Rider %s is on a task but sent no location for 10 minutes", rider_id)
        hooks.ops_alert("RIDER_STALE_ON_TASK", {"rider_id": rider_id})


def auto_offline_stale(now=None) -> dict:
    """06 §5 `rider_heartbeat_check`. Idempotent; skips rows locked by another worker."""
    now = now or timezone.now()
    cutoff = now - timedelta(minutes=settings.RIDER_AUTO_OFFLINE_MINUTES)
    stale_filter = stale_riders_filter(now)
    stale = Rider.objects.filter(is_online=True).filter(stale_filter)
    result = {"offline": 0, "on_task": 0}
    for rider_id in stale.values_list("pk", flat=True)[:500]:
        with transaction.atomic():
            rider = (
                Rider.objects.select_for_update(skip_locked=True)
                .filter(pk=rider_id, is_online=True)
                .filter(stale_filter)
                .first()
            )
            if rider is None:
                continue
            if has_active_task(rider):
                _warn_on_task_once(rider.pk)
                result["on_task"] += 1
                continue
            end_open_shift(rider, reason=ShiftEndReason.AUTO_OFFLINE, now=now)
            result["offline"] += 1
            logger.info("Rider %s auto-offline (no location since %s)", rider.pk, cutoff)
            # 04 §2.3 "notifies them": push via the FCM sender (slice 5.3); the app also learns
            # it from 409 RIDER_OFFLINE and `heartbeat`.
    return result
