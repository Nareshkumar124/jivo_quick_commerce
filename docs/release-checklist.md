# Final Release Checklist (go-live)

Use it in Phase 8, before the public launch. Each item points to the doc that defines it. The QA agent's `qa/docs/10-release-readiness-report.md` gives the verdict on the quality items.

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
- [ ] Release builds use `--obfuscate --split-debug-info`. The only public keys are restricted ones (Razorpay `key_id`, the Maps key).
- [ ] The GitHub repository is private, or a public repo has been reviewed and approved.
- [ ] Production refuses `OTP_TEST_NUMBERS`, apart from the single app-store reviewer number (D-15).

## 3. Performance and resilience (`09 §1`, `§2`)
- [ ] The load test passes: 50 orders/min and 500 concurrent sessions, with p95 targets met.
- [ ] Backup **restore tested**, with point-in-time recovery configured.
- [ ] The app degrades gracefully: Redis down, FCM/SMS failures, WebSocket drop leading to polling.
- [ ] `/health/live` and `/health/ready` are wired to the load balancer, and alerts are configured (`09 §5`).

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
