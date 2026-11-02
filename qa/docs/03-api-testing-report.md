# 03: API Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`, from a clean export · **Target:** QA instance `http://127.0.0.1:8004` · **Contract:** `backend/openapi/schema.yaml` @ `4960527` (17 operations).

## Commands
```bash
qa/tools/instance.sh start local 4960527
cd qa && uv run pytest -q -rfEsxX --deselect tests/test_fuzz_schemathesis.py
qa/tools/instance.sh start staging 4960527     # DEBUG off
QA_FORCE_ALL=1 uv run pytest -q --deselect tests/test_fuzz_schemathesis.py --deselect tests/test_p1_staff.py \
  -k "not tc04b and not tc10_api_docs_public and not tc11_served"
uv run pytest tests/test_fuzz_schemathesis.py   # local profile
```

## Results
| Run | Result (actual pytest summary) |
|---|---|
| Local profile, full suite (no fuzz) | `183 passed, 11 skipped, 13 deselected, 9 xfailed in 161.18s` |
| Local profile, final regression run (after the redaction fix) | `1 failed, 181 passed, 11 skipped, 13 deselected, 9 xfailed, 1 error in 207.81s`. The failure is P1-TC-57, an intermittent race: BUG-0007 (now xfail, non-strict). The error is P1-TC-48 setup, an httpx `ReadTimeout` while the remote DB timed out (OBS-01; passed in the two previous runs). |
| Staging profile (DEBUG off), profile-specific | `5 passed, 198 skipped` (P0-TC-01, 04, 10b; P1-TC-26c) |
| Staging profile, 🔥 smoke set | `20 passed, 1 error`. The error is P1-TC-64 admin login: Secure CSRF cookie over plain http, expected (admin is covered on local). |
| Staging profile, full API suite | `177 passed, 8 skipped, 22 deselected, 9 xfailed in 151.94s` |
| schemathesis (12 examples × 13 operations) | No app-caused 5xx. Findings: BUG-0004 (404 undocumented); local-only HTML 404 for non-integer ids (OBS-04). Every 500 reproduced as `psycopg ConnectionTimeout` against the remote DB (OBS-01) and returned 200/404/405 on manual retry. |

The 9 xfails are the open bugs: BUG-0001 ×1, BUG-0002 ×7, BUG-0003 ×1. Two of those guards (P1-TC-14b and P1-TC-24c) were then moved to the gitignored `qa/private/tests/`, because they are security-sensitive. P1-TC-57 is now an additional non-strict xfail for BUG-0007.

## Coverage per operation
| operationId | Cases | Status codes observed | Schema |
|---|---|---|---|
| `health_live` | P0-TC-01, 03 | 200, 405 | ✅ |
| `health_ready` | P0-TC-02, 03b | 200, 503 | ✅ |
| `auth_otp_request` | P1-TC-01…05, 14–20 | 200, 400, 415, 429, 503 | ✅ |
| `auth_otp_verify` | P1-TC-06…13, 17, 21–23 | 200, 400, 403, 429, 503, 500 (BUG-0001) | ✅ |
| `auth_token_refresh` | P1-TC-24…27 | 200, 400, 401 | ✅ |
| `auth_logout` | P1-TC-28…30 | 204, 400, 401 | ✅ |
| `me_retrieve` | P1-TC-33, 26, 31 | 200, 401 | ✅ strict |
| `me_update` | P1-TC-34…37 | 200, 400 | ✅ |
| `me_delete_account` | P1-TC-12, 42, 44 | 200, 400, 401 | ✅ |
| `me_device_register` | P1-TC-39…41 | 200, 400, 401 | ✅ |
| `config_app` | P1-TC-58, 59 | 200, 405, 406 | ✅ |
| `addresses_list` | P1-TC-48, 55, 73 | 200, 401, **404 (undocumented: BUG-0004)** | ✅ except 404 |
| `addresses_create` | P1-TC-47, 50–52, 56, 57 | 201, 400, 401 | ✅ |
| `addresses_retrieve` | P1-TC-49, 54, 55 | 200, 404, 401 | ✅ |
| `addresses_update` | P1-TC-49, 54, 55 | 200, 400, 404, 405 (PUT) | ✅ |
| `addresses_delete` | P1-TC-54, 55 | 204, 404 | ✅ |
| `addresses_set_default` | P1-TC-53…55, 57 | 200, 404 | ✅ (BUG-0007: a concurrent race returns a stale `is_default`) |

## Error envelope and codes (06 §6)
Every error response was checked for:
- the exact keys `{"error": {"code", "message", "details"}}`
- `details` an object
- `application/json`

| Code | Exercised by |
|---|---|
| `VALIDATION_ERROR` | ✅ field errors in `details`; malformed JSON |
| `OTP_INVALID`, `OTP_EXPIRED`, `OTP_RATE_LIMITED` | ✅ with `retry_after_seconds` and `Retry-After` |
| `AUTH_REQUIRED`, `TOKEN_INVALID` | ✅ |
| `PERMISSION_DENIED` | ✅ |
| `NOT_FOUND` | ✅ |
| `METHOD_NOT_ALLOWED`, `NOT_ACCEPTABLE`, `UNSUPPORTED_MEDIA_TYPE` | ✅ |
| `SERVICE_UNAVAILABLE` | ✅ |
| `SERVER_ERROR` | ✅ (no internals) |
| `APP_UPDATE_REQUIRED`, `MAINTENANCE` | ⏭ (shared `AppConfig`) |
| `RATE_LIMITED` | not used by any P1 endpoint (no generic DRF throttle configured) |

## Input validation summary
- **Covered:** missing fields, wrong types, enums, max lengths (every address field, name, email, `fcm_token`, reason, `terms_version`), regex fields, coordinates (range, NaN/Infinity/overflow strings, booleans), numeric strings, oversized bodies, Unicode digits.
- **Defects:** BUG-0001 (oversized body → 500) and BUG-0002 (non-ASCII numeric input). OBS-03: a boolean `lat` is coerced.
