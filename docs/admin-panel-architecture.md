# Admin Panel Architecture (Django Admin + Ops Console)

Owner: `admin-panel-dev`. Spec: `05-admin-and-store-panel.md`. This page records **how** the panel is built. It does not repeat **what** the panel does.

**Technology (decided 2026-11-02).** Django Admin with django-unfold at `/admin/`, and a server-rendered Ops Console at `/ops/` using Django templates, HTMX and Alpine.js. There is no SPA, no build step and no Tailwind CLI.

## 1. Which layer hosts each module

| # | Module | Layer | Phase | Notes |
|---|--------|-------|-------|-------|
| 1 | Dashboard | Ops `/ops/` | shell P1 (real data only), full P7 | KPI cards, charts, alerts panel |
| 2 | Products (categories, products, variants, collections, banners) | Admin | P2 | Bulk import/export via django-import-export |
| 3 | Inventory | Admin | P2 | Adjustments only through `inventory.services` |
| 4 | Stores | Admin | P2 | Polygon map widget needs PostGIS |
| 5 | Orders | Admin (list/detail/actions) + Ops (live board, packing console) | P4, live P6 | Transitions only through `orders.services.transition()` |
| 6 | Riders | Admin | P5 | KYC through signed URLs only |
| 7 | Dispatch | Ops (rider map, manual assignment, cash deposits) | P5, live P6 | |
| 8 | Customers | Admin | P1 (orders P4, tickets P7) | Full-PII screen (§4) |
| 9 | Payments & finance | Admin (read) + reports | P3/P4/P7 | Display only: no money is computed in the panel |
| 10 | Promotions (pricing config, coupons) | Admin | P3 | |
| 11 | Reports | Ops/Admin | P7 | Exports over ~10k rows run as backend Celery jobs |
| 12 | Admin settings (staff users, roles, app config, lockouts, beat) | Admin | P1 | |

**Rule of thumb.** CRUD on master data goes in the Admin. Real-time, task-oriented screens go in the Ops Console.

## 2. URL map

| URL | View | Access |
|-----|------|--------|
| `/admin/` | unfold admin (sidebar grouped by module) | `is_active` and `is_staff`, then model permissions |
| `/admin/login/`, `/admin/logout/` (POST) | the one login for both layers (axes, CSRF) | public / signed in |
| `/ops/` | `ops:dashboard` | any active staff member. Each card needs its own permission. |
| `/ops/dashboard/customer-kpis/` | `ops:dashboard-kpis` (HTMX partial, polled every 60 s) | `accounts.view_customer` |
| `/ops/dashboard/signups/` | `ops:dashboard-signups` (HTMX partial: results of the data table) | `accounts.view_customer` |
| `/ops/dashboard/operations/` | `ops:dashboard-operations` (HTMX partial: stores, catalog and stock cards, polled every 60 s) | any active staff; each card group needs its own permission (§9) |
| `/admin/stores/darkstore/` | Dark stores (map editor, opening hours inline, pause/resume actions through `stores.services.set_accepting_orders`) | `stores.view_darkstore`, scoped; edit: `stores.change_darkstore` |
| `/admin/stores/serviceabilityrequest/` | Notify-me leads with a map; coordinates in the text columns rounded to 3 decimals (about 100 m, DL-40) | `stores.view_serviceabilityrequest` |
| `/admin/catalog/{category,product,productvariant,collection,banner,trendingsearch}/` | Catalog CRUD; `import/` and `export/` (CSV and Excel) on categories, products and variants | view: `catalog.view_*`; edit and import: add + change |
| `/admin/inventory/storeinventory/` | Stock per store × variant | `inventory.view_storeinventory`, scoped |
| `/admin/inventory/storeinventory/<id>/adjust/` | Adjust one row (inward / damage / audit count) | `inventory.adjust_stock` + the row's store (`can_adjust_stock`) |
| `/admin/inventory/storeinventory/inward/` | Bulk stock inward (CSV upload or pasted rows, preview first) | `inventory.adjust_stock`; stores limited to the user's |
| `/admin/inventory/stockmovement/` | Stock ledger (read-only for everyone) | `inventory.view_stockmovement`, scoped |
| `/admin/stores/pricingconfig/` | Pricing config per store (P3): ₹ inputs, defaults note for stores without a row, history (view-only), no delete | `stores.view_pricingconfig` (Super Admin, Finance), scoped; edit and add: `stores.change/add_pricingconfig` (Super Admin) |
| `/admin/promotions/coupon/` | Coupons (P3): CRUD, state filter (live / scheduled / expired / switched off), usage summary, history (view-only); delete only while never used | `promotions.view_coupon` (Super Admin, Catalog Manager, Support, Finance); add / change / delete: Super Admin, Catalog Manager |
| `/admin/promotions/couponredemption/?coupon=<id>` | Redemptions (read-only for everyone); customer per the PII policy | `promotions.view_couponredemption`, scoped through the order |
| `/admin/orders/order/` | Orders (P3: read-only for everyone): list, detail with the stored bill, address snapshot, items, payments, refunds and status history | `orders.view_order` (Super Admin, Ops, Store Manager, Store Staff, Support, Finance), scoped |
| `/admin/payments/payment/`, `/admin/payments/refund/` | Payment attempts and refunds (read-only); gateway data as an allow-listed summary | `payments.view_payment` / `view_refund` (Super Admin, Support, Finance), scoped through the order |
| `/admin/payments/paymentwebhookevent/` | Signed gateway events (read-only); payload as an allow-listed summary | `payments.view_paymentwebhookevent` (Super Admin, Finance) |
| `/admin/accounts/customer/` actions "Block / Allow cash on delivery" | `User.cod_blocked` (DL-43) | `accounts.change_customer` + full PII (Super Admin, Ops, Support) |

Money on every screen is formatted by `ops_console.money.inr()` (two decimals, Indian grouping, "₹1,299.00"); it never adds anything up. Money inputs use `RupeeInput` (a "₹" prefix).

| `/ops/orders/live/` (+ `columns/` HTMX partial, polled every `OPS_POLL_SECONDS`, default 10 s) | Live order board (P4): Placed → Accepted → Packing → Packed → Out for delivery, exceptions lane (payment pending, delivery failed); filters store / payment / SLA breached; cards carry no customer data | capability `live_board` = `orders.view_order` + `orders.cancel_order` (Super Admin, Ops, Store Manager own, Support), scoped |
| `/ops/orders/<id>/cancel/` (POST) | Cancel with a reason (T12) through `order_actions.cancel` | capability `cancel_order` = `orders.cancel_order` (Super Admin, Ops, Store Manager own, Support), scoped (other store: 404) |
| `/ops/store/` | Packing console store picker (one store: redirect) | capability `packing` = `orders.process_order` (Super Admin, Ops, Store Manager own, Store Staff own) |
| `/ops/store/<code>/` (+ `queues/` partial) | Packing console (P4, 05 §1.3 minus returns): New / Accepted / Packing / Packed queues, acceptance countdown, pick list with rack location and ticks, new-order sound + browser notification, low-stock link | capability `packing`, store looked up inside `stores_for` (other store: 404) |
| `/ops/store/<code>/orders/<id>/{accept,start-packing,mark-packed}/`, `unavailable/`, `cancel/` (POST) | T6, T7, T8, T8a, T12 through `order_actions` | `packing` (cancel: `cancel_order`); order inside the store (else 404) |
| `/ops/store/<code>/accepting/` (POST) | Pause / resume orders (`stores.services.set_accepting_orders`) | capability `toggle_store`: `stores.change_darkstore` or store view + `inventory.adjust_stock` (Super Admin, Store Manager own; no dedicated permission yet) |
| `/ops/store/<code>/orders/<id>/slip/` | Printable slip + bag label: order number, pickup code, QR of the code, item count; no customer data | `packing`; PACKING / PACKED orders of the store only |
| `/admin/core/auditlog/` | Audit log (P4): `core.AuditLog` read-only; actor as staff name (a non-staff actor as "Customer <id>"), never the IP; search by record id | `core.view_auditlog` (Super Admin, Finance) |
| `/admin/admin/logentry/` | Admin history: `LogEntry` read-only; for roles without full PII, people and staff-access records shown as "<type> <id>" and structured change messages without related objects' names; search by record id only | capability `audit_log` = `core.view_auditlog` |
| `/admin/payments/refund/` action "Retry failed refund" | T-401c: `payments.order_refunds.retry_refund(refund_id, by=)` via `order_actions`, once per refund; the service decides (failed or stuck pending, never twice, audit) | capability `retry_refund` = `payments.issue_refund` (Super Admin, Finance, Support up to its limit) |
| `/admin/accounts/customer/<id>/` | P4 adds recent orders (scoped, linked) and refunds (`payments.view_refund` roles); "See all orders" = `/admin/orders/order/?customer=<id>` | as the Customers admin |

| `/admin/orders/order/<id>/refund/` ("Issue refund", detail action) | Manual refund, full or partial (05 §2, QA BUG-0010): shows the server's refundable amount, posts once (one-time token `once.MANUAL_REFUND` + `submit_once.js`), calls `order_refunds.manual_refund` via `order_actions`; the role limit, cap and ONLINE-only refusals come back as form errors | capability `issue_refund` = `payments.issue_refund` (Super Admin, Finance, Support up to its limit), order looked up in the scoped queryset |
| `/admin/orders/order/export/` | CSV / Excel export of the filtered, store-scoped list (BUG-0011): masked phone and no address for roles without full PII; money as two-decimal numbers (Excel cells are text: known XLSX type gap); formula escaping from the project formats | `orders.view_order` |
| `/admin/delivery/rider/`, `riderdocument/`, `ridershift/`, `riderlocation/` | Riders (P5): review actions (approve, reject, suspend, reinstate, home store, cash limit; approve / reject document; open the KYC file through a signed URL; show the document number) only through `apps.delivery.services.kyc` with `ip=`; everything else read-only; PII per role; locations rounded to 4 decimals | view: `delivery.view_*` (Super Admin, Ops, Store Manager own) scoped by `kyc.staff_riders`; review: `delivery.review_rider`; files and numbers: `delivery.view_kyc_document_file`; locations: Super Admin |
| `/ops/mfa/setup/`, `/ops/mfa/verify/`, `/ops/mfa/recovery/` | Staff two-step sign-in (H2, DL-59; interim until Jivo SSO, D-04): django-otp 1.7.5 TOTP + 10 recovery codes shown once; `ops_console.mfa.staff_mfa_middleware` sends privileged staff who are not verified in this session here from any `/admin/` or `/ops/` page (HTMX: 401 + `HX-Redirect`); Super Admin resets a device from Staff users (audited `staff.mfa_reset`); django-otp's own device admins are unregistered | Super Admin, Finance, Support, superusers (Ops with `STAFF_MFA_INCLUDE_OPS`); `STAFF_MFA_ENFORCED` (off in the test settings) |
| `/ops/csp-report/` | CSP violation reports (L7), logged in short form (directive, blocked URI, page path without query) | public POST, CSRF-exempt, 16 KB max |

**Content-Security-Policy (L7).** `ops_console.csp.report_only_csp_middleware` sends `Content-Security-Policy-Report-Only` on every `/admin/` and `/ops/` response (`CSP_REPORT_ONLY = False` switches to enforcing after a week of clean reports): scripts from our origin plus a per-request nonce (`request.csp_nonce`) and `'unsafe-eval'` (Alpine's standard build, ours and unfold's, and htmx trigger filters evaluate expressions; removing it needs Alpine's CSP build and rewriting every inline expression), inline styles allowed, images from our origin, `data:`/`blob:` and the OpenStreetMap tiles, `frame-ancestors 'none'`, `object-src 'none'`, `form-action 'self'`.

Planned additions: `/ops/riders/map/` (P5), `/ops/cash/` (P5), `/ws/ops/live/` (P6).

**Navigation.** One registry, `apps/ops_console/navigation.py` (`MODULES`), feeds both the unfold sidebar (`config/admin_ui.py`) and the Ops sidebar. Each item names its permissions, and a section with no allowed item is hidden. Adding a module therefore means adding one `NavItem`.

## 3. Code layout

```
backend/
  config/admin_ui.py                 UNFOLD settings (imported by settings/base.py); no model imports
  apps/<app>/admin.py                ModelAdmins (thin; actions call services)
  apps/ops_console/
    access.py      ops_view(*perms): staff gate, permission gate, HTMX-aware refusals, IST rendering
    navigation.py  module registry → unfold sidebar + Ops sidebar
    scoping.py     store scoping for querysets and list filters (stores_for)
    admin_support.py  service errors on forms, dry_run(), read-only scoped history, import/export
                      permissions, upload limits (LimitedImportForm), formula unescaping on import
    maps.py        map editor widget + read-only maps (swap point for Mappls)
    selectors.py   read-only queries (never write, not even get_or_create)
    dashboard.py   dashboard blocks (chart spec, tables)
    tables.py      DataTable: search, filters, pagination from GET params
    capabilities.py  05 §3 order/refund/audit capabilities (interim permission combinations)
    order_actions.py the ONE adapter to the backend services that change orders, refunds, stores
    board.py, packing.py, sla.py   live board / packing console reads and SLA timers
    order_views.py, forms.py       Phase 4 Ops views (thin) and their input forms
    admin.py       audit log viewer (LogEntry, read-only)
    pii.py         masking policy (§4)
    status.py      status badges: label + tone per state (08 §1, §3, §4; customer statuses)
    dates.py       DISPLAY_TZ = Asia/Kolkata helpers
    templatetags/ops.py   {{ phone|phone_for:user }}, {% status_badge kind code %}
  templates/ops/
    base.html                 standalone layout (does not extend unfold's skeleton)
    includes/sidebar.html, includes/header.html
    components/               the partials library (below)
    partials/                 HTMX fragments per screen
    errors/403.html, errors/403_partial.html
  templates/admin/<app>/<model>/...   admin overrides (e.g. anonymise confirmation, stock adjust / inward pages)
                                      (import/export and history screens: unfold.contrib.import_export and
                                      unfold.contrib.simple_history templates, no overrides)
  apps/catalog/admin/                 package: ModelAdmins (__init__), forms, import/export resources
  static/ops/{vendor,css,js}/
```

**Components** (`templates/ops/components/`, each documents its parameters in a header comment):

| Component | Use |
|-----------|-----|
| `data_table.html` + `data_table_results.html` + `pagination.html` | Server-side search, filters and pagination. HTMX swaps **only the results region**, so the search box keeps focus. Built from `tables.DataTable(...).context()`. |
| `form_field.html` | Label, widget (unfold classes), help text, errors |
| `confirm_dialog.html` | One Alpine dialog per page. It replaces `window.confirm` for `hx-confirm` and for `<form data-ops-confirm>`. |
| `loading.html`, `empty_state.html`, `error_state.html` | Request indicator (`htmx-indicator`), no-data and error states (with an HTMX retry) |
| `kpi_card.html`, `chart_card.html` | KPI tile; Chart.js card with a `json_script` spec and a "Show data" table for accessibility |
| `status_badge.html` | Wraps unfold's `label.html` with the tone from `status.BADGES` |
| `toasts.html` | Alpine toast store. It also renders Django `messages`. |

**Visual consistency.** The Ops layout loads unfold's fonts, `unfold/css/styles.css` and the same theme colours (from `admin.site.each_context`), and it follows the admin's light/dark choice (`static/ops/js/theme.js`). Unfold's CSS is purged Tailwind, so only utilities that unfold's own templates use exist. Anything else goes into `static/ops/css/ops.css` as plain CSS on the unfold colour variables.

## 4. Permissions (05 §3), enforced server-side

- **Staff gate.** Every Ops view is wrapped in `ops_view(...)`. It requires `is_active` and `is_staff`, the same rule as the admin site. Others are redirected to the admin login.
- **Permission gate.** `ops_view("app.perm", ...)` checks `user.has_perms`. Staff without the permission get a 403 page.
  - The 7 roles are data: Groups synced by `apps.accounts.roles.sync_roles()`, which the backend owns.
  - Checks are by **permission, never by group name**.
- **Admin.** Standard `has_*_permission`, with these overrides:
  - **Customers admin.** Requires full-PII access, which is `accounts.view_customer` per 05 §3 "Customers (PII)". "Limited" roles (Store Manager, Store Staff) are refused even if granted `change_customer`, because the screen shows phones in titles, breadcrumbs and search.
  - **Address and device inlines** follow that same check. They are read-only.
  - **The 7 managed roles** are read-only in the Groups admin and cannot be deleted. `sync_roles()` resets their permissions on every migrate, so admin edits would be silently lost. Custom groups stay editable.
- **Store scoping (Phase 2+).** `get_queryset` is filtered by `stores.services.stores_for(user)` (`ops_console.scoping.StoreScopedAdminMixin`). Never fetch by id and then check: scope the queryset. `stores_for` fails closed: a user in a store role (Store Manager, Store Staff) sees only their `StaffStoreAccess` stores even if also in a global role (the stricter role wins, DL-39), and unknown groups never widen access.
  - Another store's object is a **404** everywhere: the admin change, delete and history views (`StoreScopedAdminMixin.get_object` raises `Http404` instead of Django's redirect to the index), custom views (`get_object_or_404` on the scoped queryset) and simple-history pages.
  - Store list filters list only the user's stores (`ScopedStoreFilter`); the default related-field filter would show every store's name.
  - Store assignment is an inline on the staff user (Super Admin), saved through `grant_store_access` / `revoke_store_access`; the admin LogEntry records it.
- **History pages** (django-simple-history) are read-only and scoped (`admin_support.ReadOnlyHistoryAdmin`): stock `SimpleHistoryAdmin` falls back to the historical record for objects outside `get_queryset()` and accepts a revert POST even when revert is disabled.
- **Import/export.** django-import-export lets any staff member import when `IMPORT_EXPORT_IMPORT_PERMISSION_CODE` is unset, so every import admin uses `ImportExportPermissionsMixin`: import needs add + change on the model, export needs view.
  - **Formats** come only from `IMPORT_EXPORT_FORMATS` (`apps.core.export_formats`: CSV and Excel, owned by the backend). Their export escapes spreadsheet formulas: a text cell starting with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading `'`; plain numbers such as `-3` stay as they are. An admin never sets `import_formats` / `export_formats` back to django-import-export's stock CSV (guard test `apps/catalog/tests/test_admin_import_export.py`).
  - **Import normalisation** (`admin_support.SpreadsheetImportMixin` on every catalog resource): empty rows dropped, empty Excel cells read as empty text like CSV, and the export's apostrophe removed again, so an exported file (CSV or Excel) imports back unchanged.
  - **Uploads** go through `admin_support.LimitedImportForm`: at most 1 MB and 2000 rows (records, not lines), CSV must be UTF-8, and an .xlsx must be a real workbook that unpacks to at most 20 MB. It runs when the form validates, before django-import-export stores the file (Redis) or parses it. The stock inward CSV uses the same limits.
- **Store price override.** Super Admin / Catalog Manager only (`apps/accounts/roles.py`). Until a dedicated permission exists it is gated on `catalog.change_productvariant` (the price authority).
- **Anonymise now** (irreversible): needs `accounts.anonymise_customer`, held only by Super Admin (DL-35, DL-39; superusers hold every permission). The action is hidden from everyone else and checked again inside it.
- **Block / unblock** need `accounts.change_customer` (Super Admin, Ops, Support) and call `accounts.services.customers.block_customer` / `unblock_customer` once per selected customer. Their refusals (staff, anonymised or unknown accounts) are shown as warnings, grouped by reason.
- **Notify-me leads** (Super Admin, Ops): the text columns round coordinates to 3 decimals, about 100 m (DL-40). The leads map keeps the points for expansion planning.
- **Orders and money screens (Phase 3).**
  - Orders, payments, refunds and coupon redemptions are scoped with `StoreScopedAdminMixin` (`store_field = "store"` or `"order__store"`); another store's order is a 404 on the change and history pages and never listed. No store role holds a payment permission today; the scoping is fail-closed defence.
  - Every Phase 3 order and money screen is read-only for everyone, superusers included (`has_add/change/delete_permission` return False, no actions). Order actions arrive in Phase 4 through `orders.services.transition()` and the refund services.
  - Payment and refund inlines on an order appear only with `payments.view_payment` / `view_refund` (Django checks the inline model's permission).
- **PII on order screens** (`ops_console.pii`): roles with `accounts.view_customer` (Super Admin, Ops, Support) see the customer and the delivery address in full and may search orders by customer or receiver phone. Everyone else (Store Manager, Store Staff, Finance; Catalog Manager on redemptions) sees the name and a masked phone, the address locality only (area, city, state, pincode: no house, street, landmark or pin), no free text the customer wrote (delivery note, cancel note, timeline note; staff and system notes stay visible), and searches by order number or coupon code only, so a masked phone cannot be recovered by searching digit by digit. `str(user)` is never rendered: people are shown with `customer_label` / `person_label`, and display methods never reuse a model field's name (Django would render the field instead).
- **Gateway data.** `Payment.raw` and `PaymentWebhookEvent.payload` (the customer's contact, email, VPA and card details) are never rendered, even for superusers. The pages show only the allow-listed scalar keys of each entity (`pii.GATEWAY_SAFE_KEYS`: ids, states, method, amounts in paise, error codes).
- **Pricing config** is a standalone admin (Finance has `view_pricingconfig` but not `view_darkstore`). View-only roles see the amounts in rupees.
- **Coupons.** Panel rules on top of `Coupon.clean()`: a percent coupon needs a cap, a flat coupon has none, codes are unique ignoring case and have no spaces. The redemption link uses a plain `?coupon=<id>` filter (Django's related-only filter is dropped, and its parameter silently ignored, while only one coupon has been used).
- **PII masking.** `pii.display_phone(user, phone)` and `{{ phone|phone_for:request.user }}` show the full number only with `accounts.view_customer`. Everyone else sees `+91 XXXXXX2233`. Masking first applies on order screens (P4). Order screens must also avoid rendering `str(user)`, which is the phone.
- **Phase 4 capabilities** (`ops_console/capabilities.py`) map the 05 §3 rows onto the backend's Phase 4 permissions (`apps.accounts.roles`): `orders.process_order` (packing), `orders.cancel_order` (cancel; with `orders.view_order` also the live board), `payments.issue_refund` (refund retry), `core.view_auditlog` (audit), and for the store switch `stores.change_darkstore` or store view + `inventory.adjust_stock` (Super Admin, Store Manager). Until those roles are on the branch, interim combinations of the Phase 3 grants select the same roles. `ops_view(capability=...)`, `NavItem(capability=...)` and the admin checks all go through `capabilities.allowed()`; the role sets are pinned in `tests/helpers.py`.
- **Hiding a link is not a permission.** The sidebars hide refused links, but every view and ModelAdmin checks again.
- **Tests.** Each screen has a role-matrix test covering the 7 roles, a superuser flag, a non-staff user and an anonymous visitor (`apps/ops_console/tests/helpers.py`). From P2, each screen also needs an other-store test.

## 5. State changes

- Admin actions and Ops buttons are **thin wrappers around backend services**: `orders.services.transition()`, `inventory.services.adjust(...)`, dispatch, refunds, and so on. The panel never calls `.save()` to change an order, task, payment, stock or rider status. If a service is missing, the screen waits and the gap is reported.
- Ops POSTs are HTMX requests with the CSRF token in `hx-headers` on `<body>`. Irreversible actions need a confirmation: `hx-confirm`, or an intermediate admin page like "Anonymise now".
- **One adapter for state changes (Phase 4):** `ops_console/order_actions.py` is the only module the order screens, the refund retry and the COD block call: `orders.store_ops` (`accept_order`, `start_packing`, `mark_item_unavailable` one call per line, `mark_packed`, `cancel_by_staff` with `StaffCancelReason`), `payments.order_refunds.retry_refund`, `stores.services.set_accepting_orders`, `accounts.services.customers.set_cod_blocked`, all with `by=` (the store switch: `actor=`). A contract test compares their signatures. A service missing on the branch makes `available()` False (button hidden or disabled) and a crafted POST gets `ActionUnavailable` (HTTP 501). Refusals become `ActionRefused` with the service's message in `X-Ops-Message`: `PermissionDenied` 403, "not found" 404, validation 400, `ApiError` (wrong state) 409. Successful buttons answer 204 + `HX-Trigger: {"ops:toast", "ops:refresh"}` so the polled region reloads at once.
- The panel only displays money and never computes it. Amounts come from records produced by `cart.services.compute_bill()` and the payment services.
- Every staff mutation on orders, stock, prices, refunds, riders and config goes through the backend's audit mechanism (`AuditLog`, P4–P8; django-simple-history where the backend enabled it).
  - **With history:** `ProductVariant` (prices), `StoreInventory` (availability, threshold, store price), `PricingConfig` and `Coupon` (field changes; its stores and categories are not in the history rows, only in the admin `LogEntry`). Stock itself is audited by the `StockMovement` ledger (who, when, why).
  - **Recorded by the services as an admin `LogEntry`** (until `AuditLog`): customer block and unblock (`object_repr` is "Customer <id>", never the phone) and store pause / resume (`set_accepting_orders`).
  - **Cash on delivery block (DL-43):** `accounts.services.customers.set_cod_blocked(user_id, blocked, *, by)` (T-405c; the admin's interim copy is gone), called through `order_actions`.
  - **App configuration** `payment_window_minutes` (DL-43) is edited on the App configuration page (Super Admin); like the rest of `AppConfig` it has no history yet (gap above).
  - **Without history (gap, reported):** `DarkStore` field edits (GSTIN, invoice prefix, areas), `StoreTiming`, `Product` (GST, HSN), `Category`, `Collection`, `Banner`, `StaffStoreAccess`, and the Phase 1 mutations (anonymise, `AppConfig`, `AppVersionPolicy`, staff role membership). Until then Django's `LogEntry` (admin history) is the only trail.
- **Inventory (Phase 2).** The admin never writes stock fields:
  - `on_hand` and `reserved` are read-only in every admin, inline and form; there is no import resource for `StoreInventory`; `StockMovement` has no add, change, delete or actions, even for superusers (guard test: `apps/inventory/tests/test_admin.py`).
  - Adjustments call `adjust_stock` / `set_counted_stock`; bulk inward calls `apply_inward_batch`; settings call `set_availability`, `update_inventory_settings` and `set_price_override`.
  - Forms validate by running the service inside a rolled-back transaction (`admin_support.dry_run`), so the service's messages (MRP limit, reserved stock, quantity bounds) show on the form instead of a 500. The CSV inward preview is the same dry run.
  - If the real call still fails after validation (another user lowered the MRP in between), the inventory change view rolls back the whole save, including settings applied before the failing one, and redirects back to the form with the message. No "changed successfully" and no history row.

## 6. Static assets (vendored and pinned)

| File | Version | Source | sha256 |
|------|---------|--------|--------|
| `static/ops/vendor/htmx-2.0.4.min.js` | htmx 2.0.4 | `cdn.jsdelivr.net/npm/htmx.org@2.0.4/dist/htmx.min.js` (same build unfold ships, minus a trailing newline) | `e209dda5c8235479f3166defc7750e1dbcd5a5c1808b7792fc2e6733768fb447` |
| `static/ops/vendor/alpinejs-3.16.1.min.js` | Alpine.js 3.16.1 | `cdn.jsdelivr.net/npm/alpinejs@3.16.1/dist/cdn.min.js` (byte-identical to unfold's copy) | `04656d770039b55ac7a37aeecb92191de2c7775f61f2d0183331cc16c13f3f1e` |
| `unfold/js/chart/chart.js` (not copied) | Chart.js 4.4.0 | shipped by django-unfold 0.110.1 (pinned in `uv.lock`) | n/a |
| `static/ops/vendor/ol-7.2.2.min.js` | OpenLayers 7.2.2 (the version Django 5.2's `OSMWidget` pins) | `cdn.jsdelivr.net/npm/ol@7.2.2/dist/ol.js`, minus the trailing `//# sourceMappingURL=ol.js.map` line (no map is shipped) | `eab867af2bf8fe7fae86c21159448d9676eb1bca1e11a10434a9884b86950aa7` (upstream: `12d3babf6b47adc2bc4b6acd1fb3279752fa66c219d7856f12788a92c49a642e`) |
| `static/ops/vendor/ol-7.2.2.css` | OpenLayers 7.2.2 | `cdn.jsdelivr.net/npm/ol@7.2.2/ol.css` (unchanged) | `065779b56c76f9ba2966e30f29c721b197c1eda4be93e73c4c16cd5138fec1c9` |

| `static/ops/vendor/qrcode-generator-1.4.4.js` | qrcode-generator 1.4.4 (Kazuhiko Arase, MIT) | `cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.js` (unchanged) | `18ae399f81182bc9de916e9c77b195df20cc58d6f2d55a62b085a299f1bf1780` |

- **Versions match unfold's**, so `/admin` and `/ops` behave the same. Upgrade deliberately: new filename, update this table, run the tests.
- **Load order.** `base.html` loads the scripts deferred in this order: htmx, Chart.js, `ops.js`, then Alpine. `ops.js` registers its Alpine stores on `alpine:init`.
- **Alpine plugins.** None are loaded, so `x-trap`, `x-persist` and similar are not available. Vendor a plugin before using it.
- **Maps (Phase 2, interim).** The Mappls web key is not available yet (H-16), so stores use GeoDjango's OpenLayers editor (`ops_console.maps.MapEditWidget`, OpenLayers served from `/static/`) and read-only maps use `static/ops/js/geo_map.js`. **Only the map tiles load at runtime, from tile.openstreetmap.org.** The Mappls switch (DL-29) is local to `ops_console/maps.py` and `geo_map.js`; its key/config files are secrets and are never committed.
- **No CDN at runtime.** Everything is served from `/static/`.

## 7. HTMX: CSRF, errors, session expiry

| Situation | Server | Client (`static/ops/js/ops.js`) |
|-----------|--------|---------------------------------|
| Any POST | `CsrfViewMiddleware` | `hx-headers='{"X-CSRFToken": …}'` on `<body>` |
| Signed out / session expired / not staff | Full page: 302 to `/admin/login/?next=…`. HTMX: **401 + `HX-Redirect`** to the login, with `next` = the page in `HX-Current-URL` (a 302 would swap the login page into the target). | htmx follows `HX-Redirect`. A 401 without it falls back to a redirect to the login. |
| Staff without permission | 403. Full page: `errors/403.html`. HTMX: a partial plus the `X-Ops-Refused: 1` header. | Toast: "Access refused: your role does not allow this." Any other 403 (e.g. CSRF) gets a "reload and try again" toast. |
| 404 / 5xx / network / timeout | Standard | Warning or error toast. Error responses are never swapped in. |
| Success messages | `HX-Trigger: {"ops:toast": {"message", "tone"}}` or Django `messages` | Toast |

**Other client settings.** Ops responses are `never_cache`. The htmx history cache is turned off (`historyCacheSize = 0`) so PII never lands in `localStorage`. Views render in IST (`timezone.override`), while stored times stay UTC. The backend's staff time-zone middleware (`apps.core.middleware.staff_timezone_middleware`) also renders `/admin` in IST, and admin forms take times in IST.

**Polling, alerts and SLA (Phase 4; UX audit `design/audits/2026-11-04-packing-console.md` PC-01..06, specs `design/screens/ops/cant-supply-dialog.md` and `design/system/components/ops-alert-banner-and-sla-badges.md`, tokens `design/tokens/ops.tokens.json` aliased as `--ops-*` in `ops.css`).**
- The live board and the packing queues poll with `hx-trigger="every Ns[opsPollAllowed('<id>')], ops:refresh from:body"`. A poll is skipped only while a dialog is open or the user types in a **text** field inside the region (never for checkboxes), and never for more than 30 s.
- SLA (`ops_console/sla.py`): PLACED counts against the backend's `STORE_ACCEPTANCE_SLA_SECONDS` (default 60 s, the same value as its acceptance alert); later states count against `eta_at`; DUE SOON in the last `OPS_SLA_WARNING_FRACTION` (0.25). Every ticket and card shows a DUE SOON / LATE badge in words plus "12m left" / "3m late" (`{% sla_badge %}`, ticked every second by `ops/js/orders.js` with the same rules). LATE tickets come first with a "LATE (n)" divider and a "n late" pill.
- Alerts live in `#ops-alerts`, outside the polled regions: `new` / `urgent` (console), `stale` (no successful poll for 25 s), `breach` (board). The `paused` banner is server-rendered in the swapped store bar. A "Start taking orders" tap per page load unlocks audio; the alert repeats every 15 s, every 5 s from the oldest order's warning time, with a 2-minute mute only; the tab title shows the count; announcements go to `#ops-announcer` once per event. Pause / resume swaps `#store-bar` in place (no reload), so the unlock survives. Network toasts: one per outage.
- "Can't supply" (T8a): a per-line dialog with quantity chips (stepper above 6) that posts the line's new **total** (the form refuses a decrease; the same total again is a no-op in the service). `packing.py` gives each line `to_pack` and `would_empty`. Danger confirmations open with focus on the safe button. The pick list and slip show "Pack N" (units still to pack).
- Tickets show stored amounts only: COD "rider collects `grand_total`", online "bill `grand_total`", and `amount_refunded` when above zero.
- Pick-list ticks live in `sessionStorage` (a packing aid; the server checks the T8 guard). Page scripts that register Alpine components go in the `page_scripts` block of `ops/base.html`, which loads before Alpine.

**Sessions** (backend, `apps/accounts/middleware.py`, 05 §5): every staff session ends 8 h after login; admin roles (everyone except staff whose only roles are Store Manager / Store Staff) also after 2 h without a request. Expired sessions are signed out before the view runs, so `/ops` HTMX requests get the 401 + `HX-Redirect` above.

## 8. Module rollout per phase

| Module | Admin / Ops | Phase |
|---|---|---|
| Admin settings: staff users, roles/permissions, system config (app versions, maintenance) | Admin | P1 (exists, polish) |
| Customer management: details, addresses, block/unblock | Admin | P1. Order history P4, tickets P7 |
| Store management: stores, location, hours, service-area polygon on a map, accepting-orders toggle | Admin | P2 |
| Product management: categories, products, variants, images, pricing (MRP / selling / store override), bulk import/export | Admin | P2 |
| Inventory: store-wise stock, adjustments (through the service), ledger, low-stock | Admin | P2 (alerts P2/P7) |
| Collections and banners | Admin | P2 |
| Pricing config, coupons | Admin | P3 |
| Payments and refunds (read), webhook log | Admin | P3/P4 |
| Order management: list, detail, timeline, cancel and refund through services; live order board; packing console | Admin + Ops | P4 (live P6) |
| Rider management: applications, KYC viewer, approve/reject, home store, cash limit, suspend | Admin | P5 |
| Dispatch: rider map, manual assignment, cash deposits | Ops | P5 (live P6) |
| Notifications: templates, campaigns | Admin | P6/P7 |
| Dashboard: KPIs, charts, alerts panel | Ops `/ops/` | P7 (a shell with real available data earlier) |
| Reports: sales, products, SLA, riders, stores, GST, COD | Ops / Admin | P7 |
| Support tickets, ratings, CMS pages | Admin | P7 |
| Audit log viewer | Admin | P4–P8 |

## 9. Dashboard definitions (Phase 1 shell, Phase 2 cards)

| Card | Definition | Permission |
|------|-----------|------------|
| Customers: total, active, blocked, deletion requested | Non-staff accounts (riders included until P5), excluding anonymised. Status precedence: anonymised > deletion requested > blocked > active. Total = active + blocked + deletion requested. | `accounts.view_customer` |
| New today / new in the last 7 days | Account creations since IST midnight, and over the last 7 IST calendar days including today. Accounts anonymised later still count as sign-ups. | `accounts.view_customer` |
| Sign-ups per day (chart) | The same, per IST day for 14 days, zero-filled | `accounts.view_customer` |
| Recent sign-ups (table) | Newest first. Search covers name, phone and email; filter by status; 10 per page. | `accounts.view_customer` |
| Active staff per role | Active staff in each of the 7 roles, plus superusers and staff without a role | `accounts.view_user` |
| App configuration | Maintenance on/off, message, and the min/latest version per app and platform, read from the DB (never created) | `cms.view_appconfig` |

Phase 2 cards (`selectors.operations_stats`; every count limited to `stores_for(user)`, so a Store Manager sees only their stores and the page says so):

| Card | Definition | Permission |
|------|-----------|------------|
| Active stores / Open now / Paused | Active stores; of those, open now (`stores.services.store_status`: accepting orders and inside an IST opening window); and not accepting orders | `stores.view_darkstore` |
| Active products / Active SKUs | Active products; active variants of active products (catalog is central, not scoped) | `catalog.view_product` |
| Low-stock SKUs / Out of stock | Store × variant rows **on sale** (switched on, active store, active variant and product) whose available (on hand − reserved) is below the row's threshold, as the inventory service alerts; out of stock = on sale with nothing available. Each card links to the inventory list with the same filters (`?stock=low&on_sale=1`). | `inventory.view_storeinventory` |

Order, GMV and rider cards are **absent** until their phases. The panel never shows placeholder numbers. Phase 3 adds no dashboard card: 05 §1 puts the order KPIs in P7 and the live order board in P4.

## 10. Catalog import/export format (CSV)

The contract with the `catalog-data` agent and Jivo's SAP exports (D-17). Defined in `apps/catalog/admin/resources.py`; change both together.

**General rules**
- **Files.** UTF-8 CSV (a BOM is fine), comma-separated, or an Excel workbook (.xlsx, first sheet). Header row first with exactly these column names. One file per resource, imported in this order: categories, products, variants. Choose the format that matches the file (CSV or xlsx); old .xls files must be saved as .xlsx first.
- **Limits.** At most 1 MB and 2000 rows per file (a quoted cell with line breaks is one row). Rows with no value at all (Excel's formatted empty rows) are ignored, and an empty Excel cell means the same as an empty CSV cell (rules below). Error messages count rows after those empty rows are removed. Larger catalogs: split the file.
- **Formula escaping.** Export writes a text cell that starts with `=`, `+`, `-`, `@`, a tab or a carriage return with a leading apostrophe (`'=1+1`), so a spreadsheet shows it as text and never runs it. Import removes exactly that apostrophe again, so an exported file imports back unchanged. Plain numbers (`-3`, `349.00`) are never escaped. Known gap (backend): Excel exports currently store numbers as text cells, because django-import-export only sends native types for its own exact XLSX class (strict xfail test `test_xlsx_numbers_stay_numbers`); they still import back correctly.
- **Where.** Admin → Categories / Products / SKUs → Import. Import needs add + change on the model (Super Admin, Catalog Manager); export needs view. The import first shows a **dry run** preview (nothing saved), then **Confirm import** saves it.
- **Matching.** Rows match existing records by their key (category and product `slug`, variant `sku`): an existing key updates the record, a new key creates it. **Imports never delete.** Unchanged rows are skipped.
- **Validation.** Every row runs the model validation, and any error blocks the whole file. The checks:
  - categories at most two levels deep
  - slugs unique and never all digits
  - selling price above 0 and at most the MRP
  - `unit_value` and `unit` set together or both empty
  - GST from 0 to 28
  - HSN 4–8 digits
  - label attributes, including the nutrition JSON shape
- **Saving.** Rows are saved one by one, so the catalog cache is invalidated and variant price history is recorded.
- **Booleans** (`is_active`, `is_veg`): `1`/`0` or `true`/`false`. Empty keeps the current value (new rows: the default). Anything else is an error.
- **Empty cells.** Empty text becomes an empty string. Empty `sap_item_code` becomes NULL (it is unique). Empty numbers become NULL where the field allows it.
- **Money** as plain decimals with 2 places (`349.00`), no currency sign.
- **Not imported here:** images (uploaded in the admin), collections, banners and stock. Stock comes in through **Stock inward** (below).

**`categories.csv`**

| Column | Meaning |
|--------|---------|
| `slug` | Key. Lowercase, unique, not all digits |
| `name` | Display name |
| `parent_slug` | Empty for a top-level category; else a top-level category's slug (it may appear earlier in the same file) |
| `sort_order` | Integer, lower first |
| `is_active` | `1` / `0` |

**`products.csv`**

| Column | Meaning |
|--------|---------|
| `slug` | Key |
| `name` | Product name |
| `category_slug` | Existing category slug |
| `brand` | Default `Jivo` |
| `short_description`, `description` | Plain text (no HTML); paragraphs separated by a blank line |
| `highlights` | Up to 10 short texts separated by a vertical bar (`\|`), e.g. `Cold pressed \| Rich in omega-3` |
| `is_veg` | `1` / `0` (FSSAI veg mark) |
| `hsn_code` | 4–8 digits |
| `gst_rate` | Percent, e.g. `5.00` |
| `search_keywords` | Comma-separated tags (quote the cell) |
| `is_active` | `1` / `0` |
| `sort_order` | Integer |
| `ingredients`, `shelf_life`, `storage_instructions`, `country_of_origin`, `manufacturer`, `marketer`, `importer`, `consumer_care`, `fssai_license_no` | Label information (09 §4), stored in `Product.attributes`. Text up to 2000 characters; `fssai_license_no` is 14 digits. An empty cell clears the value; a column left out of the file keeps the current value. |
| `nutrition` | JSON text or empty: `{"columns": ["Per 100 ml"], "rows": [{"name": "Energy", "values": ["900 kcal"], "is_sub_row": false}]}` |

**`variants.csv`**

| Column | Meaning |
|--------|---------|
| `sku` | Key, unique |
| `product_slug` | Existing product slug |
| `name` | Chip label, e.g. `1 L` |
| `net_quantity` | As printed on the pack (Legal Metrology), e.g. `2 x 1 L` |
| `unit_value`, `unit` | For the unit price: total quantity and unit (`ml`, `l`, `g`, `kg`, `pc`), both or neither |
| `mrp`, `selling_price` | Decimals; `0 < selling_price <= mrp` |
| `max_qty_per_order` | Integer ≥ 1 |
| `barcode` | Text, may be empty |
| `sap_item_code` | SAP item code, unique, empty = none |
| `weight_grams` | Integer or empty |
| `is_active` | `1` / `0` |
| `sort_order` | Integer |

**Stock inward (`Inventory → Stock inward (CSV)`)**
- **Format.** Columns `sku,quantity`, header row optional.
  - `sku` takes a variant SKU or its SAP item code.
  - `quantity` is a whole number above 0.
- **Limits.** At most 2000 lines and 1 MB. Pasting a few lines instead of a file works the same way.
- **Store.** Pick one store from the stores you may adjust.
- **Reason** is required, e.g. the GRN number.
- **Preview.** Runs the inventory service and rolls it back, showing on hand before and after.
- **Apply.** Runs `apply_inward_batch`: all lines or none. Rows missing at the store are created.
- **Errors** read `line N: …`, where N is the Nth data line after the header.
