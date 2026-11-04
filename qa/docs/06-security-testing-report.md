# 06: Security Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527` · **Target:** QA instance `127.0.0.1:8004` (local, staging-like, redis-down and daylimit profiles) · **Reference:** 09 §3.1–3.3, 06 §2.1/2.2, 05 §3.

Exploit-level details of open security findings are in `qa/private/` (gitignored), not here.

## Summary
| Area | Result |
|---|---|
| OTP abuse controls | ✅ Per-phone 3/10 min and 10/day, per-IP send 30/h and verify 60/h, 5 attempts per OTP, single use, supersede, app and purpose isolation, fail-closed on Redis loss, XFF spoofing ignored with `NUM_PROXIES=0`. ❌ BUG-0002 (details private). |
| Token handling | ✅ Rotation, blacklist on reuse, logout idempotent and only for the owner's token, revoke-all on deletion and block, forged/tampered/`alg=none`/wrong-key/expired tokens rejected, deployed key separation. ❌ BUG-0003 (details private). |
| Authorisation / IDOR | ✅ Address get/patch/delete/set-default by another user → 404 `NOT_FOUND`, object unchanged; lists disjoint; anonymous → 401. Querysets are requester-scoped (`live_addresses(request.user)`). |
| Mass assignment | ✅ `phone`, `id`, `is_staff`, `is_superuser`, `is_active`, `deleted_at`, `rider_status`, `is_default` are ignored. |
| Enumeration / PII in responses | ✅ OTP request identical for known and unknown phones (and for `delete_account`); generic email-conflict message; strict schema validation finds no extra fields; 5xx bodies carry no internals. |
| PII in logs | ✅ 0 unmasked `+91` numbers and 0 JWTs in all 7 QA instance logs of the run. Rate-limit keys are hashed (no phone or IP in Redis). ⚠ BUG-0005: production defaults to the console SMS backend, which would log OTP codes. |
| Staff login | ✅ Session login works; CSRF enforced (403 without a token); django-axes locks username+IP after 5 failures (status sequence `[200, 200, 200, 200, 429, 429]`), case-insensitive, other usernames unaffected; Block revokes tokens. ⚠ BUG-0006 session lifetime. Role matrix ⏭ (run 2). |
| Deploy configuration | ✅ `manage.py check --deploy --fail-level WARNING` (production settings) → "System check identified no issues (0 silenced)". Production: `DEBUG False`, HSTS 1 year, SSL redirect, Secure cookies, docs staff-only, `OTP_TEST_NUMBERS` refused (`ImproperlyConfigured`), `seed_demo` refused. |
| Secrets in the repo | ✅ `qa/tools/secrets_scan.py 4960527`: 506 tracked files, no tracked `.env`. 22 pattern hits reviewed: hard-coded passwords in backend *test* factories, and placeholder JWTs in the schema examples that the dev key does not validly sign. No real secrets. OBS-07: the dev fallback key is public by design (local only). |
| Dependencies | ✅ `uv run pip-audit` → "No known vulnerabilities found". |
| Mobile (static) | ✅ Tokens in FlutterSecureStorage; Dio LogInterceptor only in debug non-prod builds, with headers and bodies off; no tokens, OTPs or phones logged; no secrets in code. OBS-05: obfuscation not configured yet. |

## Executed tests (actual commands)
- `uv run pytest tests/test_p1_auth_otp.py tests/test_p1_limits.py tests/test_p1_tokens.py tests/test_p1_account.py tests/test_p1_addresses.py tests/test_p1_staff.py`: part of the local run `183 passed, 9 xfailed`.
- `test_profile_redis_down.py` (redis-down): `4 passed`. `test_p1_limits.py -k tc15` (daylimit): `1 passed`.
- Staging profile: P1-TC-26c (dev-key token rejected) passed; P0-TC-10b (schema/docs staff-only: anonymous 401/403, customer JWT 403) passed.

## Findings
| Bug | Severity | Summary (non-exploitable) |
|---|---|---|
| [BUG-0002](../bugs/BUG-0002.md) | P2 Major (Medium) | Numeric input validators accept non-ASCII characters (data integrity; the security aspect is in `qa/private/`). |
| [BUG-0003](../bugs/BUG-0003.md) | P2 Major (Medium) | The refresh-token single-use rule is not enforced in all conditions (details in `qa/private/`). |
| [BUG-0005](../bugs/BUG-0005.md) | P3 Minor (Low) | Production defaults to the console SMS backend (OTP codes in logs). No system check. |
| [BUG-0006](../bugs/BUG-0006.md) | P3 Minor (Low) | Staff session is a fixed 12 h with no idle timeout (05 §5). |
| [BUG-0001](../bugs/BUG-0001.md) | P3 Minor (Low) | Oversized body → 500 (cheap 5xx / alert noise). |
| [BUG-0007](../bugs/BUG-0007.md) | P2 Major (Medium) | Data-consistency race (not a security hole): concurrent set-default can leave zero defaults. |

**No P0/P1 security holes found:** no unauthorised access, no IDOR, no account takeover path, no PII leak in responses.

## Not tested (and why)
- **426/503 positive cases:** shared `AppConfig`.
- **Admin role matrix:** QA run 2.
- **WebSocket auth:** Phase 6.
- **Payment and webhook signatures:** Phase 3.
- **Uploads and KYC storage:** Phase 5.
- **TLS/HSTS on a real host:** no staging deployment yet.
- **OWASP API Top 10 review and penetration test:** Phase 8.

## Phase 3 stage 1 (2026-11-04, `c2c153a`)
| Area | Result |
|---|---|
| IDOR: cart lines (PATCH/DELETE), orders (retrieve/cancel/retry), verify on another user's order, another user's address on cart/order | ✅ 404 / 400, nothing changed, nothing leaked (P3-TC-08/10/29/34) |
| Payment trust: verify needs a valid HMAC over `order_id|payment_id` **and** a gateway order belonging to this order; the app callback alone never places an order | ✅ P3-TC-34 |
| Webhook auth: HMAC of the raw body bytes; tampered body, wrong secret, missing signature/event id → 400, nothing stored; app headers not needed | ✅ P3-TC-35 |
| No duplicate financial transactions: event-id idempotency (also 6× parallel), one capture per payment, one refund per capture, verify/cancel race | ✅ P3-TC-36/50/52/53 |
| The amount always comes from the server: a wrong-amount capture never places the order (it is refunded) | ✅ P3-TC-37 |
| Money/stock tamper: the client total is only a guard (PRICE_CHANGED); quantities bounded by max qty and stock | ✅ P3-TC-05/24 |
| Abuse limits: 30/h placement → 429 RATE_LIMITED with Retry-After | ✅ P3-TC-46 |
| Malformed webhook input | ❌ [BUG-0009](../bugs/BUG-0009.md) (P3 Low): over-long ids → 500. Needs the webhook secret, so it is not exploitable; it is a robustness issue only. |
| PII in logs (all P3 instance logs) | ✅ 0 unmasked `+91` numbers, 0 JWTs. Every 500 in the logs is a BUG-0009 probe. |
| Fake gateway refused outside local/test (payments.E001) | ⏭ Covered by the backend suite; re-check with staging settings after R2b |
| Admin P3 role matrix (DL-46) | ⏭ T-304 |
