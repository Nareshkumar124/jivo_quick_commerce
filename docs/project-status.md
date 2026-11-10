# Project Status Report

This is the PM's summary view, kept short. The details are in:
- [`task-tracker.md`](task-tracker.md): tasks
- [`plan/00-roadmap.md`](plan/00-roadmap.md): phases
- [`decision-log.md`](decision-log.md): decisions

**As of 2026-11-09 · current phase: P5–P7 QA, P8 hardening · integration branch: `develop` (`9b58fa6`)**

## Overall
| Area | State |
|------|-------|
| Delivered | P0–P2 built and on `main`. P3 built; QA verdict "ready for sign-off" on the QA instance (T-310). P4, P5 (slices 5.1–5.4) and P6 built and merged to `develop`. P7 backend, customer and rider merged to `develop` (`18eaaef`, `10dbae4`, `ce741be`/`8a3f886`, `695c2e5`/`130984b`); P7 migrations applied (DL-66). P8 security (T-814), load-test harness (T-812) and backup/monitoring (T-813) merged. No phase gate is signed off. |
| Not built yet | Admin P7 screens (`admin/phase-7` has no commits); Jivo Auth SSO (D-04); P8 store releases, device matrix, pilot/UAT, production. |
| `main` | Last updated `3e4c4e0` (2026-11-04). Everything since is on `develop` only. |
| Staging | `jqc.jivo.in` is live with HTTPS on the shared server (compose project `jqc`; `9e10f01`, `c339294`). It is the **test server**: the test store was moved to West Delhi for phone testing, and the real oils catalog (DL-67) is to be loaded there once the loader is merged. |
| Team | Backend, admin panel, customer app, rider app and QA agents, plus DevOps, code reviewer, catalog data, UI designer, server deployer and GitHub publisher. The main session is PM. |

## Agents now
| Agent | Working on | Next |
|-------|-----------|------|
| QA | Stage 2 run for P5–P7 (`qa/phase-2`; P5 stage 1 committed `31a5830`/`a4a44fa`, 132 cases; P6/P7 suites uncommitted) | P5–P7 verdicts in `qa/docs/10-release-readiness-report.md`; re-verify BUG-0006/0008/0010/0011 |
| Backend (catalog import) | Bulk catalog and image loader for the shop.jivo.in data (`backend/catalog-import`, uncommitted, new migration `catalog 0002`) | Review, merge, migration approval, load onto `jqc.jivo.in` |
| GitHub publisher | Push `develop` to GitHub (local `develop` is ahead of `origin/develop`) | Update the `develop` → `main` PR |
| Admin panel | – (P7 worktree created, idle) | P7 dashboard/reports/support screens on the merged P7 services |
| Customer / Rider | – (P7 merged) | Phone tests on `jqc.jivo.in`; QA bug fixes |
| DevOps / server deployer | – (nginx 5 MB upload cap merged `7dc9b49`) | Redeploy `jqc.jivo.in` to `develop` HEAD |

## Blockers and risks
| # | Item | Impact | Action |
|---|------|--------|--------|
| R-1 | Repo is public | Business logic and infra details are exposed | Make it private (H-03) |
| R-2 | Session restarts stop the agents and the dev server | Lost time; runs resume from disk | Keep the terminal session alive; the PM resumes runs |
| R-3 | Shared remote DB server and shared staging server (other projects/sites) | Load or tests could affect others | Light load only; read-only QA SQL; guarded test DB names; single nginx site file for `jqc` |
| R-4 | `smart_auth` package is ageing (KGP warning) | A future Flutter version may refuse to build it | Native User Consent fallback is planned (04 §5) |
| R-5 | Gate backlog: P0–P7 unsigned; `main` not updated since 2026-11-04 | Phases pile up without sign-off | QA verdicts, then demo and sign-off per phase; PR `develop` → `main` |
| J-1 | Jivo catalog inputs: real GST rates and HSN, FSSAI/label info, SAP item codes, printed MRPs (DL-67 uses test GST 5% and site prices) | Prices and invoices are test-only | Jivo Finance (H-18) before go-live |
| J-2 | D-01 Razorpay keys | Fake gateway only; no real online payment | Jivo to provide test, then live keys |
| J-3 | D-02 SMS provider and DLT | No real OTP SMS (Twilio trial blocked, DL-48) | H-06 |
| J-4 | D-19 Firebase (FCM) projects | Push is a no-op; apps rely on sockets and polling | Jivo to create the projects |
| J-5 | D-11 Play Console (and Apple account) | No store release; real riders can't get background location approval | Jivo to open the accounts |
| J-6 | D-05 production hosting, D-04 SSO, D-14/D-16/D-10/D-12 defaults | Production and staff SSO blocked; PM defaults in use | H-13 and the open decisions in doc 11 |

## Next milestones
1. QA stage 2 verdicts for P5, P6 and P7; route bugs to the owners.
2. Merge the catalog import loader, apply its migration (with approval), load the oils onto `jqc.jivo.in`.
3. Push `develop`; admin P7 screens; redeploy staging.
4. Phone test of both apps against `jqc.jivo.in` (West Delhi store); store-staff and rider mini-UATs.
5. Gate sign-offs P1–P4 (human step), then PR `develop` → `main`.
