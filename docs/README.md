# Jivo Quick Commerce: Documentation

Project documentation for **Jivo Quick Commerce**, a Blinkit-style 10–30 minute delivery platform for **Jivo Wellness** products.

The system has four deliverables:

| # | Deliverable | Technology | Users |
|---|-------------|-----------|-------|
| 1 | **Customer App** (Android + iOS) | Flutter | Shoppers |
| 2 | **Rider App** (Android first) | Flutter | Delivery partners |
| 3 | **Backend API** | Django + Django REST Framework | Both apps, admin panel |
| 4 | **Admin & Store Ops Panel** (web) | Django (Django Admin + custom Django views) | Jivo staff, dark-store staff |

> Working names: *Jivo* (customer app), *Jivo Rider* (rider app), *Jivo Ops* (web panel). Final names are listed in [11-open-decisions.md](11-open-decisions.md).

---

## Document index

### Product & design
| File | What it covers |
|------|----------------|
| [01-project-overview.md](01-project-overview.md) | Vision, scope, roles, assumptions, glossary |
| [02-system-architecture.md](02-system-architecture.md) | Components, tech stack, repo layout, environments, API conventions |
| [03-customer-app.md](03-customer-app.md) | Every customer app feature and screen |
| [04-rider-app.md](04-rider-app.md) | Every rider app feature and screen |
| [05-admin-and-store-panel.md](05-admin-and-store-panel.md) | Web admin panel, store packing console, roles and permissions |
| [06-backend-modules-and-api.md](06-backend-modules-and-api.md) | Django apps, REST and WebSocket endpoints, background jobs |
| [07-data-model.md](07-data-model.md) | Database entities, fields, relationships (ER diagram) |
| [08-order-lifecycle.md](08-order-lifecycle.md) | Order, delivery and payment state machines, stock rules, dispatch logic. **Every phase is tested against this file.** |
| [09-nfr-security-compliance.md](09-nfr-security-compliance.md) | Performance, security, privacy, Indian compliance (GST, FSSAI, DLT, DPDP) |
| [10-testing-strategy.md](10-testing-strategy.md) | Test types, tools, coverage targets, the phase-gate process, bug severity |
| [11-open-decisions.md](11-open-decisions.md) | Decisions Jivo must make, with recommended defaults and long-lead items |

### Delivery plan (phase by phase)
| File | Phase |
|------|-------|
| [plan/00-roadmap.md](plan/00-roadmap.md) | Roadmap, phase order, the gate process, status tracker |
| [plan/phase-0-foundation.md](plan/phase-0-foundation.md) | Phase 0: Repo, tooling, skeleton projects, CI |
| [plan/phase-1-auth-and-users.md](plan/phase-1-auth-and-users.md) | Phase 1: OTP login, profiles, addresses, staff roles |
| [plan/phase-2-stores-catalog-inventory.md](plan/phase-2-stores-catalog-inventory.md) | Phase 2: Dark stores, serviceability, catalog, inventory, home screen |
| [plan/phase-3-cart-checkout-payments.md](plan/phase-3-cart-checkout-payments.md) | Phase 3: Cart, pricing, coupons, checkout, Razorpay and COD |
| [plan/phase-4-order-processing-store-ops.md](plan/phase-4-order-processing-store-ops.md) | Phase 4: Order state machine, store packing console, cancellations, refunds, invoices |
| [plan/phase-5-rider-app-delivery.md](plan/phase-5-rider-app-delivery.md) | Phase 5: Rider onboarding, dispatch, pickup, delivery OTP, COD cash |
| [plan/phase-6-realtime-tracking-notifications.md](plan/phase-6-realtime-tracking-notifications.md) | Phase 6: Live tracking, WebSockets, push and SMS notifications |
| [plan/phase-7-dashboard-promotions-support-reports.md](plan/phase-7-dashboard-promotions-support-reports.md) | Phase 7: Dashboard, reports, promotions, ratings, support, CMS |
| [plan/phase-8-hardening-and-launch.md](plan/phase-8-hardening-and-launch.md) | Phase 8: Security, load testing, UAT, store release, go-live |

---

## Project management deliverables

| # | Deliverable | Where |
|---|-------------|-------|
| 0 | Project requirements | [01-project-overview.md](01-project-overview.md) (scope, roles, business rules) plus the feature specs [03](03-customer-app.md), [04](04-rider-app.md), [05](05-admin-and-store-panel.md) and [08](08-order-lifecycle.md) |
| 1 | Architecture document | [02-system-architecture.md](02-system-architecture.md); admin panel: [admin-panel-architecture.md](admin-panel-architecture.md) |
| 2 | Project directory structure | [02-system-architecture.md §3](02-system-architecture.md#3-repository-layout-monorepo) |
| 3 | Database ER diagram | [07-data-model.md §1](07-data-model.md#1-entity-relationship-overview) |
| 4 | API documentation | [06-backend-modules-and-api.md](06-backend-modules-and-api.md), the contract `backend/openapi/schema.yaml`, and Swagger UI at `/api/docs/` |
| 5 | Agent task allocation | [development-phase.md](development-phase.md) (ownership, per-phase tracks, collision rules, §9 PM rules) and [task-tracker.md](task-tracker.md) |
| 6 | Development roadmap | [plan/00-roadmap.md](plan/00-roadmap.md) |
| 7 | Integration checklist | [integration-checklist.md](integration-checklist.md) |
| 8 | Final release checklist | [release-checklist.md](release-checklist.md) |
| – | Agent responsibility matrix | [development-phase.md](development-phase.md) (ownership table at the top, §9.1 roles) |
| – | Project status report | [project-status.md](project-status.md) |
| – | Technical decision log (ADR index) | [decision-log.md](decision-log.md) |
| – | Deployment documentation | [deployment.md](deployment.md) |
| – | Open API requests from the apps | [api-requests.md](api-requests.md) |
| – | QA plan, test cases, reports and bugs | `qa/docs/` and `qa/bugs/` (owned by the QA agent) |

## How to use the phase plan

1. Work happens **one phase at a time**, in order. Each phase is a *vertical slice*: backend, admin panel and app screens are built together, so the phase can be demonstrated end to end.
2. Every phase file contains:
   - **Scope** split by Backend / Admin panel / Customer app / Rider app
   - **Task checklist** (tick `- [x]` as tasks complete)
   - **Test cases** with IDs (`P<phase>-TC-<nn>`), steps, expected result and a status column
   - **Exit criteria**: all must be true before the phase closes
   - **Demo script**: the walkthrough shown at the end of the phase
   - **Sign-off**: who approved and when
3. A phase is **closed** only after it passes the gate described in [10-testing-strategy.md § Phase gate](10-testing-strategy.md#5-phase-gate-process). After that, the next phase starts.
4. If scope changes, update the relevant feature doc (`03`–`08`) **first**, then the phase file. The docs are the source of truth.

## Conventions in these docs

- **MUST / SHOULD / MAY** carry their usual meaning (required / recommended / optional).
- `v1` means the launch release. `v2` means a later release and is listed for context only.
- Money is in INR (₹). Times are stored in UTC and shown in IST.
- Library versions are **pinned in Phase 0**. The docs name libraries, not exact versions, unless a version is stated as already verified.
