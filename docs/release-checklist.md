# Final Release Checklist (go-live)

Use it in Phase 8, before the public launch. Each item points to the doc that defines it. The QA agent's `qa/docs/10-release-readiness-report.md` gives the verdict on the quality items.

## 0. Status: prepared vs waiting on Jivo (updated 2026-11-16)

What engineering has prepared without spending money or using external accounts, and what each remaining item waits on. Tick the detailed items in §1–§8 as they close.

| Area | Prepared (in the repo) | Waiting on | Owner of the wait |
|---|---|---|---|
| CI | `backend`, `infra`, `mobile` workflows; the 2026-11-10 `backend`/`infra` failures on `main` fixed on `devops/p8-ci` (re-run after merge) | A green run on `main` after the fix is merged | PM |
| Signed Android builds | `release-android.yml`: prod flavor, AAB + APK, `--obfuscate --split-debug-info`, upload-key check, fails clearly without secrets ([`deployment.md`](deployment.md) §12) | App Gradle `signingConfig` reading `key.properties` (§12.3, app agents); upload keys and `release` environment secrets (§12.2) | App agents; user / Jivo IT |
| Play Store | Package IDs `in.jivo.quick`, `in.jivo.rider` (D-06 defaults) | **D-11**: Play Console account, app entries, Play App Signing, listings, data safety, rider background-location declaration and video | Jivo IT |
| App Store (customer iOS) | Nothing yet (needs a macOS runner) | **D-11**: Apple Developer organisation account (D-U-N-S) | Jivo IT |
| Push (FCM) | Backend push backends and the deploy check `notifications.E001` | **D-19**: Firebase projects (staging, prod), `google-services.json` per app, FCM credentials as secrets | Tech lead / Jivo IT |
| Crash reporting | `SENTRY_DSN` support in the backend and apps; per-app DSN secrets in the release workflow (optional) | **D-19**: Sentry organisation and projects | Tech lead |
| Payments | Gateway interface, webhook runbook ([`deployment.md`](deployment.md) §5), fail-closed deploy checks `payments.E001`/`E004` | **D-01**: Razorpay KYC and test keys (staging), then live keys and the live webhook | Jivo Finance |
| OTP SMS | SMS backend interface; production refuses the console backend (`accounts.E003`) and `OTP_TEST_NUMBERS`. Gateways ready: `TwilioSmsBackend` (`accounts.E004`) and **`Msg91SmsBackend`** (T-815, MSG91 Flow API v5; `accounts.E007` needs `MSG91_AUTH_KEY` and the OTP flow, `accounts.W001` lists events without a flow). Our server generates and verifies the OTP; MSG91 only delivers it | **D-02**: confirm MSG91 (or Jivo's provider), DLT entity, sender ID (header) and approved templates (OTP + `order.placed`, `order.items_adjusted`, `order.out_for_delivery`, `order.cancelled`, `refund.processed`); on the MSG91 panel one flow per DLT template with the variable names the backend sends; then `MSG91_AUTH_KEY`, `MSG91_FLOW_IDS`, `SMS_OTP_DLT_TEMPLATE_ID`, `SMS_DLT_TEMPLATE_IDS`, `SMS_SENDER_ID`, `SMS_APP_HASH_*` as staging/production secrets and a real OTP to a real phone on staging | Jivo IT |
| Hosting, domains | Image, compose, entrypoint checks, staging preflight, backup/restore, monitoring as code ([`deployment.md`](deployment.md) §7–§11) | **D-05**: hosting, domains/DNS/TLS, `PROD_API_BASE_URL` | Jivo IT; user approval for any spend |
| Maps | Mappls config as release secrets (§12.2) | Mappls prod keys registered with the upload and Play app-signing certificate SHA-256 | Jivo IT |

## 1. Quality gates (`10 §2`, `§5`)
- [ ] Every phase P0–P7 shows 🏁 in [`plan/00-roadmap.md`](plan/00-roadmap.md), with sign-off recorded.
- [ ] CI green on `main`: lint, tests, coverage (backend ≥ 80%, and ≥ 90% on the orders/payments/inventory/cart/delivery services), migrations, schema, `pip-audit`.
- [ ] No open P0/P1 bugs, at most 5 open P2 (all with a plan), and the full 🔥 regression smoke set passed on staging.
- [ ] End-to-end order flows pass on staging: COD, online, cancel, partial unavailability, failed delivery/return, refund.
- [ ] No duplicate financial transactions under retry and webhook replay; no stock drift (`08 §6`).

## 2. Security (`09 §3`)
- [ ] OWASP API Top 10 review done, and the pen-test findings for auth, IDOR, payments and webhooks are fixed.
- [ ] `manage.py check --deploy` clean with production settings, plus HSTS, secure cookies and CSRF.
- [ ] Secrets only in the secrets manager, with separate keys per environment and no secrets in git (history scanned).
- [ ] KYC files are in a private bucket with signed URLs, and sensitive fields are encrypted.
- [ ] PII is masked in logs, and Sentry scrubbing is on.
- [ ] Release builds use `--obfuscate --split-debug-info` (Android: `release-android.yml`, [`deployment.md`](deployment.md) §12), and are signed with the upload key (the workflow verifies it). The only public keys are restricted ones (Razorpay `key_id`, the Maps key).
- [ ] The GitHub repository is private, or a public repo has been reviewed and approved.
- [ ] Production refuses `OTP_TEST_NUMBERS`, apart from the single app-store reviewer number (D-15).

## 3. Performance and resilience (`09 §1`, `§2`)
- [ ] The load test passes: 50 orders/min and 500 concurrent sessions, with p95 targets met.
- [ ] Backup **restore tested**, with point-in-time recovery configured (§3a below).
- [ ] The app degrades gracefully: Redis down, FCM/SMS failures, WebSocket drop leading to polling.
- [ ] `/health/live` and `/health/ready` are wired to the load balancer, and alerts are configured (`09 §5`).

## 3a. P8 hardening (T-813; [`deployment.md`](deployment.md) §7–§11)
- [ ] **Backups:** managed PITR on (retention 14 days), daily `pg_dump` job to the backup bucket (§7.2), bucket versioning and lifecycle on the private, public and backup buckets (§7.4). RPO/RTO targets (§7.1) confirmed by the user.
- [ ] **Full-data restore test** on staging or production infrastructure with `infra/backup/restore_db.sh --verify` (and one PITR restore), recorded in the §7.3 log. The 2026-11-04 schema-only drill on the dev DB does not count for go-live.
- [ ] Production restore runbook (§7.2) walked through once by the rollback owner.
- [ ] **Deploy-time checks:** the production image's entrypoint and the `jqc-release` task run `check --deploy --fail-level ERROR` against the real environment (§8.1); the staging deploy job's preflight passed for the release candidate; `JQC_SKIP_STARTUP_CHECK` appears in no service env, compose file or secret; the `staging`/`production` GitHub environments have required reviewers and protected-branch deployment rules (§8.4); `DJANGO_ALLOWED_HOSTS` lists real hosts (not example hosts).
- [ ] Release order and rollback (§8.2, §8.3) rehearsed on staging, including one rollback to the previous image.
- [ ] **Edge:** rate limits, `limit_conn` on `/ws/` and body sizes per location live (§9.1), or their load-balancer/WAF equivalents; **`set_real_ip_from` set when behind a load balancer** (verified: access-log `remote_addr` shows client IPs).
- [ ] Access logs contain no query strings and no `Sec-WebSocket-Protocol`/`Authorization`/`Cookie` (§9.2, §9.3); checked by reading a sample of real staging log lines.
- [ ] `NUM_PROXIES` matches the production topology and the spoofed-`X-Forwarded-For` test passed (§9.5).
- [ ] WebSocket max message size 64 KiB in effect (§9.4).
- [ ] **Monitoring:** Sentry DSNs and sample rates per §10.1; `/health/ready` wired to the load balancer and the readiness probe alert (§10.2); the metrics marked `needs-backend` in `infra/monitoring/metrics.yml` exported; the SQL exporter running with the read-only `jqc_metrics` role; `infra/monitoring/alerts.yml` loaded, with a test alert delivered to each severity's channel (page, ticket, ops).
- [ ] **Secrets:** `JWT_SIGNING_KEY` set and different from `DJANGO_SECRET_KEY`, `OTP_HASH_KEY` and `FIELD_ENCRYPTION_KEYS` set (§11.1); the app's DB login is a least-privilege role, not a superuser; rotation runbooks (§11.2) reviewed.

## 4. Compliance (`09 §4`)
- [ ] GST invoices: GSTINs, HSN and rates, invoice series, the GSTR-1 report (D-12).
- [ ] FSSAI and Legal Metrology info on product detail.
- [ ] Consumer Protection rules: grievance officer, refund/cancellation policy, price breakdown.
- [ ] TRAI DLT: entity, sender ID and templates approved, and real OTP SMS delivered (D-02).
- [ ] DPDP: consent recorded at login, privacy policy live, account deletion working, retention jobs running.
- [ ] Legal pages (Terms, Privacy, Refund) live in the CMS.

## 5. Infrastructure (`02 §8`, D-05)
- [ ] Production stack up: managed Postgres + PostGIS, managed Redis, S3 + CDN, web/worker/beat processes, nginx/LB with TLS.
- [ ] Exactly **one** Celery beat running (DatabaseScheduler), and `expire-unpaid-orders` visible as an enabled periodic task with a recent `last_run_at` ([`deployment.md`](deployment.md) §4).
- [ ] Domains and DNS for `api.` and `ops.`.
- [ ] Zero-downtime deploys, backward-compatible migrations, a documented rollback plan.
- [ ] Monitoring: Sentry (backend and apps), structured logs, dashboards, on-call contacts.

## 6. App stores (D-06, D-11)
- [ ] **Signing:** Play App Signing enabled for both apps; upload keys generated offline and held by two people; `release` environment secrets set; a `release-android` run produced verified signed AABs ([`deployment.md`](deployment.md) §12).
- [ ] Dart symbols and R8 mappings of each store build uploaded to Sentry (and the mapping to Play).
- [ ] **Customer app:** Play Store and App Store listings, data safety and privacy labels, a reviewer test account, the account deletion link.
- [ ] **Rider app:** Play listing, plus the background-location declaration and its video approved.
- [ ] Force-update policy set (`min_supported_version`), and the store URLs configured.

## 7. Business readiness (`11 §2`)
- [ ] Razorpay live keys after KYC (or the chosen alternative, Cashfree).
- [ ] Razorpay **live-mode** webhook configured as in [`deployment.md`](deployment.md) §5 (URL, events `payment.captured`, `payment.failed`, `refund.processed`, `refund.failed`), with its own `RAZORPAY_WEBHOOK_SECRET`.
- [ ] **Before enabling Razorpay auto-capture in production:** drain or expire every PAYMENT_PENDING ONLINE order whose Razorpay order was created before the release. Those gateway orders lack the per-order `payment.capture: automatic` settings, so a payment on them may stay only authorised. Either let `expire_unpaid_orders` run past their windows (15 min) before switching traffic, or check the Razorpay Dashboard for authorised-but-uncaptured payments on older orders and capture or refund them. Also confirm in Razorpay **test mode** that a repeated refund `receipt` is refused ("Duplicate receipt") and that `refund.*` webhooks carry `receipt`.
- [ ] Dark store ready: location, polygon, hardware (tablet, printer), trained staff.
- [ ] Riders recruited and approved, with their cash limits set.
- [ ] Full product catalog with photos.
- [ ] Pilot week run (`10 §7`), with feedback addressed and UAT signed off by a Jivo business owner.

## 8. Go-live
- [ ] Release tag created, a deploy window agreed, and the rollback owner named.
- [ ] Smoke test on production right after the deploy: config, login, browse, COD order to delivery, refund.
- [ ] Post-launch monitoring for the first 72 h (`01 §7` success metrics).
