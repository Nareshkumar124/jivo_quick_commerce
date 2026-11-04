# 05: Admin & Store Ops Panel (Web, Django)

The web panel is built **entirely in Django**, in two layers that share login, permissions and the database:

| Layer | URL | Built with | Used for |
|-------|-----|------------|----------|
| **Django Admin** (themed) | `/admin/` | Django Admin + django-unfold, django-import-export, custom admin actions | Master data CRUD: catalog, stores, inventory, coupons, banners, riders, customers, CMS, configuration, users/roles |
| **Ops Console** | `/ops/` | Custom Django views + templates, HTMX for partial updates, Alpine.js for small interactions, Channels WebSocket for live pushes, map JS SDK | Real-time operations: dashboard, live order board, store packing screen, dispatch, rider live map, cash deposits |

The Ops Console exists because Django Admin is good at CRUD but not at real-time, task-oriented screens such as a packing queue with sound alerts.

## 1. Ops Console screens

### 1.1 Dashboard [P7] (`/ops/`)
- KPI cards (today, filterable by store and date): orders, GMV, AOV, delivered, cancelled (%), avg delivery time, avg acceptance time, online riders, active orders
- Charts: orders per hour, GMV trend (7/30 days), top products, payment method split
- Alerts panel: orders waiting > 2 min for store acceptance, orders without a rider > 3 min, low-stock SKUs, riders over cash limit, failed deliveries

### 1.2 Live order board [P4, live updates P6] (`/ops/orders/live/`)
- Kanban columns: **Placed → Accepted → Packing → Packed → Out for delivery**, plus an exceptions lane (payment pending, delivery failed, unassigned rider)
- Each card: order no., store, age timer (turns amber/red against the SLA), items count, payment type, rider (if any)
- Filters: store, payment method, SLA breach
- Actions (by permission): open order, assign/reassign rider, cancel, add note
- Updates live via WebSocket. Falls back to HTMX polling every 10 s.

### 1.3 Store packing console [P4] (`/ops/store/<store>/`)
Designed for a tablet or desktop in the dark store. Store staff see only their store.
- **New orders** queue with an audible alert and a browser notification. Each order shows a countdown to the acceptance SLA. Optional auto-accept (store setting).
- **Accept** → **Start packing** → pick list (item, variant, qty, rack location if configured, checkbox per item) → **Mark packed**
- **Item unavailable**: mark a line (or reduce its qty) as unavailable before packing completes. The system adjusts the order, refunds the difference (prepaid) or reduces COD due, and notifies the customer. If no items remain, the order is cancelled.
- **Print**: order slip/label with order number, **4-character order code**, QR code, item count. Bag label for the rider.
- **Handover**: shows the assigned rider and their status (on the way / at store). Pickup is confirmed by the rider app scanning the code.
- **Returns**: receive failed-delivery returns and mark items restocked or damaged.
- **Store switch**: Store Manager can toggle "Accepting orders" (temporary close) and see store stock alerts.

### 1.4 Dispatch & rider map [P5, live P6] (`/ops/riders/map/`)
- Map with store markers, online riders (colour by status: idle / to store / at store / delivering), and active drop pins
- Side list of riders: status, current task, cash in hand, last ping age
- Manual dispatch: choose an order, see nearby idle riders with distance, assign (bypasses the offer, but the rider still gets a notification)
- Force a rider offline, view a rider's trip path for a task (from location history)

### 1.5 Cash deposits [P5] (`/ops/cash/`)
- Store Manager selects a rider, sees cash-in-hand, enters the amount received, and confirms. A ledger entry is created and the rider's balance is updated.
- Day-end report per store: COD collected vs deposited, and the difference.

## 2. Django Admin modules

| Module | Features | Phase |
|--------|----------|-------|
| **Users & roles** | Staff users, groups/roles, store assignment for store staff/managers, activate/deactivate | P1 |
| **Customers** | List/search by phone/name, detail with addresses, orders, tickets. Block/unblock. Anonymise on deletion request. | P1/P4 |
| **Dark stores** | Name, code, address, location pin, **service-area polygon drawn on a map** (GeoDjango map widget), opening hours per weekday, accepting-orders toggle, prep time, contact, GSTIN, FSSAI licence, invoice series prefix | P2 |
| **Pricing config** | Per store: min order, delivery fee, free-delivery threshold, small-cart fee + threshold, handling fee, COD enabled + max amount | P3 |
| **Categories** | Tree (parent/child), image, sort order, active toggle | P2 |
| **Products & variants** | Product with inline variants and images. HSN, GST rate, MRP, selling price, max qty per order, barcode, SAP item code, attributes (ingredients, nutrition JSON, shelf life), active toggle. **Bulk import/export (CSV/Excel).** | P2 |
| **Collections** | Name, slug, ordered list of variants, show on home, sort | P2 |
| **Banners** | Image (mobile ratio), link type + target, stores (all or selected), start/end datetime, sort, active | P2 |
| **Inventory** | Stock per store × variant: on hand, reserved, available (read-only), low-stock threshold, availability toggle, optional store price override. **Stock adjustment** action (inward / damage / audit correction, with a reason) creates StockMovement rows. Bulk inward via CSV. Stock ledger view. | P2 |
| **Orders** | List with filters (store, status, payment, date range, coupon). Detail with items, bill, timeline (status history), payments/refunds, delivery task, rider, notes. Actions: cancel, refund (full/partial, within role limit), resend invoice, export CSV. | P4 |
| **Payments & refunds** | Payment attempts with gateway IDs and status, refunds with status, webhook event log, reconciliation report | P3/P4 |
| **Riders** | Applications with KYC document viewer, approve/reject (reason), assign home store, set cash limit, suspend. Shifts, tasks, ratings. | P5 |
| **Rider earnings & payouts** | Earnings rules (base, per-km, incentives), per-rider earnings, payout batches (mark paid with reference), CSV export | P5/P7 |
| **Coupons** | Code, description, flat/percent, value, max discount, min order, validity window, total and per-user usage limits, first-order-only, applicable stores/categories, active. Redemption list. | P3 |
| **Notifications** | Templates (push/SMS per event), manual push campaign to a segment (all / store / inactive N days) with scheduling | P6/P7 |
| **Support** | Tickets (status, priority, assignee, conversation thread, linked order), canned replies, FAQs (category, question, answer, app = customer/rider) | P7 |
| **Ratings** | Order and rider ratings, low-rating filter | P7 |
| **CMS & app config** | Pages (About, Terms, Privacy, Refund policy) with a rich-text editor. App config: min/latest versions per app per platform, maintenance mode + message, support phone/email, global settings (payment window, cancel window, offer timeout, OTP settings) | P1/P7 |
| **Serviceability requests** | "Notify me" leads by location, shown on a map, for expansion planning | P2 |
| **Reports** | See §4 | P7 |
| **Audit log** | Who changed what and when (staff actions on orders, stock, prices, refunds, riders, config). Read-only. | P4 → P8 |

## 3. Roles & permissions

Implemented with Django Groups + model permissions + **store scoping**. Store staff and managers are linked to one or more stores and only see data for those stores.

| Capability | Super Admin | Ops/Dispatch | Store Manager | Store Staff | Catalog Mgr | Support | Finance |
|------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Manage staff users & roles | ✔ | | | | | | |
| App config, global settings | ✔ | | | | | | |
| Stores & service areas | ✔ | view | view own | | | | |
| Pricing config | ✔ | | | | | | view |
| Catalog, collections, banners | ✔ | view | view | view | ✔ | view | |
| Inventory adjust | ✔ | | ✔ own store | | | | view |
| Inventory view | ✔ | ✔ | ✔ own | ✔ own | ✔ | | ✔ |
| Live order board | ✔ | ✔ all | ✔ own | | | ✔ view | |
| Packing console | ✔ | ✔ | ✔ own | ✔ own | | | |
| Cancel order | ✔ | ✔ | ✔ own (before pickup) | | | ✔ (before pickup) | |
| Refund | ✔ | | | | | ✔ up to ₹500 | ✔ |
| Rider approval / suspend | ✔ | ✔ | view own | | | | |
| Manual dispatch | ✔ | ✔ | ✔ own | | | | |
| Cash deposit entry | ✔ | | ✔ own | | | | view |
| Payouts | ✔ | | | | | | ✔ |
| Coupons | ✔ | | | | ✔ | view | view |
| Customers (PII) | ✔ | ✔ | limited (name, masked phone on orders) | limited | | ✔ | |
| Support tickets | ✔ | ✔ | | | | ✔ | |
| Reports | ✔ | ✔ | own store | | catalog | | ✔ |
| Audit log | ✔ | | | | | | ✔ view |

Refund limits and other thresholds are settings, not hard-coded.

Phase 2 store scoping (P2 R3, code review #2): `apps.stores.services.stores_for(user)` fails closed. Superusers and the global roles (Super Admin, Ops, Catalog Manager, Support, Finance: `roles.GLOBAL_ROLES`) see every store. Anyone in a store role (Store Manager, Store Staff) sees only their `StaffStoreAccess` stores, **even if they also hold a global role** (the stricter role wins; PM decision, 2026-11-03). Unknown groups never widen access; no role means no store.

Customer moderation (P2 R3): the Customers admin blocks and unblocks through `apps.accounts.services.customers.block_customer(user_id, by=)` / `unblock_customer(user_id, by=)`. Block deactivates the account, revokes every refresh token and deactivates push devices. Both refuse staff and anonymised accounts, return whether anything changed, and record the actor as an admin log entry (no personal data in it; scrubbed again on anonymisation) until the full audit log (P4–P8). "Anonymise now" needs `accounts.anonymise_customer`, which only Super Admin holds (DL-35). Stores: pausing or resuming orders goes through `apps.stores.services.set_accepting_orders(store, accepting, actor=)` (atomic, actor in the admin log, caches refreshed).

Phase 3 permissions (R2a, PM default ⚠ until the Phase 4 order and refund screens refine them; `apps.accounts.roles`): Super Admin has every cart, coupon, order and payment permission. Catalog Manager manages coupons and views redemptions (05 §3 Coupons ✔). Support and Finance view coupons and redemptions, orders and payments/refunds (Finance also webhook events). Ops, Store Manager and Store Staff view orders (live board, packing console; store roles scoped with `stores_for`). Nobody but Super Admin may change orders through model permissions: order state changes go through `orders.services.transition()`.

Phase 4 permissions and services (R2, `apps.accounts.roles`; ⚠ PM default, T-407c): custom permissions `orders.process_order` (packing console: Super Admin, Ops, Store Manager, Store Staff), `orders.cancel_order` (T12: Super Admin, Ops, Store Manager, Support), `payments.issue_refund` (Super Admin, Finance, Support up to `SUPPORT_REFUND_LIMIT` ₹500 per refund) and `core.view_auditlog` (Super Admin, Finance view). Store roles stay scoped by `stores_for`. The screens call `apps.orders.store_ops` (accept, start packing, item unavailable, packed, cancel) and `apps.payments.order_refunds` (`manual_refund`, `retry_refund`), which re-check the permission and scope and write `core.AuditLog`. COD blocking is `apps.accounts.services.customers.set_cod_blocked(user_id, blocked, *, by)` (T-405c). `PricingConfig.clean()` bounds fees and thresholds (T-406c).

Import/export (P2 R3): CSV and Excel (`.xlsx`) only (`apps.core.export_formats`). On export, any text cell starting with `=`, `+`, `-`, `@`, a tab or a carriage return is written with a leading apostrophe, so a spreadsheet shows it as text and never runs it as a formula (CSV/formula injection); plain numbers are unchanged. The import preview is kept in Redis between the preview and confirm requests (`IMPORT_EXPORT_TMP_STORAGE_CLASS`), so it works across web processes.

Phase 1 implementation: the seven roles are Django Groups (`Super Admin`, `Ops / Dispatch`, `Store Manager`, `Store Staff`, `Catalog Manager`, `Support`, `Finance`), synced idempotently after every `migrate` (`apps.accounts.roles.sync_roles`). Each phase adds the permissions for its models. Store scoping (`StaffStoreAccess`) arrives in Phase 2 with stores. In Phase 1, Super Admin manages staff users, roles and app config; Ops and Support can view customers and block/unblock them (Customers admin, a proxy model so they cannot edit staff accounts).

## 4. Reports [P7]

All reports filter by date range and store, and export to CSV/Excel.

| Report | Contents |
|--------|----------|
| Sales summary | Orders, GMV, discounts, fees, net revenue, AOV by day/store |
| Product sales | Units and revenue per SKU, per store |
| Order SLA | Acceptance, packing, assignment, pickup-to-delivery and total time percentiles |
| Cancellations | By reason, by actor (customer/store/ops/system), by store |
| Payments | Online vs COD, success/failure rates, refunds |
| GST report | Invoice-wise taxable value, CGST/SGST/IGST by HSN and rate, for GSTR-1 preparation |
| Inventory | Current stock, low stock, stock movement ledger, stock valuation (if cost price is captured) |
| Rider performance | Deliveries, acceptance rate, avg delivery time, ratings, online hours, failed deliveries |
| Rider earnings & payouts | Per rider per period |
| COD reconciliation | Collected vs deposited per rider/store/day |
| Coupons | Redemptions, discount given, orders influenced |
| Customers | New vs repeat, cohort retention (basic) |

## 5. Panel non-functional notes
- Responsive down to tablet width (packing console). The admin is desktop-first.
- Session timeout 8 hours (store staff) / 2 hours idle (admin roles). CSRF protection. Login rate limiting.
  - Implemented in P2 R3 (BUG-0006, `apps.accounts.middleware`): **every** staff session ends 8 hours after login however active it is (`DJANGO_STAFF_SESSION_MAX_AGE_SECONDS`, stamped at login so later session saves never extend it; `DJANGO_SESSION_COOKIE_AGE` now also defaults to 8 hours). **Admin roles** also end after 2 hours without a request (`DJANGO_STAFF_SESSION_IDLE_SECONDS`). "Admin roles" = everyone except staff whose only roles are Store Manager / Store Staff: superusers, global roles, mixed roles and staff with no role all get the stricter rule. The 8-hour cap also applies to admin roles (PM decision, 2026-11-03).
  - Signed-in staff see `/admin` and `/ops` in IST (`STAFF_TIME_ZONE`); storage stays UTC.
- Every staff mutation on orders, stock, prices, refunds, riders and config is written to the audit log.
- Large lists use server-side pagination and DB indexes. Exports above ~10k rows run as Celery jobs and email or download a file.
