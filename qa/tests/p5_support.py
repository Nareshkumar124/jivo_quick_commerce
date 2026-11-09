"""Phase 5 helpers (riders and delivery), QA stage 1 scaffold, 2026-11-05.

Design: `qa/docs/01-test-plan.md` §9 and the P5 cases in `02-test-case-repository.md`.

- Every P5 order is placed at the QA-only store QA-02 (id 2, Jaipur, auto-accept on) by QA
  customers, and the QA riders (users C and D) have QA-02 as home store, so dispatch never mixes
  QA riders or orders with the user's GGN-01 data.
- Positions are client-reported, so geofence and ranking cases send computed offsets from the
  QA-02 pin (`offset`).
- Staff/system actions run through `qa/tools/rider_ops_driver.py` (rider review, dispatch,
  returns) and `qa/tools/store_ops_driver.py` (packing) until the 5.4 Ops Console pages exist.
- Slice 5.3 cases are gated by `requires_53`: they run only when commit fd1490c is an ancestor
  of the commit under test **and** the shared DB has `delivery_deliveryoffer` (migration
  `delivery.0002`, applied by the PM). `QA_P5_53=1` forces them.
"""

from __future__ import annotations

import json
import math
import os
import struct
import subprocess
import time
import zlib
from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal

import httpx
import pytest

from conftest import login
from p3_support import V_FLAX, V_SUN_1L, Shop
from p4_support import _ENV, BACKEND, OPS, SUPER
from p4_support import ops as store_ops
from qa_support import (
    APP_HEADERS,
    QA_DIR,
    QA_PHONES,
    REPO,
    RIDER_HEADERS,
    bearer,
    db_query,
    describe,
    instance_commit,
)

# --------------------------------------------------------------------------- gate for slice 5.3

P5_53_COMMIT = "fd1490c"  # backend/phase-5: P5 slice 5.3 (T-514a)


def slice_53_ready() -> tuple[bool, str]:
    if os.environ.get("QA_P5_53") == "1":
        return True, "forced by QA_P5_53=1"
    try:
        commit = instance_commit()
        ancestor = subprocess.run(
            ["git", "-C", str(REPO), "merge-base", "--is-ancestor", P5_53_COMMIT, commit],
            capture_output=True,
        ).returncode == 0
    except (OSError, subprocess.CalledProcessError):
        ancestor = False
    if not ancestor:
        return False, f"awaiting P5 slice 5.3 ({P5_53_COMMIT}) on develop"
    try:
        table = db_query("select to_regclass('public.delivery_deliveryoffer')")[0][0]
    except Exception as exc:  # DB unreachable: never run half a flow
        return False, f"cannot check delivery.0002 ({type(exc).__name__})"
    if table is None:
        return False, "awaiting migration delivery.0002 on the shared DB (PM, user approval)"
    return True, "slice 5.3 present"


_READY, _WHY = slice_53_ready()
requires_53 = pytest.mark.skipif(not _READY, reason=_WHY)
P5_53 = [pytest.mark.p5_53, requires_53]

# --------------------------------------------------------------------------- places

QA02_ID = 2
QA02 = (26.9124, 75.7873)  # QA-02 pin (01 §8.7)
DROP = (26.9250, 75.8000)  # P5 customer address, about 1.9 km from the store, inside QA-02's area
QA02_HEADERS = {**APP_HEADERS, "X-Store-Id": str(QA02_ID)}
P5_ADDRESS = {
    "label": "other",
    "custom_label": "QA-02 P5",
    "house": "QA Flat 5",
    "building_street": "QA P5 Lane",
    "landmark": "",
    "area": "C Scheme",
    "city": "Jaipur",
    "state": "Rajasthan",
    "pincode": "302001",
    "lat": DROP[0],
    "lng": DROP[1],
}
R1_PHONE, R2_PHONE = QA_PHONES["c"], QA_PHONES["d"]

EARTH_M = 6_371_000.0


def offset(point: tuple[float, float], north_m: float = 0.0, east_m: float = 0.0) -> tuple[float, float]:
    """The point `north_m` metres north and `east_m` metres east of `point` (small distances)."""
    lat, lng = point
    dlat = north_m / EARTH_M
    dlng = east_m / (EARTH_M * math.cos(math.radians(lat)))
    return round(lat + math.degrees(dlat), 7), round(lng + math.degrees(dlng), 7)


def distance_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Great-circle distance (haversine), for asserting `distance_m` answers roughly."""
    la1, lo1, la2, lo2 = map(math.radians, (*a, *b))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * EARTH_M * math.asin(math.sqrt(h))


def now_iso(delta_s: float = 0) -> str:
    return (datetime.now(UTC) + timedelta(seconds=delta_s)).isoformat().replace("+00:00", "Z")


def money(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def payout_oracle(distance_km) -> Decimal:
    """D-16 default (06 §3, 5.3 notes): 30.00 + 5.00 x route distance, 2 dp half-up."""
    return money(Decimal("30.00") + Decimal("5.00") * Decimal(str(distance_km)))


# --------------------------------------------------------------------------- tiny valid images


def png_bytes(width: int = 8, height: int = 8) -> bytes:
    """A valid RGB PNG built with zlib only (no Pillow in the QA project)."""
    raw = b"".join(b"\x00" + b"\xcc\x88\x44" * width for _ in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


# Valid test numbers for KYC uploads (format-valid, not real people's): Aadhaar passes Verhoeff.
DOC_NUMBERS = {
    "AADHAAR_FRONT": "234123412346",
    "PAN": "ABCPQ1234Z",
    "DL": "RJ1420210012345",
    "RC": "RJ14QA0005",
}

# --------------------------------------------------------------------------- drivers

RIDER_DRIVER = QA_DIR / "tools" / "rider_ops_driver.py"


def rider_ops(*steps: dict, extra_env: dict | None = None) -> list[dict]:
    """Run staff/system steps through the backend services (see tools/rider_ops_driver.py)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(_ENV)
    env.update(extra_env or {})
    for _ in range(3):  # Windows: a spawn can die with 0xC0000142 (DLL init) under load; retry
        p = subprocess.run(
            ["uv", "run", "--quiet", "python", str(RIDER_DRIVER)],
            input=json.dumps(list(steps)),
            cwd=BACKEND,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=300,
        )
        if p.returncode != 3221225794:
            break
        time.sleep(2)
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("{")]
    if p.returncode != 0 or len(lines) != len(steps):
        raise AssertionError(f"rider driver failed rc={p.returncode}: {p.stderr[-2000:]}")
    return [json.loads(ln) for ln in lines]


def rider_op(**step) -> dict:
    return rider_ops(step)[0]


# --------------------------------------------------------------------------- read-only SQL


def task_row(order_id: int) -> dict | None:
    cols = ["id", "status", "rider_id", "attempt_count", "pickup_attempts", "otp_attempts",
            "assignment_mode", "distance_km", "payout_amount", "failed_at", "returned_at"]
    rows = db_query(f"select {', '.join(cols)} from delivery_deliverytask where order_id=%s", (order_id,))
    return dict(zip(cols, rows[0])) if rows else None


def offers_of(task_id: int) -> list[tuple]:
    return db_query(
        "select id, rider_id, status, offered_at, expires_at, reject_reason from delivery_deliveryoffer "
        "where task_id=%s order by id",
        (task_id,),
    )


def rider_id_of(phone: str) -> int:
    return db_query(
        "select r.id from delivery_rider r join accounts_user u on u.id=r.user_id where u.phone=%s", (phone,)
    )[0][0]


def ledger_rows(rider_id: int) -> list[tuple]:
    return db_query(
        "select id, entry_type, amount, balance_after, order_id from delivery_ridercashledger "
        "where rider_id=%s order by id",
        (rider_id,),
    )


def movements(order_id: int) -> list[tuple]:
    return db_query(
        "select variant_id, type, delta from inventory_stockmovement "
        "where order_id=%s order by id",
        (order_id,),
    )


def stock_at_qa02(variant_id: int) -> tuple[int, int]:
    return tuple(db_query(
        "select on_hand, reserved from inventory_storeinventory where store_id=%s and variant_id=%s",
        (QA02_ID, variant_id),
    )[0])


def order_status(order_id: int) -> str:
    return db_query("select status from orders_order where id=%s", (order_id,))[0][0]


def pickup_code(order_id: int) -> str:
    return db_query("select pickup_code from orders_order where id=%s", (order_id,))[0][0]


# --------------------------------------------------------------------------- rider client


class RiderClient:
    """One QA rider through the rider API (X-App-Name: rider)."""

    def __init__(self, api: httpx.Client, phone: str):
        self.api = api
        self.phone = phone
        self.session = login(phone, app="rider")

    @property
    def h(self) -> dict:
        return {**RIDER_HEADERS, **bearer(self.session.access)}

    def get(self, path: str, **params) -> httpx.Response:
        return self.api.get(f"/api/v1/rider/{path}", headers=self.h, params=params)

    def post(self, path: str, body: dict | None = None, **kw) -> httpx.Response:
        if "files" in kw or "data" in kw:
            return self.api.post(f"/api/v1/rider/{path}", headers=self.h, **kw)
        return self.api.post(f"/api/v1/rider/{path}", json=body or {}, headers=self.h)

    # profile / KYC
    def me(self) -> httpx.Response:
        return self.get("me/")

    def register(self, **overrides) -> httpx.Response:
        body = {
            "full_name": "QA Rider " + self.phone[-3:],
            "dob": "1995-05-05",
            "emergency_contact_name": "QA Contact",
            "emergency_contact_phone": "+919812345678",
            "preferred_store_id": QA02_ID,
            "vehicle_type": "BICYCLE",
            **overrides,
        }
        return self.post("register/", body)

    def upload(self, doc_type: str, content: bytes | None = None, name: str = "doc.png",
               mime: str = "image/png", number: str | None = None) -> httpx.Response:
        data = {"doc_type": doc_type}
        if number or DOC_NUMBERS.get(doc_type):
            data["number"] = number or DOC_NUMBERS[doc_type]
        files = {"file": (name, content if content is not None else png_bytes(), mime)}
        return self.post("documents/", data=data, files=files)

    def bank(self, **overrides) -> httpx.Response:
        body = {"holder_name": "QA Rider", "account_number": "123456789012", "ifsc": "HDFC0001234", **overrides}
        return self.api.put("/api/v1/rider/bank-account/", json=body, headers=self.h)

    # shift / location
    def shift_start(self, point=QA02, accuracy: float = 10) -> httpx.Response:
        return self.post("shift/start/", {"lat": point[0], "lng": point[1], "accuracy": accuracy})

    def shift_end(self) -> httpx.Response:
        return self.post("shift/end/")

    def ping(self, point=QA02, *, recorded_at: str | None = None, accuracy: float = 10, **extra) -> httpx.Response:
        p = {"lat": point[0], "lng": point[1], "accuracy": accuracy, "recorded_at": recorded_at or now_iso(), **extra}
        return self.post("locations/", {"points": [p]})

    def heartbeat(self) -> httpx.Response:
        return self.post("heartbeat/")

    def online_at(self, point=None) -> None:
        from qa_support import clear_throttle

        # 6/min location + heartbeat limits (P5-TC-30) would trip across back-to-back cases.
        clear_throttle("rider_locations")
        clear_throttle("rider_heartbeat")
        point = point or offset(QA02, north_m=20)
        r = self.shift_start(point)
        assert r.status_code == 200, describe(r)
        r = self.ping(point)
        assert r.status_code == 200, describe(r)

    # offers
    def offer(self) -> httpx.Response:
        return self.get("offers/current/")

    def wait_offer(self, timeout: float = 25, task_id: int | None = None) -> dict:
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            r = self.offer()
            assert r.status_code == 200, describe(r)
            offer = r.json().get("offer")
            if offer and (task_id is None or offer["task_id"] == task_id):
                return offer
            time.sleep(0.5)
        raise AssertionError(f"no offer for rider {self.phone[-3:]} within {timeout}s")

    def no_offer_for(self, seconds: float) -> bool:
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if self.offer().json().get("offer"):
                return False
            time.sleep(0.5)
        return True

    def accept(self, offer_id: int) -> httpx.Response:
        return self.post(f"offers/{offer_id}/accept/")

    def reject(self, offer_id: int, reason: str | None = "TOO_FAR") -> httpx.Response:
        return self.post(f"offers/{offer_id}/reject/", {"reason": reason} if reason else {})

    # task
    def task(self) -> httpx.Response:
        return self.get("tasks/current/")

    def arrived_store(self, task_id: int, point=None, accuracy: float | None = None) -> httpx.Response:
        point = point or offset(QA02, north_m=30)
        body = {"lat": point[0], "lng": point[1]}
        if accuracy is not None:
            body["accuracy"] = accuracy
        return self.post(f"tasks/{task_id}/arrived-store/", body)

    def pickup(self, task_id: int, code: str) -> httpx.Response:
        return self.post(f"tasks/{task_id}/pickup/", {"order_code": code})

    def arrived_customer(self, task_id: int, point=None, override: str | None = None) -> httpx.Response:
        point = point or offset(DROP, north_m=30)
        body = {"lat": point[0], "lng": point[1]}
        if override is not None:
            body["override_reason"] = override
        return self.post(f"tasks/{task_id}/arrived-customer/", body)

    def deliver(self, task_id: int, otp: str, cod: dict | None = None) -> httpx.Response:
        body = {"otp": otp}
        if cod is not None:
            body["cod"] = cod
        return self.post(f"tasks/{task_id}/deliver/", body)

    def fail(self, task_id: int, reason: str, note: str | None = None, call_attempts: int | None = None,
             photo: bytes | None = None) -> httpx.Response:
        data = {"reason": reason}
        if note is not None:
            data["note"] = note
        if call_attempts is not None:
            data["call_attempts"] = str(call_attempts)
        files = {"photo": ("fail.png", photo, "image/png")} if photo is not None else None
        return self.api.post(f"/api/v1/rider/tasks/{task_id}/fail/", headers=self.h, data=data, files=files)


def ensure_active_rider(api: httpx.Client, phone: str) -> RiderClient:
    """The QA rider `phone` ACTIVE at QA-02 with every document approved (idempotent): register if
    needed, upload what is missing, add bank details, then approve as Super Admin (driver)."""
    rider = RiderClient(api, phone)
    r = rider.me()
    if r.status_code == 403:
        r = rider.register()
        assert r.status_code == 201, describe(r)
        r = rider.me()
    me = r.json()
    if me["status"] != "ACTIVE" or (me.get("home_store") or {}).get("id") != QA02_ID:
        for doc_type in me.get("missing_documents") or []:
            up = rider.upload(doc_type)
            assert up.status_code == 201, describe(up)
        if not me.get("bank_account"):
            assert rider.bank().status_code == 200
        out = rider_op(op="activate", **{"as": SUPER}, phone=phone, store_id=QA02_ID)
        assert out["ok"], out
    return rider


def reset_rider(phone: str) -> dict:
    """End any task the QA rider holds and set them offline (driver, as Super Admin)."""
    out = rider_op(op="cleanup_rider", **{"as": SUPER}, phone=phone)
    assert out["ok"], out
    return out["result"]


# --------------------------------------------------------------------------- customers at QA-02


class Qa02Shop(Shop):
    """A QA customer's cart and orders at QA-02 (X-Store-Id 2, the P5 Jaipur address)."""

    @property
    def h(self) -> dict:
        return {**QA02_HEADERS, **self.session.headers}

    placed: list[int]

    def track(self, order_id: int) -> httpx.Response:
        return self.api.get(f"/api/v1/orders/{order_id}/track/", headers=self.h)

    def place_cod(self, lines: dict[int, int] | None = None) -> dict:
        self.fill(lines or {V_SUN_1L: 1}, address_id=self.address["id"])
        r = self.place("COD", address_id=self.address["id"])
        assert r.status_code == 201, describe(r)
        self.placed.append(r.json()["order"]["id"])
        return r.json()["order"]

    def place_online_paid(self, lines: dict[int, int] | None = None) -> dict:
        self.fill(lines or {V_SUN_1L: 1}, address_id=self.address["id"])
        r = self.place("ONLINE", address_id=self.address["id"])
        assert r.status_code == 201, describe(r)
        order, rzp = r.json()["order"], r.json()["razorpay"]
        self.placed.append(order["id"])
        v = self.verify(order["id"], rzp["order_id"])
        assert v.status_code == 200 and v.json()["status"] == "PLACED", describe(v)
        return v.json()


def make_qa02_shop(api: httpx.Client, make_address, phone_key: str) -> Qa02Shop:
    from qa_support import clear_throttle

    # A P5 run places far more than the per-user hourly limits allow (orders 30/h, addresses 30/h,
    # payments 60/h); the limits themselves are covered by P3/P4 cases. QA Redis DB 5 only.
    for scope in ("orders_create", "payments", "address_write"):
        clear_throttle(scope)
    # DL-61 (d): earlier cases legitimately refuse COD deliveries, which blocks the QA customer
    # from COD after two refusals. Lift it (as Ops, through the service) so each case starts clean.
    if db_query("select cod_blocked from accounts_user where phone=%s", (QA_PHONES[phone_key],))[0][0]:
        rider_op(op="lift_cod_block", **{"as": SUPER}, customer_phone=QA_PHONES[phone_key])
    # T9 commits stock at every pickup: top QA-02 up (inventory service, INWARD) when it runs low.
    for vid in (V_SUN_1L, V_FLAX):
        row = db_query("select on_hand - reserved from inventory_storeinventory where store_id=%s and variant_id=%s",
                       (QA02_ID, vid))
        if row and row[0][0] < 20:
            store_ops({"op": "inward_qa02", "as": SUPER, "variant_id": vid, "qty": 100})
    session = login(QA_PHONES[phone_key])
    shop = Qa02Shop(api, session)
    shop.placed = []
    shop.cancel_pending()
    shop.clear()
    shop.address = make_address(session, **P5_ADDRESS)
    return shop


def cleanup_orders(shop: Qa02Shop) -> None:
    """Cancel what the test left open: the customer cancels in PLACED/ACCEPTED (T11), Ops in
    PACKING/PACKED (T12). OUT_FOR_DELIVERY and later are ended by `reset_rider` (fail + return)."""
    for oid in shop.placed:
        status = order_status(oid)
        if status in ("PLACED", "ACCEPTED"):
            shop.cancel(oid)
        elif status in ("PACKING", "PACKED"):
            store_ops({"op": "cancel", "as": OPS, "order_id": oid, "reason": "OTHER_STAFF", "note": "QA cleanup"})


def wait_order_status(order_id: int, status: str, timeout: float = 45) -> None:
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if order_status(order_id) == status:
            return
        time.sleep(0.5)
    raise AssertionError(f"order {order_id} not {status} within {timeout}s (is {order_status(order_id)})")


def wait_task_status(order_id: int, status: str, timeout: float = 45) -> dict:
    end = time.monotonic() + timeout
    row = None
    while time.monotonic() < end:
        row = task_row(order_id)
        if row and row["status"] == status:
            return row
        time.sleep(0.5)
    raise AssertionError(f"task of order {order_id} not {status} within {timeout}s (is {row})")


def pack(order_id: int) -> None:
    """Ops start packing + mark packed (QA-02 is auto-accept, so the order is ACCEPTED)."""
    out = store_ops({"op": "start_packing", "as": OPS, "order_id": order_id},
                    {"op": "packed", "as": OPS, "order_id": order_id})
    assert all(o["ok"] for o in out), out


# --------------------------------------------------------------------------- flows

STAGES = ["OFR", "ASG", "ATS", "PKD", "OFD", "ATC"]


def bring_to(stage: str, *, shop: Qa02Shop, rider: RiderClient, method: str = "COD",
             lines: dict[int, int] | None = None) -> dict:
    """Place an order at QA-02 and walk it to `stage` (see the shorthands in 02, Phase 5).
    Returns {order, task_id, offer, ...}. The rider must already be online at the store."""
    assert stage in STAGES, stage
    order = shop.place_cod(lines) if method == "COD" else shop.place_online_paid(lines)
    oid = order["id"]
    wait_order_status(oid, "ACCEPTED")  # auto-accept at QA-02 (QA worker)
    offer = rider.wait_offer()
    ctx = {"order": order, "order_id": oid, "offer": offer, "task_id": offer["task_id"]}
    if stage == "OFR":
        return ctx
    r = rider.accept(offer["id"])
    assert r.status_code == 200, describe(r)
    ctx["task"] = r.json()
    if stage == "ASG":
        return ctx
    if STAGES.index(stage) >= STAGES.index("ATS"):
        r = rider.arrived_store(ctx["task_id"])
        assert r.status_code == 200, describe(r)
    if STAGES.index(stage) >= STAGES.index("PKD"):
        pack(oid)
    if STAGES.index(stage) >= STAGES.index("OFD"):
        r = rider.pickup(ctx["task_id"], pickup_code(oid))
        assert r.status_code == 200, describe(r)
        ctx["otp"] = shop.track(oid).json()["delivery_otp"]
    if stage == "ATC":
        r = rider.arrived_customer(ctx["task_id"])
        assert r.status_code == 200, describe(r)
    return ctx


def cod_due(task_body: dict) -> dict:
    return {"mode": "cash", "amount": task_body["cod_amount_due"]}


def wrong_otp(otp: str) -> str:
    return f"{(int(otp) + 1) % 10_000:04d}"


__all__ = [
    "DROP", "P5_53", "QA02", "QA02_ID", "R1_PHONE", "R2_PHONE", "V_FLAX", "V_SUN_1L",
    "RiderClient", "Qa02Shop", "bring_to", "cod_due", "distance_m", "ensure_active_rider",
    "ledger_rows", "make_qa02_shop", "movements", "now_iso", "offers_of", "offset", "pack",
    "payout_oracle", "pickup_code", "png_bytes", "reset_rider", "rider_id_of", "rider_op",
    "rider_ops", "stock_at_qa02", "task_row", "wait_order_status", "wait_task_status", "wrong_otp",
]


# --------------------------------------------------------------------------- fixtures
# Imported by the test modules (`from p5_support import r1, r2, ...`), so pytest registers them.


@pytest.fixture(scope="module")
def qa_worker():
    """The QA Celery worker on DB 7 runs auto-accept, dispatch countdowns, refunds, invoices."""
    from p4_support import start_worker

    start_worker("p5-worker.log")
    yield


@pytest.fixture
def r1(api, qa_worker):
    reset_rider(R1_PHONE)
    rider = ensure_active_rider(api, R1_PHONE)
    yield rider
    reset_rider(R1_PHONE)


@pytest.fixture
def r2(api, qa_worker):
    reset_rider(R2_PHONE)
    rider = ensure_active_rider(api, R2_PHONE)
    yield rider
    reset_rider(R2_PHONE)


@pytest.fixture
def p5_shop_a(api, make_address):
    shop = make_qa02_shop(api, make_address, "a")
    yield shop
    cleanup_orders(shop)
    shop.cancel_pending()
    shop.clear()


@pytest.fixture
def p5_shop_b(api, make_address):
    shop = make_qa02_shop(api, make_address, "b")
    yield shop
    cleanup_orders(shop)
    shop.cancel_pending()
    shop.clear()
