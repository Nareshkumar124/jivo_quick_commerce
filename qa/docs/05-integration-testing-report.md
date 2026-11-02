# 05: Integration Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`.

| Integration | How tested | Result |
|---|---|---|
| API ↔ PostgreSQL (shared remote) | Every API test; read-only SQL cross-checks of the API's effects (OTP rows and supersede, token outstanding/blacklist, devices, addresses, terms consent, block flag) | ✅. OBS-01: intermittent DB connect timeouts (> 5 s) surface as 500. |
| API ↔ Redis (cache, rate limits) | Rate-limit counters observed in QA Redis DB 5 (hashed keys, TTLs); `config/app` cache | ✅ |
| Redis outage | `redis-down` profile: `config/app` from DB; OTP fail-closed 503; test numbers, me, refresh, logout and addresses keep working; `/health/ready` 503 | ✅ (4 passed) |
| API ↔ Celery broker / SMS | `send_otp_sms` is queued on commit to the QA broker (DB 7); with no worker, nothing is sent (by design for QA). Console backend masks the phone in its log line. | ⚠ Delivery not exercised (no worker, no real gateway: D-02). BUG-0005: production default backend. |
| API ↔ Django Admin (shared auth, Customers proxy) | Block/unblock through the admin action changes what the API allows (verify 403, refresh 401, access 401) | ✅ |
| Contract ↔ implementation | Served schema = committed `schema.yaml`; every response validated against it; schemathesis | ✅ except BUG-0004 |
| Contract ↔ generated Dart client (`packages/jivo_api`) | n/a (Flutter) | ⏭ No Flutter this run |
| Apps ↔ API (E2E login flow) | n/a | ⏭ The apps' `integration_test` suites were not re-run; device run pending |
| Production settings ↔ environment | `check --deploy` with production settings; production refuses `OTP_TEST_NUMBERS` | ✅ |
