"""Phase 7 helpers (ratings, support tickets, reports, DPDP erasure), 2026-11-09.

Staff/system actions go through `qa/tools/p7_driver.py` (the admin P7 screens are not merged):
report runs and exports, staff replies and status changes, staff rating lists, and the
anonymisation of QA user E after an API account deletion.
"""

from __future__ import annotations

import json
import os
import struct
import subprocess
import time
import zlib

import httpx

from p4_support import _ENV, BACKEND
from p5_support import bring_to
from qa_support import APP_HEADERS, QA_DIR, RIDER_HEADERS, bearer, describe

P7_DRIVER = QA_DIR / "tools" / "p7_driver.py"
TICKETS = "/api/v1/support/tickets/"


def p7_ops(*steps: dict) -> list[dict]:
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(_ENV)
    for _ in range(3):
        p = subprocess.run(
            ["uv", "run", "--quiet", "python", str(P7_DRIVER)],
            input=json.dumps(list(steps)), cwd=BACKEND, env=env, capture_output=True,
            text=True, encoding="utf-8", timeout=600,
        )
        if p.returncode != 3221225794:
            break
        time.sleep(2)
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("{")]
    if p.returncode != 0 or len(lines) != len(steps):
        raise AssertionError(f"p7 driver failed rc={p.returncode}: {p.stderr[-2000:]}")
    return [json.loads(ln) for ln in lines]


def p7_op(**step) -> dict:
    return p7_ops(step)[0]


def deliver(shop, rider, method: str = "COD") -> dict:
    """Place at QA-02 and walk the order to DELIVERED with `rider` (online at QA-02)."""
    ctx = bring_to("ATC", shop=shop, rider=rider, method=method)
    task = rider.task().json()["task"]
    cod = {"mode": "cash", "amount": task["cod_amount_due"]} if method == "COD" else None
    r = rider.deliver(ctx["task_id"], ctx["otp"], cod)
    assert r.status_code == 200, describe(r)
    return ctx


def png_with_exif(marker: bytes = b"QAEXIFMARKER-GPS-28.47-77.04", pad: int = 0) -> bytes:
    """A valid 8x8 PNG with an eXIf chunk (and an optional uncompressed tEXt pad)."""
    raw = b"".join(b"\x00" + b"\x10\x20\x30" * 8 for _ in range(8))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    exif = b"MM\x00*\x00\x00\x00\x08\x00\x00" + marker
    body = chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0)) + chunk(b"eXIf", exif)
    if pad:
        body += chunk(b"tEXt", b"Comment\x00" + os.urandom(pad // 2).hex().encode()[:pad])
    return b"\x89PNG\r\n\x1a\n" + body + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


class Tickets:
    """Support ticket API for one session in one app."""

    def __init__(self, session, app: str = "customer"):
        self.session = session
        self.app = app

    @property
    def h(self) -> dict:
        return {**(RIDER_HEADERS if self.app == "rider" else APP_HEADERS), **bearer(self.session.access)}

    def _c(self) -> httpx.Client:
        from qa_support import BASE_URL

        return httpx.Client(base_url=BASE_URL, timeout=60)

    def list(self, **params) -> httpx.Response:
        with self._c() as c:
            return c.get(TICKETS, headers=self.h, params=params)

    def create(self, category: str = "OTHER", message: str = "QA P7 ticket: please help me.", **extra) -> httpx.Response:
        with self._c() as c:
            return c.post(TICKETS, headers=self.h, json={"category": category, "message": message, **extra})

    def get(self, tid: int) -> httpx.Response:
        with self._c() as c:
            return c.get(f"{TICKETS}{tid}/", headers=self.h)

    def reply(self, tid: int, message: str = "QA follow-up", keys: list[str] | None = None) -> httpx.Response:
        body = {"message": message}
        if keys is not None:
            body["attachment_keys"] = keys
        with self._c() as c:
            return c.post(f"{TICKETS}{tid}/messages/", headers=self.h, json=body)

    def upload(self, tid: int, content: bytes, name: str = "photo.png", mime: str = "image/png") -> httpx.Response:
        with self._c() as c:
            return c.post(f"{TICKETS}{tid}/attachments/", headers=self.h, files={"file": (name, content, mime)})
