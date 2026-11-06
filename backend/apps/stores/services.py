"""Stores: lookup, opening status, serviceability (PostGIS), notify-me and staff store scoping.

- `store_status()`: `is_open` = active, accepting orders and inside a `StoreTiming` window (store
  local time, settings.STORE_TIME_ZONE); `opens_at` = next window start in UTC (null when open,
  when paused, or without timings).
- `check_serviceability()`: active stores whose `service_area` contains the point, choosing open
  stores first, then the nearest, then the lowest `priority` (07 §2.2). ETA per 08 §8. Runs on a
  cached snapshot of the store areas (GEOS in-process, no database on the hot path).
- `serviceable_exists()` / `address_point_expression()`: PostGIS `EXISTS` for address lists.
- `stores_for(user)`: the stores a staff user may see (05 §3).
- `set_accepting_orders()`: pause / resume orders at a store (panel), actor recorded.
"""

import logging
import math
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import NamedTuple
from zoneinfo import ZoneInfo

from django.conf import settings
from django.contrib.gis.db.models import PointField
from django.contrib.gis.geos import GEOSGeometry, Point
from django.core.cache import cache
from django.db import transaction
from django.db.models import Exists, F, FloatField, Func, OuterRef, QuerySet, Value
from django.db.models.functions import Cast, Coalesce
from django.utils import timezone

from apps.accounts import roles
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.stores.models import DarkStore, ServiceabilityRequest, StoreTiming

logger = logging.getLogger(__name__)

END_OF_DAY = time(23, 59)  # a window closing at 23:59 runs to midnight (see StoreTiming)
NOTIFY_ME_DEDUPE_HOURS = 24
NOTIFY_ME_DEDUPE_METRES = 100

MSG_NOT_SERVICEABLE = "We're not in your area yet. Tap Notify me and we'll tell you when we arrive."
MSG_PAUSED = "The store is not taking orders right now. Please check back soon."


def store_point(lat: float, lng: float) -> Point:
    return Point(float(lng), float(lat), srid=4326)


# --------------------------------------------------------------------------- lookup & status


def active_store(store_id: int) -> "StoreArea":
    """The active store for `X-Store-Id` from the cached snapshot (no database query when warm);
    404 `STORE_NOT_FOUND` for an unknown or deactivated store."""
    for area in store_areas():
        if area.pk == store_id:
            return area
    raise ApiError(ErrorCode.STORE_NOT_FOUND, details={"store_id": store_id})


@dataclass(frozen=True, slots=True)
class StoreStatus:
    id: int
    name: str
    is_open: bool
    opens_at: datetime | None

    def as_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "is_open": self.is_open,
            "opens_at": self.opens_at,
        }


def _local_now(now: datetime | None) -> datetime:
    return (now or timezone.now()).astimezone(ZoneInfo(settings.STORE_TIME_ZONE))


def _within(window: StoreTiming, moment: time) -> bool:
    end = time.max if window.closes_at == END_OF_DAY else window.closes_at
    return window.opens_at <= moment < end


def _timings(store) -> list:
    if isinstance(store, StoreArea):
        return list(store.windows)
    # Uses the timings prefetch when present, else one query.
    return sorted(store.timings.all(), key=lambda t: (t.weekday, t.opens_at))


def _next_opening(windows: list[StoreTiming], local_now: datetime) -> datetime | None:
    tz = local_now.tzinfo
    today: date = local_now.date()
    for offset in range(8):
        day = today + timedelta(days=offset)
        for window in windows:
            if window.weekday != day.weekday():
                continue
            start = datetime.combine(day, window.opens_at, tzinfo=tz)
            if start > local_now:
                return start.astimezone(ZoneInfo("UTC"))
    return None


def store_status(store: DarkStore, now: datetime | None = None) -> StoreStatus:
    local_now = _local_now(now)
    windows = _timings(store)
    if not store.is_active or not store.is_accepting_orders:
        return StoreStatus(store.pk, store.name, False, None)
    current = local_now.time()
    is_open = any(w.weekday == local_now.weekday() and _within(w, current) for w in windows)
    opens_at = None if is_open else _next_opening(windows, local_now)
    return StoreStatus(store.pk, store.name, is_open, opens_at)


def _format_opening(opens_at: datetime, now: datetime | None) -> str:
    local = opens_at.astimezone(ZoneInfo(settings.STORE_TIME_ZONE))
    hour = local.hour % 12 or 12
    clock = f"{hour}:{local.minute:02d} {'AM' if local.hour < 12 else 'PM'}"
    days = (local.date() - _local_now(now).date()).days
    if days == 0:
        return f"It opens at {clock}."
    if days == 1:
        return f"It opens tomorrow at {clock}."
    return f"It opens on {local:%A} at {clock}."


def status_message(status: StoreStatus, now: datetime | None = None) -> str | None:
    if status.is_open:
        return None
    if status.opens_at is None:
        return MSG_PAUSED
    return f"The store is closed now. {_format_opening(status.opens_at, now)}"


# --------------------------------------------------------------------------- serviceability


def eta_minutes(store: DarkStore, distance_km: float) -> int:
    """08 §8 with the typical rider wait: prep + wait + road distance / speed + buffer."""
    travel = distance_km * settings.ETA_ROAD_FACTOR / settings.ETA_AVG_SPEED_KMPH * 60
    total = (
        store.avg_prep_minutes
        + settings.ETA_RIDER_WAIT_MINUTES
        + travel
        + settings.ETA_BUFFER_MINUTES
    )
    return max(1, math.ceil(total))


# The serviceability hot path never touches the database: active stores (area, location, hours)
# are cached as a snapshot keyed by a version that store/timing changes bump (immediately and
# again after commit). Point-in-polygon runs in-process with GEOS, the engine PostGIS uses. A
# cache miss (or Redis outage) loads the snapshot from PostGIS (2 queries).
STORES_VERSION_KEY = "stores:areas:version"
SNAPSHOT_KEY = "stores:areas:{version}"
EARTH_RADIUS_KM = 6371.0088


class Window(NamedTuple):
    weekday: int
    opens_at: time
    closes_at: time


@dataclass(frozen=True, slots=True)
class StoreArea:
    """What serviceability needs about one active store (duck-types `store_status()`)."""

    pk: int
    name: str
    is_accepting_orders: bool
    avg_prep_minutes: int
    priority: int
    lat: float
    lng: float
    area: object  # GEOS PreparedGeometry
    windows: tuple[Window, ...]
    is_active: bool = True


def bump_stores_version(**kwargs) -> None:
    """Signal receiver (DarkStore, StoreTiming): drop the cached snapshot now and after commit."""
    _bump_areas()
    transaction.on_commit(_bump_areas)


def _bump_areas() -> None:
    try:
        cache.add(STORES_VERSION_KEY, 1, timeout=None)
        cache.incr(STORES_VERSION_KEY)
    except Exception:
        logger.warning("could not bump %s", STORES_VERSION_KEY, exc_info=True)


def _load_snapshot() -> list[dict]:
    stores = DarkStore.objects.filter(is_active=True).prefetch_related("timings")
    return [
        {
            "pk": store.pk,
            "name": store.name,
            "is_accepting_orders": store.is_accepting_orders,
            "avg_prep_minutes": store.avg_prep_minutes,
            "priority": store.priority,
            "lat": store.location.y,
            "lng": store.location.x,
            "area_wkb": bytes(store.service_area.wkb),
            "windows": [(t.weekday, t.opens_at, t.closes_at) for t in store.timings.all()],
        }
        for store in stores
    ]


def _snapshot() -> list[dict]:
    try:
        version = cache.get(STORES_VERSION_KEY)
        if version is None:
            cache.add(STORES_VERSION_KEY, 1, timeout=None)
            version = cache.get(STORES_VERSION_KEY) or 1
        key = SNAPSHOT_KEY.format(version=version)
        data = cache.get(key)
    except Exception:
        logger.warning("store snapshot cache unavailable; reading PostGIS", exc_info=True)
        return _load_snapshot()
    if data is None:
        data = _load_snapshot()
        try:
            cache.set(key, data, timeout=settings.CATALOG_CACHE_SECONDS)
        except Exception:
            logger.warning("store snapshot cache write failed", exc_info=True)
    return data


def store_areas() -> list[StoreArea]:
    return [
        StoreArea(
            pk=row["pk"],
            name=row["name"],
            is_accepting_orders=row["is_accepting_orders"],
            avg_prep_minutes=row["avg_prep_minutes"],
            priority=row["priority"],
            lat=row["lat"],
            lng=row["lng"],
            area=GEOSGeometry(memoryview(row["area_wkb"]), srid=4326).prepared,
            windows=tuple(Window(*w) for w in sorted(row["windows"], key=lambda w: (w[0], w[1]))),
        )
        for row in _snapshot()
    ]


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def check_serviceability(lat: float, lng: float, now: datetime | None = None) -> dict:
    """`GET /serviceability/` body: `{serviceable, store, eta_minutes, message}` (DL-27).
    Active stores whose area contains the point; open first, then nearest, then priority."""
    point = store_point(lat, lng)
    candidates = [area for area in store_areas() if area.area.contains(point)]
    if not candidates:
        return {
            "serviceable": False,
            "store": None,
            "eta_minutes": None,
            "message": MSG_NOT_SERVICEABLE,
        }
    ranked = sorted(
        (
            (store_status(area, now), haversine_km(lat, lng, area.lat, area.lng), area)
            for area in candidates
        ),
        key=lambda item: (not item[0].is_open, item[1], item[2].priority, item[2].pk),
    )
    status, distance_km, area = ranked[0]
    return {
        "serviceable": True,
        "store": status.as_dict(),
        "eta_minutes": eta_minutes(area, distance_km) if status.is_open else None,
        "message": status_message(status, now),
    }


def _decimal_point(lat_field: str, lng_field: str) -> Func:
    point = Func(
        Cast(F(lng_field), FloatField()),
        Cast(F(lat_field), FloatField()),
        function="ST_MakePoint",
    )
    return Func(point, Value(4326), function="ST_SetSRID", output_field=PointField(srid=4326))


def address_point_expression() -> Coalesce:
    """`Address.location`, or a point from its `lat`/`lng` decimals when not set yet (rows
    written by pre-Phase-2 code). Removed with the decimal columns."""
    return Coalesce(F("location"), _decimal_point("lat", "lng"), output_field=PointField(srid=4326))


def serviceable_exists(point_ref: str = "address_point") -> Exists:
    """`Exists` subquery for annotations: an active store's area contains `OuterRef(point_ref)`."""
    return Exists(
        DarkStore.objects.filter(is_active=True, service_area__contains=OuterRef(point_ref))
    )


def is_point_serviceable(lat, lng) -> bool:
    point = store_point(lat, lng)
    return any(area.area.contains(point) for area in store_areas())


# --------------------------------------------------------------------------- store operations

LOG_PAUSED = "Stopped accepting orders (temporarily closed)."
LOG_RESUMED = "Accepting orders again."


def set_accepting_orders(store: DarkStore, accepting: bool, *, actor) -> bool:
    """Pause or resume orders at a store (`is_accepting_orders`: customers can still browse,
    not check out). For the panel's store screens. Atomic, with the store row locked; returns
    whether anything changed. The actor is recorded as an admin `LogEntry` on the store (like
    the customer moderation services, until the audit log of P4-P8). The store snapshot
    (serviceability, `X-Store-Id`) is refreshed by the DarkStore save signal, and the store's
    catalog cache is invalidated after commit."""
    from django.contrib.admin.models import CHANGE, LogEntry
    from django.contrib.contenttypes.models import ContentType

    from apps.catalog.cache import invalidate_store_on_commit

    if actor is None or actor.pk is None:
        raise ValueError("set_accepting_orders needs the acting staff user (`actor`).")
    accepting = bool(accepting)
    with transaction.atomic():
        locked = DarkStore.objects.select_for_update().get(pk=store.pk)
        if locked.is_accepting_orders == accepting:
            store.is_accepting_orders = accepting
            return False
        locked.is_accepting_orders = accepting
        locked.save(update_fields=["is_accepting_orders", "updated_at"])
        LogEntry.objects.create(
            user_id=actor.pk,
            content_type=ContentType.objects.get_for_model(DarkStore),
            object_id=str(locked.pk),
            object_repr=str(locked)[:200],
            action_flag=CHANGE,
            change_message=LOG_RESUMED if accepting else LOG_PAUSED,
        )
        invalidate_store_on_commit(locked.pk)
    store.is_accepting_orders = accepting
    return True


# --------------------------------------------------------------------------- notify-me


def record_notify_me(
    *, lat: float, lng: float, phone: str | None, address_text: str, user=None
) -> ServiceabilityRequest:
    """Save a notify-me lead. A signed-in user's repeat within 24 h and 100 m gets their own
    lead back, so repeated taps do not multiply leads.

    An anonymous request is never merged (BUG-0008 and its R2b review): it always gets a lead of
    its own, so its response (`id`, `created_at`) can never reveal that someone else submitted
    the same phone and address before. Anonymous repeats are bounded by the notify-me throttle
    (`NOTIFY_ME_RATE`); expansion reports count distinct phones."""
    point = store_point(lat, lng)
    address_text = address_text.strip()
    if user is not None and not phone:
        phone = user.phone or None
    since = timezone.now() - timedelta(hours=NOTIFY_ME_DEDUPE_HOURS)
    recent = ServiceabilityRequest.objects.filter(created_at__gte=since).filter(
        location__dwithin=(point, NOTIFY_ME_DEDUPE_METRES / 111_320)  # degrees, approx.
    )
    if user is not None:
        existing = recent.filter(user=user).first()
        if existing is not None:
            return existing
    return ServiceabilityRequest.objects.create(
        location=point, user=user, phone=phone, address_text=address_text
    )


def notify_me_body(
    lead: ServiceabilityRequest, *, lat: float, lng: float, phone: str | None, address_text: str
) -> dict:
    """The notify-me response. A signed-in caller sees their own lead; an anonymous caller gets
    the lead made for this very request (never merged, `record_notify_me`), echoing the values
    they sent (BUG-0008: no field of an earlier request)."""
    if lead.user_id is not None:
        return {
            "id": lead.pk,
            "lat": lead.location.y,
            "lng": lead.location.x,
            "phone": lead.phone,
            "address_text": lead.address_text,
            "created_at": lead.created_at,
        }
    return {
        "id": lead.pk,
        "lat": lat,
        "lng": lng,
        "phone": phone,
        "address_text": address_text.strip(),
        "created_at": lead.created_at,
    }


# --------------------------------------------------------------------------- staff scoping


def stores_for(user) -> QuerySet[DarkStore]:
    """Stores a staff user may see (05 §3). Fail closed:

    - every store: superusers, and staff in a global role (`roles.GLOBAL_ROLES`: Super Admin,
      Ops, Catalog Manager, Support, Finance) **and in no store-scoped role**;
    - only their `StaffStoreAccess` stores: anyone in a store-scoped role (Store Manager,
      Store Staff), even if they are also in a global or any other group (the stricter role
      wins, PM decision 2026-11-03);
    - none: everyone else (non-staff, inactive, no role, or only unknown groups). Unknown groups
      never widen access.
    """
    if not (user and user.is_authenticated and user.is_active and user.is_staff):
        return DarkStore.objects.none()
    if user.is_superuser:
        return DarkStore.objects.all()
    groups = set(user.groups.values_list("name", flat=True))
    if groups & roles.STORE_SCOPED_ROLES:
        return DarkStore.objects.filter(staff_access__user=user).distinct()
    if groups & roles.GLOBAL_ROLES:
        return DarkStore.objects.all()
    return DarkStore.objects.none()


def grant_store_access(user, store: DarkStore) -> None:
    from apps.stores.models import StaffStoreAccess

    StaffStoreAccess.objects.get_or_create(user=user, store=store)


def revoke_store_access(user, store: DarkStore) -> None:
    from apps.stores.models import StaffStoreAccess

    StaffStoreAccess.objects.filter(user=user, store=store).delete()
