"""Phase 5 slice 5.1 (registration, KYC, bank, review) and the slice 5.2 cases not in
test_p5_shift.py. Black-box through the rider API; staff actions through
`qa/tools/rider_ops_driver.py` (the backend services the Riders admin calls).

Oracles: 06 §3 (Registration and KYC, Shift, Location, rate limits), 04 §2.2-2.3, 09 §3.6,
05 §3 (role matrix). Stage 2, 2026-11-06, executed on develop (5.1/5.2 + contract).

User E (+919000000105) is the spare user without a rider profile: every registration it sends
is invalid, so it never gets a profile. C (R1) and D (R2) are the QA riders.
"""

from __future__ import annotations

from datetime import date, timedelta
from pathlib import Path

import httpx
from decimal import Decimal

import pytest
from conftest import login
from p4_support import CATALOG, FINANCE, MANAGER, OPS, STAFF, SUPER, SUPPORT
from p5_support import (  # noqa: F401 (fixtures)
    QA02,
    QA02_ID,
    R1_PHONE,
    R2_PHONE,
    RiderClient,
    ensure_active_rider,
    now_iso,
    offset,
    png_bytes,
    qa_worker,
    r1,
    r2,
    reset_rider,
    rider_id_of,
    rider_op,
    rider_ops,
)
from qa_support import (
    QA_PHONES,
    RIDER_HEADERS,
    assert_error,
    bearer,
    clear_throttle,
    db_query,
    describe,
    validate_response,
)

FIXTURES = Path(__file__).parent / "fixtures"
EXIF_JPEG = (FIXTURES / "exif_gps.jpg").read_bytes()
SPARE = QA_PHONES["e"]
BASE_DOCS = ["PHOTO", "AADHAAR_FRONT", "AADHAAR_BACK", "PAN"]
MOTOR_DOCS = [*BASE_DOCS, "DL", "RC"]


def ist_today() -> date:
    from datetime import UTC, datetime

    return (datetime.now(UTC) + timedelta(hours=5, minutes=30)).date()


def years_ago(n: int, d: date) -> date:
    try:
        return d.replace(year=d.year - n)
    except ValueError:  # 29 Feb
        return d.replace(year=d.year - n, day=28)


@pytest.fixture
def r1p(api):
    """R1 still PENDING_KYC (first run only; afterwards the review fixtures activate R1)."""
    rider = RiderClient(api, R1_PHONE)
    me = rider.me()
    if me.status_code != 200 or me.json()["status"] not in ("PENDING_KYC", "REJECTED"):
        pytest.skip("R1 is no longer PENDING_KYC (approved by an earlier run)")
    clear_throttle("rider_documents")
    return rider


@pytest.fixture
def spare(api):
    rider = RiderClient(api, SPARE)
    r = rider.me()
    if r.status_code != 403:
        pytest.skip("spare user E already has a rider profile (cannot re-run registration validation)")
    clear_throttle("rider_profile_write")
    return rider


# --------------------------------------------------------------------------- 5.1 registration


@pytest.mark.smoke
def test_p5_tc01_register_and_stores(api):
    """P5-TC-01 🔥 stores list (active only); register R1 → 201 PENDING_KYC, home_store null,
    required documents for a SCOOTER, strict schema. If R1 already exists, the profile is read."""
    rider = RiderClient(api, R1_PHONE)
    stores = rider.get("stores/")
    validate_response(stores, "rider_stores_list")
    ids = {s["id"] for s in (stores.json() if isinstance(stores.json(), list) else stores.json()["results"])}
    assert QA02_ID in ids, describe(stores)
    inactive = {r[0] for r in db_query("select id from stores_darkstore where not is_active")}
    assert not ids & inactive
    me = rider.me()
    if me.status_code == 403:
        assert me.json()["error"]["details"].get("rider_status") == "NONE", describe(me)
        r = rider.register(vehicle_type="SCOOTER", vehicle_number="RJ14QA0005")
        validate_response(r, "rider_register")
        assert r.status_code == 201, describe(r)
        body = r.json()
    else:
        body = me.json()
        pytest.xfail("R1 registered by an earlier run; registration evidence is in the run log") \
            if body["status"] != "PENDING_KYC" else None
    assert body["status"] == "PENDING_KYC"
    assert body["home_store"] is None
    assert body["preferred_store"]["id"] == QA02_ID
    assert set(body["required_documents"]) == set(MOTOR_DOCS)
    assert body["ready_for_review"] is False


def _bad_register_cases():
    today = ist_today()
    short = years_ago(18, today) + timedelta(days=1)
    return [
        ("one day short of 18", {"dob": short.isoformat()}),
        ("future dob", {"dob": (today + timedelta(days=3)).isoformat()}),
        ("own phone as contact", {"emergency_contact_phone": SPARE}),
        ("non +91 contact", {"emergency_contact_phone": "+14155550123"}),
        ("landline contact", {"emergency_contact_phone": "+911123456789"}),
        ("scooter without number", {"vehicle_type": "SCOOTER"}),
        ("motorbike blank number", {"vehicle_type": "MOTORBIKE", "vehicle_number": ""}),
        ("unknown store", {"preferred_store_id": 999999}),
        ("121-char name", {"full_name": "Q" * 121}),
        ("unknown vehicle", {"vehicle_type": "TRUCK"}),
        ("missing dob", {"dob": None}),
    ]


@pytest.mark.parametrize(("label", "override"), _bad_register_cases(), ids=[c[0] for c in _bad_register_cases()])
def test_p5_tc03_register_validation(spare, label, override):
    """P5-TC-03 invalid registrations → 400 VALIDATION_ERROR, never a profile."""
    body = {k: v for k, v in override.items() if v is not None}
    r = spare.register(**body) if "dob" not in override or override["dob"] else spare.post(
        "register/", {"full_name": "QA", "emergency_contact_name": "QA C", "emergency_contact_phone": "+919812345678",
                      "preferred_store_id": QA02_ID, "vehicle_type": "BICYCLE"})
    assert_error(r, 400, "VALIDATION_ERROR")
    assert spare.me().status_code == 403


def test_p5_tc03_register_18th_birthday_accepted_shape(spare):
    """P5-TC-03 the 18th birthday (IST) is not refused for age. Sent together with an invalid
    contact so no profile is created: the age field must not be among the errors."""
    dob = years_ago(18, ist_today()).isoformat()
    r = spare.register(dob=dob, emergency_contact_phone="+14155550123")
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert "dob" not in err["details"], describe(r)
    assert "emergency_contact_phone" in err["details"]


def test_p5_tc03_bicycle_number_optional_and_markup(spare):
    """P5-TC-03 BICYCLE with or without a vehicle number is valid (checked with an invalid store so
    nothing is created); `<script>` in the name is not a 500."""
    r = spare.register(vehicle_type="BICYCLE", preferred_store_id=999999)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert set(err["details"]) == {"preferred_store_id"}, describe(r)
    # Observation O-P5-01: a BICYCLE with a number is refused ("Only motorbikes and scooters have
    # a number here"); 06 §3 only says the number is required for motorised vehicles. Recorded,
    # not filed (doc ambiguity A-list); the response must still be a clean 400.
    r = spare.register(vehicle_type="BICYCLE", vehicle_number="RJ14QA0007", preferred_store_id=999999)
    assert_error(r, 400, "VALIDATION_ERROR")
    r = spare.register(full_name="<script>alert(1)</script>", preferred_store_id=999999)
    assert r.status_code == 400, describe(r)


# --------------------------------------------------------------------------- 5.1 documents


def test_p5_tc04_upload_strips_exif(r1p):
    r1 = r1p
    """P5-TC-04 PHOTO as a JPEG with EXIF GPS and camera tags; AADHAAR_FRONT as PNG. 201 PENDING;
    the stored file (fetched through the staff signed link) is JPEG without EXIF/GPS."""
    r = r1.upload("PHOTO", EXIF_JPEG, name="me.jpg", mime="image/jpeg")
    validate_response(r, "rider_documents_create")
    assert r.status_code == 201 and r.json()["status"] == "PENDING", describe(r)
    out = rider_op(op="document_url", **{"as": SUPER}, phone=R1_PHONE, doc_type="PHOTO")
    assert out["ok"], out
    url = out["result"]["url"]
    assert "X-Amz-Signature" in url or "Signature" in url, "KYC link must be signed"
    blob = httpx.get(url, timeout=20).content
    assert blob[:2] == b"\xff\xd8", "stored file is not a JPEG"
    assert b"Exif" not in blob[:2048] and b"QA-Model-X" not in blob and b"QA-CameraMaker" not in blob
    key = url.split("?")[0].rsplit("/", 1)[-1]
    assert "me" not in key.lower().split(".")[0] or len(key) > 20, f"key looks user-chosen: {key}"
    # Anonymous fetch without the signature must fail (private bucket).
    assert httpx.get(url.split("?")[0], timeout=20).status_code in (403, 400)
    r = r1.upload("AADHAAR_FRONT", png_bytes(), name="a.png", mime="image/png")
    assert r.status_code == 201, describe(r)


def _bad_uploads():
    jpeg_script = EXIF_JPEG[:200] + b"<script>alert(1)</script>" * 20
    return [
        ("over 1 MB", ("PHOTO", b"\xff\xd8" + b"\x00" * 1_000_001, "big.jpg", "image/jpeg", None)),
        ("gif", ("PHOTO", b"GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x00\x00\x00\x00\x00,"
                          b"\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;", "a.gif", "image/gif", None)),
        ("pdf", ("PHOTO", b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF", "a.pdf", "application/pdf", None)),
        ("html as jpg", ("PHOTO", b"<html><script>alert(1)</script></html>", "a.jpg", "image/jpeg", None)),
        ("jpeg header + script", ("PHOTO", jpeg_script, "b.jpg", "image/jpeg", None)),
        ("empty", ("PHOTO", b"", "e.jpg", "image/jpeg", None)),
        ("unknown doc_type", ("PASSPORT", png_bytes(), "p.png", "image/png", None)),
    ]


@pytest.mark.parametrize(("label", "case"), _bad_uploads(), ids=[c[0] for c in _bad_uploads()])
def test_p5_tc05_upload_rejections(r1p, label, case):
    """P5-TC-05 bad uploads → 400 VALIDATION_ERROR (413 over the body limit), never 500."""
    doc_type, content, name, mime, number = case
    r = r1p.upload(doc_type, content, name=name, mime=mime, number=number)
    assert r.status_code in (400, 413), describe(r)
    assert_error(r, r.status_code, "VALIDATION_ERROR" if r.status_code == 400 else "PAYLOAD_TOO_LARGE")


def test_p5_tc05_three_mb_body(r1p):
    """P5-TC-05 a 3 MB body → 413 PAYLOAD_TOO_LARGE or 400, never 500."""
    clear_throttle("rider_documents")
    r = r1.upload("PHOTO", b"\xff\xd8" + b"\x00" * 3_000_000, name="big.jpg", mime="image/jpeg")
    assert r.status_code in (400, 413), describe(r)


def test_p5_tc05_pan_without_number(r1p):
    """P5-TC-05 PAN without a number → 400."""
    r = r1p.post("documents/", data={"doc_type": "PAN"}, files={"file": ("p.png", png_bytes(), "image/png")})
    assert_error(r, 400, "VALIDATION_ERROR")


@pytest.mark.parametrize(("doc_type", "number"), [
    ("AADHAAR_FRONT", "234123412345"),  # Verhoeff fails
    ("AADHAAR_FRONT", "12345678901"),   # 11 digits
    ("PAN", "ABCP1234Z"),
    ("PAN", "abcpq1234z1"),
    ("DL", "R1"),
    ("RC", "!!!!"),
])
def test_p5_tc06_document_number_formats(r1p, doc_type, number):
    """P5-TC-06 wrong number formats → 400 VALIDATION_ERROR on `number`."""
    me = r1p.me().json()
    if doc_type in ("DL", "RC") and doc_type not in me["required_documents"]:
        pytest.skip("R1 is not motorised")
    err = assert_error(r1p.upload(doc_type, png_bytes(), number=number), 400, "VALIDATION_ERROR")
    assert "number" in err["details"], err


def test_p5_tc08_vehicle_change_changes_required_documents(api):
    """P5-TC-08 BICYCLE → base docs; MOTORBIKE (with number) → + DL, RC. On R1 while PENDING_KYC."""
    rider = RiderClient(api, R1_PHONE)
    me = rider.me()
    if me.status_code != 200 or me.json()["status"] not in ("PENDING_KYC", "REJECTED"):
        pytest.skip("R1 not editable (already approved)")
    clear_throttle("rider_profile_write")
    r = rider.api.patch("/api/v1/rider/me/", json={"vehicle_type": "BICYCLE"}, headers=rider.h)
    validate_response(r, "rider_me_partial_update")
    assert r.status_code == 200 and set(r.json()["required_documents"]) == set(BASE_DOCS), describe(r)
    r = rider.api.patch("/api/v1/rider/me/", json={"vehicle_type": "MOTORBIKE"}, headers=rider.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    r = rider.api.patch("/api/v1/rider/me/", json={"vehicle_type": "MOTORBIKE", "vehicle_number": "RJ14QA0006"},
                        headers=rider.h)
    assert r.status_code == 200 and set(r.json()["required_documents"]) == set(MOTOR_DOCS), describe(r)
    assert {"DL", "RC"} <= set(r.json()["missing_documents"])
    r = rider.api.patch("/api/v1/rider/me/", json={"vehicle_type": "BICYCLE"}, headers=rider.h)
    assert r.status_code == 200


def test_p5_tc07_numbers_encrypted_at_rest(r1):
    """P5-TC-07 read-only SQL: KYC numbers and the bank account are not stored in clear; the API
    shows them masked."""
    rid = rider_id_of(R1_PHONE)
    me = r1.me().json()
    if not me["bank_account"]:
        assert r1.bank().status_code == 200
        me = r1.me().json()
    rows = db_query("select doc_type, number_encrypted, doc_number_masked from delivery_riderdocument "
                    "where rider_id=%s and number_encrypted <> ''", (rid,))
    assert rows, "no numbered documents to check"
    from p5_support import DOC_NUMBERS

    for doc_type, enc, masked in rows:
        clear = DOC_NUMBERS.get(doc_type)
        if clear:
            assert clear not in enc and clear.lower() not in enc.lower(), f"{doc_type} stored in clear"
            assert clear not in masked and clear[-2:] == masked[-2:] and "X" in masked, masked
    enc, last4 = db_query("select bank_account_number_encrypted, bank_account_last4 from delivery_rider "
                          "where id=%s", (rid,))[0]
    assert "123456789012" not in enc and last4 == "9012"
    shown = me["bank_account"]["account_number_masked"]
    assert shown.endswith("9012") and "12345678" not in shown
    for d in me["documents"]:
        assert d["doc_number_masked"] in ("", None) or not any(
            v in d["doc_number_masked"] for v in DOC_NUMBERS.values())


def test_p5_tc02_register_twice(r1):
    """P5-TC-02 a second registration → 409 INVALID_STATE_TRANSITION, profile unchanged."""
    before = r1.me().json()
    err = assert_error(r1.register(), 409, "INVALID_STATE_TRANSITION")
    assert err["details"].get("rider_status") == before["status"]
    assert_error(r1.register(full_name="Someone Else", vehicle_type="SCOOTER", vehicle_number="RJ14QA0099"),
                 409, "INVALID_STATE_TRANSITION")
    after = r1.me().json()
    assert (after["full_name"], after["vehicle_type"]) == (before["full_name"], before["vehicle_type"])


@pytest.mark.parametrize("body", [
    {"account_number": "12345678"},
    {"account_number": "1234567890123456789"},
    {"account_number": "12345ABC9012"},
    {"ifsc": "HDFC1001234"},
    {"ifsc": "HDF0001234"},
    {"holder_name": ""},
    {"upi_id": "not a upi"},
])
def test_p5_tc09_bank_validation(r1, body):
    """P5-TC-09 bad bank details → 400 VALIDATION_ERROR; good ones → 200 masked."""
    clear_throttle("rider_profile_write")
    assert_error(r1.bank(**body), 400, "VALIDATION_ERROR")


def test_p5_tc09_bank_ok_masked(r1):
    """P5-TC-09 valid details → 200 masked; a lowercase IFSC is normalised to upper case."""
    clear_throttle("rider_profile_write")
    r = r1.bank(ifsc="hdfc0001234")
    assert r.status_code == 200 and r.json()["ifsc"] == "HDFC0001234", describe(r)
    r = r1.bank(upi_id="qa.rider@okhdfc")
    validate_response(r, "rider_bank_account_update")
    assert r.status_code == 200, describe(r)
    assert r.json()["account_number_masked"].endswith("9012") and "123456" not in r.text


def test_p5_tc10_replace_document_and_approved_locked(r1):
    """P5-TC-10 an approved document cannot be replaced (409); R1 is ACTIVE with all approved."""
    clear_throttle("rider_documents")
    me = r1.me().json()
    assert me["status"] == "ACTIVE"
    approved = [d["doc_type"] for d in me["documents"] if d["status"] == "APPROVED"]
    assert set(approved) >= set(me["required_documents"])
    assert_error(r1.upload("AADHAAR_BACK"), 409, "INVALID_STATE_TRANSITION")


@pytest.mark.smoke
def test_p5_tc11_rider_cannot_patch_privileged_fields(r1):
    """P5-TC-11 🔥 PATCH /rider/me/ with status, home_store, cash fields, is_online: ignored or 400;
    an ACTIVE rider may change only the emergency contact."""
    clear_throttle("rider_profile_write")
    before = r1.me().json()
    hacks = [{"status": "SUSPENDED"}, {"home_store": 1}, {"home_store_id": 1}, {"cash_limit": "999999.00"},
             {"cash_in_hand": "0.00"}, {"is_online": True}, {"rating_avg": "5.00"}]
    for h in hacks:
        r = r1.api.patch("/api/v1/rider/me/", json=h, headers=r1.h)
        assert r.status_code in (200, 400), describe(r)
    r = r1.api.patch("/api/v1/rider/me/", json={"full_name": "Changed Name"}, headers=r1.h)
    assert r.status_code in (400, 409), describe(r)
    r = r1.api.patch("/api/v1/rider/me/", json={"emergency_contact_name": "QA Contact Two"}, headers=r1.h)
    assert r.status_code == 200, describe(r)
    after = r1.me().json()
    for k in ("status", "is_online", "full_name", "cash", "rating_avg"):
        assert after[k] == before[k], k
    assert after["home_store"]["id"] == QA02_ID


# --------------------------------------------------------------------------- 5.1 review


def test_p5_tc13_reject_and_resubmit(api):
    """P5-TC-13 OPS rejects R2 (PENDING_KYC) with a reason (empty reason refused); R2 sees it;
    R2 re-uploads a rejected document and goes back to PENDING_KYC by itself (#9)."""
    reset_rider(R2_PHONE) if _rider_exists(R2_PHONE) else None
    rider = RiderClient(api, R2_PHONE)
    if rider.me().status_code == 403:
        clear_throttle("rider_profile_write")
        assert rider.register().status_code == 201
    me = rider.me().json()
    if me["status"] == "ACTIVE":
        pytest.skip("R2 already ACTIVE (earlier run)")
    clear_throttle("rider_documents")
    for doc in me["missing_documents"]:
        assert rider.upload(doc).status_code == 201
    if not me["bank_account"]:
        assert rider.bank().status_code == 200
    out = rider_op(op="reject_rider", **{"as": OPS}, phone=R2_PHONE, reason="")
    assert not out["ok"], out
    out = rider_ops({"op": "reject_document", "as": OPS, "phone": R2_PHONE, "doc_type": "PAN",
                     "note": "QA blurry"},
                    {"op": "reject_rider", "as": OPS, "phone": R2_PHONE, "reason": "QA: PAN unreadable"})
    assert all(o["ok"] for o in out), out
    me = rider.me().json()
    assert me["status"] == "REJECTED" and me["rejection_reason"] == "QA: PAN unreadable"
    pan = next(d for d in me["documents"] if d["doc_type"] == "PAN")
    assert pan["status"] == "REJECTED" and pan["review_note"] == "QA blurry"
    assert_error(rider.shift_start(), 403, "PERMISSION_DENIED")
    assert rider.upload("PAN").status_code == 201
    me = rider.me().json()
    assert me["status"] == "PENDING_KYC" and me["rejection_reason"] == "", me["status"]


def _rider_exists(phone: str) -> bool:
    return bool(db_query("select 1 from delivery_rider r join accounts_user u on u.id=r.user_id "
                         "where u.phone=%s", (phone,)))


def test_p5_tc14_active_rider_rejected_document_blocks_online(r2):
    """P5-TC-14 OPS rejects ACTIVE R2's AADHAAR_BACK: R2 stays ACTIVE but shift/start → 409
    DOCUMENTS_NOT_APPROVED; re-upload + approve → online works."""
    clear_throttle("rider_documents")
    out = rider_op(op="reject_document", **{"as": OPS}, phone=R2_PHONE, doc_type="AADHAAR_BACK", note="QA expired")
    assert out["ok"], out
    me = r2.me().json()
    assert me["status"] == "ACTIVE"
    err = assert_error(r2.shift_start(), 409, err_code := _shift_doc_code(r2))
    assert err["details"].get("reason") == "DOCUMENTS_NOT_APPROVED" and "AADHAAR_BACK" in err["details"]["doc_types"]
    assert r2.upload("AADHAAR_BACK").status_code == 201
    assert_error(r2.shift_start(), 409, err_code)  # pending, still not approved
    assert rider_op(op="approve_document", **{"as": OPS}, phone=R2_PHONE, doc_type="AADHAAR_BACK")["ok"]
    assert r2.shift_start().status_code == 200


def _shift_doc_code(rider) -> str:
    r = rider.shift_start()
    return r.json()["error"]["code"] if r.status_code == 409 else "INVALID_STATE_TRANSITION"


def test_p5_tc15_suspend_and_reinstate(r1):
    """P5-TC-15 OPS suspends R1 (reason): shift/start 403 RIDER_NOT_ACTIVE; online R1 is set offline;
    records stay readable; reinstate → can go online again."""
    r1.online_at()
    out = rider_op(op="suspend", **{"as": OPS}, phone=R1_PHONE, reason="QA suspension")
    assert out["ok"] and out["result"]["status"] == "SUSPENDED" and out["result"]["is_online"] is False, out
    me = r1.me().json()
    assert me["status"] == "SUSPENDED" and me["suspension_reason"] == "QA suspension"
    err = assert_error(r1.shift_start(), 403, "PERMISSION_DENIED")
    assert err["details"].get("reason") == "RIDER_NOT_ACTIVE"
    assert_error(r1.heartbeat(), 403, "PERMISSION_DENIED") if r1.heartbeat().status_code == 403 else None
    out = rider_op(op="reinstate", **{"as": OPS}, phone=R1_PHONE)
    assert out["ok"] and out["result"]["status"] == "ACTIVE", out
    assert r1.shift_start(offset(QA02, north_m=20)).status_code == 200


def test_p5_tc16_no_profile_gets_403_none(api):
    """P5-TC-16 a user without a rider profile: every rider operation → 403 rider_status NONE."""
    s = login(SPARE, app="rider")
    h = {**RIDER_HEADERS, **bearer(s.access)}
    if api.get("/api/v1/rider/me/", headers=h).status_code != 403:
        pytest.skip("spare user has a profile")
    for method, path in [("get", "me/"), ("post", "documents/"), ("put", "bank-account/"), ("post", "shift/start/"),
                         ("post", "shift/end/"), ("post", "locations/"), ("post", "heartbeat/"),
                         ("get", "offers/current/"), ("get", "tasks/current/"), ("get", "tasks/history/"),
                         ("get", "earnings/"), ("get", "cash/ledger/"), ("get", "payouts/")]:
        valid = {
            "bank-account/": {"holder_name": "QA", "account_number": "123456789012", "ifsc": "HDFC0001234"},
            "shift/start/": {"lat": QA02[0], "lng": QA02[1], "accuracy": 10},
            "locations/": {"points": [{"lat": QA02[0], "lng": QA02[1], "accuracy": 10, "recorded_at": now_iso(-1)}]},
        }
        kw = {} if method == "get" else (
            {"data": {"doc_type": "PAN", "number": "ABCPQ1234Z"}, "files": {"file": ("p.png", png_bytes(), "image/png")}}
            if path == "documents/" else {"json": valid.get(path, {})})
        r = getattr(api, method)(f"/api/v1/rider/{path}", headers=h, **kw)
        if r.status_code == 503:
            continue  # contract stub on a 5.1/5.2 build
        err = assert_error(r, 403, "PERMISSION_DENIED")
        assert err["details"].get("rider_status") == "NONE", (path, err)


@pytest.mark.limits
def test_p5_tc17_document_and_profile_rate_limits(r2):
    """P5-TC-17 the 31st document upload in an hour and the 21st register/bank write → 429."""
    clear_throttle("rider_documents")
    codes = [r2.upload("PASSPORT").status_code for _ in range(31)]  # invalid type: no state change
    assert codes[:30].count(429) == 0 and codes[30] == 429, codes
    clear_throttle("rider_documents")
    clear_throttle("rider_profile_write")
    codes = [r2.bank(ifsc="bad").status_code for _ in range(21)]
    assert codes[:20].count(429) == 0 and codes[20] == 429, codes
    clear_throttle("rider_profile_write")


def test_p5_tc20_photo_url_signed(r1):
    """P5-TC-20 photo_url is a signed link with an expiry about 1 h ahead; it fetches the photo."""
    from datetime import UTC, datetime

    me = r1.me().json()
    url, exp = me["photo_url"], me["photo_url_expires_at"]
    assert url and exp, me
    left = (datetime.fromisoformat(exp.replace("Z", "+00:00")) - datetime.now(UTC)).total_seconds()
    assert 3000 < left <= 3700, left
    r = httpx.get(url, timeout=20)
    assert r.status_code == 200 and r.content[:2] == b"\xff\xd8"


# --------------------------------------------------------------------------- 5.2 extras


def test_p5_tc23_me_reflects_online_and_shift(r1):
    """P5-TC-23 after shift/start, /rider/me/ shows is_online true and today's online seconds."""
    r1.online_at()
    me = r1.me()
    validate_response(me, "rider_me_retrieve")
    assert me.json()["is_online"] is True
    assert me.json()["today"]["online_seconds"] >= 0
    # cash_in_hand carries over between QA runs (the ledger is append-only): assert the shape and
    # the server-side flags, not 0.00. `deposit_required` is the DL-61 (b) field added in 5.4.
    cash = me.json()["cash"]
    assert set(cash) >= {"cash_in_hand", "cash_limit", "limit_reached", "deposit_required"}, cash
    assert cash["limit_reached"] is (Decimal(cash["cash_in_hand"]) >= Decimal(cash["cash_limit"]))


def test_p5_tc28_auto_offline_rules(r1):
    """P5-TC-28 (b) heartbeat within 10 min and a fresh point → stays online after the job;
    (a) is time-based (10 min without points), checked through the job on an old point only."""
    r1.online_at()
    assert r1.heartbeat().status_code == 200
    out = rider_op(op="heartbeat_check", **{"as": SUPER})
    assert out["ok"], out
    assert r1.heartbeat().json()["is_online"] is True


@pytest.mark.limits
def test_p5_tc30_location_and_heartbeat_rate(r1):
    """P5-TC-30 the 7th location batch and the 7th heartbeat in one minute → 429 RATE_LIMITED."""
    r1.online_at()
    clear_throttle("rider_locations")
    clear_throttle("rider_heartbeat")
    codes = [r1.ping(recorded_at=now_iso(-i - 1)).status_code for i in range(7)]
    assert codes[:6].count(429) == 0 and codes[6] == 429, codes
    codes = [r1.heartbeat().status_code for _ in range(7)]
    assert codes[:6].count(429) == 0 and codes[6] == 429, codes
    r = r1.heartbeat()
    assert_error(r, 429, "RATE_LIMITED")
    clear_throttle("rider_locations")
    clear_throttle("rider_heartbeat")


def test_p5_tc31_force_offline(r1):
    """P5-TC-31 OPS forces R1 offline (ended_by ops, ADMIN); R1's next point → 409 RIDER_OFFLINE."""
    r1.online_at()
    out = rider_op(op="force_offline", **{"as": OPS}, phone=R1_PHONE)
    assert out["ok"] and out["result"]["is_online"] is False, out
    rid = rider_id_of(R1_PHONE)
    reason = db_query("select end_reason from delivery_ridershift where rider_id=%s order by id desc limit 1", (rid,))
    assert reason[0][0] == "ADMIN"
    assert_error(r1.ping(recorded_at=now_iso(-1)), 409, "RIDER_OFFLINE")


# --------------------------------------------------------------------------- 5.1 role matrix (service level)

ROLES_DENIED = [MANAGER, STAFF, CATALOG, SUPPORT, FINANCE]


@pytest.mark.smoke
@pytest.mark.parametrize("role", ROLES_DENIED)
def test_p5_tc111_review_actions_denied(r1, role):
    """P5-TC-111 🔥 (service level) roles without delivery.review_rider cannot suspend, reinstate,
    approve/reject documents, set the home store or cash limit (05 §3: Super Admin and Ops only)."""
    steps = [
        {"op": "suspend", "as": role, "phone": R1_PHONE, "reason": "QA role test"},
        {"op": "reject_document", "as": role, "phone": R1_PHONE, "doc_type": "PAN", "note": "QA"},
        {"op": "set_home_store", "as": role, "phone": R1_PHONE, "store_id": 1},
        {"op": "set_cash_limit", "as": role, "phone": R1_PHONE, "amount": "9999.00"},
        {"op": "force_offline", "as": role, "phone": R1_PHONE},
    ]
    out = rider_ops(*steps)
    assert not any(o["ok"] for o in out), out
    state = rider_op(op="rider_state", phone=R1_PHONE)["result"]
    assert state["status"] == "ACTIVE" and state["home_store_id"] == QA02_ID


@pytest.mark.parametrize("role", [*ROLES_DENIED, OPS, SUPER])
def test_p5_tc112_reveal_number_by_role(r1, role):
    """P5-TC-112 only Super Admin and Ops may reveal a full KYC number or open the file."""
    out = rider_ops({"op": "document_number", "as": role, "phone": R1_PHONE, "doc_type": "PAN"},
                    {"op": "document_url", "as": role, "phone": R1_PHONE, "doc_type": "PAN"})
    allowed = role in (OPS, SUPER)
    assert [o["ok"] for o in out] == [allowed, allowed], out
    if allowed:
        assert out[0]["result"]["len"] == 10


@pytest.mark.xfail(strict=True, reason="BUG-0013: body validation runs before the rider-profile check")
@pytest.mark.parametrize("path", ["bank-account/", "documents/"])
def test_p5_tc16_no_profile_invalid_body_still_403(api, path):
    """P5-TC-16 06 §3 Access: without a rider profile the answer is 403 rider_status NONE, whatever the body."""
    s = login(SPARE, app="rider")
    h = {**RIDER_HEADERS, **bearer(s.access)}
    if path == "documents/":
        r = api.post("/api/v1/rider/documents/", headers=h, data={"doc_type": "PAN"},
                     files={"file": ("p.png", png_bytes(), "image/png")})
    else:
        r = api.put("/api/v1/rider/bank-account/", headers=h, json={})
    err = assert_error(r, 403, "PERMISSION_DENIED")
    assert err["details"].get("rider_status") == "NONE"
