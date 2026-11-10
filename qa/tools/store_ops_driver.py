"""QA driver for the Phase 4 store/ops services while the Ops Console is not merged (T-416 stage 1).

Runs inside the backend (cwd = <worktree>/backend, `uv run python <this file>`) with the QA
instance's environment (Redis DB 5/6/7, local settings), so the domain events and refund tasks it
queues go to the QA broker (DB 7) only. It calls the same services the console will call
(`apps.orders.store_ops`, `apps.payments.order_refunds`) as a seeded staff user; it never writes
to the DB directly.

Input: a JSON list of steps on stdin, each {"op": ..., "as": <staff email>, ...}.
Output: one JSON line per step: {"ok": bool, "error": <class>, "code", "message", "details",
"result": {...}}. Only QA customers' orders may be touched: the driver refuses any order whose
user phone is not a QA number (+9190000001xx).
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
for k, v in {
    "REDIS_URL": "redis://127.0.0.1:6380/5",
    "CHANNELS_REDIS_URL": "redis://127.0.0.1:6380/6",
    "CELERY_BROKER_URL": "redis://127.0.0.1:6380/7",
}.items():
    if os.environ.get(k) != v:
        sys.exit(f"refusing to run: {k} must be the QA Redis DB")

import django  # noqa: E402

django.setup()

from decimal import Decimal  # noqa: E402

from django.contrib.auth import get_user_model  # noqa: E402
from django.core.exceptions import PermissionDenied, ValidationError  # noqa: E402

from apps.core.exceptions import ApiError  # noqa: E402
from apps.orders import store_ops  # noqa: E402
from apps.orders.models import Order  # noqa: E402
from apps.payments import order_refunds  # noqa: E402

QA_PREFIX = "+9190000001"


def guard(order_id: int) -> None:
    order = Order.objects.select_related("user").filter(pk=order_id).first()
    if order is None:
        return  # the service decides (not found)
    phone = str(getattr(order.user, "phone", ""))
    if not phone.startswith(QA_PREFIX):
        raise SystemExit(f"refusing: order {order_id} is not a QA customer's order")


def order_state(order_id: int) -> dict:
    o = Order.objects.filter(pk=order_id).first()
    if o is None:
        return {}
    return {
        "status": o.status,
        "payment_status": o.payment_status,
        "grand_total": str(o.grand_total),
        "item_total": str(o.item_total),
        "amount_paid": str(o.amount_paid),
        "amount_refunded": str(o.amount_refunded),
        "pickup_code": o.pickup_code,
    }


def run(step: dict) -> dict:
    User = get_user_model()
    op = step["op"]
    by = User.objects.get(email=step["as"]) if step.get("as") else None
    oid = step.get("order_id")
    if oid is not None:
        guard(oid)
    if op == "accept":
        store_ops.accept_order(oid, by=by)
    elif op == "start_packing":
        store_ops.start_packing(oid, by=by)
    elif op == "packed":
        store_ops.mark_packed(oid, by=by)
    elif op == "unavailable":
        store_ops.mark_item_unavailable(oid, step["item_id"], unavailable=step["unavailable"], by=by)
    elif op == "cancel":
        store_ops.cancel_by_staff(oid, by=by, reason=step["reason"], note=step.get("note", ""))
    elif op == "manual_refund":
        r = order_refunds.manual_refund(oid, Decimal(step["amount"]), by=by, note=step.get("note", ""))
        return {"ok": True, "result": {"refund_id": r.pk, "amount": str(r.amount), **order_state(oid)}}
    elif op == "retry_refund":
        from apps.payments.models import Refund

        rf = Refund.objects.select_related("order__user").get(pk=step["refund_id"])
        guard(rf.order_id)
        r = order_refunds.retry_refund(step["refund_id"], by=by)
        return {"ok": True, "result": {"refund_id": r.pk, "key": r.idempotency_key, "status": r.status}}
    elif op == "sync_refund_status":
        return {"ok": True, "result": order_refunds.sync_refund_status()}
    elif op == "sla_alert":
        return {"ok": True, "result": store_ops.acceptance_sla_alert(oid)}
    elif op == "inward_qa02":
        # QA-02 (QA-only store, id 2) restock through the inventory service, as staff: P5 runs
        # commit stock at every pickup (T9), so the QA store runs dry. Never any other store.
        from apps.catalog.models import ProductVariant
        from apps.inventory.services import adjust_stock
        from apps.stores.models import DarkStore

        store = DarkStore.objects.get(pk=2)
        if store.code != "QA-02":
            raise SystemExit("refusing: store 2 is not QA-02")
        mv = adjust_stock(store=store, variant=ProductVariant.objects.get(pk=step["variant_id"]),
                          delta=int(step["qty"]), movement_type="INWARD", reason="QA P5 restock", actor=by)
        return {"ok": True, "result": {"movement": mv.pk}}
    elif op == "refundable":
        return {"ok": True, "result": str(order_refunds.refundable(Order.objects.get(pk=oid)))}
    else:
        raise SystemExit(f"unknown op {op}")
    return {"ok": True, "result": order_state(oid) if oid else {}}


def main() -> None:
    steps = json.load(sys.stdin)
    for step in steps:
        try:
            out = run(step)
        except ApiError as exc:
            out = {"ok": False, "error": "ApiError", "code": exc.error_code.value, "message": str(exc.message), "details": exc.details}
        except PermissionDenied as exc:
            out = {"ok": False, "error": "PermissionDenied", "message": str(exc)}
        except ValidationError as exc:
            out = {"ok": False, "error": type(exc).__name__, "message": "; ".join(exc.messages)}
        print(json.dumps(out, default=str), flush=True)


if __name__ == "__main__":
    main()
