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
