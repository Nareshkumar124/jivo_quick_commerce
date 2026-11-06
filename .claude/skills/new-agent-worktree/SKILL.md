---
name: new-agent-worktree
description: "Create an isolated git worktree and module branch for a development agent (.worktrees/<name> on <agent>/phase-N from develop), set up its env, deps and private test DB/Redis slot, and write the agent's brief. Use whenever starting a new agent run, a new phase for an agent, or a parallel second backend run (backend4, sms, xdist, ...)."
---

# New agent worktree + brief

## 1. Pick names and check what exists
```bash
R=/c/jivo_projects/jivo_quick_commerce
git -C $R worktree list
git -C $R branch --list '*/phase-*' '*/p*'
```
- Worktree name: `backend`, `admin`, `customer`, `rider`, `qa`, `devops`; extra parallel runs get a suffix (`backend8`, `support`, `sms`).
- Branch: `<agent>/phase-N` (or `<agent>/<topic>`, e.g. `backend/p7-support`).
- An existing worktree whose branch is fully merged can be reused: `git -C $R/.worktrees/<name> status --short` must be empty, then `git -C $R/.worktrees/<name> checkout -b <agent>/phase-N develop`. Never reuse one with uncommitted work.

## 2. Create it with absolute paths
Run from the main tree on an up-to-date `develop`; always absolute paths (a relative path once nested a worktree inside another worktree):
```bash
git -C $R worktree add $R/.worktrees/<name> -b <agent>/phase-N develop
git -C $R worktree list | grep <name>          # must be directly under .worktrees/
```

## 3. Env and deps
Backend-type worktrees (backend, admin, qa, devops when it runs Django):
```bash
cp $R/backend/.env $R/.worktrees/<name>/backend/.env && chmod 600 $R/.worktrees/<name>/backend/.env
cd $R/.worktrees/<name>/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD && uv sync
```
Never `cat` or print the file. (`.env` is gitignored, so it can't be committed, but check `git status` anyway.)

Flutter worktrees (customer, rider):
```bash
for d in packages/jivo_core packages/jivo_api customer_app rider_app; do (cd $R/.worktrees/<name>/$d && /c/dev/flutter/bin/flutter pub get --enforce-lockfile); done
bash $R/.worktrees/<name>/customer_app/tool/setup_mappls.sh --copy     # customer only, for device builds
```

## 4. Test DB / Redis slot (backend-type only)
Pick a pair no other running agent uses (`docs/dev-environment.md` table):
| Who | `POSTGRES_TEST_DB` | `TEST_REDIS_DB` |
|---|---|---|
| backend main run | `test_jivo_quick_commerce` (default) | 15 |
| second backend worktree | `test_jivo_quick_commerce_<name>` | 12 or 13 |
| admin | `test_jivo_quick_commerce_admin` | 14 |
| QA (:8004) | its own settings | 5–7 |
Names must start with `test_jivo_quick_commerce` (settings refuse others). Two concurrent `-n` runs must never share both values. Avoid 0–2 (dev cache/broker/channels).

## 5. Brief template (Agent tool, subagent_type = the agent)
```
<Phase N / task title> (T-xxx). Read your agent file, CLAUDE.md, docs/dev-environment.md and <phase docs, DL-xx>.
Worktree: C:/jivo_projects/jivo_quick_commerce/.worktrees/<name> (branch <agent>/phase-N). ALL edits and commands happen there.
Env: in Bash, first `unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD`; Python only via `uv run` from backend/;
tests with POSTGRES_TEST_DB=<db> TEST_REDIS_DB=<n>; touched files while iterating, then once `uv run pytest -n 4`.
Flutter: /c/dev/flutter/bin/flutter only. Don't touch the USB phone or the :8001 server.
Rules: don't commit, push, switch branches or `git stash`; never print backend/.env; never migrate/flush/drop the shared DB
(write migrations, the PM applies them); stay inside your owned paths; report missing APIs instead of inventing them.
Scope: <numbered tasks with acceptance criteria and P<n>-TC ids>.
Definition of done: <ruff/format/check/makemigrations --check/spectacular re-export | flutter analyze 0 issues + flutter test>; coverage targets.
Final message: the §9.3 report (completed, in progress, pending, files, APIs required, APIs implemented, dependencies, blockers, issues, next) plus the actual test output.
```
Launch in the background. Record the worktree, branch, DB/Redis slot and agent ID in `docs/task-tracker.md` ("In Progress (`<branch>`)").

## Cleanup (after merge, when the branch is done)
`git -C $R worktree remove $R/.worktrees/<name>` only if `status --short` is empty; then `git -C $R branch -d <branch>` (merged). The copied `.env` goes with it.
