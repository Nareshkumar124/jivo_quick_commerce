"""P7-TC-40 (QA stage 4, 2026-11-10, develop f8db671 incl. admin P7 6f92706): the Ops Console P7
screens through real HTTP, as each seeded staff role, compared with the service-level results
of the same day (`tools/p7_driver.py`, already verified against SQL oracles in test_p7.py).

Screens (05 §1.1, §2, §3, §4): dashboard order KPIs + alerts (`/ops/`, `/ops/dashboard/orders/`),
reports index / report page / CSV / async export + download (`/ops/reports/...`), the support
ticket console (`/ops/support/...`) and the read-only ratings admin (`/admin/orders/rating/`).

Sub-cases are named P7-TC-40a…f in the docstrings. Writes: only a QA customer's support tickets,
console replies/status/priority on them, and report exports of the QA staff session (Celery on
the QA broker). QA instance :8004 only.
"""

from __future__ import annotations

import html
import re
import time
from datetime import datetime, timedelta
from html.parser import HTMLParser
from zoneinfo import ZoneInfo

import httpx
import pytest

from conftest import login
from p3_admin import csrf, staff_login
from p4_support import CATALOG, FINANCE, MANAGER, OPS, QA02_MANAGER, STAFF, SUPER, SUPPORT
from p5_support import QA02_ID
from p7_support import Tickets, p7_op, p7_ops
from qa_support import QA_PHONES, db_query

IST = ZoneInfo("Asia/Kolkata")
ALL_ROLES = (SUPER, OPS, FINANCE, MANAGER, QA02_MANAGER, SUPPORT, STAFF, CATALOG)
REPORT_ROLES = {SUPER, OPS, FINANCE, MANAGER, QA02_MANAGER}  # reports.view_reports (05 §3)
SUPPORT_ROLES = {SUPER, OPS, SUPPORT}  # 05 §3 "Support tickets"
RATING_ROLES = {SUPER, OPS, SUPPORT, MANAGER, QA02_MANAGER}  # orders.view_rating (05 §2 Ratings)
ALL_REPORTS = {"sales_summary", "orders", "cancellations", "refunds", "cod_reconciliation", "product_sales",
               "inventory_stock", "inventory_movements", "gst_invoices", "gst_hsn_summary", "rider_earnings",
               "payouts"}
SALES_CATALOG = {"sales_summary", "orders", "cancellations", "refunds", "cod_reconciliation", "product_sales",
                 "inventory_stock", "inventory_movements"}
EXPECTED_INDEX = {SUPER: ALL_REPORTS, FINANCE: ALL_REPORTS, OPS: SALES_CATALOG, MANAGER: SALES_CATALOG,
                  QA02_MANAGER: SALES_CATALOG, CATALOG: {"product_sales", "inventory_stock", "inventory_movements"},
                  STAFF: set(), SUPPORT: set()}
HX = {"HX-Request": "true"}


def today() -> str:
    return datetime.now(IST).date().isoformat()


_SESSIONS: dict[str, httpx.Client] = {}


def staff(email: str) -> httpx.Client:
    """One signed-in client per role for the module (fewer logins: axes counts only failures)."""
    if email not in _SESSIONS:
        c = staff_login(email)
        c.get("/ops/")  # stamps the staff-session clock (05 §5)
        _SESSIONS[email] = c
    return _SESSIONS[email]


@pytest.fixture(scope="module", autouse=True)
def _close_sessions():
    yield
    for c in _SESSIONS.values():
        c.close()
    _SESSIONS.clear()


# --------------------------------------------------------------------------- tiny HTML readers


class _Table(HTMLParser):
    """Header cells and body rows of the first <table> (text only, entities decoded)."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.head: list[str] = []
        self.rows: list[list[str]] = []
        self._in: str | None = None
        self._cell: list[str] = []
        self._row: list[str] | None = None
        self._done = False

    def handle_starttag(self, tag, attrs):
        if self._done:
            return
        if tag == "tr":
            self._row = []
        elif tag in ("th", "td"):
            self._in, self._cell = tag, []

    def handle_endtag(self, tag):
        if self._done:
            return
        if tag in ("th", "td") and self._in:
            text = " ".join("".join(self._cell).split())
            (self.head if self._in == "th" else self._row).append(text)
            self._in = None
        elif tag == "tr" and self._row:
            self.rows.append(self._row)
            self._row = None
        elif tag == "table":
            self._done = True

    def handle_data(self, data):
        if self._in:
            self._cell.append(data)


def table(page: str) -> tuple[list[str], list[list[str]]]:
    p = _Table()
    p.feed(page)
    return p.head, p.rows


def kpi_cards(page: str) -> dict[str, str]:
    """{label: value} of the dashboard order KPI cards (data-testid="kpi-order")."""
    out = {}
    for block in page.split('data-testid="kpi-order"')[1:]:
        label = re.search(r'<span class="truncate">(.*?)</span>', block, re.S).group(1)
        value = re.search(r"data-kpi-value>(.*?)</div>", block, re.S).group(1)
        out[html.unescape(label.strip())] = html.unescape(" ".join(value.split()))
    return out


def alert_counts(page: str) -> dict[str, int]:
    return {k: int(n) for k, n in re.findall(
        r'data-alert="([a-z_]+)">.*?<span class="font-semibold">(\d+)</span>', page, re.S)}


def inr(value: str) -> str:
    """The console's money format (apps/ops_console/money.py: Indian grouping, 2 dp)."""
    from decimal import Decimal

    amount = Decimal(value)
    whole, _, frac = f"{abs(amount):.2f}".partition(".")
    if len(whole) > 3:
        head, tail = whole[:-3], whole[-3:]
        groups = []
        while len(head) > 2:
            groups.insert(0, head[-2:])
            head = head[:-2]
        if head:
            groups.insert(0, head)
        whole = ",".join(groups + [tail])
    return f"{'-' if amount < 0 else ''}₹{whole}.{frac}"


def refused(r: httpx.Response) -> bool:
    return r.status_code == 403 and r.headers.get("X-Ops-Refused") == "1"


# =========================================================================== dashboard (05 §1.1)


@pytest.mark.smoke
def test_p7_tc40a_dashboard_cards_roles_and_numbers():
    """P7-TC-40a 🔥 `/ops/` for every role: the order section only for the 05 §3 Reports roles; OPS
    filtered to QA-02 shows the service KPIs (orders, GMV, AOV, delivered, cancelled %, online
    riders, active orders, stock-outs, low stock) and alert counts; the QA-02 manager unfiltered
    = OPS on QA-02; the GGN-01 manager asking for QA-02 gets the filter error, no numbers; the
    order partial is a 403 for SUP/SS/CAT."""
    for who in ALL_ROLES:
        r = staff(who).get("/ops/")
        assert r.status_code == 200, (who, r.status_code)
        has_orders = 'data-testid="order-dashboard"' in r.text
        assert has_orders == (who in REPORT_ROLES), (who, has_orders)
    ops_page = staff(OPS).get("/ops/dashboard/orders/", params={"store": QA02_ID}, headers=HX)
    assert ops_page.status_code == 200
    cards = kpi_cards(ops_page.text)
    k = p7_op(op="kpis", **{"as": OPS}, store_id=QA02_ID)["result"]
    a = p7_op(op="alerts", **{"as": OPS}, store_id=QA02_ID)["result"]
    assert cards["Orders"] == str(k["orders"]) and cards["Delivered"] == str(k["delivered"]), (cards, k)
    assert cards["GMV"] == inr(k["gmv"]) and cards["AOV"] == inr(k["aov"]), (cards, k)
    assert cards["Cancelled"] == f"{k['cancelled']} ({k['cancelled_pct']}%)", (cards, k)
    for label, key in (("Online riders", "online_riders"), ("Active orders", "active_orders"),
                       ("Out of stock", "stock_outs"), ("Low stock", "low_stock")):
        assert cards[label] == str(k[key]), (label, cards[label], k[key])
    assert cards["SLA breaches"] == str(k["sla_breaches"]["total"]), (cards, k["sla_breaches"])
    shown = alert_counts(ops_page.text)
    expect = {"acceptance": a["awaiting_acceptance"]["count"], "no_rider": a["no_rider"]["count"],
              "low_stock": a["low_stock"]["count"], "cash_limit": a["riders_over_cash_limit"]["count"],
              "failed": a["failed_deliveries"]["count"]}
    for key, n in expect.items():
        assert shown.get(key, 0) == n, (key, shown, expect)
    # 05 §3 "own store": the QA-02 manager's unfiltered cards are OPS's QA-02 cards
    smq = staff(QA02_MANAGER).get("/ops/dashboard/orders/", headers=HX)
    assert smq.status_code == 200
    assert kpi_cards(smq.text) == cards, (kpi_cards(smq.text), cards)
    # GGN-01 manager asking for QA-02: the store is not a choice → filter error, no numbers
    sm = staff(MANAGER).get("/ops/dashboard/orders/", params={"store": QA02_ID}, headers=HX)
    assert sm.status_code == 200 and "Check the filters" in sm.text and kpi_cards(sm.text) == {}, sm.text[:300]
    for who in (SUPPORT, STAFF, CATALOG):
        assert refused(staff(who).get("/ops/dashboard/orders/", headers=HX)), who
    # a future day is refused by the form, not computed
    fut = (datetime.now(IST).date() + timedelta(days=1)).isoformat()
    r = staff(OPS).get("/ops/dashboard/orders/", params={"day": fut}, headers=HX)
    assert "Check the filters" in r.text and kpi_cards(r.text) == {}


# =========================================================================== reports (05 §3, §4)


@pytest.mark.smoke
def test_p7_tc40b_reports_index_role_matrix():
    """P7-TC-40b 🔥 `/ops/reports/`: SA/FIN 12 reports, OPS/SM/SMQ the 8 sales + catalog ones, CAT
    the 3 catalog ones, SS/SUP 403; a known report the role may not open → 403; unknown → 404."""
    for who in ALL_ROLES:
        r = staff(who).get("/ops/reports/")
        if not EXPECTED_INDEX[who]:
            assert refused(r), (who, r.status_code)
            continue
        assert r.status_code == 200, (who, r.status_code)
        listed = set(re.findall(r'data-report="([a-z_]+)"', r.text))
        assert listed == EXPECTED_INDEX[who], (who, sorted(listed ^ EXPECTED_INDEX[who]))
    assert refused(staff(CATALOG).get("/ops/reports/sales_summary/"))
    assert refused(staff(OPS).get("/ops/reports/payouts/"))
    assert refused(staff(SUPPORT).get("/ops/reports/orders/"))
    assert staff(SUPER).get("/ops/reports/no_such_report/").status_code == 404


@pytest.mark.smoke
def test_p7_tc40c_report_page_and_csv_equal_service():
    """P7-TC-40c 🔥 sales_summary for QA-02 today: the page table = the service rows ("" shown as
    "-"), the CSV download = the service CSV byte for byte (BOM, injection-safe writer); the QA-02
    manager unfiltered = OPS on QA-02; the GGN-01 manager on QA-02 → filter error and CSV 400;
    end < start, future end and > 366 days → filter error, never a table."""
    d = today()
    q = {"date_from": d, "date_to": d, "store": QA02_ID}
    out = p7_ops({"op": "run", "as": OPS, "key": "sales_summary", "store_id": QA02_ID, "start": d, "end": d},
                 {"op": "csv", "as": OPS, "key": "sales_summary", "store_id": QA02_ID, "start": d, "end": d},
                 {"op": "run", "as": OPS, "key": "orders", "store_id": QA02_ID, "start": d, "end": d})
    svc, svc_csv, svc_orders = out[0]["result"], out[1]["result"], out[2]["result"]
    page = staff(OPS).get("/ops/reports/sales_summary/", params=q)
    assert page.status_code == 200
    head, rows = table(page.text)
    assert len(head) == len(svc["columns"]) and len(rows) == len(svc["rows"]), (head, rows, svc)
    expect = [["-" if v == "" else str(v) for v in row] for row in svc["rows"]]
    assert rows == expect, (rows, expect)
    csv_r = staff(OPS).get("/ops/reports/sales_summary/", params={**q, "export": "csv"})
    assert csv_r.status_code == 200 and csv_r.headers["content-type"].startswith("text/csv")
    assert "attachment" in csv_r.headers.get("content-disposition", "")
    assert csv_r.content.startswith(b"\xef\xbb\xbf")
    assert csv_r.content.decode("utf-8") == svc_csv, "console CSV differs from the service CSV"
    # orders report (QA-02, today): row count equal to the service (first page of 50)
    o_page = staff(OPS).get("/ops/reports/orders/", params=q)
    _, o_rows = table(o_page.text)
    assert len(o_rows) == min(50, len(svc_orders["rows"])), (len(o_rows), len(svc_orders["rows"]))
    # store scope (05 §3 "own store")
    smq = staff(QA02_MANAGER).get("/ops/reports/sales_summary/", params={"date_from": d, "date_to": d})
    assert table(smq.text)[1] == expect, (table(smq.text)[1], expect)
    sm = staff(MANAGER).get("/ops/reports/sales_summary/", params=q)
    assert "Check the filters" in sm.text and table(sm.text)[1] == [], "GGN-01 manager read QA-02"
    sm_csv = staff(MANAGER).get("/ops/reports/sales_summary/", params={**q, "export": "csv"})
    assert sm_csv.status_code == 400 and not sm_csv.headers["content-type"].startswith("text/csv")
    # date validation
    day = datetime.now(IST).date()
    for bad in ({"date_from": d, "date_to": (day - timedelta(days=1)).isoformat()},
                {"date_from": d, "date_to": (day + timedelta(days=1)).isoformat()},
                {"date_from": (day - timedelta(days=400)).isoformat(), "date_to": d}):
        r = staff(OPS).get("/ops/reports/sales_summary/", params={**bad, "store": QA02_ID})
        assert r.status_code == 200 and "Check the filters" in r.text and table(r.text)[1] == [], bad


def test_p7_tc40d_async_export_and_download_scope():
    """P7-TC-40d export in background (POST + CSRF) → the export appears DONE in OPS's list with
    a download link → 302 to a signed private URL that serves the CSV; Finance asking for OPS's
    export id → refused; a POST without CSRF → 403; CAT exporting `orders` → 403."""
    d = today()
    c = staff(OPS)
    path = "/ops/reports/orders/"
    token = csrf(c, f"{path}?date_from={d}&date_to={d}&store={QA02_ID}")
    before = {x for (x,) in db_query("select id from reports_reportexport where requested_by_id="
                                      "(select id from accounts_user where email=%s)", (OPS,))}
    r = c.post(f"{path}export/", data={"date_from": d, "date_to": d, "store": QA02_ID,
                                       "query": f"date_from={d}&date_to={d}&store={QA02_ID}",
                                       "csrfmiddlewaretoken": token},
               headers={"Referer": f"{c.base_url}{path}"})
    assert r.status_code == 302 and r.headers["location"].startswith(path), (r.status_code, r.headers.get("location"))
    new_id = None
    for _ in range(60):
        ids = {x for (x,) in db_query("select id from reports_reportexport where requested_by_id="
                                       "(select id from accounts_user where email=%s)", (OPS,))}
        fresh = sorted(ids - before)
        if fresh:
            new_id = fresh[-1]
            st = db_query("select status, row_count from reports_reportexport where id=%s", (new_id,))[0]
            if st[0] in ("DONE", "FAILED"):
                break
        time.sleep(2)
    assert new_id, "no export row was created"
    status, rows = db_query("select status, row_count from reports_reportexport where id=%s", (new_id,))[0]
    assert status == "DONE", status
    page = c.get(path, params={"date_from": d, "date_to": d, "store": QA02_ID}).text
    assert f"/ops/reports/exports/{new_id}/download/" in page, "DONE export not listed with a link"
    dl = c.get(f"/ops/reports/exports/{new_id}/download/")
    assert dl.status_code == 302, dl.status_code
    signed = dl.headers["location"]
    assert "X-Amz-Signature" in signed or "Signature=" in signed, "download URL is not signed"
    body = httpx.get(signed, timeout=30)
    assert body.status_code == 200 and body.content.startswith(b"\xef\xbb\xbf"), body.status_code
    assert body.content.decode("utf-8").count("\n") >= rows, (rows, body.content[:100])
    unsigned = signed.split("?")[0]
    assert httpx.get(unsigned, timeout=30).status_code in (401, 403), "private export readable without a signature"
    fin = staff(FINANCE).get(f"/ops/reports/exports/{new_id}/download/")
    assert fin.status_code in (403, 404) and "location" not in fin.headers, fin.status_code
    nocsrf = c.post(f"{path}export/", data={"date_from": d, "date_to": d, "store": QA02_ID})
    assert nocsrf.status_code == 403
    cat = staff(CATALOG)
    tok = csrf(cat, "/ops/reports/product_sales/")
    assert refused(cat.post(f"{path}export/", data={"date_from": d, "date_to": d, "csrfmiddlewaretoken": tok},
                            headers={"Referer": f"{cat.base_url}{path}"}))


# =========================================================================== support console


@pytest.fixture(scope="module")
def a_ticket():
    a = login(QA_PHONES["a"])
    t = Tickets(a).create("OTHER", "QA stage 4 console ticket: please check.")
    assert t.status_code == 201, t.text
    return a, t.json()


@pytest.mark.smoke
def test_p7_tc40e_support_console_roles_and_reply(a_ticket):
    """P7-TC-40e 🔥 `/ops/support/`: SA/OPS/SUP open the queue and the ticket, FIN/SS/CAT/SM/SMQ get
    403 on list, detail and actions; SUP replies through the console (POST + CSRF) → IN_PROGRESS,
    the customer sees the staff message, SLA first response not late; OPS sets URGENT; an unknown
    action / ticket → 404; a CLOSED ticket shows no reply form and refuses a reply."""
    a, t = a_ticket
    tid = t["id"]
    for who in ALL_ROLES:
        c = staff(who)
        lst = c.get("/ops/support/")
        det = c.get(f"/ops/support/tickets/{tid}/")
        if who in SUPPORT_ROLES:
            assert lst.status_code == 200 and det.status_code == 200, (who, lst.status_code, det.status_code)
            assert f"TK-{tid:06d}" in det.text
        else:
            assert refused(lst) and refused(det), (who, lst.status_code, det.status_code)
    sup = staff(SUPPORT)
    detail = f"/ops/support/tickets/{tid}/"
    tok = csrf(sup, detail)
    fin = staff(FINANCE)
    assert fin.get(detail).status_code == 403
    r = sup.post(f"{detail}reply/", data={"body": "QA console reply: we are checking.", "status": "",
                                          "csrfmiddlewaretoken": tok}, headers={"Referer": f"{sup.base_url}{detail}"})
    assert r.status_code == 302 and r.headers["location"] == detail, (r.status_code, r.headers.get("location"))
    got = Tickets(a).get(tid).json()
    assert got["status"] == "IN_PROGRESS", got["status"]
    assert any(m.get("from_support") and "QA console reply" in m.get("body", "") for m in got["messages"]), got["messages"]
    page = sup.get(detail).text
    first = re.search(r'data-testid="sla-first">(.*?)</dd>', page, re.S).group(1)
    assert "late" not in first, first
    ops = staff(OPS)
    tok_o = csrf(ops, detail)
    r = ops.post(f"{detail}priority/", data={"priority": "URGENT", "csrfmiddlewaretoken": tok_o},
                 headers={"Referer": f"{ops.base_url}{detail}"})
    assert r.status_code == 302
    sla = p7_op(op="ticket_sla", ticket_id=tid)["result"]
    assert sla["priority"] == "URGENT", sla
    assert ops.post(f"{detail}explode/", data={"csrfmiddlewaretoken": tok_o},
                    headers={"Referer": f"{ops.base_url}{detail}"}).status_code == 404
    assert ops.get("/ops/support/tickets/999999999/").status_code == 404
    assert sup.post(f"{detail}reply/", data={"body": "no csrf"}).status_code == 403
    # CLOSED: no reply form; a forged reply is refused by the service with a message
    r = sup.post(f"{detail}status/", data={"status": "CLOSED", "csrfmiddlewaretoken": tok},
                 headers={"Referer": f"{sup.base_url}{detail}"})
    assert r.status_code == 302
    page = sup.get(detail).text
    assert 'data-testid="ticket-closed"' in page and 'data-testid="reply-form"' not in page
    n_before = len(Tickets(a).get(tid).json()["messages"])
    r = sup.post(f"{detail}reply/", data={"body": "QA reply on a closed ticket", "status": "",
                                          "csrfmiddlewaretoken": tok}, headers={"Referer": f"{sup.base_url}{detail}"})
    assert r.status_code == 302
    after = Tickets(a).get(tid).json()
    assert len(after["messages"]) == n_before and after["status"] == "CLOSED", after["status"]


def test_p7_tc40e2_support_sla_filter_matches_service():
    """P7-TC-40e2 the queue's SLA filter (`?sla=breached`) lists only tickets the service flags as
    breached (with_sla), each with the "SLA breached" badge; a fresh unbreached QA ticket is not
    in it."""
    sup = staff(SUPPORT)
    page = sup.get("/ops/support/tickets/", params={"sla": "breached"}, headers=HX).text
    numbers = [int(n) for n in re.findall(r">TK-(\d{6})<", page)]
    assert numbers, "no breached ticket listed (the shared DB has old unanswered QA tickets)"
    _, rows = table(page)
    assert rows and all("SLA breached" in row[-1] for row in rows), rows[:3]
    flags = p7_op(op="breached", **{"as": SUPPORT}, ids=numbers)["result"]["flags"]
    assert all(flags[str(n)] for n in numbers), {n: flags.get(str(n)) for n in numbers}
    a = login(QA_PHONES["a"])
    fresh = Tickets(a).create("OTHER", "QA stage 4 fresh ticket for the SLA filter.").json()["id"]
    page2 = sup.get("/ops/support/tickets/", params={"sla": "breached", "q": ""}, headers=HX).text
    assert f">TK-{fresh:06d}<" not in page2
    assert p7_op(op="breached", **{"as": SUPPORT}, ids=[fresh])["result"]["flags"][str(fresh)] is False


# =========================================================================== ratings admin (05 §2)


def _qa02_rating() -> tuple[int, str, int]:
    rows = db_query(
        "select r.id, o.order_number, r.user_id from orders_rating r join orders_order o on o.id=r.order_id "
        "join accounts_user u on u.id=r.user_id where o.store_id=%s and u.phone like '+9190000001%%' "
        "order by r.id desc limit 1", (QA02_ID,))
    if not rows:
        pytest.skip("no QA rating at QA-02 yet (run test_p7.py ratings first)")
    return rows[0]


@pytest.mark.smoke
def test_p7_tc40f_ratings_admin_roles_scope_readonly():
    """P7-TC-40f 🔥 `/admin/orders/rating/`: SA/OPS/SUP list and open a QA-02 rating; the GGN-01
    manager's list does not contain it and its detail is 404; the QA-02 manager opens it; CAT/
    FIN/SS 403; read-only for everyone (add / change POST / delete refused); the customer shows as
    "Customer <id>", never the phone; the low filter lists only ≤ 2 stars."""
    rid, number, uid = _qa02_rating()
    lst, det = "/admin/orders/rating/", f"/admin/orders/rating/{rid}/change/"
    for who in ALL_ROLES:
        c = staff(who)
        r1, r2 = c.get(lst), c.get(det)
        if who in (SUPER, OPS, SUPPORT, QA02_MANAGER):
            assert r1.status_code == 200 and number in r1.text, (who, r1.status_code)
            assert r2.status_code == 200 and f"Customer {uid}" in r2.text, (who, r2.status_code)
            assert QA_PHONES["a"] not in r1.text + r2.text and QA_PHONES["b"] not in r1.text + r2.text
            assert 'name="_save"' not in r2.text, f"{who}: rating detail has a Save button"
        elif who == MANAGER:
            assert r1.status_code == 200 and number not in r1.text, "GGN-01 manager lists a QA-02 rating"
            assert r2.status_code == 404, (who, r2.status_code)
        else:
            assert r1.status_code == 403 and r2.status_code == 403, (who, r1.status_code, r2.status_code)
    sa = staff(SUPER)
    assert sa.get("/admin/orders/rating/add/").status_code == 403
    tok = csrf(sa, lst)
    post = sa.post(det, data={"stars": 5, "csrfmiddlewaretoken": tok}, headers={"Referer": f"{sa.base_url}{det}"})
    assert post.status_code == 403, post.status_code
    assert sa.get(f"/admin/orders/rating/{rid}/delete/").status_code == 403
    low = sa.get(lst, params={"low": "1"}).text
    head, rows = table(low)
    if rows:
        col = [h.lower() for h in head].index("stars")
        assert all(int(row[col]) <= 2 for row in rows if row[col].isdigit()), rows[:5]


def test_p7_tc40g_ticket_text_escaped_in_console():
    """P7-TC-40g 09 (XSS): a customer ticket body with HTML/JS is shown escaped in the support
    console detail page (never as markup)."""
    a = login(QA_PHONES["a"])
    payload = 'QA xss probe <img src=x onerror=alert(1)> <script>alert("qa")</script> end'
    r = Tickets(a).create("OTHER", payload)
    assert r.status_code == 201, r.text
    tid = r.json()["id"]
    page = staff(SUPPORT).get(f"/ops/support/tickets/{tid}/").text
    assert "<img src=x onerror" not in page and '<script>alert("qa")' not in page
    assert "&lt;img src=x onerror=alert(1)&gt;" in page or "&lt;img src=x onerror" in page, "probe text missing"
