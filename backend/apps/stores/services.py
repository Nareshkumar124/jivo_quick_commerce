"""Stores: lookup, opening status, serviceability (PostGIS), notify-me and staff store scoping.

- `store_status()`: `is_open` = active, accepting orders and inside a `StoreTiming` window (store
  local time, settings.STORE_TIME_ZONE); `opens_at` = next window start in UTC (null when open,
  when paused, or without timings).
- `check_serviceability()`: active stores whose `service_area` contains the point, choosing open
  stores first, then the nearest, then the lowest `priority` (07 §2.2). ETA per 08 §8. Runs on a
  cached snapshot of the store areas (GEOS in-process, no database on the hot path). A store
  with delivery pincodes (ADR 0004, pincode mode) covers its active pincodes' outlines + 250 m
  instead, and serves an address only when its pincode is active (`StoreArea.delivers_to`).
- `serviceable_exists()` / `address_point_expression()`: PostGIS `EXISTS` for address lists.
- `add_delivery_pincode()` / `update_delivery_pincode()` / `set_delivery_pincode_active()`:
  the admin's delivery locations (ADR 0004, Super Admin only, audited).
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
from django.contrib.postgres.aggregates import JSONBAgg
from django.core.cache import cache
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, connection, transaction
from django.db.models import Exists, F, FloatField, Func, OuterRef, Q, QuerySet, Value
from django.db.models.functions import Cast, Coalesce, JSONObject
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.validators import pincode_validator
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.stores.models import (
    DarkStore,
    DeliveryPincode,
    ServiceabilityRequest,
    StoreTiming,
)

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


# The serviceability hot path never touches the database: active stores (area, location, hours,
# delivery pincodes and their outlines) are cached as a snapshot keyed by a version that store,
# timing and pincode changes bump (immediately and again after commit). Point-in-polygon runs
# in-process with GEOS, the engine PostGIS uses. A cache miss (or Redis outage) loads the
# snapshot from PostGIS (2 queries, plus 1 when a store delivers by pincode).
STORES_VERSION_KEY = "stores:areas:version"
SNAPSHOT_KEY = "stores:areas:{version}"
EARTH_RADIUS_KM = 6371.0088

# ADR 0004 §1: delivery by pincode. A pincode outline is approximate, so the location check
# accepts points up to 250 m outside it; the address check (the address pincode) is exact.
PINCODE_BUFFER_METRES = 250
MAX_PLACES_IN_MESSAGE = 3
MSG_NOT_DELIVERED = "We don't deliver here yet. We'll come to your area soon."
MSG_NOT_DELIVERED_PLACES = (
    "We don't deliver here yet. We deliver in {places}. We'll come to your area soon."
)


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
    # ADR 0004 §1: the store has DeliveryPincode rows (active or not), so pincode rules apply.
    pincode_mode: bool = False
    pincodes: tuple[str, ...] = ()  # its active pincodes
    places: tuple[str, ...] = ()  # the active pincodes as the customer message names them
    outline: object = None  # GEOS PreparedGeometry: active pincodes' outlines + 250 m, or None

    def covers(self, point: Point) -> bool:
        """The location check (`GET /serviceability/`, before any address exists): in pincode
        mode, inside the buffered outline of an active pincode (none without outlines); else
        inside the service area."""
        if self.pincode_mode:
            return self.outline is not None and self.outline.contains(point)
        return self.area.contains(point)

    def delivers_to(self, lat, lng, pincode: str | None) -> bool:
        """The address check (`cart.services.serves()`, the exact rule): in pincode mode, the
        address pincode (stripped) is an active pincode of this store; else the address pin is
        inside the service area."""
        if self.pincode_mode:
            return (pincode or "").strip() in self.pincodes
        return self.area.contains(store_point(lat, lng))

    def not_delivered_message(self) -> str | None:
        """In pincode mode, the customer message for an address `delivers_to` refused (it names
        the active pincodes); None otherwise (the caller's own message)."""
        return not_delivered_message(self.places) if self.pincode_mode else None


def not_delivered_message(places) -> str:
    """ADR 0004 §1, the one place that words it: the customer message when a store in pincode
    mode does not deliver to an address or a location. Names at most 3 places, then "and
    more"."""
    places = list(places)
    if not places:
        return MSG_NOT_DELIVERED
    shown = ", ".join(places[:MAX_PLACES_IN_MESSAGE])
    if len(places) > MAX_PLACES_IN_MESSAGE:
        shown += " and more"
    return MSG_NOT_DELIVERED_PLACES.format(places=shown)


def place_label(pincode: str, area_name: str) -> str:
    """How the message names an active pincode: "Rajouri Garden (110027)", or "110027"."""
    return f"{area_name} ({pincode})" if area_name else pincode


def bump_stores_version(**kwargs) -> None:
    """Signal receiver (DarkStore, StoreTiming, DeliveryPincode, PincodeBoundary): drop the
    cached snapshot now and after commit."""
    _bump_areas()
    transaction.on_commit(_bump_areas)


def _bump_areas() -> None:
    try:
        cache.add(STORES_VERSION_KEY, 1, timeout=None)
        cache.incr(STORES_VERSION_KEY)
    except Exception:
        logger.warning("could not bump %s", STORES_VERSION_KEY, exc_info=True)


# Geography buffer = metres; quad_segs=4 keeps the rounded corners small in the snapshot.
PINCODE_OUTLINES_SQL = (
    "SELECT dp.store_id, ST_AsBinary(ST_Union("
    "ST_Buffer(pb.geom::geography, %s, 'quad_segs=4')::geometry)) "
    "FROM stores_deliverypincode dp JOIN stores_pincodeboundary pb ON pb.pincode = dp.pincode "
    "WHERE dp.is_active AND dp.store_id = ANY(%s) GROUP BY dp.store_id"
)


def _pincode_outlines(store_ids: list[int]) -> dict[int, bytes]:
    """Per store: the union of its active pincodes' outlines, each buffered 250 m (as
    geography, so in metres), as WKB. One query; a store whose active pincodes have no outline
    is missing (its location check then covers nothing)."""
    if not store_ids:
        return {}
    with connection.cursor() as cursor:
        cursor.execute(PINCODE_OUTLINES_SQL, [PINCODE_BUFFER_METRES, store_ids])
        return {store_id: bytes(wkb) for store_id, wkb in cursor.fetchall() if wkb}


def _load_snapshot() -> list[dict]:
    rows = JSONBAgg(
        JSONObject(
            pincode="delivery_pincodes__pincode",
            area_name="delivery_pincodes__area_name",
            is_active="delivery_pincodes__is_active",
        ),
        filter=Q(delivery_pincodes__isnull=False),
        order_by="delivery_pincodes__pincode",
    )
    stores = list(
        DarkStore.objects.filter(is_active=True)
        .annotate(pincode_rows=rows)
        .prefetch_related("timings")
    )
    active = {
        store.pk: [row for row in (store.pincode_rows or []) if row["is_active"]]
        for store in stores
    }
    outlines = _pincode_outlines([pk for pk, pins in active.items() if pins])
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
            "pincode_mode": bool(store.pincode_rows),
            "pincodes": [row["pincode"] for row in active[store.pk]],
            "places": [place_label(row["pincode"], row["area_name"]) for row in active[store.pk]],
            "outline_wkb": outlines.get(store.pk),
        }
        for store in stores
    ]


def _prepared(wkb: bytes | None):
    return GEOSGeometry(memoryview(wkb), srid=4326).prepared if wkb else None


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
            # .get(): a snapshot cached by the release before ADR 0004 has no pincode keys
            pincode_mode=row.get("pincode_mode", False),
            pincodes=tuple(row.get("pincodes", ())),
            places=tuple(row.get("places", ())),
            outline=_prepared(row.get("outline_wkb")),
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
    Active stores that cover the point (`StoreArea.covers`: the service area, or in pincode mode
    the active pincodes' outlines, ADR 0004); open first, then nearest, then priority."""
    point = store_point(lat, lng)
    areas = store_areas()
    candidates = [area for area in areas if area.covers(point)]
    if not candidates:
        return {
            "serviceable": False,
            "store": None,
            "eta_minutes": None,
            "message": _location_message(areas),
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


def _location_message(areas: list[StoreArea]) -> str:
    """Not served at this location: with stores in pincode mode, name their active pincodes
    (ADR 0004 §1); else the notify-me message."""
    places = []
    for area in sorted(areas, key=lambda a: (a.priority, a.pk)):
        if area.pincode_mode:
            places.extend(place for place in area.places if place not in places)
    if any(area.pincode_mode for area in areas):
        return not_delivered_message(places)
    return MSG_NOT_SERVICEABLE


def serviceable_exists(point_ref: str = "address_point", pincode_ref: str = "pincode") -> Exists:
    """`Exists` subquery for address annotations, the address rule of `StoreArea.delivers_to`
    in SQL: an active store has the address pincode `OuterRef(pincode_ref)` as an active
    delivery pincode, or has no delivery pincodes and its area contains `OuterRef(point_ref)`."""
    pincode_mode = Exists(DeliveryPincode.objects.filter(store=OuterRef("pk")))
    active_pincode = Exists(
        DeliveryPincode.objects.filter(
            store=OuterRef("pk"), is_active=True, pincode=OuterRef(OuterRef(pincode_ref))
        )
    )
    return Exists(
        DarkStore.objects.filter(is_active=True).filter(
            Q(active_pincode) | (~Q(pincode_mode) & Q(service_area__contains=OuterRef(point_ref)))
        )
    )


def is_point_serviceable(lat, lng) -> bool:
    """The location check: some active store covers the point."""
    point = store_point(lat, lng)
    return any(area.covers(point) for area in store_areas())


def is_address_serviceable(lat, lng, pincode: str | None) -> bool:
    """The address check (the address list's flag for a new or moved address): some active
    store delivers to it (`StoreArea.delivers_to`)."""
    return any(area.delivers_to(lat, lng, pincode) for area in store_areas())


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
    if sees_all_stores(user):
        return DarkStore.objects.all()
    groups = set(user.groups.values_list("name", flat=True))
    if groups & roles.STORE_SCOPED_ROLES:
        return DarkStore.objects.filter(staff_access__user=user).distinct()
    return DarkStore.objects.none()


def sees_all_stores(user) -> bool:
    """True when `stores_for(user)` is every store (a superuser, or a global role and no
    store-scoped role). Lets callers include rows that belong to no store yet (e.g. a rider
    with neither a home nor a preferred store), which a store filter would hide."""
    if not (user and user.is_authenticated and user.is_active and user.is_staff):
        return False
    if user.is_superuser:
        return True
    groups = set(user.groups.values_list("name", flat=True))
    return not (groups & roles.STORE_SCOPED_ROLES) and bool(groups & roles.GLOBAL_ROLES)


def grant_store_access(user, store: DarkStore) -> None:
    from apps.stores.models import StaffStoreAccess

    StaffStoreAccess.objects.get_or_create(user=user, store=store)


def revoke_store_access(user, store: DarkStore) -> None:
    from apps.stores.models import StaffStoreAccess

    StaffStoreAccess.objects.filter(user=user, store=store).delete()


# --------------------------------------------------------------------------- delivery pincodes
# ADR 0004 §1: the admin's "Delivery locations" page calls only these. Super Admin only
# (`stores.manage_delivery_pincodes`); each change is audited. The DeliveryPincode save signal
# refreshes the serviceability snapshot, so a change applies to the next request.

MANAGE_DELIVERY_PINCODES = "stores.manage_delivery_pincodes"
MSG_PINCODE_NO_PERMISSION = "Only a Super Admin can change delivery pincodes."
MSG_PINCODE_FORMAT = "Enter a 6-digit pincode, e.g. 110027."
MSG_PINCODE_TAKEN = "This store already delivers to this pincode."
MSG_PINCODE_STORE = "Choose a store."


def can_manage_delivery_pincodes(user) -> bool:
    return bool(
        user and user.is_active and user.is_staff and user.has_perm(MANAGE_DELIVERY_PINCODES)
    )


def _require_pincode_manager(actor) -> None:
    if not can_manage_delivery_pincodes(actor):
        raise PermissionDenied(MSG_PINCODE_NO_PERMISSION)


def _clean_pincode(value) -> str:
    pincode = str(value or "").strip()
    try:
        pincode_validator(pincode)
    except ValidationError:
        raise ValidationError({"pincode": MSG_PINCODE_FORMAT}) from None
    return pincode


def _clean_area_name(value) -> str:
    name = " ".join(str(value or "").split())
    limit = DeliveryPincode._meta.get_field("area_name").max_length
    if len(name) > limit:
        raise ValidationError({"area_name": f"Use at most {limit} characters."})
    return name


def _save_pincode(row: DeliveryPincode, fields: list[str] | None = None) -> None:
    """Save, turning a raced duplicate (unique store + pincode) into a field error."""
    try:
        with transaction.atomic():
            row.save(update_fields=fields)
    except IntegrityError as error:
        if "deliverypincode_unique" in str(error):
            raise ValidationError({"pincode": MSG_PINCODE_TAKEN}) from error
        raise


def add_delivery_pincode(
    store, pincode, *, area_name: str = "", is_active: bool = True, actor
) -> DeliveryPincode:
    """Add a pincode the store delivers to. The store's first row switches it to pincode mode
    (ADR 0004 §1). `store` is a DarkStore or its id. Raises `ValidationError` per field
    (`store`, `pincode`, `area_name`) and `PermissionDenied`; saves nothing then."""
    _require_pincode_manager(actor)
    store_id = getattr(store, "pk", store)
    pincode = _clean_pincode(pincode)
    area_name = _clean_area_name(area_name)
    with transaction.atomic():
        found = DarkStore.objects.filter(pk=store_id).first() if store_id else None
        if found is None:
            raise ValidationError({"store": MSG_PINCODE_STORE})
        if DeliveryPincode.objects.filter(store=found, pincode=pincode).exists():
            raise ValidationError({"pincode": MSG_PINCODE_TAKEN})
        row = DeliveryPincode(
            store=found, pincode=pincode, area_name=area_name, is_active=bool(is_active)
        )
        _save_pincode(row)
        audit.record(
            actor,
            "delivery_pincode.add",
            row,
            {
                "store_id": found.pk,
                "pincode": pincode,
                "is_active": row.is_active,
                "area_name_set": bool(area_name),
            },
        )
    return row


def update_delivery_pincode(row: DeliveryPincode, *, actor, pincode=None, area_name=None) -> bool:
    """Edit a delivery pincode's number and/or area name (None = keep). Returns whether
    anything changed. Same errors as `add_delivery_pincode`."""
    _require_pincode_manager(actor)
    new_pincode = None if pincode is None else _clean_pincode(pincode)
    new_name = None if area_name is None else _clean_area_name(area_name)
    with transaction.atomic():
        locked = DeliveryPincode.objects.select_for_update().get(pk=row.pk)
        changes, fields = {}, []
        if new_pincode is not None and new_pincode != locked.pincode:
            taken = DeliveryPincode.objects.filter(store_id=locked.store_id, pincode=new_pincode)
            if taken.exclude(pk=locked.pk).exists():
                raise ValidationError({"pincode": MSG_PINCODE_TAKEN})
            changes["pincode"] = [locked.pincode, new_pincode]
            locked.pincode = new_pincode
            fields.append("pincode")
        if new_name is not None and new_name != locked.area_name:
            changes["area_name_changed"] = True  # free text stays out of the audit log
            locked.area_name = new_name
            fields.append("area_name")
        if not fields:
            return False
        _save_pincode(locked, [*fields, "updated_at"])
        audit.record(
            actor, "delivery_pincode.update", locked, {"store_id": locked.store_id, **changes}
        )
    row.pincode, row.area_name = locked.pincode, locked.area_name
    return True


def set_delivery_pincode_active(row: DeliveryPincode, active: bool, *, actor) -> bool:
    """Switch a delivery pincode on or off (an inactive one is kept, but not delivered to; the
    store stays in pincode mode). Returns whether anything changed."""
    _require_pincode_manager(actor)
    active = bool(active)
    with transaction.atomic():
        locked = DeliveryPincode.objects.select_for_update().get(pk=row.pk)
        if locked.is_active == active:
            row.is_active = active
            return False
        locked.is_active = active
        locked.save(update_fields=["is_active", "updated_at"])
        audit.record(
            actor,
            "delivery_pincode.activate" if active else "delivery_pincode.deactivate",
            locked,
            {"store_id": locked.store_id, "pincode": locked.pincode, "is_active": active},
        )
    row.is_active = active
    return True
