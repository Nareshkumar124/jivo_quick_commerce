# Phase 6: Real-time tracking & notifications

Goal (`development-phase.md` §3): live tracking within 5 s, push for every event in `08 §9`, and live ops screens. Needs D-11 (Apple account) and D-19 (FCM projects).

## Status summary (as of 2026-11-14)
1. **Build: done.** Backend, customer, rider and admin P6 are merged to `develop` (hashes below). The roadmap marks the build ✅ (2026-11-06).
2. **Gate: not passed.** QA stage 3 (`3a59367`, 2026-11-10): 47 of 59 cases pass, verdict **Not ready**.
3. **Bugs:** BUG-0021 and BUG-0022 are fixed (`ca8e69c`, merged `e61d8c0`). BUG-0020 is fixed (merged `2f7c942`). QA has **not** re-checked any of the three yet.
4. **Waiting on people:** push is a no-op until the FCM projects exist (D-19). Real SMS waits on D-02 (DLT). The Apple account (D-11) is open.
5. **Not done yet:** device cases (P6-TC-17, P6-TC-57), the "profile" cases (TC-09, 20, 32, 33, 44) and the config reviews (TC-45, 54). Demo and sign-off are open.

---

## 1. Scope

### Backend (`backend/`)
- `realtime` app: order socket `/ws/v1/orders/{id}/`, rider socket `/ws/v1/rider/`, ops socket `/ws/ops/live/` (`06 §4`). The JWT goes in the first message, never in the URL.
- `broadcast_ws`, rider location fan-out, ETA formula (`08 §8`).
- Notification templates and `send_push` / `send_sms` with retries, per `08 §9`. Push stays a no-op until D-19.
- Inbox endpoints (`06 §2.7`) and the jobs `purge_old_locations`, `purge_old_notifications`, `sweep_stuck_sends`.
- WebSocket JSON examples in the schema (`Ws…Message` components) and `WebsocketCommunicator` tests.

### Admin panel (`backend/apps/ops_console/`)
- Live board and rider map get live updates from `/ws/ops/live/`. Polling stays as the fallback.
- The feed is scoped to the user's stores and needs the `orders.view_order` permission (`05 §3`).
- Alerts (SLA breach, delivery failed, dispatch unassigned).

### Customer app (`customer_app/`)
- Tracking screen on the WebSocket, with a 10 s polling fallback.
- FCM adapter and local notifications (needs D-19), deep links (`03 §2.12`), inbox.

### Rider app (`rider_app/`)
- `/ws/v1/rider/` for `offer.*` and `task.updated`, with polling and FCM as fallbacks.
- Inbox. Offer latency target: under 3 s (`09 §1`).

## 2. Task checklist
Sources: `docs/task-tracker.md` and `plan/00-roadmap.md`. A box is ticked only for merged work. QA verification is a separate line and is still open.

- [x] T-611 BE: WS contract examples, `realtime` app, `notifications`, inbox, purge jobs. Merged `b8eead2`.
- [x] T-612 BE: rider location fan-out, ETA, rider socket events. Merged `d29ed94`.
- [x] T-613 CUS: tracking over WS with polling fallback, inbox, FCM adapter. Merged `0e55bb4`.
- [x] T-614 RID: rider socket with polling and FCM fallback, inbox. Merged `1ef1ba3`.
- [x] ADM P6: live Ops Console, ops alerts. Merged `ee35f0a`.
- [x] BUG-0021 (T9 pickup sends no `order.status` OUT_FOR_DELIVERY): fixed `ca8e69c`, merged `e61d8c0`. Review: Approve (2 Minor, go to `backend/p8-bugs`).
- [x] BUG-0022 (`rider.location` heading always null): fixed `ca8e69c`, merged `e61d8c0`.
- [x] BUG-0020 (oversized socket message closes 1011, not 1009): fixed, merged `2f7c942`.
- [ ] QA re-verification of BUG-0020 / 0021 / 0022 (tracker status: Testing).
- [ ] QA verification of T-611..T-614 (tracker: "QA verification pending"; QA passed 47 of 59 on the QA instance).
- [ ] D-19: Firebase projects and FCM keys (needed before real push works).
- [ ] D-11: Apple Developer account (organisation, D-U-N-S).
- [ ] D-02: DLT registration and SMS provider (real order SMS).
- [ ] Device runs by the PM on the user's phone: P6-TC-17 and P6-TC-57.
- [ ] QA "profile" cases: TC-09, 20, 32, 33, 44.
- [ ] DevOps config reviews: TC-45 (`notifications.E001` on staging) and TC-54 (`--ws-max-size 65536`).

## 3. Test cases
Steps and expected results: [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md), section "Phase 6". Layers: BE backend/API, E2E end to end, ADM admin/ops, CUS/RID device. Status: ✅ passed (`8f87d7b` = 2026-11-06, `efb3c3d` = 2026-11-09/10), ❌ failed, ⏭ not run. Total 59: 47 ✅, 3 ❌, 9 ⏭. Titles below are short summaries written for this file (the repository has no separate title column).

| ID | Title | Pri | Layer | Latest status | Bug |
|----|-------|-----|-------|---------------|-----|
| P6-TC-01 🔥 | Order socket: `auth.ok` then one snapshot | P0 | BE | ✅ 8f87d7b | |
| P6-TC-02 🔥 | Token in the URL is ignored | P0 | BE | ✅ 8f87d7b | |
| P6-TC-03 | Auth by subprotocol, token not echoed | P0 | BE | ✅ 8f87d7b | |
| P6-TC-04 | Bad tokens close with 4401 | P0 | BE | ✅ 8f87d7b | |
| P6-TC-05 | No message in 10 s closes 4408 | P1 | BE | ✅ 8f87d7b | |
| P6-TC-06 | Bad first message closes 4400 | P0 | BE | ✅ 8f87d7b | |
| P6-TC-07 🔥 | Another user's order: 4404, no leak | P0 | BE | ✅ 8f87d7b | |
| P6-TC-08 | Token renewal on an open socket | P0 | BE | ✅ 8f87d7b | |
| P6-TC-09 | Socket closes at token expiry | P1 | BE | ⏭ needs `shorttoken` profile | |
| P6-TC-10 | `ping`/`pong`; unknown type gives `error` | P1 | BE | ✅ 8f87d7b | |
| P6-TC-11 🔥 | Cancel shows on the socket within 3 s | P0 | E2E | ✅ efb3c3d | |
| P6-TC-12 | OTP never on a socket | P0 | BE | ✅ 8f87d7b | |
| P6-TC-13 | Deleted user's token gives 4401 | P1 | BE | ✅ efb3c3d | |
| P6-TC-14 🔥 | `rider.location` reaches only the order owner | P0 | E2E | ❌ (only `heading` wrong) | BUG-0022 (fixed, re-check pending) |
| P6-TC-15 | ETA follows the `08 §8` formula, rate limited | P1 | BE | ✅ efb3c3d | |
| P6-TC-16 | No location before pickup or after delivery | P0 | BE | ✅ efb3c3d | |
| P6-TC-17 | Customer polling fallback on a dropped socket | P0 | CUS | ⏭ device run (PM) | |
| P6-TC-18 | Reconnect gives a fresh snapshot | P1 | BE | ✅ 8f87d7b | |
| P6-TC-19 🔥 | Rider socket: riders only (4403 otherwise) | P0 | BE | ✅ 8f87d7b | |
| P6-TC-20 | Suspended rider closed at re-check | P0 | BE | ⏭ needs `wsrecheck` profile | |
| P6-TC-21 🔥 | `offer.new` within 3 s of dispatch | P0 | E2E | ✅ efb3c3d | |
| P6-TC-22 | `offer.withdrawn` reasons | P0 | BE | ✅ efb3c3d | |
| P6-TC-23 | Expired offer gives `offer.withdrawn` EXPIRED | P1 | BE | ✅ efb3c3d | |
| P6-TC-24 | `task.updated` change types | P0 | BE | ✅ efb3c3d | |
| P6-TC-25 | Cash update event matches `/rider/cash/` | P1 | BE | ✅ efb3c3d | |
| P6-TC-26 🔥 | Offer to R1 is not seen by R2 | P0 | BE | ✅ efb3c3d | |
| P6-TC-27 🔥 | Ops feed opens with session and Origin | P0 | ADM | ✅ 8f87d7b | |
| P6-TC-28 | Ops feed refuses bad cookie or Origin | P0 | ADM | ✅ 8f87d7b | |
| P6-TC-29 🔥 | Ops feed per role | P0 | ADM | ✅ 8f87d7b | |
| P6-TC-30 🔥 | Ops feed scoped to permitted stores | P0 | ADM | ✅ efb3c3d | |
| P6-TC-31 | No customer data on the ops feed | P0 | ADM | ✅ efb3c3d | |
| P6-TC-32 | Ops feed closes on logout or expiry | P1 | ADM | ⏭ needs profile | |
| P6-TC-33 | `alert` events to the store's feeds | P1 | ADM | ⏭ needs timer profile | |
| P6-TC-34 | `rider.status`/`rider.location` to home store | P1 | ADM | ✅ efb3c3d | |
| P6-TC-35 🔥 | Inbox list for the customer | P0 | BE | ✅ 8f87d7b | |
| P6-TC-36 🔥 | Mark read; IDOR gives 404 | P0 | BE | ✅ 8f87d7b | |
| P6-TC-37 | Read-all twice | P1 | BE | ✅ 8f87d7b | |
| P6-TC-38 🔥 | No OTP in the inbox | P0 | BE | ✅ 8f87d7b | |
| P6-TC-39 | Inbox errors use the envelope | P1 | BE | ✅ 8f87d7b | |
| P6-TC-40 | Inbox paging cap and links | P2 | BE | ✅ 8f87d7b | |
| P6-TC-41 🔥 | SMS only for the allowed events | P0 | BE | ✅ 8f87d7b | |
| P6-TC-42 | No SMS "SENT" without a DLT id | P0 | BE | ✅ 8f87d7b | |
| P6-TC-43 🔥 | OTP blanked after sending | P0 | BE | ✅ 8f87d7b | |
| P6-TC-44 | Retries and stuck-send sweep | P1 | BE | ⏭ needs gateway-fault profile (unit tests cover it) | |
| P6-TC-45 | `check --deploy` refuses console push on staging | P1 | BE | ⏭ config review | |
| P6-TC-46 | Cancel text quotes the stored refund | P1 | BE | ✅ 8f87d7b | |
| P6-TC-47 | Beat schedule has purge and sweep jobs | P1 | BE | ✅ 8f87d7b | |
| P6-TC-48 | Retention: 90 d notifications, 30 d locations | P1 | BE | ✅ 8f87d7b | |
| P6-TC-49 🔥 | Max 6 sockets per user (4429) | P0 | BE | ✅ 8f87d7b | |
| P6-TC-50 | Oversized message closes 1009 | P0 | BE | ❌ (was xfail) | BUG-0020 (fixed `2f7c942`, re-check pending) |
| P6-TC-51 | 11 bad messages close 4400 | P1 | BE | ✅ 8f87d7b | |
| P6-TC-52 | Malformed frames never crash the server | P1 | BE | ✅ 8f87d7b | |
| P6-TC-53 | No leaked socket slots | P2 | BE | ✅ 8f87d7b | |
| P6-TC-54 | ASGI frame cap 64 KiB in staging flags | P1 | BE | ⏭ DevOps config review | |
| P6-TC-55 🔥 | No JWT in server logs | P0 | BE | ✅ 8f87d7b | |
| P6-TC-56 | Schema has one `Ws…Message` per type | P1 | BE | ✅ 8f87d7b | |
| P6-TC-57 | Rider polling and FCM fallback | P0 | RID | ⏭ device run (PM) | |
| P6-TC-58 🔥 | `notification.new` and unread count | P0 | BE | ✅ efb3c3d | |
| P6-TC-59 🔥 | Polling fallback equals the socket (full walk) | P0 | E2E | ❌ | BUG-0021 (fixed, re-check pending) |

## 4. Exit criteria
| # | Criterion | Met? |
|---|-----------|------|
| 1 | All P0/P1 cases passed (`10 §5`) | **Not met.** TC-14, 50, 59 are ❌ pending re-check; TC-17, 20, 57 (P0) and several P1 cases are not run. |
| 2 | No open P0/P1 bug | **Met.** QA stage 3: none open. BUG-0021 is P2, BUG-0020 and BUG-0022 are P3. All are fixed but not re-verified. |
| 3 | Order status and cancel show on the socket within 3 s | **Met on the QA instance** (TC-11: 0.2 to 0.4 s). Not yet shown on a phone. |
| 4 | Rider offer arrives within 3 s (`09 §1`) | **Met on the QA instance** (TC-21). Not measured on a phone. |
| 5 | Polling fallback works when the socket drops | **Not met.** Device cases TC-17 and TC-57 are not run, and TC-59 fails until BUG-0021 is re-verified. |
| 6 | Push sent for every `08 §9` event | **Not met.** `send_push` is a no-op until D-19. |
| 7 | Real SMS delivered with DLT templates | **Not met.** Waits on D-02. |
| 8 | Full 🔥 smoke set of earlier phases re-run on staging | **Not met.** The stage 3 smoke run was on the QA instance (138 passed, 1 skipped, 2 xfailed), not on staging. |
| 9 | Demo given and sign-off recorded | **Not met.** |

## 5. Demo script (staging `https://jqc.jivo.in`)
Use phone `+919000000001` (customer) and `+919000000002` (rider), both with OTP `123456`. Staff login details come from the PM (staff use a two-step code, DL-70). Push will not show until D-19.

1. Open the customer app (staging build). Sign in as `+919000000001`.
2. Add any product to the cart and place a **COD** order.
3. Open the ops console in a browser and sign in as store staff. The order should appear on the live board **without refreshing**.
4. Open the rider app. Sign in as `+919000000002` and go online. The offer card should appear within about 3 seconds. Accept it.
5. In the ops console, mark the order packed. The rider app updates by itself.
6. The rider picks up the order. The customer app should show "Out for delivery" and the rider moving on the map (use the route simulator if nobody walks).
7. Turn on airplane mode on the customer phone for 20 seconds, then turn it off. The status keeps updating (polling first, then the socket again).
8. Open the inbox in the customer app. Each step shows an entry. No delivery code is visible in the inbox.
9. Place another order and cancel it before it is packed. The status changes to Cancelled on screen within a few seconds.

## 6. Sign-off (template from `10 §8`, empty)
```
Phase 6 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

## 7. Open questions
1. **Case counts differ.** The roadmap and tracker say P6 "47/59". The QA stage 3 table in `qa/docs/10` shows "45 / 57". Possibly the 57 excludes 2 skipped cases. QA should confirm.
2. **Readiness report contradicts itself.** An earlier section (lines ~161, 168) says the T-612 cases were "not run". The stage 3 section shows them passed. This file uses the newer section.
3. **Admin P6 has no T-id** in the tracker. Only the roadmap names it (`ee35f0a`).
4. **TC-23 and TC-25** mention contract ambiguity P6-A1 (`offer.expired` vs `offer.withdrawn`, and the cash event). These sources do not say whether `06 §4` was updated.
5. **Apple D-11:** `development-phase.md` §3 says P6 needs the Apple account. The roadmap does not say if it is open. Treated as open here.
