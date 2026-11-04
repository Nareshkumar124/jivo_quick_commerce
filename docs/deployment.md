# Deployment & Environments

This file records what is **actually set up today**, plus the target for the environments that don't exist yet.
- Target architecture: [`02-system-architecture.md`](02-system-architecture.md) §4 and §8.
- Hosting decision: D-05 in [`11-open-decisions.md`](11-open-decisions.md).

| Environment | Status |
|-------------|--------|
| **local** (developer machine) | ✅ working (described below) |
| **CI** (GitHub Actions) | ✅ green on `main` (`.github/workflows/backend.yml`, `mobile.yml`). T-404c (2026-11-04) added parallel backend tests and the env-example and Razorpay pin checks. |
| **staging** | ⬜ **not set up.** Needs D-05 (hosting), domains/TLS, Razorpay test keys, and the Firebase staging project |
| **production** | ⬜ **not set up** (Phase 8, [`release-checklist.md`](release-checklist.md)) |

## 1. Local development

### Prerequisites
- **Backend:** `uv` (Python 3.13 is installed through uv; never use the system Python 3.14) and Docker with Compose.
- **Geo libraries:** GDAL/GEOS/PROJ for GeoDjango: `sudo apt install -y gdal-bin libgdal-dev libgeos-dev libproj-dev`. The backend Docker image already has them.
- **Flutter:** 3.47.9 / Dart 3.13.7, the Android SDK with **platform 37**, Java 17. The API generator needs Java 17 and python3.

### Database
- The DB is a **remote PostgreSQL 16 + PostGIS 3.4.2** server, shared with other projects.
- Credentials live only in **`backend/.env`**, which is gitignored and chmod 600. Every setting is listed with placeholders in `infra/env/backend.env.example`.
- There is no local Postgres container.

### Backend
```bash
docker compose -f infra/docker-compose.yml up -d redis minio mailpit   # from repo root; ports bound to 127.0.0.1
cd backend
uv sync
uv run python manage.py migrate
uv run python manage.py seed_demo                  # idempotent demo data; staff password = SEED_DEMO_STAFF_PASSWORD in .env
uv run python manage.py runserver 127.0.0.1:8001   # API, admin (/admin/), ops (/ops/)
uv run celery -A config worker -l info             # needed for real (non-test-number) OTP SMS
uv run celery -A config beat -l info               # scheduled jobs (required: expire_unpaid_orders, §4)
```
- **Windows host** (the current dev machine, no Docker; see `dev-environment.md`): run `uv run celery -A config worker -l info --pool threads` and `uv run celery -A config beat -l info` as two separate processes. Windows refuses `-B` (embedded beat).
- **Alternative:** the compose services `backend`, `worker` and `beat` run the same stack in Docker, using `backend/.env`. Don't run them alongside a host `runserver` on 8001.

### Mobile apps (dev flavor)
- **Emulator:** the default dev API URL is `http://10.0.2.2:8001`.
- **Physical phone over USB:**
  ```bash
  cd customer_app      # or rider_app
  flutter build apk --flavor dev -t lib/main_dev.dart --dart-define=API_BASE_URL=http://localhost:8001
  adb install -r build/app/outputs/flutter-apk/app-dev-release.apk
  adb reverse tcp:8001 tcp:8001     # re-apply after reconnecting USB
  ```
- **Test login:** `+919000000001`, `…002` or `…003`, with OTP `123456` (local and test settings only).
- **Maps (Mappls/MapmyIndia, DL-29):** the Android SDK config files live outside the repo in `~/.config/jivo-quick-commerce/mappls/`, and `customer_app/tool/setup_mappls.sh` copies them in for a build (they're gitignored). Without them, the app falls back to manual address entry. The files are bound to the package name + signing SHA-1 registered in the Mappls console.
- **iOS:** builds need a Mac with Xcode. The flavors/schemes aren't set up yet (`customer_app/README.md`).

### Ports in use on this host
- **This project:** Redis 6380, Django 8001, MinIO 9000/9001, Mailpit 1025/8025.
- **Agent instances:** the QA instance runs on 8004, and agents' smoke servers on 8002/8003.
- **Never use:** 6379, which is another project's `redis-chai`.

## 2. CI (GitHub Actions)
- **`backend.yml`:**
  - ruff, and the **env-example check** (`infra/scripts/check_env_example.py`). Every variable read in `backend/config/**` or `backend/apps/**` (tests excluded) must be listed in `infra/env/backend.env.example`. A new setting goes there with a placeholder and a comment, or CI fails.
  - `manage.py check` and `makemigrations --check`
  - migrations on a fresh PostGIS service DB, then pytest with coverage, **run in parallel**: `uv run --with pytest-xdist==3.8.0 pytest -n auto --create-db`.
    - Each xdist worker gets its own test DB (`…_gw0`, `…_gw1`, …) on the CI service container.
    - pytest-cov combines the workers' results, so the 80% `fail_under` applies to the whole suite.
    - `--with` adds xdist for the run only, so this works whether or not `pytest-xdist` is in `uv.lock` (T-408c).
    - **Worker count:** set by the repository variable `BACKEND_PYTEST_WORKERS` (Settings > Secrets and variables > Actions > Variables). If it's unset, CI uses `auto` (one worker per vCPU, 4 on `ubuntu-24.04`). Set it to `0` to run serially without editing the YAML, e.g. while investigating xdist-only flakes.
  - a schema-drift check
  - `check --deploy`, pip-audit, and a Docker build
  - Caching: `setup-uv` caches uv's downloads, keyed on `backend/uv.lock`.
- **`mobile.yml`:**
  - the shared-version check
  - the **Razorpay pin check** (`infra/scripts/check_razorpay_pins.py`). It requires:
    - `razorpay_flutter` exactly `1.4.7` in `customer_app/pubspec.yaml` and `pubspec.lock`
    - the Android set forced in `customer_app/android/app/build.gradle.kts`: `com.razorpay:checkout:1.6.41`, `standard-core:1.7.22` and `core:1.0.22`
    - no floating `com.razorpay` versions, and no Razorpay in `rider_app`

    Bumping these is a deliberate change. Re-run the release-build checks (R8 rules, merged manifest, Data Safety), then change the app and the pins in the script in the same reviewed change.
  - `pub get --enforce-lockfile` per project
  - an API-client drift check
  - analyze and test for the 4 projects
  - dev APK builds for both apps
  - Caching:
    - the Flutter SDK and `~/.pub-cache`, through `subosito/flutter-action`, keyed on every `pubspec.lock`
    - Gradle for the APK builds, through `setup-java` `cache: gradle`, keyed on each app's Gradle files
- **Pins and local runs:**
  - Every action is pinned by commit SHA, with its version in a comment.
  - Run either script locally with `python3 infra/scripts/<script>.py`. Both use only the standard library and support `--help`.
  - Validate workflow edits with `uvx --from actionlint-py==1.7.12.25 actionlint`.

## 3. Branches and releases
- The flow is `main` ← `develop` ← module branches (`development-phase.md` §9.4).
- A phase merges to `main` through a PR after CI passes and QA says "Ready".
- Release tags and deploy jobs are added when staging exists.

## 4. Processes (every environment)
There is one image (`backend/Dockerfile`) and three process types (doc 02). **All three run in every environment:** local compose, staging and production. Without beat, unpaid online orders never expire and their reserved stock is never released.

| Process | Command | Replicas | DB connections (T-218) |
|---|---|---|---|
| `web` (ASGI) | image default: `gunicorn config.asgi:application -k uvicorn_worker.UvicornWorker` | 2+ (rolling) | `POSTGRES_POOL=true`, `POSTGRES_CONN_MAX_AGE=0` |
| `worker` | `celery -A config worker -l INFO` | 1+ | `POSTGRES_POOL=false`, `POSTGRES_CONN_MAX_AGE=60` |
| `beat` | `celery -A config beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler` | **exactly 1** | same as `worker` |

- **Beat is a singleton.** Two beats would enqueue every periodic task twice, so never scale it above 1. On deploy, stop the old beat before starting the new one. A few seconds without beat does no harm, because the jobs catch up on the next tick.
- **Scheduler:** beat uses django-celery-beat's `DatabaseScheduler` (`CELERY_BEAT_SCHEDULER` in settings).
  - At start it syncs `CELERY_BEAT_SCHEDULE` into its tables, so run `migrate` before (re)starting beat.
  - Changes made in the admin's Periodic Tasks screen persist. Entries defined in `CELERY_BEAT_SCHEDULE` are re-synced at each start.
- **Current schedule** (`backend/config/settings/base.py`, times in UTC):
  - `orders.expire_unpaid_orders`: every 60 s (06 §5)
  - `accounts.anonymise_deleted_accounts`: 21:30
  - `accounts.purge_old_otp_requests`: 21:45
  - Phase 4 adds `sync_refund_status` (backend agent).
- **Check that beat is running:**
  - In `/admin/` > Periodic Tasks, `expire-unpaid-orders` is enabled and its `last_run_at` is under 2 minutes old.
  - The worker log shows `orders.expire_unpaid_orders` succeeding every minute.
  - Alert if `last_run_at` is more than 5 minutes old (`09 §5`).
- **Connection budget:** the DB server is shared. `web processes x POSTGRES_POOL_MAX_SIZE + worker concurrency + 1 (beat)` must stay under its connection limit.

## 5. Razorpay webhook (staging runbook, not done yet)
This is prepared for when staging exists (D-05) and the Razorpay test keys arrive (D-01). **Don't configure it until the user approves staging.** For production, repeat the steps in **live mode** with a different secret (`release-checklist.md` §7).

1. In the Razorpay Dashboard, switch to **Test mode** and open Account & Settings > Webhooks > Add New Webhook.
2. **Webhook URL:** `https://<staging-api-host>/api/v1/payments/razorpay/webhook/`. It must be HTTPS and publicly reachable, and it includes the trailing slash. nginx or the load balancer passes the body through unchanged, which the signature check needs.
3. **Secret:**
   - Generate one with `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`.
   - Paste it into the dashboard, and store the same value as `RAZORPAY_WEBHOOK_SECRET` in the staging secrets manager.
   - Never commit it, and never paste it into chat, tickets or logs.
4. **Active events:** subscribe to exactly the events that `apps/payments/services.py` handles. Any other event is stored and ignored.
   - `payment.captured`: marks the order paid. The verify call and the webhook can arrive in either order; whichever comes second is a no-op.
   - `payment.failed`: records the failed attempt.
   - `refund.processed` and `refund.failed`: update the refund status.
5. **Alert email:** use the on-call or payments address, so the email Razorpay sends after disabling a webhook for repeated failures reaches someone.
6. **Other staging settings:** `PAYMENT_GATEWAY=apps.payments.gateways.RazorpayGateway`, `RAZORPAY_KEY_ID` (`rzp_test_…`) and `RAZORPAY_KEY_SECRET`. Keep them in the secrets manager only (`09 §3`).
7. **Verify:**
   - Place a test-mode online order and pay with a Razorpay test card.
   - In `/admin/` > Payment webhook events, there is one row per `X-Razorpay-Event-Id`, and the order is now paid.
   - Re-send the same event from the dashboard. The response is `200` with `{"status": "duplicate"}`, and nothing changes.

**Responses and monitoring:**
- `200`: the event was processed (`processed`), was already handled (`duplicate`), or was not acted on (`ignored`: an unhandled event type or an unknown order).
- `400`: the signature is bad, `X-Razorpay-Event-Id` is missing, or the body isn't a Razorpay event. Nothing is stored. A burst of 400s usually means the secrets no longer match after a rotation, so alert on it.
- `503`: the backend is asking Razorpay to **retry later** after a transient failure while processing. This is expected and **not an outage alert**: Razorpay retries with back-off. Alert only if 503s go on for more than about 15 minutes. Other endpoints returning 5xx still alert as usual.

**Secret rotation:**
1. Set the new secret in the dashboard and in the secrets manager.
2. Roll the `web` processes.
3. Events signed while the two don't match fail with 400, and Razorpay retries them. So rotate in a quiet window, and check the webhook-events list afterwards.

## 6. Staging and production (target; to be implemented once D-05 is decided)
- **Hosting:** the default recommendation is AWS ap-south-1:
  - ECS/EC2 for the `web` (ASGI), `worker` and `beat` processes
  - RDS PostgreSQL + PostGIS
  - ElastiCache Redis
  - S3 + CloudFront: a public bucket for product images, private buckets for KYC files and invoices
  - nginx or an ALB for TLS
- **Secrets:** a secrets manager, with separate keys per environment. Production refuses `OTP_TEST_NUMBERS` (except the reviewer number, D-15).
- **Deploys:** zero-downtime rolling deploys, backward-compatible migrations, and a backup + PITR **restore test before launch**. Every environment runs the three processes in §4, with exactly one beat.
- **Apps:** staging/prod flavors need `--dart-define=API_BASE_URL=https://…`. Distribution goes through Firebase App Distribution or Play internal testing, then the stores.
