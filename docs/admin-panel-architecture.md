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

Planned additions: `/ops/orders/live/` (P4), `/ops/store/<store>/` (P4), `/ops/riders/map/` (P5), `/ops/cash/` (P5), `/ws/ops/live/` (P6).

**Navigation.** One registry, `apps/ops_console/navigation.py` (`MODULES`), feeds both the unfold sidebar (`config/admin_ui.py`) and the Ops sidebar. Each item names its permissions, and a section with no allowed item is hidden. Adding a module therefore means adding one `NavItem`.

## 3. Code layout

```
backend/
  config/admin_ui.py                 UNFOLD settings (imported by settings/base.py); no model imports
  apps/<app>/admin.py                ModelAdmins (thin; actions call services)
  apps/ops_console/
    access.py      ops_view(*perms): staff gate, permission gate, HTMX-aware refusals, IST rendering
    navigation.py  module registry → unfold sidebar + Ops sidebar
    selectors.py   read-only queries (never write, not even get_or_create)
    dashboard.py   dashboard blocks (chart spec, tables)
    tables.py      DataTable: search, filters, pagination from GET params
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
  templates/admin/<app>/<model>/...   admin overrides (e.g. anonymise confirmation)
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
- **Store scoping (Phase 2+).** `get_queryset` is filtered by `StaffStoreAccess`. Never fetch by id and then check: scope the queryset. Every screen gets a test where another store's object returns 404.
- **PII masking.** `pii.display_phone(user, phone)` and `{{ phone|phone_for:request.user }}` show the full number only with `accounts.view_customer`. Everyone else sees `+91 XXXXXX2233`. Masking first applies on order screens (P4). Order screens must also avoid rendering `str(user)`, which is the phone.
- **Hiding a link is not a permission.** The sidebars hide refused links, but every view and ModelAdmin checks again.
- **Tests.** Each screen has a role-matrix test covering the 7 roles, a superuser flag, a non-staff user and an anonymous visitor (`apps/ops_console/tests/helpers.py`). From P2, each screen also needs an other-store test.

## 5. State changes

- Admin actions and Ops buttons are **thin wrappers around backend services**: `orders.services.transition()`, `inventory.services.adjust(...)`, dispatch, refunds, and so on. The panel never calls `.save()` to change an order, task, payment, stock or rider status. If a service is missing, the screen waits and the gap is reported.
- Ops POSTs are HTMX requests with the CSRF token in `hx-headers` on `<body>`. Irreversible actions need a confirmation: `hx-confirm`, or an intermediate admin page like "Anonymise now".
- The panel only displays money and never computes it. Amounts come from records produced by `cart.services.compute_bill()` and the payment services.
- Every staff mutation on orders, stock, prices, refunds, riders and config goes through the backend's audit mechanism (`AuditLog`, P4–P8; django-simple-history where the backend enabled it). The Phase 2 store, catalog and inventory models have `HistoricalRecords`. **The Phase 1 admin mutations have no audit yet:** customer block, unblock and anonymise (`User`), `AppConfig`, `AppVersionPolicy` and staff role membership. This is reported as a gap.

## 6. Static assets (vendored and pinned)

| File | Version | Source | sha256 |
|------|---------|--------|--------|
| `static/ops/vendor/htmx-2.0.4.min.js` | htmx 2.0.4 | `cdn.jsdelivr.net/npm/htmx.org@2.0.4/dist/htmx.min.js` (same build unfold ships, minus a trailing newline) | `e209dda5c8235479f3166defc7750e1dbcd5a5c1808b7792fc2e6733768fb447` |
| `static/ops/vendor/alpinejs-3.16.1.min.js` | Alpine.js 3.16.1 | `cdn.jsdelivr.net/npm/alpinejs@3.16.1/dist/cdn.min.js` (byte-identical to unfold's copy) | `04656d770039b55ac7a37aeecb92191de2c7775f61f2d0183331cc16c13f3f1e` |
| `unfold/js/chart/chart.js` (not copied) | Chart.js 4.4.0 | shipped by django-unfold 0.110.1 (pinned in `uv.lock`) | n/a |

- **Versions match unfold's**, so `/admin` and `/ops` behave the same. Upgrade deliberately: new filename, update this table, run the tests.
- **Load order.** `base.html` loads the scripts deferred in this order: htmx, Chart.js, `ops.js`, then Alpine. `ops.js` registers its Alpine stores on `alpine:init`.
- **Alpine plugins.** None are loaded, so `x-trap`, `x-persist` and similar are not available. Vendor a plugin before using it.
- **Phase 2/5.** The map SDK loader is **Mappls** (MapmyIndia, DL-29), not Google Maps. It is vendored when the store-polygon (P2) and rider-map (P5) screens land. Its key/config files are secrets and are never committed.
- **No CDN at runtime.** Everything is served from `/static/`.

## 7. HTMX: CSRF, errors, session expiry

| Situation | Server | Client (`static/ops/js/ops.js`) |
|-----------|--------|---------------------------------|
| Any POST | `CsrfViewMiddleware` | `hx-headers='{"X-CSRFToken": …}'` on `<body>` |
| Signed out / session expired / not staff | Full page: 302 to `/admin/login/?next=…`. HTMX: **401 + `HX-Redirect`** to the login, with `next` = the page in `HX-Current-URL` (a 302 would swap the login page into the target). | htmx follows `HX-Redirect`. A 401 without it falls back to a redirect to the login. |
| Staff without permission | 403. Full page: `errors/403.html`. HTMX: a partial plus the `X-Ops-Refused: 1` header. | Toast: "Access refused: your role does not allow this." Any other 403 (e.g. CSRF) gets a "reload and try again" toast. |
| 404 / 5xx / network / timeout | Standard | Warning or error toast. Error responses are never swapped in. |
| Success messages | `HX-Trigger: {"ops:toast": {"message", "tone"}}` or Django `messages` | Toast |

**Other client settings.** Ops responses are `never_cache`. The htmx history cache is turned off (`historyCacheSize = 0`) so PII never lands in `localStorage`. Views render in IST (`timezone.override`), while stored times stay UTC.

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

## 9. Dashboard definitions (Phase 1 shell)

| Card | Definition | Permission |
|------|-----------|------------|
| Customers: total, active, blocked, deletion requested | Non-staff accounts (riders included until P5), excluding anonymised. Status precedence: anonymised > deletion requested > blocked > active. Total = active + blocked + deletion requested. | `accounts.view_customer` |
| New today / new in the last 7 days | Account creations since IST midnight, and over the last 7 IST calendar days including today. Accounts anonymised later still count as sign-ups. | `accounts.view_customer` |
| Sign-ups per day (chart) | The same, per IST day for 14 days, zero-filled | `accounts.view_customer` |
| Recent sign-ups (table) | Newest first. Search covers name, phone and email; filter by status; 10 per page. | `accounts.view_customer` |
| Active staff per role | Active staff in each of the 7 roles, plus superusers and staff without a role | `accounts.view_user` |
| App configuration | Maintenance on/off, message, and the min/latest version per app and platform, read from the DB (never created) | `cms.view_appconfig` |

Order, GMV, rider and store cards are **absent** until their phases. The panel never shows placeholder numbers.
