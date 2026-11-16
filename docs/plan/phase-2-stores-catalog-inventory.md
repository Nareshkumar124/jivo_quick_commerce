# Phase 2: Stores, Catalog, Inventory, Home

**Status summary (as of 2026-11-14)**
1. **Build:** done. Backend (`0b801d1`), admin screens (`28a3433`) and customer app (`2274875`) are merged. Roadmap: built 2026-11-03, code on `main` at `3b5066e`. Gate not passed.
2. **QA:** QA run 2 was stopped part-way at the user's request (`eb69ccf`). There is **no Phase 2 verdict** and no Phase 2 section in `qa/docs/02`. The P2 automated tests exist in `qa/tests/test_p2_*.py` (43 case ids), but no results are recorded.
3. **Bugs:** none open at P0/P1/P2. BUG-0008 (notify-me privacy) is verified fixed (2026-11-09). One P3 is open: BUG-0006 (staff session length).
4. **Gate:** open. Not started: QA verdict, staff role matrix check (T-213), phone checks, demo, sign-off. Phase 3 to 8 were started before this gate at the user's request (DL-42, DL-47, DL-54, DL-55, DL-58).
5. **Staging:** `jqc.jivo.in` shows **only water products** since 2026-11-11 (45 products and 4 banners hidden on purpose; the undo file is on the server). The demo store is in West Delhi.

**Goal:** a customer picks a location, sees whether it is serviceable, and browses the store's catalog with live stock.

**Needs (decisions):** D-03 maps (decided: Mappls, not Google Maps, DL-29), D-08 one or two stores, D-17 CSV format, D-21 product sample.

Sources: `docs/development-phase.md` §3, `docs/plan/00-roadmap.md`, `docs/task-tracker.md`, `docs/decision-log.md`, `docs/03` §2.3 to 2.7, `docs/05` §2, `docs/06` §2.3 and §2.4, `docs/10` §5/§8, `qa/tests/test_p2_*.py`, `qa/docs/08`, `qa/docs/10`, `qa/bugs/`.

---

## 1. Scope

| Area | What Phase 2 delivers |
|---|---|
| **Backend** | The `06 §2.3` and `§2.4` endpoints, all catalog calls taking `X-Store-Id`: `serviceability`, `notify-me`, `home`, `categories`, `products`, product detail, `search`, `suggest`, `collections`. Stores with a service-area polygon (PostGIS), opening hours and a serviceability check that always answers 200 (DL-27). Catalog with FSSAI and Legal Metrology fields, images with 256, 512 and 1024 px versions. Inventory with DB constraints and a `StockMovement` ledger. Stock is shown as `orderable_quantity` and "Only N left", never the exact number (DL-26). CSV import and export. Redis caching per store. `Address.is_serviceable`. `StaffStoreAccess`. `seed_demo` data. |
| **Admin panel** | Dark stores (polygon drawn on a map), categories, products with variants and images, collections, banners, inventory with stock adjustments (all through the service), notify-me leads on a map. Bulk CSV import and export. Role matrix per `05 §3`. The `/ops/` foundation and `docs/admin-panel-architecture.md`. |
| **Customer app** | Product tile with ADD stepper (behind a `CartRepository`), home, category, product list and product detail, search with 300 ms debounce and recent searches, location permission and the map pin picker, the not-serviceable screen with Notify me, the store-closed banner, `X-Store-Id` on catalog calls. Real API with an integration test of browsing. The add-to-cart half moved to Phase 3. |
| **Rider app** | Lookahead only: registration, document upload (up to 1 MB), bank details and approval status, all on fakes. Accepted at the Phase 5 gate. |

Later additions that touch Phase 2 screens: real Jivo catalog loaders (DL-67, DL-69), wholesale slab prices (ADR 0001).

---

## 2. Task checklist

`[x]` = merged, with the hash. The tracker status is shown when it is not "Completed". Almost every Phase 2 tracker row is "Testing" because QA run 2 did not finish.

**Backend**
- [x] T-201 API contract (R1). Tracker: Testing. The contract's own hash is not in the tracker; it ships in the P2 backend merge `0b801d1`.
- [x] T-202 Test isolation env vars (`POSTGRES_TEST_DB`, `TEST_REDIS_DB`). Tracker: Testing, no hash.
- [x] T-203a Non-geo internals: catalog, inventory, services, caching, seed (`0b801d1`, `96a2117`; code review: Approve with fixes, all applied)
- [x] T-203b Geo: `DarkStore` polygon, serviceability query, `Address` to PointField (`0b801d1`)
- [x] T-204 ER diagram with P1 entities (`9742d40`, Completed)
- [x] T-205 Address PATCH can clear receiver name and phone (Completed)
- [x] QA bug fixes BUG-0001 to 0005 and 0007 (`96a2117`, Completed); BUG-0008 (QA verified 2026-11-09, `10dbae4`, Completed)
- [x] T-219 Token `app` claim enforced (`9742d40`, Testing)
- [x] T-226 Bulk catalog and image loader, `catalog 0002` approved and applied (`fcb54f3`; fix run `0242f6d`; migration `0003` applied, DL-71). Tracker: Testing.
- [x] Wholesale slab prices in the backend (`c7f6da9`; from the git log, not a tracker row)
- [ ] T-218 DB connection reuse or pooling (In Progress; optional pool in `96a2117`, not enabled)

**Admin panel**
- [x] T-207 Admin screens: stores with map polygon, categories, products and variants, collections, banners, inventory, leads (`28a3433`, follow-up `74b453e`). Tracker: Testing.
- [ ] T-206 Admin architecture and `/ops/` foundation (tracker: In Review; code review Approve with fixes, folded into T-207)
- [ ] T-213 QA admin role-matrix tests, every role (In Progress)

**Customer app**
- [x] T-208 Tile, stepper and layouts, map picker, not-serviceable screen (`2274875`; Mappls launch-crash fix `746288c`). Tracker: Testing.
- [x] T-209 Real contract and API binding; `jivo_api` regenerated (`2274875`, `4d6f5fa`). Tracker: Testing.
- [x] Wholesale slab prices in the customer app (`9468080`; from the git log)

**Rider app**
- [x] T-210 Registration, KYC (up to 1 MB) and bank details lookahead (`84bad46`; tracker: Testing, phone test pending)
- [x] T-211 Rider adopts the promoted `jivo_core` helpers (merged with T-225; tracker: Testing, no own hash)

**Catalog data and design**
- [x] T-222 12 oils from shop.jivo.in (`9b58fa6`, DL-67). Still missing: GST/HSN, FSSAI, SAP codes (H-18). Tracker: In Progress.
- [x] T-228 Catalog from the Amazon Excel sheet and Drive photos, loaded on staging 2026-11-10 (`5ffaef3`, DL-69). Tracker: Testing. QA check of the staging catalog is pending.
- [ ] T-223 Design system with brand values (needs the brand kit, H-19; the UX audit part is merged `d840401`)

**QA and PM**
- [ ] T-215 QA verifies Phase 2 (In Progress; partial run `eb69ccf`, no verdict)
- [ ] T-221 Code review of each module branch (In Progress; P2 backend, admin and customer reviews are done with fixes applied)
- [ ] T-217 P2 integration and the `develop` to `main` PR (Not Started)

**Human steps**
- [x] H-01 PostGIS on the DB server (2026-11-02, 3.4.2)
- [x] H-02 GDAL and GEOS on the dev machine
- [x] H-04 Maps provider and Android config (Mappls, DL-29)
- [ ] H-15 Register the three Android package IDs in the Mappls console (Not Started)
- [ ] H-16 Mappls iOS config and a web or REST key for admin maps (Not Started)
- [ ] H-10 MinIO image `pgsty/minio` approval (Not Started)
- [ ] H-18 Real product data: GST/HSN, FSSAI, label info (Not Started; part done)
- [ ] H-19 Brand kit (Not Started)
- [ ] H-11 Formal gate (Not Started)

**Count: 21 done / 34 total.**

---

## 3. Test cases

The ids below come from the docstrings and file names of the QA automated suite (`qa/tests/test_p2_catalog.py`, `test_p2_serviceability.py`, `test_p2_db.py`, `test_p2_security.py`, `test_p2_clock.py`). They are **not yet written up** in [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md), so that file has no steps for them (the steps are in each test's docstring). The suite does not store a test priority, so the Pri column shows only 🔥 (smoke). Layer is BE (API or database) unless shown.

Status: no run result is recorded in `qa/docs/` (QA run 2 stopped). Cases 17 and 18 are ✅ because the bug files record the verification.

| ID | Title | 🔥 | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P2-TC-01 | Point inside the service area: serviceable, store shown | 🔥 | BE | ⬜ | |
| P2-TC-02 | Points outside every area: 200, not serviceable | 🔥 | BE | ⬜ | |
| P2-TC-03 | 13x13 grid matches PostGIS point-in-polygon | | BE | ⬜ | |
| P2-TC-04 | ETA formula (prep + travel) | | BE | ⬜ | |
| P2-TC-05 | Bad lat/lng give 400, never 500 | | BE | ⬜ | |
| P2-TC-06 | Non-ASCII digits in coordinates | | BE | ⬜ | |
| P2-TC-07 | Serviceability and catalog are public and read-only (405 on writes) | | BE | ⬜ | |
| P2-TC-09/10 | Store open or closed at a shifted clock time | 🔥 | BE | ⬜ | |
| P2-TC-11 | Open and close boundary flips within 60 s | | BE | ⬜ | |
| P2-TC-15 | Notify-me, anonymous | 🔥 | BE | ⬜ | |
| P2-TC-16 | Notify-me, signed in | | BE | ⬜ | |
| P2-TC-17 | Notify-me input validation (incl. non-ASCII phone) | | BE | ✅ (BUG-0002 re-check, run 2) | [BUG-0002](../../qa/bugs/BUG-0002.md) |
| P2-TC-18 | Anonymous repeats never merged (privacy) | | BE | ✅ verified 2026-11-09 | [BUG-0008](../../qa/bugs/BUG-0008.md) |
| P2-TC-18b | Signed-in repeat merges into own lead | | BE | ⬜ | |
| P2-TC-19 | Notify-me throttle (11th request in an hour gives 429) | | BE | ⬜ | |
| P2-TC-20 | `Address.is_serviceable` | 🔥 | BE | ⬜ | |
| P2-TC-21 | `X-Store-Id` rules on all 7 catalog calls | 🔥 | BE | ⬜ | |
| P2-TC-22 | Deactivated store gives 404 `STORE_NOT_FOUND` | | BE | ⬜ | |
| P2-TC-23 | Home feed (banners, categories, collections) | 🔥 | BE | ⬜ | |
| P2-TC-24 | Home is optionally authenticated | | BE | ⬜ | |
| P2-TC-25 | Category tree, only categories with products at the store | 🔥 | BE | ⬜ | |
| P2-TC-26 | Product list: scope, paging, sorts, filters, bad input | 🔥 | BE | ⬜ (page 404 documented: BUG-0004 verified) | [BUG-0004](../../qa/bugs/BUG-0004.md) |
| P2-TC-27 | Money fields and discount equal the database | 🔥 | BE | ⬜ | |
| P2-TC-28 | Stock never exact (`orderable_quantity`, `units_left`) | 🔥 | BE | ⬜ | |
| P2-TC-29 | `default_variant_id` is the first in-stock variant | | BE | ⬜ | |
| P2-TC-30 | Product detail by id and slug, label fields filled | 🔥 | BE | ⬜ | |
| P2-TC-31 | A product not sold at the store is never shown | 🔥 | BE | ⬜ | |
| P2-TC-32 | Search validation and results | | BE | ⬜ | |
| P2-TC-33 | Suggest (blank query gives trending) | | BE | ⬜ | |
| P2-TC-34 | Collection page | | BE | ⬜ | |
| P2-TC-37 | Pagination links stay canonical; host header cache safety | | BE | ⬜ | |
| P2-TC-38 | Image URLs: public, random keys, 3 sizes | | BE | ⬜ | |
| P2-TC-39 | Unicode, NUL and overflow in paths and queries give no 500 | | BE | ⬜ | |
| P2-TC-40 | No personal data in public bodies | | BE | ⬜ | |
| P2-TC-41 | Contract inventory: 9 operations, strict responses | | BE | ⬜ | |
| P2-TC-44 | Anonymous users cannot open P2 admin and ops pages | 🔥 | ADM | ⬜ | |
| P2-TC-45 | Stock check constraints and unique key | 🔥 | BE (SQL) | ⬜ | |
| P2-TC-46 | Ledger movements add up to `on_hand` | 🔥 | BE (SQL) | ⬜ | |
| P2-TC-47 | Prices: 0 < selling price <= MRP | | BE (SQL) | ⬜ | |
| P2-TC-48 | No orphan rows, foreign keys present | | BE (SQL) | ⬜ | |
| P2-TC-49 | Service area is a valid MultiPolygon with a GiST index | 🔥 | BE (SQL) | ⬜ | |
| P2-TC-50 | Slugs never all digits; slugs and SKUs unique | | BE (SQL) | ⬜ | |
| P2-TC-51 | Notify-me rows hold ASCII phones, valid points | | BE (SQL) | ⬜ | |

**Count: 43 cases written in the suite. 2 pass, 0 fail, 41 not recorded (0 deferred).**

Not yet written with ids (do not invent them; QA to add): the admin role matrix for the P2 modules (T-213), CSV import and export, stock adjustment through the panel, and every phone case (home, search, map picker, not-serviceable, store-closed). The id gaps 08, 12 to 14, 35, 36, 42 and 43 are not defined in the sources.

---

## 4. Exit criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | All tasks done or deferred with owner and target | Not met | T-206, T-213, T-215, T-217, T-218, T-223 and the human steps H-10, H-11, H-15, H-16, H-18, H-19 are open. |
| 2 | CI green (lint, tests, coverage, migrations, schema) | Not met | Dev reports for P2 were green when merged (407 tests at the contract step). CI on the `develop` to `main` PR is not recorded. |
| 3 | Phase cases on staging: 100% P0/P1 priority pass, 95% of all | Not met | No P2 results recorded. Cases written for demo seed data, not for the staging water catalog. |
| 4 | Smoke set from P0 and P1 passed | Not met | Passed on the QA instance in later stages; not run on staging. |
| 5 | No open P0/P1 bugs | Met | None open. BUG-0006 (P3) is open. |
| 6 | Documentation updated (feature docs, this file, schema) | Not met | `06 §2.3/2.4`, `03` and `07` were updated and the ER diagram added (T-204). Not checked as a whole. QA docs have no P2 section. |
| 7 | Demo done and sign-off recorded | Not met | Not started (H-11). |
| 8 | Serviceability p95 under 150 ms (`09 §1`) | Not met | No measurement recorded in the sources. |
| 9 | Role matrix verified for every role on the P2 admin modules | Not met | T-213 In Progress. |
| 10 | Real-API browse test on a phone | Not met | The customer integration test of browsing passes (T-209). The phone run on staging is not recorded for Phase 2. |
| 11 | Stock changes only through the inventory service | Met (code level) | Admin adjustments go through the service (T-207). SQL checks P2-TC-45 and 46 are written but not recorded. |

---

## 5. Demo script (for a non-developer, on staging `jqc.jivo.in`)

Needs: a phone with the **staging** customer app, a laptop, and the PM. Staging shows only **water products** (the other categories are hidden on purpose). The test store is in West Delhi; ask the PM for the exact test location. Test login: `+919000000001`, OTP `123456`. Staff passwords come from the PM in person.

**Part A: customer app**
1. Open the app and sign in. On the location step choose the test location. If the map does not load, use the search box to pick an address (the map key for the staging app ID is still pending, H-15). **You should see:** a delivery time such as "Delivery in 14 mins" and the address at the top.
2. Look at Home. **You should see:** banners, categories and rails of water products with price, struck-out MRP and an ADD button.
3. Type `water` in the search bar. **You should see:** suggestions after a short pause, then results as product tiles.
4. Open a product. **You should see:** photos, size choices, price per size, and a quantity box after ADD. If the product has a minimum order quantity, ADD starts at that number. If it has wholesale rates, a "Wholesale rates" table shows.
5. Find a product that is low in stock. **You should see:** "Only N left" (never the exact stock).
6. Change the location to a far away place (for example another city) on the map. **You should see:** "We're not in your area yet". Tap Notify me and enter a number. **You should see:** a thank-you message.

**Part B: staff panel (laptop)**
7. Open `https://jqc.jivo.in/admin/` and sign in as a Catalog Manager or Super Admin. **You should see:** Dark stores, Categories, Products, Collections, Banners, Inventory.
8. Open Dark stores and the test store. **You should see:** the service area drawn on a map, opening hours and the "accepting orders" switch.
9. Open Inventory and make a stock adjustment of +1 on one water SKU with the reason "demo". **You should see:** a new line in the stock ledger. Then adjust -1 with the same reason to undo it.
10. Open Notify-me leads. **You should see:** the lead from step 6 on a map. Only Super Admin and Ops can see it.
11. Back in the app, pull to refresh the product from step 5. **You should see:** the stock text changes within a few minutes at most (the server clears its cache when stock changes).

Stop and report any crash, blank screen or error showing code or file names.

---

## 6. Sign-off

```
Phase 2 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

---

## 7. Open questions

1. **Missing P2 test case write-up:** `qa/docs/02` has no Phase 2 section (its title says "Phases 0, 1, 3, 4 and 5"). The ids here come only from `qa/tests/test_p2_*.py` docstrings. QA needs to add them and record results.
2. **No QA verdict for P2:** QA run 2 stopped at the user's request (`eb69ccf`). `qa/docs/10` has no Phase 2 section.
3. **Maps provider:** `development-phase.md` §3 still says D-03 is Google Maps. The decision is Mappls (DL-29, doc 11). That plan file is out of date.
4. **Staging maps:** H-15 (register the staging package ID in the Mappls console) is "Not Started". The sources do not say whether the map picker works on the staging build.
5. **Catalog compliance gap:** `09 §4` and P2-TC-30 expect FSSAI, GST and HSN data. The loaded catalog uses a GST 5% placeholder and has no FSSAI or HSN yet (T-228, H-18).
6. **Test data mismatch:** the P2 automated cases name the seeded demo data (Gurugram polygon, mustard oil, pumpkin seeds). Staging has the real catalog (water only visible) and a West Delhi store. Some cases may not apply on staging as written.
7. **`main` and gating:** `main` holds Phase 2 code at `3b5066e` without a gate (DL-34, DL-36), while `CLAUDE.md` says `main` holds only gated work.
8. **Tracker statuses:** almost every P2 row is "Testing", and T-206 says "In Review" although its work seems to be inside the merged T-207. T-201, T-202 and T-211 have no merge hash of their own.
9. **Stale bug report:** `qa/docs/08` still lists BUG-0008 as "Open"; the tracker and the bug file say verified (2026-11-09).
10. **Rider lookahead:** T-210's phone test is pending, and the rider KYC policy answers (H-17) are open. The tracker says these are accepted at the Phase 5 gate.
11. **Performance target:** is a serviceability p95 measurement (under 150 ms) required before sign-off? None is recorded.
