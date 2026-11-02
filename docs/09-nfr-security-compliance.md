# 09: Non-functional Requirements, Security & Compliance

## 1. Performance targets

| Area | Target |
|------|--------|
| API latency (read endpoints: home, catalog, cart) | p95 < 300 ms at expected load |
| API latency (order placement) | p95 < 800 ms (excluding the payment gateway UI) |
| Serviceability check | p95 < 150 ms |
| Rider location → customer map | < 5 s end to end |
| Offer delivery to rider | < 3 s from dispatch decision |
| Store new-order alert | < 3 s from PLACED |
| Customer app cold start (mid-range Android) | < 3 s to home with cached data |
| App size | Customer APK (per-ABI) < 30 MB; rider < 25 MB |
| Initial load capacity | 50 orders/min peak and 500 concurrent app sessions without degradation. Tested in Phase 8. |

Techniques: Redis caching of catalog/home per store (invalidated on change), `select_related`/`prefetch_related` everywhere (enforced with tests using `django_assert_max_num_queries`), DB indexes per [07 §3](07-data-model.md#3-key-indexes--constraints), CDN for images, image resizing (thumbnail sizes) at upload.

## 2. Availability & resilience
- Target 99.5% monthly uptime for the API in v1.
- Managed Postgres with automated daily backups + point-in-time recovery (7–30 days). **Restore tested in Phase 8.**
- Redis loss must not lose orders. Redis holds only cache, broker messages and ephemeral locations. Celery tasks are idempotent and critical jobs are re-derivable from DB state (e.g., `expire_unpaid_orders` scans the DB).
- Graceful degradation: if FCM/SMS fails, retry with backoff. If Redis is down, app config and the force-update/maintenance guard are read from the database; OTP sends/verifies are deliberately fail-closed (503 `SERVICE_UNAVAILABLE`), because OTP abuse limits live in Redis (Phase 1). If WebSockets fail, apps poll. If the maps SDK fails, show the address text plus an external navigation link.
- Health endpoints: `/health/live` and `/health/ready` (DB + Redis checks).

## 3. Security

### 3.1 Authentication & sessions
- OTP: 6 digits, 5-minute expiry, stored **hashed**, max 5 verify attempts per OTP, max 3 OTP sends per phone per 10 min and 10 per day, per-IP throttle. Test numbers with a fixed OTP are allowed **only** in non-production settings, plus an allow-list for app-store reviewers in production (D-15).
- JWT: access 15 min, refresh 30 days with rotation + blacklist. Logout and account deletion revoke all refresh tokens.
- Staff: strong passwords or SSO (Jivo Auth), session expiry, login throttling (django-axes or equivalent), optional 2FA for admin roles. Phase 1: django-axes locks a username + IP pair after 5 failures for 15 minutes (case-insensitive usernames; settings `AXES_FAILURE_LIMIT`, `AXES_COOLOFF_MINUTES`).

### 3.2 Authorisation
- Object-level permission checks on every endpoint: customers see only their own orders/addresses/tickets, riders only their own tasks/offers, store staff only their stores.
- Querysets are always filtered by the requester (never "fetch by id then check"). Tests include **IDOR tests**: user A requesting user B's resources must get 404.
- The customer's phone/address is revealed to a rider only after acceptance and hidden again 1 hour after task completion.

### 3.3 Data protection
- HTTPS everywhere (HSTS). Secure cookies. CSRF on the staff panel.
- Secrets in environment variables / a secrets manager. `.env` files are never committed. Separate keys per environment.
- Bank account numbers and KYC document numbers encrypted at field level. KYC files in a **private** bucket with short-lived signed URLs, viewable only by authorised staff.
- PII is minimised in logs (phone numbers masked). Sentry scrubbing configured.
- Django security settings checked with `manage.py check --deploy` in CI for production settings.

### 3.4 Payments
- Razorpay signature verification on checkout callbacks and webhooks (webhook secret).
- The amount is always taken from the server-side order, never from the client.
- Idempotency on order placement and webhook processing.

### 3.5 Mobile app security
- Tokens in `flutter_secure_storage` (Keystore/Keychain).
- Release builds use `--obfuscate --split-debug-info`. Debug logging is off in prod.
- No secrets in the app binary, except public keys (Razorpay key_id, Maps API key restricted by package name + SHA-1 / bundle ID).
- Optional: certificate pinning (decide in Phase 8). Root/jailbreak detection for the rider app (optional).

### 3.6 Uploads
- Validate type (magic bytes) and size (images ≤ 5 MB). Strip EXIF on product images. Store under random keys.

### 3.7 Security testing
- Dependency scanning in CI (`pip-audit`, `dart pub outdated`/OSV).
- OWASP API Top 10 review in Phase 8, plus basic penetration testing of auth, IDOR, payment and webhook endpoints.

## 4. Compliance (India)

| Item | Requirement | What the system does | Owner / lead time |
|------|-------------|----------------------|-------------------|
| **GST invoicing** | Tax invoice per order with seller GSTIN, invoice number series per FY, HSN, taxable value, CGST+SGST (intra-state) or IGST (inter-state), place of supply | Invoice model + PDF per [07 §2.6](07-data-model.md#26-orders-orders). Credit notes for refunds after invoicing. GST report for GSTR-1. | Jivo Finance confirms GSTINs, HSN codes, GST rates per product, **GST treatment of delivery/handling fees and tips**, and whether e-invoicing applies (D-12). Needed by **Phase 4**. |
| **FSSAI** | Food business licence displayed; product labelling info available to the buyer | Store FSSAI licence on invoices and in the app footer/about. Product detail shows mandatory label info (ingredients, nutrition, veg mark, manufacturer, best before guidance). | Jivo regulatory. Data needed by **Phase 2**. |
| **Legal Metrology (Packaged Commodities)** | E-commerce listings must show MRP, net quantity, manufacturer/packer, country of origin, consumer care details | Product attributes fields + product detail screen | Jivo catalog team, **Phase 2** |
| **Consumer Protection (E-Commerce) Rules** | Grievance officer details, return/refund/cancellation policy, seller details, total price breakdown | CMS pages + checkout bill breakdown + grievance officer on the support screen | Jivo legal, **Phase 7** |
| **TRAI DLT** | Transactional SMS (OTP, order updates) must use a registered entity, sender ID (header) and templates | SMS templates store the DLT template id. OTP sends fail if the template is not registered. | **Jivo must register in Phase 0.** Approval can take days to weeks. |
| **DPDP Act 2023** | Consent, purpose limitation, data principal rights (access, correction, erasure), breach handling | Consent at login (the accepted Terms & Privacy version and time are stored on the user from Phase 1), privacy policy, account deletion flow, retention policy ([07 §4](07-data-model.md#4-data-retention)), location tracking only while online | Jivo legal reviews the privacy policy, **Phase 7** |
| **Google Play policies** | In-app account deletion + web deletion link; **background location declaration** with video for the rider app; data safety form | Deletion flow (Phase 1); foreground service + prominent disclosure screen for rider location (Phase 5) | Play Console access by **Phase 5** |
| **Apple App Store** | Account deletion in-app; privacy nutrition labels; demo account for review | Reviewer test login (D-15) | Apple Developer account by **Phase 6** |
| **RBI / payments** | Card data never touches our servers | Razorpay hosted checkout / SDK only | Razorpay KYC and live keys by **Phase 7** |
| **Rider KYC** | Identity verification, safe storage of Aadhaar (masked) | Masked numbers, private storage, restricted access | Jivo HR/Ops policy (D-14) |

## 5. Observability
- **Errors**: Sentry for backend + both apps (release + environment tagged).
- **Logs**: structured JSON with request id, user id (hashed), order id. Centralised log store (cloud-native).
- **Metrics**: request rate/latency/error per endpoint, Celery queue depth and task failures, orders per state, dispatch time, online riders, WebSocket connections.
- **Alerts**: API 5xx rate, queue backlog, payment webhook failures, no orders placed in X minutes during open hours, DB CPU/storage.
- **Business monitoring**: the ops dashboard alerts panel (SLA breaches).

## 6. Accessibility & localisation
- Apps follow platform accessibility basics: semantic labels, scalable text, contrast AA.
- All user-facing strings are in Flutter ARB files from day one (English in v1), so Hindi can be added later without code changes.
- Currency and date formats use the `en_IN` locale.

## 7. Maintainability
- Code style enforced in CI: `ruff` (Python), `flutter analyze` with lints (Dart).
- Backend service layer + tests per [10-testing-strategy.md](10-testing-strategy.md). Minimum coverage gates.
- Conventional Commits. PRs need review and green CI. `main` is always deployable to staging.
- ADRs (architecture decision records) in `docs/adr/` for any decision that changes these docs.
