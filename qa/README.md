# QA: Jivo Quick Commerce

The independent QA workspace, owned by the `qa-engineer` agent. It contains:
- `docs/`: the 10 QA deliverables (test plan, test case repository, reports, release readiness)
- `bugs/`: one file per reproducible bug (`BUG-nnnn.md`)
- `tests/`: black-box suites (pytest + httpx + jsonschema + schemathesis), a standalone `uv` project with pinned dependencies (`pyproject.toml`, `uv.lock`)
- `tools/`: instance control, performance baseline and secrets scan
- `private/`: **gitignored**. It holds exploit details of open security bugs, run outputs and instance logs.

## Rules the suite enforces
- **Target.** It only ever targets the QA instance (`127.0.0.1:8004` by default). `QA_BASE_URL` with port 8001 is refused.
- **Redis.** It uses Redis 6380 DBs 5–7 only. Cleanup deletes only `jqc:rl:*` keys in DB 5, never on port 6379.
- **Phone numbers.**
  - Fixed-OTP QA numbers `+919000000101…105` (OTP `123456`).
  - Non-test numbers `+9199999000xx`, only for limit tests. No SMS is ever sent: console backend, and no worker on the QA broker DB.
- **Database.**
  - Read-only SQL: credentials from `backend/.env`, never printed; aggregates only.
  - Writes happen only through the API and admin, with QA accounts.
  - Never `migrate`, `seed_demo`, `flush` or DDL.
- **Lockouts.** Lockout tests use non-existent usernames only.
- **Redaction.** Tokens and phones are redacted in assertion output.

## Run it against your own instance
Prerequisites: `uv`, the compose Redis on 6380, `backend/.env` (DB credentials) and git access to the commit under test.

```bash
# 1. Start a QA backend on 127.0.0.1:8004 from a clean export of a commit (default HEAD).
#    The export goes to /tmp/jivo-qa-<sha>/ with backend/.env symlinked (never copied).
qa/tools/instance.sh start local 4960527          # profiles: local | staging | redis-down | daylimit
qa/tools/instance.sh status

# 2. Run the suites
cd qa
uv sync
uv run pytest                                      # full suite for the running profile
uv run pytest -m smoke                             # 🔥 regression smoke set
uv run pytest tests/test_fuzz_schemathesis.py      # fuzzing (~3 min)
uv run python tools/perf_baseline.py               # p50/p95 + bursts of <= 20
uv run python tools/secrets_scan.py 4960527        # tracked-file secrets scan (file:line only)

# 3. The profile-specific tests skip themselves unless the instance runs that profile
qa/tools/instance.sh stop && qa/tools/instance.sh start staging 4960527 && uv run pytest
QA_FORCE_ALL=1 uv run pytest --deselect tests/test_p1_staff.py   # the whole API suite with DEBUG off

# 4. Always stop the QA instance (kills only the PID listening on 8004)
qa/tools/instance.sh stop
```

**Environment variables:**
- `QA_BASE_URL` (default `http://127.0.0.1:8004`)
- `QA_REDIS_URL` (default `redis://localhost:6380/5`)
- `QA_PROFILE` (overrides the recorded instance profile)
- `QA_SCHEMA` (the OpenAPI file to validate against; default: the exported commit's `backend/openapi/schema.yaml`)
- `QA_KEEP_COUNTERS=1` (don't clear rate-limit counters at session start)
- `QA_FORCE_ALL=1` (run local-profile tests on another profile)
- `QA_SLOW=1` (run the slow cases, e.g. P3-TC-47, which waits about 16 min for the :8001 beat to expire an unpaid order)

**Phase 3** (`tests/test_p3_*.py`) uses the FakeRazorpayGateway's published dev-only secrets (06 §2.6) and, read-only, the demo catalogue and coupons. COD orders and paid ONLINE orders stay PLACED in Phase 3, so they keep a little demo stock reserved; see `docs/03` ("Demo data consumed"). Refunds settle only when a Celery worker consumes the QA broker (Redis DB 7): `uv run celery -A config worker --pool=solo` with the QA Redis URLs.

Guard tests for **open security bugs** live in the gitignored `qa/private/tests/` (run them with `uv run pytest private/tests`). They move back into `tests/` once the bug is fixed.

**Known open bugs** are `xfail(strict=True)` with the bug ID. When a fix lands, the test XPASSes and fails the run, which is the cue to verify the fix and remove the marker.

**Phase 5** (`tests/test_p5_*.py`, helpers in `p5_support.py`, staff/system actions through `tools/rider_ops_driver.py`) uses the QA-only store QA-02 and QA users C and D as riders. The slice 5.3 cases are marked `p5_53` and skip themselves until commit `fd1490c` is an ancestor of the commit under test **and** the shared DB has `delivery.0002` (`QA_P5_53=1` forces them). They need the QA Celery worker on DB 7 (started by the `qa_worker` fixture). Timer cases use the `dispatchfast`, `riderclock` and `triggerplaced` instance profiles (environment only; see `docs/01-test-plan.md` §9.2).
