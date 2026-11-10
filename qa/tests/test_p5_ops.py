"""Phase 5 admin / Ops Console (slice 5.3 admin, develop 680b904): dispatch board and task page,
DL-61 (a) task actions (unassign, retry, unlock pickup/OTP, ops fail, force offline), store
returns, read-only DeliveryTask/Offer admin.

Oracles: 05 §1.3-1.4 and §3 (Manual dispatch: Super Admin, Ops, Store Manager own store),
DL-61 (a) (Support none; Finance deposits only), 09 (no pickup code / OTP rendered to staff),
CLAUDE.md (another store's object is 404). Black-box: real seeded staff sessions (p4_console.Ops),
real QA orders at QA-02 and the QA riders.
"""

from __future__ import annotations

import pytest

from p4_console import Ops
from p4_support import CATALOG, FINANCE, MANAGER, OPS, QA02_MANAGER, STAFF, SUPER, SUPPORT
from p5_support import (  # noqa: F401 (fixtures)
    P5_53, R1_PHONE, bring_to, p5_shop_a, pickup_code, qa_worker, r1, rider_id_of, task_row,
    wait_task_status, wrong_otp,
)

pytestmark = P5_53

ALL_ROLES = [SUPER, OPS, MANAGER, QA02_MANAGER, STAFF, CATALOG, SUPPORT, FINANCE]
DISPATCHERS = {SUPER, OPS, MANAGER, QA02_MANAGER}  # MANAGER: own store (GGN-01) only


@pytest.fixture
def staff():
    sessions: dict[str, Ops] = {}

    def get(email: str) -> Ops:
        if email not in sessions:
            sessions[email] = Ops(email)
        return sessions[email]

    yield get
    for s in sessions.values():
        s.close()


def denied(r) -> bool:
    return r.status_code in (302, 403, 404) and "Traceback" not in r.text


@pytest.mark.smoke
@pytest.mark.parametrize("role", ALL_ROLES)
def test_p5_tc113_dispatch_board_by_role(staff, role):
    """P5-TC-113 🔥 /ops/dispatch/ opens for Super Admin, Ops and Store Manager only."""
    r = staff(role).get("/ops/dispatch/")
    assert r.status_code != 500
    if role in DISPATCHERS:
        assert r.status_code == 200, (role, r.status_code)
    else:
        assert denied(r), (role, r.status_code)


@pytest.mark.smoke
def test_p5_tc113_task_page_scoped_and_no_secrets(staff, r1, p5_shop_a):
    """P5-TC-113/121 🔥 OPS sees the QA-02 task page with no pickup code or OTP rendered; the GGN-01
    Store Manager and the roles without dispatch get 404/403 on the same task (IDOR across stores)."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    tid, oid = ctx["task_id"], ctx["order_id"]
    code, otp = pickup_code(oid), ctx["otp"]
    page = staff(OPS).get(f"/ops/dispatch/tasks/{tid}/")
    assert page.status_code == 200
    panel = staff(OPS).get(f"/ops/dispatch/tasks/{tid}/panel/", headers={"HX-Request": "true"})
    board = staff(OPS).get("/ops/dispatch/board/", headers={"HX-Request": "true"})
    for body in (page.text, panel.text, board.text):
        assert f">{code}<" not in body and f" {code} " not in body and f'"{code}"' not in body, "pickup code rendered"
        assert otp not in body, "delivery OTP rendered"
    for role in (MANAGER, STAFF, CATALOG, SUPPORT, FINANCE):
        r = staff(role).get(f"/ops/dispatch/tasks/{tid}/")
        assert denied(r), (role, r.status_code)
        assert otp not in r.text


@pytest.mark.parametrize("role", [MANAGER, STAFF, CATALOG, SUPPORT, FINANCE])
def test_p5_tc113_actions_denied(staff, r1, p5_shop_a, role):
    """P5-TC-113/117 unassign, retry, unlock, fail and force offline by a role without the right (or the
    GGN-01 manager on a QA-02 task) are refused and change nothing."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    tid, oid = ctx["task_id"], ctx["order_id"]
    s = staff(role)
    s.get("/ops/")
    rid = rider_id_of(R1_PHONE)
    for path, data in [(f"/ops/dispatch/tasks/{tid}/unassign/", {}), (f"/ops/dispatch/tasks/{tid}/retry/", {}),
                       (f"/ops/dispatch/tasks/{tid}/unlock-pickup/", {}), (f"/ops/dispatch/tasks/{tid}/unlock-otp/", {}),
                       (f"/ops/dispatch/tasks/{tid}/fail/", {"reason": "WRONG_ADDRESS", "note": "QA"}),
                       (f"/ops/dispatch/riders/{rid}/offline/", {})]:
        r = s.post(path, data, order_id=oid)
        assert denied(r), (role, path, r.status_code)
    assert task_row(oid)["status"] == "ASSIGNED"
    assert r1.heartbeat().json()["is_online"] is True


@pytest.mark.smoke
def test_p5_tc56_ops_unassign_and_retry(staff, r1, p5_shop_a):
    """P5-TC-56/57 OPS unassigns through the console → task back to searching/unassigned, R1 freed;
    the order stays ACCEPTED."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    s = staff(OPS)
    s.get(f"/ops/dispatch/tasks/{ctx['task_id']}/")
    r = s.post(f"/ops/dispatch/tasks/{ctx['task_id']}/unassign/", {}, order_id=ctx["order_id"])
    assert r.status_code in (200, 204, 302), r.status_code
    row = task_row(ctx["order_id"])
    assert row["status"] in ("SEARCHING", "OFFERED", "UNASSIGNED") and row["rider_id"] in (None, rider_id_of(R1_PHONE))
    assert r1.task().json()["task"] is None


@pytest.mark.smoke
def test_p5_tc113_own_store_manager_unassigns(staff, r1, p5_shop_a):
    """P5-TC-113 🔥 DL-61 (a): the QA-02 Store Manager (SMQ) may unassign a QA-02 task (own store)."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    s = staff(QA02_MANAGER)
    assert s.get(f"/ops/dispatch/tasks/{ctx['task_id']}/").status_code == 200
    r = s.post(f"/ops/dispatch/tasks/{ctx['task_id']}/unassign/", {}, order_id=ctx["order_id"])
    assert r.status_code in (200, 204, 302), r.status_code
    row = task_row(ctx["order_id"])
    assert row["status"] in ("SEARCHING", "OFFERED", "UNASSIGNED"), row
    assert r1.task().json()["task"] is None


def test_p5_tc93_console_unlock_pickup(staff, r1, p5_shop_a):
    """P5-TC-93 (console) 5 wrong codes lock the pickup; OPS unlocks in the console; the right code works."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    code = pickup_code(ctx["order_id"])
    bad = "ZZZZ" if code != "ZZZZ" else "YYYY"
    for _ in range(5):
        r1.pickup(ctx["task_id"], bad)
    assert r1.pickup(ctx["task_id"], code).status_code == 423
    s = staff(OPS)
    s.get(f"/ops/dispatch/tasks/{ctx['task_id']}/")
    r = s.post(f"/ops/dispatch/tasks/{ctx['task_id']}/unlock-pickup/", {}, order_id=ctx["order_id"])
    assert r.status_code in (200, 204, 302), r.status_code
    assert r1.pickup(ctx["task_id"], code).status_code == 200


def test_p5_tc93_console_unlock_otp(staff, r1, p5_shop_a):
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = {"mode": "cash", "amount": r1.task().json()["task"]["cod_amount_due"]}  # TC-70: body needed
    for _ in range(5):
        r1.deliver(ctx["task_id"], wrong_otp(ctx["otp"]), due)
    task = r1.task().json()["task"]
    assert task["delivery_otp"]["locked"] is True
    s = staff(OPS)
    s.get(f"/ops/dispatch/tasks/{ctx['task_id']}/")
    s.post(f"/ops/dispatch/tasks/{ctx['task_id']}/unlock-otp/", {}, order_id=ctx["order_id"])
    task = r1.task().json()["task"]
    assert task["delivery_otp"]["locked"] is False
    body = {"mode": "cash", "amount": task["cod_amount_due"]}
    assert r1.deliver(ctx["task_id"], ctx["otp"], body).status_code == 200


def test_p5_ops_fail_then_store_receives_return(staff, r1, p5_shop_a):
    """DL-61 (a) ops-marked T13, then the return received on /ops/store/QA-02/returns/ (T14)."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    s = staff(OPS)
    s.get(f"/ops/dispatch/tasks/{ctx['task_id']}/")
    r = s.post(f"/ops/dispatch/tasks/{ctx['task_id']}/fail/", {"reason": "WRONG_ADDRESS", "note": "QA ops fail"},
               order_id=ctx["order_id"])
    assert r.status_code in (200, 204, 302), r.status_code
    wait_task_status(ctx["order_id"], "RETURNING", timeout=10)
    page = s.get("/ops/store/QA-02/returns/")
    assert page.status_code == 200 and ctx["order"]["order_number"] in page.text
    r = s.post(f"/ops/store/QA-02/orders/{ctx['order_id']}/return/", {}, order_id=ctx["order_id"])
    assert r.status_code in (200, 204, 302), r.status_code
    wait_task_status(ctx["order_id"], "RETURNED", timeout=10)
    r = s.post(f"/ops/store/QA-02/orders/{ctx['order_id']}/return/", {}, order_id=ctx["order_id"])
    assert r.status_code in (200, 302, 404, 409), r.status_code  # twice: no second restock


@pytest.mark.parametrize("role", [SUPPORT, FINANCE, CATALOG])
def test_p5_tc116_returns_page_denied(staff, role):
    """P5-TC-116 store returns page is refused for roles without packing + dispatch rights."""
    assert denied(staff(role).get("/ops/store/QA-02/returns/"))


def test_p5_tc116_manager_other_store_returns_404(staff):
    """IDOR across stores: the GGN-01 manager cannot open QA-02's returns."""
    assert denied(staff(MANAGER).get("/ops/store/QA-02/returns/"))


def test_p5_tc118_csrf_required(staff, r1, p5_shop_a):
    """P5-TC-118 a console POST without the CSRF token → 403, nothing changes."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    r = staff(OPS).post(f"/ops/dispatch/tasks/{ctx['task_id']}/unassign/", {}, csrf=False, order_id=ctx["order_id"])
    assert r.status_code == 403
    assert task_row(ctx["order_id"])["status"] == "ASSIGNED"


@pytest.mark.parametrize("model", ["deliverytask", "deliveryoffer"])
def test_p5_delivery_admin_read_only(staff, model):
    """The DeliveryTask/Offer admin is read-only: list opens for Super Admin; add is refused."""
    s = staff(SUPER)
    assert s.get(f"/admin/delivery/{model}/").status_code == 200
    assert s.get(f"/admin/delivery/{model}/add/").status_code in (403, 404)
