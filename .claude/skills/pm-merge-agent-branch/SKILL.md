---
name: pm-merge-agent-branch
description: "Commit an agent's finished run in its worktree and merge the module branch (<agent>/phase-N) into develop with --no-ff. Use whenever an agent reports done, the user says merge/commit/integrate a run, or a code review came back Approve; covers ownership check, secret scan, conflicts, migration collisions and post-merge checks."
---

# Merge an agent branch into develop

Agents never commit; the PM does, in the agent's worktree, then merges `--no-ff` into `develop` (`docs/development-phase.md` §9.4). Run from Git Bash. `R=/c/jivo_projects/jivo_quick_commerce`, `W=$R/.worktrees/<name>`, `B=<agent>/phase-N`.

## 1. Ownership check
```bash
git -C $W status --short            # include untracked files
git -C $W diff --stat develop...HEAD
```
Every changed path must be inside the agent's owned paths (see `.claude/agents/<agent>.md` "What you own"):
- backend: `backend/**` except `apps/*/admin.py`, `apps/ops_console/`, `templates/`, `static/`, `config/admin_ui.py`, admin tests; plus placeholder lines in `infra/env/backend.env.example`; plus `backend/openapi/schema.yaml`
- admin: those admin paths, plus agreed one-line edits to `config/settings/base.py` / `config/urls.py`
- customer: `customer_app/`, `packages/` (jivo_core additive only; jivo_api only regenerated)
- rider: `rider_app/` (+ additive `jivo_core`, regenerated `jivo_api`)
- qa: `qa/` only (`qa/private/` must stay untracked) · devops: `infra/`, `.github/workflows/`, `backend/Dockerfile`, `backend/.dockerignore`, `docs/deployment.md`
- catalog-data: `data/` (not `data/incoming/`) · ui-designer: `design/` (not `design/incoming/`)

Out-of-scope edits: revert them or ask the user; never silently commit another agent's files. An app worktree that regenerated `jivo_api` from a copied backend schema must **not** commit `backend/openapi/schema.yaml` (`git -C $W checkout -- backend/openapi/schema.yaml`).

## 2. Secret scan (repo is public)
```bash
git -C $W add -A
git -C $W diff --cached --name-only | grep -E '(^|/)\.env(\.localdb)?$|\.(a|i)\.(olf|conf)$|^qa/private/|incoming/' && echo "STOP: secret file staged"
git -C $W diff --cached | grep -E '^\+' | grep -nE 'AC[0-9a-f]{32}|POSTGRES_PASSWORD=.+|SEED_DEMO_STAFF_PASSWORD=.+|rzp_live_|-----BEGIN|FIELD_ENCRYPTION_KEYS=.+' \
  | grep -vE 'AC0{32}|=unused|=<[a-z-]+>|re\.compile'
```
Any remaining hit: unstage, inspect the line (without echoing a real value to the user), fix, rescan. Only print file:line, never the value.

## 3. Commit in the worktree
Conventional Commit summarising the §9.3 report, tracker IDs in the body. Use a heredoc (no backslash paths in it):
```bash
git -C $W commit -F - <<'EOF'
feat(backend): P5 R2 dispatch offers and pickup (T-512)

- <bullet per completed task from the report>
- Tests: <N passed, coverage %>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```
Types: `feat(backend|admin|customer|rider)`, `test(qa)`, `chore(infra)`/`ci`, `fix(...)`, `docs(pm)`.

## 4. Optional: refresh the branch first
If `develop` moved since the branch was cut and the change is risky, `git -C $W merge develop`, then targeted tests in the worktree with its own test DB/Redis (see `new-agent-worktree`), e.g.
```bash
cd $W/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
POSTGRES_TEST_DB=test_jivo_quick_commerce_<wt> TEST_REDIS_DB=<n> uv run pytest -n 4 apps/<app>
```
Flutter: `/c/dev/flutter/bin/flutter analyze && /c/dev/flutter/bin/flutter test` in the app folder.

## 5. Merge into develop (main tree)
```bash
cd $R && git status --short          # must be clean; never git stash (shared across worktrees)
git checkout develop && git merge --no-ff $B -m "Merge branch '$B' into develop (<short summary>, T-xxx)"
```

## 6. Conflicts
- `config/settings/base.py`, `config/urls.py`, role/permission seeds, `infra/env/backend.env.example`: keep **both** sides' lines.
- `backend/openapi/schema.yaml`: take either side, finish the merge, then re-export: `cd backend && uv run python manage.py spectacular --file openapi/schema.yaml` and commit it in the merge.
- `packages/jivo_api/**`: take either side, then regenerate (`pm-regenerate-api-client`).
- `pubspec.lock`: take theirs, run `flutter pub get`, then `python3 packages/tool/check_shared_versions.py`.
- After resolving: `python3 infra/scripts/check_env_example.py`.
- **Migration collisions:** `ls backend/apps/<app>/migrations/` for two files with the same number (e.g. two `cms/0004_*`). Renumber the one **not yet applied** to the shared DB (check `docs/decision-log.md` DL-53/57/58 for what's applied), fix its `dependencies` to point at the other, and confirm with `makemigrations --check`. Never edit an applied migration.

## 7. Post-merge checks (main tree, develop)
```bash
cd $R/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
uv run python manage.py check && uv run python manage.py makemigrations --check --dry-run
uv run ruff check . && uv run ruff format --check .
```
If the merge brought new migrations, **stop**: they reach the shared DB only via `shared-db-migrate` with user approval. Otherwise restart :8001 and Celery (`local-stack`) and `curl -s http://127.0.0.1:8001/health/ready`.

Then: regenerate `jivo_api` if the schema changed, update `docs/task-tracker.md` (status + merge hash), and tell other active agents' worktrees to `git merge develop` before their next run.

## 8. Drop the merged run's test databases (user decision, 2026-11-05)
Each run name creates 5 test DBs on the **shared** server: the base DB plus `_gw0`–`_gw3`. Once a run is merged and its agent is done, drop them so they don't pile up:
- Match **only** `^test_jivo_quick_commerce_<name>(_gw[0-3])?$`, with an `assert` before each `DROP DATABASE`.
- Skip a DB that still has connections in `pg_stat_activity`.
- Connect through the Django connection with autocommit, the way the cleanup on 2026-11-05 did.
- Never touch any other database on that server; it hosts other company databases.
