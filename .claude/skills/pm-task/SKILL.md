---
name: pm-task
description: "Add, update or close rows in docs/task-tracker.md (T-xxx tasks, H-xx 'waiting on you or Jivo' items, BUG rows) with the right next number, section, owner code and status wording. Use whenever an agent run starts or ends, a review creates follow-ups, the user asks to track/add/close a task, or a Jivo input arrives."
---

# Task tracker rows

Only the PM edits `docs/task-tracker.md`. `R=/c/jivo_projects/jivo_quick_commerce`.

## 1. Before editing
- `git -C $R pull --ff-only` (the other PC also adds rows; numbers can clash).
- Next number: `grep -o '^| T-[0-9]*' $R/docs/task-tracker.md | sort -t- -k2 -n | tail -1` (same for `H-`, and `ls qa/bugs` for BUG ids). Follow-ups from a review use the parent id plus a letter (`T-817c`).

## 2. Where the row goes
| Kind | Section |
|---|---|
| Phase 8 / launch work (current) | `## Phase 8: Hardening & launch` (new rows directly after the highest T-8xx row) |
| Old-phase follow-up | that phase's section or its carry-overs subsection |
| Something the user or Jivo must provide/decide | `## Waiting on you or Jivo` as `H-xx` |
| API gap from an app agent | `docs/api-requests.md` and the `## Open API requests` line |

## 3. Row format (Phase 8 table)
`| T-xxx | <task, plain words, key files/flags in backticks> | <BE/ADM/CUS/RID/QA/DEVOPS/REVIEW/CATALOG/DESIGN/PM/USER> | <P0/P1/P2> | <depends: T-/H- ids or –> | <deliverables> | <acceptance> | <status> |`

Status wording (keep it factual, dated, with hashes):
- `Not Started (after T-xxx; worktree .worktrees/<name> ready)`
- `In Progress (<branch>, worktree .worktrees/<name>, test DB <db>, Redis <n>, started YYYY-MM-DD)`
- `In Review (review launched YYYY-MM-DD)`
- `Merged <hash> YYYY-MM-DD (review <verdict>). Open: <device check / migration approval / Jivo input>`
- `Blocked (<on what: H-xx / user approval>)`
- `Testing (QA verifying)` / `Completed (QA verified <ref>)`: Completed only after QA verification, never from an agent's own report.

H rows: `| H-xx | <what is needed, from whom, why> | <status> | <needed by> |`.

## 4. Edit and commit
- Edit with the Edit tool (or `sed -i '/^| T-816 /a ...'` for an insert after a known row); update the `Last updated:` line when the change is notable.
- Commit on main as `docs(pm): <what changed> (T-xxx)` with the attribution line. Push only when the user asked for pushes (or batch it with the next push).
- If `docs/project-status.md` or `docs/plan/00-roadmap.md` now disagrees, fix them in the same commit.
