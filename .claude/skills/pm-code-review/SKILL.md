---
name: pm-code-review
description: "Launch the read-only code-reviewer agent on an agent's work (a commit, an uncommitted worktree or a branch diff vs develop) with a project-specific focus checklist, then triage its verdict. Use before every merge into develop, or when the user asks to review, audit or double-check an agent's run."
---

# Code review before merge

`code-reviewer` (Sonnet, read-only: Read/Grep/Glob/Bash) returns a verdict `Approve` / `Approve with fixes` / `Request changes` and findings ranked **Blocker / Major / Minor / Nit** with file:line. It never edits. Launch it in the background with the Agent tool (`subagent_type: code-reviewer`) and keep working.

## 1. Pick the target
| Situation | What to give it |
|---|---|
| Committed branch | `git -C <repo> diff develop...<agent>/phase-N` (worktree path + branch name) |
| Uncommitted run (before `pm-merge-agent-branch` step 3) | worktree path; it runs `git -C <wt> diff` + `git -C <wt> status --short` and reads untracked files |
| One commit / range | `git show <sha>` or `<a>..<b>` |

Before launching, get the scale: `git -C <wt> diff --stat develop...HEAD | tail -1`. Over ~3k lines: split by area (e.g. services+migrations, then views+tests) into separate reviews.

## 2. Brief template
```
Review <target> in C:/jivo_projects/jivo_quick_commerce/.worktrees/<name> (branch <agent>/phase-N vs develop).
Agent: <agent>. Report summary: <3-5 lines from its §9.3 report: tasks, files, tests>.
Read-only: never edit, never run migrate/seed, never print backend/.env.
Contract docs: docs/08-order-lifecycle.md, 06, 07, 05 §3, 09; decisions DL-xx relevant here.
Focus (in order): <paste the relevant areas below>.
Return: verdict, findings by severity with file:line and a concrete fix, and what you did NOT check.
```

## 3. Focus checklist by area
**Backend**
- Money only via `cart.services.compute_bill()`; `Decimal`, 2-dp strings; amount from server-side order; refunds capped at captured.
- Order status only via `orders.services.transition()` (T1–T14); delivery states only via delivery services; `OrderStatusHistory` written.
- Stock: reserve at order placement with `select_for_update()` in variant-id order; commit at T9; every `on_hand` change writes `StockMovement`.
- Side effects in `transaction.on_commit` → idempotent Celery tasks; no gateway/network calls under row locks.
- IDOR: querysets scoped to requester, never fetch-then-check; an IDOR test (other user → 404) per object endpoint.
- Error envelope + codes from `06 §6`; `Idempotency-Key` on orders/payments; new settings mirrored in `infra/env/backend.env.example`.
- Migrations: reversible, safe on existing rows, number doesn't collide with another branch; `schema.yaml` re-exported.
- Tests cite `P<n>-TC-<nn>`; coverage ≥ 90% on orders/payments/inventory/cart/delivery services.

**Admin / Ops Console**
- `05 §3` role matrix enforced server-side (view + POST), store scoping via `stores_for`; DL-35/37/39 defaults.
- State changes only through backend services; CSRF on every HTMX POST; no `@csrf_exempt`.
- PII: masked phones, rounded coordinates (DL-40), no KYC/document URLs to unauthorised roles, audit log entries.

**Flutter (customer/rider)**
- No client-side money maths; render server bill strings; rupee formatting only.
- Fakes gated to the dev flavor (DL-30/32); prod/staging never enable `FAKE_API`.
- Tokens in secure storage only; no tokens/PII in logs; error codes mapped in one place.
- `jivo_api` not hand-edited; `jivo_core` changes additive; `JivoApi(dio: dio, interceptors: const [])`, imports with `show`.
- Required headers (`X-App-Name`, `X-App-Version`, `X-Platform`, `X-Store-Id`); 426 handling.

**WebSockets / realtime**
- JWT in the first message, never in the URL; unauthenticated sockets closed with a timeout.
- Group membership scoped (customer → own orders; rider → own tasks; ops → permitted stores); IDOR test per channel.
- Rider phone and `delivery_otp` only to the order owner while OUT_FOR_DELIVERY (DL-56); polling fallback.

## 4. Triage the verdict
- **Approve** / only Minor+Nit → merge now (`pm-merge-agent-branch`); log the Minors as `T-xxxc` follow-ups in `docs/task-tracker.md`.
- **Approve with fixes** → small, mechanical fixes: send them back to the owning agent (SendMessage to the same agent, or a short fix run), re-review only the delta. If the fix is in another agent's area, route it there.
- **Request changes** / any Blocker → do not merge. Fix run first, then re-review.
- Verify findings before acting: the reviewer is Sonnet and can be wrong; spot-check each Blocker/Major at its file:line.
- A finding that is really a **policy choice** (roles, retention, money rule): decide a PM default or ask the user when it's money/stock/permissions, then add a `DL-<next>` row to `docs/decision-log.md` (date, decision, who, alternative, docs touched; mark ⚠ if Jivo must confirm).
- Mention the verdict and the review's "not checked" list in the merge commit body and the status update to the user.
