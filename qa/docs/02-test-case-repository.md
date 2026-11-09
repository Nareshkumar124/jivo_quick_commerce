# 02: Test Case Repository: Phases 0, 1, 3, 4 and 5

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

## Phase 3: Cart, coupons, orders and payments (stage 1, 2026-11-04)
**Build:** `qa/phase-2` at `c2c153a` (`develop` merged in: backend R2b WIP and admin T-304 WIP). QA instance `127.0.0.1:8004`, local settings, FakeRazorpayGateway, shared remote DB. **R2b** = re-run after the backend R2b review-fix merge. **T-304** = re-run after the admin T-304 merge.

Sources: 08 §1–§4, §6, §7; 06 §2.5, §2.6, §5, §6; 05 §3 (P3 rows, DL-46); DL-43…46. Automated in `qa/tests/test_p3_*.py` (+ `test_p2_clock.py::test_p3_tc56`).

Oracle: the bill is recomputed independently from the DB (`coalesce(price_override, selling_price)`, `mrp`, the store's `PricingConfig`) with the 08 §6.2 formula, half-up to 2 dp. It never uses the server's numbers.

| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P3-TC-01 🔥 | BE | P0 | `GET /cart/` on an empty cart | All-zero bill, only `CART_EMPTY`, ONLINE then COD, strict schema | ✅ |
| P3-TC-02 🔥 | BE | P0 | 5 carts (below/above free delivery, big, max tip 500) | Every bill field = oracle; 2-dp strings; Σ line_total = item_total | ✅ |
| P3-TC-03 | BE | P1 | Thresholds below/above free delivery | `amount_to_*` = remaining amount, or null once reached | ✅ |
| P3-TC-04 | BE | P1 | Set the same qty twice; PATCH line; qty 0; DELETE line | Sets, never adds; PATCH 0 → 400; POST 0 removes | ✅ |
| P3-TC-05 | BE | P0 | Qty > max; out-of-stock variant; variant not sold; bad qty types | 422 `MAX_QTY_EXCEEDED` {variant_id, max}; 409 `STOCK_UNAVAILABLE` orderable 0; 400 | ✅ (OBS-P3-02: `"2"` is coerced) |
| P3-TC-06 | BE | P0 | Add 4 units to the cart; read `reserved` | The cart never reserves stock (08 §6.1) | ✅ |
| P3-TC-07 | BE | P1 | Tip −1 / 500.01 / 3 dp / text; chips duplicate/unknown; note 201; `DELETE /cart/` | 400s; DELETE drops lines and tip, keeps address and instructions | ✅ |
| P3-TC-08 | BE | P0 | Mumbai address; another user's address; `?address_id=` preview | 422 `NOT_SERVICEABLE` and nothing saved; 400; the preview is not saved | ✅ |
| P3-TC-09 🔥 | BE | P0 | No token; no / malformed / unknown `X-Store-Id` | 401 `AUTH_REQUIRED`; 400; 404 `STORE_NOT_FOUND` | ✅ |
| P3-TC-10 🔥 | BE | P0 | User A patches/deletes user B's cart line | 404, B's line unchanged (IDOR) | ✅ |
| P3-TC-11 | BE | P1 | An orderable cart | No line issue, `can_place_order` true | ✅ (the issue-line case needs stock to drop after the item is added: ⬜, not producible without stock writes) |
| P3-TC-12 🔥 | BE | P0 | Apply `jivo50` (lower case); remove twice | FLAT discount; bill = oracle with the coupon; DELETE idempotent | ✅ |
| P3-TC-13 | BE | P0 | JIVO10 on a ₹3,591 cart and a ₹549 cart | Capped at max_discount; 10 % half-up | ✅ |
| P3-TC-14 | BE | P0 | OILS15 on oil + seeds; seeds only | Discount on the eligible subtotal only; 422 `NO_ELIGIBLE_ITEMS` | ✅ |
| P3-TC-15 | BE | P1 | JIVO50 on a ₹165 cart | 422 `COUPON_NOT_ELIGIBLE` MIN_ORDER_VALUE + amount_to_unlock | ✅ |
| P3-TC-16 | BE | P1 | Apply, then drop below the minimum | Coupon kept, `is_applicable` false, 0 discount, unlock 20.00, blocker | ✅ |
| P3-TC-17 | BE | P1 | Unknown code; empty/long/non-string code | 422 `COUPON_INVALID`; 400 | ✅ |
| P3-TC-18 | BE | P1 | `GET /cart/coupons/` | Strict schema; hidden coupon absent; eligible first, by savings; savings = discount | ✅ |
| P3-TC-19 | BE | P1 | Coupon endpoints without a token / store header | 401 / 400 | ✅ |
| P3-TC-20 🔥 | BE | P0 | COD placement | 201 PLACED, COD_PENDING, `razorpay` null, bill = cart = oracle, +1 reserved (no expiry), lines leave the cart, history `''→PLACED`, JV-number | ✅ R2b |
| P3-TC-21 🔥 | BE | P0 | ONLINE placement, then cancel (T5) | 201 PAYMENT_PENDING, fake key, amount = paise, reserved with expiry, 15-min window, cart kept; T5: CANCELLED/FAILED, stock released, cart kept; 2nd cancel 409 | ✅ R2b |
| P3-TC-22 🔥 | BE | P0 | Same key + same body; same key + another body | 200, the same order and gateway order, 1 row, 1 reservation; 400 on `Idempotency-Key` | ✅ |
| P3-TC-23 | BE | P1 | Key missing / short / spaces / 65 characters | 400 | ✅ |
| P3-TC-24 🔥 | BE | P0 | `expected_grand_total` ≠ bill | 409 `PRICE_CHANGED` {expected, actual}; nothing created | ✅ |
| P3-TC-25 | BE | P0 | Empty cart; unserviceable / unknown address; bad method | 400; 422 `NOT_SERVICEABLE`; 400; 400 | ✅ |
| P3-TC-26 | BE | P1 | Item total below the store minimum | 422 `MIN_ORDER_NOT_MET` with the amounts | ⏭ no demo variant is priced below ₹99 |
| P3-TC-27 🔥 | BE | P0 | A second placement while one is unpaid | 409 `INVALID_STATE_TRANSITION` {pending_order_id} (DL-44) | ✅ |
| P3-TC-28 | BE | P1 | COD above ₹2,000 | Cart COD unavailable (ABOVE_LIMIT); 422 `COD_NOT_AVAILABLE` {reason, cod_max}; nothing reserved | ✅ |
| P3-TC-29 🔥 | BE | P0 | B retrieves/cancels/retries/verifies A's order | 404 ×4; not in B's list; A's order unchanged | ✅ |
| P3-TC-30 | BE | P1 | `GET /orders/?status=active/past/bogus`, no token | Strict schema; PAYMENT_PENDING in active; past is terminal only; 400; 401 | ✅ |
| P3-TC-31 | BE | P1 | Cancel with a bad/missing reason; cancel a COD PLACED order | 400; 409 {status: PLACED} (P3: T5 only) | ✅ |
| P3-TC-32 | BE | P2 | The 06 §2.6 worked signature example | Matches | ✅ |
| P3-TC-33 🔥 | BE | P0 | Verify a valid signature ×3 | 200 PLACED/PAID, 1 capture, 0 refunds, reservation expiry cleared, cart lines gone, history T3 | ✅ R2b |
| P3-TC-34 🔥 | BE | P0 | Verify: zero signature, other secret, foreign gateway order, non-ASCII, malformed, other user, no token | 400 `PAYMENT_VERIFICATION_FAILED` ×3; 400; 400; 404; 401; still PAYMENT_PENDING, no capture | ✅ |
| P3-TC-35 🔥 | BE | P0 | Webhook: bad signature, signature of another body, no signature, no event id | 400; nothing stored; order unchanged | ✅ |
| P3-TC-36 🔥 | BE | P0 | `payment.captured` webhook, the same event again, a new event id, then verify | processed → duplicate → no 2nd capture → verify 200 PLACED; 1 capture, 0 refunds | ✅ |
| P3-TC-37 | BE | P0 | Capture of the wrong amount | Not placed; one full refund of that amount; cancel still allowed | ✅ stage 2 · ✅ refund re-check `9ed7ffc` (T-310): refund PROCESSED with a gateway id, order settled once |
| P3-TC-38 🔥 | BE | P0 | Cancel, then verify + webhook for the same capture (T3a) | 409 {status: CANCELLED}; one full refund; REFUND_PENDING→REFUNDED; stock stays released | ✅ stage 2 · ✅ refund re-check `9ed7ffc` (T-310): refund PROCESSED with a gateway id, order settled once |
| P3-TC-39 | BE | P0 | Retry-payment (same key ×2), pay the new gateway order, then the old one | New gateway order, same on repeat, window not extended; PLACED; the 2nd capture refunded once (DL-45); retry on PLACED 409 | ✅ stage 2 · ✅ refund re-check `9ed7ffc` (T-310): refund PROCESSED with a gateway id, order settled once |
| P3-TC-40 | BE | P1 | Retry without a key; retry on a cancelled order | 400; 409 {status: CANCELLED} | ✅ |
| P3-TC-41 | BE | P1 | `payment.failed`, then capture, then `payment.failed` again | The attempt FAILED, order still pending; then PLACED; the capture is never overwritten | ✅ |
| P3-TC-42 | BE | P1 | Signed: unknown gateway order, unhandled type, malformed payload; garbage body | 200 ignored ×3; 400 | ✅ |
| P3-TC-43 🔥 | BE | P0 | 5 customers race for the last 2 units (ONLINE, parallel) | Exactly one 201, four 409 `STOCK_UNAVAILABLE`; reserved ≤ on_hand; released after the cancel | ✅ (`[201, 409, 409, 409, 409]`, reserved back to baseline) |
| P3-TC-44 🔥 | BE | P0 | One `Idempotency-Key` sent 6× in parallel | One order, one reservation, one 201 and five 200 | ✅ |
| P3-TC-45 | BE | P0 | ONLINE order with a coupon, then T5 | Redemption HELD (₹50), then RELEASED | ✅ |
| P3-TC-46 | BE | P1 | 31 placements within an hour | 31st: 429 `RATE_LIMITED` + `retry_after_seconds` + `Retry-After` | ✅ |
| P3-TC-47 | BE | P0 | Unpaid ONLINE order with a coupon: wait for the :8001 beat (T4), then a late capture | PAYMENT_FAILED/FAILED, stock and coupon released, cart kept, retry 409; late webhook → one refund, not revived | ✅ stage 2: automated run `1 passed in 969.11s` (`QA_SLOW=1`) · ✅ refund re-check `9ed7ffc` (T-310): refund PROCESSED with a gateway id, order settled once |
| P3-TC-48 🔥 | BE | P0 | SQL: order money identities over all orders | 0 violations | ✅ |
| P3-TC-49 🔥 | BE | P0 | SQL: 0 ≤ reserved ≤ on_hand, reserved ≥ Σ ACTIVE reservations, no ACTIVE on terminal orders | 0 violations | ✅ |
| P3-TC-50 🔥 | BE | P0 | SQL: duplicate payment ids, two live captures, double refunds, duplicate events, PAID without capture, dead+PAID | 0 | ✅ |
| P3-TC-51 | BE | P1 | SQL: history matches status; coupon counts within limits | 0 | ✅ |
| P3-TC-52 | BE | P0 | The same webhook event 6× in parallel | All 200, one `processed`, one capture, one stored event | ✅ |
| P3-TC-53 | BE | P0 | Verify and cancel at the same instant (3 rounds) | Either PLACED (cancel 409, 0 refunds, reserved) or CANCELLED (verify 409, 1 refund, released); never both | ✅ |
| P3-TC-54 | BE | P1 | `POST /orders/` without `X-Store-Id`; without the app headers | 400; processed normally (headers are informational, P0-TC-13) | ✅ |
| P3-TC-55 | BE | P0 | WELCOME100 for a user with a PLACED order / with only cancelled unpaid orders | 422 FIRST_ORDER_ONLY / applicable (DL-45) | ✅ |
| P3-TC-56 | BE | P1 | Clock profile (store closed): cart and `POST /orders/` | `STORE_CLOSED` first blocker; 422 `STORE_CLOSED` {store_id, opens_at}; nothing created | ✅ (clock profile `QA_FAKE_NOW=2026-11-04T23:30+05:30`, token prepared on local; no writes) |
| P3-TC-57 | BE | P2 | Signed webhook with a payment id over 64 / over 56 characters (refund) | 200 ignored | ✅ stage 2: [BUG-0009](../bugs/BUG-0009.md) verified, both events `ignored`, nothing stored |
| P3-TC-58 | BE | P1 | `refund.processed` replayed for a processed refund; `refund.failed` for an unknown refund | No double count; ignored | ✅ stage 2 · ✅ refund re-check `9ed7ffc` (T-310): refund PROCESSED with a gateway id, order settled once |
| P3-TC-59 | ADM | P0 | 05 §3 P3 rows (DL-46): Catalog Manager manages coupons; Support/Finance view coupons/orders/payments; Finance views webhook events; only Super Admin changes orders | Per the matrix, enforced server-side | ✅ stage 2: 7 roles × 7 pages = 49 checks match the matrix (`test_p3_tc59`); 59b: Catalog Manager saves a coupon, Support/Finance get 403 on a change POST, nobody can add an order or payment |
| P3-TC-60 | ADM | P1 | Admin order/payment screens show the bill, history, payments and refunds read-only | Per 05 | ✅ stage 2: order screen read-only (no Save; change POST 403 even for Super Admin; order unchanged); 60b: no full QA phone for Store Manager/Staff or Finance on the order list, detail or search |
| P3-TC-61 | BE | P1 | Coupon usage limits exhausted (per user, total); expired / not-started coupons | 422 `COUPON_USAGE_EXCEEDED` {scope} / `COUPON_EXPIRED` / `COUPON_INVALID` | ✅ stage 2 with QA coupons `QAP3*` (hidden, made in admin as Super Admin, switched off afterwards): expired → COUPON_EXPIRED; not started or inactive → COUPON_INVALID; expired after applying → blocker + 422, nothing created; per_user and total limits count HELD; T5 gives the use back; last-use race of 3 → `[201, 422, 422]` |
| P3-TC-62 | BE | P1 | COD for a `cod_blocked` user; store COD disabled | 422 `COD_NOT_AVAILABLE` NOT_ALLOWED / COD_DISABLED | ✅ stage 2 (cod_blocked part, QA user E via the Customers admin action, then reset): COD NOT_ALLOWED in the cart and 422 on placement; allowed again after reset. Store COD-disabled ⏭ by PM instruction (the demo store's COD is in use on the phone) |
| P3-TC-63 | BE | P1 | Gateway unreachable at placement / retry | 503 `SERVICE_UNAVAILABLE`, nothing created | ⏭ cannot be induced black-box with the fake gateway |
| P3-TC-64 | CUS | P0 | Customer app cart → checkout → pay (fake key) / COD → success; retry/cancel screens | Per 03 §2.8–2.9 | ⬜ the user's phone test (in progress; PM) |
| P3-TC-65 | BE | P0 | `refund.processed` (no receipt) arrives before `process_refund` recorded the id; the gateway retries the same event id before and after the task runs | 503 `SERVICE_UNAVAILABLE` ×2, nothing stored; after the task: 200 `processed`; replay `duplicate`; one refund, REFUNDED once | ✅ `9ed7ffc` (QA-started worker, deterministic) |
| P3-TC-66 | BE | P0 | `refund.processed` with the refund's receipt before the task, then the task runs | 200 `processed` via the receipt; the task skips; one refund; order unchanged by the task | ✅ `9ed7ffc` |
| P3-TC-67 | BE | P1 | While payment A has an unrecorded PENDING refund: refund events for another payment (no receipt / A's receipt / malformed payment id) | 200 `ignored` ×3 (never 503); A's refund untouched, then settled by the task | ✅ `9ed7ffc` |
| P3-TC-68 | BE | P1 | `refund.failed` (receipt-matched) before the task, then the task runs | Refund FAILED and stays FAILED (never back to PENDING); no second refund; order not REFUNDED | ✅ `9ed7ffc` |
| P3-TC-69 | BE | P1 | `refundwindow` profile (window 20 s): unmatched refund event inside the window, then 22 s later | 503, then 200 `ignored` with the "past the retry window" warning; the refund still settles via the task | ✅ `9ed7ffc` |

### Totals (Phase 3 stage 1)
| | Cases | ✅ | ❌ | ⏭ | ⬜ |
|---|---|---|---|---|---|
| Phase 3 (stage 1) | 64 | 56 | 1 | 6 | 1 |
| Phase 3 (stage 2, `f84482f`) | 64 | 61 | 0 | 2 | 1 (P3-TC-64, the user's phone test) |
| Phase 3 (refund re-check, `9ed7ffc`, T-310) | 69 | 66 | 0 | 2 (TC-26, 63: carried into P4 as P4-TC-49/50, DL-50) | 1 (P3-TC-64) |

**Refund re-check (`9ed7ffc`):** 66/69 (95.7%). P3-TC-37/38/39/47/58 re-passed on the merged refund fixes; P3-TC-65…69 (new, refund webhook ordering) pass. Not passed: P3-TC-26 and 63 (⏭, moved to P4 by DL-50) and P3-TC-64 (the user's device test).

**Stage 2:** 61/64 (95.3%). The 2 not passed are ⏭: P3-TC-26 (P1, no demo variant below ₹99) and P3-TC-63 (P1, gateway fault injection). P3-TC-64 is counted as not run and belongs to the user's device test. No ❌.

Stage 1: 56/64 (87.5%) of all cases, and 56/57 of the cases executed. The Pri P0/P1 cases that have not passed are all ⏭/⬜, none ❌: P3-TC-26 (no data), 59/60 (T-304), 61 (QA coupon needed), 62 (admin/shared config), 63 (gateway fault injection) and 64 (device). The only ❌ is P3-TC-57 (Pri P2, BUG-0009).

## Phase 4: Order processing and store ops (written 2026-11-04, QA T-416)
**Contract under test:** backend P4 R1 (interim `schema.yaml` in the `backend/phase-4` worktree, read-only: `Order.timeline / cancellation / amount_refunded / refunds / can_download_invoice`, `OrderLine.quantity_unavailable`, `orders_reorder`, `orders_invoice`, the widened `orders_cancel`). **Behaviour:** R2 (backend `store_ops`, `order_refunds`, invoices) and the admin P4 screens are **not merged** yet. Cases marked **R2** are automated as skipped stubs (`awaiting P4 R2 merge`) in `qa/tests/test_p4_*.py`; the rest already run on develop.

Sources: 08 T6–T8a, T11, T12, §6.1, §6.3, §6.4, §7, §9; 05 §1.2, §1.3, §2 (Orders, Payments & refunds, Audit log), §3; 06 §2.6, §5 (`process_refund`, `sync_refund_status`, `auto_accept_orders`, `store_acceptance_sla_alert`, `generate_invoice`); 03 §2.5, §2.10; DL-50.

Oracle for T8a: the reduced bill is recomputed independently (DB prices, the store's `PricingConfig`, 08 §6.2 + §6.3: coupon discount kept and capped at the new `item_total`, fees never above the old ones, refund = old − new `grand_total`), never taken from the server.

Data notes: the shared dev DB has a single store (GGN-01), so the cross-store scoping cases (P4-TC-30) need a second store owned by QA or staging. Auto-accept (P4-TC-36) needs a store setting change: run on a QA-owned store or staging, never on GGN-01 (the user's phone test uses it). Invoices (P4-TC-16/17/57) need a DELIVERED order, which needs the Phase 5 rider flow: deferred to P5 unless the backend exposes a way to reach DELIVERED in P4.

### Customer order API
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P4-TC-01 🔥 | BE | P0 | Order detail of an ONLINE order, then after verify (strict P4 schema on `orders_retrieve`, `orders_create`, `payments_razorpay_verify`, `orders_cancel`) | `timeline` oldest first with the 08 §1 labels; `cancellation` null; `refunds` []; `amount_refunded` "0.00"; `can_download_invoice` false; every `quantity_unavailable` 0; decimals as 2-dp strings | ✅ `1b3552d` |
| P4-TC-02 🔥 | BE | P0 | Customer cancels a COD order in PLACED (T11) | 200 CANCELLED; `cancellation {reason, message, cancelled_by: customer, cancelled_at}`; reservation released; coupon redemption reversed; no Refund row; `can_cancel` false; timeline ends CANCELLED | ✅ `1b3552d` |
| P4-TC-03 🔥 | BE | P0 | Customer cancels a paid ONLINE order in PLACED (T11) | One full refund (ORDER_CANCELLED) to the original payment; `payment_status` REFUND_PENDING → REFUNDED (QA worker); `amount_refunded` = `grand_total`; stock released; repeat cancel 409, no 2nd refund | ✅ `1b3552d` |
| P4-TC-04 | BE | P0 | Store accepts, then the customer cancels in ACCEPTED (paid ONLINE and COD) | 200 CANCELLED; full refund (ONLINE) / nothing due (COD); `cancelled_by` customer | ✅ `1b3552d` (ONLINE + COD; T6 via service) |
| P4-TC-05 🔥 | BE | P0 | Customer cancels in PACKING and in PACKED | 409 `INVALID_STATE_TRANSITION` `{status}`; `can_cancel` false; nothing released or refunded (08 §7, "Contact support") | ✅ `1b3552d` (PACKING + PACKED) |
| P4-TC-06 | BE | P0 | The same paid order cancelled 5× in parallel | Exactly one 200, four 409; one Refund row; reservation released once | ✅ `1b3552d` (1×200, 4×409, 1 refund) |
| P4-TC-07 🔥 | BE | P0 | User B cancels user A's order: (a) PAYMENT_PENDING, (b) PLACED | 404 both; A's order and reservation unchanged (IDOR) | ✅ `1b3552d` (a + b) |
| P4-TC-08 | BE | P1 | Customer cancel with staff reasons (ITEMS_UNAVAILABLE, SUSPECTED_FRAUD, NO_RIDER, OTHER_STAFF, CUSTOMER_REQUEST), empty / null / number, note of 251 characters | 400 `VALIDATION_ERROR`; order unchanged | ✅ `1b3552d` |
| P4-TC-09 | BE | P0 | Customer cancel and staff "Start packing" at the same instant (3 rounds) | Either CANCELLED (+ refund, start packing refused) or PACKING (cancel 409, no refund); never both, never two refunds | ✅ `1b3552d` (3 rounds: cancelled, packing, packing; T7 via service) |
| P4-TC-10 | BE | P2 | Instance with `CUSTOMER_CANCEL_UNTIL=PLACED`: cancel in ACCEPTED | 409; `can_cancel` false in ACCEPTED | ✅ `1b3552d` (`cancelplaced` profile) |
| P4-TC-11 🔥 | BE | P0 | Reorder a past order twice | 200 `ReorderResult`; each line raised to the ordered units (never on top); `added_count` = lines in the cart; repeat changes nothing; no stock reserved; coupon and tip untouched | ✅ `1b3552d` |
| P4-TC-12 | BE | P1 | Reorder an order whose variants are now out of stock / partly in stock / not sold at the store | `unavailable[]` with OUT_OF_STOCK / LIMITED_STOCK (+ `added_quantity`) / NOT_AVAILABLE; the rest added | ✅ OOS/LIMITED (stage 1) + NOT_AVAILABLE at QA-02 (stage 2 `f744508`) |
| P4-TC-13 | BE | P1 | Reorder when the cart already holds more units of a line | That line left as it is; other lines raised | ✅ `1b3552d` |
| P4-TC-14 🔥 | BE | P0 | (a) list/detail/cancel without a token; (b) reorder and invoice of another user's order; reorder without / with an unknown `X-Store-Id`; without a token | (a) 401 `AUTH_REQUIRED`; (b) 404 `NOT_FOUND`; 400; 404 `STORE_NOT_FOUND`; 401 | ✅ `1b3552d` (a + b) |
| P4-TC-15 | BE | P0 | Invoice of a PLACED / CANCELLED order | 409 `INVALID_STATE_TRANSITION` `{status}`; `can_download_invoice` false | ✅ `1b3552d` |
| P4-TC-16 | BE | P1 | Invoice of a DELIVERED order, twice | 200 `{invoice_number, issued_at, url, expires_at}`; same number on repeat; series per store and financial year; the PDF opens; GST lines sum to the bill; placeholder banner "not a valid tax invoice" (D-12) | ⏭ needs a QA DELIVERED order (P5); the 503 on this host (no WeasyPrint libs) cannot be reached before DELIVERED |
| P4-TC-17 | BE | P1 | Signed invoice URL: after `expires_at`, with a changed signature, with another order's path; check the URL for PII | Refused (403/404); no phone, name or address in the URL | ⏭ needs a DELIVERED order (P5) |
| P4-TC-18 | BE | P1 | Order list after cancel / accept | CANCELLED in `past`; ACCEPTED / PACKING in `active`; strict schema | ✅ `1b3552d` |
| P4-TC-19 🔥 | ADM | P0 | Store Staff accepts a PLACED order (T6) | ACCEPTED; history actor + `actor_type` store; audit row; customer timeline "Order confirmed"; accepting again refused, no 2nd history row | ✅ console (stage 2 `f744508`) + service (stage 1) |
| P4-TC-20 🔥 | ADM | P0 | Start packing (T7), Mark packed (T8) | PACKING, then PACKED; 4-character pickup code on the slip; pick list with every line | ✅ console (stage 2 `f744508`): slip with number, 4-char code, QR, item count |
| P4-TC-21 | ADM | P0 | Out-of-order actions: pack from PLACED/ACCEPTED, start packing from PLACED, accept PACKING, anything on CANCELLED / PAYMENT_PENDING | Refused with a readable message; no state or history change | ✅ console (stage 2 `f744508`): 409 out of order, 404 unknown step, 405 on GET |
| P4-TC-22 🔥 | ADM | P0 | T8a: paid ONLINE order in PACKING, mark 1 of 2 units of a line unavailable | Bill = oracle (§6.3); one refund (ITEMS_UNAVAILABLE) of old − new `grand_total`; reserved −1; `quantity_unavailable` 1; `line_total`/`item_count` count units coming; customer notified | ✅ console (stage 2 `f744508`): oracle match, second post 'nothing changed', 1 refund |
| P4-TC-23 | ADM | P0 | T8a on a COD order | Amount due reduced; no Refund; `payment_status` COD_PENDING; reserved −1 | ✅ `1b3552d` |
| P4-TC-24 | ADM | P0 | T8a with every unit unavailable | CANCELLED (ITEMS_UNAVAILABLE, `cancelled_by` store); ONLINE refunds total = amount paid, never more; reservation released | ✅ `1b3552d` |
| P4-TC-25 | ADM | P0 | T8a that drops `item_total` below the free-delivery and small-cart thresholds | `delivery_fee`/`small_cart_fee` not raised; new `grand_total` ≤ old; refund ≥ 0 | ✅ `1b3552d` (with the ₹45 sachet) |
| P4-TC-26 | ADM | P1 | T8a on an order with a FLAT coupon whose minimum is no longer met | Discount kept, capped at the new `item_total`; redemption stays REDEEMED | ✅ `1b3552d` (redemption APPLIED → REVERSED; doc term corrected) |
| P4-TC-27 | ADM | P0 | Item unavailable on PACKED; qty > line qty, 0, negative; an item of another order; the same adjustment submitted twice | Refused, nothing changed; the double submit refunds once | ✅ console (stage 2 `f744508`) |
| P4-TC-28 | ADM | P0 | Store Manager / Ops / Support cancel (T12) in PLACED, ACCEPTED, PACKING, PACKED | CANCELLED; `cancelled_by` store / ops; full refund when paid; reservation released with no StockMovement and no `on_hand` change; audit row | ✅ `1b3552d` (4 states; Ops on COD) |
| P4-TC-29 | ADM | P1 | Staff cancel without a reason / with a customer-only reason | Refused | ✅ console (stage 2 `f744508`) + service |
| P4-TC-30 🔥 | ADM | P0 | Store Staff / Manager of GGN-01: another store's console URL; accept / cancel / unavailable on another store's order id | 404 (or 403); nothing changes; other stores' orders never listed | ✅ QA-02 (stage 2 `f744508`) |
| P4-TC-31 🔥 | ADM | P0 | 05 §3 P4 rows × 7 roles: live board, packing console, cancel, refund, audit log (pages and POST actions) | Exactly per the matrix, enforced server-side | ✅ pages + POSTs (stage 2 `f744508`) + service (stage 1) |
| P4-TC-32 | ADM | P0 | Support refunds 500.00 and 500.01; Finance any amount; refund above refundable; two concurrent manual refunds | 500.00 ok, 500.01 refused (`SUPPORT_REFUND_LIMIT`); cap enforced; never above refundable | ❌ console: no manual refund form (BUG-0010); service level ✅ stage 1 |
| P4-TC-33 | ADM | P0 | Manual partial then full refund (GOODWILL); double submit | PARTIALLY_REFUNDED → REFUNDED; `amount_refunded` = Σ processed; one refund per submit | ❌ console: no manual refund form (BUG-0010); service level ✅ stage 1 |
| P4-TC-34 | ADM | P1 | Retry a FAILED refund from the ops screen; try to retry a PENDING / PROCESSED one | New refund `<key>:retry-1`; only FAILED retryable; customer sees PENDING (never FAILED) | ✅ console (stage 2 `f744508`): retry action; same form twice → 'already sent', one retry (OBS-P4-01 verified) |
| P4-TC-35 | BE | P1 | Refund PENDING without a gateway answer for > `REFUND_STUCK_MINUTES`; `sync_refund_status` runs | Re-sent once; the gateway lookup prevents a second refund | ✅ `1b3552d` (2 resends + original task → 1 gateway refund) |
| P4-TC-36 | BE | P1 | Store with auto-accept: new PLACED order | ACCEPTED after `AUTO_ACCEPT_DELAY_SECONDS` (+ beat); history `actor_type` system | ✅ QA-02 (stage 2 `f744508`): ACCEPTED by system within seconds |
| P4-TC-37 | BE | P1 | Order not accepted within `STORE_ACCEPTANCE_SLA_SECONDS` (60 s); one accepted in time | Ops alert raised once (not on the next sweep); none for the accepted one | ✅ `1b3552d` (alerted/already/skipped; service level) |
| P4-TC-38 | ADM | P1 | Live board `/ops/orders/live/` | Columns Placed → Out for delivery + exceptions lane; card fields and age timer (amber/red vs SLA); filters store / payment / SLA breach; 10 s HTMX poll returns the partial; no full phone | ✅ (stage 2 `f744508`): Placed…Packed + Out for delivery + Exceptions lanes, filters, 10 s poll, no phone |
| P4-TC-39 | ADM | P1 | Packing console `/ops/store/<store>/` | New-orders queue with SLA countdown and sound; pick list; slip with order number, 4-char code, QR, item count; accepting-orders switch (Store Manager only) | ✅ (stage 2 `f744508`): queue, slip, switch on QA-02 (Super Admin), switch offered to SM not SS |
| P4-TC-40 | ADM | P1 | Orders admin: filters, detail, actions, CSV export | Timeline, payments, refunds; cancel/refund only with permission; CSV formula-injection escaped | ❌ (stage 2 `f744508`): filters/detail ✅; no refund action (BUG-0010), no CSV export (BUG-0011) |
| P4-TC-41 🔥 | ADM | P0 | Each staff action (accept, start packing, pack, unavailable, cancel, refund), then the audit log | One row per action with actor, action, object, changes; no customer PII; read-only; only Super Admin and Finance can open it | ✅ console (stage 2 `f744508`): row shown, read-only, Super/Finance only |
| P4-TC-42 | ADM | P0 | Console POST without a CSRF token; GET on action URLs | 403, nothing changes; GET never changes state | ✅ (stage 2 `f744508`) |
| P4-TC-43 | ADM | P1 | Customer detail (Customers admin, P4) per role | Orders listed; phone masked for Store Manager/Staff; full for Super Admin/Ops/Support | ✅ (stage 2 `f744508`) |
| P4-TC-44 🔥 | BE | P0 | SQL: refunds per payment ≤ captured; `amount_refunded` ∈ [0, `grand_total`]; no duplicate refund id / key; PROCESSED has a gateway id; refunds only on CAPTURED payments of the same order | 0 violations | ✅ `1b3552d` (bound updated to max(grand_total, amount_paid) for T8a) |
| P4-TC-45 🔥 | BE | P0 | SQL: no ACTIVE reservation on CANCELLED/PAYMENT_FAILED orders; 0 ≤ reserved ≤ on_hand | 0 violations | ✅ `1b3552d` |
| P4-TC-46 | BE | P1 | SQL: T6/T7/T8/T11/T12 history rows with actor types; the API timeline equals the history | 0 violations | ✅ `1b3552d` |
| P4-TC-47 | BE | P0 | SQL: bill identity after T8a; `item_total` = Σ (qty − unavailable) × price; `amount_refunded` ≤ `amount_paid`; ITEMS_UNAVAILABLE refund = old − new | 0 violations | ✅ `1b3552d` (incl. amount_paid backfill) |
| P4-TC-48 | BE | P2 | Domain events per transition (08 §9): T6, T8a, T11, T12, refund processed | Emitted once each, after commit (console SMS / log) | ✅ `1b3552d` (worker log: one accepted + one cancelled event, after commit) |
| P4-TC-49 | BE | P1 | (ex P3-TC-26, DL-50) Cart of one ₹45 sachet `JV-WG-PW-10S`; place COD and ONLINE | Cart blocker; 422 `MIN_ORDER_NOT_MET` {min_order_value, item_total, amount_to_min_order}; nothing created | ✅ `1b3552d` (seed_demo by PM) |
| P4-TC-50 | BE | P1 | (ex P3-TC-63, DL-50) Instance with `FAKE_GATEWAY_DOWN=1`: ONLINE placement, retry, verify; COD placement | 503 `SERVICE_UNAVAILABLE`, nothing created; verify 503, order still pending; COD 201 | ✅ `1b3552d` (`gwdown` profile: place, retry, verify 503; COD 201) |

### Customer app (device; the user's phone or the PM's device run)
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P4-TC-51 🔥 | CUS | P0 | Orders tab: active then past, status chips, pagination, empty and error states | Per 03 §2.10; no crash | ⬜ device |
| P4-TC-52 🔥 | CUS | P0 | Order detail: timeline, items with removed units struck through, server bill, refunds with "5–7 working days", invoice button only when `can_download_invoice` | Per 03 §2.10; the app computes no money | ⬜ device |
| P4-TC-53 🔥 | CUS | P0 | Cancel sheet: only when `can_cancel`; reason picker; confirmation; refund info; a 409 shows "Contact support" | Per 03 §2.10, 08 §7 | ⬜ device |
| P4-TC-54 | CUS | P1 | "Order again": cart opens, unavailable lines listed | Per 03 §2.10 | ⬜ device |
| P4-TC-55 | CUS | P2 | Home "Previously bought" rail | From past delivered orders only; hidden without history (03 §2.5) | ⬜ device (needs DELIVERED, P5) |
| P4-TC-56 | CUS | P1 | Customer app integration test "cancel an order" (S4-B) against the QA instance | Passes | ⬜ |
| P4-TC-57 | CUS | P1 | Invoice download opens the PDF; an expired link is refreshed | Per 03 §2.10 | ⏭ P5 (DELIVERED) |

### End to end
| ID | Area | Pri | Steps | Expected | Status |
|---|---|---|---|---|---|
| P4-TC-58 🔥 | E2E | P0 | COD order on the phone → accept on the packing console → start packing → one unit unavailable → pack | Customer sees "Order confirmed", "Packing", the reduced amount due and the struck-through unit; cancel is gone from PACKING | ⬜ R2 + device |
| P4-TC-59 | E2E | P0 | Paid ONLINE order → customer cancels → a late `payment.captured` for the same capture → worker settles | One refund only; REFUNDED in the app; `amount_refunded` = `grand_total` | ✅ `1b3552d` (API part) |
| P4-TC-60 | BE | P2 | Live board and packing console poll endpoints: query count and p95 with 20 open orders | Fixed query count; p95 recorded (remote-DB latency noted) | ◐ (stage 2 `f744508`): p50/p95 live-board columns 253/278 ms, packing queues 264/310 ms (remote DB); query count white-box only |

### Totals (Phase 4, plan)
| | Cases | ✅ | ❌ | ⏭ | ⬜ |
|---|---|---|---|---|---|
| Phase 4 (2026-11-04, before R2) | 60 | 3 (TC-08, 44, 45; plus part (a) of TC-07 and TC-14) | 0 | 3 (TC-16, 17, 57: need DELIVERED) | 54 |

None of the P4 cases counts toward the gate yet: the passes above are develop baselines that must be re-run on the R2 build.

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

### Totals (Phase 4 stage 1, 2026-11-04, `1b3552d`)
| | Cases | ✅ | ◐ partial | ❌ | ⏭ | ⬜ |
|---|---|---|---|---|---|---|
| Phase 4 | 60 | 37 | 5 (TC-12, 31, 32, 33, 41) | 0 | 12 (TC-16, 17, 30, 36, 38, 39, 40, 42, 43, 55, 57, 60) | 5 (TC-51–54, 56: device) + TC-58 (device + console) |

Service-level passes of console cases (TC-19–21, 27, 31, 41) are re-run through the console when admin P4 merges. TC-26's expected status was a QA wording error ("REDEEMED"; the model's state is APPLIED, then REVERSED on cancel): test corrected, not a bug.

### Totals (Phase 4 stage 2, 2026-11-04, `f744508`)
| | Cases | ✅ | ◐ | ❌ | ⏭ | ⬜ |
|---|---|---|---|---|---|---|
| Phase 4 | 60 | 46 | 1 (TC-60) | 3 (TC-32, 33, 40: BUG-0010/0011) | 4 (TC-16, 17, 55, 57: need DELIVERED, P5) | 6 (TC-51–54, 56, 58: device) |

## Phase 5: Riders and delivery (written 2026-11-05, stage 1: design only)
**Contract read:**
- 5.1/5.2: `develop` `4fdea44`, live.
- 5.3: `backend/phase-5` `fd1490c` (`schema.yaml`, services and the 06/07/08 doc diffs), not merged.
- 5.4: docs only, being built.

Nothing in this section has been executed: every status is ⬜, or ⏭ with the reason. The plan, environment, dependencies and the doc ambiguities A1–A23 are in `01-test-plan.md` §9.

**Format.** The 10 §5.4 columns, plus **Slice** (5.1–5.4, or P6), **Ref** (the doc section that is the oracle) and **Pre** (preconditions). Automated cases are `test_p5_tcNN_*` in `qa/tests/test_p5_*.py`. Those marked `[auto 5.3]` are scaffolded and skip themselves until slice 5.3 is on develop and `delivery.0002` is applied.

**Precondition shorthands** (all at store QA-02, id 2, pin 26.9124, 75.7873):

| Code | Meaning |
|---|---|
| R1, R2 | QA users C and D as riders: ACTIVE, home store QA-02, all documents approved, cash in hand 0.00, limit 5,000.00, offline, no task |
| ON(R) | Rider online: `shift/start` and a fresh location point at the store (≤ 50 m from the pin) |
| A, B | QA customers A and B. Each has a Jaipur address at 26.9250, 75.8000 (about 1.9 km from the store) |
| COD(A) / ONL(A) | A COD order / a paid ONLINE order (fake gateway verify) by A at QA-02, auto-accepted, so dispatch starts (trigger ACCEPTED) |
| OFR | The task is OFFERED to R1 |
| ASG | R1 accepted (task ASSIGNED) |
| ATS | + arrived at the store |
| PKD | + Ops marked the order PACKED (start packing → packed) |
| OFD | + pickup with the right code (task PICKED_UP, order OUT_FOR_DELIVERY) |
| ATC | + arrived at the customer |
| RET | + failed (task RETURNING, order DELIVERY_FAILED) |
| Staff | SA Super Admin, OPS, SM Store Manager (GGN-01 only), SMQ QA-only Store Manager of QA-02 (requested, 01 §9.4), SS Store Staff (GGN-01), CAT Catalog Manager, SUP Support, FIN Finance |

### 5.1 KYC and onboarding
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-01 🔥 | BE | P0 | 5.1 | 06 §3 Registration; 04 §2.2 | A logged-in user with no rider profile (spare QA number) | `GET /rider/stores/`; `POST /rider/register/` with a valid body (SCOOTER + vehicle number, preferred store QA-02) | Stores lists active stores only. 201 `RiderProfile`: status PENDING_KYC, `home_store` null, `required_documents` = PHOTO, AADHAAR_FRONT, AADHAAR_BACK, PAN, DL, RC; strict schema | ⬜ |
| P5-TC-02 | BE | P1 | 5.1 | 06 §3 | TC-01 rider | Register again (same body, then a different one) | 409 `INVALID_STATE_TRANSITION`; profile unchanged | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-03 | BE | P1 | 5.1 | 06 §3; 04 §2.2 | User with no profile | Validation: dob exactly 18 years ago (IST) and one day short; emergency contact = own phone, non-+91, a landline; SCOOTER without a vehicle number; BICYCLE with and without one; unknown and inactive `preferred_store_id`; 121-char name; `<script>` in the name | 18th birthday accepted, a day short → 400; bad contacts → 400; motorised without a number → 400; bicycle fine either way; bad store → 400; long name → 400; markup stored as text and shown escaped in the admin | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-04 | BE | P0 | 5.1 | 06 §3 KYC; 09 §3.6 | PENDING_KYC rider | Upload PHOTO (JPEG 900 KB with EXIF GPS and camera tags) and AADHAAR_FRONT (PNG); SA downloads both through the admin's signed link | 201 `RiderDocument` PENDING. The stored files are JPEG with no EXIF/GPS, under random keys in the private bucket | ⬜ |
| P5-TC-05 | BE | P0 | 5.1 | 06 §3; 09 §3.6; 06 §6 PAYLOAD_TOO_LARGE | PENDING_KYC rider | Upload 1,000,001 bytes; GIF; PDF; HTML renamed `.jpg`; a JPEG header followed by a script payload; 0 bytes; 3 MB body; unknown `doc_type`; PAN without `number` | 400 `VALIDATION_ERROR` (or 413 `PAYLOAD_TOO_LARGE` over 2.5 MB), never 500; nothing stored | ⬜ |
| P5-TC-06 | BE | P1 | 5.1 | 04 §5 note; 09 §4 Rider KYC | PENDING_KYC rider | Numbers: Aadhaar failing the Verhoeff check, PAN/DL/RC in the wrong format, then valid ones; `GET /rider/me/` | Invalid → 400. Valid → only the masked form (`XXXX XXXX 1234`) in every response; the full number is never returned to the rider | ⬜ |
| P5-TC-07 | BE | P0 | 5.1 | 09 §3.3 | Rider with documents and bank details | Read-only SQL on the document-number and bank-account columns | No plaintext Aadhaar, PAN or account number in any column (field-level encryption); the masked column agrees with the last 4 digits | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-08 | BE | P1 | 5.1 | 06 §3 (D-14 default) | PENDING_KYC rider | BICYCLE, then E_BIKE, then MOTORBIKE (PATCH `/rider/me/`); read `missing_documents` and `ready_for_review` | DL and RC required only for MOTORBIKE/SCOOTER; the lists recompute on every change | ⬜ |
| P5-TC-09 | BE | P1 | 5.1 | 04 §2.2, §5 note | PENDING_KYC rider | `PUT /rider/bank-account/`: 8- and 19-digit accounts, letters, lowercase or bad IFSC, then a valid one with and without a UPI ID | Invalid → 400. Valid → 200, account masked (last 4) in the response and in `/rider/me/` | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-10 | BE | P1 | 5.1 | 06 §3 | Rider with one PENDING and one APPROVED document | Upload a new copy of each | PENDING replaced (status PENDING, one current copy); APPROVED → 409, original kept | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-11 | BE | P0 | 5.1 | 06 §3; 09 §3.2 | PENDING_KYC rider, then ACTIVE R1 | PATCH `/rider/me/` with `status`, `home_store`, `cash_limit`, `cash_in_hand`, `is_online`, `rating_avg`; as ACTIVE, PATCH `full_name` and `vehicle_number` | Protected fields are never changed (SQL check). ACTIVE/SUSPENDED: only the emergency contact can change; other fields refused (400) or ignored, never stored (A: 06 does not say which) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-12 🔥 | ADM | P0 | 5.1 | 05 §2 Riders; 04 §2.2 | Rider with every required document and bank details | OPS in the Riders admin: approve each document, then approve the rider with home store QA-02. Also try approving a rider with one document missing or PENDING | ACTIVE, `home_store` QA-02, `cash_limit` 5,000.00 (`RIDER_DEFAULT_CASH_LIMIT`). One audit row per action (actor, IP, no free text). The incomplete rider is refused with the reason | ⬜ |
| P5-TC-13 | ADM | P1 | 5.1 | 06 §3 (#9); 04 §2.2 | PENDING_KYC rider | OPS rejects the rider with a reason (and once with an empty reason); the rider reads `/rider/me/`, then re-uploads the rejected document | Empty reason refused. REJECTED with `rejection_reason` shown; back to PENDING_KYC by itself once nothing required is missing or rejected | ⬜ |
| P5-TC-14 | ADM | P1 | 5.1 | 06 §3 (#25) | R2 offline; then R2 ON | OPS rejects R2's DL; R2 calls `shift/start`; R2 re-uploads, OPS approves; repeat with R2 online when the DL is rejected | Stays ACTIVE; `shift/start` → 409 `DOCUMENTS_NOT_APPROVED` with `doc_types` [DL]; online again after approval. Online variant: behaviour recorded against A18 (no new offers expected) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-15 | ADM | P0 | 5.1 | 05 §2 Riders; 06 §3 (5.3 notes "Going offline") | ON(R1) with OFR, ON(R2) | OPS suspends R1 with a reason; R1 calls `shift/start` and the records endpoints; OPS reinstates R1 | R1 offline (shift `end_reason` ADMIN, `ended_by` ops); offer withdrawn and R2 offered; `shift/start` → 403 `RIDER_NOT_ACTIVE`; records 200; reinstated rider can go online | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-16 | BE | P0 | 5.1–5.4 | 06 §3 Access | Users with no profile, PENDING_KYC, REJECTED, ACTIVE, SUSPENDED | Call me, documents, bank, shift, locations, heartbeat, offers, tasks, history, earnings, ledger and payouts as each | No profile → 403 `PERMISSION_DENIED` `details.rider_status` NONE (including `/rider/me/`). Not ACTIVE on shift/location/offer/task → 403 `details.reason` `RIDER_NOT_ACTIVE`. Records open in any status | ❌ BUG-0013 (xfail, still open at efb3c3d) |
| P5-TC-17 | BE | P2 | 5.1 | 06 §3 Rate limits | PENDING_KYC rider; QA Redis counters cleared | 31 document uploads in an hour; 21 register/bank writes | The 31st and 21st → 429 `RATE_LIMITED` with `retry_after_seconds` and `Retry-After` | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-18 | BE | P1 | 5.1 | 06 §3 Erasure; DL-57; 07 §4 | Spare-number rider with documents, bank and location history | Delete the account (grace period by driver), anonymise; then run `purge_offboarded_kyc` with `kyc_purge_after` in the past (driver) | Name, dob, emergency contact, vehicle number and bank blanked; location history and history rows deleted; `kyc_purge_after` = today + 365. After the purge the document rows and files are gone (old signed link fails) | ⬜ (needs a spare QA number, 01 §9.4) |
| P5-TC-19 | RID | P1 | 5.1 | 04 §2.2, §5 | Rider dev build against :8001, user's phone | Register → documents (camera, compressed ≤ 1 MB) → bank → status; ops rejects one document → re-upload | Screens bound to the real API; masked numbers only; no crash after Android kills the app while the camera is open | ⏭ device run (PM) |
| P5-TC-20 | BE | P1 | 5.1 | 09 §3.3; 06 §3 `/rider/me/` | R1 with a PHOTO document | Read `photo_url` and `photo_url_expires_at`; fetch the URL; fetch after expiry (profile with a short expiry, or a tampered signature) | Signed link valid ≤ 1 h; tampered or expired → denied. No rider response contains a public or permanent link to any KYC file | ✅ (efb3c3d, 2026-11-09) |

### 5.2 Shifts, location and heartbeat
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-21 🔥 | BE | P0 | 5.2 | 06 §3 Shift; 04 §2.3 | R1 offline | `shift/start` at the store; again | 200 `ShiftState` `is_online` true, `location` intervals; the repeat returns the same shift; one open shift in the DB | ⬜ [auto 5.3] |
| P5-TC-22 | BE | P1 | 5.2 | 06 §3 Shift | R1 offline | `shift/start` at 1,990 m and 2,010 m from the pin; lat/lng missing, out of range, or strings | ≤ 2,000 m → 200; beyond → 422 `OUTSIDE_GEOFENCE` with `distance_m`, `radius_m` 2000; bad input → 400 | ⬜ [auto 5.3] |
| P5-TC-23 | BE | P1 | 5.2 | 04 §2.3/§2.7; 06 §3 | R1 with `cash_in_hand` ≥ `cash_limit` (OPS lowers the limit, or after COD) | `shift/start`; `GET /rider/me/` | 200 with `prepaid_only` true; `cash.limit_reached` true | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-24 | BE | P0 | 5.2/5.3 | 06 §3 Shift; 5.3 notes | ON(R1) idle; then OFR; then ASG | `shift/end` in each state; a location batch after going offline | Idle → offline, shift `end_reason` MANUAL, `ended_by` rider; then locations → 409 `RIDER_OFFLINE`. OFR → offline and the offer withdrawn. ASG → 409 `ACTIVE_TASK`, still online | ⬜ [auto 5.3] |
| P5-TC-25 | BE | P1 | 5.2 | 06 §3 Location | ON(R1) | Batches of 1, 50, 51 and 0 points; a repeated `recorded_at` in the same batch and across batches; `recorded_at` −25 h, +3 min and +1 min; negative accuracy; lat 91 | `accepted`/`duplicates`/`rejected` exact; 0 or 51 points → 400; points outside −24 h/+2 min rejected and not stored; invalid values → 400 | ⬜ [auto 5.3] |
| P5-TC-26 | BE | P1 | 5.3 | 06 §3 (5.3 notes, `MOCKED_LOCATION`) | ON(R1) | A point with `is_mocked` true | Stored with `is_mocked`; ops alert `MOCKED_LOCATION` logged; rider not blocked (⚠ Jivo) | ⬜ |
| P5-TC-27 | BE | P1 | 5.2/5.3 | 06 §3 (heartbeat) | R1 offline / ON idle / OFR / ASG | `POST /rider/heartbeat/` in each state | `is_online`, `pending_offer_id`, `active_task_id` and `shift` match the state | ⬜ [auto 5.3] |
| P5-TC-28 | BE | P1 | 5.2 | 06 §3 Auto-offline (#42); 06 §5 | ON(R1); `rider_heartbeat_check` triggered by the driver with a shifted clock | (a) no point for 10+ min, no heartbeat; (b) a heartbeat within 10 min and the last point ≤ 30 min old; (c) a heartbeat but the last point > 30 min old; (d) R1 on an active task | (a) offline, AUTO_OFFLINE, `ended_by` system, pending offer withdrawn; (b) stays online; (c) offline; (d) stays online + ops alert `RIDER_STALE_ON_TASK` | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-29 | BE | P1 | 5.2/5.3 | 06 §3 Presence | ON(R1) | Send one point with `recorded_at` = now + 110 s, then nothing; dispatch an order 130 s later | Presence counts from the server's receipt time: R1 is not a candidate after 120 s (`DISPATCH_PING_MAX_AGE_SECONDS`) | ⬜ |
| P5-TC-30 | BE | P2 | 5.2 | 06 §3 Rate limits | ON(R1) | 7 location batches and 7 heartbeats in one minute | The 7th of each → 429 `RATE_LIMITED`, `Retry-After` | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-31 | ADM | P1 | 5.2 | 05 §1.4; 06 §3 (`shifts.force_offline`) | ON(R1) idle | OPS forces R1 offline; R1 sends a point | Shift ended ADMIN by ops; 409 `RIDER_OFFLINE`; audit row | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-32 | BE | P1 | 5.2 | 04 §3; 09 §4 DPDP | R1 offline | Send points while offline; count R1's location rows (read-only SQL) | 409 and no rows stored: tracking only while online | ⬜ [auto 5.3] |
| P5-TC-33 | RID | P1 | 5.2 | 04 §2.1, §2.3, §3 | Rider dev build, phone | Permissions gate order (disclosure before the first prompt), online toggle, the "You're online" notification, going offline stops tracking, the auto-offline message | As 04 §2.1/§3 | ⏭ device run (PM) |

### 5.3 Dispatch and offers
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-34 🔥 | E2E | P0 | 5.3 | 08 §5.3; 04 §2.4; 09 §1 | ON(R1) | A places COD(A); poll `GET /rider/offers/current/` every 0.5 s | Task SEARCHING → OFFERED. Offer fields: `store_name`, `drop_locality` only (no house, street, phone or coordinates), `distance_km`, `payment_type` COD, `cod_amount` = the order's `grand_total` (2-dp string), `estimated_payout`, `item_count`, `expires_at − offered_at` = 30 s, `server_time`. Seen within 3 s of ACCEPTED (local, remote DB noted) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-35 | BE | P0 | 5.3 | 08 §5.1 | ON(R1) as a control; R2 in one variant per run | R2 variants: offline; home store GGN-01; last point 130 s old; on another active task; holding a pending offer for another order; SUSPENDED. Then place COD(A) | R2 is never offered; R1 (or nobody → SEARCHING) is | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-36 | BE | P0 | 5.3 | 08 §5.1; 04 §2.7 | ON(R1) with `cash_in_hand` + order total above, equal to and below `cash_limit` (OPS sets the limit) | Place a COD order each time, then an ONLINE order | Above → R1 not offered (task SEARCHING); equal → offered; ONLINE → offered whatever the cash | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-37 | BE | P1 | 5.3 | 08 §5.2 | R1 and R2 online at chosen offsets | (a) R1 150 m, R2 1.2 km; (b) both ≤ 200 m, R2 idle longer (its last task ended earlier); (c) R1 900 m, R2 600 m | (a) R1; (b) R2 (longest idle; A6); (c) R2 (nearest) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-38 | BE | P1 | 5.3 | 08 §2.1 | ON(R1); `triggerplaced` profile for part 2 | 1: a COD order is PLACED and not yet accepted (auto-accept delay): no task. 2: profile `DISPATCH_TRIGGER=PLACED` | 1: task created only at ACCEPTED. 2: task and offer at PLACED | ⬜ |
| P5-TC-39 🔥 | BE | P0 | 5.3 | 08 §5.4; 04 §2.4; 09 §3.2 | OFR | R1 accepts; accepts again; reads `tasks/current/` and `offers/current/` | 200 `RiderTask` ASSIGNED with `assigned_at`; full `customer_address` (with the receiver's phone), instructions and items revealed only now; the offer is gone; the repeat → 200, same task; the order's status is not changed by the accept | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-40 | BE | P0 | 5.3 | 08 §5.5; 04 §2.4 | OFR; ON(R2) | R1 rejects with `TOO_FAR`; reject with an unknown reason; reject with no body | 204, offer REJECTED with the reason; R2 offered; R1 never re-offered this task; unknown reason → 400; no body → 204 | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-41 | BE | P0 | 5.3 | 08 §5.4–5; 06 §3 (5.3 notes) | OFR; ON(R2); QA worker running | Wait for expiry (30 s + up to 15 s sweep), then R1 accepts, then rejects | Offer EXPIRED and R2 offered; late accept → 409 `OFFER_EXPIRED`; late reject → 409 | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-42 | BE | P0 | 5.3 | 08 §5.4 | OFR | 10 trials: R1's accept sent in parallel with the driver's `expire_offer` at the expiry instant | Exactly one outcome per trial: (accept 200, offer ACCEPTED, task ASSIGNED) or (409 `OFFER_EXPIRED`, offer EXPIRED). Never ASSIGNED with an EXPIRED offer; ≤ 1 PENDING offer per task | ⬜ |
| P5-TC-43 | BE | P0 | 5.3 | 08 §5.4; 07 (5.3 constraints) | OFR | 10 parallel accepts by R1 | Every answer 200 (same task) or 409, never 500; one assignment; one active task for R1 | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-44 | BE | P0 | 5.3 | 08 T11, §5.4 | OFR | A cancels (T11) in parallel with R1's accept | Either (cancel 200, accept 409 `OFFER_TAKEN`, task CANCELLED) or (accept 200, then task CANCELLED, R1 freed, `recent_task` CANCELLED). Never an ASSIGNED task on a CANCELLED order | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-45 | BE | P0 | 5.3 | 08 §5.7; 06 §3 (5.3 notes) | OFR; ON(R2) | OPS manual-assigns R2 in parallel with R1's accept | One rider bound; the loser gets 409 (`OFFER_TAKEN` or `INVALID_STATE_TRANSITION`); no PENDING offer left | ⬜ |
| P5-TC-46 | BE | P1 | 5.3 | 06 §3 (5.3 notes) | OFR; ON(R2) | R1 goes offline, then accepts | Offer withdrawn when going offline; accept → 409 `OFFER_TAKEN` (or `RIDER_OFFLINE`); R2 offered | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-47 | BE | P1 | 5.3 | 08 §5.6 | `dispatchfast` profile; ON(R1) only | R1 lets every offer expire; watch the task through the give-up and the pause | After `MAX_OFFER_ATTEMPTS` (5) offers or `DISPATCH_TIMEOUT_SECONDS`: UNASSIGNED with `unassigned_at`, ops alert `DISPATCH_UNASSIGNED`; after the pause a new round (SEARCHING). R1 is not re-offered (already offered this task): behaviour recorded against A15 | ⬜ |
| P5-TC-48 | BE | P1 | 5.3 | 08 §5.1; 06 §5 `dispatch_sweep` | No rider online | Place COD(A); 20 s later R1 goes online | Task SEARCHING; offered to R1 within `DISPATCH_RETRY_SECONDS` (15) + the sweep | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-49 | BE | P1 | 5.3 | 08 T11/T12, §9; 04 §2.4 | (a) OFR; (b) ASG (order ACCEPTED); (c) ATS + PKD | (a) A cancels; (b) A cancels; (c) OPS cancels (T12) | Offer WITHDRAWN (`offers/current` empty) or task CANCELLED with `cancelled_at`; `recent_task` shows CANCELLED for `RIDER_RECENT_TASK_SECONDS`; R1 freed (gets the next offer); notifications `rider.offer_withdrawn` / `rider.task_cancelled` recorded | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-50 | BE | P1 | 5.3 | 08 T8 | (a) ASG; (b) a task SEARCHING with its next retry in the future | OPS: start packing, mark packed | (a) `ready_for_pickup` true, notification `rider.order_ready`; (b) dispatch runs at once (offer without waiting for the retry) | ⬜ |
| P5-TC-51 | BE | P0 | 5.3 | 08 T8a, §6.3 | COD(A) of 2 × JV-SUN-1L, ASG | OPS marks 1 unit unavailable; R1 reads the task; later delivers with the old amount | `cod_amount_due` = the new `grand_total` (QA oracle), `cod_amount_previous` = the old one; notification `rider.cod_amount_changed`; delivering with the old amount → 400 | ⬜ |
| P5-TC-52 | BE | P1 | 5.3 | D-16 default; 06 §3 (5.3 notes) | OFR | Read `estimated_payout` and `distance_km` on the offer and the task | `estimated_payout` = 30.00 + 5.00 × `distance_km` (QA oracle, 2 dp, half-up); both 2-dp strings, never floats; `distance_km` = store-to-drop distance, not the GPS trail | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-53 | BE | P0 | 5.3 | 08 §5.1 (v1 one order at a time) | ON(R1) only | Place two COD orders (A, B) a second apart | R1 offered one; the other stays SEARCHING until R1 is free; never two PENDING offers or two active tasks for R1 (SQL) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-54 🔥 | ADM | P0 | 5.3/5.4 | 08 §5.7; 05 §1.4 | A task SEARCHING or UNASSIGNED; ON(R2) idle | OPS manual-assigns R2 (console in 5.4; service until then) | ASSIGNED at once, `assignment_mode` MANUAL; R2's `tasks/current` shows it; notification `rider.task_assigned`; any pending offer of R2 withdrawn; audit `delivery.manual_assign` with IP | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-55 | ADM | P0 | 5.3/5.4 | 06 §3 (5.3 notes); 08 §5.1 | As TC-54 | Manual assign of: an offline rider; a busy rider; a GGN-01 rider; R2 whose cash + COD total > limit; an order that already has a rider; a DELIVERED or CANCELLED order | Refused ("offline", "on another delivery", "active rider of this store"); 422 `CASH_LIMIT_EXCEEDED`; 409 `INVALID_STATE_TRANSITION`; nothing changes | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-56 | ADM | P0 | 5.3/5.4 | 08 §3 Reassignment | (a) ASG; (b) ATS with 3 wrong pickup codes; (c) OFD | OPS unassigns | (a, b) task SEARCHING, rider cleared, R1 freed (`tasks/current` empty), pickup attempts reset, offered to others (not R1); notification `rider.task_cancelled` to R1; audit. (c) 409, nothing changes | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-57 | ADM | P1 | 5.3/5.4 | 08 §5.6 | (a) UNASSIGNED; (b) ASG | OPS retries dispatch | (a) SEARCHING, new round, audit; (b) 409 | ⬜ |
| P5-TC-58 | BE | P2 | 5.3 | 09 §1 (A21) | ON(R1) | 10 runs: ACCEPTED time (history) → offer `offered_at` → first successful poll | p95 of dispatch decision → offer < 3 s (server side); poll latency recorded; FCM/WS end to end in P6 | ⬜ |

### 5.3 Pickup and T9 (stock commit)
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-59 | BE | P1 | 5.3 | 04 §2.5; 06 §3 (A20) | ASG | `arrived-store` at 150 m; at 240 m with accuracy 50; at 260 m with accuracy 50; at 400 m; repeat after success; from OFR and from OFD | ≤ 200 m + min(accuracy, 50) → AT_STORE, `arrived_store_at` set; outside → 422 `OUTSIDE_GEOFENCE` with `distance_m`, `radius_m`; repeat → 200; wrong state → 409 | ⬜ [auto 5.3] |
| P5-TC-60 🔥 | BE | P0 | 5.3 | 08 T9, §6.1 | ATS + PKD; stock and reservations read before (SQL) | Pickup with the 4-character code | 200 PICKED_UP, order OUT_FOR_DELIVERY, `picked_up_at`. Per line: `on_hand` −q and `reserved` −q; one `StockMovement` SALE linked to the order; reservations COMMITTED. History PACKED → OUT_FOR_DELIVERY, actor rider. A 4-digit OTP appears on the customer's `track`; notification `order.out_for_delivery` | ⬜ [auto 5.3] |
| P5-TC-61 | BE | P0 | 5.3 | 06 §3 (bag QR); A11 | ATS + PKD | Pickup with `JQC1:<order_number>:<code>`; the QR of another QA order; the right code with the wrong number; the lower-case code; the code with spaces around it | Correct QR, lower case and trimmed → 200 (case-insensitive). Mismatches → 400 `PICKUP_CODE_INVALID` with `attempts_remaining` counting down | ⬜ [auto 5.3] |
| P5-TC-62 | BE | P0 | 5.3 | 08 T9 guards; 06 §6 | (a) ATS, order ACCEPTED or PACKING; (b) ASG + PKD; (c) ATS + PKD | (a, b) pickup with the right code; (c) pickup with `ＡＢＣＤ`, `١٢٣٤`, a 3-character code and a 50-character code | (a) 409 `INVALID_STATE_TRANSITION`, `ready_for_pickup` false; (b) 409; (c) 400 `PICKUP_CODE_INVALID` with no attempt used. Stock unchanged in every case | ⬜ [auto 5.3] |
| P5-TC-63 | BE | P0 | 5.3/5.4 | 06 §6 `PICKUP_CODE_LOCKED` | ATS + PKD | 5 wrong codes, then the right one; OPS unassigns and re-assigns R1 (5.3) or unlocks (5.4) | `attempts_remaining` 4, 3, 2, 1, then 423 `PICKUP_CODE_LOCKED` (0) + ops alert; the right code → 423; after reassignment or unlock the right code → 200 | ⬜ [auto 5.3] (lock part) |
| P5-TC-64 | BE | P1 | 5.3 | 06 §3 Rate limits (`RIDER_PICKUP_RATE`) | ATS | 11 pickup calls in one minute (wrong-shape codes, so the lock is not reached) | The 11th → 429 `RATE_LIMITED`, `Retry-After` | ⬜ |
| P5-TC-65 | BE | P0 | 5.3 | 08 T9, §6.1 | ATS + PKD | 5 parallel pickups with the right code | Each 200 (idempotent) or 409, never 500; exactly one SALE movement per line, one T9 history row; `on_hand` decremented once | ⬜ [auto 5.3] |
| P5-TC-66 🔥 | BE | P0 | 5.3 | 08 §6.1; 07 §3 | After every 5.3 run (read-only SQL) | Stock invariants on QA-02 | `on_hand` ≥ 0, `reserved` ≥ 0; `reserved` = Σ ACTIVE reservations per (store, variant); Σ SALE per OUT_FOR_DELIVERY/DELIVERED order = the units delivered; no SALE for CANCELLED orders | ✅ (efb3c3d, 2026-11-09) |

### 5.3 Arrival, delivery OTP and T10
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-67 | BE | P1 | 5.3 | 04 §2.6; 06 §3 | OFD | `arrived-customer` at 150 m from the drop; at 600 m with no override; at 600 m with override "gate locked"; override of spaces only; from ATS | AT_CUSTOMER + notification `order.rider_arrived`; 600 m without override → 422; with override → 200 and the reason stored; spaces only → 422; wrong state → 409 | ⬜ [auto 5.3] |
| P5-TC-68 🔥 | BE | P0 | 5.3 | 08 T10 | ONL(A), ATC | Deliver with the right OTP (read from A's `track`) | 200 DELIVERED with `delivered_at`; order DELIVERED, history T10 actor rider; `can_download_invoice` true and the invoice generated (`GET /invoice/` 200, or 503 when WeasyPrint is missing here); R1 freed; `recent_task` DELIVERED | ⬜ [auto 5.3] |
| P5-TC-69 🔥 | BE | P0 | 5.3 | 08 T10; 04 §2.6/§2.7 | COD(A), ATC | Deliver with the OTP and `cod: {mode: cash, amount: <cod_amount_due>}` | 200; `payment_status` COD_COLLECTED; one `RiderCashLedger` COD_COLLECTED row of +due with `balance_after` = previous + due; `/rider/me` `cash.cash_in_hand` updated | ⬜ [auto 5.3] |
| P5-TC-70 | BE | P0 | 5.3 | 06 §3 deliver; 08 T10 note | COD(A), ATC | Deliver with the right OTP and: due − 0.01; due + 0.01; `"249"` for `"249.00"`; the number 249; `"249.000"`; `"-249.00"`; `"1e2"`; no `cod`; `mode: upi` (before 5.4). Also a prepaid task with `cod` | Mismatch → 400 `VALIDATION_ERROR` (`details.cod`) and `attempts_remaining` **unchanged**. Equal value in another format: accepted or 400, recorded (exact-match rule). UPI before 5.4 → 400. Prepaid with `cod` → 400 | ⬜ [auto 5.3] |
| P5-TC-71 🔥 | BE | P0 | 5.3 | 04 §2.6; 06 §3 (5.3 notes); A12 | ATC | 4 wrong OTPs, a 5th wrong one, then the right one; re-read the task; repeat `arrived-customer` | 400 `DELIVERY_OTP_INVALID` with `attempts_remaining` 4, 3, 2, 1; the 5th → 423 `DELIVERY_OTP_LOCKED` (0) + ops alert `DELIVERY_OTP_LOCKED`; the right OTP → 423; `delivery_otp.locked` true; nothing the rider does resets it | ⬜ [auto 5.3] |
| P5-TC-72 | BE | P0 | 5.3 | 09 §3.1 spirit; 08 T10 | ATC (fresh task) | 20 parallel wrong OTPs, then the right one | At most 4 × 400 and the rest 423; `otp_attempts` never above 5 (SQL); the right OTP afterwards → 423. No race gives extra guesses | ⬜ [auto 5.3] |
| P5-TC-73 | BE | P1 | 5.3 | 06 §3; A12 | ATC | OTP `""`, `"123"`, `"12345"`, `"abcd"`, `"١٢٣٤"`, `" 1234 "` | 400 `VALIDATION_ERROR` or counted as a wrong OTP (A12), recorded; never 500 | ⬜ [auto 5.3] |
| P5-TC-74 | BE | P1 | 5.3 | 08 T10 | (a) OFD, not arrived; (b) ATS; (c) DELIVERED | Deliver with the right OTP | (a, b) 409; (c) 200 (idempotent), no second ledger row or earning | ⬜ [auto 5.3] |
| P5-TC-75 | BE | P0 | 5.3 | 08 T10; 07 (one COD_COLLECTED per order) | COD(A), ATC | 5 parallel delivers with the right OTP and amount | One DELIVERED history row; one ledger row; `cash_in_hand` + due once | ⬜ [auto 5.3] |
| P5-TC-76 | BE | P0 | 5.3 | DL-56; 06 track | After TC-68/69 | A reads `track` | `rider.phone` null, `delivery_otp` null, `eta_at` null, status DELIVERED | ⬜ [auto 5.3] |
| P5-TC-77 | E2E | P1 | 5.3 | 06 §2.6 invoice; carries P4-TC-16/17/57 | A DELIVERED order of A | A reads the invoice; waits past `INVOICE_URL_EXPIRY_SECONDS`; B asks for it | `invoice_number` `<prefix>/<FY>/<6 digits>`; signed link valid 600 s, then refused; B → 404. (503 here if WeasyPrint is missing: render check on staging) | ⬜ |

### 5.3 Failed and returned deliveries (T13, T14)
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-78 🔥 | BE | P0 | 5.3 | 08 T13, §6.4; 08 5.3 notes | ONL(A), ATC | Fail with `CUSTOMER_REFUSED`; then R1 tries `shift/end` | 200: task RETURNING, `failed_at`, `fail_reason`; order DELIVERY_FAILED, history T13 actor rider. One refund, reason DELIVERY_FAILED, key `failed:<order>`, amount = refundable − delivery fee (QA oracle); customer notification; ops alert. `shift/end` → 409 `ACTIVE_TASK` | ⬜ [auto 5.3] |
| P5-TC-79 | BE | P0 | 5.3 | 08 T13; 06 §3 fail; A13 | ONL(A); `riderclock` profile for the last step | `CUSTOMER_NOT_REACHABLE` with `call_attempts` 1; with 2 inside the wait; from OFD (not arrived); with 2 after the wait | 400 (`call_attempts`); 409 `WAIT_NOT_ELAPSED` with `not_reachable_after`; 409; 200, and the refund keeps the delivery fee | ⬜ [auto 5.3] (first three) |
| P5-TC-80 | BE | P0 | 5.3 | 08 §6.4; A14 | ONL(A), ATC | Fail with `WRONG_ADDRESS`; another order with `OTHER` and a note; `OTHER` without a note | Full refund (everything refundable). `OTHER` without a note: 400, or accepted (04 says the app requires a note), recorded | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-81 | BE | P0 | 5.3 | 08 §6.4; 5.3 notes | COD(A), ATC | Fail with `CUSTOMER_REFUSED` | `payment_status` FAILED; no ledger row; no refund | ⬜ [auto 5.3] |
| P5-TC-82 | BE | P1 | 5.3 | 08 §6.4; `COD_BLOCK_AFTER_REFUSALS` (2); A14 | A spare QA customer with 1 refused COD order | Second refused COD delivery; then the customer places COD; OPS unblocks (`set_cod_blocked`) | COD-blocked: 422 `COD_NOT_AVAILABLE`; after unblocking, COD works again | ⬜ (needs a spare QA number, 01 §9.4) |
| P5-TC-83 | BE | P0 | 5.3 | 08 §6.4; 06 §2.6 refunds | ONL(A), ATC | Fail, then fail again; on another order, 3 parallel fails | Repeats → 200, same task; exactly one refund row (`failed:<order>`) and one T13 history row | ⬜ [auto 5.3] |
| P5-TC-84 | BE | P1 | 5.3 | 04 §2.6; 09 §3.6 | ATC | Fail with a photo: JPEG 800 KB with EXIF; PNG; PDF; 6 MB | Image stored in the private bucket, re-encoded without EXIF (staff view); PDF → 400; 6 MB → 400/413; no public link | ⬜ |
| P5-TC-85 🔥 | ADM | P0 | 5.3 | 08 T14, §6.1 | RET (2 lines); stock read before | OPS (packing console in 5.4, service until then) receives the return with no damage | Order RETURNED, task RETURNED with `returned_at`; history T14; per line a RETURN movement and `on_hand` += q; R1 freed (`tasks/current` empty, `shift/end` 200); audit | ⬜ [auto 5.3] |
| P5-TC-86 | ADM | P0 | 5.3 | 08 T14; 08 5.3 note | RET | Receive with `damaged {line: 1}`; then attempts with damaged > units, an unknown line, −1, `true` | That line: RETURN q + DAMAGE 1 (net `on_hand` += q − 1). Invalid inputs refused and nothing changes | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-87 | ADM | P1 | 5.3 | 08 T14 guards | OFD; RET received once | Receive while OFD; receive the same return twice | Refused (state message); the second call adds no movement | ⬜ [auto 5.3] |

### 5.4 COD UPI QR, cash, earnings, payouts, history and ops actions
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-88 | BE | P0 | 5.4 | 04 §2.6; 06 §3 cod-qr; A17 | COD(A), ATC; also a prepaid ATC and a COD OFD | `POST /tasks/{id}/cod-qr/`; repeat | 200 `CodQr {qr_id, image_url (https), amount = cod_amount_due, status PENDING, expires_at}`; the repeat returns the open QR (A17). Prepaid → 409; not yet arrived → 409 (A17) | ❌ (efb3c3d, 2026-11-09; 2 tests failed, cause not analysed: run stopped for PC shutdown) |
| P5-TC-89 | BE | P0 | 5.4 | 04 §2.6; 08 T10 | TC-88 QR | Simulate the QR payment (fake gateway, signed); poll `tasks/current`; deliver with `mode: upi` and the amount | `cod_qr.status` PAID; deliver → DELIVERED; **no** cash-ledger row; one payment recorded; `payment_status` as the 5.4 contract (A17) | ❌ (efb3c3d, 2026-11-09; 2 tests failed, cause not analysed: run stopped for PC shutdown) |
| P5-TC-90 | BE | P0 | 5.4 | 08 §4 rule 2; 09 §3.4 | TC-88 QR | Replay the QR-payment event 3 times and 3 in parallel; a payment of a different amount | One payment (duplicates answered `duplicate`); a wrong amount does not mark the QR PAID and is refunded | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-91 | BE | P0 | 5.4 | 06 §3 ("A QR paid after cash was taken is refunded automatically") | COD(A) with an open QR | Deliver with cash; then the QR payment arrives | The QR payment is refunded in full; the ledger has only the cash row; the customer pays once | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-92 | BE | P1 | 5.4 | 08 T8a; 04 §2.6; A17 | COD(A) of 2 units reduced by T8a before pickup (as TC-51), then OFD and ATC; a second order whose QR is left unpaid past `expires_at`, and one whose task is then failed | Generate the QR on the first; wait out the second's expiry and pay it late; fail the third and pay its QR | First: QR amount = the new due (not the offer's `cod_amount`). Expired or failed-task QR: status EXPIRED/CANCELLED, and a late payment to it is refunded, never counted as collected | ⬜ 5.4 |
| P5-TC-93 🔥 | ADM | P0 | 5.4 | 06 §6 `PICKUP_CODE_LOCKED`; 08 5.3 note (T10); A3 | OTP locked (TC-71); pickup locked (TC-63) | OPS unlocks each | Attempts reset, `locked` false; R1 completes with the right code or OTP; audit; roles per TC-117 | ❌ (efb3c3d, 2026-11-09; test_p5_cash tc93 failed, cause not analysed; console variants not reached) |
| P5-TC-94 | BE | P0 | 5.4 | 04 §2.7; 06 §3 (#21, #24) | R1 after 2 COD deliveries and 1 deposit | `GET /rider/cash/ledger/` with `before_id` paging; `GET /rider/me/` | COD_COLLECTED rows (order number) and DEPOSIT rows (negative) with running `balance_after`; `next` carries `before_id`, `previous` null; `cash.cash_in_hand` = the latest balance; `limit_reached` at ≥ limit; 2-dp strings | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-95 🔥 | ADM | P0 | 5.4 | 05 §1.5; 04 §2.7 | R1 with cash 498.00 | SMQ records a deposit of 498.00 at `/ops/cash/` | Ledger DEPOSIT −498.00, balance 0.00; R1 sees it at once; audit | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-96 | ADM | P0 | 5.4 | 05 §1.5; 08 §6 money rules | R1 with cash 498.00 | Deposits of 498.01, 0, −5, 1.005, "abc"; a GGN-01 rider; the same form posted twice | All refused except the valid one; the balance never goes negative; a double post → one entry | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-97 | ADM | P1 | 5.4 | 05 §1.5 | Several COD deliveries and deposits today | Day-end report for QA-02 | Collected, deposited and the difference per rider agree with a SQL oracle | ⬜ 5.4 |
| P5-TC-98 🔥 | BE | P0 | 5.3/5.4 | 07 (RiderCashLedger append-only; one COD_COLLECTED per order) | After every run (read-only SQL) | Ledger invariants | No row ever updated (balance chain consistent in id order); one COD_COLLECTED per order; `cash_in_hand` = the last `balance_after` = Σ amount; never negative | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-99 | BE | P1 | 5.4 | 04 §2.8; 06 §3 Earnings (#19); D-16 | R1 with deliveries today, one with a tip | `GET /rider/earnings/` for today, this week and a range; `from` > `to`; a range over 366 days; bad dates | One line per delivered task: 30.00 + 5.00 × km + tip (QA oracle; A16); totals = Σ lines; IST dates inclusive; invalid ranges → 400; > 200 orders → `orders_truncated` | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-100 | BE | P1 | 5.4 | A16; A22 | A failed+returned task and a task cancelled after ASSIGNED | Earnings for that day | Behaviour recorded against A16/A22 (expected: no earnings) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-101 | BE | P1 | 5.4 | 04 §2.8; 09 §3.2; A8 | R1 with delivered, failed, returned and cancelled tasks | `GET /rider/tasks/history/` with `before_id` paging | Newest first; a task cancelled before pickup has no distance or payout; **no customer phone or full address** (locality at most) | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-102 | ADM | P1 | 5.4 | 05 §2 (Rider earnings & payouts); 04 §2.8 | Earnings for R1 | FIN creates a payout batch and marks it paid with a reference; R1 reads `/rider/payouts/` (page numbers) | Period, amount, status and reference shown; amounts agree with the earnings | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-103 | BE | P1 | 5.4 | 06 §3 Access | R1 SUSPENDED; a PENDING_KYC rider | Read history, earnings, ledger and payouts | 200 in any status | ⬜ 5.4 |

### IDOR (every rider object, plus tracking)
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-104 🔥 | BE | P0 | 5.3 | 09 §3.2; 06 §3 Access | OFR (offer O1 to R1); R2 ACTIVE | R2 accepts and rejects O1 | 404 `NOT_FOUND`; O1 still PENDING | ⬜ [auto 5.3] |
| P5-TC-105 🔥 | BE | P0 | 5.3/5.4 | 09 §3.2 | R1's task T1 in ASG, ATS + PKD, OFD and ATC | R2 calls arrived-store, pickup (right code), arrived-customer, cod-qr, deliver (right OTP) and fail on T1 | 404 each; T1 unchanged; R2's calls do not count against T1's pickup or OTP limits | ⬜ [auto 5.3] |
| P5-TC-106 | BE | P0 | 5.3 | 09 §3.2 | R1 with an offer and a task; R2 | R2 sweeps offer and task ids ±50 around R1's | Only R2's own ids answer non-404; the 404 body is identical for missing ids and other riders' ids; R2's `tasks/current` never shows R1's task | ⬜ [auto 5.3] |
| P5-TC-107 | BE | P0 | 5.3 | 06 §3 Access | OFR; customer A (no rider profile) | A calls the rider endpoints, including accept on O1 | 403 `PERMISSION_DENIED` `rider_status` NONE; O1 unchanged | ⬜ [auto 5.3] |
| P5-TC-108 🔥 | BE | P0 | 5.3 | 06 track; DL-56; 09 §3.2 | ONL(A) at OFD with R1 | B reads A's `track`; R1 (the delivering rider, not the owner) reads it | 404 for both; no rider phone or OTP leaks | ⬜ [auto 5.3] |
| P5-TC-109 | BE | P0 | 5.4 | 09 §3.2 | R1 and R2 with records | R2 reads history, ledger, earnings and payouts with `rider_id=<R1>` and with `before_id` taken from R1's rows | Only R2's rows; a foreign `before_id` reveals nothing of R1's | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-110 | BE | P0 | 5.1/5.3 | 09 §3.3 | R1's `photo_url`, a document link and a failure photo | R2 and customer A use them; change the key in the link | Signed links work only as issued and expire; no endpoint returns another rider's documents or photos | ⬜ |

### Role matrix for the ops actions (05 §3)
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-111 🔥 | ADM | P0 | 5.1 | 05 §3 "Rider approval / suspend"; 06 §3 staff services | A PENDING_KYC rider; R2 | Each role: approve/reject a document, approve/reject the rider, suspend/reinstate, set home store, set cash limit (admin pages and POSTs) | SA ✔, OPS ✔. SM: views its own store's riders only, no actions; another store's rider → 404. SS, CAT, SUP, FIN: no access (403 or not listed). Every ✔ audited | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-112 | ADM | P0 | 5.1 | 09 §3.3; 06 §3 (`document_file_url`, `document_number`) | Rider with documents | Each role opens a KYC file and reveals a full number | SA and OPS only, each view audited; everyone else refused | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-113 🔥 | ADM | P0 | 5.3/5.4 | 05 §3 "Manual dispatch"; 06 §3 (5.3 ops services) | A QA-02 task SEARCHING; ON(R2) | Each role: manual assign, unassign, retry dispatch | SA ✔, OPS ✔, SMQ ✔ (own store); SM (GGN-01) → not found; SS, CAT, SUP, FIN refused. Audited | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-114 🔥 | ADM | P0 | 5.4 | 05 §3 "Cash deposit entry"; A4 | R1 with cash | Each role: record a deposit; open the day-end report | Record: SA ✔, SMQ ✔ (own store); SM (GGN-01) refused for a QA-02 rider; OPS refused (A4); FIN view only; SS, CAT, SUP refused | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-115 | ADM | P0 | 5.4 | 05 §3 "Payouts" | Earnings exist | Each role: create a payout batch, mark it paid | SA ✔, FIN ✔; everyone else refused | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-116 | ADM | P1 | 5.3/5.4 | 08 T14; 05 §1.3 "Returns"; A2 | RET at QA-02 | Each role receives the return | SA, OPS, SMQ ✔; SS of GGN-01 and SM of GGN-01 → not found (other store); CAT, SUP, FIN refused | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-117 | ADM | P1 | 5.2/5.4 | A4 | R1 online; OTP-locked task | Each role: force offline; unlock OTP/pickup; set cash limit | Recorded per role and compared with the A4 working assumption (SA/OPS for force offline and cash limit; the Manual dispatch roles for unlock) | ⬜ 5.4 |
| P5-TC-118 | ADM | P1 | 5.4 | 05 §1.4; 05 §3 Customers (PII); 05 §5 | Riders online | Each role opens `/ops/riders/map/` and the rider list; a POST without the CSRF token | SA and OPS: all stores; SMQ: QA-02 only; others refused. Customer phones masked for store roles; no POST works without CSRF (403); audit rows carry actor and IP, no free text | ⬜ 5.4 |

### Customer tracking and OTP visibility
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-119 🔥 | BE | P0 | 5.3 | DL-56; 06 §3 track (#28, #33); 08 §9 | ONL(A) through every state | A reads `track` at SEARCHING, OFR, ASG, ATS, OFD and ATC | `rider` null until ASG. ASG/ATS: `rider {name "First L.", phone null, photo https or null, lat, lng, updated_at}`, `delivery_otp` null. OFD/ATC: `rider.phone` = R1's phone, `delivery_otp` = the 4-digit OTP that `deliver` accepts. Strict schema | ⬜ [auto 5.3] |
| P5-TC-120 | BE | P0 | 5.3 | DL-56 | Orders ending DELIVERED, DELIVERY_FAILED, RETURNED and CANCELLED (after ASG) | A reads `track` | `rider.phone` null and `delivery_otp` null in all four; `eta_at` null once finished | ⬜ [auto 5.3] |
| P5-TC-121 | BE | P0 | 5.3 | DL-56; 09 §3.3 (PII in logs); A7 | OFD | Look for the OTP value in: order detail and list; R1's task, offers and heartbeat; the ops-alert log lines and the instance log; A's notification inbox after DELIVERED | The OTP value appears only in A's `track` (OFD) and A's T9 notification. R1's task has only `{length, attempts_remaining, locked}`; nothing in the logs. Inbox after delivery recorded (A7) | ⬜ [auto 5.3] (API part) |
| P5-TC-122 | BE | P1 | 5.3 | 09 §1 (< 5 s); A9 | OFD | R1 sends a point; A polls `track` | `rider.lat/lng/updated_at` reflect the new point within 5 s (local indication); after DELIVERED no rider location is returned | ⬜ [auto 5.3] |
| P5-TC-123 | BE | P1 | 5.3 | 04 §2.4; 06 track | OFR, ASG | Compare what each side sees | Before accept the rider sees only the locality; the customer never sees the rider's full surname | ⬜ [auto 5.3] |
| P5-TC-124 | CUS | P1 | 5.3 | 03 tracking; DL-56 | Customer dev build, phone | Tracking screen through ASG → OFD → DELIVERED with the socket down | Rider name, call button and OTP card only while OUT_FOR_DELIVERY; polling fallback; no crash | ⏭ device run (PM) |

### End to end, data integrity and non-functional
| ID | Area | Pri | Slice | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P5-TC-125 🔥 | E2E | P0 | 5.3 | 08 §1–§3, §6.1 | ON(R1) | ONLINE: place → pay → auto-accept → offer → accept → arrive at store → OPS pack → pickup → arrive → deliver, all through the API | Statuses and history T3, T6, T7, T8, T9, T10 in order; bill unchanged (oracle); stock reserved, then committed; invoice; R1 free again | ⬜ [auto 5.3] |
| P5-TC-126 🔥 | E2E | P0 | 5.3/5.4 | 08 T10; 05 §1.5 | ON(R1) | COD end to end with cash; then a deposit of the whole balance | COD_COLLECTED; ledger back to 0.00 after the deposit | ⬜ [auto 5.3] (to T10) |
| P5-TC-127 | E2E | P1 | 5.3 | 08 T13, T14, §6.4 | ON(R1); QA worker | ONLINE → fail (refused) → return received; the worker settles the refund | `payment_status` PARTIALLY_REFUNDED (delivery fee kept) after `refund.processed`; stock restored; R1 freed | ⬜ [auto 5.3] |
| P5-TC-128 🔥 | BE | P0 | 5.3 | 08 §1, §3; 07 (5.3 constraints) | After every run (read-only SQL) | Delivery invariants | ≤ 1 active task per rider; ≤ 1 PENDING offer per task and per rider; DELIVERED order ⇔ DELIVERED task; OUT_FOR_DELIVERY ⇔ PICKED_UP/AT_CUSTOMER; DELIVERY_FAILED ⇔ RETURNING; RETURNED ⇔ RETURNED; a CANCELLED order has no task or a CANCELLED one; every task from ASSIGNED on has a rider | ✅ (efb3c3d, 2026-11-09) |
| P5-TC-129 | BE | P1 | 5.3 | 10 §2 (API tests) | Rider token | Schemathesis on the rider operations (low example count) | No 500; responses schema-valid | ⬜ |
| P5-TC-130 | BE | P1 | 5.3 | 06 §6 | — | Every rider endpoint with no token, a bad token, `X-App-Version` below the minimum (read-only check of the current minimum) and a wrong method | 401 `AUTH_REQUIRED` / `TOKEN_INVALID`; 405 envelope; codes in `ErrorCodeEnum` | ⬜ [auto 5.3] |
| P5-TC-131 🔥 | RID | P0 | 5.3/5.4 | 04 §1, §2.4–§2.7 | Rider dev build on the user's phone against :8001 (PM), GPX route | Prepaid, COD cash, COD UPI and failed → return, with the app killed and restored mid-task | Every step matches the server; restored to the right step; no crash | ⏭ device run (PM) |
| P5-TC-132 | E2E | P1 | P6 | 06 §4; 08 §9; 09 §1 | Firebase project (D-19); rider socket | Offer by FCM and `/ws/v1/rider/`; `offer.withdrawn`; `task.updated` | Delivered < 3 s; the app follows the payload keys of 06 §4.3 | ⏭ P6 / D-19 |

### Totals (Phase 5, stage 1 design, 2026-11-05)
| By section | Cases | 🔥 | Pri P0 | Pri P1 | Pri P2 | `[auto 5.3]` | ⏭ |
|---|---|---|---|---|---|---|---|
| 5.1 KYC and onboarding | 20 | 2 | 8 | 11 | 1 | 0 | 1 |
| 5.2 Shifts, location and heartbeat | 13 | 1 | 2 | 10 | 1 | 6 | 1 |
| 5.3 Dispatch and offers | 25 | 3 | 15 | 9 | 1 | 13 | 0 |
| 5.3 Pickup and T9 (stock commit) | 8 | 2 | 6 | 2 | 0 | 7 | 0 |
| 5.3 Arrival, delivery OTP and T10 | 11 | 3 | 7 | 4 | 0 | 10 | 0 |
| 5.3 Failed and returned deliveries (T13, T14) | 10 | 2 | 7 | 3 | 0 | 6 | 0 |
| 5.4 COD UPI QR, cash, earnings, payouts, history and ops actions | 16 | 3 | 9 | 7 | 0 | 1 | 0 |
| IDOR (every rider object, plus tracking) | 7 | 3 | 7 | 0 | 0 | 5 | 0 |
| Role matrix for the ops actions (05 §3) | 8 | 3 | 5 | 3 | 0 | 0 | 0 |
| Customer tracking and OTP visibility | 6 | 1 | 3 | 3 | 0 | 5 | 1 |
| End to end, data integrity and non-functional | 8 | 4 | 4 | 4 | 0 | 5 | 2 |
| **Total** | **132** | **27** | **73** | **56** | **3** | **58** | **5** |

| By area | Cases | 🔥 | Pri P0 | Pri P1 | Pri P2 |
|---|---|---|---|---|---|
| BE | 97 | 15 | 54 | 40 | 3 |
| ADM | 25 | 8 | 15 | 10 | 0 |
| RID | 3 | 1 | 1 | 2 | 0 |
| E2E | 6 | 3 | 3 | 3 | 0 |
| CUS | 1 | 0 | 0 | 1 | 0 |

None executed: 127 ⬜ and 5 ⏭ (TC-19, TC-33, TC-124, TC-131, TC-132: device run or P6/D-19). Slice split: 5.4-only cases are marked `⬜ 5.4`.

## Phase 6: Real-time and notifications (written 2026-11-06, stage 1: T-611 on develop `8f87d7b`)
Plan, environment and ambiguities: `01-test-plan.md` §10. Automated cases are `test_p6_tcNN_*` in `qa/tests/test_p6_ws.py`. **Task** = the tracker task that delivers the behaviour; T-612/613/614 cases are ⏭ until they land.

**Shorthands:** A, B, E = QA customers (`…101`, `…102`, `…105`); R1 = QA rider (`…103`, ACTIVE at QA-02); SA/OPS/SM/SS/CAT/SUP/FIN = seeded staff (SM and SS are GGN-01 only); `WS(path)` = a socket on the QA instance; "auth" = the first message `{"type":"auth","token":<access>}`.

### Order socket `/ws/v1/orders/{id}/` (06 §4.1)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-01 🔥 | BE | P0 | T-611 | 06 §4.1, §4.2 | A has an order | WS(own order); auth with A's access token | `auth.ok` `{user_id, expires_at}` (= token exp), then exactly one `order.status` snapshot of that order; every message is `{type, data, sent_at}`; data keys = order_id, order_number, store_id, status, payment_status, eta_at, updated_at (no OTP, phone, address, name) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-02 🔥 | BE | P0 | T-611 | 06 §4 (never in the URL); 09 | A's order | WS(own order + `?token=<A access>`); send nothing | The query token is ignored: no `auth.ok`, no data; closed 4408 after the auth timeout | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-03 | BE | P0 | T-611 | 06 §4.1 | A's order | WS with subprotocols `jivo.v1` + `jivo.auth.<token>` | Handshake selects `jivo.v1`; no response header contains the token; `auth.ok` then the snapshot without an auth message | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-04 | BE | P0 | T-611 | 06 §4.1 close codes | A's order | Auth with: a tampered signature, A's refresh token, an empty string, a 5,000-char string, a number | 4401 each time; nothing sent before the close | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-05 | BE | P1 | T-611 | 06 §4.1 | — | WS(own order), wait 12 s without a message | Closed 4408 after ~10 s (`WS_AUTH_TIMEOUT_SECONDS`) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-06 | BE | P0 | T-611 | 06 §4.1 | — | First message: `{"type":"ping"}`; non-JSON text; a JSON array | 4400 each, nothing sent | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-07 🔥 | BE | P0 | T-611 | 06 §4.1 4404; CLAUDE.md IDOR | A and B each have an order | A's token on WS(B's order); A's token on WS(id 999999999) | 4404 for both (same code, so ids leak nothing); no `auth.ok`, no data | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-08 | BE | P0 | T-611 | 06 §4.1 renewal | A's socket authorised | Re-auth with a fresh token of A; then re-auth with B's valid token | A's renewal: a second `auth.ok`, socket stays; B's token: 4401 | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-09 | BE | P1 | T-611 | 06 §4.1 | Instance profile `shorttoken` (access lifetime 60 s) | Auth, wait past `expires_at` without renewing | Closed 4401 at expiry | ⏭ needs the `shorttoken` profile (stage 2) |
| P6-TC-10 | BE | P1 | T-611 | 06 §4.2 control | A authorised | `ping`; then `{"type":"bogus"}` | `pong` with `sent_at`; `error` `{code: VALIDATION_ERROR}`, socket stays open | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-11 🔥 | E2E | P0 | T-611 | 06 §4.4; 08 §9 | A places COD at QA-02 | WS(that order) authorised; A cancels via REST | `order.status` CANCELLED arrives on the socket within 3 s of the cancel response | ⬜ first run blocked: A's COD was blocked by a concurrent P5 DL-61 case; test switched to an ONLINE order, rerun pending |
| P6-TC-12 | BE | P0 | T-611/T-612 | 06 §4.1 (OTP never on a socket) | Orders of A in every state | Snapshot `order.status` of each | No `otp`/`delivery_otp` key (or 4-digit OTP value) in any socket message | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-13 | BE | P1 | T-611 | 06 §4.1; 09 | A deactivated/deleted user's token | Auth | 4401 | ✅ (efb3c3d, 2026-11-09) |
| P6-TC-14 🔥 | E2E | P0 | T-612 | 06 §4.2 `rider.location`; 08 §8 | OUT_FOR_DELIVERY order of A, R1 on task | R1 sends location points | A's socket gets `rider.location` `{order_id, lat, lng, heading, recorded_at}`; B's socket for B's order gets nothing | ⏭ T-612 |
| P6-TC-15 | BE | P1 | T-612 | 08 §8 | As TC-14 | Location updates every 5 s for 2 min | `order.eta` recomputed per the 08 §8 formula (road factor 1.3, 20 km/h, +2 min), no more often than `WS_ETA_MIN_INTERVAL_SECONDS` (30 s) | ⏭ T-612 |
| P6-TC-16 | BE | P0 | T-612 | 06 §4.2; 09 privacy | Orders before pickup and after T10 | R1 pings | No `rider.location` to the customer before OUT_FOR_DELIVERY or after DELIVERED/FAILED | ⏭ T-612 |
| P6-TC-17 | CUS | P0 | T-613 | 06 §4.1 fallback | Device run | Drop the socket during tracking (airplane mode) | App polls `GET /orders/{id}/track/` every 10 s and reconnects with backoff, re-reading REST on reconnect; no crash, no stale status | ⏭ device run (PM) |
| P6-TC-18 | BE | P1 | T-611 | 06 §4.2 (state, not diffs) | A's order | Connect, auth, close; reconnect and auth again | A fresh snapshot each time; the closed socket's slot is released | ✅ (8f87d7b, 2026-11-06) |

### Rider socket `/ws/v1/rider/` (06 §4.1, §4.2)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-19 🔥 | BE | P0 | T-611 | 06 §4.1 | R1 ACTIVE; E has no rider profile | R1 rider-app token; R1 customer-app token; E rider-app token | `auth.ok`; 4403; 4403 | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-20 | BE | P0 | T-611 | 06 §4.1 re-check | Spare QA rider, instance profile `wsrecheck` | Suspend the rider while the socket is open | Closed 4403 at the next re-check (≤ `WS_RIDER_RECHECK_SECONDS`) | ⏭ stage 2 (spare rider and profile) |
| P6-TC-21 🔥 | E2E | P0 | T-612 | 06 §4.2 `offer.new`; 08 §5 | R1 online at QA-02, socket open | A places COD at QA-02 | `offer.new` within 3 s of dispatch; data equals `GET /rider/offers/current/` | ⏭ T-612 |
| P6-TC-22 | BE | P0 | T-612 | 06 §4.2 `offer.withdrawn` | R1 has an offer | Let it expire; cancel the order; another rider takes it; ops reassign | `offer.withdrawn` with reason EXPIRED / ORDER_CANCELLED / TAKEN / REASSIGNED | ⏭ T-612 |
| P6-TC-23 | BE | P1 | T-612 | Brief `offer.expired` vs 06 §4.2 | As TC-22 | Expire an offer | Per 06: `offer.withdrawn` reason EXPIRED (no `offer.expired` type); ambiguity P6-A1 | ⏭ T-612 |
| P6-TC-24 | BE | P0 | T-612 | 06 §4.2 `task.updated` | R1 assigned | Pack, adjust items (COD), cancel, reassign, status change | `task.updated` with change ORDER_PACKED / AMOUNT_CHANGED / ORDER_CANCELLED / REASSIGNED / STATUS_CHANGED; the REST task matches | ⏭ T-612 |
| P6-TC-25 | BE | P1 | T-612 | Brief `cash.updated`; 08 §6 | R1 collects COD, ops records a deposit | — | A cash update event (contract to be defined, P6-A1) with `cash_in_hand` equal to `GET /rider/cash/` | ⏭ T-612 |
| P6-TC-26 🔥 | BE | P0 | T-612 | 06 §4 scoping | R1 and R2 sockets open | An offer to R1 | R2 receives nothing | ⏭ T-612 |

### Ops live feed `/ws/ops/live/` (06 §4.1; 05 §3)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-27 🔥 | ADM | P0 | T-611 | 06 §4.1 | OPS signed in (session) | WS(`/ws/ops/live/`) with the session cookie and Origin `http://127.0.0.1:8004`; `ping` | Open without an auth message; `pong` | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-28 | ADM | P0 | T-611 | 06 §4.1; 09 (CSWSH) | OPS session | No cookie; a forged session id; the right cookie with Origin `https://evil.example`; no Origin | 4401; 4401; handshake refused (403); handshake refused | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-29 🔥 | ADM | P0 | T-611 | 05 §3; 06 §4.1 | Each seeded role signed in | Open the feed as SA, OPS, SM, SS, SUP, FIN, CAT | Open for roles with `orders.view_order` and ≥ 1 store; CAT (no order view) 4403 | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-30 🔥 | ADM | P0 | T-611 | 06 §4.1 (scoped to permitted stores) | OPS, SM (GGN-01), SS (GGN-01) feeds open | A places COD at QA-02, then cancels | OPS gets `order.created` and `order.status` for the order; SM and SS get nothing about it | ⬜ rerun pending (same test as TC-11) |
| P6-TC-31 | ADM | P0 | T-611 | 06 §4.2 (no customer data) | As TC-30 | Inspect `order.created`/`order.status` | Keys exactly as the 06 §4.2 example; no phone, name, address, OTP | ⬜ rerun pending (same test as TC-11) |
| P6-TC-32 | ADM | P1 | T-611 | 06 §4.1 (P8 M1) | Profile `wsrecheck` (short `WS_OPS_RECHECK_SECONDS`) | Log out / let the session expire while the feed is open | Closed 4401 at the re-check or the session deadline | ⏭ stage 2 (profile) |
| P6-TC-33 | ADM | P1 | T-611/T-612 | 06 §4.2 `alert`; 08 §9 | QA-02 order unaccepted past the SLA / failed delivery / unassigned | — | `alert` with ACCEPTANCE_SLA_BREACHED / DELIVERY_FAILED / DISPATCH_UNASSIGNED to the store's feeds only | ⏭ timer profile, stage 2 |
| P6-TC-34 | ADM | P1 | T-612 | 06 §4.2 `rider.status`, `rider.location` | QA rider goes online/offline, pings on task | — | `rider.status`/`rider.location` to the rider's home-store feeds only | ⏭ T-612 |

### Inbox (06 §2.7)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-35 🔥 | BE | P0 | T-611 | 06 §2.7 | A has order notifications | `GET /me/notifications/` (customer token) | 200, standard page, newest first, schema-valid; only customer-app entries (no `rider.*`) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-36 🔥 | BE | P0 | T-611 | 06 §2.7; IDOR | A and B have entries; R1 has rider entries | A marks own entry read (twice); A marks B's id; A marks 999999999; R1's customer token marks R1's rider-app entry | 200 `read: true` both times; 404; 404; 404 (app scoping) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-37 | BE | P1 | T-611 | 06 §2.7 | A has unread entries | `POST /me/notifications/read-all/` twice | `{updated: n}` then `{updated: 0}`; list shows all `read: true` | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-38 🔥 | BE | P0 | T-611 | 08 §9; catalog (no OTP in the inbox) | Entries of `order.out_for_delivery` exist | Read the inbox and DB | No OTP in any inbox body; `order.rider_arrived` never in the inbox | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-39 | BE | P1 | T-611 | 06 §6 envelope | — | Inbox endpoints without a token / with a bad token | 401 `{"error":{code,...}}` | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-40 | BE | P2 | T-611 | 06 §2.7; 02 §5 paging | A | `?page_size=1000`; `link` values | Page capped at 100; `link` is `jivo://orders/<id>[/detail]` or null | ✅ (8f87d7b, 2026-11-06) |

### Notifications, SMS and push (08 §9; 06 §4.3, §5; 09 DLT)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-41 🔥 | BE | P0 | T-611 | 08 §9 | Notifications of all users (read-only SQL) | Group by event and channel status | SMS channel used only for placed, items_adjusted, out_for_delivery, cancelled, refund.processed; accepted, payment_failed, delivered, delivery_failed, rider_arrived are push-only (`sms_status` NONE); at most one row per (event, user, order) except items_adjusted | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-42 | BE | P0 | T-611 | 06 §5; 09 DLT | Local (no `SMS_DLT_TEMPLATE_IDS`) | SMS events | `sms_status` never SENT without a DLT id (rows with SMS SENT have a `sms_dlt_template_id`) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-43 🔥 | BE | P0 | T-611 | 09 (secrets at rest) | Sent `order.out_for_delivery` rows | Read-only SQL on `push_body`, `sms_body`, `body` | No OTP stored after the send (blanked) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-44 | BE | P1 | T-611 | 06 §5 retries | Fault-injection profile (push/SMS gateway down) | Trigger events | Transient errors retried ≤ 5 with backoff; rejected/unknown-outcome SMS FAILED, never resent; SENDING > 15 min swept to FAILED and text blanked | ⏭ needs a gateway-fault profile; backend unit tests cover it |
| P6-TC-45 | BE | P1 | T-611 | 06 §4.3; D-19 | — | `manage.py check --deploy` with staging settings and a console `PUSH_BACKEND` | `notifications.E001` refuses console/locmem push on staging/prod | ⏭ config review (DevOps/PM) |
| P6-TC-46 | BE | P1 | T-611 | 06 §4.3 (stored refund amount) | A places a paid ONLINE order at QA-02 | A cancels | `order.cancelled` inbox body quotes `₹<Refund.amount>` equal to the stored refund | ✅ (8f87d7b, 2026-11-06) |

### Purge and sweep jobs (06 §5; 07 §4)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-47 | BE | P1 | T-611 | 06 §5 | — | Read the beat schedule (`django_celery_beat_periodictask`, read-only) | `realtime.purge_old_locations` and `notifications.purge_old_notifications` daily, `notifications.sweep_stuck_sends` every 15 min | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-48 | BE | P1 | T-611 | 07 §4 retention | Beat has run | Read-only SQL | No notification older than 90 days, no rider location older than 30 days | ✅ (8f87d7b, 2026-11-06) |

### Socket abuse limits (06 §4.1, P8 L5)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-49 🔥 | BE | P0 | T-611 | 06 §4.1 4429 | A | Open 6 authorised sockets; close one; open another | 6th closed 4429; after a close a new one is accepted | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-50 | BE | P0 | T-611 | 06 §4.1 1009 | A | Send 5,000 bytes before auth; after auth | Closed 1009 both times | ❌ BUG-0020 (still open at efb3c3d: code unchanged; now xfail strict) |
| P6-TC-51 | BE | P1 | T-611 | 06 §4.1 4400 | A authorised | 11 malformed/unknown messages | 10 `error` replies, then closed 4400 | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-52 | BE | P1 | T-611 | 09; 06 §4.1 | A | Binary frame, invalid JSON, deep nesting, huge numbers, unicode | Never a server crash; `/health/live` 200 afterwards; another open socket unaffected | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-53 | BE | P2 | T-611 | 06 §4.1 leases | A | 20 rapid connect/auth/close cycles (≤ 5 open at once) | No leaked slots: 5 fresh sockets then authorise | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-54 | BE | P1 | T-611 | 06 §4.1 (ASGI frame cap) | Staging config | Review daphne/uvicorn flags | `--ws-max-size 65536` / `--websocket_max_size 65536` | ⏭ DevOps config review |

### Cross-cutting
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-55 🔥 | BE | P0 | T-611 | 06 §4; 09 logs | After the WS run | Grep the QA instance log for JWTs (`eyJ…`) | None | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-56 | BE | P1 | T-611 | 06 §4.1 contract | `openapi/schema.yaml` | Look up `Ws…Message` components | One per message type in 06 §4.2 (order.status, order.eta, order.created, rider.location, rider.status, offer.new, offer.withdrawn, task.updated, alert, auth.ok, pong, error) | ✅ (8f87d7b, 2026-11-06) |
| P6-TC-57 | RID | P0 | T-614 | 04; 06 §4.1 fallback | Device run | Rider app with the socket dropped | Polls `GET /rider/offers/current/`, FCM fallback, inbox; no crash | ⏭ device run (PM) |

### Added in stage 2 (2026-11-09)
| ID | Area | Pri | Task | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|---|
| P6-TC-58 🔥 | BE | P0 | T-612 | 06 §4.2 `notification.new`; 06 §2.7 unread count | A's order socket open | An order event creates an inbox entry | `notification.new` on A's open socket; `GET /me/notifications/unread-count/` rises by one and drops after read; no other user's socket gets it | ⬜ not run (stage 2 stopped for PC shutdown) |
| P6-TC-59 🔥 | E2E | P0 | T-612/T-613/T-614 (server side) | 06 §4.1 polling fallback | ASG; A's order socket and R1's rider socket open | Walk to OUT_FOR_DELIVERY, ping; compare REST `track` and `rider/tasks/current` with the last socket messages; close both sockets, deliver | REST status/task status = last `order.status`; `track.rider` lat/lng = last `rider.location`; `live_eta_minutes` = last `order.eta`; rider REST task = last `task.updated`; with sockets closed, REST alone shows DELIVERED (OTP and ETA cleared, task gone) | ⬜ not run (stage 2 stopped for PC shutdown) |

### Totals (Phase 6, stage 1 design, 2026-11-06)
| Cases | 🔥 | P0 | P1 | P2 | BE | ADM | E2E | CUS | RID | T-611 (incl. 2 shared with T-612) | T-612 | T-613 | T-614 | ⬜ | ⏭ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 57 | 18 | 33 | 22 | 2 | 44 | 8 | 3 | 1 | 1 | 45 | 10 | 1 | 1 | 37 | 20 |

⏭ reasons: T-612 not merged (10), device run (2: TC-17, TC-57), stage 2 timer/instance profiles (5: TC-09, 20, 32, 33 and the fault profile TC-44), config review (TC-45, TC-54), spare QA number (TC-13). Execution results: `03-api-testing-report.md` / `06-security-testing-report.md` (Phase 6 sections) after the run.

**Stage 1 execution (2026-11-06, develop `8f87d7b`, QA instance :8004, `config.settings.local`, daphne runserver):** `uv run pytest tests/test_p6_ws.py -q -rfEsx` gave 45 passed, 4 failed and 18 skipped. Afterwards, TC-04 [huge] was fixed in the test (it used a 5,000-byte message, which is the TC-50 path) and rerun: 5 passed. By case: 33 ✅, 1 ❌ (TC-50, BUG-0020), 3 ⬜ waiting for a rerun (TC-11/30/31), and 20 ⏭.

## Phase 7: Dashboard, support, ratings and reports (written 2026-11-09, QA stage 2, develop `efb3c3d`)
**Contract and code read:** 05 §1.1 (dashboard), §2 (Ratings, Support), §3 (Reports, Support tickets rows), §4 (report definitions, DL-65 net revenue); 06 §2 (ratings, support tickets, attachments); 03 §2.10/§2.11; 04 §2.9; 09 (PII, DPDP erasure); DL-64, DL-65, DL-66. Backend `apps/reports` (`services`, `registry`, `dashboard`), `apps/support/services` (SLA), `apps/orders/ratings`. **The admin P7 screens (reports, ticket queue, ratings, dashboard cards) are not merged**, so staff-side cases call the same backend services as the seeded staff user through `qa/tools/p7_driver.py` (read-only except ticket replies, status and priority through `apps.support.services`). SLA and dashboard-alert time travel is done by passing `now` to the read-only service functions; nothing in the DB is back-dated. Automation: `qa/tests/test_p7.py`.

**Shorthands:** as Phase 5/6; SMQ = the QA-only Store Manager scoped to QA-02 (`qa02.manager@jivo.test`, created by QA through the admin on 2026-11-09, PM-approved).

### Ratings (06 §2; 03 §2.10)
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-01 🔥 | BE | P0 | 06 §2 ratings; 08 §9 | A's QA-02 COD order DELIVERED by R1 | `POST /orders/{id}/rating/` order 4, rider 5, tags (with a duplicate), padded comment; `GET`; order detail | 201 (trimmed comment, de-duplicated tags); GET equal; `can_rate` false and `rating` set; one ORDER and one RIDER row (rider tags only on the RIDER row); rider `rating_avg` = SQL mean (1 dp) | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-02 🔥 | BE | P0 | 06 §2 (once) | Delivered order | 5 parallel first ratings; then a sixth | Exactly one 201, four 400 `VALIDATION_ERROR` `details.reason` ALREADY_RATED; one ORDER row; the later one ALREADY_RATED | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-03 🔥 | BE | P0 | 06 §2 | A's PLACED/ACCEPTED order, then CANCELLED | Rate; GET rating | 400 `NOT_DELIVERED` both times; GET 404; `can_rate` false; nothing stored | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-04 🔥 | BE | P0 | CLAUDE.md IDOR | A's delivered order | B rates / reads it before and after A rates; missing id; no token | 404, 404, 401; no row of B | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-05 | BE | P1 | 06 §2 validation | Delivered order | Rider tags without rider stars; stars 0/6/9/"five"; unknown tag; comment 501 chars; empty body | 400 `details.<field>`; nothing stored | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-06 | BE | P1 | 06 §2 | Delivered order | Order stars only with a shared tag | One ORDER row, no RIDER row; `rider_stars` null | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-07 🔥 | BE | P0 | 06 §2 `GET /rider/ratings/`; 09 PII | R1 rated 2 with a secret comment | R1 lists ratings; R2 lists; R1 customer-app token; `before_id` paging | R1 sees only `{id, stars, tags, rated_at, order_number}` (no comment, no customer); summary = SQL; R2 never sees it; customer token 403; paging by id | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-08 | ADM | P1 | 05 §2 Ratings | A rated order at QA-02 | Staff ratings as SA, OPS, SUP, SM (GGN-01), CAT, FIN, SS | SA/OPS/SUP see it; SM sees nothing; CAT/FIN/SS refused | ⬜ not run (stage 2 stopped for PC shutdown) |

### Support tickets (06 §2; 03 §2.11; 04 §2.9)
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-10 🔥 | BE | P0 | 06 §2 tickets | A | Create OTHER; list; detail | 201 `TK-nnnnnn`, OPEN, `can_reply`, one message; first in the list; SLA NORMAL due at +60 min / +24 h | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-11 | BE | P1 | 06 §2 validation | A | Order-bound category without `order_id`; message < 10, > 1000, whitespace; unknown/rider-only category; unknown order; **B's order id** | 400 `details.<field>`; B's order gives exactly the same error as a missing order (no existence leak) | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-12 🔥 | BE | P0 | IDOR | A's ticket | B: GET, reply, upload; missing id; no token | 404 ×4, 401; A's ticket untouched | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-13 🔥 | BE | P0 | 06 §2 per-app scoping | QA C is customer and rider | A customer-app ticket and a rider-app ticket | Each app lists only its own; the other app's id → 404 on GET/reply/upload | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-14 | RID | P1 | 04 §2.9 | R1 delivered a task | Rider ticket TASK with own task; R2 naming R1's task; PAYOUT with an unknown payout | 201 with `order_number`; 400 `task_id`; 400 `payout_id` | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-15 🔥 | BE | P0 | 06 §2 attachments; 09 (EXIF, private bucket) | A's tickets | Upload a PNG with an EXIF marker; fetch the signed URL and the unsigned URL; reply with the key; reuse it; another ticket's key; B's key; 4 keys | 201 `{key, url}` signed 600 s; stored as WebP without EXIF; unsigned URL refused; reply carries it once; the other keys and > 3 → 400 `attachment_keys` | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-16 | BE | P1 | 06 §2 | A's ticket | Upload GIF, PDF, HTML-as-PNG, empty, SVG | 400 `VALIDATION_ERROR` each, never 500; nothing stored | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-17 | BE | P1 | 06 §2 (5 MB) | A's ticket | 5 MB + 1 KB PNG; 4.5 MB PNG | 400/413, nothing stored; 201 | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-18 🔥 | BE | P0 | 05 §2 Support; 08 §9 | A's ticket | Support replies; Finance replies; inbox; RESOLVED then customer reply; CLOSED then reply/upload; CLOSED → OPEN | IN_PROGRESS, staff message; Finance refused; inbox entry `support` with link `jivo://support/tickets/<id>` not quoting the reply; reply reopens (OPEN); CLOSED refuses with `details.ticket`; CLOSED → OPEN refused | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-19 | BE | P2 | 06 §2 limits | QA D customer app | 11 creates in one hour | 10 × 201, 11th 429 | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-20 | BE | P1 | 09 §3.3 PII in logs | After the run | Grep the QA instance and worker logs for ticket bodies and rating comments | None | ✅ (efb3c3d, 2026-11-09) |

### Support SLA (05 §2 Support; PM default SLA settings)
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-35 🔥 | ADM | P0 | `SUPPORT_FIRST_RESPONSE_SLA_MINUTES` / `SUPPORT_RESOLUTION_SLA_HOURS` | A's ticket | Support sets URGENT, HIGH, LOW, NORMAL; Finance sets URGENT; unknown CRITICAL | Due times from `created_at`: 15 min/4 h, 30 min/8 h, 240 min/72 h, 60 min/24 h; Finance refused; CRITICAL refused | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-36 🔥 | ADM | P0 | `sla_state`, `breached_tickets`, `with_sla` | A's NORMAL ticket | Evaluate at now, +61 min (no reply), Support reply, +61 min, +25 h, RESOLVED, +25 h; breached queue as Support and Finance | Not breached at once; first response breached at +61 min and in Support's breached queue (Finance: empty); an in-time reply clears it; resolution breached at +25 h while open; RESOLVED in time clears it and leaves the queue | ✅ (efb3c3d, 2026-11-09) |

### Reports and CSV export (05 §3, §4; DL-65)
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-21 🔥 | ADM | P0 | 05 §3 Reports | — | Available reports per role; run without permission; unknown key | SA/FIN: all 12; OPS/SM: 8 sales + catalog; CAT: 3 catalog; SS/SUP: none; refused runs PermissionDenied; unknown key ValidationError | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-22 🔥 | ADM | P0 | 05 §3 "own store" | — | SM (GGN-01): orders with `store_id` QA-02, sales unfiltered, inventory QA-02, export QA-02; OPS: sales QA-02 | Explicit other store → PermissionDenied (not an empty report); unfiltered → no QA-02 row; OPS QA-02 → only QA-02 rows | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-22b | ADM | P1 | 05 §3 "own store" | SMQ | SMQ: sales unfiltered; orders with GGN-01 | Only QA-02 rows, equal to OPS filtered to QA-02; GGN-01 PermissionDenied | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-23 🔥 | ADM | P0 | 05 §4; DL-65 | A COD order at QA-02 refused at the door (DELIVERY_FAILED) | `sales_summary` for QA-02 today | Every column equals an independent SQL oracle (GMV, tips, refunded, uncollected COD, net revenue = GMV − tips − refunded − uncollected COD, AOV); the failed COD stays in GMV and is excluded from net revenue; money as 2-decimal strings | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-24 🔥 | ADM | P0 | 09 (CSV injection) | — | CSV writer probe; CSV of all 12 reports | UTF-8 BOM; `= + - @ TAB CR` cells prefixed with `'` (plain numbers untouched); no unescaped formula cell in any report | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-25 | ADM | P1 | 05 §4 | — | start > end; > 366 days; an empty day | ValidationError, ValidationError, no rows | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-26 | ADM | P0 | 09 PII | — | CSV of orders, refunds, COD reconciliation, cancellations | No customer phone, name or address | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-27 | ADM | P1 | 05 §4 async export | — | OPS exports orders QA-02; OPS downloads; Finance downloads OPS's export | DONE with rows; signed URL; Finance refused (own exports only) | ✅ (efb3c3d, 2026-11-09) |

### Dashboard (05 §1.1)
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-31 🔥 | ADM | P0 | 05 §1.1 KPI cards | A QA-02 order delivered today | OPS: KPIs for QA-02 today; `sales_summary` for the same day | Orders, delivered, cancelled (%), GMV, AOV, avg delivery and acceptance time, SLA breaches (late deliveries/acceptances), online riders, active orders, stock-outs and low stock equal an independent SQL oracle; GMV/orders/AOV equal the sales summary; money as 2-decimal strings | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-32 🔥 | ADM | P0 | 05 §3 Reports (dashboard uses `reports.view_reports`) | — | KPIs as SA, OPS, FIN, SUP, SS, CAT; SM (GGN-01) with `store_id` QA-02 (KPIs, alerts); SMQ unfiltered vs OPS filtered to QA-02 | SA/OPS/FIN allowed; SUP/SS/CAT and SM-on-QA-02 PermissionDenied; SMQ == OPS(QA-02) for KPIs and alerts | ✅ (efb3c3d, 2026-11-09) |
| P7-TC-33 | ADM | P1 | 05 §1.1 alerts ("orders without a rider > 3 min") | No QA rider online | Place a COD at QA-02; alerts now and with the service clock +4 min; SM (GGN-01) alerts +4 min | Not listed at once; listed at +4 min (store QA-02, task SEARCHING/OFFERED/UNASSIGNED); never in the GGN-01 manager's alerts | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-34 | ADM | P1 | 05 §1.1 charts | — | Charts and KPIs for QA-02 today | Orders per hour (24 IST hours) sums to KPI orders; today's GMV trend point = KPI GMV; payment split (ONLINE, COD) sums to live orders and GMV; top products = SQL | ⬜ not run (stage 2 stopped for PC shutdown) |

### DPDP and device
| ID | Area | Pri | Ref | Pre | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| P7-TC-30 🔥 | BE | P0 | 09 DPDP; 06 §3 erasure | QA E: delivered order rated with a comment, a ticket with a staff reply | E deletes the account (API); anonymise | Rating comments erased (stars/tags kept, rider average unchanged); E's ticket bodies erased; staff replies kept; phone and name cleared | ⬜ not run (stage 2 stopped for PC shutdown) |
| P7-TC-37 | CUS | P1 | 03 §2.10 | Customer dev build, phone | Rate a delivered order (stars, tags, comment) from the order and from the push deep link; re-open the order | Rated view, no second rating; no crash | ⏭ device run (PM) |
| P7-TC-38 | CUS | P1 | 03 §2.11 | Customer dev build, phone | Help → new ticket with a photo (camera and gallery); reply; open the support push/inbox link | Ticket created, photo shown, deep link opens the ticket | ⏭ device run (PM) |
| P7-TC-39 | RID | P1 | 04 §2.9 | Rider dev build, phone | Help → TASK and PAYOUT tickets; My rating; legal pages | Tickets per app; rating summary without comments; legal pages render safe HTML | ⏭ device run (PM) |
| P7-TC-40 | ADM | P1 | 05 §1.1, §2 | Admin P7 screens merged | Dashboard cards, alerts panel, ticket queue with SLA badge, ratings list, reports page and export download in the console | Same numbers as the service-level cases above; role matrix enforced in the console | ⏭ admin P7 screens not merged |
