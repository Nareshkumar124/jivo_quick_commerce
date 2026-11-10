"""Phase 4 helpers.

Stage 1 (2026-11-04): the Ops Console (admin P4) is not merged, so staff actions are driven
through the backend services by `qa/tools/store_ops_driver.py`, run inside the QA worktree's
backend with the QA instance environment (Redis 5/6/7, local settings). Only QA customers'
orders are accepted by the driver. Once the console merges, `Console` replaces these calls with
real HTTP posts (CSRF) and the service-level results become a cross-check.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from decimal import Decimal

from p3_support import money
from qa_support import QA_DIR, STORE_ID, db_query

BACKEND = Path(os.environ["QA_BACKEND_DIR"]) if os.environ.get("QA_BACKEND_DIR") else QA_DIR.parent / "backend"
DRIVER = QA_DIR / "tools" / "store_ops_driver.py"

STAFF = "store.staff@jivo.test"
MANAGER = "store.manager@jivo.test"
OPS = "ops@jivo.test"
SUPPORT = "support@jivo.test"
FINANCE = "finance@jivo.test"
SUPER = "superadmin@jivo.test"
# QA-only Store Manager scoped to QA-02 (PM-approved, created by QA through the admin 2026-11-09)
QA02_MANAGER = "qa02.manager@jivo.test"
CATALOG = "catalog@jivo.test"

_ENV = {
    "REDIS_URL": "redis://127.0.0.1:6380/5",
    "CHANNELS_REDIS_URL": "redis://127.0.0.1:6380/6",
    "CELERY_BROKER_URL": "redis://127.0.0.1:6380/7",
    "DJANGO_SETTINGS_MODULE": os.environ.get("QA_DJANGO_SETTINGS", "config.settings.local"),
    **({"PYTHONPATH": os.environ["QA_PYTHONPATH"]} if os.environ.get("QA_PYTHONPATH") else {}),
    "SMS_BACKEND": "apps.notifications.sms.ConsoleSmsBackend",
    "OTP_TEST_NUMBERS": "+919000000101:123456,+919000000102:123456,+919000000103:123456,+919000000104:123456,+919000000105:123456",
    "PYTHONIOENCODING": "utf-8",
}


def ops(*steps: dict, extra_env: dict | None = None) -> list[dict]:
    """Run staff/system steps through the backend services; one result dict per step.
    `extra_env` overrides settings for the driver process only (e.g. REFUND_STUCK_MINUTES=0)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(_ENV)
    env.update(extra_env or {})
    p = subprocess.run(
        ["uv", "run", "--quiet", "python", str(DRIVER)],
        input=json.dumps(list(steps)),
        cwd=BACKEND,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=300,
    )
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("{")]
    if p.returncode != 0 or len(lines) != len(steps):
        raise AssertionError(f"driver failed rc={p.returncode}: {p.stderr[-2000:]}")
    return [json.loads(ln) for ln in lines]


def op(**step) -> dict:
    return ops(step)[0]


def history(order_id: int) -> list[tuple]:
    return db_query(
        "select from_status, to_status, actor_type from orders_orderstatushistory where order_id=%s order by id",
        (order_id,),
    )


def audit_rows(order_id: int) -> list[tuple]:
    return db_query(
        "select action, actor_id from core_auditlog where object_type='orders.order' and object_id=%s order by id",
        (str(order_id),),
    )


def refunds(order_id: int) -> list[tuple]:
    return db_query(
        "select id, amount, status, reason, idempotency_key from payments_refund where order_id=%s order by id",
        (order_id,),
    )


def order_row(order_id: int) -> dict:
    cols = ["status", "payment_status", "mrp_total", "item_total", "product_discount", "coupon_discount",
            "delivery_fee", "small_cart_fee", "handling_fee", "tip", "grand_total", "amount_paid",
            "amount_refunded", "pickup_code", "cancel_reason", "cancelled_by_type"]
    row = db_query(f"select {', '.join(cols)} from orders_order where id=%s", (order_id,))[0]
    return dict(zip(cols, row))


def pricing_cfg() -> dict:
    row = db_query(
        "select delivery_fee, free_delivery_threshold, small_cart_fee, small_cart_threshold, handling_fee "
        "from stores_pricingconfig where store_id=%s",
        (STORE_ID,),
    )[0]
    return dict(zip(["delivery_fee", "free_delivery_threshold", "small_cart_fee", "small_cart_threshold", "handling_fee"], row))


def t8a_oracle(old: dict, lines: list[tuple[Decimal, Decimal, int]]) -> dict:
    """08 §6.3, independently of the server. `old` = order money before T8a (strings or
    Decimals); `lines` = (mrp, selling_price, units still coming) from the order's snapshot.
    Coupon kept and capped at the new item_total; each fee recalculated from the store's
    PricingConfig and capped at the order's old fee; tip unchanged."""
    cfg = pricing_cfg()
    mrp_total = sum((mrp * q for mrp, _, q in lines), Decimal("0"))
    item_total = sum((sp * q for _, sp, q in lines), Decimal("0"))
    coupon = min(money(old["coupon_discount"]), item_total)
    delivery = Decimal("0") if item_total >= cfg["free_delivery_threshold"] else cfg["delivery_fee"]
    small = cfg["small_cart_fee"] if item_total < cfg["small_cart_threshold"] else Decimal("0")
    handling = cfg["handling_fee"]
    delivery = min(delivery, money(old["delivery_fee"]))
    small = min(small, money(old["small_cart_fee"]))
    handling = min(handling, money(old["handling_fee"]))
    tip = money(old["tip"])
    grand = item_total - coupon + delivery + small + handling + tip
    return {
        "mrp_total": money(mrp_total),
        "item_total": money(item_total),
        "coupon_discount": money(coupon),
        "delivery_fee": money(delivery),
        "small_cart_fee": money(small),
        "handling_fee": money(handling),
        "tip": tip,
        "grand_total": money(grand),
        "refund": money(money(old["grand_total"]) - money(grand)),
    }


# --------------------------------------------------------------------------- QA worker control
# The QA Celery worker consumes only the QA broker (Redis DB 7). Stopping it lets a test hold a
# refund PENDING without a gateway answer (P4-TC-34/35); never touches the :8001 workers.

def _qa_worker_pids() -> list[int]:
    ps = (
        "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'celery.exe' -and "
        "($_.CommandLine -like '*worktrees?qa?backend*' -or $_.CommandLine -like '*qa-dev?backend*') -and $_.CommandLine -like '*worker*' } "
        "| ForEach-Object { $_.ProcessId }"
    )
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
    return [int(x) for x in out.split() if x.strip().isdigit()]


def stop_worker() -> None:
    for pid in _qa_worker_pids():
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)


# Threads pool (P5 stage 2): with --pool=solo the slow socket fan-out tasks (2-6 s each against the
# remote DB) queue ahead of auto-accept and dispatch countdowns. QA_WORKER_POOL=solo restores it.
_POOL = ("--pool=solo" if os.environ.get("QA_WORKER_POOL") == "solo"
         else f"--pool=threads --concurrency={os.environ.get('QA_WORKER_CONCURRENCY', '4')}")


def start_worker(log_name: str) -> None:
    """Start the QA worker detached through Git Bash `nohup` (a child of pytest would die with
    the test run on Windows and leave refunds queued)."""
    import time as _t

    if _qa_worker_pids():
        return
    envs = " ".join(f"{k}={v!r}" if " " in v else f"{k}='{v}'" for k, v in _ENV.items())
    log = (QA_DIR / "private" / "logs" / log_name).as_posix()
    cmd = (f"cd '{BACKEND.as_posix()}' && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD VIRTUAL_ENV; "
           f"{envs} nohup uv run celery -A config worker {_POOL} --without-heartbeat --without-mingle "
           f"--without-gossip --loglevel INFO >> '{log}' 2>&1 &")
    subprocess.run(["C:/Program Files/Git/bin/bash.exe", "-c", cmd], timeout=30)
    _t.sleep(12)
