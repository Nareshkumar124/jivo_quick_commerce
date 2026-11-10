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
| **P8 hardening (prepared, T-813)** | ✅ backup/restore scripts + verifier with a schema-only drill (§7), deploy-time checks and release step in the image (§8), edge limits and log hygiene (§9), monitoring as code (§10), secrets and rotation (§11). Nothing is applied to staging/production until D-05. |

## 1. Local development

### Prerequisites
- **Backend:** `uv` (Python 3.13 is installed through uv; never use the system Python 3.14) and Docker with Compose. On the Windows dev machine (no Docker), Redis runs natively and MinIO/Mailpit come from `infra/scripts/windows/dev-services.ps1` (below).
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

### Windows dev machine: MinIO and Mailpit without Docker
The user approved this on 2026-11-04. `infra/scripts/windows/dev-services.ps1` replaces the compose `minio` and `mailpit` services.
- **No admin rights, nothing installed system-wide.**
- **Binaries:** `%USERPROFILE%\.local\share\jivoqc-tools\<tool>\<version>\`
- **Data and logs:** `…\jivoqc-tools\data\{minio,mailpit,logs}`
- **Binding:** everything binds to `127.0.0.1` only. The ports are the compose ports: MinIO 9000/9001, Mailpit SMTP 1025 and UI 8025.

```powershell
# from the repo root; every action is idempotent. -Service all|minio|mailpit (default all)
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action start
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action status   # processes + listening ports
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action init     # MinIO buckets + policy + checks
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action stop
```
- **`start`:**
  - Downloads any missing pinned binary from its official source and checks its sha256 against the pin in the script. On a mismatch it stops and installs nothing.
  - Then starts each service as a hidden background process that outlives the shell. Logs go to `data\logs\<service>.log`.
  - If another process already holds a service's port, it refuses to start that service.
  - **Exit codes:** `0` if everything requested is running, `2` if anything was skipped or failed.
- **`stop`:** kills only processes whose executable path is inside the tools folder.
- **`init`:** runs `infra/scripts/minio_buckets.py` through the backend's uv environment.
  - It reads the endpoint, credentials and bucket names from the Django storage settings, so `backend/.env` overrides apply. It refuses any endpoint that isn't localhost.
  - It creates the private bucket `jivo-media` (`S3_MEDIA_BUCKET`) and the public bucket `jivo-public` (`S3_PUBLIC_MEDIA_BUCKET`).
  - It sets the anonymous `s3:GetObject` policy on the public bucket. This is the same policy `seed_demo` sets.
  - It then proves both buckets: a test object round-trips in each. An anonymous GET must return 403 on the private bucket and 200 on the public one.
- **Credentials:**
  - MinIO starts with `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` from the environment, or with the compose and `local.py` defaults.
  - If `backend/.env` sets `S3_ACCESS_KEY_ID`/`S3_SECRET_ACCESS_KEY`, export the same values as `MINIO_ROOT_*` before `start`.
- **Pins:**

  | Tool | Version | Source | sha256 |
  |---|---|---|---|
  | Mailpit | v1.33.0 | GitHub `axllent/mailpit` releases, `mailpit-windows-amd64.zip` | `47122dd828ff80dcaef62b2952c478b178afadadf066c990489608e537121bfd` (GitHub's published asset digest; the release ships no checksum file) |
  | MinIO server (pgsty community build) | `RELEASE.2026-08-04T00-00-00Z` (the same release as the compose image) | GitHub `pgsty/minio` releases (the repo is now named `pgsty/silo`; GitHub redirects), `minio_20260804000000.0.0_windows_amd64.tar.gz` | `c2160a4ccbb80ce1d45f69cc35137cb5ba68f638cc2f86ebfb3d0523ce3e0d74` (GitHub asset digest; matches the release's `_checksums.txt`) |

  To upgrade, change `Version`, `Url` and `Sha256` together in `$Pins`, as a reviewed change.
- **MinIO is an archived-upstream community build, for local dev only.**
  - Official `dl.min.io` returns **410 Gone** for every community build (checked 2026-11-04), and upstream open-source MinIO no longer gets security fixes.
  - The user approved the pgsty fork on 2026-11-04, for local development only. Never use it in staging or production; those use S3 (§6).
  - That release publishes no `mc`. `-Action init` uses boto3 instead, so no `mc` is needed.
  - Besides `127.0.0.1:9000`, MinIO also binds the IPv6 loopback `[::1]:9000`. That address is still local-only.
- **Check that it works:**
  - `curl http://127.0.0.1:8025/readyz` returns 200.
  - `uv run python manage.py sendtestemail you@example.com` (from `backend/`) delivers a message that shows up at `http://127.0.0.1:8025` and in `GET /api/v1/messages`.
  - For MinIO: `curl http://127.0.0.1:9000/minio/health/live`, then `-Action init`.

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
- **`infra.yml`** (paths `infra/**`): `bash -n` + shellcheck and a PowerShell parse of `infra/backup/`, the restore scripts' refusal of non-test targets and of names with a trailing newline (bash and PowerShell), `infra/scripts/test_entrypoint.sh` (a failing deploy check blocks start; `JQC_SKIP_STARTUP_CHECK` is refused under staging/production settings), a grep that rejects `JQC_SKIP_STARTUP_CHECK` in any env or compose file, ruff on the infra Python, `check_monitoring.py`, `promtool check rules` and `nginx -t` (pinned images by digest).
- **`deploy-staging.yml`** (manual, protected branches only, environment `staging` with required reviewers, §8.4): builds the production image tagged with the checked-out commit and runs its deploy checks against the real staging env file (§8.1); the deploy step is a placeholder until D-05.
- **Pins and local runs:**
  - Every action is pinned by commit SHA, with its version in a comment.
  - Run either script locally with `python3 infra/scripts/<script>.py`. Both use only the standard library and support `--help`.
  - Validate workflow edits with `uvx --from actionlint-py==1.7.12.25 actionlint`.

## 3. Branches and releases
- The flow is `main` ← `develop` ← module branches (`development-phase.md` §9.4).
- A phase merges to `main` through a PR after CI passes and QA says "Ready".
- Release tags and deploy jobs are added when staging exists.

## 4. Processes (every environment)
There is one image (`backend/Dockerfile`) and three process types (doc 02). **All three run in every environment:** local compose, staging and production. In the production image every container first runs `manage.py check --deploy --fail-level ERROR` against its real environment (the `jqc-entrypoint`, §8.1). Without beat, unpaid online orders never expire and their reserved stock is never released.

| Process | Command | Replicas | DB connections (T-218) |
|---|---|---|---|
| `release` (one-off, once per deploy) | `jqc-release`: `check --deploy --fail-level ERROR`, then `migrate` (§8) | 1 task, before the others roll | as `worker` |
| `web` (ASGI) | image default: `gunicorn config.asgi:application -k jqc_asgi_worker.JqcUvicornWorker --no-control-socket` (uvicorn with `ws_max_size` and no access log, §9.4; no `gunicornc` control socket, the non-root user has no writable `$HOME`) | 2+ (rolling) | `POSTGRES_POOL=true`, `POSTGRES_CONN_MAX_AGE=0` |
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
- **Staff MFA (H2) rollout:** run `migrate` (it creates the django-otp tables `otp_totp_totpdevice`, `otp_static_staticdevice`, `otp_static_statictoken`) **before** starting web processes whose settings enable `STAFF_MFA_ENFORCED`; the middleware queries those tables on every privileged staff request. Set `STAFF_MFA_ENFORCED=false` in the local dev and QA `.env`; leave it on (the default) in staging and production. The recovery-code table holds plain-text codes: include it in the secret-handling rules for backups (09 §3.1).
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

## 7. Backup and restore (P8, T-813; `09 §2`)

A backup only counts once a restore of it has passed `verify_restore.py` (§7.3). Nothing here creates cloud resources: bucket names, KMS keys and retention settings are applied when D-05 is approved.

### 7.1 Targets
`09 §2` sets daily backups with 7–30 days of point-in-time recovery and 99.5% monthly uptime, but no explicit RPO/RTO. **Proposed (⚠ to confirm with the user/Jivo):**

| Data | RPO (data we may lose) | RTO (time to serve again) | How |
|---|---|---|---|
| PostgreSQL + PostGIS | ≤ 5 min | ≤ 1 h | managed PITR (continuous WAL archiving) + daily snapshots |
| PostgreSQL, logical copy | ≤ 24 h | ≤ 4 h | daily `pg_dump -Fc` to a separate bucket (protects against a deleted instance or a bad PITR window) |
| Object storage (KYC, invoices, media) | 0 for overwrites and deletes (versioning) | ≤ 1 h | bucket versioning + lifecycle |
| Redis | not backed up | minutes (empty start) | see §7.5 |

### 7.2 PostgreSQL
- **Managed PITR (primary mechanism).** On RDS (the D-05 default): automated backups on, **retention 14 days** (inside 09's 7–30), backup window 20:30–21:00 UTC (02:00–02:30 IST, the quietest hour). Copy snapshots to a second region only if the user approves the cost. PITR always restores into a **new** instance; you then repoint `POSTGRES_HOST`.
- **Logical dumps (second line).** `infra/backup/backup_db.sh` (or `backup_db.ps1`) once a day from a scheduled job inside the VPC, uploading to `BACKUP_UPLOAD_URI` (an S3 prefix in a bucket the app's role cannot write or delete). Keep 35 daily and 12 monthly dumps.
  - Each run writes `<db>_<UTC stamp>.dump` (`pg_dump -Fc`), a `.sha256` per dump and a `.manifest.json` (server, PostGIS and pg_dump versions, repo commit, sizes, checksums). It never overwrites a file and refuses an output directory inside the git repo.
  - `--schema-only` (no PII) also writes `<base>.migrations.dump` with the `django_migrations` rows, so a schema-only restore can still be checked for migration state. Used for restore drills on shared servers.
  - Use the same PostgreSQL client major as the server, or newer. pg_restore 17+ into PostgreSQL 16 issues `SET transaction_timeout`, which the server rejects; the restore scripts tolerate exactly that error and fail on any other.
  - A full dump contains PII (phones, addresses; KYC and bank numbers stay Fernet-encrypted). Never write it inside the repo (the scripts refuse) or to a laptop; only to encrypted storage.
  - `--upload` is a placeholder until D-05: it supports `s3://` (AWS CLI, `--sse aws:kms`) and exits 3 when `BACKUP_UPLOAD_URI` is unset.
- **Restore into a named database, never over the live one:**
  ```bash
  # restore drill (refuses every target except test_jivo_quick_commerce_restore*)
  infra/backup/restore_db.sh --env-file backend/.env --dump <dir>/<db>_<stamp>.dump \
      --target-db test_jivo_quick_commerce_restore_check --drop-existing --verify --source-db jivo_quick_commerce
  infra/backup/restore_db.sh --env-file backend/.env --target-db test_jivo_quick_commerce_restore_check --drop-only

  # production disaster recovery (user approval first): always into a NEW database
  infra/backup/restore_db.sh --dump <file> --target-db jivo_quick_commerce_restored_20261201 \
      --production --confirm "RESTORE INTO jivo_quick_commerce_restored_20261201" --verify
  ```
  PowerShell: the same options in PascalCase (`-EnvFile`, `-Dump`, `-TargetDb`, `-DropExisting`, `-DropOnly`, `-Verify`, `-SourceDb`, `-Production`, `-Confirm`, `-DryRun`); `Get-Help infra\backup\restore_db.ps1 -Full`.
  - **Safety rules (both scripts):** the target must match `test_jivo_quick_commerce_restore*` unless `--production` and the exact phrase `RESTORE INTO <target>` are given; a production target must not exist yet; only `test_jivo_quick_commerce_restore*` databases can ever be dropped; the dump's `.sha256` must match before anything is created; database names are restricted to `[a-z0-9_]`.
  - **Production restore runbook:**
    1. Declare the incident. Stop `beat` and `worker`, so no jobs run on a half-restored database.
    2. PITR to a new instance at the chosen time, **or** `restore_db.sh --production` into a new database from the latest good dump.
    3. `verify_restore.py --target-db <new> --full` must pass.
    4. Point `POSTGRES_HOST`/`POSTGRES_DB` at it and roll `web`, then `worker`, then the single `beat`.
    5. Run `anonymise_deleted_accounts` once: a restored backup may hold accounts erased after it was taken (DPDP).
    6. Reconcile payments for the lost window from the Razorpay dashboard. Webhooks are idempotent, so re-send them.
    7. Keep the old instance read-only for 7 days, then delete it.
- **Restore test cadence:** before go-live (release checklist §3), then quarterly and after any PostgreSQL or PostGIS major upgrade. Record each run in the log below.

### 7.3 `verify_restore.py`
Read-only: every transaction is `READ ONLY`, on the target and on the source. Run `uv run --project backend python infra/backup/verify_restore.py --target-db <db> [--source-db <db>] [--env-file backend/.env] [--counts] [--json]`. Exit 0 = OK (warnings allowed), 1 = a check failed, 2 = usage or connection error.
- PostGIS is installed; the exact row count of every `public` table (`--counts` prints them).
- Migration state: `django_migrations` exists and is not empty. With `--source-db`, the applied migrations, tables, columns, constraints and indexes must equal the source's (and row counts for a full restore; a live source keeps changing, so a row-count difference is a warning).
- Key money and stock constraints exist (`storeinventory_reserved_within_on_hand`, `payment_amount_positive`, …).
- Business invariants (08 §6, like QA's read-only SQL): `on_hand` = Σ `StockMovement.delta`; the latest `on_hand_after` = `on_hand`; `reserved` = Σ ACTIVE reservations; `0 ≤ reserved ≤ on_hand`; the 08 §6.2 bill formula; `product_discount = mrp_total − item_total`; no negative amounts; `amount_refunded ≤ amount_paid`; refunds never exceed their payment. Warnings: ACTIVE reservations on terminal orders, duplicate captures without a refund, orders without status history. Tables a later phase adds are skipped, not failed.

**Restore test log**

| Date | Who | Source | Mode | Target | Result |
|---|---|---|---|---|---|
| 2026-11-04 | devops agent (T-813) | shared dev DB (PostgreSQL 16.15, PostGIS 3.4.2) | schema-only + `django_migrations` rows; bash and PowerShell scripts | `test_jivo_quick_commerce_restore_check`, dropped afterwards | ✅ 25/25 checks: 69 tables, 90 migrations, 682 columns, 265 constraints and 280 indexes equal to the source; restore 8 s. A read-only invariant run on the dev DB itself (10,356 rows): 0 violations. **A full-data restore test is still required before launch** (needs staging/production, D-05). |

### 7.4 Object storage (S3 in staging/production; MinIO locally)
| Bucket | Holds | Protection |
|---|---|---|
| private (`S3_MEDIA_BUCKET`) | KYC documents, invoices (GST PDFs), other private files | Block Public Access; SSE-KMS; **versioning on**; lifecycle: noncurrent versions expire after **30 days** (so `purge_offboarded_kyc` and DPDP erasure really complete), incomplete multipart uploads after 7 days. Invoices are statutory records (GST: keep at least 72 months). **⚠ D-12:** decide whether invoices get Object Lock (governance mode) on their own bucket or prefix. |
| public (`S3_PUBLIC_MEDIA_BUCKET`) | product, category and banner images | versioning on, noncurrent versions expire after 30 days; also recoverable from Jivo's catalog sources (`data/`) |
| backups (new, D-05) | daily `pg_dump` files, checksums, manifests | separate bucket, SSE-KMS, versioning, writable only by the backup job's role, no delete for the app role; lifecycle 35 days daily, 12 months monthly |

Cross-region replication of the private bucket is optional and doubles its storage cost: ask the user. To restore an object, copy its previous version back (`aws s3api list-object-versions`).

### 7.5 Redis: what is and isn't backed up
Nothing in Redis is a system of record (09 §2), so it is **not backed up** and runs without persistence (`--save "" --appendonly no`, as in compose):
- **Cache** (catalog and home per store, serviceability snapshot, app config): rebuilt on demand from PostgreSQL.
- **Celery broker:** tasks in flight are lost with Redis. They are idempotent, and the critical ones are re-derived from the DB by beat: `expire_unpaid_orders` (stock release), `sync_refund_status`, `auto_accept_orders`, and the Phase 6 stuck-notification sweeper.
- **Channel layer and rider latest locations:** ephemeral. Apps fall back to polling; a rider's next ping restores the position.
- **OTP throttling counters:** losing them only resets the limits. OTP codes are in PostgreSQL (`accounts_otprequest`, hashed). OTP sends fail closed while Redis is down (DL-13).

### 7.6 Access and encryption
- Encryption at rest everywhere: RDS storage encryption (KMS), S3 SSE-KMS, encrypted volumes for any worker scratch space. In transit: `POSTGRES_SSLMODE=require` (or `verify-full` with the RDS CA) in staging and production.
- Backups are readable only through the on-call break-glass role, with access logged (CloudTrail). The backup job's role can write new objects but not delete them.
- The scripts read credentials from the libpq variables or `--env-file` (only the `POSTGRES_*` connection keys are read), never print them, and print neither host nor role unless `JQC_SHOW_HOST=1`. Dumps are created with umask 077 (bash) or a user-only ACL (PowerShell).

## 8. Deploy, release step and rollback

### 8.1 Deploy-time configuration checks (P8 OWASP M8)
CI runs `check --deploy` with placeholder values, so it cannot catch a real environment that is misconfigured. Two places now run the checks against the **real** environment:
- **`jqc-entrypoint`** (the production image's `ENTRYPOINT`): every `web`, `worker` and `beat` container runs `python manage.py check --deploy --fail-level ERROR` before its command starts. A failing check stops the container, so a rolling deploy halts with the old version still serving. At ERROR level, deploy warnings are printed but not fatal. It catches `accounts.E003` (console SMS backend), `payments.E001`/`E004` (fake gateway, `FAKE_GATEWAY_DOWN`), `delivery.E001` (no `FIELD_ENCRYPTION_KEYS`) and `notifications.E001` (dev push backend), as those checks land from the backend branches, plus every other registered error. **`JQC_SKIP_STARTUP_CHECK=1` is for local/dev settings only**, where it skips the check with a loud WARNING. Under `config.settings.staging`, `production` or `deployed` the entrypoint **refuses** it for every command (gunicorn, uvicorn, celery, `jqc-release`, anything) and exits 64. It must never appear in a service env file, compose file or secret: CI rejects it in env and compose files, and the staging preflight rejects it in `STAGING_BACKEND_ENV`. Break-glass during an incident is an explicit `--entrypoint python` override on a one-off task, which the orchestrator records.
- **`jqc-release`** (the release task, §8.2) runs the same check before `migrate`.
- **Staging deploy job** (`.github/workflows/deploy-staging.yml`, manual only, GitHub environment `staging`): builds the image and runs it once with the staging environment (the `STAGING_BACKEND_ENV` environment secret, a `KEY=value` env file), so the entrypoint's check runs before anything is deployed. The deploy step itself fails with "not configured" until D-05.
- Some checks skip themselves when `DJANGO_ALLOWED_HOSTS` lists only reserved example hosts (CI's dry run). Real environments must list their real hosts, or those checks never fire.

### 8.2 Release order (zero downtime)
1. Build and push the image tagged with the git SHA. Set `SENTRY_RELEASE` to the same SHA.
2. Run the **release task** once: `jqc-release` (deploy checks, then `migrate --noinput`). Migrations must stay compatible with the running version: expand now, contract in a later release (add nullable columns or columns with defaults, backfill in a task, drop a column only once no running code reads it).
3. Roll `web`: health check `/health/ready`, at least 2 replicas, 30 s drain (`--graceful-timeout 30`).
4. Roll `worker`: Celery's warm shutdown finishes running tasks (`CELERY_TASK_TIME_LIMIT` is 5 min).
5. Stop the old `beat`, then start the new one (never two, §4).
6. Smoke: `/health/ready`, `/api/v1/config/app/`, a test-number OTP login on staging, and the new release visible in Sentry.

### 8.3 Rollback
- **Code:** redeploy the previous image tag (steps 3–5). Because migrations are expand-only, the previous version runs against the new schema.
- **A migration must be reverted:** only when it is reversible and data-safe: `manage.py migrate <app> <previous>` as a one-off task, then roll back the code. Otherwise fix forward.
- **Data damage:** the production restore runbook (§7.2).
- The release checklist §8 names the rollback owner for each deploy window.

### 8.4 Who can run the staging deploy
`deploy-staging.yml` is `workflow_dispatch` only, and its jobs run only when dispatched on a **protected** `develop` or `main` (`github.ref_protected`); it deploys exactly that commit, and the image tag is `git rev-parse HEAD` of the checkout. One-time GitHub setup (repository admin, no cost):
1. Branch protection on `develop` and `main` (PR required, CI green, no force-push).
2. Settings > Environments > `staging`: **required reviewers** (at least one person other than the dispatcher; tick "Prevent self-review"), and **deployment branches** limited to `develop` and `main`.
3. Store `STAGING_BACKEND_ENV` (and later the cloud deploy credentials, preferably OIDC rather than keys) as **environment** secrets of `staging`, never repository secrets, so only an approved run can read them.
4. Later, `deploy-production.yml` follows the same pattern with a `production` environment, `main` only, and two reviewers.

## 9. Edge proxy hardening (`infra/nginx/default.conf`, P8 OWASP review)

### 9.1 Rate limits, connection limits and body sizes (H3, edge half)
These are coarse per-IP limits. The backend keeps its own per-user and per-phone throttles, which return the real error codes (06 §6). The limits are generous because mobile carriers put many users behind one CGNAT address.

| Location | Limit per IP | Burst | Max body |
|---|---|---|---|
| `/api/v1/auth/otp/request/` only (each costs an SMS) | 60 req/min (`jqc_otp`); 429 `OTP_RATE_LIMITED` | 30 | 16 KB |
| `/api/v1/auth/otp/verify/` | the general API zone (the backend limits attempts per OTP, per phone and per IP) | 40 | 2560 KB |
| `/api/v1/search/` (search, suggest) | 5 req/s | 20 | 16 KB |
| `/api/v1/rider/documents/` | 20 req/s | 10 | 1200 KB (1 MB image + multipart overhead; `RIDER_DOCUMENT_MAX_BYTES`) |
| `/api/v1/payments/razorpay/webhook/` | none (signed, idempotent, Razorpay retries) | n/a | 256 KB |
| `/api/v1/support/tickets/<id>/attachments/` (regex location; customer and rider ticket photos) | 20 req/s | 40 | 5300 KB (5 MB photo + multipart overhead; `SUPPORT_ATTACHMENT_MAX_BYTES`) |
| `/api/` (all other) and `/` | 20 req/s | 40 | 2560 KB (= `DATA_UPLOAD_MAX_MEMORY_SIZE`, 2.5 MB) |
| `/admin/`, `/ops/` | 10 req/s | 40 | 6 MB (product images up to 5 MB, 09 §3.6) |
| `/ws/` | **50 concurrent sockets** (`limit_conn`); upgrades 20 req/s | 20 | 64 KB |
| `/health/` | none; not logged | n/a | default |

Over a limit, nginx answers 429 with the JSON error envelope and `Retry-After: 60`; an oversized body gets 413 `PAYLOAD_TOO_LARGE`.

**Behind a load balancer, the `set_real_ip_from <lb-subnet>` block (with `real_ip_header X-Forwarded-For` and `real_ip_recursive on`) MUST be set.** Without it every request appears to come from the balancer, all clients share one OTP bucket and one 50-socket bucket, and the first busy minute locks everyone out. Leave it commented only when nginx itself faces the internet. Check after setting it: the nginx access log's `remote_addr` shows client addresses, not the balancer's.

**Load-balancer equivalents,** if nginx is dropped (D-05):
- **AWS:** WAF on the ALB with rate-based rules per IP (5-minute windows: e.g. 300 for `/api/v1/auth/otp/request/`, 6,000 for `/api/`, using URI scope-down statements) and the AWS managed core rule set. Body limits through WAF size-constraint rules (2.5 MB; 1.2 MB on `/api/v1/rider/documents/`; 5.3 MB on `/api/v1/support/tickets/<id>/attachments/`). ALB idle timeout 3600 s for WebSockets. An ALB has no per-IP connection cap, so keep nginx in front of `/ws/` or enforce the cap in the app.
- **Cloudflare:** rate-limiting rules per path, WAF managed rules, and a WAF rule on `http.request.body.size`.
- **GCP:** Cloud Armor rate-based throttle or ban rules per path.

### 9.2 Access logs without query strings (L8)
- nginx logs JSON with `$uri` (path only, no query string), because serviceability and notify-me carry lat/lng in the query string. There is no `$request`, `$request_uri` or `$args` in the format.
- The app server writes **no** access log. uvicorn's access line holds the full request line, so the image's worker class `jqc_asgi_worker.JqcUvicornWorker` sets `access_log=False` (gunicorn's own `--access-logformat` does not apply to uvicorn workers). The edge log is the access log of record; requests are correlated by `X-Request-ID` (`$request_id`).
- An ALB's access logs contain the full request line, query string included. If ALB access logs are enabled, restrict that bucket to on-call and give it a 30-day lifecycle, or log at nginx only.

### 9.3 No token-bearing headers in logs (L11)
No proxy log format includes `Sec-WebSocket-Protocol`, `Authorization` or `Cookie`: nginx logs no `$http_*` request header except `User-Agent`, and the app server logs no requests. The socket JWT travels in the first message anyway. Adding a header to a log format needs a review.

### 9.4 WebSocket message size (L5)
uvicorn's default `ws_max_size` is 16 MiB. The image's worker class sets it to **64 KiB** (override with `WS_MAX_MESSAGE_BYTES`), since our socket messages are small JSON. A larger frame closes the socket with code 1009. Local `runserver` (Daphne) keeps its defaults; deployed environments never run Daphne.

### 9.5 `NUM_PROXIES` per topology (L1)
`NUM_PROXIES` is the number of proxies in front of Django that append to `X-Forwarded-For`. DRF and the OTP and lockout limits take the client IP at that position from the right. A value that is too high trusts a spoofed header; one that is too low rate-limits the proxy instead of the client. `deployed.py` requires it explicitly.

| Topology | `NUM_PROXIES` |
|---|---|
| Internet → nginx → Django | 1 |
| Internet → load balancer (ALB) → nginx → Django | 2 |
| Internet → load balancer → Django (no nginx) | 1 |
| Internet → CDN (CloudFront/Cloudflare) → load balancer → nginx → Django | 3 (only if the CDN fronts the API; otherwise 2) |

nginx keeps `X-Forwarded-For $proxy_add_x_forwarded_for` in every topology, including with `set_real_ip_from`, so these counts hold. After any topology change, send a request with a spoofed `X-Forwarded-For: 1.2.3.4` and confirm the OTP throttle keys on your real IP.

## 10. Monitoring and alerting (`09 §2`, `§5`; `infra/monitoring/`)

### 10.1 Sentry (D-19)
- Already wired: `config/sentry.py`, called from `deployed.py` (staging and production only), with `send_default_pii=False` and no frame locals.
- **Environment names:** `SENTRY_DSN` (secret; empty disables Sentry), `SENTRY_ENVIRONMENT` (defaults to the settings module, `staging` or `production`), `SENTRY_RELEASE` (set by the deploy to the git SHA), `SENTRY_TRACES_SAMPLE_RATE`.
- **Sample-rate policy:** errors are always sent at 100% (the SDK's default `sample_rate`). Traces: **0.2 in staging and 0.05 in production** at launch, lowered if the Sentry quota is reached; never 1.0 in production. `/health/*` should be excluded from tracing (backend ask, §10.3).
- **Apps:** a DSN per Sentry project and flavor (`--dart-define=SENTRY_DSN=…`), with release = app version + build. Owned by the app agents.

### 10.2 Probes
`/health/live` checks only the process (use it for liveness and restarts). `/health/ready` checks PostgreSQL (`SELECT 1`) and Redis (`PING`) and answers 503 otherwise: use it for the load balancer's target health and for the `JqcApiNotReady` alert (blackbox exporter `probe_success{job="jqc-health-ready"}`). Both are exempt from the HTTPS redirect and are neither rate limited nor logged at the edge.

### 10.3 Metrics
Catalogued in `infra/monitoring/metrics.yml` (name, type, labels, source, status):
- **Request latency p95 per route** and request/5xx counters: `jqc_http_request_duration_seconds` and `jqc_http_requests_total`. **Needs backend:** a `/metrics` endpoint (prometheus_client in multiprocess mode, `PROMETHEUS_MULTIPROC_DIR`) on an internal port or path that nginx does not expose, with `route` = the resolver's URL pattern, never the raw path (no ids or PII in labels).
- **WebSocket connections:** `jqc_ws_connections{consumer}`. **Needs backend:** a gauge updated in the consumers' connect and disconnect (`livesum`).
- **Celery queue depth, task failures, live workers:** `celery_queue_length`, `celery_task_failed_total` and `celery_worker_up` from a `celery-exporter` sidecar. **Needs backend settings** `CELERY_WORKER_SEND_TASK_EVENTS=True` and `CELERY_TASK_SEND_SENT_EVENT=True` (queue length works without them).
- **Beat liveness (`last_run_at`), refund FAILED count, stuck notifications, order SLA breaches** and other business counts: `infra/monitoring/sql_exporter/jqc_business.collector.yml`, all read-only aggregates. Every query was run read-only against the dev DB on 2026-11-04; the two notification queries wait for the Phase 6 table.
- **Redis/PostgreSQL up:** exporters or the managed provider's metrics. DB CPU and storage come from the provider: RDS `CPUUtilization` > 80% for 15 min and `FreeStorageSpace` < 20% raise tickets.
- **Structured logs:** `LOGGING` is plain text today. **Backend ask:** a JSON formatter with the request id (`X-Request-ID` from the edge), hashed user id and order id, and phone masking (`09 §3.3`, `§5`).

### 10.4 Alert rules
`infra/monitoring/alerts.yml` (Prometheus rule format) has 23 rules:
- **availability:** API not ready, 5xx > 2%, Redis or PostgreSQL down;
- **latency:** the 09 §1 p95 targets (reads 300 ms, order placement 800 ms, serviceability 150 ms);
- **jobs:** queue > 200, no workers, repeated task failures, beat stale > 5 min, daily jobs > 26 h, unpaid orders past their window;
- **payments:** new FAILED refunds, PENDING > 2 h, webhook 400 bursts, webhook 503 > 15 min;
- **notifications:** stuck sends, many failures, WebSocket collapse;
- **business SLA:** store acceptance SLA, orders past ETA, no orders during open hours.

Severities: `page` (on-call engineer), `ticket` (working hours), `ops` (store/ops on-call). The SQL exporter connects with its own read-only role, never the app's login:
```sql
create role jqc_metrics login password '<from the secrets manager>';
grant connect on database jivo_quick_commerce to jqc_metrics;
grant usage on schema public to jqc_metrics;
grant select on django_celery_beat_periodictask, orders_order, payments_refund,
      payments_paymentwebhookevent, notifications_notification to jqc_metrics;
alter role jqc_metrics set default_transaction_read_only = on;
```
Validate locally with `uv run --project backend python infra/monitoring/check_monitoring.py` (structure, every metric catalogued, every runbook anchor present). CI also runs `promtool check rules` and `nginx -t` in pinned images (`.github/workflows/infra.yml`).

### 10.5 Threshold changes
Record each tuned threshold here with its date and reason (after the pilot week, 10 §7).

### 10.6 Alert runbooks

#### Runbook: API availability
`JqcApiNotReady`, `JqcApi5xxRateHigh`. Read `/health/ready`'s `details.checks`, look in Sentry for the new error, and check the last deploy (roll back per §8.3 if the alert started with a release). Check DB connections: web processes × `POSTGRES_POOL_MAX_SIZE` + workers must stay within the server's limit (§4).

#### Runbook: data stores
`JqcRedisDown`, `JqcPostgresDown`. Redis: OTP fails closed and sockets fall back to polling; there is nothing to restore (§7.5). Restart or fail over, then watch the Celery backlog drain. PostgreSQL: check the provider's status and failover; if data is damaged, follow §7.2.

#### Runbook: latency
`JqcReadLatencyP95High`, `JqcOrderPlacementLatencyP95High`, `JqcServiceabilityLatencyP95High`. Compare with the deploy timeline. Check slow queries (`pg_stat_statements`), the Redis cache (catalog cache, serviceability snapshot) and lock waits on `inventory_storeinventory` during order bursts.

#### Runbook: Celery
`JqcCeleryQueueBacklog`, `JqcCeleryWorkersDown`, `JqcCeleryTaskFailures`. Read the worker logs and Sentry. Scale workers within the DB connection budget. One task name failing repeatedly usually means an external provider (SMS, FCM, Razorpay) is down; the tasks retry with back-off.

#### Runbook: Celery beat
`JqcBeatNotRunning`, `JqcBeatDailyJobMissed`, `JqcPaymentWindowOverdue`. Exactly one `beat` must run (§4). Check that it is up, that `migrate` ran before it started, and its `last_run_at` in `/admin/` > Periodic Tasks. Overdue unpaid orders hold stock; once beat recovers they expire within a minute.

#### Runbook: payments
`JqcRefundFailed`, `JqcRefundPendingTooLong`, `JqcWebhookSignatureFailures`, `JqcWebhookRetryLoop`. Start with the Razorpay dashboard. A failed refund is retried from the admin by a role allowed to. A burst of 400s after a secret rotation: follow the §5 rotation steps. Persistent 503s: check Sentry for the webhook handler.

#### Runbook: notifications
`JqcNotificationsStuckSending`, `JqcNotificationFailuresHigh`, `JqcWebsocketConnectionsCollapsed`. Check that the sweeper runs (beat), the FCM credentials, the SMS gateway and the DLT template status. For a WebSocket collapse, check the channel-layer Redis and the edge's `/ws/` route (`limit_conn`, idle timeouts).

#### Runbook: business SLA
`JqcStoreAcceptanceSlaBreach`, `JqcOrdersPastEta`, `JqcNoOrdersDuringOpenHours`. These go to the store/ops on-call: call the store and check the packing console and rider availability. For no orders during open hours, place a test order end to end (serviceability, cart, payment).

## 11. Secrets and rotation

### 11.1 Required secrets in staging and production
Kept per environment in the secrets manager; never in git or in images:
- `DJANGO_SECRET_KEY` (at least 50 characters): sessions, CSRF, signing.
- **`JWT_SIGNING_KEY`:** signs the apps' access and refresh tokens. In staging and production it must be **set, at least 50 characters, and different from `DJANGO_SECRET_KEY`** (system check `accounts.E005`, which fails the deploy-time check, §8.1), so rotating one never invalidates the other. The fallback to the secret key is for local use only. Generate with `secrets.token_urlsafe(64)`.
- **`OTP_HASH_KEY`:** the key used to hash OTP codes (HMAC). Staging and production: **at least 32 characters, distinct from both keys above**; never reuse another key. Generate with `secrets.token_urlsafe(48)`.
- CI's `check --deploy` step (`backend.yml`) generates throwaway values for all three on every run; the staging preflight (`deploy-staging.yml`) refuses a `STAGING_BACKEND_ENV` that lacks `DJANGO_SECRET_KEY`, `JWT_SIGNING_KEY` or `OTP_HASH_KEY`.
- **`FIELD_ENCRYPTION_KEYS`:** comma-separated Fernet keys, **newest first**, for rider bank and KYC numbers (09 §3.3). Required in staging and production (`delivery.E001`).
- `POSTGRES_PASSWORD`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `TWILIO_AUTH_TOKEN`, `S3_SECRET_ACCESS_KEY` (or an instance role instead), `SENTRY_DSN`, `EMAIL_HOST_PASSWORD`.
- Generate keys with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` and Fernet keys with `uv run python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` (from `backend/`), straight into the secrets manager.

### 11.2 Rotation runbooks
- **`DJANGO_SECRET_KEY`:** set the new value and roll `web`. Staff sessions end and staff log in again. The apps are unaffected while `JWT_SIGNING_KEY` is separate.
- **`JWT_SIGNING_KEY`:** set the new value and roll `web`. Every app access and refresh token becomes invalid, so every customer and rider logs in again. Rotate only on suspected compromise, announce it first, and expect an OTP SMS spike.
- **`FIELD_ENCRYPTION_KEYS`:** add the new key **first** and keep the old ones after it; deploy; run `manage.py rotate_field_keys` as a one-off task and confirm it reports no undecryptable values; remove the old key in the next deploy.
- **`OTP_HASH_KEY`:** set it and roll `web` and `worker`. OTPs in flight (5-minute lifetime) fail and users request a new one, so rotate in a quiet window.
- **`RAZORPAY_WEBHOOK_SECRET`:** §5.
- **Database password:** set the new password on the role, update the secret, roll `web`, `worker` and `beat` in that order, then confirm no connection still uses the old one. **Least privilege:** staging and production must use a role that owns only the app's database (never a superuser), plus the separate read-only `jqc_metrics` role (§10.4).
- After any rotation, check Sentry for auth errors, `/health/ready`, and the webhook-events list.
