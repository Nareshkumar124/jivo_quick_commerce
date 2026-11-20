---
name: pm-ship-run
description: "Take a finished agent run all the way to GitHub in one go: code review, fix round, merge into main, post-merge checks, tracker update, push and worktree cleanup. Use whenever the user says 'merge it after review', 'review, merge and push', 'ship it', or an agent reports done and the user has already asked for it to be merged/pushed. Stops only for Blockers, migrations needing approval, or a phone check."
---

# Ship an agent run (review → merge → push)

This chains the existing skills so the user doesn't have to ask for each step. `R=/c/jivo_projects/jivo_quick_commerce`, `W=$R/.worktrees/<name>`, `B=<agent>/<topic>`.

## 0. Preconditions
- The agent's §9.3 report is in and its final test output is green (or the only failures are known remote-DB `ConnectionTimeout` setup errors, with targeted runs green: say so in the commit body and to the user).
- The user asked for merge (and push) for this run. "Merge after review" covers merge; push only if they said push, or said it earlier for this run.

## 1. Review: `pm-code-review`
Launch `code-reviewer` in the background with the report summary and the area checklist. Keep working on other things while it runs.

## 2. Triage
| Verdict | Action |
|---|---|
| Approve / only Minor+Nit | go to 3; log Minors as `T-xxxc` rows via `pm-task` |
| Approve with fixes | spot-check each Major at its file:line, then SendMessage the owning agent (same agent id) with a numbered fix list; when it reports, verify the fixes yourself (grep/read the lines), no second full review unless the delta is large |
| Request changes / any Blocker | **stop**: tell the user what and why in plain words, propose the fix run, wait |

## 3. Merge: `pm-merge-agent-branch`
Ownership check → secret scan → commit in the worktree (Conventional Commit, review verdict in the body, `git add --chmod=+x` for new scripts) → `git pull --ff-only` on main → `merge --no-ff`. The main tree may hold PM-only edits to `docs/task-tracker.md`; that's fine if the branch doesn't touch it.

## 4. Stop points after the merge
- **New migrations** → don't apply. Tell the user in one line what the migration does and ask for approval (`shared-db-migrate`). Pushing to GitHub is still fine.
- **App changes** → offer `phone-build-install` (the user tests on the phone).
- **Schema changed** → `pm-regenerate-api-client`.
- **Backend merged** → backend post-merge checks (`check`, `makemigrations --check`, ruff); restart :8001/Celery via `local-stack` only if no migration is pending.

## 5. Tracker and push
- `pm-task`: set the row to `Merged <hash> <date> (review <verdict>)` plus anything still open (device check, migration approval, Jivo inputs).
- Commit the tracker as `docs(pm): ...` on main.
- Push: launch `github-publisher` ("push main; fetch first, stop if origin moved; secret-scan origin/main..main").

## 6. Clean up
`git -C $W status --short` empty → `git -C $R worktree remove $W` and `git -C $R branch -d $B`. Backend runs: drop the run's test DBs per `pm-merge-agent-branch` §8 (only `^test_jivo_quick_commerce_<name>(_gw[0-3])?$`).

## 7. Tell the user (short)
One line each: review verdict and what was fixed; merge hash; pushed or not; what's waiting on them (migration approval, phone test, Jivo inputs); what was not verified.
