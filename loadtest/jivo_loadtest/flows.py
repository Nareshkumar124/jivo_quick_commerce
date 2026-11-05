"""The app journeys the load test replays, written against a tiny HTTP interface (`Http`) so the
same code runs under Locust (`locustfile.py`) and in the unit tests (a fake server).

Every request carries the app headers (`X-App-Name`, `X-App-Version`, `X-Platform`), catalog
and cart calls carry `X-Store-Id` from the serviceability check, and requests are grouped by
path template (`/api/v1/orders/{id}/`) so each endpoint has one stats row.

A buyer journey (one order):
  serviceability -> home -> categories -> product list -> product detail -> search suggest ->
  search -> clear cart -> add 1-3 items -> change a quantity -> set the address -> read cart ->
  place the order (COD, or ONLINE: fake-gateway verify, or abandon + cancel on a real gateway)
  -> poll the order and the active list -> sometimes cancel it.
A browser journey (anonymous): app config -> serviceability -> home -> categories -> a product
list -> a product -> search.
A rider session (`RiderSession`, the rider app): log in -> profile -> start a shift at the
home store -> then, every location interval the server gives, a GPS batch and an offer
poll, plus a heartbeat about once a minute -> end the shift when the session stops. Riders
never accept an offer, so load-test orders stay before pickup and no stock is committed.

Money is never computed here: the order is placed with the cart's own `bill.grand_total` as
`expected_grand_total`, as the app does.
"""

from __future__ import annotations

import random
import threading
import time
import uuid
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol
from urllib.parse import urlencode

from jivo_loadtest import gateway
from jivo_loadtest.config import API, RunConfig

ACCESS_REFRESH_AFTER_S = 13 * 60  # access tokens live 15 minutes; refresh like the app does


@dataclass
class Reply:
    status: int
    body: Any = None

    @property
    def error_code(self) -> str | None:
        if isinstance(self.body, dict) and isinstance(self.body.get("error"), dict):
            return self.body["error"].get("code")
        return None

    @property
    def error_details(self) -> dict:
        if isinstance(self.body, dict) and isinstance(self.body.get("error"), dict):
            return self.body["error"].get("details") or {}
        return {}


class Http(Protocol):
    def request(
        self,
        method: str,
        path: str,
        *,
        name: str,
        json: Any = None,
        headers: dict | None = None,
        expect: Iterable[int] = (200,),
    ) -> Reply:
        """Send one request; record it as failed unless its status is in `expect`."""

    def journey_failed(self, name: str, message: str) -> None:
        """Record a journey that could not go on (a stats row of type JOURNEY)."""


class JourneyAborted(Exception):
    """The journey cannot continue (already recorded)."""


@dataclass
class Recorder:
    """Process-wide counters for the report: when orders were placed, and how journeys ended."""

    started_at: float = field(default_factory=time.monotonic)
    placed: list[tuple[float, str]] = field(default_factory=list)  # (seconds into run, method)
    outcomes: dict[str, int] = field(default_factory=dict)
    lock: threading.Lock = field(default_factory=threading.Lock)

    def reset(self) -> None:
        with self.lock:
            self.started_at = time.monotonic()
            self.placed.clear()
            self.outcomes.clear()

    def order_placed(self, method: str) -> None:
        with self.lock:
            self.placed.append((time.monotonic() - self.started_at, method))

    def outcome(self, name: str) -> None:
        with self.lock:
            self.outcomes[name] = self.outcomes.get(name, 0) + 1

    def orders_per_min(self, from_s: float, to_s: float) -> float:
        span = to_s - from_s
        if span <= 0:
            return 0.0
        with self.lock:
            count = sum(1 for t, _ in self.placed if from_s <= t <= to_s)
        return count * 60.0 / span


RECORDER = Recorder()


def _q(path: str, **params: Any) -> str:
    return f"{path}?{urlencode(params)}" if params else path


@dataclass
class Variant:
    id: int
    orderable: int
    max_qty: int


class Session:
    """One app session. Anonymous until `login()`."""

    def __init__(
        self,
        http: Http,
        cfg: RunConfig,
        *,
        phone: str | None = None,
        rng: random.Random | None = None,
        pause: Callable[[float], None] | None = None,
        clock: Callable[[], float] = time.monotonic,
        recorder: Recorder = RECORDER,
        app: str = "customer",
    ) -> None:
        self.http, self.cfg, self.phone, self.app = http, cfg, phone, app
        self.rng = rng or random.Random()
        self.pause = pause or (lambda seconds: None)
        self.clock, self.recorder = clock, recorder
        self.access: str | None = None
        self.refresh: str | None = None
        self.token_at = 0.0
        self.terms_version: str | None = None
        self.store_id: int | None = None
        self.address_id: int | None = None
        self.lat, self.lng = cfg.lat, cfg.lng

    # ------------------------------------------------------------------ plumbing

    def headers(self, *, store: bool = False, auth: bool = False, extra: dict | None = None):
        headers = {
            "X-App-Name": self.app,
            "X-App-Version": self.cfg.app_version,
            "X-Platform": self.cfg.platform,
            "Accept": "application/json",
        }
        if store and self.store_id is not None:
            headers["X-Store-Id"] = str(self.store_id)
        if auth and self.access:
            headers["Authorization"] = f"Bearer {self.access}"
        if extra:
            headers.update(extra)
        return headers

    def call(
        self,
        method: str,
        path: str,
        name: str,
        *,
        json: Any = None,
        store: bool = False,
        auth: bool = False,
        expect: Iterable[int] = (200,),
        extra: dict | None = None,
    ) -> Reply:
        if auth:
            self._refresh_if_due()
        return self.http.request(
            method,
            path,
            name=name,
            json=json,
            headers=self.headers(store=store, auth=auth, extra=extra),
            expect=tuple(expect),
        )

    def fail(self, name: str, message: str) -> JourneyAborted:
        self.http.journey_failed(name, message)
        self.recorder.outcome(f"aborted: {name}")
        return JourneyAborted(f"{name}: {message}")

    def think(self, low: float = 0.5, high: float = 2.0) -> None:
        self.pause(self.rng.uniform(low, high))

    # ------------------------------------------------------------------ auth

    def app_config(self) -> None:
        reply = self.call("GET", f"{API}/config/app/", f"{API}/config/app/")
        if reply.status == 200 and isinstance(reply.body, dict):
            self.terms_version = reply.body.get("terms_version") or self.terms_version

    def login(self) -> None:
        if not self.phone:
            raise ValueError("an anonymous session cannot log in")
        if self.terms_version is None:
            self.app_config()
        reply = self.call(
            "POST",
            f"{API}/auth/otp/request/",
            f"{API}/auth/otp/request/",
            json={"phone": self.phone, "app": self.app, "purpose": "login"},
        )
        if reply.status != 200:
            raise self.fail("login", f"OTP request answered {reply.status} {reply.error_code}")
        self.think(1, 3)  # typing the OTP
        reply = self.call(
            "POST",
            f"{API}/auth/otp/verify/",
            f"{API}/auth/otp/verify/",
            json={
                "phone": self.phone,
                "otp": self.cfg.otp,
                "app": self.app,
                "terms_version": self.terms_version or "1",
            },
        )
        if reply.status != 200 or not isinstance(reply.body, dict):
            raise self.fail("login", f"OTP verify answered {reply.status} {reply.error_code}")
        self.access, self.refresh = reply.body["access"], reply.body["refresh"]
        self.token_at = self.clock()
        user = reply.body.get("user") or {}
        if self.app == "customer" and not user.get("is_profile_complete", True):
            self.call(
                "PATCH",
                f"{API}/me/",
                f"{API}/me/",
                json={"name": f"Loadtest {self.phone[-3:]}"},
                auth=True,
            )

    def _refresh_if_due(self) -> None:
        if not self.refresh or self.clock() - self.token_at < ACCESS_REFRESH_AFTER_S:
            return
        reply = self.http.request(
            "POST",
            f"{API}/auth/token/refresh/",
            name=f"{API}/auth/token/refresh/",
            json={"refresh": self.refresh},
            headers=self.headers(),
            expect=(200,),
        )
        if reply.status == 200 and isinstance(reply.body, dict):
            self.access, self.refresh = reply.body["access"], reply.body["refresh"]
            self.token_at = self.clock()
        else:  # refresh token lost (e.g. the server's data was reset): log in again
            self.access = self.refresh = None
            self.login()

    def ensure_address(self) -> int:
        if self.address_id is not None:
            return self.address_id
        reply = self.call("GET", f"{API}/addresses/", f"{API}/addresses/", auth=True)
        results = (reply.body or {}).get("results", []) if reply.status == 200 else []
        usable = [a for a in results if a.get("is_serviceable")]
        usable.sort(key=lambda a: not a.get("is_default"))
        if usable:
            chosen = usable[0]
        else:
            reply = self.call(
                "POST",
                f"{API}/addresses/",
                f"{API}/addresses/",
                auth=True,
                expect=(201,),
                json={
                    "label": "other",
                    "custom_label": "loadtest",
                    "house": f"Load test {self.phone[-3:] if self.phone else '000'}",
                    "building_street": "Load test street",
                    "city": "Gurugram",
                    "state": "Haryana",
                    "pincode": "122001",
                    "lat": float(self.cfg.lat),
                    "lng": float(self.cfg.lng),
                },
            )
            if reply.status != 201:
                raise self.fail("address", f"could not save an address ({reply.status})")
            chosen = reply.body
        self.address_id = int(chosen["id"])
        self.lat, self.lng = chosen.get("lat", self.cfg.lat), chosen.get("lng", self.cfg.lng)
        return self.address_id

    # ------------------------------------------------------------------ browse

    def serviceability(self) -> int:
        reply = self.call(
            "GET",
            _q(f"{API}/serviceability/", lat=self.lat, lng=self.lng),
            f"{API}/serviceability/",
        )
        body = reply.body if reply.status == 200 and isinstance(reply.body, dict) else {}
        if not body.get("serviceable") or not body.get("store"):
            raise self.fail("serviceability", "the load-test location is not serviceable")
        self.store_id = int(body["store"]["id"])
        if not body["store"].get("is_open", True):
            self.recorder.outcome("store closed")
        return self.store_id

    def browse(self) -> list[Variant]:
        """Home, categories, a product list, a product page and a search: the in-stock variants
        seen on the way (to fill the cart with)."""
        seen: dict[int, Variant] = {}

        def collect(cards: Iterable[dict]) -> None:
            for card in cards or ():
                for v in card.get("variants") or ():
                    if v.get("orderable_quantity", 0) > 0:
                        seen[int(v["id"])] = Variant(
                            int(v["id"]), int(v["orderable_quantity"]), int(v["max_qty_per_order"])
                        )

        home = self.call("GET", f"{API}/home/", f"{API}/home/", store=True, auth=bool(self.access))
        for rail in (home.body or {}).get("collections", []) if home.status == 200 else []:
            collect(rail.get("products"))
        self.think()

        cats = self.call("GET", f"{API}/categories/", f"{API}/categories/", store=True)
        categories = (cats.body or {}).get("results", []) if cats.status == 200 else []
        slugs = [c["slug"] for c in categories if c.get("slug")]
        products: list[dict] = []
        if slugs:
            reply = self.call(
                "GET",
                _q(f"{API}/products/", category=self.rng.choice(slugs), page_size=20),
                f"{API}/products/",
                store=True,
            )
            products = (reply.body or {}).get("results", []) if reply.status == 200 else []
            collect(products)
            self.think()
        if products:
            product = self.rng.choice(products)
            reply = self.call(
                "GET",
                f"{API}/products/{product['slug']}/",
                f"{API}/products/{{id_or_slug}}/",
                store=True,
            )
            if reply.status == 200 and isinstance(reply.body, dict):
                collect([reply.body])
            self.think()

        term = self.rng.choice(self.cfg.search_terms)
        self.call(
            "GET",
            _q(f"{API}/search/suggest/", q=term[:3]),
            f"{API}/search/suggest/",
            store=True,
        )
        reply = self.call("GET", _q(f"{API}/search/", q=term), f"{API}/search/", store=True)
        if reply.status == 200:
            collect((reply.body or {}).get("results", []))
        return list(seen.values())

    # ------------------------------------------------------------------ cart & checkout

    def _cart_call(self, method: str, path: str, name: str, **kwargs) -> dict:
        reply = self.call(method, path, name, store=True, auth=True, **kwargs)
        if reply.status != 200 or not isinstance(reply.body, dict):
            raise self.fail("cart", f"{method} {name} answered {reply.status} {reply.error_code}")
        return reply.body

    def set_item(self, variant_id: int, quantity: int) -> dict:
        return self._cart_call(
            "POST",
            f"{API}/cart/items/",
            f"{API}/cart/items/",
            json={"variant_id": variant_id, "quantity": quantity},
        )

    def fill_cart(self, variants: list[Variant]) -> dict:
        if not variants:
            raise self.fail("cart", "no in-stock product was found while browsing")
        self._cart_call("DELETE", f"{API}/cart/", f"{API}/cart/")
        picks = self.rng.sample(variants, k=min(len(variants), self.rng.randint(1, 3)))
        cart: dict = {}
        for v in picks:
            cart = self.set_item(v.id, max(1, min(self.rng.randint(1, 2), v.max_qty, v.orderable)))
            self.think(0.3, 1.0)
        lines = cart.get("items") or []
        if lines:  # change a quantity with the stepper (PATCH /cart/items/{id}/)
            line = lines[0]
            limit = min(
                line["variant"].get("max_qty_per_order", 1),
                line["variant"].get("orderable_quantity", 1),
            )
            if line["quantity"] < limit:
                cart = self._cart_call(
                    "PATCH",
                    f"{API}/cart/items/{line['id']}/",
                    f"{API}/cart/items/{{id}}/",
                    json={"quantity": line["quantity"] + 1},
                )
        cart = self._cart_call(
            "PATCH", f"{API}/cart/", f"{API}/cart/", json={"address_id": self.ensure_address()}
        )
        return self._fix_blockers(cart, variants)

    def _fix_blockers(self, cart: dict, variants: list[Variant]) -> dict:
        """Act on checkout blockers the way a customer would: add items below the minimum
        order, lower quantities above stock. Anything else ends the journey."""
        for _ in range(4):
            blockers = {b["code"] for b in (cart.get("checkout") or {}).get("blockers", [])}
            if not blockers:
                return cart
            if "STOCK_UNAVAILABLE" in blockers:
                for line in cart.get("items") or []:
                    if line.get("issue"):
                        cart = self.set_item(
                            line["variant"]["id"], line["variant"].get("orderable_quantity", 0)
                        )
                continue
            if blockers == {"MIN_ORDER_NOT_MET"}:
                in_cart = {line["variant"]["id"]: line for line in cart.get("items") or []}
                more = [v for v in variants if v.id not in in_cart]
                if more:
                    v = self.rng.choice(more)
                    cart = self.set_item(v.id, 1)
                    continue
                line = next(
                    (
                        line
                        for line in in_cart.values()
                        if line["quantity"] < line["variant"].get("max_qty_per_order", 1)
                    ),
                    None,
                )
                if line is not None:
                    cart = self.set_item(line["variant"]["id"], line["quantity"] + 1)
                    continue
            raise self.fail("checkout blocked", ",".join(sorted(blockers)))
        raise self.fail("checkout blocked", "blockers did not clear")

    def choose_method(self, cart: dict) -> str:
        available = [
            m["method"] for m in cart.get("payment_methods") or [] if m.get("is_available")
        ]
        if not available:
            raise self.fail("checkout blocked", "no payment method available")
        wants = "ONLINE" if self.rng.random() < self.cfg.online_share else "COD"
        return wants if wants in available else available[0]

    def place(self, cart: dict, method: str, *, retry: bool = True) -> dict:
        reply = self.call(
            "POST",
            f"{API}/orders/",
            f"{API}/orders/",
            store=True,
            auth=True,
            expect=(200, 201),
            extra={"Idempotency-Key": str(uuid.uuid4())},
            json={
                "address_id": self.ensure_address(),
                "payment_method": method,
                "expected_grand_total": cart["bill"]["grand_total"],
            },
        )
        if reply.status in (200, 201):
            return reply.body
        pending = reply.error_details.get("pending_order_id")
        if retry and reply.error_code == "INVALID_STATE_TRANSITION" and pending:
            # One unpaid order at a time: give the old one up, as the app offers.
            self.cancel(int(pending), "CHANGE_PAYMENT_METHOD")
            return self.place(self.read_cart(), method, retry=False)
        if retry and reply.error_code in {"PRICE_CHANGED", "STOCK_UNAVAILABLE"}:
            cart = self._fix_blockers(self.read_cart(), [])
            return self.place(cart, method, retry=False)
        raise self.fail("place order", f"{reply.status} {reply.error_code}")

    def read_cart(self) -> dict:
        return self._cart_call("GET", f"{API}/cart/", f"{API}/cart/")

    def pay_online(self, placement: dict) -> bool:
        """Pay with the fake gateway (local servers). On a real gateway (staging, Razorpay test
        mode) a script cannot pay, so the customer gives up and cancels (T5): False."""
        order, razorpay = placement["order"], placement.get("razorpay")
        if not gateway.is_fake_checkout(razorpay):
            self.recorder.outcome("online: abandoned (real gateway)")
            self.think(1, 3)
            self.cancel(order["id"], "CHANGE_PAYMENT_METHOD")
            return False
        self.think(1, 3)  # the checkout sheet
        payment_id = gateway.new_payment_id()
        reply = self.call(
            "POST",
            f"{API}/payments/razorpay/verify/",
            f"{API}/payments/razorpay/verify/",
            auth=True,
            json={
                "order_id": order["id"],
                "razorpay_order_id": razorpay["order_id"],
                "razorpay_payment_id": payment_id,
                "razorpay_signature": gateway.signature(razorpay["order_id"], payment_id),
            },
        )
        if reply.status != 200:
            raise self.fail("payment", f"verify answered {reply.status} {reply.error_code}")
        self.recorder.outcome("online: paid (fake gateway)")
        return True

    def poll(self, order_id: int) -> dict | None:
        latest = None
        self.call("GET", _q(f"{API}/orders/", status="active"), f"{API}/orders/", auth=True)
        for _ in range(self.cfg.polls):
            self.think(2, 5)
            reply = self.call(
                "GET", f"{API}/orders/{order_id}/", f"{API}/orders/{{id}}/", auth=True
            )
            if reply.status == 200:
                latest = reply.body
        return latest

    def cancel(self, order_id: int, reason: str) -> bool:
        reply = self.call(
            "POST",
            f"{API}/orders/{order_id}/cancel/",
            f"{API}/orders/{{id}}/cancel/",
            auth=True,
            json={"reason": reason, "note": "loadtest"},
        )
        return reply.status == 200

    # ------------------------------------------------------------------ journeys

    def buyer_journey(self) -> str:
        """One order, start to finish. Returns how it ended (also counted in the recorder)."""
        try:
            if self.access is None:
                self.login()
            self.ensure_address()
            self.serviceability()
            variants = self.browse()
            cart = self.fill_cart(variants)
            self.think()
            method = self.choose_method(cart)
            placement = self.place(cart, method)
            order = placement["order"]
            if order.get("status") == "PAYMENT_PENDING" and not self.pay_online(placement):
                return "abandoned"
            self.recorder.order_placed(method)
            latest = self.poll(order["id"]) or order
            if latest.get("can_cancel") and self.rng.random() < self.cfg.cancel_share:
                outcome = "cancelled" if self.cancel(order["id"], "CHANGED_MIND") else "placed"
            else:
                outcome = "placed"
        except JourneyAborted:
            return "aborted"
        self.recorder.outcome(f"order {outcome}")
        return outcome

    def browser_journey(self) -> str:
        try:
            if self.terms_version is None:
                self.app_config()
            self.serviceability()
            self.browse()
        except JourneyAborted:
            return "aborted"
        self.recorder.outcome("browsed")
        return "browsed"


def _iso(moment: datetime) -> str:
    return moment.astimezone(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class RiderSession(Session):
    """The rider app on shift (04 §2.3, §3). Uses only the contract published by Phase 5:
    `/rider/me/`, `/rider/shift/start/`, `/rider/locations/`, `/rider/offers/current/`,
    `/rider/heartbeat/`, `/rider/shift/end/`."""

    DEFAULT_INTERVAL_S = 30.0
    DEFAULT_SAMPLE_S = 10.0
    WANDER_DEG = 0.005  # about 500 m around the store: well inside the 2 km shift geofence

    def __init__(
        self,
        http: Http,
        cfg: RunConfig,
        *,
        phone: str,
        wallclock: Callable[[], datetime] | None = None,
        **kwargs: Any,
    ) -> None:
        super().__init__(http, cfg, phone=phone, app="rider", **kwargs)
        self.wallclock = wallclock or (lambda: datetime.now(UTC))
        self.online = False
        self.interval_s = self.DEFAULT_INTERVAL_S
        self.sample_s = self.DEFAULT_SAMPLE_S
        self.max_batch = 50
        self.last_heartbeat = float("-inf")
        self.last_point: datetime | None = None
        self.position = (float(cfg.lat), float(cfg.lng))

    def _settings(self, body: dict | None) -> None:
        location = (body or {}).get("location") or {}
        self.interval_s = float(location.get("idle_interval_seconds") or self.interval_s)
        self.sample_s = float(location.get("idle_sample_seconds") or self.sample_s)
        self.max_batch = int(location.get("max_batch") or self.max_batch)

    def next_wait(self) -> float:
        """Seconds until the next upload: the server's idle interval (Locust `wait_time`)."""
        return self.interval_s

    def start_shift(self) -> None:
        if self.access is None:
            self.login()
        me = self.call("GET", f"{API}/rider/me/", f"{API}/rider/me/", auth=True)
        status = (me.body or {}).get("status") if me.status == 200 else None
        if status != "ACTIVE":
            raise self.fail(
                "rider shift", f"rider profile is {status or me.status}, not ACTIVE (seeded?)"
            )
        lat, lng = self.position
        reply = self.call(
            "POST",
            f"{API}/rider/shift/start/",
            f"{API}/rider/shift/start/",
            auth=True,
            json={"lat": lat, "lng": lng, "accuracy": 10.0},
        )
        if reply.status != 200 or not (reply.body or {}).get("is_online"):
            reason = reply.error_details.get("reason") or reply.error_code
            raise self.fail("rider shift", f"shift start answered {reply.status} {reason}")
        self._settings(reply.body)
        self.online = True
        self.recorder.outcome("rider: shift started")

    def _step(self, value: float, centre: float) -> float:
        moved = value + self.rng.uniform(-0.0002, 0.0002)
        return min(max(moved, centre - self.WANDER_DEG), centre + self.WANDER_DEG)

    def _points(self) -> list[dict]:
        """GPS points sampled since the last upload, along a small random walk around the
        configured point, with strictly increasing `recorded_at` (the server de-duplicates on
        it)."""
        now = self.wallclock()
        count = max(1, min(self.max_batch, round(self.interval_s / self.sample_s)))
        points = []
        for i in range(count):
            at = now - timedelta(seconds=self.sample_s * (count - 1 - i))
            if self.last_point is not None and at <= self.last_point:
                at = self.last_point + timedelta(milliseconds=1)
            self.last_point = at
            lat = self._step(self.position[0], float(self.cfg.lat))
            lng = self._step(self.position[1], float(self.cfg.lng))
            self.position = (lat, lng)
            points.append(
                {
                    "lat": round(lat, 6),
                    "lng": round(lng, 6),
                    "accuracy": round(self.rng.uniform(5, 20), 1),
                    "speed": round(self.rng.uniform(0, 3), 2),
                    "heading": round(self.rng.uniform(0, 359), 1),
                    "recorded_at": _iso(at),
                    "is_mocked": False,
                }
            )
        return points

    def tick(self) -> str:
        """One location interval: a GPS batch, an offer poll, and a heartbeat when due."""
        reply = self.call(
            "POST",
            f"{API}/rider/locations/",
            f"{API}/rider/locations/",
            auth=True,
            json={"points": self._points()},
        )
        if reply.status == 200:
            self._settings(reply.body)
        elif reply.error_code == "RIDER_OFFLINE":
            self.online = False  # the server set the rider offline: go online again next time
            return "set offline"
        self.call("GET", f"{API}/rider/offers/current/", f"{API}/rider/offers/current/", auth=True)
        if self.clock() - self.last_heartbeat >= self.cfg.heartbeat_every_s:
            beat = self.call(
                "POST", f"{API}/rider/heartbeat/", f"{API}/rider/heartbeat/", auth=True
            )
            self.last_heartbeat = self.clock()
            if beat.status == 200 and (beat.body or {}).get("is_online") is False:
                self.online = False
                return "set offline"
        return "online"

    def rider_journey(self) -> str:
        try:
            if not self.online:
                self.start_shift()
            outcome = self.tick()
        except JourneyAborted:
            return "aborted"
        self.recorder.outcome(f"rider: {outcome}")
        return outcome

    def end_shift(self) -> None:
        if self.online:
            self.call("POST", f"{API}/rider/shift/end/", f"{API}/rider/shift/end/", auth=True)
            self.online = False
