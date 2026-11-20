---
name: pm-agent-check
description: "Answer 'is the X agent done yet / what is it doing / is it stuck' quickly and honestly from evidence: notifications received, worktree activity, running test processes, and a direct status ping to the agent when it has been quiet too long. Use whenever the user asks about a running agent's progress."
---

# Is the agent done?

Never guess or predict an agent's result. A run is done only when its report (SubagentHandback / task notification with a report) has arrived.

## 1. Look at what you already know
- Has a report arrived in this conversation? If yes, answer from it (and continue the agreed next step, e.g. `pm-ship-run`).
- Last notification: "waiting on its own background work" means it is usually running a full test suite.

## 2. Gather evidence (one Bash call)
```bash
R=/c/jivo_projects/jivo_quick_commerce; W=$R/.worktrees/<name>
date; git -C $W status --short | wc -l
find $W -newermt "-15 minutes" -type f -not -path '*/.venv/*' -not -path '*/__pycache__/*' -not -path '*/.dart_tool/*' -not -path '*/build/*' | head
tasklist 2>/dev/null | grep -ic python    # pytest workers alive?
```
Files changing → it's editing. Only `.coverage`/`dump.rdb`/caches changing, or nothing for > 20 min with python processes alive → it's in a test run.

## 3. When to ping it
If nothing changed for ~30 min, or the run is over ~60 min: SendMessage the agent (its id from the launch) asking for a 3-line status: what it's waiting on (command), progress, anything stuck. Tell it: if the full suite hits mass remote-DB `ConnectionTimeout` setup errors, don't loop; report with targeted results.

## 4. Known slow spots (say these plainly)
- The full backend suite on the remote shared Postgres takes ~20 min, and two agents running full suites at once cause setup `ConnectionTimeout`s: only one full suite at a time.
- Flutter `flutter test` on customer_app takes ~2 min; analyze ~1 min.
- Redis 6380 may be down; an agent may start it under its own background task (it stops when that task ends: re-check with `local-stack` afterwards).

## 5. Answer
2–4 lines: done or not; what it's doing right now (with the evidence, e.g. "files unchanged since 10:40, test run in progress"); expected next event; what you'll do when it reports. No made-up percentages or ETAs beyond what the agent itself said.
