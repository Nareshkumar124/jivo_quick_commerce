---
name: pm-status-report
description: "Answer the user's 'how much work is done / where are we / what's running' with a short evidence-based status: per-phase table, running agents, unmerged work and what's waiting on the user. Use whenever the user asks for progress, status, a summary of the project, or what's left."
---

# PM status report

Status must be honest (§9.2 rule 7): "built" needs green test output, "done/passed" needs QA verification or a gate. Gather facts in parallel, then write a short answer; no file dumps.

## 1. Gather (run together)
- **Agents running:** `ListAgents` (load via ToolSearch if deferred). Note each agent's name, task and how long it's been running; check the background task list for builds/servers too.
- **Worktrees and unmerged work:**
  ```bash
  R=/c/jivo_projects/jivo_quick_commerce
  git -C $R worktree list
  for w in $R/.worktrees/*/; do n=$(git -C $w status --short | wc -l); a=$(git -C $w rev-list --count develop..HEAD); echo "$(basename $w) $(git -C $w branch --show-current) dirty=$n unmerged_commits=$a"; done
  ```
  `dirty>0` with no running agent = a finished run waiting for review/merge. `unmerged_commits>0` = committed but not merged.
- **Recent integration:** `git -C $R log develop --merges --oneline --since='2 days ago' | head -15` and `git -C $R rev-list --count main..develop` (commits on develop not yet released to main).
- **Plan state:** `docs/plan/00-roadmap.md` (Build/Gate per phase), `docs/task-tracker.md` (per-phase task statuses: `grep -cE 'Completed|Testing|In Progress|Not Started'` per section), `docs/project-status.md`, open ⚠ rows in `docs/decision-log.md`, open bugs in `qa/bugs/` (status lines), `docs/api-requests.md` open items.
- **Server:** `curl -s http://127.0.0.1:8001/health/ready` (one line in the report).

## 2. Present (keep it under ~30 lines)
Lead with one sentence: overall position (e.g. "P0–P3 built, P4 closing, P5–P8 partly started").

| Phase | Build | Gate | Done / total tasks | Open now |
|---|---|---|---|---|
| P4 Order processing | 🔄 | ⬜ | 4/6 | admin merge, QA run |

Use the roadmap legend (⬜ 🔄 ⛔ ✅ 🏁). Count tasks from the tracker; don't estimate percentages you can't back up. If you give a % at all, say what it counts ("tasks Completed or Testing / all tasks").

Then three short lists:
- **Running now:** agent → task → worktree (and any build/QA instance).
- **Ready for me (PM):** finished runs to review/merge, migrations awaiting approval, `jivo_api` regenerations, phone installs.
- **Waiting on you (user):** approvals (migrations, seed, staging D-05), decisions with ⚠ (D-xx from doc 11), credentials/accounts (Razorpay keys D-01, Firebase D-19, Play Console D-11, DLT D-02), phone tests, sign-offs.

End with the single next step you propose. Don't print secrets, `.env` contents or staff passwords.

## 3. Keep the docs in sync
If what you found disagrees with `docs/task-tracker.md` / the roadmap / `docs/project-status.md` (e.g. a merge not recorded), fix those PM docs in the same turn and mention it in one line.
