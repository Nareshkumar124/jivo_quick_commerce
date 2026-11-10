"""Phase 3 helpers: cart, order placement, fake-gateway signatures and webhooks, and the 08 §6.2
bill oracle (computed independently from the database's prices and the store's PricingConfig).

The fake-gateway secrets below are the published dev-only values from 06 §2.6 ("not secrets:
they work only with the fake gateway, which deployed environments refuse").

Stock and coupon hygiene on the shared dev DB:
- ONLINE orders are always cancelled again (T5 releases stock and the coupon hold).
- COD orders and paid ONLINE orders stay PLACED (Phase 3 cannot cancel them): they keep their
  reservation. Tests that need them use the high-stock variants (on_hand 40) and qty 1.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import secrets
import string
import uuid
from decimal import ROUND_HALF_UP, Decimal

import httpx

from qa_support import STORE_HEADERS, STORE_ID, db_query, describe

FAKE_KEY_SECRET = "jivo-fake-razorpay-key-secret-local-only"
FAKE_WEBHOOK_SECRET = "jivo-fake-razorpay-webhook-secret-local-only"
FAKE_KEY_ID = "rzp_fake_jivo_local"

CART = "/api/v1/cart/"
ITEMS = "/api/v1/cart/items/"
COUPON = "/api/v1/cart/coupon/"
COUPONS = "/api/v1/cart/coupons/"
ORDERS = "/api/v1/orders/"
VERIFY = "/api/v1/payments/razorpay/verify/"
WEBHOOK = "/api/v1/payments/razorpay/webhook/"

# Demo catalogue variants used by the suite (store GGN-01; see qa/docs/02 P3 data notes).
V_CANOLA_1L = 1  # 279 / mrp 349, max 5, high stock
V_CANOLA_2L = 2  # 549 / mrp 680, max 4, high stock
V_OLIVE_5L = 6  # 2999, max 2, on_hand 2: the oversell race
V_MUSTARD_1L = 9  # on_hand 0: out of stock
V_SUN_1L = 13  # 165 / mrp 190, max 5, high stock (category 5, under Edible Oils)
V_FLAX = 22  # 169 / mrp 199, max 5, high stock (Seeds: not Edible Oils)
V_CHIA = 21  # 249 / mrp 299, max 5 (Seeds)
V_PUMPKIN = 24  # not sold at the store (no StoreInventory row)

TWO = Decimal("0.01")


def money(value) -> Decimal:
    return Decimal(str(value)).quantize(TWO, rounding=ROUND_HALF_UP)


def m(value) -> str:
    return f"{money(value):.2f}"


def new_key() -> str:
    return uuid.uuid4().hex


def fake_id(prefix: str) -> str:
    alphabet = string.ascii_letters + string.digits
    return prefix + "".join(secrets.choice(alphabet) for _ in range(14))


def checkout_signature(order_id: str, payment_id: str, secret: str = FAKE_KEY_SECRET) -> str:
    return hmac.new(secret.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()


def webhook_signature(body: bytes, secret: str = FAKE_WEBHOOK_SECRET) -> str:
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def captured_event(rzp_order_id: str, payment_id: str, amount_paise: int) -> dict:
    return {
        "entity": "event",
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": payment_id,
                    "order_id": rzp_order_id,
                    "amount": amount_paise,
                    "currency": "INR",
                    "status": "captured",
                    "method": "upi",
                }
            }
        },
    }


def failed_event(rzp_order_id: str, payment_id: str, amount_paise: int) -> dict:
    return {
        "entity": "event",
        "event": "payment.failed",
        "payload": {
            "payment": {
                "entity": {
                    "id": payment_id,
                    "order_id": rzp_order_id,
                    "amount": amount_paise,
                    "status": "failed",
                    "error_code": "BAD_REQUEST_ERROR",
                    "error_description": "QA simulated failure",
                }
            }
        },
    }


def send_webhook(api: httpx.Client, event: dict, *, event_id: str | None = None, signature: str | None = None, raw: bytes | None = None):
    body = raw if raw is not None else json.dumps(event, separators=(",", ":")).encode()
    headers = {
        "Content-Type": "application/json",
        "X-Razorpay-Signature": signature if signature is not None else webhook_signature(body),
        "X-Razorpay-Event-Id": event_id or fake_id("evt_"),
    }
    # The webhook is server to server: no app headers, no JWT.
    return httpx.post(f"{api.base_url}{WEBHOOK}", content=body, headers=headers, timeout=30)


# --------------------------------------------------------------------------- cart / orders


class Shop:
    """One customer's cart and orders through the API (store GGN-01)."""

    def __init__(self, api: httpx.Client, session):
        self.api = api
        self.session = session

    @property
    def h(self) -> dict:
        return {**STORE_HEADERS, **self.session.headers}

    def cart(self, **params) -> httpx.Response:
        return self.api.get(CART, headers=self.h, params=params)

    def set_qty(self, variant_id: int, quantity: int) -> httpx.Response:
        return self.api.post(ITEMS, json={"variant_id": variant_id, "quantity": quantity}, headers=self.h)

    def patch(self, **body) -> httpx.Response:
        return self.api.patch(CART, json=body, headers=self.h)

    def clear(self) -> None:
        r = self.api.delete(CART, headers=self.h)
        assert r.status_code == 200, describe(r)

    def apply(self, code: str) -> httpx.Response:
        return self.api.post(COUPON, json={"code": code}, headers=self.h)

    def remove_coupon(self) -> httpx.Response:
        return self.api.delete(COUPON, headers=self.h)

    def fill(self, lines: dict[int, int], address_id: int | None = None, tip: str = "0.00") -> dict:
        """Empty cart -> exactly `lines`; address and tip saved. Returns the cart body."""
        self.clear()
        for variant_id, qty in lines.items():
            r = self.set_qty(variant_id, qty)
            assert r.status_code == 200, describe(r)
        body = {"tip": tip}
        if address_id is not None:
            body["address_id"] = address_id
        r = self.patch(**body)
        assert r.status_code == 200, describe(r)
        return r.json()

    def place(self, payment_method: str = "COD", *, address_id: int, expected: str | None = None, key: str | None = None, headers: dict | None = None) -> httpx.Response:
        if expected is None:
            expected = self.cart().json()["bill"]["grand_total"]
        hdrs = {**self.h, "Idempotency-Key": key or new_key(), **(headers or {})}
        body = {"address_id": address_id, "payment_method": payment_method, "expected_grand_total": expected}
        return self.api.post(ORDERS, json=body, headers=hdrs)

    def order(self, order_id: int) -> httpx.Response:
        return self.api.get(f"{ORDERS}{order_id}/", headers=self.h)

    def cancel(self, order_id: int, reason: str = "CHANGED_MIND") -> httpx.Response:
        return self.api.post(f"{ORDERS}{order_id}/cancel/", json={"reason": reason}, headers=self.h)

    def retry(self, order_id: int, key: str | None = None) -> httpx.Response:
        return self.api.post(
            f"{ORDERS}{order_id}/retry-payment/", json={}, headers={**self.h, "Idempotency-Key": key or new_key()}
        )

    def verify(self, order_id: int, rzp_order_id: str, payment_id: str | None = None, signature: str | None = None) -> httpx.Response:
        payment_id = payment_id or fake_id("pay_")
        body = {
            "order_id": order_id,
            "razorpay_order_id": rzp_order_id,
            "razorpay_payment_id": payment_id,
            "razorpay_signature": signature or checkout_signature(rzp_order_id, payment_id),
        }
        return self.api.post(VERIFY, json=body, headers=self.h)

    def cancel_pending(self) -> None:
        """Cancel this customer's PAYMENT_PENDING orders (one unpaid order at a time, DL-44)."""
        r = self.api.get(ORDERS, headers=self.h, params={"status": "active"})
        assert r.status_code == 200, describe(r)
        for o in r.json()["results"]:
            if o["status"] == "PAYMENT_PENDING":
                self.cancel(o["id"])


# --------------------------------------------------------------------------- oracle (08 §6.2)


def pricing() -> dict:
    row = db_query(
        "select min_order_value, delivery_fee, free_delivery_threshold, small_cart_fee, "
        "small_cart_threshold, handling_fee, cod_enabled, cod_max_order_value "
        "from stores_pricingconfig where store_id=%s",
        (STORE_ID,),
    )[0]
    keys = ["min_order_value", "delivery_fee", "free_delivery_threshold", "small_cart_fee",
            "small_cart_threshold", "handling_fee", "cod_enabled", "cod_max_order_value"]
    return dict(zip(keys, row))


def variant_prices(ids) -> dict[int, tuple[Decimal, Decimal]]:
    rows = db_query(
        "select v.id, v.mrp, coalesce(i.price_override, v.selling_price) from catalog_productvariant v "
        "left join inventory_storeinventory i on i.variant_id=v.id and i.store_id=%s where v.id = any(%s)",
        (STORE_ID, list(ids)),
    )
    return {r[0]: (r[1], r[2]) for r in rows}


def stock(variant_id: int) -> tuple[int, int]:
    """(on_hand, reserved) at GGN-01."""
    rows = db_query(
        "select on_hand, reserved from inventory_storeinventory where store_id=%s and variant_id=%s",
        (STORE_ID, variant_id),
    )
    return rows[0] if rows else (0, 0)


def expected_bill(lines: dict[int, int], *, coupon_discount: Decimal = Decimal("0"), tip: Decimal = Decimal("0")) -> dict:
    """08 §6.2, independently: thresholds against item_total before the coupon; half-up 2dp."""
    if not lines:
        return {k: "0.00" for k in ("mrp_total", "item_total", "product_discount", "coupon_discount",
                                     "delivery_fee", "small_cart_fee", "handling_fee", "tip", "grand_total", "total_savings")}
    cfg, prices = pricing(), variant_prices(lines)
    mrp_total = sum((prices[v][0] * q for v, q in lines.items()), Decimal("0"))
    item_total = sum((prices[v][1] * q for v, q in lines.items()), Decimal("0"))
    coupon_discount = min(coupon_discount, item_total)
    delivery = Decimal("0") if item_total >= cfg["free_delivery_threshold"] else cfg["delivery_fee"]
    small = cfg["small_cart_fee"] if item_total < cfg["small_cart_threshold"] else Decimal("0")
    handling = cfg["handling_fee"]
    grand = item_total - coupon_discount + delivery + small + handling + tip
    return {
        "mrp_total": m(mrp_total),
        "item_total": m(item_total),
        "product_discount": m(mrp_total - item_total),
        "coupon_discount": m(coupon_discount),
        "delivery_fee": m(delivery),
        "small_cart_fee": m(small),
        "handling_fee": m(handling),
        "tip": m(tip),
        "grand_total": m(grand),
        "total_savings": m(mrp_total - item_total + coupon_discount),
    }
