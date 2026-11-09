"""QA driver for the Phase 5 staff and system actions (rider KYC review, dispatch, returns).

Until the slice 5.4 Ops Console pages exist, the staff actions a test needs (approve a QA rider,
manual assign, unassign, retry dispatch, receive a return) and the system jobs it must trigger
on demand (`expire_offer`, `dispatch_order`, `dispatch_sweep`, `rider_heartbeat_check`) are run
through the backend services, exactly as the console and Celery would call them.

Runs inside the backend (cwd = <worktree>/backend, `uv run python <this file>`) with the QA
instance's environment (Redis DB 5/6/7, local settings), so anything it queues goes to the QA
broker (DB 7) only. It never writes to the DB directly.

Input: a JSON list of steps on stdin, each {"op": ..., "as": <staff email>, ...}.
Output: one JSON line per step: {"ok": bool, "error", "code", "message", "details", "result"}.

Safety: only QA numbers (+9190000001xx) may be touched. Any rider or order whose user is not a
QA number is refused before the service is called.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
for k, v in {
    "REDIS_URL": "redis://localhost:6380/5",
    "CHANNELS_REDIS_URL": "redis://localhost:6380/6",
    "CELERY_BROKER_URL": "redis://localhost:6380/7",
}.items():
    if os.environ.get(k) != v:
        sys.exit(f"refusing to run: {k} must be the QA Redis DB")

import django

django.setup()

from apps.core.exceptions import ApiError
from apps.delivery.models import Rider
from apps.orders.models import Order
from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied, ValidationError

QA_PREFIX = "+9190000001"
User = get_user_model()


def _qa_phone(user) -> bool:
    return str(getattr(user, "phone", "") or "").startswith(QA_PREFIX)


def rider_by_phone(phone: str) -> Rider:
    if not phone.startswith(QA_PREFIX):
        raise SystemExit("refusing: not a QA number")
    return Rider.objects.select_related("user").get(user__phone=phone)


def guard_order(order_id: int) -> Order | None:
    order = Order.objects.select_related("user").filter(pk=order_id).first()
    if order is not None and not _qa_phone(order.user):
        raise SystemExit(f"refusing: order {order_id} is not a QA customer's order")
    return order


def guard_rider_id(rider_id: int) -> Rider:
    rider = Rider.objects.select_related("user").get(pk=rider_id)
    if not _qa_phone(rider.user):
        raise SystemExit(f"refusing: rider {rider_id} is not a QA rider")
    return rider


def rider_state(rider: Rider) -> dict:
    rider.refresh_from_db()
    return {
        "rider_id": rider.pk,
        "status": rider.status,
        "is_online": rider.is_online,
        "home_store_id": rider.home_store_id,
        "cash_in_hand": str(rider.cash_in_hand),
        "cash_limit": str(rider.cash_limit),
    }


def task_state(order_id: int) -> dict:
    from apps.delivery.models import DeliveryTask

    task = DeliveryTask.objects.filter(order_id=order_id).first()
    if task is None:
        return {}
    return {
        "task_id": task.pk,
        "status": task.status,
        "rider_id": task.rider_id,
        "attempt_count": task.attempt_count,
        "pickup_attempts": task.pickup_attempts,
        "otp_attempts": task.otp_attempts,
    }


def run(step: dict) -> dict:
    op = step["op"]
    by = User.objects.get(email=step["as"]) if step.get("as") else None
    oid = step.get("order_id")
    if oid is not None:
        guard_order(oid)

    # ---------------------------------------------------------------- rider review (slice 5.1)
    if op == "activate":
        # Approve every PENDING required document, then the rider, home store `store_id`.
        from apps.delivery.services import kyc

        rider = rider_by_phone(step["phone"])
        for doc in rider.documents.filter(status="PENDING"):
            kyc.approve_document(doc.pk, by=by)
        rider.refresh_from_db()
        if rider.status == "PENDING_KYC":
            kyc.approve_rider(rider.pk, by=by, home_store_id=step["store_id"])
        elif rider.status == "ACTIVE" and rider.home_store_id != step["store_id"]:
            kyc.set_home_store(rider.pk, step["store_id"], by=by)
        return {"ok": True, "result": rider_state(rider)}
    if op == "rider_state":
        return {"ok": True, "result": rider_state(rider_by_phone(step["phone"]))}
    if op == "set_cash_limit":
        from apps.delivery.services import kyc

        rider = rider_by_phone(step["phone"])
        kyc.set_cash_limit(rider.pk, step["amount"], by=by)
        return {"ok": True, "result": rider_state(rider)}
    if op in ("suspend", "reinstate"):
        from apps.delivery.services import kyc

        rider = rider_by_phone(step["phone"])
        if op == "suspend":
            kyc.suspend_rider(rider.pk, by=by, reason=step.get("reason", "QA suspension test"))
        else:
            kyc.reinstate_rider(rider.pk, by=by)
        return {"ok": True, "result": rider_state(rider)}
    if op in ("approve_rider", "reject_rider", "set_home_store"):
        from apps.delivery.services import kyc

        rider = rider_by_phone(step["phone"])
        if op == "approve_rider":
            kyc.approve_rider(rider.pk, by=by, home_store_id=step["store_id"])
        elif op == "reject_rider":
            kyc.reject_rider(rider.pk, by=by, reason=step.get("reason", ""))
        else:
            kyc.set_home_store(rider.pk, step["store_id"], by=by)
        return {"ok": True, "result": rider_state(rider)}
    if op in ("approve_document", "reject_document", "document_number", "document_url"):
        # The rider's current document of `doc_type` (any status).
        from apps.delivery.services import kyc

        rider = rider_by_phone(step["phone"])
        doc = rider.documents.filter(doc_type=step["doc_type"]).order_by("-pk").first()
        if op == "approve_document":
            kyc.approve_document(doc.pk, by=by)
            return {"ok": True, "result": rider_state(rider)}
        if op == "reject_document":
            kyc.reject_document(doc.pk, by=by, note=step.get("note", ""))
            return {"ok": True, "result": rider_state(rider)}
        if op == "document_number":
            number = kyc.document_number(doc.pk, by=by)
            return {"ok": True, "result": {"len": len(number), "last4": number[-4:]}}
        url, expires = kyc.document_file_url(doc.pk, by=by)
        return {"ok": True, "result": {"url": url, "expires_at": expires}}
    if op == "force_offline":
        from apps.delivery.services import shifts

        rider = rider_by_phone(step["phone"])
        shifts.force_offline(rider.pk, by=by)
        return {"ok": True, "result": rider_state(rider)}

    # ---------------------------------------------------------------- dispatch (slice 5.3)
    if op == "manual_assign":
        from apps.delivery.services import dispatch

        rider = rider_by_phone(step["phone"])
        dispatch.manual_assign(oid, rider.pk, by=by)
        return {"ok": True, "result": task_state(oid)}
    if op == "unassign":
        from apps.delivery.services import dispatch

        dispatch.unassign(oid, by=by)
        return {"ok": True, "result": task_state(oid)}
    if op == "retry_dispatch":
        from apps.delivery.services import dispatch

        dispatch.retry_dispatch(oid, by=by)
        return {"ok": True, "result": task_state(oid)}
    if op == "dispatch_order":
        from apps.delivery.services import dispatch

        return {"ok": True, "result": {"outcome": dispatch.dispatch_order(oid), **task_state(oid)}}
    if op == "expire_offer":
        from apps.delivery.models import DeliveryOffer
        from apps.delivery.services import dispatch

        offer = DeliveryOffer.objects.select_related("task__order__user").get(pk=step["offer_id"])
        guard_order(offer.task.order_id)
        return {"ok": True, "result": {"outcome": dispatch.expire_offer(offer.pk)}}
    if op == "dispatch_sweep":
        from apps.delivery.services import dispatch

        return {"ok": True, "result": dispatch.dispatch_sweep()}
    if op == "heartbeat_check":
        from apps.delivery.tasks import rider_heartbeat_check

        return {"ok": True, "result": rider_heartbeat_check()}
    if op == "task_state":
        return {"ok": True, "result": task_state(oid)}

    # ---------------------------------------------------------------- returns (T14)
    if op == "receive_return":
        from apps.orders import store_ops

        damaged = {int(k): v for k, v in (step.get("damaged") or {}).items()}
        store_ops.receive_return(oid, by=by, damaged=damaged)
        return {"ok": True, "result": task_state(oid)}

    # ---------------------------------------------------------------- cash, payouts, unlocks (slice 5.4)
    if op == "record_deposit":
        from apps.delivery.services import cash

        rider = rider_by_phone(step["phone"])
        entry = cash.record_deposit(rider.pk, step["amount"], by=by, note=step.get("note", "QA deposit"),
                                    idempotency_key=step.get("key", ""))
        return {"ok": True, "result": {"entry_id": entry.pk, "balance_after": str(entry.balance_after),
                                       **rider_state(rider)}}
    if op == "day_report":
        from datetime import date as _d

        from apps.delivery.services import cash

        rep = cash.store_day_report(by, step["store_id"], _d.fromisoformat(step["day"]))
        return {"ok": True, "result": rep}
    if op == "create_payout":
        from datetime import date as _d

        from apps.delivery.services import payouts

        rider = rider_by_phone(step["phone"])
        payout = payouts.create_payout(rider.pk, _d.fromisoformat(step["start"]), _d.fromisoformat(step["end"]), by=by)
        return {"ok": True, "result": {"payout_id": payout.pk, "amount": str(payout.amount), "status": payout.status}}
    if op == "mark_paid":
        from apps.delivery.services import payouts

        payout = payouts.mark_paid(step["payout_id"], reference=step.get("reference", "QA-REF"), by=by)
        return {"ok": True, "result": {"payout_id": payout.pk, "status": payout.status}}
    if op in ("unlock_pickup", "unlock_otp"):
        from apps.delivery.services import ops as dops

        (dops.unlock_pickup if op == "unlock_pickup" else dops.unlock_delivery_otp)(oid, by=by)
        return {"ok": True, "result": task_state(oid)}
    if op == "lift_cod_block":
        from apps.delivery.services import ops as dops

        user = User.objects.get(phone=step["customer_phone"])
        if not _qa_phone(user):
            raise SystemExit("refusing: not a QA customer")
        return {"ok": True, "result": {"lifted": dops.lift_cod_block(user.pk, by=by)}}

    # ---------------------------------------------------------------- cleanup of a QA rider
    if op == "cleanup_rider":
        # End whatever the rider is doing so the next case starts idle and offline:
        # ASSIGNED/AT_STORE -> unassign; PICKED_UP/AT_CUSTOMER -> fail (WRONG_ADDRESS) and
        # receive the return; RETURNING -> receive the return; then force offline.
        from apps.delivery.services import shifts

        try:  # slice 5.3+; on a 5.1/5.2 build there are no tasks to end
            from apps.delivery.services import dispatch, tasks
        except ImportError:
            tasks = None
        rider = rider_by_phone(step["phone"])
        done = []
        task = tasks.active_task(rider) if tasks is not None else None
        if task is not None:
            guard_order(task.order_id)
            if task.status in ("ASSIGNED", "AT_STORE"):
                dispatch.unassign(task.order_id, by=by)
                done.append("unassigned")
            else:
                if task.status in ("PICKED_UP", "AT_CUSTOMER"):
                    tasks.fail(rider.user, task.pk, reason="WRONG_ADDRESS", note="QA cleanup")
                    done.append("failed")
                from apps.orders import store_ops

                store_ops.receive_return(task.order_id, by=by)
                done.append("returned")
        rider.refresh_from_db()
        if rider.is_online:
            shifts.force_offline(rider.pk, by=by)
            done.append("offline")
        if step.get("clear_cash", True) and rider.cash_in_hand > 0:
            # COD deliveries accumulate cash; without a deposit the rider reaches the cash limit
            # and stops getting COD offers (DL-61 b), which breaks later cases. Deposit it all
            # through the cash service (as the staff user in `as`), like ops would at day end.
            from apps.delivery.services import cash

            cash.record_deposit(rider.pk, str(rider.cash_in_hand), by=by, note="QA cleanup deposit")
            done.append("deposited")
            rider.refresh_from_db()
        return {"ok": True, "result": {"done": done, **rider_state(rider)}}
    raise SystemExit(f"unknown op {op}")


def main() -> None:
    steps = json.load(sys.stdin)
    for step in steps:
        try:
            out = run(step)
        except ApiError as exc:
            out = {
                "ok": False,
                "error": "ApiError",
                "code": exc.error_code.value,
                "message": str(exc.message),
                "details": exc.details,
            }
        except PermissionDenied as exc:
            out = {"ok": False, "error": "PermissionDenied", "message": str(exc)}
        except ValidationError as exc:
            out = {"ok": False, "error": type(exc).__name__, "message": "; ".join(exc.messages)}
        print(json.dumps(out, default=str), flush=True)


if __name__ == "__main__":
    main()
