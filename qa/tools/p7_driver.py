"""QA driver for the Phase 7 staff and system actions (reports, support staff side, staff
ratings, DPDP anonymisation of the QA deletion user).

The admin P7 screens (reports, ticket queue, ratings) are not merged yet, so the staff actions
a black-box test needs are run through the backend services, exactly as the Ops Console will
call them (`apps.reports.services`, `apps.support.services`, `apps.orders.ratings`), as the
seeded staff user named in `as`.

Runs inside the backend (cwd = <worktree>/backend, `uv run python <this file>`) with the QA
instance's environment (Redis DB 5/6/7, local settings), so anything it queues goes to the QA
broker (DB 7) only. It never writes to the DB directly.

Input: a JSON list of steps on stdin, each {"op": ..., "as": <staff email>, ...}.
Output: one JSON line per step: {"ok": bool, "error", "message", "result"}.

Safety: tickets, ratings and users touched must belong to QA numbers (+9190000001xx); the
anonymise op only accepts +919000000105 (QA user E, reserved for the deletion run) after the
user deleted the account through the API.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import date

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

from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied, ValidationError

from apps.core.exceptions import ApiError

QA_PREFIX = "+9190000001"
DELETION_USER = "+919000000105"
User = get_user_model()


def staff(email: str):
    return User.objects.get(email=email, is_staff=True)


def _d(value):
    return date.fromisoformat(value) if value else None


def _now(step):
    """The service clock for read-only evaluations: now + `now_offset_s` (default 0)."""
    from datetime import timedelta

    from django.utils import timezone

    return timezone.now() + timedelta(seconds=float(step.get("now_offset_s", 0)))


def guard_ticket(ticket_id: int):
    from apps.support.models import SupportTicket

    t = SupportTicket.objects.select_related("user").get(pk=ticket_id)
    if not str(t.user.phone or "").startswith(QA_PREFIX):
        raise SystemExit(f"refusing: ticket {ticket_id} is not a QA user's")
    return t


def run(step: dict) -> dict:
    op = step["op"]
    user = staff(step["as"]) if step.get("as") else None

    # ------------------------------------------------------------------ reports
    if op in ("available", "run", "csv", "export", "download"):
        from apps.reports import services as rs

        if op == "available":
            return {"ok": True, "result": [s.key for s in rs.available_reports(user)]}
        kw = {"start": _d(step.get("start")), "end": _d(step.get("end")), "store_id": step.get("store_id")}
        if op == "run":
            res = rs.run_report(user, step["key"], **kw)
            return {"ok": True, "result": {"columns": list(res.columns), "rows": res.rows,
                                           "truncated": res.truncated}}
        if op == "csv":
            data = rs.report_csv(user, step["key"], **kw)
            return {"ok": True, "result": data.decode("utf-8")}
        if op == "export":
            exp = rs.request_export(user, step["key"], **kw)
            exp = rs.generate_export(exp.pk) or exp
            exp.refresh_from_db()
            return {"ok": True, "result": {"id": exp.pk, "status": exp.status, "rows": exp.row_count,
                                           "error": exp.error}}
        if op == "download":
            url = rs.export_download_url(user, step["export_id"])
            return {"ok": True, "result": {"signed": "X-Amz-Signature" in url or "Signature" in url}}
    if op == "csv_probe":
        from apps.reports.services import _write_csv

        values = step["values"]
        data = _write_csv(("probe",), [[v] for v in values]).decode("utf-8")
        return {"ok": True, "result": data}

    # ------------------------------------------------------------------ support (staff side)
    if op == "staff_reply":
        from apps.support import services as ss

        guard_ticket(step["ticket_id"])
        msg = ss.staff_reply(user, step["ticket_id"], step["body"], status=step.get("status"))
        return {"ok": True, "result": {"message_id": msg.pk}}
    if op == "change_status":
        from apps.support import services as ss

        guard_ticket(step["ticket_id"])
        t = ss.change_status(user, step["ticket_id"], step["status"])
        return {"ok": True, "result": {"status": t.status}}
    if op == "ticket_sla":
        from apps.support import services as ss

        t = guard_ticket(step["ticket_id"])
        st = ss.sla_state(t)
        return {"ok": True, "result": {"priority": t.priority, "app": t.app,
                                       "first_response_due_at": t.first_response_due_at,
                                       "resolution_due_at": t.resolution_due_at,
                                       "state": {k: str(v) for k, v in st.items()}}}
    if op == "set_priority":
        from apps.support import services as ss

        guard_ticket(step["ticket_id"])
        t = ss.set_priority(user, step["ticket_id"], step["priority"])
        return {"ok": True, "result": {"priority": t.priority, "created_at": t.created_at,
                                       "first_response_due_at": t.first_response_due_at,
                                       "resolution_due_at": t.resolution_due_at}}
    if op == "sla_at":  # evaluate the SLA as of now + offset (service-level clock; nothing written)
        from apps.support import services as ss

        t = guard_ticket(step["ticket_id"])
        st = ss.sla_state(t, now=_now(step))
        return {"ok": True, "result": {k: (v if isinstance(v, bool) else str(v)) for k, v in st.items()}}
    if op == "breached":
        from apps.support import services as ss

        qs = ss.breached_tickets(user, now=_now(step)).filter(pk__in=step["ids"])
        listed = ss.with_sla(ss.staff_tickets(user).filter(pk__in=step["ids"]), now=_now(step))
        return {"ok": True, "result": {"breached": sorted(qs.values_list("pk", flat=True)),
                                       "flags": {str(t.pk): t.sla_breached for t in listed}}}

    # ------------------------------------------------------------------ dashboard (05 §1.1)
    if op in ("kpis", "alerts", "charts"):
        from apps.reports import dashboard

        kw = {"store_id": step.get("store_id")}
        if op == "kpis":
            res = dashboard.kpis(user, day=_d(step.get("day")), now=_now(step), **kw)
        elif op == "alerts":
            res = dashboard.alerts(user, now=_now(step), **kw)
        else:
            res = dashboard.charts(user, day=_d(step.get("day")), **kw)
        return {"ok": True, "result": res}
    if op == "staff_tickets":
        from apps.support import services as ss

        ids = list(ss.staff_tickets(user).filter(pk__in=step["ids"]).values_list("pk", flat=True))
        return {"ok": True, "result": ids}
    if op == "staff_attachment_url":
        from apps.support import services as ss

        url = ss.staff_attachment_url(user, step["key"])
        return {"ok": True, "result": {"has_url": bool(url)}}

    # ------------------------------------------------------------------ ratings (staff side)
    if op == "staff_ratings":
        from apps.orders import ratings

        rows = ratings.staff_ratings(user, store_id=step.get("store_id"))
        ids = list(rows.filter(order_id__in=step["order_ids"]).values_list("order_id", flat=True))
        return {"ok": True, "result": sorted(set(ids))}

    # ------------------------------------------------------------------ DPDP (QA user E only)
    if op == "anonymise":
        from apps.accounts.services.auth import anonymise_user

        phone = step["phone"]
        if phone != DELETION_USER:
            raise SystemExit("refusing: anonymise only runs on QA user E")
        u = User.objects.get(phone=phone)
        if u.deleted_at is None:
            raise SystemExit("refusing: the account was not deleted through the API")
        return {"ok": True, "result": {"user_id": u.pk, "anonymised": anonymise_user(u.pk)}}
    raise SystemExit(f"unknown op {op}")


def main() -> None:
    steps = json.load(sys.stdin)
    for step in steps:
        try:
            out = run(step)
        except ApiError as exc:
            out = {"ok": False, "error": "ApiError", "code": exc.error_code.value,
                   "message": str(exc.message), "details": exc.details}
        except PermissionDenied as exc:
            out = {"ok": False, "error": "PermissionDenied", "message": str(exc)}
        except ValidationError as exc:
            out = {"ok": False, "error": "ValidationError", "message": "; ".join(exc.messages)}
        print(json.dumps(out, default=str), flush=True)


if __name__ == "__main__":
    main()
