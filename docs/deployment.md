# Deployment & Environments

This file records what is **actually set up today**, plus the target for the environments that don't exist yet.
- Target architecture: [`02-system-architecture.md`](02-system-architecture.md) §4 and §8.
- Hosting decision: D-05 in [`11-open-decisions.md`](11-open-decisions.md).

| Environment | Status |
|-------------|--------|
| **local** (developer machine) | ✅ working (described below) |
| **CI** (GitHub Actions) | ✅ green on `main` (`.github/workflows/backend.yml`, `mobile.yml`) |
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
uv run celery -A config beat -l info               # scheduled jobs
```
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
  - ruff
  - `manage.py check` and `makemigrations --check`
  - migrations on a fresh PostGIS service DB, then pytest with coverage
  - a schema-drift check
  - `check --deploy`, pip-audit, and a Docker build
- **`mobile.yml`:**
  - the shared-version check
  - `pub get --enforce-lockfile` per project
  - an API-client drift check
  - analyze and test for the 4 projects
  - dev APK builds for both apps

## 3. Branches and releases
- The flow is `main` ← `develop` ← module branches (`development-phase.md` §9.4).
- A phase merges to `main` through a PR after CI passes and QA says "Ready".
- Release tags and deploy jobs are added when staging exists.

## 4. Staging and production (target; to be implemented once D-05 is decided)
- **Hosting:** the default recommendation is AWS ap-south-1:
  - ECS/EC2 for the `web` (ASGI), `worker` and `beat` processes
  - RDS PostgreSQL + PostGIS
  - ElastiCache Redis
  - S3 + CloudFront: a public bucket for product images, private buckets for KYC files and invoices
  - nginx or an ALB for TLS
- **Secrets:** a secrets manager, with separate keys per environment. Production refuses `OTP_TEST_NUMBERS` (except the reviewer number, D-15).
- **Deploys:** zero-downtime rolling deploys, backward-compatible migrations, and a backup + PITR **restore test before launch**.
- **Apps:** staging/prod flavors need `--dart-define=API_BASE_URL=https://…`. Distribution goes through Firebase App Distribution or Play internal testing, then the stores.
