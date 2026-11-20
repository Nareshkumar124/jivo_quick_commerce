# Jivo Quick Commerce

A quick-commerce platform (orders delivered in 10–30 minutes) that sells only **Jivo Wellness** products. The catalog is central and stock is held per dark store. There are no sellers or marketplace.

| Deliverable | Tech | Folder |
|---|---|---|
| Customer app (Android + iOS) | Flutter | [`customer_app/`](customer_app/README.md) |
| Rider app (Android) | Flutter | [`rider_app/`](rider_app/README.md) |
| Backend API | Django + DRF, PostgreSQL/PostGIS, Redis, Celery, Channels | `backend/` |
| Admin & Ops panel | Django Admin (unfold) + Ops Console (templates, HTMX, Alpine.js) | `backend/apps/ops_console/` |

**Status:** Phases 0–7 are built; Phase 8 (hardening and launch) is in progress. See [`docs/project-status.md`](docs/project-status.md) and [`docs/task-tracker.md`](docs/task-tracker.md).

## Repository layout

| Folder | What's in it |
|---|---|
| `backend/` | Django project: apps under `backend/apps/`, API contract in `backend/openapi/schema.yaml` |
| `customer_app/`, `rider_app/` | Standalone Flutter apps (each with its own `pubspec.lock`, no pub workspace) |
| `packages/` | Shared Flutter code: `jivo_core`, the generated API client `jivo_api`, `tool/` |
| `infra/`, `.github/workflows/` | Docker, environment templates, scripts and CI/CD |
| `deployment/` | Record of the staging deployment ([`deployment/README.md`](deployment/README.md)) |
| `loadtest/` | Locust load test ([`loadtest/README.md`](loadtest/README.md)) |
| `qa/` | Independent QA plans, black-box tests and bug reports ([`qa/README.md`](qa/README.md)) |
| `design/`, `data/` | Design system and prototypes; catalog import data |
| `docs/` | Product and technical documentation ([`docs/README.md`](docs/README.md)) |

## Getting started

- **Local setup (Windows dev machine):** [`docs/dev-environment.md`](docs/dev-environment.md) covers Redis, MinIO, Mailpit, the dev server on port 8001, tests and Flutter.
- **Backend:** from `backend/`, always through `uv` (Python 3.13):
  ```bash
  uv run python manage.py runserver 0.0.0.0:8001
  uv run pytest -n 4
  uv run ruff check . && uv run ruff format --check .
  ```
- **Apps:** from `customer_app/` or `rider_app/` (Flutter 3.47.9):
  ```bash
  flutter pub get --enforce-lockfile
  flutter analyze && flutter test
  flutter build apk --flavor dev -t lib/main_dev.dart
  ```
- **API client:** after any API change, re-export the schema (`manage.py spectacular --file openapi/schema.yaml`) and regenerate `packages/jivo_api` with `packages/tool/generate_api.sh`. Never hand-edit generated code.

Secrets (`backend/.env`, Maps, Firebase and SMS keys) are never committed. The repository is public.

## Key documents

- [`docs/08-order-lifecycle.md`](docs/08-order-lifecycle.md): the behavioural contract (order, delivery and payment state machines, stock, billing, refunds)
- [`docs/06-backend-modules-and-api.md`](docs/06-backend-modules-and-api.md): endpoints, background jobs, error codes
- [`docs/07-data-model.md`](docs/07-data-model.md): data model
- [`docs/09-nfr-security-compliance.md`](docs/09-nfr-security-compliance.md): security and compliance (GST, FSSAI, DLT, DPDP)
- [`docs/11-open-decisions.md`](docs/11-open-decisions.md) and [`docs/decision-log.md`](docs/decision-log.md): open and recorded decisions
- [`docs/deployment.md`](docs/deployment.md) and [`docs/release-checklist.md`](docs/release-checklist.md): deployment and release
- [`CLAUDE.md`](CLAUDE.md): working rules for the project's AI development agents
