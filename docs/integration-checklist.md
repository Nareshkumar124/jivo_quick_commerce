# Integration Checklist

The main session (Project Manager) runs this at every sync point and at the end of every phase. It is the procedural side of [`development-phase.md`](development-phase.md) §1.5 and §4.

## A. After the backend publishes or changes the contract (sync A)
- [ ] The backend reports `schema.yaml` re-exported with `--validate --fail-on-warn`, and its schema contract test passing.
- [ ] Every new or changed endpoint is in `06` (with its error codes) and has request, response and error examples.
- [ ] No app agent invented an endpoint. Every app-side need appears in [`api-requests.md`](api-requests.md) or in the contract.
- [ ] No duplicate models: new models exist only in `backend/apps/<owner app>/models.py` and match `07`.
- [ ] The response structure follows `development-phase.md` §9.2: plain resource body, error envelope, standard pagination, money as 2-decimal strings, UTC ISO times.
- [ ] Regenerate the client: `packages/tool/generate_api.sh` (exit 0, "No issues found!").
- [ ] Run `flutter pub get` in `packages/jivo_core`, `customer_app` and `rider_app` (whichever depend on `jivo_api`).
- [ ] `python3 packages/tool/check_shared_versions.py` passes.
- [ ] Run `flutter analyze` and `flutter test` in every Flutter project. The generated-code change broke nothing.
- [ ] Tell the app agents and the admin agent what changed.

## B. After the backend implementation lands (sync B)
- [ ] Backend: `uv run pytest` green, coverage gates met (`10 §2`), ruff clean, `makemigrations --check` clean, migrations applied.
- [ ] `seed_demo` extended and idempotent, with test data for the phase.
- [ ] Restart the dev server on `127.0.0.1:8001` (it runs with `--noreload`), then check `health/ready` returns 200.
- [ ] App agents swap fakes for the real API, and their real-API integration tests pass (customer on the device the PM assigns, rider on the emulator).
- [ ] The admin agent wires the phase's admin and ops screens to the real models and services, with role tests passing.
- [ ] The QA agent verifies the phase (API, security, DB, integration) on its own instance on :8004, and files bugs.

## C. Bug loop
- [ ] Route each QA bug to its owner agent's next fix run, with the bug file path.
- [ ] Track it in [`task-tracker.md`](task-tracker.md).
- [ ] QA verifies the fix and runs regression on the 🔥 smoke set.
- [ ] Close the bug only after QA verifies it.

## D. Review, commit and merge a module branch (`development-phase.md` §9.4)
- [ ] The run is complete and its definition-of-done output has been seen.
- [ ] **Review:** run `git -C .worktrees/<agent> status` and the diff. Every change sits inside the agent's owned paths. No working functionality was removed. Tests are green.
- [ ] **Code review:** run the `code-reviewer` agent on the branch (`git diff develop...<agent>/phase-N`). Merge only on `Approve`, or `Approve with fixes` once the fixes are in. Blockers go back to the owning agent.
- [ ] Secret scan of the diff finds 0 hits (the values from `backend/.env`, key patterns). `backend/.env` and `qa/private/` are not staged.
- [ ] No Mappls config (`*.a.olf`, `*.a.conf`, `*.i.olf`, `*.i.conf`) and nothing from `data/incoming/` or `design/incoming/` is staged.
- [ ] Commit in the worktree on `<agent>/phase-N` with a conventional message and the attribution line.
- [ ] In the main tree on `develop`, run `git merge --no-ff <agent>/phase-N`, resolving any shared-file conflict by keeping both sides.
- [ ] After the merge:
  - regenerate `jivo_api` if the schema changed
  - run the shared-version check
  - run the affected tests
  - restart :8001
- [ ] Run `git -C .worktrees/<other> merge develop` for every other active agent before its next run.

## E. Phase end
- [ ] All tasks for the phase in `task-tracker.md` are ✅ or explicitly deferred.
- [ ] `qa/docs/10-release-readiness-report.md` says **Ready**: no open P0/P1 bugs, all P0/P1 cases passed, and at least 95% of all cases.
- [ ] Push `develop`, open a PR `develop` → `main`, and get CI green (backend + mobile workflows).
- [ ] Merge the PR. Update [`plan/00-roadmap.md`](plan/00-roadmap.md) (build ✅) and `CLAUDE.md` (current state).
- [ ] Human gate steps (`10 §5`): staging deploy, QA on staging, demo, sign-off recorded in the roadmap's sign-off log.
