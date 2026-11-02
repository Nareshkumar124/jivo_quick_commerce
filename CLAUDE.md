# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state of the repo

**Phase 0 (foundation) and Phase 1 (auth & users) are built and tested** (2026-11-02): OTP login, profile, addresses and staff roles on the backend and both apps, with real-API integration tests passing. The formal phase gate (staging QA, demo, sign-off; `docs/10-testing-strategy.md` §5) is still a human step. Phase 2 is next. The work is run as three parallel subagents per `docs/development-phase.md`.

Repo layout (top-level folders, chosen by the user for readability):
- `backend/`: the Django project
- `customer_app/` and `rider_app/`: standalone Flutter apps, each with its own `pubspec.lock`. **There is no pub workspace.**
- `packages/`: shared Flutter code used via `path: ../packages/<pkg>`:
  - `jivo_core`, `jivo_api`
  - `analysis_options.yaml`
  - `tool/`
- `infra/`, `docs/`, `.github/workflows/`

**Environment specifics** (they differ from the docs' original plan):
- **Database.** The DB is a **remote PostgreSQL 16** server. Its credentials are only in `backend/.env`, which is gitignored. Never print that file or copy the password anywhere. The server is shared, so the only database tests may create or drop is `test_jivo_quick_commerce`. Never run `DROP DATABASE`, `flush` or `CREATE EXTENSION`.
- **No PostGIS yet.** The server has no PostGIS, and the host has no GDAL/GEOS.
  - Settings use the plain `postgresql` engine.
  - `django.contrib.gis` is not installed.
  - `Address` stores `lat`/`lng` as decimals.
  - Phase 2 needs PostGIS on the server, plus GDAL locally or the Docker image, which already has it.
- **Host ports.** Other projects already use some defaults: **6379 is another project's `redis-chai`; never use it or touch that container**, nor `mongo-chai`. 5432 and 8000 are also taken. This project uses:
  - Redis 6380
  - Django 8001 (Android emulator: `http://10.0.2.2:8001`)
  - MinIO 9000/9001
  - Mailpit 1025/8025
- **Git.** Hosted at `github.com/Nareshkumar124/jivo_quick_commerce`, branch `main`. Commit all four Flutter `pubspec.lock` files, because CI uses `--enforce-lockfile`.
- **Test login:** fixed-OTP test numbers `+919000000001`, `…002` and `…003` all use OTP `123456` and send no SMS (local and test settings only; production refuses them). Seeded staff passwords come only from `SEED_DEMO_STAFF_PASSWORD` in `backend/.env`.

**Known gap:** `docs/README.md` links to `docs/plan/00-roadmap.md` and `docs/plan/phase-0-…` through `phase-8-…`. All three subagents treat `docs/plan/phase-N-*.md` as their main brief. **The `docs/plan/` directory does not exist yet.** Don't invent phase files on your own. Tell the user they're missing and offer to draft them from `docs/README.md` (the phase list and file format) and `docs/10-testing-strategy.md` §5 (gate, test case format, sign-off template).

## What is being built

Jivo Quick Commerce is a quick-commerce platform (orders delivered in 10–30 minutes, like Blinkit) that sells only Jivo Wellness products. There are no sellers, commissions or marketplace. The catalog is central, and stock is held per dark store. There are four deliverables:

| Deliverable | Tech | Location (planned) |
|---|---|---|
| Customer app (Android + iOS) | Flutter | `customer_app/` |
| Rider app (Android only in v1) | Flutter | `rider_app/` |
| Backend API | Django + DRF | `backend/` |
| Admin & Ops panel | Django Admin (django-unfold) + server-rendered Ops Console (templates + HTMX + Alpine.js) | `backend/apps/ops_console/` |

## Commands

Toolchain notes:
- **Backend Python:** 3.13, pinned in `backend/.python-version` and `uv.lock`. Always go through `uv run`. The system Python is 3.14; never use it for the project.
- **Library versions:** pinned in `uv.lock` and the `pubspec.lock` files. Don't pick versions ad hoc. CI's shared-version check fails if a package resolves to different versions across the four Flutter lockfiles.
- **Flutter / Dart:** Flutter 3.47.9 / Dart 3.13.7, pinned exactly in CI. `rider_app` uses `compileSdk 37`, and both apps use `minSdk` 26.

Backend (run from `backend/` unless noted):
```bash
docker compose -f infra/docker-compose.yml up -d redis minio mailpit   # from repo root. No postgres service: the DB is remote
uv run python manage.py runserver 0.0.0.0:8001      # dev server (8000 is taken on this host)
uv run pytest                                        # full suite against the remote Postgres + compose Redis (settings: config.settings.test, --reuse-db)
uv run pytest apps/accounts/tests/test_models.py::test_name   # single test (or -k <expr>). Tests live in apps/<app>/tests/ and backend/tests/
uv run ruff check . && uv run ruff format --check .
uv run python manage.py check
uv run python manage.py makemigrations --check       # must be clean
uv run python manage.py check --deploy               # with production settings
uv run python manage.py spectacular --file openapi/schema.yaml   # re-export API contract after ANY API change
uv run python manage.py seed_demo                    # idempotent demo data. Extend it every phase
uv run python manage.py simulate_rider               # sends location pings along a route (Phase 5/6)
uv run pip-audit
```

Mobile (run inside `customer_app/`, `rider_app/` or `packages/<pkg>`; there is no workspace root):
```bash
packages/tool/generate_api.sh                        # from anywhere: regenerate packages/jivo_api from backend/openapi/schema.yaml (needs Java 17 + python3), then `flutter pub get` in each app
python3 packages/tool/check_shared_versions.py       # from repo root: shared packages must resolve to the same version in all 4 lockfiles
flutter pub get --enforce-lockfile
flutter analyze                                      # zero issues required
flutter test                                         # all tests for that project
flutter test test/path/to/some_test.dart             # single test file (add --plain-name "<test name>" for one test)
flutter build apk --flavor dev -t lib/main_dev.dart  # flavors: dev / staging / prod (main_<flavor>.dart)
```

CI gates (`docs/10-testing-strategy.md` §2):
- **Lint:** ruff and `flutter analyze` are clean.
- **Migrations:** `makemigrations --check` is clean.
- **Schema:** generation succeeds with no warnings.
- **Coverage:** backend ≥ 80% overall, and ≥ 90% on the `orders`, `payments`, `inventory`, `cart` and `delivery` services. Flutter domain code and controllers ≥ 60%.
- **Security:** `pip-audit` reports no high or critical issues.

## Architecture (big picture)

**Doc 02 shows one Django project in three process types:**
- **`web`** (ASGI): DRF at `/api/v1/`, Channels WebSockets at `/ws/v1/` and `/ws/ops/live/`, Django Admin at `/admin`, and the Ops Console at `/ops`.
- **`worker`:** Celery.
- **`beat`:** django-celery-beat.

Data and services: PostgreSQL + PostGIS for point-in-polygon serviceability and rider distance, Redis (cache, Celery broker, channel layer, latest rider locations), and S3/MinIO storage (private bucket for KYC documents and invoices). Business areas are separate Django apps under `backend/apps/`, listed in `docs/06-backend-modules-and-api.md` §1.

**The API contract pipeline ties the backend and the apps together:**
- drf-spectacular exports the API schema to `backend/openapi/schema.yaml`, which is committed.
- `packages/tool/generate_api.sh` generates the Dart client `packages/jivo_api` from that file. Generated code is never hand-edited. `normalize_openapi.py` first collapses same-type `oneOf` branches that dart-dio cannot generate.
- In the apps, use `JivoApi(dio: dio, interceptors: const [])` so the generated client doesn't add its own auth interceptors. Import generated types with `show` lists. The schema's error component is `ErrorBody`, so it doesn't clash with `jivo_core`'s `ApiError`.
- At the start of each phase, the backend defines its serializers and endpoints and exports the schema before building internals, so app work can start in parallel.

**Invariants that hold across every layer:**
- **Order status changes** happen only through `orders.services.transition()`. It validates against the transition table T1–T14 in doc 08, writes `OrderStatusHistory`, and raises `INVALID_STATE_TRANSITION` for anything not listed. Delivery task states change only through the delivery services.
- **Money** is computed only by `cart.services.compute_bill()`. The same function serves the cart, order creation and partial-unavailability recalculation. Amounts are `Decimal` and travel as 2-decimal strings (`"249.00"`). The apps never compute totals. They render the bill the server returns.
- **Business logic** lives in `apps/<app>/services.py`. Views and serializers stay thin. Services emit domain events, and side effects (push, SMS, WebSocket broadcasts, dispatch, invoices, refunds) run through `transaction.on_commit` as idempotent Celery tasks.
- **Stock** is reserved when an order is placed, never when items go into the cart. Reservation runs in a transaction with `select_for_update()`, locking rows in variant-id order. Stock is committed (`on_hand` decremented) only at rider pickup (T9). Every `on_hand` change writes a `StockMovement`.
- **Payments:** the server decides success, using the Razorpay signature on verify plus an idempotent webhook keyed on a unique `event_id`. The amount always comes from the server-side order.
- **Data scoping:** querysets are always scoped to the requester. Never fetch by id and then check ownership. Every object endpoint gets an IDOR test, in which another user must get a 404.
- **Error envelope:** `{"error": {"code", "message", "details"}}`. The codes are listed in doc 06 §6, and the apps map codes to messages in one place.
- **Request headers:** apps send `X-App-Name` (`customer`/`rider`), `X-App-Version` and `X-Platform` on every request. Catalog and cart calls also send `X-Store-Id`, which comes from the serviceability check. A client version below the minimum gets `426 APP_UPDATE_REQUIRED`.
- **Time and IDs:** times are stored and sent in UTC (ISO 8601) and shown in IST. `POST /orders/` and the payment endpoints take an `Idempotency-Key` header.
- **Real-time:** WebSockets carry live updates, and apps fall back to polling when a socket drops. FCM push is always sent for important events. The JWT goes in the first socket message, never in the URL.

**Authentication:**
- **Customers and riders:** phone OTP issues simplejwt tokens. Access tokens last 15 minutes. Refresh tokens last 30 days and rotate.
- **One user table:** a single `User` table holds everyone. A `Rider` profile marks a rider, and Groups plus `StaffStoreAccess` mark staff.
- **Staff:** use Django session login for now. `User.auth_id` is reserved for the Jivo Auth SSO decision (D-04). Don't build a custom SSO. That integration is done later with the `integrate-jivo-auth` skill.

## Docs are the source of truth

- `docs/08-order-lifecycle.md` is the **behavioural contract**. It holds the order, delivery-task and payment state machines, the stock rules, the bill formula, dispatch and refunds. Implement it exactly. Every phase is tested against it.
- Other key docs:
  - `06`: endpoints, Celery jobs and error codes
  - `07`: the data model
  - `05`: the Ops Console screens and the role permission matrix
  - `09`: security and compliance (GST, FSSAI, DLT, DPDP, Play background-location policy)
  - `11`: open decisions, each with a recommended default to use until Jivo decides
- **On a scope change,** update the feature doc (`03`–`08`) first, then the phase file. A decision that changes the docs gets an ADR in `docs/adr/`.
- **When docs are ambiguous** about money, stock or permissions, stop and ask instead of guessing.
- **API gaps** raised by the app agents are tracked in `docs/api-requests.md` until the backend resolves them.
- **Delivery runs in phases 0 to 8,** each a vertical slice (backend, panel and app screens together). A phase closes only after the gate in doc 10 §5. Test case IDs use the format `P<phase>-TC-<nn>`, and backend tests reference these IDs in their docstrings.
- **Doc 02 typo:** the repo-layout tree in doc 02 names the root `jio_quick_commerce/`. The actual directory is `jivo_quick_commerce`.

## Subagents and ownership

The agents live in `.claude/agents/`. Their files hold the detailed engineering rules and definitions of done, so read them rather than duplicating their rules here.
- **`django-backend-dev`:** owns `backend/`, `infra/`, the backend CI, and `backend/openapi/schema.yaml`. It never edits the Flutter folders.
- **`flutter-customer-dev`:** owns `customer_app/` and the shared Flutter code in `packages/`: `jivo_core`, `jivo_api`, `tool/` and the shared lint config. It also owns the Flutter CI (`.github/workflows/mobile.yml`).
- **`flutter-rider-dev`:** owns `rider_app/` and builds on `packages/`.
- **Shared code:** changes to `jivo_core` must be **additive only**. Never rename or remove its public APIs. If an app needs an API that's missing, it reports the gap to the backend owner rather than inventing backend behaviour.
- **Git:** no agent commits or pushes unless explicitly asked. Conventional Commits are planned.
