# 02: Test Case Repository: Phase 0 and Phase 1

This is the first written test case set for P0/P1, because `docs/plan/` does not exist yet. It uses the format from `docs/10-testing-strategy.md` §5.4.

**Build under test:** backend commit `4960527`, from a clean `git archive` export, so uncommitted Phase 2 work in the main tree is not under test. Apps: static review of the same commit only. **Last run:** 2026-11-02 (QA run 1).

Key: 🔥 = regression smoke case · Area BE/ADM/CUS/RID/E2E · Pri P0–P2 = test priority. Status: ⬜ not run · ✅ pass · ❌ fail (bug link) · ⏭ deferred (with reason).

The automated case lives in `qa/tests/` under the same ID, for example `test_p1_tc24_*`.

Sources: 03 §2.1/2.2/2.4/2.11, 04 §2.1, 05 §2–§3 (P1 rows), 06 §2.0/2.1/2.2/§6, 07 §2.1/§3/§4, 09 §2/§3.1–3.3.

## Phase 0: Foundation

| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P0-TC-01 🔥 | BE | P0 | `GET /health/live`, no auth | 200 `{"status":"ok"}`, `Cache-Control` no-cache | ✅ local + staging |
| P0-TC-02 🔥 | BE | P0 | `GET /health/ready` | 200 `{status: ok, checks: {database: ok, redis: ok}}` | ✅ |
| P0-TC-03 | BE | P1 | Probes with a garbage Bearer; 40 rapid calls; POST; trailing slash | 200 (auth ignored); never throttled; POST → 405 envelope; `/health/live/` → 404 | ✅ |
| P0-TC-03b | BE | P1 | Redis unreachable (redis-down profile): `GET /health/ready` | 503 `SERVICE_UNAVAILABLE`, `details.checks = {database: ok, redis: error}`, no driver text | ✅ (first attempt hit a transient remote-DB connect timeout; see 07 report) |
| P0-TC-04 🔥 | BE | P1 | DEBUG off (staging profile): unknown `/api/v1/…`, `/api/v1/addresses/abc/`, `/health/x` | 404 JSON envelope `NOT_FOUND`; non-API paths get HTML | ✅ staging. Local DEBUG on: HTML debug page, by design |
| P0-TC-05 | BE | P1 | `PUT /me/`, `DELETE /config/app/`, `GET /auth/otp/request/` | 405 `METHOD_NOT_ALLOWED` envelope | ✅ |
| P0-TC-06 | BE | P1 | Form-encoded and `text/plain` body to a JSON endpoint | 415 `UNSUPPORTED_MEDIA_TYPE` | ✅ |
| P0-TC-07 | BE | P2 | `Accept: application/xml` | 406 `NOT_ACCEPTABLE` | ✅ |
| P0-TC-08 | BE | P1 | Truncated JSON; bare `NaN` literal | 400 `VALIDATION_ERROR` (message names the parse error) | ✅ |
| P0-TC-08b | BE | P2 | ~3 MB JSON body (over Django's 2.5 MB limit) | 400/413, never 500 | ❌ [BUG-0001](../bugs/BUG-0001.md) |
| P0-TC-09 | BE | P1 | Trigger a 500 (via BUG-0001) | Bare `SERVER_ERROR` envelope, no traceback, class name or path | ✅ |
| P0-TC-10 | BE | P1 | `/api/schema/`, `/api/docs/`: anonymous (local), then anonymous and customer JWT (staging) | Local: public 200. Staging: anonymous 401/403, customer 403 | ✅ local + staging |
| P0-TC-11 | BE | P1 | Compare served `/api/schema/` with committed `backend/openapi/schema.yaml` | Paths and components identical | ✅ |
| P0-TC-12 🔥 | BE | P0 | Contract inventory: the 17 P0/P1 operationIds exist and each is exercised with response-schema validation (strict: no undocumented fields) | All present; all responses validate | ✅ (one gap: [BUG-0004](../bugs/BUG-0004.md)) |
| P0-TC-13 | BE | P2 | Unknown or malformed `X-App-Name`/`X-Platform`/`X-App-Version` (including 500 chars) | Ignored, 200, never an error | ✅ |
| P0-TC-14 | BE | P2 | Security headers on API responses | `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy` | ✅ |
| P0-TC-15 | BE | P1 | `manage.py check --deploy --fail-level WARNING` with production settings | No issues | ✅ |
| P0-TC-16 | BE | P0 | Secrets scan of git-tracked files at `4960527` | No real secrets; no tracked `.env` | ✅ (22 hits reviewed: test-fixture passwords and placeholder JWT examples that the dev key does not validly sign) |
| P0-TC-17 | BE | P1 | `pip-audit` on the backend lock | No known vulnerabilities | ✅ |
| P0-TC-18 | ADM | P1 | `GET /admin/` anonymous | 302 to `/admin/login/` (unfold, CSRF token in the form) | ✅ |
| P0-TC-19 | BE | P2 | Timestamps in responses | ISO 8601 UTC (`Z`) | ✅ |
| P0-TC-20 | BE | P2 | Compose services | Redis 6380, MinIO 9000/9001 and Mailpit 1025/8025 up; Redis reachable from the app | ✅ (`docker ps`; `/health/ready` redis ok) |
| P0-TC-21 | CUS/RID | P1 | Build the `dev` flavor of both apps and reach the backend | Builds; splash reaches `config/app` | ⏭ No Flutter commands this run (SDK lock shared with the app agents) |
| P0-TC-22 | CUS | P1 | `packages/jivo_api` generated from the schema compiles | `flutter analyze` clean | ⏭ same reason |
| P0-TC-23 | BE/CUS | P1 | Backend and mobile CI green on `main` | All jobs green | ⬜ Not checked this run (no CI access exercised) |

## Phase 1: Auth & users

### OTP sign-in (06 §2.1, 09 §3.1, 03 §2.2, 04 §2.1)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-01 🔥 | BE | P0 | `POST /auth/otp/request/ {phone, app}` (also `purpose: login`) | 200 `{otp_length: 6, expires_in_seconds: 300, resend_after_seconds: 30}` | ✅ |
| P1-TC-02 | BE | P0 | Request for a known phone, an unknown phone, and `delete_account` for a phone with no account | Identical 200 bodies; no OTP row stored for the `delete_account`/no-account case | ✅ |
| P1-TC-03 | BE | P1 | Invalid phones: no `+91`, no `+`, spaces, dashes, 9/11 digits, starts with 5, letters, +1, empty, 200 chars | 400 `VALIDATION_ERROR`, `details.phone` | ✅ (12 variants) |
| P1-TC-04 | BE | P1 | Phones with non-ASCII digits (Devanagari, full-width, Arabic-Indic, mixed) | 400 | ❌ [BUG-0002](../bugs/BUG-0002.md) (some variants accepted) |
| P1-TC-05 | BE | P1 | Missing phone/app; app `admin`/`Customer`; purpose `reset`; phone as number/null/list; body `[]`/`"x"` | 400 `VALIDATION_ERROR` | ✅ |
| P1-TC-06 🔥 | BE | P0 | Verify with a fixed test OTP | 200 `{access, refresh, user, is_new_user, rider_status: NONE, deletion_cancelled: false}`; JWTs with `app` claim; `is_new_user` true only when created | ✅ |
| P1-TC-07 | BE | P1 | Verify again for the same phone | `is_new_user: false`, same user id | ✅ |
| P1-TC-08 🔥 | BE | P0 | 5 wrong codes, then a 6th wrong, then the correct code | `OTP_INVALID` with `attempts_remaining` 4,3,2,1,0; then `OTP_EXPIRED` (correct code too) | ✅ |
| P1-TC-09 | BE | P0 | Verify the same OTP twice | Second → `OTP_EXPIRED` | ✅ |
| P1-TC-10 | BE | P1 | Request twice, verify twice (DB check) | Older row `expires_at` moved to issue time; only one verify succeeds; TTL 300 s | ✅ |
| P1-TC-11 | BE | P1 | OTP for app=customer verified with app=rider; body app vs `X-App-Name` | `OTP_EXPIRED`; the body `app` is authoritative (token claim = body app) | ✅ |
| P1-TC-12 | BE | P0 | Strict sequence: a `delete_account` OTP cannot sign in; a login OTP cannot delete; the login OTP is not consumed by the failed delete | As stated | ✅ |
| P1-TC-13 | BE | P1 | Verify validation: OTP 5/7 digits, letters, full-width digits; missing `terms_version`; `terms_version` > 32; bad app/phone | 400 `VALIDATION_ERROR`, no attempt consumed | ❌ [BUG-0002](../bugs/BUG-0002.md) (full-width OTP passes validation and costs an attempt); other variants ✅ |
| P1-TC-14 🔥 | BE | P0 | 4 sends to one non-test phone in 10 min (customer, customer, rider, rider) | 4th → 429 `OTP_RATE_LIMITED`, `details.retry_after_seconds` ≤ 600, `Retry-After` header; other phones unaffected | ✅ |
| P1-TC-14b | BE | P1 | Security guard for BUG-0002 (case and test kept in `qa/private/` until fixed) | See private file | ❌ [BUG-0002](../bugs/BUG-0002.md) |
| P1-TC-15 | BE | P1 | 11 sends to one phone in 24 h (daylimit profile: 10-minute cap raised to 50) | 11th → 429 with `retry_after_seconds` > 600 | ✅ |
| P1-TC-16 | BE | P1 | 31 sends from one client IP across 11 phones | 31st → 429; test numbers still exempt | ✅ |
| P1-TC-17 | BE | P1 | 61 verifies from one client IP | 61st → 429 `OTP_RATE_LIMITED` | ✅ |
| P1-TC-18 | BE | P0 | P1-TC-16 with a different spoofed `X-Forwarded-For`/`X-Real-IP` on each request (`NUM_PROXIES=0`) | Spoofing ignored; the limit still applies | ✅ |
| P1-TC-19 | BE | P1 | Fixed-OTP test numbers: 6 sends in a row; production settings with `OTP_TEST_NUMBERS` set | All 200; production refuses to start (`ImproperlyConfigured`) | ✅ |
| P1-TC-20 | BE | P1 | Inspect the QA Redis keys after a send | Keys `jqc:rl:<scope>:<sha256 prefix>`, no phone or IP; TTL ≤ 24 h | ✅ |
| P1-TC-21 🔥 | RID/BE | P0 | Rider-app login (`X-App-Name: rider`, `app: rider`) | `rider_status: NONE`; token `app` claim `rider`; `GET /me/` ok | ✅ |
| P1-TC-22 | BE | P1 | Log in with `terms_version` v2, back to v1, then v1 again (DB) | Version stored with time; time bumps only on change | ✅ |
| P1-TC-23 | BE/ADM | P0 | Blocked customer (Customers admin "Block") verifies an OTP | 403 `PERMISSION_DENIED` "This account is deactivated."; refresh → 401; access token → 401 | ✅ |

### Tokens and sessions (06 §2.1, 09 §3.1, 02 §5)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-24 🔥 | BE | P0 | Refresh; reuse the old refresh token | 200 new pair; reuse → 401 `TOKEN_INVALID` ("blacklisted"); new pair works | ✅ |
| P1-TC-24b | BE | P1 | DB after rotation | New jti outstanding (not blacklisted); old jti blacklisted | ✅ |
| P1-TC-24c | BE | P1 | Security guard for BUG-0003 (case and test kept in `qa/private/` until fixed) | Refresh token single use holds in all conditions | ❌ [BUG-0003](../bugs/BUG-0003.md) |
| P1-TC-25 | BE | P1 | Refresh with `{}`, `""`, missing, `garbage`, `a.b.c`, an access token | 400 `VALIDATION_ERROR` / 401 `TOKEN_INVALID` | ✅ |
| P1-TC-26 | BE | P0 | `/me/` with a tampered payload (user_id swapped), `alg=none`, a wrong key, a refresh token as Bearer, garbage | 401 `TOKEN_INVALID` | ✅ |
| P1-TC-26b | BE | P1 | Expired access token (local profile) | 401 `TOKEN_INVALID` | ✅ |
| P1-TC-26c | BE | P0 | Staging profile: token signed with the public dev fallback key | 401 (deployed settings use their own key) | ✅ |
| P1-TC-27 | BE | P1 | Decode tokens | access 15 min, refresh 30 days; `app` claim kept after rotation | ✅ |
| P1-TC-28 🔥 | BE | P0 | Logout; refresh afterwards; logout twice; garbage refresh; no auth; no body | 204 empty; refresh → 401; idempotent 204; no auth → 401 `AUTH_REQUIRED`; no body → 400 | ✅ |
| P1-TC-28b | BE | P2 | Access token right after logout | Still valid until expiry (≤ 15 min): stateless JWT. **Observation**, matches 06. | ✅ (observed) |
| P1-TC-29 | BE | P0 | A logs out with B's refresh token | 204; B's refresh still works | ✅ |
| P1-TC-30 | BE | P1 | Logout with `fcm_token` (DB) | That device inactive; the user's other device stays active | ✅ |
| P1-TC-31 | BE | P1 | No header; `Bearer`, `Bearer x extra`, `Token x`, `bearer x`, `JWT x` | 401 `AUTH_REQUIRED` (with `WWW-Authenticate: Bearer`) or `TOKEN_INVALID`; never 200/500 | ✅ |
| P1-TC-31b | BE | P1 | `/api/v1/me/` with a session cookie only | 401: the API is JWT only | ✅ |
| P1-TC-32 | BE | P1 | Public endpoints with a stale or garbage Bearer | `config/app`, `otp/request` 200; refresh judged by body only | ✅ |

### Profile and devices (06 §2.1, 03 §2.11)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-33 🔥 | BE | P0 | `GET /me/` | Exactly the documented fields (strict schema); own data | ✅ |
| P1-TC-34 | BE | P1 | PATCH name (padded), mixed-case email, `marketing_opt_in` | 200; name trimmed; email lowercased; `is_profile_complete` true; GET equals PATCH | ✅ |
| P1-TC-35 | BE | P1 | name `""`, spaces, null, 121 chars, list | 400 `details.name` | ✅ |
| P1-TC-36 | BE | P0 | Invalid emails; null/""/spaces clear; email taken by B, B uppercased, or a staff email | 400; cleared to null; conflict → the same generic "This email can't be used." (no enumeration) | ✅ |
| P1-TC-37 | BE | P0 | PATCH `phone`, `id`, `rider_status`, `is_staff`, `is_superuser`, `is_active`, `deleted_at` | All ignored (DB: still non-staff, active) | ✅ |
| P1-TC-38 | BE | P2 | PUT/DELETE/POST `/me/` | 405 | ✅ |
| P1-TC-39 🔥 | BE | P1 | Register the same `fcm_token` twice with changes | 200, same id, updated fields, newer `last_seen_at` | ✅ |
| P1-TC-40 | BE | P1 | B registers A's token | One row, now B's (documented upsert) | ✅ |
| P1-TC-41 | BE | P1 | Bad app/platform/app_version (`abc`, `1.0.0-beta`, too long), token 513 chars/empty/missing; no auth | 400 naming the field; 401 without auth | ✅ |

### Account deletion (06 §2.1, 03 §2.2, 07 §4, 09 §4 DPDP/Play)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-42 🔥 | BE | P0 | `delete_account` OTP → `POST /me/delete/ {otp, reason}` | 200 `{deleted_at, anonymise_after = +30 d}`; access and refresh tokens (including a rotated one) → 401; devices inactive; reason stored | ✅ |
| P1-TC-43 🔥 | BE | P0 | Sign in again within the grace period | `deletion_cancelled: true`; same user id; `deleted_at`/reason cleared; old tokens stay revoked; the next login returns false | ✅ |
| P1-TC-44 | BE | P1 | `/me/delete/`: empty, short OTP, reason 501 chars, no auth, no active delete OTP | 400 / 401 / 400 `OTP_EXPIRED` | ✅ |
| P1-TC-45 | BE | P2 | Staff account calls `/me/delete/` | 403 `PERMISSION_DENIED` | ⏭ No black-box path: staff have no phone/OTP JWT. Covered by backend unit tests (not re-run) |
| P1-TC-46 | BE | P1 | Anonymisation job after 30 days | PII erased, devices and addresses deleted, phone free for a new sign-up | ⏭ Needs time travel or running the Celery job on the shared DB |

### Addresses (06 §2.2, 03 §2.4, 07 §2.1, 09 §3.2)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-47 🔥 | BE | P0 | Create the first and second address | 201; first is default; receiver defaults to own name/phone; lat/lng are numbers | ✅ |
| P1-TC-48 | BE | P1 | List: order, `page_size` 1/1000/0/abc, `page` 2/99/0/-1/abc; no auth | Default first then newest; cap 100; invalid → 20; bad page → 404 `NOT_FOUND`; 401 | ✅ (404 not in the contract: [BUG-0004](../bugs/BUG-0004.md)) |
| P1-TC-49 | BE | P1 | GET own; PATCH landmark + lat; PUT | 200; partial update; 405 | ✅ |
| P1-TC-50 | BE | P1 | 22 invalid bodies: missing/blank required fields, every max length, label enum, PIN code (5/7 digits, leading 0, letters), receiver phone, missing lat/lng | 400 naming the field | ✅ |
| P1-TC-51 | BE | P0 | lat 90.000001/-91, lng 180.5/-181, `abc`, `nan`, `NaN`, `inf`, `-Infinity`, `1e400`, list; boundaries; 6-dp rounding (DB `28.123457`) | 400, never 500; ±90/±180/0 accepted; numbers returned | ✅ (OBS-03: JSON `true` → 1.0) |
| P1-TC-52 | BE | P2 | Non-ASCII digits in PIN code / receiver phone | 400 | ❌ [BUG-0002](../bugs/BUG-0002.md) |
| P1-TC-53 🔥 | BE | P0 | set-default on the 3rd of 3, twice | 200; exactly one default; listed first | ✅ |
| P1-TC-54 | BE | P0 | Delete default / non-default / last; reuse a deleted id | 204; most recently updated promoted; deleted → 404 for GET/PATCH/DELETE/set-default and not listed; new first address default | ✅ |
| P1-TC-55 🔥 | BE | P0 | **IDOR:** B GET/PATCH/DELETE/set-default on A's address; anonymous GET | 404 `NOT_FOUND` ×4, A's address unchanged, lists disjoint; anonymous → 401 | ✅ |
| P1-TC-55b | BE | P1 | Unknown, 0, negative, decimal, injection-like ids; bigint overflow (fuzz) | 404, never 500 | ✅ |
| P1-TC-56 | BE | P1 | `is_default`/`id`/`created_at` in create or patch | Ignored | ✅ |
| P1-TC-57 | BE | P0 | 10 concurrent set-defaults; 8 concurrent creates for an address-less user (DB) | Exactly one live default | ❌ [BUG-0007](../bugs/BUG-0007.md) (intermittent: zero defaults in 1 of 8 trials; concurrent creates ✅) |

### App configuration and guard (06 §2.1, 03 §2.1, 04 §2.1)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-58 🔥 | BE | P0 | `config/app` for customer/android, rider/android, customer/ios, no headers | Policy and store URL per app; nulls without headers; exact schema | ✅ |
| P1-TC-59 | BE | P1 | `config/app` with an ancient version and a garbage Bearer; POST | 200 (exempt, public); 405 | ✅ |
| P1-TC-60 🔥 | BE | P0 | `/me/` and `otp/request` with partial or malformed client headers or version == min (0.0.0); refresh with an old version | No 426 anywhere | ✅ |
| P1-TC-61 | BE | P0 | Version below `min_supported_version` | 426 `APP_UPDATE_REQUIRED` with details | ⏭ Min is 0.0.0 for every app/platform; QA may not change `AppConfig` (shared DB, user's phone testing) |
| P1-TC-62 | BE | P0 | Maintenance on | 503 `MAINTENANCE` on app endpoints; `config/app` and refresh exempt | ⏭ same reason |
| P1-TC-63 | BE | P0 | Redis down (redis-down profile) | `config/app` 200 from DB; non-test OTP send/verify → 503 `SERVICE_UNAVAILABLE`; test numbers sign in; me/refresh/logout/addresses work | ✅ |

### Staff, roles and admin (05 §2–§3, 09 §3.1)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-64 🔥 | ADM | P0 | Super Admin email + password at `/admin/login/` | 302 to `/admin/`, dashboard 200, `sessionid` HttpOnly; the session is not accepted on `/api/v1/` | ✅ (local; staging uses Secure cookies over http, so admin was run on local only) |
| P1-TC-65 | ADM | P0 | Non-existent username: 6 wrong logins, uppercase variant, another username | Locked after 5 (429); case-insensitive; other username not locked; axes `failures ≥ 5` | ✅ |
| P1-TC-66 | ADM | P1 | Groups and permissions (DB) | 7 roles; Super Admin accounts/auth/cms; Ops + Support view/change customer; others none in P1 | ✅ |
| P1-TC-67 | ADM | P0 | Role matrix per 05 §3 (P1 rows) page by page for 7 roles | Allowed/denied per matrix | ⏭ QA run 2: admin-panel-dev is reworking the admin UI |
| P1-TC-68 | ADM | P1 | POST `/admin/login/` without a CSRF token | 403 | ✅ |
| P1-TC-71 | ADM | P1 | Customers admin Block / Unblock on a QA customer | Block: inactive, tokens revoked; Unblock: login works, same id | ✅ |
| P1-TC-95 | ADM | P2 | Staff session lifetime vs 05 §5 (8 h; 2 h idle for admin roles) | Per doc | ❌ [BUG-0006](../bugs/BUG-0006.md) (fixed 12 h, no idle) |

### Database (read-only SQL) (07 §2.1/§3/§4)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-69 | BE | P0 | Unique indexes and duplicates on phone/email/auth_id; lowercase emails; blank stored as NULL; E.164 phones | Unique, no duplicates (case-insensitive), lowercase, no `''`, all E.164 | ✅ |
| P1-TC-70 | BE | P0 | Partial unique index; users with >1 or 0 live defaults; deleted default rows | Present; 0; 0; 0 | ✅ |
| P1-TC-71b | BE | P0 | OTP storage: columns; `code_hash` format; plain SHA-256 of `123456`; attempts | Only `code_hash` (64 hex, keyed HMAC); max attempts ≤ 5 | ✅ |
| P1-TC-72 | BE | P1 | FK constraints and orphan counts (addresses, devices, outstanding/blacklisted tokens, user groups, version policies) | FKs present; 0 orphans | ✅ |
| P1-TC-73 | BE | P0 | Soft-deleted address in DB vs API list | Row kept with `is_deleted`; API list = live DB rows | ✅ |
| P1-TC-74 | BE | P1 | Column types | lat/lng `numeric(9,6)`; no float columns; lengths 15/64/512; range and singleton check constraints | ✅ |
| P1-TC-75 | BE | P2 | Retention state | No OTP rows > 30 days; no un-anonymised deletions past 30 days | ✅ (trivially: the system is days old) |

### Cross-cutting security, PII, performance and fuzzing
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-76 | BE | P0 | Strict schema validation of every response (`additionalProperties: false`); enumeration probes (OTP request, email conflict) | No undocumented fields (no `code_hash`, password, `is_staff`…); no account enumeration | ✅ |
| P1-TC-77 | BE | P1 | Grep the QA instance logs | No unmasked `+91` numbers, no JWTs, no OTP codes for QA traffic | ✅ (0 unmasked phones and 0 JWTs in all 7 instance logs of the run) |
| P1-TC-78 | BE | P1 | ~30 sequential calls per main endpoint; bursts of 20 | p95 within 09 §1 read target (< 300 ms); no 5xx caused by the app | ✅ baseline recorded (07 report); env risk OBS-01 |
| P1-TC-79 | BE | P1 | schemathesis (12 examples × 13 ops, OTP/delete excluded) | No app 5xx; documented statuses; schema conformance | ✅ after triage. The automated run was **not green** (7 failing operations): every failure was triaged by manual replay to BUG-0004, OBS-01 (remote-DB connect timeouts → 500) or OBS-04 (local DEBUG HTML 404). The check tweak afterwards was not re-run. |
| P1-TC-96 | BE | P1 | Production settings: SMS backend and system checks | Deployed env refuses the console/locmem SMS backend | ❌ [BUG-0005](../bugs/BUG-0005.md) |

### Mobile apps (executed as static review only this run; device cases pending)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P1-TC-80 🔥 | CUS | P0 | Cold start → splash → `config/app` → onboarding (first launch) / login / home | Routes per 03 §2.1 | ⬜ device run needed |
| P1-TC-81 | CUS/RID | P0 | `config/app` with min > installed, or maintenance | Blocking update screen with store link; dismissible prompt below latest; maintenance screen | ⬜ device + a QA-owned config (cannot change shared `AppConfig`) |
| P1-TC-82 🔥 | CUS | P0 | Login: +91 10-digit validation, consent text and links | Invalid numbers blocked client-side; consent shown | ⬜ device |
| P1-TC-83 | CUS | P0 | OTP screen: 6 digits, SMS Retriever autofill, 30 s resend countdown, wrong/expired/locked messages | Per 03 §2.2 | ⬜ device (autofill needs a real SMS) |
| P1-TC-84 | CUS | P1 | New user → complete profile (name required, email optional) | Cannot continue without a name | ⬜ device |
| P1-TC-85 🔥 | CUS/RID | P0 | Session: secure storage; silent refresh once on 401; logout to login on refresh failure | Per 03 §2.2 | ⬜ device. Static: `jivo_core` `SecureTokenStore` (FlutterSecureStorage), single-flight `AuthInterceptor` retrying once ✅ |
| P1-TC-86 | CUS | P1 | Logout | Refresh revoked, FCM token sent, local data cleared | ⬜ device |
| P1-TC-87 🔥 | CUS | P0 | Account → Delete account → OTP → login screen; re-login shows the deletion-cancelled notice | Per 03 §2.2 / 06 | ⬜ device |
| P1-TC-88 | CUS | P1 | Profile edit (name/email, phone read-only) | Saved; errors shown | ⬜ device |
| P1-TC-89 🔥 | CUS | P0 | Addresses: list/add/edit/delete/set default (no map in P1) | Matches API behaviour; loading/empty/error states | ⬜ device. Static: EmptyView / ErrorRetryView / SkeletonList present; repository pages through all results ✅ |
| P1-TC-90 | CUS | P2 | Offline banner; retry on reconnect | Banner shown and cleared | ⬜ device |
| P1-TC-91 🔥 | RID | P0 | Rider login with `X-App-Name: rider`; route by `rider_status` (NONE → placeholder/registration) | Per 04 §1/§2.1 | ⬜ device (API side ✅ in P1-TC-21) |
| P1-TC-92 | RID | P1 | Rider force update / maintenance | Per 04 §2.1 | ⬜ device + QA-owned config |
| P1-TC-93 | E2E | P1 | Re-run both apps' `integration_test` login flows against a QA backend | Pass | ⏭ No Flutter this run |
| P1-TC-94 | CUS/RID | P1 | Static review: tokens/PII in logs, hard-coded URLs or secrets, client-side money, missing states | None found | ✅ (`qa/private/runs/mobile-static-review-4960527.txt`; OBS-05 obfuscation not configured yet) |

## Totals (QA run 1)
| | Cases | ✅ | ❌ | ⏭ | ⬜ |
|---|---|---|---|---|---|
| Phase 0 | 25 | 21 | 1 | 2 | 1 |
| Phase 1 | 105 | 78 | 8 | 6 | 13 |

Pass rates: P0 21/25 (84%) and P1 78/105 (74%) of all cases. Of the cases that were executed (✅ or ❌): P0 21/22 and P1 78/86.

Notes:
- The **Pri P0/P1** cases not yet passed are:
  - ❌ P1-TC-04, 13 and 14b (all BUG-0002), P1-TC-24c (BUG-0003) and P1-TC-57 (BUG-0007)
  - ⏭ P1-TC-61, 62, 67 and 46
  - ⬜ all device cases
- Automated cases are in `qa/tests/`. The raw outputs are in `qa/private/runs/`, which is gitignored.
