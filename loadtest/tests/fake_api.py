"""A small in-memory imitation of the Jivo API, enough to drive the flows without a server. It
checks what the real API requires (app headers, X-Store-Id, the bearer token, the
Idempotency-Key, the fake-gateway signature) so a flow that forgets one fails here first."""

import re
from dataclasses import dataclass, field
from decimal import Decimal
from urllib.parse import parse_qs, urlsplit

from jivo_loadtest import gateway
from jivo_loadtest.flows import Reply

API = "/api/v1"
STORE_ID = 7
PRODUCTS = [
    {"id": 1, "slug": "canola-1l", "price": Decimal("279.00"), "stock": 50, "max": 5},
    {"id": 2, "slug": "chia-100g", "price": Decimal("119.00"), "stock": 50, "max": 5},
    {"id": 3, "slug": "flax-200g", "price": Decimal("49.00"), "stock": 50, "max": 5},
    {"id": 4, "slug": "olive-5l", "price": Decimal("1299.00"), "stock": 0, "max": 3},
]


def money(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.01'))}"


@dataclass
class FakeApi:
    serviceable: bool = True
    min_order: Decimal = Decimal("99.00")
    cod_max: Decimal = Decimal("2000.00")
    key_id: str = gateway.FAKE_KEY_ID
    pending_order_once: bool = False
    calls: list[tuple[str, str, str, dict]] = field(
        default_factory=list
    )  # method, path, name, headers
    journey_failures: list[tuple[str, str]] = field(default_factory=list)
    failures: list[tuple[str, int]] = field(default_factory=list)
    cart: dict[int, int] = field(default_factory=dict)
    address_id: int | None = None
    orders: dict[int, dict] = field(default_factory=dict)
    keys: set[str] = field(default_factory=set)
    tokens: int = 0
    refreshes: int = 0
    # rider side (P5 contract)
    rider_status: str = "ACTIVE"
    rider_online: bool = False
    rider_offline_once: bool = False  # the next location batch answers 409 RIDER_OFFLINE
    shift_starts: int = 0
    heartbeats: int = 0
    offer_polls: int = 0
    points: list[dict] = field(default_factory=list)
    location_settings: dict = field(
        default_factory=lambda: {
            "idle_interval_seconds": 30,
            "idle_sample_seconds": 10,
            "active_interval_seconds": 10,
            "active_sample_seconds": 5,
            "max_batch": 50,
        }
    )

    # ------------------------------------------------------------------ Http protocol

    def request(self, method, path, *, name, json=None, headers=None, expect=(200,)):
        headers = headers or {}
        self.calls.append((method, path, name, headers))
        reply = self._route(method, path, json or {}, headers)
        if reply.status not in expect:
            self.failures.append((f"{method} {name}", reply.status))
        return reply

    def journey_failed(self, name, message):
        self.journey_failures.append((name, message))

    # ------------------------------------------------------------------ helpers

    def names(self) -> list[str]:
        return [f"{m} {n}" for m, _, n, _ in self.calls]

    @staticmethod
    def error(status, code, details=None) -> Reply:
        return Reply(status, {"error": {"code": code, "message": code, "details": details or {}}})

    def _variant(self, p) -> dict:
        return {
            "id": p["id"],
            "name": p["slug"],
            "selling_price": money(p["price"]),
            "orderable_quantity": p["stock"],
            "max_qty_per_order": p["max"],
            "stock_status": "IN_STOCK" if p["stock"] else "OUT_OF_STOCK",
        }

    def _card(self, p) -> dict:
        return {"id": p["id"], "slug": p["slug"], "variants": [self._variant(p)]}

    def _cart_body(self) -> dict:
        by_id = {p["id"]: p for p in PRODUCTS}
        items, total = [], Decimal(0)
        for line_id, (variant_id, qty) in enumerate(sorted(self.cart.items()), start=1):
            p = by_id[variant_id]
            total += p["price"] * qty
            issue = {"code": "OUT_OF_STOCK"} if qty > p["stock"] else None
            items.append(
                {"id": line_id, "variant": self._variant(p), "quantity": qty, "issue": issue}
            )
        blockers = []
        if not items:
            blockers.append({"code": "CART_EMPTY"})
        elif any(i["issue"] for i in items):
            blockers.append({"code": "STOCK_UNAVAILABLE"})
        elif total < self.min_order:
            blockers.append({"code": "MIN_ORDER_NOT_MET"})
        if items and self.address_id is None:
            blockers.append({"code": "ADDRESS_REQUIRED"})
        grand = total + (Decimal(25) if total and total < 299 else 0)
        return {
            "items": items,
            "bill": {"item_total": money(total), "grand_total": money(grand)},
            "payment_methods": [
                {"method": "ONLINE", "is_available": True},
                {"method": "COD", "is_available": grand <= self.cod_max},
            ],
            "checkout": {"can_place_order": not blockers, "blockers": blockers},
            "_grand": grand,
        }

    def _require(self, headers, *, auth=False, store=False, app=None) -> Reply | None:
        name = headers.get("X-App-Name")
        if name not in {"customer", "rider"} or (app and name != app):
            return self.error(400, "VALIDATION_ERROR", {"headers": "wrong app"})
        if not headers.get("X-App-Version"):
            return self.error(400, "VALIDATION_ERROR", {"headers": "app headers missing"})
        if auth and not headers.get("Authorization", "").startswith("Bearer access-"):
            return self.error(401, "NOT_AUTHENTICATED")
        if store and headers.get("X-Store-Id") != str(STORE_ID):
            return self.error(400, "VALIDATION_ERROR", {"X-Store-Id": "required"})
        return None

    # ------------------------------------------------------------------ routes

    def _route(self, method, path, body, headers) -> Reply:
        parts = urlsplit(path)
        p, query = parts.path, parse_qs(parts.query)
        anon_get = {
            f"{API}/config/app/",
            f"{API}/serviceability/",
        }
        catalog = {
            f"{API}/home/",
            f"{API}/categories/",
            f"{API}/products/",
            f"{API}/search/",
            f"{API}/search/suggest/",
        }
        if (p in anon_get or p.startswith(f"{API}/auth/")) and (bad := self._require(headers)):
            return bad
        if p.startswith(f"{API}/rider/"):
            return self._rider(method, p, body, headers)
        if p in catalog or p.startswith(f"{API}/products/"):
            if bad := self._require(headers, store=True, app="customer"):
                return bad
            if p == f"{API}/home/":
                rail = {"products": [self._card(x) for x in PRODUCTS[:2]]}
                return Reply(200, {"collections": [rail]})
            if p == f"{API}/categories/":
                return Reply(200, {"results": [{"slug": "edible-oils"}, {"slug": "seeds"}]})
            if p in (f"{API}/products/", f"{API}/search/"):
                assert "q" in query or "category" in query
                return Reply(200, {"results": [self._card(x) for x in PRODUCTS]})
            if p == f"{API}/search/suggest/":
                return Reply(200, {"suggestions": []})
            slug = p.rstrip("/").rsplit("/", 1)[1]
            match = [x for x in PRODUCTS if x["slug"] == slug]
            return Reply(200, self._card(match[0])) if match else self.error(404, "NOT_FOUND")
        if p == f"{API}/config/app/":
            return Reply(200, {"terms_version": "2026-11-01"})
        if p == f"{API}/serviceability/":
            assert "lat" in query
            assert "lng" in query
            if not self.serviceable:
                return Reply(200, {"serviceable": False, "store": None})
            return Reply(200, {"serviceable": True, "store": {"id": STORE_ID, "is_open": True}})
        if p == f"{API}/auth/otp/request/":
            assert re.fullmatch(r"\+91[6-9]\d{9}", body["phone"])
            return Reply(200, {"otp_length": 6})
        if p == f"{API}/auth/otp/verify/":
            if body.get("otp") != "123456" or not body.get("terms_version"):
                return self.error(400, "OTP_INVALID")
            self.tokens += 1
            return Reply(
                200,
                {
                    "access": f"access-{self.tokens}",
                    "refresh": f"refresh-{self.tokens}",
                    "user": {"is_profile_complete": False},
                },
            )
        if p == f"{API}/auth/token/refresh/":
            self.refreshes += 1
            self.tokens += 1
            return Reply(200, {"access": f"access-{self.tokens}", "refresh": "r2"})

        if bad := self._require(headers, auth=True, app="customer"):
            return bad
        if p == f"{API}/me/":
            return Reply(200, {"name": body.get("name")})
        if p == f"{API}/addresses/":
            if method == "GET":
                return Reply(200, {"results": []})
            return Reply(201, {"id": 55, "lat": body["lat"], "lng": body["lng"]})
        if p.startswith(f"{API}/cart/"):
            if bad := self._require(headers, auth=True, store=True):
                return bad
            if p == f"{API}/cart/" and method == "DELETE":
                self.cart.clear()
            elif p == f"{API}/cart/" and method == "PATCH":
                self.address_id = body.get("address_id", self.address_id)
            elif p == f"{API}/cart/items/":
                if body["quantity"] == 0:
                    self.cart.pop(body["variant_id"], None)
                else:
                    self.cart[body["variant_id"]] = body["quantity"]
            elif p.startswith(f"{API}/cart/items/"):
                line_id = int(p.rstrip("/").rsplit("/", 1)[1])
                variant_id = sorted(self.cart)[line_id - 1]
                self.cart[variant_id] = body["quantity"]
            cart = self._cart_body()
            cart.pop("_grand")
            return Reply(200, cart)
        if p == f"{API}/orders/" and method == "POST":
            return self._place(body, headers)
        if p == f"{API}/orders/" and method == "GET":
            return Reply(200, {"results": list(self.orders.values())})
        if m := re.fullmatch(rf"{API}/orders/(\d+)/", p):
            order = self.orders.get(int(m.group(1)))
            return Reply(200, order) if order else self.error(404, "NOT_FOUND")
        if m := re.fullmatch(rf"{API}/orders/(\d+)/cancel/", p):
            order = self.orders.get(int(m.group(1)))
            if order is None:
                return self.error(404, "NOT_FOUND")
            assert body["reason"] in {"CHANGED_MIND", "CHANGE_PAYMENT_METHOD"}
            order.update(status="CANCELLED", can_cancel=False)
            return Reply(200, order)
        if p == f"{API}/payments/razorpay/verify/":
            order = self.orders[body["order_id"]]
            expected = gateway.signature(body["razorpay_order_id"], body["razorpay_payment_id"])
            if body["razorpay_signature"] != expected:
                return self.error(400, "PAYMENT_VERIFICATION_FAILED")
            order.update(status="PLACED")
            return Reply(200, order)
        return self.error(404, "NOT_FOUND")

    def _place(self, body, headers) -> Reply:
        if bad := self._require(headers, auth=True, store=True):
            return bad
        key = headers.get("Idempotency-Key", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]{8,64}", key) or key in self.keys:
            return self.error(400, "VALIDATION_ERROR", {"Idempotency-Key": ["bad"]})
        if self.pending_order_once:
            self.pending_order_once = False
            self.orders[900] = {"id": 900, "status": "PAYMENT_PENDING", "can_cancel": True}
            return self.error(409, "INVALID_STATE_TRANSITION", {"pending_order_id": 900})
        cart = self._cart_body()
        if cart["checkout"]["blockers"]:
            return self.error(422, cart["checkout"]["blockers"][0]["code"])
        if body["expected_grand_total"] != money(cart["_grand"]):
            return self.error(409, "PRICE_CHANGED")
        if body["payment_method"] == "COD" and cart["_grand"] > self.cod_max:
            return self.error(422, "COD_NOT_AVAILABLE")
        self.keys.add(key)
        order_id = len(self.orders) + 1
        online = body["payment_method"] == "ONLINE"
        order = {
            "id": order_id,
            "status": "PAYMENT_PENDING" if online else "PLACED",
            "can_cancel": True,
            "bill": cart["bill"],
        }
        self.orders[order_id] = order
        self.cart.clear()
        razorpay = (
            {"key_id": self.key_id, "order_id": f"order_Fake{order_id:010d}"} if online else None
        )
        return Reply(201, {"order": order, "razorpay": razorpay})

    def _rider(self, method, p, body, headers) -> Reply:
        if bad := self._require(headers, auth=True, app="rider"):
            return bad
        state = {"location": self.location_settings, "server_time": "2026-11-05T06:00:00Z"}
        if p == f"{API}/rider/me/":
            return Reply(200, {"status": self.rider_status})
        if p == f"{API}/rider/shift/start/":
            if self.rider_status != "ACTIVE":
                return self.error(403, "RIDER_NOT_ACTIVE", {"rider_status": self.rider_status})
            assert {"lat", "lng"} <= set(body)
            self.shift_starts += 1
            self.rider_online = True
            return Reply(200, {"is_online": True, **state})
        if p == f"{API}/rider/shift/end/":
            self.rider_online = False
            return Reply(200, {"is_online": False, **state})
        if p == f"{API}/rider/locations/":
            points = body["points"]
            assert 1 <= len(points) <= self.location_settings["max_batch"]
            for point in points:
                assert {"lat", "lng", "accuracy", "recorded_at"} <= set(point)
                assert isinstance(point["lat"], float)
                assert point["recorded_at"].endswith("Z")
            if self.rider_offline_once or not self.rider_online:
                self.rider_offline_once = False
                self.rider_online = False
                return self.error(409, "RIDER_OFFLINE")
            seen = {x["recorded_at"] for x in self.points}
            fresh = [x for x in points if x["recorded_at"] not in seen]
            self.points.extend(fresh)
            return Reply(
                200,
                {
                    "accepted": len(fresh),
                    "duplicates": len(points) - len(fresh),
                    "rejected": 0,
                    **state,
                },
            )
        if p == f"{API}/rider/offers/current/":
            self.offer_polls += 1
            return Reply(200, {"offer": None, "server_time": state["server_time"]})
        if p == f"{API}/rider/heartbeat/":
            self.heartbeats += 1
            return Reply(200, {"is_online": self.rider_online, "offer": None, "task": None})
        return self.error(404, "NOT_FOUND")
