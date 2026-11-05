---
name: shared-db-migrate
description: "Apply approved Django migrations (and optionally seed_demo) to the shared dev PostgreSQL, gated on the user's explicit approval, with a migrate --plan check, a read-only constraint check on existing rows, restarts and a decision-log entry. Use whenever a merge brought new migrations, the user approves migrations, :8001 errors with missing columns/tables, or demo data needs refreshing."
---

# Migrate / seed the shared dev DB

The dev DB is **shared** (remote PostgreSQL 16 + PostGIS; temporarily the local `jivoqc-pg-local` container if `backend/.env.localdb` is loaded, DL-36). Agents never migrate it; only the PM does, and only after the user approves the **exact** migration list. Never `flush`, never `DROP`, never print `backend/.env`.

## 0. Get approval first
List what's pending and ask the user, naming each migration and what it does (new table, new column with default, constraint, data migration):
```bash
cd /c/jivo_projects/jivo_quick_commerce/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
uv run python manage.py showmigrations --plan | grep '\[ \]'
```
Approval must name the migrations (e.g. "apply `cms 0005`, `delivery 0001`, `notifications 0001`"), and say separately whether `seed_demo` may run. Past approvals: DL-53, DL-57, DL-58. If an approval has a condition (e.g. "once the P5 final test run is green"), check it.

## 1. Plan must match exactly
Run from the **main tree on develop** (merged code only):
```bash
uv run python manage.py migrate --plan
```
Every listed operation must belong to an approved migration. Anything extra (an unmerged dependency, a migration from another app) → stop and ask. Also `uv run python manage.py makemigrations --check --dry-run` must be clean, so nothing is left unmigrated.

## 2. Read-only check on existing rows
For each new constraint, NOT NULL, unique or check: read the migration file and count rows that would violate it, read-only, through the Django shell:
```bash
uv run python manage.py shell -c "
from apps.orders.models import Order
print('violations', Order.objects.filter(grand_total__lt=0).count())
"
```
(Adapt the model and filter to the constraint. Use `.count()`/`.exists()` only; no `.update()`, `.delete()` or `.save()`.) Report the counts (DL-53 example: "all 153 existing orders satisfy the new money constraints"). Any violation → stop; a data-fix migration is a backend task.

## 3. Migrate
```bash
uv run python manage.py migrate 2>&1 | tail -30
uv run python manage.py showmigrations <app> | tail -5     # confirm [X]
```
On failure: don't retry blindly or fake (`--fake`) anything. Capture the error, report it, and hand it to the backend agent. Postgres DDL is transactional per migration, so a failed one rolls back.

## 4. Seed (only if approved)
```bash
uv run python manage.py seed_demo 2>&1 | tail -20
```
`seed_demo` is idempotent; it never prints staff passwords (they come from `SEED_DEMO_STAFF_PASSWORD`). Don't echo its credentials output if any appears.

## 5. Restart and verify
Restart Django :8001, the Celery worker and beat (`local-stack` skill), then:
```bash
curl -s http://127.0.0.1:8001/health/ready
```
Spot-check the feature the migration supports (an API call or the admin page). QA's :8004 instance uses the same DB: tell QA if it's mid-run.

## 6. Record it
Add a `DL-<next>` row to `docs/decision-log.md`:
`| DL-xx | <date> | **<Phase> migrations applied to the shared DB** with the user's approval: <app NNNN list>. Read-only check: <result>. seed_demo <re-run / not run>, which adds <data>. | user, <date> |`
Update `docs/task-tracker.md` (status note "migrations applied DL-xx") and mention it in `docs/project-status.md` if the phase status changes. Commit as `docs(pm): DL-xx <phase> migrations applied`.
