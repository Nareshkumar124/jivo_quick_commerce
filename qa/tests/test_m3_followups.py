"""Run 3 on main (2026-11-16, main b6736cf): the follow-ups merged after run 2.

- P5-TC-133: the rider's customer-PII window (09 §3.2, 06 §3 "Customer PII window").
  Needs the instance started with a short window, e.g.
  ``QA_EXTRA_ENV="RIDER_CUSTOMER_PII_SECONDS=30" bash qa/tools/instance.sh start local`` and the
  same QA_EXTRA_ENV for pytest; it skips itself otherwise (the default window is 1 h).
- P7-TC-41: photos on ticket create (``POST /support/attachments/`` then ``attachment_keys`` on
  ``POST /support/tickets/``; 06 §2 "Photos on ticket create").

QA numbers and the QA-only store QA-02 only. QA instance :8004 only.
"""

from __future__ import annotations

import os
import time

import httpx
import pytest

from conftest import login
from p5_support import (  # noqa: F401 (fixtures)
    R1_PHONE, bring_to, p5_shop_a, png_bytes, qa_worker, r1, rider_id_of, task_row,
)
from p7_support import TICKETS, Tickets, png_with_exif
from qa_support import BASE_URL, QA_PHONES, assert_error, clear_throttle, db_query, describe, validate_response

EXTRA = dict(kv.split("=", 1) for kv in os.environ.get("QA_EXTRA_ENV", "").split() if "=" in kv)
PII_SECONDS = int(EXTRA.get("RIDER_CUSTOMER_PII_SECONDS", "3600"))
PII_FIELDS = ("custom_label", "receiver_name", "receiver_phone", "house", "building_street", "landmark")


# =========================================================================== P5-TC-133 PII window


@pytest.mark.p5_53
@pytest.mark.skipif(PII_SECONDS > 120, reason="needs RIDER_CUSTOMER_PII_SECONDS <= 120 on the instance (QA_EXTRA_ENV)")
def test_p5_tc133_rider_customer_pii_window(r1, p5_shop_a):
    """P5-TC-133 (09 §3.2; 06 §3): R1 delivers a COD order. Inside the window an idempotent replay
    of `deliver/` returns the full drop address (receiver name and phone). After the window the
    same replay keeps the same field set, with name, phone and street fields and the note blank and
    lat/lng rounded to 2 decimals. The history list and detail never carry the customer's name,
    phone or address."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    tid = ctx["task_id"]
    body = r1.task().json()["task"]
    full = dict(body["customer_address"])
    assert full.get("receiver_phone") and full.get("house"), "fixture address lacks phone/house"
    secrets_ = [v for k, v in full.items() if k in PII_FIELDS and isinstance(v, str) and len(v) >= 4]
    cod = {"mode": "cash", "amount": body["cod_amount_due"]}
    r = r1.deliver(tid, ctx["otp"], cod)
    assert r.status_code == 200, describe(r)
    assert r.json()["customer_address"] == full, "inside the window the address must be in full"
    t_end = time.monotonic()
    replay = r1.deliver(tid, ctx["otp"], cod)
    assert replay.status_code == 200, describe(replay)
    assert replay.json()["customer_address"]["receiver_phone"] == full["receiver_phone"]
    time.sleep(max(0.0, PII_SECONDS + 3 - (time.monotonic() - t_end)))
    late = r1.deliver(tid, ctx["otp"], cod)
    assert late.status_code == 200, describe(late)
    validate_response(late, "rider_tasks_deliver", strict=False)
    addr = late.json()["customer_address"]
    print("TC-133 after the window:", {k: addr.get(k) for k in (*PII_FIELDS, "lat", "lng", "pincode")})
    assert set(addr) == set(full), (set(addr) ^ set(full))
    for f in PII_FIELDS:
        if f in full:
            assert addr[f] == "", (f, "not blanked")
    for f in ("lat", "lng"):
        if isinstance(full.get(f), int | float):
            assert addr[f] == round(float(full[f]), 2), (f, addr[f])
    assert late.json()["instructions"]["note"] == ""
    hist = r1.get("tasks/history/")
    det = r1.get(f"tasks/history/{tid}/")
    assert hist.status_code == 200 and det.status_code == 200, (hist.status_code, det.status_code)
    for resp in (hist, det):
        text = resp.text
        leaked = [v for v in secrets_ if v in text]
        assert not leaked, ("history carries PII", len(leaked))
        assert "customer_address" not in text
    cur = r1.task().json()
    assert full["receiver_phone"] not in str(cur.get("recent_task"))


# =========================================================================== P7-TC-41 photos on create


def _upload_unbound(t: Tickets, content: bytes, name: str = "photo.png", mime: str = "image/png") -> httpx.Response:
    with httpx.Client(base_url=BASE_URL, timeout=60) as c:
        return c.post("/api/v1/support/attachments/", headers=t.h, files={"file": (name, content, mime)})


def _ticket_count(phone: str) -> int:
    return db_query("select count(*) from support_supportticket t join accounts_user u on u.id=t.user_id "
                    "where u.phone=%s", (phone,))[0][0]


@pytest.mark.smoke
def test_p7_tc41_photos_on_ticket_create():
    """P7-TC-41 🔥 (06 §2, P8 follow-up): A uploads two photos with no ticket (201 {key, url}, WebP,
    no EXIF, signed); creates a ticket with both keys → 201 with ONE message carrying both photos.
    Refused keys (already used; B's unbound key; 4 keys; unknown key) → 400 details.attachment_keys
    and no ticket is created. An unbound key also works on a reply. Unauthenticated upload → 401."""
    for scope in ("support_tickets_create", "support_messages", "support_attachments"):
        clear_throttle(scope)
    ta, tb = Tickets(login(QA_PHONES["a"])), Tickets(login(QA_PHONES["b"]))
    with httpx.Client(base_url=BASE_URL, timeout=30) as c:
        anon = c.post("/api/v1/support/attachments/", files={"file": ("p.png", png_bytes(), "image/png")})
    assert anon.status_code == 401, describe(anon)
    u1 = _upload_unbound(ta, png_with_exif())
    assert u1.status_code == 201, describe(u1)
    validate_response(u1, "support_attachments_create")
    u2 = _upload_unbound(ta, png_bytes())
    k1, k2 = u1.json()["key"], u2.json()["key"]
    raw = httpx.get(u1.json()["url"], timeout=30)
    assert raw.status_code == 200 and raw.content[8:12] == b"WEBP" and b"QAEXIFMARKER" not in raw.content
    assert httpx.get(u1.json()["url"].split("?")[0], timeout=30).status_code in (401, 403)
    bad = _upload_unbound(ta, b"not an image", "x.txt", "text/plain")
    assert bad.status_code == 400, describe(bad)

    before = _ticket_count(QA_PHONES["a"])
    t = ta.create("OTHER", "QA P7-TC-41 ticket with photos", attachment_keys=[k1, k2])
    assert t.status_code == 201, describe(t)
    validate_response(t, "support_tickets_create")
    msgs = t.json()["messages"]
    assert len(msgs) == 1, msgs
    assert sorted(a["key"] for a in msgs[0]["attachments"]) == sorted([k1, k2]), msgs[0]
    tid = t.json()["id"]
    assert db_query("select count(*) from support_ticketattachment where key in (%s,%s) and ticket_id=%s",
                    (k1, k2, tid))[0][0] == 2
    assert _ticket_count(QA_PHONES["a"]) == before + 1

    # refusals: no ticket is created
    kb = _upload_unbound(tb, png_bytes()).json()["key"]
    ka3, ka4, ka5, ka6 = (_upload_unbound(ta, png_bytes()).json()["key"] for _ in range(4))
    cases = {
        "used": [k1],
        "other user's": [kb],
        "four keys": [ka3, ka4, ka5, ka6],
        "unknown": ["0" * 32],
    }
    for label, keys in cases.items():
        n = _ticket_count(QA_PHONES["a"])
        err = assert_error(ta.create("OTHER", f"QA P7-TC-41 refused ({label})", attachment_keys=keys),
                           400, "VALIDATION_ERROR")
        assert "attachment_keys" in err["details"], (label, err)
        assert _ticket_count(QA_PHONES["a"]) == n, f"{label}: a ticket was created"
    # B cannot claim A's unbound key either, and A's refused keys stay usable
    err = assert_error(tb.create("OTHER", "QA P7-TC-41 B claims A's key", attachment_keys=[ka3]),
                       400, "VALIDATION_ERROR")
    assert "attachment_keys" in err["details"]
    # an unbound key on a reply
    rep = ta.reply(tid, "QA P7-TC-41 reply with an unbound photo", [ka3])
    assert rep.status_code == 201, describe(rep)
    assert [a["key"] for a in rep.json()["messages"][-1]["attachments"]] == [ka3]
    # the old flow still works: create without keys, upload to the ticket, reply
    t2 = ta.create("OTHER", "QA P7-TC-41 old flow")
    assert t2.status_code == 201 and len(t2.json()["messages"]) == 1
    k_old = ta.upload(t2.json()["id"], png_bytes()).json()["key"]
    assert ta.reply(t2.json()["id"], "QA old flow photo", [k_old]).status_code == 201
    # B sees neither ticket
    assert tb.get(tid).status_code == 404
    _ = TICKETS
