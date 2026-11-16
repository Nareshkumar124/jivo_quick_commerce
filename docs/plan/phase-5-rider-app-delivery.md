# Phase 5: Rider app and delivery

**Goal:** an order is delivered end to end: dispatch, accept, pickup, delivery OTP, COD, with returns (`development-phase.md` §3).
**Needs:** D-07 (Android only), D-11 (Play Console and the background-location declaration; needed only for real riders), D-14 (rider KYC policy), D-16 (rider pay). D-14 and D-16 run on the `11` defaults (DL-54).
**Contracts:** `docs/08-order-lifecycle.md` (§3 delivery task states, §5 dispatch, T9, T10, T13, T14, §6.4 failed delivery). Rider API in `06 §3`; rider screens in `04`; ops screens in `05 §1.4`, `§1.5`; role matrix `05 §3`. Test steps are in [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (Phase 5 section).

## Status summary (as of 2026-11-14)

1. **Build:** done and merged to `develop` in four slices (2026-11-05/06): backend `57e8fb0`, `8566589`, `d72bd23`; rider `130b42a`; customer `9ce3234`; admin `680b904`. Migrations applied (DL-62, DL-63).
2. **QA:** stage 3 (`3a59367`, 2026-11-10): 105 of 132 pass, 1 xfail (BUG-0013), 21 not run, 5 deferred (4 device cases, 1 for P6). Verdict "Not ready (gate incomplete)". No open P0/P1 bug.
3. **Open work:** BUG-0013 (P3 minor) fix was running on 2026-11-10; the rider mini-UAT, the four device cases and the 21 unrun cases (P0 first: TC-12, 42, 45, 51, 110) are open.
4. **Since 2026-11-10:** water slab prices, a minimum of 5 cartons per order, referral coupons, COD limit kept at ₹2,000 (user, 2026-11-14), cart tip and instructions reset after an order (`d387784`). These touch the order amounts that riders collect. QA has not re-run P5 on them.
5. **Waiting on Jivo or the user:** D-14 and D-16 confirmation (H-17), D-11 Play Console for real riders (H-08), H-20 failed-delivery rule, H-21 ML Kit licence check.

## Scope

### Backend
| Item | Notes |
|---|---|
| Final rider contract (`06 §3`) and `GET /orders/{id}/track/` (T-511) | Additive; schema re-exported. |
| Slice 5.1: registration, KYC (private bucket, masked and encrypted numbers), bank details, admin approval | D-14 defaults; DPDP. Rider data is blanked on erasure and KYC files are purged 1 year later (DL-57). |
| Slice 5.2: shifts, location ingestion (Redis latest plus history), heartbeat auto-offline, `simulate_rider` | |
| Slice 5.3: dispatch (`08 §5`), offers and `expire_offer`, tasks with T9, T10, T13, T14, geofences, delivery OTP, FCM sender interface | The rider phone and `delivery_otp` are shown to the order owner only while OUT_FOR_DELIVERY (DL-56). |
| Slice 5.4: cash ledger, `cod-qr`, earnings (D-16 defaults), payouts, invoices on DELIVERED | COD offers only if `cash_in_hand + order COD amount <= limit` (DL-61 (b)). |
| Rules from DL-61 | Ops actions per role (a); earnings paid once the order is picked up, also for failed, returned and cancelled-after-pickup (c); two refused COD deliveries block COD for the customer (d); re-dispatch excludes only riders offered in the current round (e). |
| Stock commit at pickup (T9) | `on_hand` is decremented only at T9; every change writes a `StockMovement`. |
| New since 2026-11-10 | Orders are now water-carton orders of at least 5 cartons at slab prices; the COD amount a rider collects follows the server bill and the ₹2,000 COD limit. |

### Admin panel and Ops Console
| Item | Notes |
|---|---|
| Riders list, KYC review and approve, suspend | Role matrix `05 §3`. |
| Dispatch board with retry, manual assign and unassign | DL-61 (a): Super Admin and Ops everywhere, Store Manager own store, Finance only cash deposits, Support none. |
| Rider map with polling (`05 §1.4`), cash deposits (`05 §1.5`), receiving returns, set cash limit | |
| Payouts and rider earnings | |

### Customer app
| Item | Notes |
|---|---|
| Rider and delivery OTP on order detail by polling `track/` | Customer sees the OTP only while OUT_FOR_DELIVERY. |
| FCM token through `/me/devices/` | Push is a no-op until the Firebase project exists (D-19). |
| P7 lookahead on fakes: rating, help, CMS | Bound later in P7. |

### Rider app
| Item | Notes |
|---|---|
| Onboarding, KYC upload, status screens | Dev flavor can use fakes; staging and prod use the real API (DL-30, DL-32). |
| Online toggle with the foreground location service, background-location disclosure | Real-device only. |
| Offers (full-screen alert, countdown from `expires_at`), the whole task flow, pickup by QR or 4-character code, delivery OTP with lock, COD cash and UPI QR, failed delivery with a 10-minute timer | QR scanner uses the unbundled ML Kit model (DL-32). |
| Earnings, cash ledger, history, profile and documents | |

## Task checklist

Source: `docs/task-tracker.md`. `[x]` means tracker "Completed" or merged to `develop` (hash shown). The tracker keeps every P5 row at "QA verification pending".

- [x] T-511 Final P5 rider contract and `track/`: merged `57e8fb0`
- [x] T-512 Slice 5.1 registration, KYC, bank, approval: merged `57e8fb0`
- [x] T-513 Slice 5.2 shifts, location, heartbeat, `simulate_rider`: merged `57e8fb0`
- [x] T-514 Slices 5.3 and 5.4 dispatch, offers, T9-T14, OTP, cash, earnings, payouts, invoices: merged `8566589` (5.3) and `d72bd23` (5.4); migrations applied DL-62, DL-63
- [x] T-515 Rider P5: foreground location, disclosure, FCM plumbing, bind slices 5.1 to 5.4: merged `305942b`, `130b42a`
- [x] T-516 Customer P5: FCM token, rider and delivery OTP via `track/`: merged `efd4a1f`, `f89f89a`, `9ce3234`
- [x] T-517 Admin P5: riders, KYC review, rider map, cash deposits, returns: merged `680b904`
- [ ] T-518 QA P5 and rider mini-UAT: In Progress (stage 3 `3a59367`)
- [x] BUG-0021/0022 (P6 items found in the same run) fixed in `ca8e69c`; the re-check is pending
- [x] T-405c COD block count restart (DL-61 (d)): merged `64dc6ce`
- [x] BUG-0013 fix (403 before body validation for a user with no rider profile): merged `2f7c942` 2026-11-11; QA re-check pending
- [ ] Run the 21 unrun QA cases (P0 first: TC-12, 42, 45, 51, 110)
- [ ] Device cases P5-TC-19, 33, 124, 131 on the user's phone (adb reverse, see `CLAUDE.md`)
- [ ] Rider mini-UAT with 3 to 5 riders (`10 §7`)
- [ ] Play background-location video (human step, D-11)
- [ ] QA re-run for slab prices, minimum cartons and the COD limit, as they change COD amounts
- [ ] CI on the `develop` to `main` PR, staging run, demo, sign-off

## Test cases

Steps and expected results: `qa/docs/02-test-case-repository.md`, section "Phase 5". 🔥 = regression smoke case (27 in P5). Layers: BE backend, ADM admin panel, CUS customer app, RID rider app, E2E end to end. Status is the latest QA run (stage 3, `3a59367`, develop `efb3c3d`, 2026-11-09 and 2026-11-10). Titles are shortened from the Steps column. Order within the file: 5.1 KYC (01-20), 5.2 shifts and location (21-33), 5.3 dispatch to returns (34-87), 5.4 cash, earnings, ops (88-103), IDOR (104-110), role matrix (111-118), customer tracking (119-124), end to end and data (125-132).

| ID | Title | Pri | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P5-TC-01 | GET /rider/stores/; POST /rider/register/ with a valid body (SCOOTER +... | P0 🔥 | BE | pass | - |
| P5-TC-02 | Register again (same body, then a different one) | P1 | BE | pass | - |
| P5-TC-03 | Validation: dob exactly 18 years ago (IST) and one day short; emergenc... | P1 | BE | pass | - |
| P5-TC-04 | Upload PHOTO (JPEG 900 KB with EXIF GPS and camera tags) and AADHAAR_F... | P0 | BE | pass | - |
| P5-TC-05 | Upload 1,000,001 bytes; GIF; PDF; HTML renamed .jpg; a JPEG header fol... | P0 | BE | pass | - |
| P5-TC-06 | Numbers: Aadhaar failing the Verhoeff check, PAN/DL/RC in the wrong fo... | P1 | BE | pass | - |
| P5-TC-07 | Read-only SQL on the document-number and bank-account columns | P0 | BE | pass | - |
| P5-TC-08 | BICYCLE, then E_BIKE, then MOTORBIKE (PATCH /rider/me/); read missing_... | P1 | BE | pass | - |
| P5-TC-09 | PUT /rider/bank-account/: 8- and 19-digit accounts, letters, lowercase... | P1 | BE | pass | - |
| P5-TC-10 | Upload a new copy of each | P1 | BE | pass | - |
| P5-TC-11 | PATCH /rider/me/ with status, home_store, cash_limit, cash_in_hand, is... | P0 | BE | pass | - |
| P5-TC-12 | OPS in the Riders admin: approve each document, then approve the rider... | P0 🔥 | ADM | not run | - |
| P5-TC-13 | OPS rejects the rider with a reason (and once with an empty reason); t... | P1 | ADM | pass | - |
| P5-TC-14 | OPS rejects R2's DL; R2 calls shift/start; R2 re-uploads, OPS approves... | P1 | ADM | pass | - |
| P5-TC-15 | OPS suspends R1 with a reason; R1 calls shift/start and the records en... | P0 | ADM | pass | - |
| P5-TC-16 | Call me, documents, bank, shift, locations, heartbeat, offers, tasks, ... | P0 | BE | fixed `2f7c942`, QA re-check pending | BUG-0013 |
| P5-TC-17 | 31 document uploads in an hour; 21 register/bank writes | P2 | BE | pass | - |
| P5-TC-18 | Delete the account (grace period by driver), anonymise; then run purge... | P1 | BE | not run | - |
| P5-TC-19 | Register → documents (camera, compressed ≤ 1 MB) → bank → stat... | P1 | RID | deferred | - |
| P5-TC-20 | Read photo_url and photo_url_expires_at; fetch the URL; fetch after ex... | P1 | BE | pass | - |
| P5-TC-21 | shift/start at the store; again | P0 🔥 | BE | pass | - |
| P5-TC-22 | shift/start at 1,990 m and 2,010 m from the pin; lat/lng missing, out ... | P1 | BE | pass | - |
| P5-TC-23 | shift/start; GET /rider/me/ | P1 | BE | pass | - |
| P5-TC-24 | shift/end in each state; a location batch after going offline | P0 | BE | pass | - |
| P5-TC-25 | Batches of 1, 50, 51 and 0 points; a repeated recorded_at in the same ... | P1 | BE | pass | - |
| P5-TC-26 | A point with is_mocked true | P1 | BE | not run | - |
| P5-TC-27 | POST /rider/heartbeat/ in each state | P1 | BE | pass | - |
| P5-TC-28 | (a) no point for 10+ min, no heartbeat; (b) a heartbeat within 10 min ... | P1 | BE | pass | - |
| P5-TC-29 | Send one point with recorded_at = now + 110 s, then nothing; dispatch ... | P1 | BE | not run | - |
| P5-TC-30 | 7 location batches and 7 heartbeats in one minute | P2 | BE | pass | - |
| P5-TC-31 | OPS forces R1 offline; R1 sends a point | P1 | ADM | pass | - |
| P5-TC-32 | Send points while offline; count R1's location rows (read-only SQL) | P1 | BE | pass | - |
| P5-TC-33 | Permissions gate order (disclosure before the first prompt), online to... | P1 | RID | deferred | - |
| P5-TC-34 | A places COD(A); poll GET /rider/offers/current/ every 0.5 s | P0 🔥 | E2E | pass | - |
| P5-TC-35 | R2 variants: offline; home store GGN-01; last point 130 s old; on anot... | P0 | BE | pass | - |
| P5-TC-36 | Place a COD order each time, then an ONLINE order | P0 | BE | pass | - |
| P5-TC-37 | (a) R1 150 m, R2 1.2 km; (b) both ≤ 200 m, R2 idle longer (its last ... | P1 | BE | pass | - |
| P5-TC-38 | 1: a COD order is PLACED and not yet accepted (auto-accept delay): no ... | P1 | BE | not run | - |
| P5-TC-39 | R1 accepts; accepts again; reads tasks/current/ and offers/current/... | P0 🔥 | BE | pass | - |
| P5-TC-40 | R1 rejects with TOO_FAR; reject with an unknown reason; reject with no... | P0 | BE | pass | - |
| P5-TC-41 | Wait for expiry (30 s + up to 15 s sweep), then R1 accepts, then rejec... | P0 | BE | pass | - |
| P5-TC-42 | 10 trials: R1's accept sent in parallel with the driver's expire_offer... | P0 | BE | not run | - |
| P5-TC-43 | 10 parallel accepts by R1 | P0 | BE | pass | - |
| P5-TC-44 | A cancels (T11) in parallel with R1's accept | P0 | BE | pass | - |
| P5-TC-45 | OPS manual-assigns R2 in parallel with R1's accept | P0 | BE | not run | - |
| P5-TC-46 | R1 goes offline, then accepts | P1 | BE | pass | - |
| P5-TC-47 | R1 lets every offer expire; watch the task through the give-up and the... | P1 | BE | not run | - |
| P5-TC-48 | Place COD(A); 20 s later R1 goes online | P1 | BE | pass | - |
| P5-TC-49 | (a) A cancels; (b) A cancels; (c) OPS cancels (T12) | P1 | BE | pass | - |
| P5-TC-50 | OPS: start packing, mark packed | P1 | BE | not run | - |
| P5-TC-51 | OPS marks 1 unit unavailable; R1 reads the task; later delivers with t... | P0 | BE | not run | - |
| P5-TC-52 | Read estimated_payout and distance_km on the offer and the task | P1 | BE | pass | - |
| P5-TC-53 | Place two COD orders (A, B) a second apart | P0 | BE | pass | - |
| P5-TC-54 | OPS manual-assigns R2 (console in 5.4; service until then) | P0 🔥 | ADM | pass | - |
| P5-TC-55 | Manual assign of: an offline rider; a busy rider; a GGN-01 rider; R2 w... | P0 | ADM | pass | - |
| P5-TC-56 | OPS unassigns | P0 | ADM | pass | - |
| P5-TC-57 | OPS retries dispatch | P1 | ADM | not run | - |
| P5-TC-58 | 10 runs: ACCEPTED time (history) → offer offered_at → first succes... | P2 | BE | not run | - |
| P5-TC-59 | arrived-store at 150 m; at 240 m with accuracy 50; at 260 m with accur... | P1 | BE | pass | - |
| P5-TC-60 | Pickup with the 4-character code | P0 🔥 | BE | pass | - |
| P5-TC-61 | Pickup with JQC1:<order_number>:<code>; the QR of another QA order; th... | P0 | BE | pass | - |
| P5-TC-62 | (a, b) pickup with the right code; (c) pickup with ＡＢＣＤ, ١٢�... | P0 | BE | pass | - |
| P5-TC-63 | 5 wrong codes, then the right one; OPS unassigns and re-assigns R1 (5.... | P0 | BE | pass | - |
| P5-TC-64 | 11 pickup calls in one minute (wrong-shape codes, so the lock is not r... | P1 | BE | not run | - |
| P5-TC-65 | 5 parallel pickups with the right code | P0 | BE | pass | - |
| P5-TC-66 | Stock invariants on QA-02 | P0 🔥 | BE | pass | - |
| P5-TC-67 | arrived-customer at 150 m from the drop; at 600 m with no override; at... | P1 | BE | pass | - |
| P5-TC-68 | Deliver with the right OTP (read from A's track) | P0 🔥 | BE | pass | - |
| P5-TC-69 | Deliver with the OTP and cod: {mode: cash, amount: <cod_amount_due>} | P0 🔥 | BE | pass | - |
| P5-TC-70 | Deliver with the right OTP and: due − 0.01; due + 0.01; "249" for "2... | P0 | BE | pass | - |
| P5-TC-71 | 4 wrong OTPs, a 5th wrong one, then the right one; re-read the task; r... | P0 🔥 | BE | pass | - |
| P5-TC-72 | 20 parallel wrong OTPs, then the right one | P0 | BE | pass | - |
| P5-TC-73 | OTP "", "123", "12345", "abcd", "١٢٣٤", " 1234 " | P1 | BE | pass | - |
| P5-TC-74 | Deliver with the right OTP | P1 | BE | pass | - |
| P5-TC-75 | 5 parallel delivers with the right OTP and amount | P0 | BE | pass | - |
| P5-TC-76 | A reads track | P0 | BE | pass | - |
| P5-TC-77 | A reads the invoice; waits past INVOICE_URL_EXPIRY_SECONDS; B asks for... | P1 | E2E | not run | - |
| P5-TC-78 | Fail with CUSTOMER_REFUSED; then R1 tries shift/end | P0 🔥 | BE | pass | - |
| P5-TC-79 | CUSTOMER_NOT_REACHABLE with call_attempts 1; with 2 inside the wait; f... | P0 | BE | pass | - |
| P5-TC-80 | Fail with WRONG_ADDRESS; another order with OTHER and a note; OTHER wi... | P0 | BE | pass | - |
| P5-TC-81 | Fail with CUSTOMER_REFUSED | P0 | BE | pass | - |
| P5-TC-82 | Second refused COD delivery; then the customer places COD; OPS unblock... | P1 | BE | pass | - |
| P5-TC-83 | Fail, then fail again; on another order, 3 parallel fails | P0 | BE | pass | - |
| P5-TC-84 | Fail with a photo: JPEG 800 KB with EXIF; PNG; PDF; 6 MB | P1 | BE | not run | - |
| P5-TC-85 | OPS (packing console in 5.4, service until then) receives the return w... | P0 🔥 | ADM | pass | - |
| P5-TC-86 | Receive with damaged {line: 1}; then attempts with damaged > units, an... | P0 | ADM | pass | - |
| P5-TC-87 | Receive while OFD; receive the same return twice | P1 | ADM | pass | - |
| P5-TC-88 | POST /tasks/{id}/cod-qr/; repeat | P0 | BE | pass | - |
| P5-TC-89 | Simulate the QR payment (fake gateway, signed); poll tasks/current; de... | P0 | BE | pass | - |
| P5-TC-90 | Replay the QR-payment event 3 times and 3 in parallel; a payment of a ... | P0 | BE | pass | - |
| P5-TC-91 | Deliver with cash; then the QR payment arrives | P0 | BE | pass | - |
| P5-TC-92 | Generate the QR on the first; wait out the second's expiry and pay it ... | P1 | BE | not run | - |
| P5-TC-93 | OPS unlocks each | P0 🔥 | ADM | pass | - |
| P5-TC-94 | GET /rider/cash/ledger/ with before_id paging; GET /rider/me/ | P0 | BE | pass | - |
| P5-TC-95 | SMQ records a deposit of 498.00 at /ops/cash/ | P0 🔥 | ADM | pass | - |
| P5-TC-96 | Deposits of 498.01, 0, −5, 1.005, "abc"; a GGN-01 rider; the same fo... | P0 | ADM | pass | - |
| P5-TC-97 | Day-end report for QA-02 | P1 | ADM | not run | - |
| P5-TC-98 | Ledger invariants | P0 🔥 | BE | pass | - |
| P5-TC-99 | GET /rider/earnings/ for today, this week and a range; from > to; a ra... | P1 | BE | pass | - |
| P5-TC-100 | Earnings for that day | P1 | BE | pass | - |
| P5-TC-101 | GET /rider/tasks/history/ with before_id paging | P1 | BE | pass | - |
| P5-TC-102 | FIN creates a payout batch and marks it paid with a reference; R1 read... | P1 | ADM | pass | - |
| P5-TC-103 | Read history, earnings, ledger and payouts | P1 | BE | not run | - |
| P5-TC-104 | R2 accepts and rejects O1 | P0 🔥 | BE | pass | - |
| P5-TC-105 | R2 calls arrived-store, pickup (right code), arrived-customer, cod-qr,... | P0 🔥 | BE | pass | - |
| P5-TC-106 | R2 sweeps offer and task ids ±50 around R1's | P0 | BE | pass | - |
| P5-TC-107 | A calls the rider endpoints, including accept on O1 | P0 | BE | pass | - |
| P5-TC-108 | B reads A's track; R1 (the delivering rider, not the owner) reads it | P0 🔥 | BE | pass | - |
| P5-TC-109 | R2 reads history, ledger, earnings and payouts with rider_id=<R1> and ... | P0 | BE | pass | - |
| P5-TC-110 | R2 and customer A use them; change the key in the link | P0 | BE | not run | - |
| P5-TC-111 | Each role: approve/reject a document, approve/reject the rider, suspen... | P0 🔥 | ADM | pass | - |
| P5-TC-112 | Each role opens a KYC file and reveals a full number | P0 | ADM | pass | - |
| P5-TC-113 | Each role: manual assign, unassign, retry dispatch | P0 🔥 | ADM | pass | - |
| P5-TC-114 | Each role: record a deposit; open the day-end report | P0 🔥 | ADM | pass | - |
| P5-TC-115 | Each role: create a payout batch, mark it paid | P0 | ADM | pass | - |
| P5-TC-116 | Each role receives the return | P1 | ADM | pass | - |
| P5-TC-117 | Each role: force offline; unlock OTP/pickup; set cash limit | P1 | ADM | not run | - |
| P5-TC-118 | Each role opens /ops/riders/map/ and the rider list; a POST without th... | P1 | ADM | pass | - |
| P5-TC-119 | A reads track at SEARCHING, OFR, ASG, ATS, OFD and ATC | P0 🔥 | BE | pass | - |
| P5-TC-120 | A reads track | P0 | BE | pass | - |
| P5-TC-121 | Look for the OTP value in: order detail and list; R1's task, offers an... | P0 | BE | pass | - |
| P5-TC-122 | R1 sends a point; A polls track | P1 | BE | pass | - |
| P5-TC-123 | Compare what each side sees | P1 | BE | pass | - |
| P5-TC-124 | Tracking screen through ASG → OFD → DELIVERED with the socket down | P1 | CUS | deferred | - |
| P5-TC-125 | ONLINE: place → pay → auto-accept → offer → accept → arrive ... | P0 🔥 | E2E | pass | - |
| P5-TC-126 | COD end to end with cash; then a deposit of the whole balance | P0 🔥 | E2E | pass | - |
| P5-TC-127 | ONLINE → fail (refused) → return received; the worker settles the ... | P1 | E2E | pass | - |
| P5-TC-128 | Delivery invariants | P0 🔥 | BE | pass | - |
| P5-TC-129 | Schemathesis on the rider operations (low example count) | P1 | BE | not run | - |
| P5-TC-130 | Every rider endpoint with no token, a bad token, X-App-Version below t... | P1 | BE | pass | - |
| P5-TC-131 | Prepaid, COD cash, COD UPI and failed → return, with the app killed ... | P0 🔥 | RID | deferred | - |
| P5-TC-132 | Offer by FCM and /ws/v1/rider/; offer.withdrawn; task.updated | P1 | E2E | deferred | - |

Totals (stage 3): 132 cases. Pass 105 (79.5%), fail 1 (TC-16, xfail on BUG-0013), not run 21, deferred 5 (TC-19, 33, 124, 131: device; TC-132: needs P6 and D-19). Priority split of the plan: 73 P0, 56 P1, 3 P2.

## Exit criteria

| # | Criterion (`10 §5.2`) | State |
|---|---|---|
| 1 | All checklist tasks done or deferred with an owner | Not met: T-518, BUG-0013, mini-UAT open |
| 2 | CI green | Not met: not verified by QA; CI on the `develop` to `main` PR pending |
| 3 | All cases run on staging: 100% of P0/P1 and at least 95% of all pass | Not met: 105/132 = 79.5% on the QA instance; 21 cases unrun, including P0 TC-12, 42, 45, 51, 110 |
| 4 | Regression smoke set passed | Met on the QA instance (138 passed, 2 xfail for BUG-0021/0022, at stage 3); the P5 smoke case TC-12 (admin approval screen) is not run |
| 5 | No open P0/P1 bugs | Met: BUG-0013 is P3; BUG-0012 verified |
| 6 | Docs updated | Met for the rider contract (`06 §3`), DL-61 (`04`, `05`, `08`); re-check for the new price rules |
| 7 | Demo done and sign-off recorded | Not met |
| P5 | Mini-UAT with riders | Not met |
| P5 | Real-device run of offers, location, pickup, OTP, COD (TC-19, 33, 124, 131) | Not met |
| P5 | No unauthorised access, stock or cash corruption, duplicate payment | Met: IDOR TC-104 to 109, SQL TC-66, 98, 128 and TC-90 pass |
| P5 | Coverage at least 90% on the `delivery` services | Not checked in the sources read; confirm |
| P5 | Play background-location declaration and video | Not met (D-11, human step) |

## Demo script (staging jqc.jivo.in)

For a non-developer, with three people or three devices: a customer phone, a rider phone and the ops panel on a computer. Test numbers: customer `+919000000001`, rider `+919000000002` (seeded as an active rider in DL-62), OTP `123456` for both. Ask the project manager for the demo ops login (passwords are not written here). Check first that the rider test account exists on staging (see Open questions).

1. Rider: sign in, then slide to Online and allow location. Expected: the rider shows as online on the ops rider map.
2. Customer: place a Cash on delivery order with at least 5 cartons.
3. Store (ops): accept the order, start packing and mark packed.
4. Rider: a full-screen offer appears with a countdown. Press Accept. Expected: the task shows Assigned. Another rider no longer sees the offer.
5. Rider: go to the store, scan the bag QR (or type the 4-character code from the packing slip). Expected: Picked up, then Out for delivery. The customer app shows the rider name and the delivery OTP.
6. Rider: press Arrived at the address. Expected: the customer sees "arrived".
7. Rider: enter the delivery OTP from the customer, then collect cash. Expected: Delivered. The order is DELIVERED and the rider's cash in hand increases by the order amount.
8. Customer: open the order. Expected: Delivered, with an invoice to download. The delivery OTP is no longer shown.
9. Rider: open Earnings and Cash. Expected: the delivery fee is listed once and the cash is listed as owed.
10. Ops: open Cash deposits and record the rider's deposit. Expected: cash in hand goes back to zero. Support users cannot do this.
11. Failed delivery: place another order, take it to Out for delivery, and as the rider use "Customer not available" after the waiting time. Expected: failed delivery, then a return to the store. Ops press "Receive return" and the stock goes back.
12. Customer: after two refused COD deliveries, Cash on delivery is blocked for that customer; ops can allow it again.

## Sign-off

```
Phase 5 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

## Open questions

1. **Tracker versus QA:** the tracker still says "QA verification pending" for every P5 row, while QA stage 3 passed 105 of 132. The PM should decide which rows can move to Completed.
2. **BUG-0013:** the tracker (2026-11-10) says a fix is running; no later commit was found in `git log`. Is it merged?
3. **TC-132** needs the P6 rider socket and D-19 (Firebase). Deferred to P6, or part of this gate?
4. **Demo on staging:** the seeded rider `+919000000002` and the demo store are described in DL-62 for the shared dev DB. The sources do not say whether jqc.jivo.in has them or a store that dispatches. The staging catalog and data may differ.
5. **Rider cash limit and COD limit:** DL-61 (b) says doc 08 wins over doc 04 for the rider cash limit. The store COD limit stays ₹2,000 (user, 2026-11-14). The sources do not say how the two interact for riders, and no decision-log entry records the 2026-11-14 decision.
6. **Minimum 5 cartons and slabs with failed delivery and returns:** `08 §6.4` refunds are written for the old bill. Do slab prices change refund or T14 stock rules? Needs QA cases.
7. **WELCOME90 and referral coupons:** not found in docs or code under that name (see phase 3 file); the referral reward is a personal ₹90 coupon (`65c9248`). Is the coupon reversal on a failed delivery covered?
8. **H-20:** the minimum call attempts (2 assumed) and the start of the 10-minute wait are unconfirmed; the UNASSIGNED to CANCELLED edge is missing from the `08 §3` diagram.
9. **Delivery-service coverage** (at least 90%) was not found in the sources read for this phase.
