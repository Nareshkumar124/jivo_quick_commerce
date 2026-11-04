# Continue Jivo Quick Commerce on another machine

Use this file to pick up the project on a new machine with Claude Code.

**Contents**
1. Set up the machine.
2. Copy the secret files, which are not in git.
3. Paste the prompt at the end into Claude Code.

> **This repo is public.** Never commit secrets: `backend/.env`, passwords, the DB host, or the Mappls config files. Run a secret scan before every push.

---

## 1. State on 2026-11-04 (end of the first machine's session)

### Phases

| Phase | State |
|---|---|
| P0 Foundation | Built and pushed |
| P1 Auth & users | Built and pushed; formal QA sign-off still open |
| P2 Stores, catalog, inventory, home | Code done and merged. QA run 2 was stopped part-way at the user's request, so there's no verdict yet. BUG-0006 is fixed but not re-verified. |
| **P3 Cart, checkout, payments** | **About 85% done.** Started before the P2 gate at the user's request (DL-42). |

### Phase 3: done, reviewed and merged

- **Backend contract and internals:**
  - cart, `compute_bill`, coupons with holds
  - `place_order` (stock reservation, `Idempotency-Key`, `PRICE_CHANGED`)
  - `transition()` for T3, T4 and T5
  - Razorpay verify and webhook, retry-payment and cancel
  - `expire_unpaid_orders` (a Celery beat task)
  - T3a refunds
  - BUG-0008
  - Payments use a fake gateway in local and test settings. Deployed settings refuse it (system checks `payments.E001` and `E003`).
- **Shared remote DB:** migrated (12 Phase 3 migrations) and seeded on 2026-11-03, with the user's approval. The demo coupons are `JIVO50`, `JIVO10`, `OILS15`, `WELCOME100` and `JIVOSTAFF`. Store GGN-01 uses the D-09 pricing.
- **API smoke test on :8001 passed:**
  - COD order: PLACED / COD_PENDING.
  - Fake ONLINE order: verified, then PLACED / PAID.
- **Customer app:**
  - cart, bill, coupons, tip and instructions
  - checkout (COD or online), success and payment-failed screens
  - `PaymentLauncher` (real Razorpay, plus a fake sheet only in dev with `rzp_fake_` keys)
  - `PAYMENT_PENDING` recovery on launch
  - all of it bound to the real API in the dev flavor
  - 220 tests pass. The launch check on the phone passed (0 crashes with the Razorpay SDK).
- **Rider app:** T-225 (earnings, cash ledger, history, payouts and profile, on fakes) and T-211 (jivo_core helpers). 342 tests pass.

### Phase 3: committed as WIP, unreviewed (finish these first)

1. **Backend R2b review-fix run** (commit `f0ad1cc` on `backend/phase-3`, merged to `develop` and `main` as WIP).
   - **Scope:**
     - `process_refund` idempotency: lock the `Refund` row, a Razorpay refund idempotency header, and no retries on 4xx.
     - Two-thread concurrency tests: webhook×webhook, verify×webhook, expire×expire, capture×cancel.
     - The `mark_payment_failed` race.
     - Razorpay auto-capture (`payment_capture: 1`).
     - A `payment.refund_failed` ops alert.
     - The BUG-0008 residual: an anonymous merged repeat must not return the old lead's `id` and `created_at`.
   - **State:** ruff, `makemigrations --check` and the schema export are clean. **The full test suite has not been run on this state.**
   - **To do:** finish whatever the run left half-done, run the full suite, code review, then fix.
2. **Admin Phase 3 screens, T-304** (commit `77d5949` on `admin/phase-3`, merged as WIP).
   - **Scope:**
     - per-store `PricingConfig` with defaults
     - coupon CRUD
     - read-only orders and payments, store-scoped, with the phone masked for Store Staff
     - the customer `cod_blocked` flag
   - **State:** the agent reported its 370 Phase 3 admin tests passing; ruff and `manage.py check` are clean.
   - **To do:** run the full suite with `POSTGRES_TEST_DB=test_jivo_quick_commerce_admin TEST_REDIS_DB=14`, then code review.

### Phase 3: still to do

- **Install the latest customer dev build on the phone.** It was built from `develop`; the phone disconnected mid-install.
- **Manual checkout test on the phone:** COD and a fake ONLINE payment.
- **Optional S3-B integration test.** `flutter drive` on the Realme phone was unreliable before.
- **Close Phase 3:** QA verification, then a PR from `develop` to `main` at the gate. `main` currently also holds the WIP above.

### Phase 4 carry-overs

These are in `docs/task-tracker.md`, IDs T-401c to T-404c:
- an ops view for FAILED or PENDING refunds
- refund `payment_status` and a cap on total refunds
- gateway calls made outside row locks
- `skip_locked` on the expiry task
- the DevOps env-example mirroring, Celery beat, staging Razorpay webhook config, and a CI check of the native Razorpay pin

### Waiting on the user or Jivo

- **Razorpay test keys** (D-01). They go only in `backend/.env`.
- **Mappls console registration** of `in.jivo.quick.dev`, `.staging` and `in.jivo.quick` with the debug-key SHA-1 and SHA-256 (listed in `customer_app/README.md`). Then download a fresh config. Until that happens, "Pick on map" shows "Map isn't available".
- **Confirmation of the PM defaults marked ⚠** in `docs/decision-log.md`, especially DL-43 to DL-46, the Phase 3 money, coupon and order rules.
- **Real data:** product data, the brand kit, real store details (H-18, H-19).
- **Security housekeeping:**
  - make the GitHub repo private (H-03);
  - rotate the DB password and the DB server's SSH password (both were shared in chat);
  - remove the old temporary local DB container `jivoqc-pg-local` on the first machine.

---

## 2. Set up the new machine

**Tools** (exact versions are pinned; see `CLAUDE.md` → Commands):
- **Flutter 3.47.9 / Dart 3.13.7.** Android SDK with `compileSdk 37`; both apps use `minSdk 26`.
- **Python 3.13 via `uv`.** Never use the system Python. Run backend commands through `uv run`.
- **Java 17**, used by `packages/tool/generate_api.sh`, which runs openapi-generator 7.26.0.
- **Docker**, for Redis, MinIO and Mailpit from `infra/docker-compose.yml`.
- **GDAL and GEOS** on the host (GeoDjango/PostGIS).
- **`adb`**, for the USB phone. **Never use the Android emulator** (user instruction).

**Code:**
```bash
git clone https://github.com/Nareshkumar124/jivo_quick_commerce.git
cd jivo_quick_commerce
git checkout develop    # integration branch; main also has everything as of 2026-11-04
```

**Per-agent worktrees.** These are gitignored; recreate them:
```bash
mkdir -p .worktrees
for a in backend admin customer rider; do git worktree add .worktrees/$a $a/phase-3; done
git worktree add .worktrees/qa qa/phase-2
```

### Secret files: copy them from the old machine securely, never through git

| File | Contents | Notes |
|---|---|---|
| `backend/.env` | Remote PostgreSQL credentials (separate `POSTGRES_*` vars; the password contains `@`, so never build a `DATABASE_URL`), `SEED_DEMO_STAFF_PASSWORD`, and other dev settings | Required. Run `chmod 600` on it. Worktrees need their own copy or a symlink, at `.worktrees/<agent>/backend/.env`. |
| `~/.config/jivo-quick-commerce/mappls/*.a.olf` and `*.a.conf` | Mappls (MapmyIndia) Android SDK config. The active pair is `app1793687503179…` | Then run `customer_app/tool/setup_mappls.sh` to link them into the build. |
| `qa/private/` (optional) | QA security reproduction details. Gitignored because the repo is public. | On the old machine they are in `.worktrees/qa/qa/private/`. |
| `backend/.env.localdb` (optional) | Credentials for the old temporary local DB | Probably not needed any more. |

**Remote DB access:** the DB server may only accept known IP addresses. If the backend can't connect from the new machine (connection timeouts), the server's firewall or `pg_hba` needs the new machine's IP. That needs the DB server admin.

**Start the local stack** (from the repo root):
```bash
docker compose -f infra/docker-compose.yml up -d redis minio mailpit
cd backend
uv sync
uv run python manage.py migrate --plan       # should show nothing pending (shared DB already migrated)
uv run python manage.py runserver 127.0.0.1:8001
uv run celery -A config worker -B --concurrency 2 --loglevel INFO   # second terminal: expiry + refunds
```
If the shell has `POSTGRES_*` variables exported from elsewhere, run `unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD` first so `backend/.env` applies.

**Admin panel:** http://127.0.0.1:8001/admin/ and http://127.0.0.1:8001/ops/
- Staff logins: `superadmin@jivo.test`, `catalog@jivo.test`, `store.manager@jivo.test`, `store.staff@jivo.test`, `ops@jivo.test`, `support@jivo.test`, `finance@jivo.test`.
- Their password is `SEED_DEMO_STAFF_PASSWORD` in `backend/.env`.

**Test app logins:** `+919000000001`, `…002` and `…003`, all with OTP `123456` (local and test settings only). Address with delivery coverage at store GGN-01 (Gurugram): around lat 28.471, lng 77.044.

**Phone builds** (the user's USB phone, Realme RMX5056):
```bash
adb reverse tcp:8001 tcp:8001 && adb reverse tcp:9000 tcp:9000
cd customer_app && bash tool/setup_mappls.sh
flutter build apk --flavor dev -t lib/main_dev.dart --dart-define=API_BASE_URL=http://localhost:8001
adb install -r build/app/outputs/flutter-apk/app-dev-release.apk
```
- The rider app is the same: in `rider_app/`, package `in.jivo.rider.dev`.
- A build signed with a different debug key **can't update** an installed app (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Ask the user before uninstalling, because they lose that app's login.
- To install over the old machine's builds without uninstalling, copy `~/.android/debug.keystore` from the old machine. The Mappls registration is also tied to that key's SHA-1.

---

## 3. Working rules (from CLAUDE.md and the user's instructions)

- **The main Claude session is the PM/Tech Lead.** It runs the agents in `.claude/agents/` in parallel, in their worktrees, on the `<agent>/phase-N` branches.
- **Agents never commit.** The PM reviews, commits, runs the `code-reviewer` agent, then merges into `develop` with `--no-ff`.
- **Agent reports** use the `docs/development-phase.md` §9.3 format.
- **The PM keeps these docs up to date:**
  - `docs/task-tracker.md` (only the PM edits it)
  - `docs/decision-log.md` (DL-xx entries; ⚠ = waiting for the user)
  - `docs/plan/00-roadmap.md`
  - `docs/api-requests.md`
- **Contract-first.** The backend exports `backend/openapi/schema.yaml`. The PM runs `packages/tool/generate_api.sh` at sync points, then `flutter pub get` in both apps, then `python3 packages/tool/check_shared_versions.py`.
- **Shared remote DB:**
  - Tests may only create or drop databases whose names start with `test_jivo_quick_commerce`. The admin agent uses `POSTGRES_TEST_DB=test_jivo_quick_commerce_admin TEST_REDIS_DB=14`.
  - Never run `DROP DATABASE` or `flush`.
  - **Ask the user before running `migrate` on the shared DB.**
  - Never print `backend/.env` or any credential.
- **Ports:** never use 6379 (another project's Redis) or touch the `redis-chai` / `mongo-chai` containers. This project uses Redis 6380, Django 8001, MinIO 9000/9001 and Mailpit 1025/8025.
- **Business invariants:**
  - Money comes only from `cart.services.compute_bill()`, as Decimal on the server and 2-decimal strings on the wire. The apps never compute totals.
  - Order status changes only through `orders.services.transition()`.
  - Stock is reserved at placement and committed at pickup (T9).
  - `docs/08-order-lifecycle.md` is the behavioural contract. When money, stock or permissions are ambiguous, ask; don't guess.
- **No Android emulator.** Use the user's USB phone. Don't run `flutter test` or `pub get` while `flutter build` runs in the same checkout.
- **Mappls config files are secrets:** gitignored, never printed or committed.
- **Before every push:** secret-scan the diff (DB host or password, staff password, keys). The repo is public.
- **The user** writes short messages, often asks "how much work is done", and prefers fast parallel progress. They said not to start a new phase until the current one is complete, unless they explicitly ask.

---

## 4. Prompt to paste into Claude Code on the new machine

```
You are continuing the Jivo Quick Commerce project as Project Manager / Tech Lead.
Read CLAUDE.md, prompt.md (state, setup, rules), docs/development-phase.md §9,
docs/task-tracker.md and docs/decision-log.md first.

Current phase: Phase 3 (cart, checkout, payments), ~85% done. Next steps, in order:
1. Recreate the per-agent worktrees (prompt.md §2) and check backend/.env exists
   (never print it). Start Redis/MinIO/Mailpit, the :8001 server and the Celery
   worker+beat.
2. Finish the WIP backend R2b review-fix run (commit f0ad1cc, scope in prompt.md §1)
   with the django-backend-dev agent in .worktrees/backend: complete the work, run the
   full suite, then code-review it and merge.
3. Finish the WIP admin T-304 run (commit 77d5949) with admin-panel-dev in
   .worktrees/admin: full suite, code review, merge.
4. Regenerate jivo_api if the schema changed; build the customer dev APK; install it
   on my USB phone (no emulator) and let me test checkout with COD and a test payment.
5. Update the tracker, then tell me what's left to close Phase 3.
Don't start Phase 4 until I say so. Ask me before running migrate on the shared DB.
```
