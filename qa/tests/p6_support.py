"""Phase 6 helpers: black-box WebSocket clients for the QA instance (06 §4), 2026-11-06.

Design: `qa/docs/01-test-plan.md` §10 and the P6 cases in `02-test-case-repository.md`.

- App sockets authenticate with the first message (or the `jivo.auth.<jwt>` subprotocol), never
  the URL. Tokens are never printed: assertion messages go through `qa_support.redact`.
- The ops feed uses a seeded staff session (`p3_admin.staff_login`) and an allowed Origin.
- Socket slots are Redis leases in the QA DB 5 (`jqc:1:ws:sockets:<user>`); `clear_socket_slots`
  drops only those keys, so a crashed earlier test cannot cause a false 4429.
"""

from __future__ import annotations

import asyncio
import json
from contextlib import asynccontextmanager
from typing import Any

import httpx
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed, InvalidStatus

from qa_support import APP_HEADERS, BASE_URL, _delete_matching, bearer, redact

WS_BASE = BASE_URL.replace("http://", "ws://", 1).replace("https://", "wss://", 1)
ORIGIN = BASE_URL  # http://127.0.0.1:8004 (in ALLOWED_HOSTS of config.settings.local)

STATUS_KEYS = {"order_id", "order_number", "store_id", "status", "payment_status", "eta_at", "updated_at"}
CREATED_KEYS = {"order_id", "order_number", "store_id", "status", "payment_method", "item_count",
                "grand_total", "placed_at", "eta_at"}


def run(coro):
    return asyncio.run(coro)


def clear_socket_slots() -> int:
    return _delete_matching("jqc:1:ws:sockets:*")


@asynccontextmanager
async def ws_open(path: str, **kw):
    """Open a socket on the QA instance (closed on exit, so its slot is released)."""
    ws = await connect(WS_BASE + path, open_timeout=10, close_timeout=3, max_size=2**20, **kw)
    try:
        yield ws
    finally:
        await ws.close()


async def recv(ws, timeout: float = 5.0) -> dict | None:
    """The next message as JSON, None on timeout. Raises ConnectionClosed when closed."""
    try:
        raw = await asyncio.wait_for(ws.recv(), timeout)
    except TimeoutError:
        return None
    return json.loads(raw)


async def until_closed(ws, timeout: float) -> tuple[int | None, list[dict]]:
    """Collect messages until the server closes (its close code) or `timeout` (None)."""
    msgs: list[dict] = []
    loop = asyncio.get_running_loop()
    end = loop.time() + timeout
    while True:
        remaining = end - loop.time()
        if remaining <= 0:
            return None, msgs
        try:
            raw = await asyncio.wait_for(ws.recv(), remaining)
        except TimeoutError:
            return None, msgs
        except ConnectionClosed as exc:
            return (exc.rcvd.code if exc.rcvd else None), msgs
        msgs.append(json.loads(raw) if isinstance(raw, str) else {"binary": len(raw)})


async def collect(ws, seconds: float) -> list[dict]:
    """Every message within `seconds` (stops early if the socket closes)."""
    _, msgs = await until_closed(ws, seconds)
    return msgs


async def auth(ws, token: Any) -> dict | None:
    await ws.send(json.dumps({"type": "auth", "token": token}))
    return await recv(ws, 8)


def assert_shape(msg: dict) -> None:
    assert set(msg) == {"type", "data", "sent_at"}, redact(json.dumps(msg))
    assert isinstance(msg["sent_at"], str) and msg["sent_at"].endswith("Z"), msg


# --------------------------------------------------------------------------- REST helpers


def orders_of(access: str, api: httpx.Client | None = None) -> list[dict]:
    c = api or httpx.Client(base_url=BASE_URL, timeout=30)
    r = c.get("/api/v1/orders/", params={"page_size": 50}, headers={**APP_HEADERS, **bearer(access)})
    assert r.status_code == 200, redact(r.text[:300])
    return r.json()["results"]


def staff_cookie(email: str) -> tuple[httpx.Client, str]:
    """A signed-in staff client (session stamped by an HTTP page) and its Cookie header."""
    from p3_admin import staff_login

    c = staff_login(email)
    c.get("/ops/")  # an HTTP request stamps the staff-session clock (05 §5)
    cookie = "; ".join(f"{k}={v}" for k, v in c.cookies.items())
    return c, cookie


async def ops_close_code(cookie: str | None, origin: str | None = ORIGIN, wait: float = 4.0):
    """('refused', http_status) if the handshake is refused, else (close_code or None, msgs)."""
    headers = {"Cookie": cookie} if cookie else {}
    kw = {"additional_headers": headers}
    if origin is not None:
        kw["origin"] = origin
    try:
        async with ws_open("/ws/ops/live/", **kw) as ws:
            await ws.send(json.dumps({"type": "ping"}))
            return await until_closed(ws, wait)
    except InvalidStatus as exc:
        return "refused", exc.response.status_code
