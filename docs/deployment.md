# Deployment & Environments

This file records what is **actually set up today**, plus the target for the environments that don't exist yet.
- Target architecture: [`02-system-architecture.md`](02-system-architecture.md) §4 and §8.
- Hosting decision: D-05 in [`11-open-decisions.md`](11-open-decisions.md).

| Environment | Status |
|-------------|--------|
| **local** (developer machine) | ✅ working (described below) |
| **CI** (GitHub Actions) | ⚠️ `mobile` green on `main`; `backend` and `infra` red on `main` `8e42ec0` (2026-11-10), fixed on `devops/p8-ci` (2026-11-16): runner lacked GDAL after the PostGIS engine switch, four new settings missing from the env example, and the PowerShell restore test's exit code (§2). T-404c (2026-11-04) added parallel backend tests and the env-example and Razorpay pin checks. |
| **CI workflows** | (`.github/workflows/backend.yml`, `mobile.yml`). T-404c (2026-11-04) added parallel backend tests and the env-example and Razorpay pin checks. 2026-11-10: secret scanning (`secret-scan.yml`) and dependency advisories (`dependency-scan.yml`) added (§2.1, §2.2); not yet run on GitHub. |
| **staging** | ⬜ **not set up.** Needs D-05 (hosting), domains/TLS, Razorpay test keys, and the Firebase staging project |
| **production** | ⬜ **not set up** (Phase 8, [`release-checklist.md`](release-checklist.md)) |
| **P8 hardening (prepared, T-813)** | ✅ backup/restore scripts + verifier with a schema-only drill (§7), deploy-time checks and release step in the image (§8), edge limits and log hygiene (§9), monitoring as code (§10), secrets and rotation (§11). Nothing is applied to staging/production until D-05. |

## 1. Local development

### Prerequisites
- **Backend:** `uv` (Python 3.13 is installed through uv; never use the system Python 3.14) and Docker with Compose. On the Windows dev machine (no Docker), Redis runs natively and MinIO/Mailpit come from `infra/scripts/windows/dev-services.ps1` (below).
- **Geo libraries:** GDAL/GEOS/PROJ for GeoDjango: `sudo apt install -y gdal-bin libgdal-dev libgeos-dev libproj-dev`. The backend Docker image already has them.
- **Flutter:** 3.47.9 / Dart 3.13.7, the Android SDK with **platform 37**, Java 17. The API generator needs Java 17 and python3.

### Database
- The DB is a **remote PostgreSQL 16 + PostGIS 3.4.2** server, shared with other projects.
- Credentials live only in **`backend/.env`**, which is gitignored and chmod 600. Every setting is listed with placeholders in `infra/env/backend.env.example`.
- There is no local Postgres container.

### Backend
```bash
docker compose -f infra/docker-compose.yml up -d redis minio mailpit   # from repo root; ports bound to 127.0.0.1
cd backend
uv sync
uv run python manage.py migrate
uv run python manage.py seed_demo                  # idempotent demo data; staff password = SEED_DEMO_STAFF_PASSWORD in .env
uv run python manage.py runserver 127.0.0.1:8001   # API, admin (/admin/), ops (/ops/)
uv run celery -A config worker -l info             # needed for real (non-test-number) OTP SMS
uv run celery -A config beat -l info               # scheduled jobs (required: expire_unpaid_orders, §4)
```
- **Windows host** (the current dev machine, no Docker; see `dev-environment.md`): run `uv run celery -A config worker -l info --pool threads` and `uv run celery -A config beat -l info` as two separate processes. Windows refuses `-B` (embedded beat).
- **Alternative:** the compose services `backend`, `worker` and `beat` run the same stack in Docker, using `backend/.env`. Don't run them alongside a host `runserver` on 8001.

### Windows dev machine: MinIO and Mailpit without Docker
The user approved this on 2026-11-04. `infra/scripts/windows/dev-services.ps1` replaces the compose `minio` and `mailpit` services.
- **No admin rights, nothing installed system-wide.**
- **Binaries:** `%USERPROFILE%\.local\share\jivoqc-tools\<tool>\<version>\`
- **Data and logs:** `…\jivoqc-tools\data\{minio,mailpit,logs}`
- **Binding:** everything binds to `127.0.0.1` only. The ports are the compose ports: MinIO 9000/9001, Mailpit SMTP 1025 and UI 8025.

```powershell
# from the repo root; every action is idempotent. -Service all|minio|mailpit (default all)
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action start
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action status   # processes + listening ports
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action init     # MinIO buckets + policy + checks
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action stop
```
- **`start`:**
  - Downloads any missing pinned binary from its official source and checks its sha256 against the pin in the script. On a mismatch it stops and installs nothing.
  - Then starts each service as a hidden background process that outlives the shell. Logs go to `data\logs\<service>.log`.
  - If another process already holds a service's port, it refuses to start that service.
  - **Exit codes:** `0` if everything requested is running, `2` if anything was skipped or failed.
- **`stop`:** kills only processes whose executable path is inside the tools folder.
- **`init`:** runs `infra/scripts/minio_buckets.py` through the backend's uv environment.
  - It reads the endpoint, credentials and bucket names from the Django storage settings, so `backend/.env` overrides apply. It refuses any endpoint that isn't localhost.
  - It creates the private bucket `jivo-media` (`S3_MEDIA_BUCKET`) and the public bucket `jivo-public` (`S3_PUBLIC_MEDIA_BUCKET`).
  - It sets the anonymous `s3:GetObject` policy on the public bucket. This is the same policy `seed_demo` sets.
  - It then proves both buckets: a test object round-trips in each. An anonymous GET must return 403 on the private bucket and 200 on the public one.
- **Credentials:**
  - MinIO starts with `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` from the environment, or with the compose and `local.py` defaults.
  - If `backend/.env` sets `S3_ACCESS_KEY_ID`/`S3_SECRET_ACCESS_KEY`, export the same values as `MINIO_ROOT_*` before `start`.
- **Pins:**

  | Tool | Version | Source | sha256 |
  |---|---|---|---|
  | Mailpit | v1.33.0 | GitHub `axllent/mailpit` releases, `mailpit-windows-amd64.zip` | `47122dd828ff80dcaef62b2952c478b178afadadf066c990489608e537121bfd` (GitHub's published asset digest; the release ships no checksum file) |
  | MinIO server (pgsty community build) | `RELEASE.2026-08-04T00-00-00Z` (the same release as the compose image) | GitHub `pgsty/minio` releases (the repo is now named `pgsty/silo`; GitHub redirects), `minio_20260804000000.0.0_windows_amd64.tar.gz` | `c2160a4ccbb80ce1d45f69cc35137cb5ba68f638cc2f86ebfb3d0523ce3e0d74` (GitHub asset digest; matches the release's `_checksums.txt`) |

  To upgrade, change `Version`, `Url` and `Sha256` together in `$Pins`, as a reviewed change.
- **MinIO is an archived-upstream community build, for local dev only.**
  - Official `dl.min.io` returns **410 Gone** for every community build (checked 2026-11-04), and upstream open-source MinIO no longer gets security fixes.
  - The user approved the pgsty fork on 2026-11-04, for local development only. Never use it in staging or production; those use S3 (§6).
  - That release publishes no `mc`. `-Action init` uses boto3 instead, so no `mc` is needed.
  - Besides `127.0.0.1:9000`, MinIO also binds the IPv6 loopback `[::1]:9000`. That address is still local-only.
- **Check that it works:**
  - `curl http://127.0.0.1:8025/readyz` returns 200.
  - `uv run python manage.py sendtestemail you@example.com` (from `backend/`) delivers a message that shows up at `http://127.0.0.1:8025` and in `GET /api/v1/messages`.
  - For MinIO: `curl http://127.0.0.1:9000/minio/health/live`, then `-Action init`.

### Mobile apps (dev flavor)
- **Emulator:** the default dev API URL is `http://10.0.2.2:8001`.
- **Physical phone over USB:**
  ```bash
  cd customer_app      # or rider_app
  flutter build apk --flavor dev -t lib/main_dev.dart --dart-define=API_BASE_URL=http://localhost:8001
  adb install -r build/app/outputs/flutter-apk/app-dev-release.apk
  adb reverse tcp:8001 tcp:8001     # re-apply after reconnecting USB
  ```
- **Test login:** `+919000000001`, `…002` or `…003`, with OTP `123456` (local and test settings only).
- **Maps (Google Maps, DL-80; replaced Mappls/DL-29):** the customer app's Gradle build reads the Android Maps API key from the Gradle property or env var `MAPS_API_KEY`, else from `~/.config/jivo-quick-commerce/google-maps/android-api-key.txt` (outside the repo), and injects it through a manifest placeholder. Never put the key in a committed file (`gradle.properties`, the manifest, Dart code). Without a key the app still builds and falls back to manual address entry. Reverse geocoding uses the platform geocoder (no key). The key's restrictions are in §12.2 step 5. The old Mappls config in `~/.config/jivo-quick-commerce/mappls/` is unused.
- **iOS:** builds need a Mac with Xcode. The flavors/schemes aren't set up yet (`customer_app/README.md`).

### Ports in use on this host
- **This project:** Redis 6380, Django 8001, MinIO 9000/9001, Mailpit 1025/8025.
- **Agent instances:** the QA instance runs on 8004, and agents' smoke servers on 8002/8003.
- **Never use:** 6379, which is another project's `redis-chai`.

## 2. CI (GitHub Actions)
- **`backend.yml`:**
  - ruff, and the **env-example check** (`infra/scripts/check_env_example.py`). Every variable read in `backend/config/**` or `backend/apps/**` (tests excluded) must be listed in `infra/env/backend.env.example`. A new setting goes there with a placeholder and a comment, or CI fails.
  - `manage.py check` and `makemigrations --check`
  - migrations on a fresh PostGIS service DB, then pytest with coverage, **run in parallel**: `uv run --with pytest-xdist==3.8.0 pytest -n auto --create-db`.
    - Each xdist worker gets its own test DB (`…_gw0`, `…_gw1`, …) on the CI service container.
    - pytest-cov combines the workers' results, so the 80% `fail_under` applies to the whole suite.
    - `--with` adds xdist for the run only, so this works whether or not `pytest-xdist` is in `uv.lock` (T-408c).
    - **Worker count:** set by the repository variable `BACKEND_PYTEST_WORKERS` (Settings > Secrets and variables > Actions > Variables). If it's unset, CI uses `auto` (one worker per vCPU, 4 on `ubuntu-24.04`). Set it to `0` to run serially without editing the YAML, e.g. while investigating xdist-only flakes.
  - a schema-drift check
  - `check --deploy`, pip-audit, and a Docker build
  - Caching: `setup-uv` caches uv's downloads, keyed on `backend/uv.lock`.
- **`mobile.yml`:**
  - the shared-version check
  - the **Razorpay pin check** (`infra/scripts/check_razorpay_pins.py`). It requires:
    - `razorpay_flutter` exactly `1.4.7` in `customer_app/pubspec.yaml` and `pubspec.lock`
    - the Android set forced in `customer_app/android/app/build.gradle.kts`: `com.razorpay:checkout:1.6.41`, `standard-core:1.7.22` and `core:1.0.22`
    - no floating `com.razorpay` versions, and no Razorpay in `rider_app`

    Bumping these is a deliberate change. Re-run the release-build checks (R8 rules, merged manifest, Data Safety), then change the app and the pins in the script in the same reviewed change.
  - `pub get --enforce-lockfile` per project
  - an API-client drift check
  - analyze and test for the 4 projects
  - dev APK builds for both apps
  - Caching:
    - the Flutter SDK and `~/.pub-cache`, through `subosito/flutter-action`, keyed on every `pubspec.lock`
    - Gradle for the APK builds, through `setup-java` `cache: gradle`, keyed on each app's Gradle files
- **`infra.yml`** (paths `infra/**`): `bash -n` + shellcheck and a PowerShell parse of `infra/backup/`, the restore scripts' refusal of non-test targets and of names with a trailing newline (bash and PowerShell), `infra/scripts/test_entrypoint.sh` (a failing deploy check blocks start; `JQC_SKIP_STARTUP_CHECK` is refused under staging/production settings), a grep that rejects `JQC_SKIP_STARTUP_CHECK` in any env or compose file, ruff on the infra Python, `check_monitoring.py`, `promtool check rules` and `nginx -t` (pinned images by digest).
- **`deploy-staging.yml`** (manual, protected branches only, environment `staging` with required reviewers, §8.4): builds the production image tagged with the checked-out commit and runs its deploy checks against the real staging env file (§8.1); the deploy step is a placeholder until D-05.
- **`secret-scan.yml`** (every PR, pushes to `develop`/`main`, weekly, manual): gitleaks looks for committed secrets (§2.1).
- **`dependency-scan.yml`** (PRs and pushes that change a lockfile, weekly, manual): osv-scanner looks for known vulnerabilities in the locked dependencies of the backend, both apps and the shared packages (§2.2).
- **`release-android.yml`** (manual, protected `main`/`develop` only, environment `release`): signed prod-flavor AAB + APK per app with `--obfuscate --split-debug-info`; fails until the release secrets exist (§12).
- **Runner system libraries:** the backend test job installs `gdal-bin`, Pango and HarfBuzz with apt (the same set as `backend/Dockerfile`), because the DB engine is PostGIS and importing Django loads libgdal. Their versions follow the pinned `ubuntu-24.04` image.
- **PowerShell steps:** the runner wraps `shell: pwsh` scripts in `pwsh -Command` and appends `exit $LASTEXITCODE`; `pwsh -Command` turns any exit code other than 0/1 into 1. A step that runs a native command expected to fail must end with an explicit `exit 0`.
- **Pins and local runs:**
  - Every action is pinned by commit SHA, with its version in a comment. Downloaded tools (gitleaks, osv-scanner) are pinned by version and sha256.
  - Run the scripts locally with `python3 infra/scripts/<script>.py`. They use only the standard library and support `--help`.
  - Validate workflow edits with `uvx --from actionlint-py==1.7.12.25 actionlint`. With `shellcheck` on your PATH, actionlint also checks the `run:` scripts. **Known:** `backend.yml` then shows 4 old shellcheck warnings (SC2034, SC2155); the other workflows are clean.

### 2.1 Secret scanning (gitleaks)
**What it does.** The repo is public, so a committed secret is a published secret, even on a branch that is never merged. `secret-scan.yml` runs gitleaks with the repo-root `.gitleaks.toml`:
- **Rules:**
  - gitleaks' built-in rules (cloud keys, private keys, tokens, JWTs, `generic-api-key`, …).
  - Project rules for what the built-in set misses:
    - `jqc-razorpay-key-id`: Razorpay key ids.
    - `jqc-twilio-account-sid`: Twilio account SIDs.
    - `jqc-dotenv-secret`: a literal value for one of our secret settings (`POSTGRES_PASSWORD=…`, or `RAZORPAY_KEY_SECRET` passed with a value to `docker run -e`).
    - `jqc-db-url-password`: a password inside a `postgres://` or `redis://` URL.
    - `jqc-secret-file`: any of the gitignored secret files (`.env*`, signing keys, `*.local.json`, `qa/private/`, `*/incoming/`, and the legacy Mappls `*.a.olf/conf`), whatever it contains.
    - A Google Maps API key (`AIza…`) in any committed file is caught by gitleaks' built-in `gcp-api-key` rule (no project allowlist targets it).
- **What is scanned:**

  | Event | Commits | Plus |
  |---|---|---|
  | Pull request | the PR's commits (`base..head`) | the checked-out files |
  | Push to `develop`/`main` | the pushed commits (`before..after`); a new branch or a force-push falls back to the full history | the checked-out files |
  | Weekly (Mon 02:23 UTC) and manual | the full history of every branch and tag | the checked-out files |

  The checked-out-files scan exists because `git log -p` shows no diff for merge commits, so a secret typed into a merge-conflict fix would otherwise be missed.
- **Output:** always `--redact`. The log, the `::error` annotations and the job summary show only rule, file, line and commit, never the value. No report file is uploaded.
- **Config changes are flagged:** a PR or push that edits `.gitleaks.toml` or `infra/security/osv-scanner.toml` gets a warning, so the reviewer looks at the allowlist.
- **Schedule and manual runs** only work once the workflow file is on `main` (the default branch). GitHub also pauses schedules after 60 days without repo activity.

**Pins:**

| Tool | Version | Asset | sha256 |
|---|---|---|---|
| gitleaks (CI) | 8.30.1 | `gitleaks_8.30.1_linux_x64.tar.gz` | `551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb` |
| gitleaks (Windows, local) | 8.30.1 | `gitleaks_8.30.1_windows_x64.zip` | `d29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e` |

Both match the release's `gitleaks_8.30.1_checksums.txt` and GitHub's asset digest. The binary needs no licence; `gitleaks-action` would need one for an organisation, so we don't use it.

**If the scan finds a real secret:**
1. Treat it as leaked. Don't print or paste the value anywhere, including chat and tickets.
2. **Rotate it first:** revoke or regenerate it at the provider (§11.2 for our own keys), then update the secrets manager or `backend/.env`.
3. Replace the value in the code with a setting, an env variable or a `<placeholder>`.
4. Rewriting history does not un-publish it, and force-pushing `develop`/`main` breaks every clone. Do it only if the user asks.
5. So the full-history scan passes again, put the finding's **fingerprint** in a root `.gitleaksignore` file: one line `<commit>:<file>:<rule>:<line>` (the `Fingerprint` field of a local JSON report), with a `#` comment naming the rotation date and task. A fingerprint contains no value.

**If the scan flags something that is not a secret** (a test fixture, an example, a placeholder):
1. Prove it is fake, without printing it (open the file at that line). Good signs: the word EXAMPLE, an `example.com` host, a test-only folder, the documented fake scheme (06 §2.6). **If you are not sure, treat it as real.**
2. Best fix: make the value obviously fake at the source, so no allowlist is needed. For example `rzp_test_EXAMPLEEXAMPLE`, `AC` + 32 zeros, `NAME=<placeholder>`.
3. Otherwise add an entry under "allowlists" in `.gitleaks.toml`:
   - `targetRules` = only the rule id from the finding.
   - The narrowest match: the exact value in `regexes`, plus `paths` with `condition = "AND"` when the value alone isn't enough.
   - A comment saying why it is safe.
   - **Never** allowlist a whole folder for every rule, skip `commits`, or add `stopwords` that real values could contain.
4. Re-run the local full-history scan (below). The CI warning makes the reviewer check the entry.

**Run it locally** (from the repo root; `.gitleaks.toml` is found automatically). Download the pinned binary once, outside the repo, and check its sha256. On Windows use the zip above, for example in `%USERPROFILE%\.local\share\jivoqc-tools\gitleaks\8.30.1\`.
```bash
v=8.30.1; curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$v/gitleaks_${v}_linux_x64.tar.gz"
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks_${v}_linux_x64.tar.gz" | sha256sum -c - \
  && tar -xzf "gitleaks_${v}_linux_x64.tar.gz" gitleaks
gitleaks git . --redact                      # full history of every branch (what the weekly run does)
gitleaks git . --redact --log-opts="--full-history --diff-filter=tuxdb main..HEAD"   # only your branch
gitleaks git . --redact --report-format json --report-path /tmp/gitleaks.json   # findings with fingerprints
```
- Always pass `--redact`.
- Don't run `gitleaks dir .` on your working copy. It also reads the gitignored secret files (`backend/.env`, `key.properties`, any local key files) and reports them. To scan only committed files, run it on an export: `git archive HEAD | tar -x -C /tmp/jqc-tree && (cd /tmp/jqc-tree && gitleaks dir . --redact)`.

### 2.2 Dependency advisories (osv-scanner)
**What it does.** `dependency-scan.yml` checks the locked versions in these lockfiles against the OSV database (GitHub advisories, PyPA, Pub, …):
- `backend/uv.lock`
- `customer_app/pubspec.lock` and `rider_app/pubspec.lock`
- `packages/*/pubspec.lock`

pip-audit in `backend.yml` stays: it covers only Python, and osv-scanner adds the Flutter side.
- **Pass or fail:** osv-scanner has no severity threshold, so `infra/scripts/osv_gate.py` rates every advisory:
  - It uses the CVSS score: ≥ 9.0 CRITICAL, ≥ 7.0 HIGH, ≥ 4.0 MEDIUM, otherwise LOW.
  - The GitHub label wins when it is higher, or when there is no score.
  - A `MAL-*` id (a known malicious package) is always CRITICAL.
  - **HIGH and CRITICAL fail the job.** MEDIUM, LOW and unrated (UNKNOWN) advisories become warnings.
  - Everything is listed in the job summary with the fixed versions.
  - The gate runs `--self-test` first, so a broken gate cannot pass silently.
- **When it runs:** PRs and pushes to `develop`/`main` that change a lockfile, the gate or the config. Weekly (Mon 02:41 UTC) and manually it scans **both `main` and `develop`**, because new advisories appear without any code change.
- **Exceptions:** only in `infra/security/osv-scanner.toml`, which CI passes with `--config`. So an `osv-scanner.toml` dropped next to a lockfile cannot hide anything.

**Pins:**

| Tool | Version | Asset | sha256 |
|---|---|---|---|
| osv-scanner (CI) | 2.7.0 | `osv-scanner_linux_amd64` | `160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b` |
| osv-scanner (Windows, local) | 2.7.0 | `osv-scanner_windows_amd64.exe` | `9964ed64ec9a387391eb4cc006ad5c531154821aef29b793e02c448de4686438` |

Both match the release's `osv-scanner_SHA256SUMS` and GitHub's asset digest. We pinned 2.7.0, not 2.7.1, because 2.7.1 was one day old on 2026-11-10.

**If an advisory fails the job:**
1. **Upgrade** the package. The lockfile's owner does it:
   - Backend: `uv lock --upgrade-package <pkg>` in `backend/`, then the tests.
   - Flutter: `flutter pub upgrade <pkg>` in every project that uses it. Then run `python3 packages/tool/check_shared_versions.py`, because the four lockfiles must agree.
2. If there is no fixed version yet, or the vulnerable code is provably never called, add a **reviewed exception** to `infra/security/osv-scanner.toml`. It needs the advisory `id`, `ignoreUntil` at most 90 days ahead, and a `reason` naming the task that removes it. The file has an example. osv-scanner logs every exception it applies.

**Run it locally** (from the repo root; Windows: the `.exe` above):
```bash
v=2.7.0; curl -fsSLo osv-scanner "https://github.com/google/osv-scanner/releases/download/v$v/osv-scanner_linux_amd64"
echo "160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b  osv-scanner" | sha256sum -c - && chmod +x osv-scanner
./osv-scanner scan source --config infra/security/osv-scanner.toml \
  -L backend/uv.lock -L customer_app/pubspec.lock -L rider_app/pubspec.lock \
  -L packages/jivo_core/pubspec.lock -L packages/jivo_api/pubspec.lock \
  --format json --output-file /tmp/osv.json
python3 infra/scripts/osv_gate.py /tmp/osv.json   # same pass/fail as CI; --fail-on critical|high|medium|low
```
For a quick look, use `--format table` instead of the JSON output.

**Upgrading either scanner:**
1. Pick a release that is at least about two weeks old.
2. Take the sha256 from the release's own checksum file, and confirm it matches GitHub's asset digest.
3. Change the version and the sha256 together, in the workflow's `env` and in the tables above.
4. Re-run both local scans. In the same change, look at what the new version adds or deprecates (for example, osv-scanner 2.7.1 renames `ignoreUntil` to `effectiveUntil`).

## 3. Branches and releases
- The flow is `main` ← module branches (`development-phase.md` §9.4, DL-79). `develop` is stale since 2026-11-16; the workflows below still accept it, but it is no longer used.
- A phase gate is CI green on `main`, plus QA "Ready" and the sign-off in the roadmap.
- Release tags and deploy jobs are added when staging exists.

## 4. Processes (every environment)
There is one image (`backend/Dockerfile`) and three process types (doc 02). **All three run in every environment:** local compose, staging and production. In the production image every container first runs `manage.py check --deploy --fail-level ERROR` against its real environment (the `jqc-entrypoint`, §8.1). Without beat, unpaid online orders never expire and their reserved stock is never released.

| Process | Command | Replicas | DB connections (T-218) |
|---|---|---|---|
| `release` (one-off, once per deploy) | `jqc-release`: `check --deploy --fail-level ERROR`, then `migrate` (§8) | 1 task, before the others roll | as `worker` |
| `web` (ASGI) | image default: `gunicorn config.asgi:application -k jqc_asgi_worker.JqcUvicornWorker --no-control-socket` (uvicorn with `ws_max_size` and no access log, §9.4; no `gunicornc` control socket, the non-root user has no writable `$HOME`) | 2+ (rolling) | `POSTGRES_POOL=true`, `POSTGRES_CONN_MAX_AGE=0` |
| `worker` | `celery -A config worker -l INFO` | 1+ | `POSTGRES_POOL=false`, `POSTGRES_CONN_MAX_AGE=60` |
| `beat` | `celery -A config beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler` | **exactly 1** | same as `worker` |

- **Beat is a singleton.** Two beats would enqueue every periodic task twice, so never scale it above 1. On deploy, stop the old beat before starting the new one. A few seconds without beat does no harm, because the jobs catch up on the next tick.
- **Scheduler:** beat uses django-celery-beat's `DatabaseScheduler` (`CELERY_BEAT_SCHEDULER` in settings).
  - At start it syncs `CELERY_BEAT_SCHEDULE` into its tables, so run `migrate` before (re)starting beat.
  - Changes made in the admin's Periodic Tasks screen persist. Entries defined in `CELERY_BEAT_SCHEDULE` are re-synced at each start.
- **Current schedule** (`backend/config/settings/base.py`, times in UTC):
  - `orders.expire_unpaid_orders`: every 60 s (06 §5)
  - `accounts.anonymise_deleted_accounts`: 21:30
  - `accounts.purge_old_otp_requests`: 21:45
  - Phase 4 adds `sync_refund_status` (backend agent).
- **Check that beat is running:**
  - In `/admin/` > Periodic Tasks, `expire-unpaid-orders` is enabled and its `last_run_at` is under 2 minutes old.
  - The worker log shows `orders.expire_unpaid_orders` succeeding every minute.
  - Alert if `last_run_at` is more than 5 minutes old (`09 §5`).
- **Staff MFA (H2) rollout:** run `migrate` (it creates the django-otp tables `otp_totp_totpdevice`, `otp_static_staticdevice`, `otp_static_statictoken`) **before** starting web processes whose settings enable `STAFF_MFA_ENFORCED`; the middleware queries those tables on every privileged staff request. Set `STAFF_MFA_ENFORCED=false` in the local dev and QA `.env`; leave it on (the default) in staging and production. The recovery-code table holds plain-text codes: include it in the secret-handling rules for backups (09 §3.1).
- **Connection budget:** the DB server is shared. `web processes x POSTGRES_POOL_MAX_SIZE + worker concurrency + 1 (beat)` must stay under its connection limit.

## 5. Razorpay webhook (staging runbook, not done yet)
This is prepared for when staging exists (D-05) and the Razorpay test keys arrive (D-01). **Don't configure it until the user approves staging.** For production, repeat the steps in **live mode** with a different secret (`release-checklist.md` §7).

1. In the Razorpay Dashboard, switch to **Test mode** and open Account & Settings > Webhooks > Add New Webhook.
2. **Webhook URL:** `https://<staging-api-host>/api/v1/payments/razorpay/webhook/`. It must be HTTPS and publicly reachable, and it includes the trailing slash. nginx or the load balancer passes the body through unchanged, which the signature check needs.
3. **Secret:**
   - Generate one with `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`.
   - Paste it into the dashboard, and store the same value as `RAZORPAY_WEBHOOK_SECRET` in the staging secrets manager.
   - Never commit it, and never paste it into chat, tickets or logs.
4. **Active events:** subscribe to exactly the events that `apps/payments/services.py` handles. Any other event is stored and ignored.
   - `payment.captured`: marks the order paid. The verify call and the webhook can arrive in either order; whichever comes second is a no-op.
   - `payment.failed`: records the failed attempt.
   - `refund.processed` and `refund.failed`: update the refund status.
5. **Alert email:** use the on-call or payments address, so the email Razorpay sends after disabling a webhook for repeated failures reaches someone.
6. **Other staging settings:** `PAYMENT_GATEWAY=apps.payments.gateways.RazorpayGateway`, `RAZORPAY_KEY_ID` (`rzp_test_…`) and `RAZORPAY_KEY_SECRET`. Keep them in the secrets manager only (`09 §3`).
7. **Verify:**
   - Place a test-mode online order and pay with a Razorpay test card.
   - In `/admin/` > Payment webhook events, there is one row per `X-Razorpay-Event-Id`, and the order is now paid.
   - Re-send the same event from the dashboard. The response is `200` with `{"status": "duplicate"}`, and nothing changes.

**Responses and monitoring:**
- `200`: the event was processed (`processed`), was already handled (`duplicate`), or was not acted on (`ignored`: an unhandled event type or an unknown order).
- `400`: the signature is bad, `X-Razorpay-Event-Id` is missing, or the body isn't a Razorpay event. Nothing is stored. A burst of 400s usually means the secrets no longer match after a rotation, so alert on it.
- `503`: the backend is asking Razorpay to **retry later** after a transient failure while processing. This is expected and **not an outage alert**: Razorpay retries with back-off. Alert only if 503s go on for more than about 15 minutes. Other endpoints returning 5xx still alert as usual.

**Secret rotation:**
1. Set the new secret in the dashboard and in the secrets manager.
2. Roll the `web` processes.
3. Events signed while the two don't match fail with 400, and Razorpay retries them. So rotate in a quiet window, and check the webhook-events list afterwards.

## 6. Staging and production (target; to be implemented once D-05 is decided)
- **Hosting:** the default recommendation is AWS ap-south-1:
  - ECS/EC2 for the `web` (ASGI), `worker` and `beat` processes
  - RDS PostgreSQL + PostGIS
  - ElastiCache Redis
  - S3 + CloudFront: a public bucket for product images, private buckets for KYC files and invoices
  - nginx or an ALB for TLS
- **Secrets:** a secrets manager, with separate keys per environment. Production refuses `OTP_TEST_NUMBERS` (except the reviewer number, D-15).
- **Deploys:** zero-downtime rolling deploys, backward-compatible migrations, and a backup + PITR **restore test before launch**. Every environment runs the three processes in §4, with exactly one beat.
- **Apps:** staging/prod flavors need `--dart-define=API_BASE_URL=https://…`. Distribution goes through Firebase App Distribution or Play internal testing, then the stores.

## 7. Backup and restore (P8, T-813; `09 §2`)

A backup only counts once a restore of it has passed `verify_restore.py` (§7.3). Nothing here creates cloud resources: bucket names, KMS keys and retention settings are applied when D-05 is approved.

### 7.1 Targets
`09 §2` sets daily backups with 7–30 days of point-in-time recovery and 99.5% monthly uptime, but no explicit RPO/RTO. **Proposed (⚠ to confirm with the user/Jivo):**

| Data | RPO (data we may lose) | RTO (time to serve again) | How |
|---|---|---|---|
| PostgreSQL + PostGIS | ≤ 5 min | ≤ 1 h | managed PITR (continuous WAL archiving) + daily snapshots |
| PostgreSQL, logical copy | ≤ 24 h | ≤ 4 h | daily `pg_dump -Fc` to a separate bucket (protects against a deleted instance or a bad PITR window) |
| Object storage (KYC, invoices, media) | 0 for overwrites and deletes (versioning) | ≤ 1 h | bucket versioning + lifecycle |
| Redis | not backed up | minutes (empty start) | see §7.5 |

### 7.2 PostgreSQL
- **Managed PITR (primary mechanism).** On RDS (the D-05 default): automated backups on, **retention 14 days** (inside 09's 7–30), backup window 20:30–21:00 UTC (02:00–02:30 IST, the quietest hour). Copy snapshots to a second region only if the user approves the cost. PITR always restores into a **new** instance; you then repoint `POSTGRES_HOST`.
- **Logical dumps (second line).** `infra/backup/backup_db.sh` (or `backup_db.ps1`) once a day from a scheduled job inside the VPC, uploading to `BACKUP_UPLOAD_URI` (an S3 prefix in a bucket the app's role cannot write or delete). Keep 35 daily and 12 monthly dumps.
  - Each run writes `<db>_<UTC stamp>.dump` (`pg_dump -Fc`), a `.sha256` per dump and a `.manifest.json` (server, PostGIS and pg_dump versions, repo commit, sizes, checksums). It never overwrites a file and refuses an output directory inside the git repo.
  - `--schema-only` (no PII) also writes `<base>.migrations.dump` with the `django_migrations` rows, so a schema-only restore can still be checked for migration state. Used for restore drills on shared servers.
  - Use the same PostgreSQL client major as the server, or newer. pg_restore 17+ into PostgreSQL 16 issues `SET transaction_timeout`, which the server rejects; the restore scripts tolerate exactly that error and fail on any other.
  - A full dump contains PII (phones, addresses; KYC and bank numbers stay Fernet-encrypted). Never write it inside the repo (the scripts refuse) or to a laptop; only to encrypted storage.
  - `--upload` is a placeholder until D-05: it supports `s3://` (AWS CLI, `--sse aws:kms`) and exits 3 when `BACKUP_UPLOAD_URI` is unset.
- **Restore into a named database, never over the live one:**
  ```bash
  # restore drill (refuses every target except test_jivo_quick_commerce_restore*)
  infra/backup/restore_db.sh --env-file backend/.env --dump <dir>/<db>_<stamp>.dump \
      --target-db test_jivo_quick_commerce_restore_check --drop-existing --verify --source-db jivo_quick_commerce
  infra/backup/restore_db.sh --env-file backend/.env --target-db test_jivo_quick_commerce_restore_check --drop-only

  # production disaster recovery (user approval first): always into a NEW database
  infra/backup/restore_db.sh --dump <file> --target-db jivo_quick_commerce_restored_20261201 \
      --production --confirm "RESTORE INTO jivo_quick_commerce_restored_20261201" --verify
  ```
  PowerShell: the same options in PascalCase (`-EnvFile`, `-Dump`, `-TargetDb`, `-DropExisting`, `-DropOnly`, `-Verify`, `-SourceDb`, `-Production`, `-Confirm`, `-DryRun`); `Get-Help infra\backup\restore_db.ps1 -Full`.
  - **Safety rules (both scripts):** the target must match `test_jivo_quick_commerce_restore*` unless `--production` and the exact phrase `RESTORE INTO <target>` are given; a production target must not exist yet; only `test_jivo_quick_commerce_restore*` databases can ever be dropped; the dump's `.sha256` must match before anything is created; database names are restricted to `[a-z0-9_]`.
  - **Production restore runbook:**
    1. Declare the incident. Stop `beat` and `worker`, so no jobs run on a half-restored database.
    2. PITR to a new instance at the chosen time, **or** `restore_db.sh --production` into a new database from the latest good dump.
    3. `verify_restore.py --target-db <new> --full` must pass.
    4. Point `POSTGRES_HOST`/`POSTGRES_DB` at it and roll `web`, then `worker`, then the single `beat`.
    5. Run `anonymise_deleted_accounts` once: a restored backup may hold accounts erased after it was taken (DPDP).
    6. Reconcile payments for the lost window from the Razorpay dashboard. Webhooks are idempotent, so re-send them.
    7. Keep the old instance read-only for 7 days, then delete it.
- **Restore test cadence:** before go-live (release checklist §3), then quarterly and after any PostgreSQL or PostGIS major upgrade. Record each run in the log below.

### 7.3 `verify_restore.py`
Read-only: every transaction is `READ ONLY`, on the target and on the source. Run `uv run --project backend python infra/backup/verify_restore.py --target-db <db> [--source-db <db>] [--env-file backend/.env] [--counts] [--json]`. Exit 0 = OK (warnings allowed), 1 = a check failed, 2 = usage or connection error.
- PostGIS is installed; the exact row count of every `public` table (`--counts` prints them).
- Migration state: `django_migrations` exists and is not empty. With `--source-db`, the applied migrations, tables, columns, constraints and indexes must equal the source's (and row counts for a full restore; a live source keeps changing, so a row-count difference is a warning).
- Key money and stock constraints exist (`storeinventory_reserved_within_on_hand`, `payment_amount_positive`, …).
- Business invariants (08 §6, like QA's read-only SQL): `on_hand` = Σ `StockMovement.delta`; the latest `on_hand_after` = `on_hand`; `reserved` = Σ ACTIVE reservations; `0 ≤ reserved ≤ on_hand`; the 08 §6.2 bill formula; `product_discount = mrp_total − item_total`; no negative amounts; `amount_refunded ≤ amount_paid`; refunds never exceed their payment. Warnings: ACTIVE reservations on terminal orders, duplicate captures without a refund, orders without status history. Tables a later phase adds are skipped, not failed.

**Restore test log**

| Date | Who | Source | Mode | Target | Result |
|---|---|---|---|---|---|
| 2026-11-04 | devops agent (T-813) | shared dev DB (PostgreSQL 16.15, PostGIS 3.4.2) | schema-only + `django_migrations` rows; bash and PowerShell scripts | `test_jivo_quick_commerce_restore_check`, dropped afterwards | ✅ 25/25 checks: 69 tables, 90 migrations, 682 columns, 265 constraints and 280 indexes equal to the source; restore 8 s. A read-only invariant run on the dev DB itself (10,356 rows): 0 violations. **A full-data restore test is still required before launch** (needs staging/production, D-05). |

### 7.4 Object storage (S3 in staging/production; MinIO locally)
| Bucket | Holds | Protection |
|---|---|---|
| private (`S3_MEDIA_BUCKET`) | KYC documents, invoices (GST PDFs), other private files | Block Public Access; SSE-KMS; **versioning on**; lifecycle: noncurrent versions expire after **30 days** (so `purge_offboarded_kyc` and DPDP erasure really complete), incomplete multipart uploads after 7 days. Invoices are statutory records (GST: keep at least 72 months). **⚠ D-12:** decide whether invoices get Object Lock (governance mode) on their own bucket or prefix. |
| public (`S3_PUBLIC_MEDIA_BUCKET`) | product, category and banner images | versioning on, noncurrent versions expire after 30 days; also recoverable from Jivo's catalog sources (`data/`) |
| backups (new, D-05) | daily `pg_dump` files, checksums, manifests | separate bucket, SSE-KMS, versioning, writable only by the backup job's role, no delete for the app role; lifecycle 35 days daily, 12 months monthly |

Cross-region replication of the private bucket is optional and doubles its storage cost: ask the user. To restore an object, copy its previous version back (`aws s3api list-object-versions`).

### 7.5 Redis: what is and isn't backed up
Nothing in Redis is a system of record (09 §2), so it is **not backed up** and runs without persistence (`--save "" --appendonly no`, as in compose):
- **Cache** (catalog and home per store, serviceability snapshot, app config): rebuilt on demand from PostgreSQL.
- **Celery broker:** tasks in flight are lost with Redis. They are idempotent, and the critical ones are re-derived from the DB by beat: `expire_unpaid_orders` (stock release), `sync_refund_status`, `auto_accept_orders`, and the Phase 6 stuck-notification sweeper.
- **Channel layer and rider latest locations:** ephemeral. Apps fall back to polling; a rider's next ping restores the position.
- **OTP throttling counters:** losing them only resets the limits. OTP codes are in PostgreSQL (`accounts_otprequest`, hashed). OTP sends fail closed while Redis is down (DL-13).

### 7.6 Access and encryption
- Encryption at rest everywhere: RDS storage encryption (KMS), S3 SSE-KMS, encrypted volumes for any worker scratch space. In transit: `POSTGRES_SSLMODE=require` (or `verify-full` with the RDS CA) in staging and production.
- Backups are readable only through the on-call break-glass role, with access logged (CloudTrail). The backup job's role can write new objects but not delete them.
- The scripts read credentials from the libpq variables or `--env-file` (only the `POSTGRES_*` connection keys are read), never print them, and print neither host nor role unless `JQC_SHOW_HOST=1`. Dumps are created with umask 077 (bash) or a user-only ACL (PowerShell).

### 7.7 Staging nightly backups (`jqc.jivo.in`, since 2026-11-16)
- **Schedule:** `30 2 * * *` (02:30 IST; the server clock is IST) in the `superadmin` user's own crontab. It is not a root or system cron. A copy of the crontab from before the change is at `/srv/jqc/logs/crontab-superadmin-before-backup-20261116.txt`.
- **Job:** `/srv/jqc/tools/backup-nightly.sh` (server only, mode 700). It runs `infra/backup/backup_db.sh` from `/srv/jqc/tools/f6ed556/` (shipped from `main` with `git -c core.autocrlf=false archive`) in a one-off `postgis/postgis:16-3.4` container on `jqc_net` (`--rm`, 512 MB cap, runs as `superadmin`). The connection keys come from `/srv/jqc/env/backend.env`, mounted read-only. After the dump it checks `sha256sum -c` and `pg_restore -l`. A `flock` stops two runs from overlapping.
- **Output:** `/srv/jqc/backups/nightly/` (dir 700, files 600). Each run writes `jivo_quick_commerce_<UTC stamp>.dump`, `.dump.sha256` and `.manifest.json`.
- **Retention:** 14 days. Only after a verified dump, it deletes files older than 14 days that match `jivo_quick_commerce_<stamp>Z.(dump|dump.sha256|manifest.json)` in that folder. The pre-deploy dumps in `/srv/jqc/backups/` are never touched.
- **Logs:** `/srv/jqc/logs/backup-nightly.log`; failures also go to `journalctl -t jqc-backup-nightly`. First run: 2026-11-16 05:50 UTC, 792,537 bytes, sha256 OK, 948 TOC entries.
- **Upgrade the tools:** ship the new commit to `/srv/jqc/tools/<sha>/` and change `TOOLS=` in the job script.
- **Disable:** remove the two `JQC staging` lines with `crontab -e`. The dumps stay where they are.
- **Gap:** every copy is on the same disk as the database, so a lost server loses the backups too. Offsite copies wait on Jivo (D7). MinIO is not mirrored yet.

## 8. Deploy, release step and rollback

### 8.1 Deploy-time configuration checks (P8 OWASP M8)
CI runs `check --deploy` with placeholder values, so it cannot catch a real environment that is misconfigured. Two places now run the checks against the **real** environment:
- **`jqc-entrypoint`** (the production image's `ENTRYPOINT`): every `web`, `worker` and `beat` container runs `python manage.py check --deploy --fail-level ERROR` before its command starts. A failing check stops the container, so a rolling deploy halts with the old version still serving. At ERROR level, deploy warnings are printed but not fatal. It catches `accounts.E003` (console SMS backend), `payments.E001`/`E004` (fake gateway, `FAKE_GATEWAY_DOWN`), `delivery.E001` (no `FIELD_ENCRYPTION_KEYS`) and `notifications.E001` (dev push backend), as those checks land from the backend branches, plus every other registered error. **`JQC_SKIP_STARTUP_CHECK=1` is for local/dev settings only**, where it skips the check with a loud WARNING. Under `config.settings.staging`, `production` or `deployed` the entrypoint **refuses** it for every command (gunicorn, uvicorn, celery, `jqc-release`, anything) and exits 64. It must never appear in a service env file, compose file or secret: CI rejects it in env and compose files, and the staging preflight rejects it in `STAGING_BACKEND_ENV`. Break-glass during an incident is an explicit `--entrypoint python` override on a one-off task, which the orchestrator records.
- **`jqc-release`** (the release task, §8.2) runs the same check before `migrate`.
- **Staging deploy job** (`.github/workflows/deploy-staging.yml`, manual only, GitHub environment `staging`): builds the image and runs it once with the staging environment (the `STAGING_BACKEND_ENV` environment secret, a `KEY=value` env file), so the entrypoint's check runs before anything is deployed. The deploy step itself fails with "not configured" until D-05.
- Some checks skip themselves when `DJANGO_ALLOWED_HOSTS` lists only reserved example hosts (CI's dry run). Real environments must list their real hosts, or those checks never fire.

### 8.2 Release order (zero downtime)
1. Build and push the image tagged with the git SHA. Set `SENTRY_RELEASE` to the same SHA.
2. Run the **release task** once: `jqc-release` (deploy checks, then `migrate --noinput`). Migrations must stay compatible with the running version: expand now, contract in a later release (add nullable columns or columns with defaults, backfill in a task, drop a column only once no running code reads it).
3. Roll `web`: health check `/health/ready`, at least 2 replicas, 30 s drain (`--graceful-timeout 30`).
4. Roll `worker`: Celery's warm shutdown finishes running tasks (`CELERY_TASK_TIME_LIMIT` is 5 min).
5. Stop the old `beat`, then start the new one (never two, §4).
6. Smoke: `/health/ready`, `/api/v1/config/app/`, a test-number OTP login on staging, and the new release visible in Sentry.

### 8.3 Rollback
- **Code:** redeploy the previous image tag (steps 3–5). Because migrations are expand-only, the previous version runs against the new schema.
- **A migration must be reverted:** only when it is reversible and data-safe: `manage.py migrate <app> <previous>` as a one-off task, then roll back the code. Otherwise fix forward.
- **Data damage:** the production restore runbook (§7.2).
- The release checklist §8 names the rollback owner for each deploy window.

### 8.4 Who can run the staging deploy
`deploy-staging.yml` is `workflow_dispatch` only, and its jobs run only when dispatched on a **protected** `develop` or `main` (`github.ref_protected`); it deploys exactly that commit, and the image tag is `git rev-parse HEAD` of the checkout. One-time GitHub setup (repository admin, no cost):
1. Branch protection on `develop` and `main` (PR required, CI green, no force-push).
2. Settings > Environments > `staging`: **required reviewers** (at least one person other than the dispatcher; tick "Prevent self-review"), and **deployment branches** limited to `develop` and `main`.
3. Store `STAGING_BACKEND_ENV` (and later the cloud deploy credentials, preferably OIDC rather than keys) as **environment** secrets of `staging`, never repository secrets, so only an approved run can read them.
4. Later, `deploy-production.yml` follows the same pattern with a `production` environment, `main` only, and two reviewers.

## 9. Edge proxy hardening (`infra/nginx/default.conf`, P8 OWASP review)

### 9.1 Rate limits, connection limits and body sizes (H3, edge half)
These are coarse per-IP limits. The backend keeps its own per-user and per-phone throttles, which return the real error codes (06 §6). The limits are generous because mobile carriers put many users behind one CGNAT address.

| Location | Limit per IP | Burst | Max body |
|---|---|---|---|
| `/api/v1/auth/otp/request/` only (each costs an SMS) | 60 req/min (`jqc_otp`); 429 `OTP_RATE_LIMITED` | 30 | 16 KB |
| `/api/v1/auth/otp/verify/` | the general API zone (the backend limits attempts per OTP, per phone and per IP) | 40 | 2560 KB |
| `/api/v1/search/` (search, suggest) | 5 req/s | 20 | 16 KB |
| `/api/v1/rider/documents/` | 20 req/s | 10 | 1200 KB (1 MB image + multipart overhead; `RIDER_DOCUMENT_MAX_BYTES`) |
| `/api/v1/payments/razorpay/webhook/` | none (signed, idempotent, Razorpay retries) | n/a | 256 KB |
| `/api/v1/support/tickets/<id>/attachments/` (regex location; customer and rider ticket photos) | 20 req/s | 40 | 5300 KB (5 MB photo + multipart overhead; `SUPPORT_ATTACHMENT_MAX_BYTES`) |
| `/api/` (all other) and `/` | 20 req/s | 40 | 2560 KB (= `DATA_UPLOAD_MAX_MEMORY_SIZE`, 2.5 MB) |
| `/admin/`, `/ops/` | 10 req/s | 40 | 6 MB (product images up to 5 MB, 09 §3.6) |
| `/ws/` | **50 concurrent sockets** (`limit_conn`); upgrades 20 req/s | 20 | 64 KB |
| `/health/` | none; not logged | n/a | default |

Over a limit, nginx answers 429 with the JSON error envelope and `Retry-After: 60`; an oversized body gets 413 `PAYLOAD_TOO_LARGE`.

**Behind a load balancer, the `set_real_ip_from <lb-subnet>` block (with `real_ip_header X-Forwarded-For` and `real_ip_recursive on`) MUST be set.** Without it every request appears to come from the balancer, all clients share one OTP bucket and one 50-socket bucket, and the first busy minute locks everyone out. Leave it commented only when nginx itself faces the internet. Check after setting it: the nginx access log's `remote_addr` shows client addresses, not the balancer's.

**Load-balancer equivalents,** if nginx is dropped (D-05):
- **AWS:** WAF on the ALB with rate-based rules per IP (5-minute windows: e.g. 300 for `/api/v1/auth/otp/request/`, 6,000 for `/api/`, using URI scope-down statements) and the AWS managed core rule set. Body limits through WAF size-constraint rules (2.5 MB; 1.2 MB on `/api/v1/rider/documents/`; 5.3 MB on `/api/v1/support/tickets/<id>/attachments/`). ALB idle timeout 3600 s for WebSockets. An ALB has no per-IP connection cap, so keep nginx in front of `/ws/` or enforce the cap in the app.
- **Cloudflare:** rate-limiting rules per path, WAF managed rules, and a WAF rule on `http.request.body.size`.
- **GCP:** Cloud Armor rate-based throttle or ban rules per path.

### 9.2 Access logs without query strings (L8)
- nginx logs JSON with `$uri` (path only, no query string), because serviceability and notify-me carry lat/lng in the query string. There is no `$request`, `$request_uri` or `$args` in the format.
- The app server writes **no** access log. uvicorn's access line holds the full request line, so the image's worker class `jqc_asgi_worker.JqcUvicornWorker` sets `access_log=False` (gunicorn's own `--access-logformat` does not apply to uvicorn workers). The edge log is the access log of record; requests are correlated by `X-Request-ID` (`$request_id`).
- An ALB's access logs contain the full request line, query string included. If ALB access logs are enabled, restrict that bucket to on-call and give it a 30-day lifecycle, or log at nginx only.

### 9.3 No token-bearing headers in logs (L11)
No proxy log format includes `Sec-WebSocket-Protocol`, `Authorization` or `Cookie`: nginx logs no `$http_*` request header except `User-Agent`, and the app server logs no requests. The socket JWT travels in the first message anyway. Adding a header to a log format needs a review.

### 9.4 WebSocket message size (L5)
uvicorn's default `ws_max_size` is 16 MiB. The image's worker class sets it to **64 KiB** (override with `WS_MAX_MESSAGE_BYTES`), since our socket messages are small JSON. A larger frame closes the socket with code 1009. Local `runserver` (Daphne) keeps its defaults; deployed environments never run Daphne.

### 9.5 `NUM_PROXIES` per topology (L1)
`NUM_PROXIES` is the number of proxies in front of Django that append to `X-Forwarded-For`. DRF and the OTP and lockout limits take the client IP at that position from the right. A value that is too high trusts a spoofed header; one that is too low rate-limits the proxy instead of the client. `deployed.py` requires it explicitly.

| Topology | `NUM_PROXIES` |
|---|---|
| Internet → nginx → Django | 1 |
| Internet → load balancer (ALB) → nginx → Django | 2 |
| Internet → load balancer → Django (no nginx) | 1 |
| Internet → CDN (CloudFront/Cloudflare) → load balancer → nginx → Django | 3 (only if the CDN fronts the API; otherwise 2) |

nginx keeps `X-Forwarded-For $proxy_add_x_forwarded_for` in every topology, including with `set_real_ip_from`, so these counts hold. After any topology change, send a request with a spoofed `X-Forwarded-For: 1.2.3.4` and confirm the OTP throttle keys on your real IP.

## 10. Monitoring and alerting (`09 §2`, `§5`; `infra/monitoring/`)

### 10.1 Sentry (D-19)
- Already wired: `config/sentry.py`, called from `deployed.py` (staging and production only), with `send_default_pii=False` and no frame locals.
- **Environment names:** `SENTRY_DSN` (secret; empty disables Sentry), `SENTRY_ENVIRONMENT` (defaults to the settings module, `staging` or `production`), `SENTRY_RELEASE` (set by the deploy to the git SHA), `SENTRY_TRACES_SAMPLE_RATE`.
- **Sample-rate policy:** errors are always sent at 100% (the SDK's default `sample_rate`). Traces: **0.2 in staging and 0.05 in production** at launch, lowered if the Sentry quota is reached; never 1.0 in production. `/health/*` should be excluded from tracing (backend ask, §10.3).
- **Apps:** a DSN per Sentry project and flavor (`--dart-define=SENTRY_DSN=…`), with release = app version + build. Owned by the app agents.

### 10.2 Probes
`/health/live` checks only the process (use it for liveness and restarts). `/health/ready` checks PostgreSQL (`SELECT 1`) and Redis (`PING`) and answers 503 otherwise: use it for the load balancer's target health and for the `JqcApiNotReady` alert (blackbox exporter `probe_success{job="jqc-health-ready"}`). Both are exempt from the HTTPS redirect and are neither rate limited nor logged at the edge.

### 10.3 Metrics
Catalogued in `infra/monitoring/metrics.yml` (name, type, labels, source, status):
- **Request latency p95 per route** and request/5xx counters: `jqc_http_request_duration_seconds` and `jqc_http_requests_total`. **Needs backend:** a `/metrics` endpoint (prometheus_client in multiprocess mode, `PROMETHEUS_MULTIPROC_DIR`) on an internal port or path that nginx does not expose, with `route` = the resolver's URL pattern, never the raw path (no ids or PII in labels).
- **WebSocket connections:** `jqc_ws_connections{consumer}`. **Needs backend:** a gauge updated in the consumers' connect and disconnect (`livesum`).
- **Celery queue depth, task failures, live workers:** `celery_queue_length`, `celery_task_failed_total` and `celery_worker_up` from a `celery-exporter` sidecar. **Needs backend settings** `CELERY_WORKER_SEND_TASK_EVENTS=True` and `CELERY_TASK_SEND_SENT_EVENT=True` (queue length works without them).
- **Beat liveness (`last_run_at`), refund FAILED count, stuck notifications, order SLA breaches** and other business counts: `infra/monitoring/sql_exporter/jqc_business.collector.yml`, all read-only aggregates. Every query was run read-only against the dev DB on 2026-11-04; the two notification queries wait for the Phase 6 table.
- **Redis/PostgreSQL up:** exporters or the managed provider's metrics. DB CPU and storage come from the provider: RDS `CPUUtilization` > 80% for 15 min and `FreeStorageSpace` < 20% raise tickets.
- **Structured logs:** `LOGGING` is plain text today. **Backend ask:** a JSON formatter with the request id (`X-Request-ID` from the edge), hashed user id and order id, and phone masking (`09 §3.3`, `§5`).

### 10.4 Alert rules
`infra/monitoring/alerts.yml` (Prometheus rule format) has 23 rules:
- **availability:** API not ready, 5xx > 2%, Redis or PostgreSQL down;
- **latency:** the 09 §1 p95 targets (reads 300 ms, order placement 800 ms, serviceability 150 ms);
- **jobs:** queue > 200, no workers, repeated task failures, beat stale > 5 min, daily jobs > 26 h, unpaid orders past their window;
- **payments:** new FAILED refunds, PENDING > 2 h, webhook 400 bursts, webhook 503 > 15 min;
- **notifications:** stuck sends, many failures, WebSocket collapse;
- **business SLA:** store acceptance SLA, orders past ETA, no orders during open hours.

Severities: `page` (on-call engineer), `ticket` (working hours), `ops` (store/ops on-call). The SQL exporter connects with its own read-only role, never the app's login:
```sql
create role jqc_metrics login password '<from the secrets manager>';
grant connect on database jivo_quick_commerce to jqc_metrics;
grant usage on schema public to jqc_metrics;
grant select on django_celery_beat_periodictask, orders_order, payments_refund,
      payments_paymentwebhookevent, notifications_notification to jqc_metrics;
alter role jqc_metrics set default_transaction_read_only = on;
```
Validate locally with `uv run --project backend python infra/monitoring/check_monitoring.py` (structure, every metric catalogued, every runbook anchor present). CI also runs `promtool check rules` and `nginx -t` in pinned images (`.github/workflows/infra.yml`).

### 10.5 Threshold changes
Record each tuned threshold here with its date and reason (after the pilot week, 10 §7).

### 10.6 Alert runbooks

#### Runbook: API availability
`JqcApiNotReady`, `JqcApi5xxRateHigh`. Read `/health/ready`'s `details.checks`, look in Sentry for the new error, and check the last deploy (roll back per §8.3 if the alert started with a release). Check DB connections: web processes × `POSTGRES_POOL_MAX_SIZE` + workers must stay within the server's limit (§4).

#### Runbook: data stores
`JqcRedisDown`, `JqcPostgresDown`. Redis: OTP fails closed and sockets fall back to polling; there is nothing to restore (§7.5). Restart or fail over, then watch the Celery backlog drain. PostgreSQL: check the provider's status and failover; if data is damaged, follow §7.2.

#### Runbook: latency
`JqcReadLatencyP95High`, `JqcOrderPlacementLatencyP95High`, `JqcServiceabilityLatencyP95High`. Compare with the deploy timeline. Check slow queries (`pg_stat_statements`), the Redis cache (catalog cache, serviceability snapshot) and lock waits on `inventory_storeinventory` during order bursts.

#### Runbook: Celery
`JqcCeleryQueueBacklog`, `JqcCeleryWorkersDown`, `JqcCeleryTaskFailures`. Read the worker logs and Sentry. Scale workers within the DB connection budget. One task name failing repeatedly usually means an external provider (SMS, FCM, Razorpay) is down; the tasks retry with back-off.

#### Runbook: Celery beat
`JqcBeatNotRunning`, `JqcBeatDailyJobMissed`, `JqcPaymentWindowOverdue`. Exactly one `beat` must run (§4). Check that it is up, that `migrate` ran before it started, and its `last_run_at` in `/admin/` > Periodic Tasks. Overdue unpaid orders hold stock; once beat recovers they expire within a minute.

#### Runbook: payments
`JqcRefundFailed`, `JqcRefundPendingTooLong`, `JqcWebhookSignatureFailures`, `JqcWebhookRetryLoop`. Start with the Razorpay dashboard. A failed refund is retried from the admin by a role allowed to. A burst of 400s after a secret rotation: follow the §5 rotation steps. Persistent 503s: check Sentry for the webhook handler.

#### Runbook: notifications
`JqcNotificationsStuckSending`, `JqcNotificationFailuresHigh`, `JqcWebsocketConnectionsCollapsed`. Check that the sweeper runs (beat), the FCM credentials, the SMS gateway and the DLT template status. For a WebSocket collapse, check the channel-layer Redis and the edge's `/ws/` route (`limit_conn`, idle timeouts).

#### Runbook: business SLA
`JqcStoreAcceptanceSlaBreach`, `JqcOrdersPastEta`, `JqcNoOrdersDuringOpenHours`. These go to the store/ops on-call: call the store and check the packing console and rider availability. For no orders during open hours, place a test order end to end (serviceability, cart, payment).

## 11. Secrets and rotation

### 11.1 Required secrets in staging and production
Kept per environment in the secrets manager; never in git or in images:
- `DJANGO_SECRET_KEY` (at least 50 characters): sessions, CSRF, signing.
- **`JWT_SIGNING_KEY`:** signs the apps' access and refresh tokens. In staging and production it must be **set, at least 50 characters, and different from `DJANGO_SECRET_KEY`** (system check `accounts.E005`, which fails the deploy-time check, §8.1), so rotating one never invalidates the other. The fallback to the secret key is for local use only. Generate with `secrets.token_urlsafe(64)`.
- **`OTP_HASH_KEY`:** the key used to hash OTP codes (HMAC). Staging and production: **at least 32 characters, distinct from both keys above**; never reuse another key. Generate with `secrets.token_urlsafe(48)`.
- CI's `check --deploy` step (`backend.yml`) generates throwaway values for all three on every run, plus a throwaway FCM service-account file (fresh RSA key, project `ci-dummy`, in `$RUNNER_TEMP`, deleted after the step) so `notifications.E002` validates a key and `W001` (push disabled) does not fail the `--fail-level WARNING` gate; the staging preflight (`deploy-staging.yml`) refuses a `STAGING_BACKEND_ENV` that lacks `DJANGO_SECRET_KEY`, `JWT_SIGNING_KEY` or `OTP_HASH_KEY`.
- **`FIELD_ENCRYPTION_KEYS`:** comma-separated Fernet keys, **newest first**, for rider bank and KYC numbers (09 §3.3). Required in staging and production (`delivery.E001`).
- **`FCM_CREDENTIALS_FILE`** (D-19): the **path** of the Firebase service-account JSON key, never the JSON itself. On servers it is a read-only mounted secret file, e.g. `/run/secrets/fcm-service-account.json`, mounted into `web`, `worker` and `beat`; one Firebase project per environment (`FCM_PROJECT_ID` optional, defaults to the key's `project_id`). Missing, unreadable or malformed fails startup (`notifications.E002`); unset leaves push disabled and `check --deploy` warns (`notifications.W001`).
- `POSTGRES_PASSWORD`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `TWILIO_AUTH_TOKEN`, `S3_SECRET_ACCESS_KEY` (or an instance role instead), `SENTRY_DSN`, `EMAIL_HOST_PASSWORD`.
- Generate keys with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` and Fernet keys with `uv run python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` (from `backend/`), straight into the secrets manager.

### 11.2 Rotation runbooks
- **`DJANGO_SECRET_KEY`:** set the new value and roll `web`. Staff sessions end and staff log in again. The apps are unaffected while `JWT_SIGNING_KEY` is separate.
- **`JWT_SIGNING_KEY`:** set the new value and roll `web`. Every app access and refresh token becomes invalid, so every customer and rider logs in again. Rotate only on suspected compromise, announce it first, and expect an OTP SMS spike.
- **`FIELD_ENCRYPTION_KEYS`:** add the new key **first** and keep the old ones after it; deploy; run `manage.py rotate_field_keys` as a one-off task and confirm it reports no undecryptable values; remove the old key in the next deploy.
- **`OTP_HASH_KEY`:** set it and roll `web` and `worker`. OTPs in flight (5-minute lifetime) fail and users request a new one, so rotate in a quiet window.
- **`RAZORPAY_WEBHOOK_SECRET`:** §5.
- **FCM service-account key (`FCM_CREDENTIALS_FILE`):** in the Firebase/Google Cloud console create a **new key** for the same service account; replace the mounted secret file's contents (same path); roll `worker`, `beat` and `web` so every process reads the new file (the backend caches the access token per process); send a test push and confirm `JqcNotificationFailuresHigh` stays quiet; then **delete the old key** in the console. On suspected compromise, delete the old key first and accept failed pushes until the new file is rolled out.
- **Database password:** set the new password on the role, update the secret, roll `web`, `worker` and `beat` in that order, then confirm no connection still uses the old one. **Least privilege:** staging and production must use a role that owns only the app's database (never a superuser), plus the separate read-only `jqc_metrics` role (§10.4).
- After any rotation, check Sentry for auth errors, `/health/ready`, and the webhook-events list.

## 12. Android release builds (Phase 8; D-06, D-11)

### 12.1 What exists
- **`.github/workflows/release-android.yml`** (manual). Inputs: `app` (`both`, `customer_app`, `rider_app`) and `build_number` (Android `versionCode`, default the run number; it must be higher than every build already uploaded to Play). The version name comes from each app's `pubspec.yaml`.
- It builds the **prod** flavor (`in.jivo.quick`, `in.jivo.rider`) as an AAB and an APK, with `--obfuscate --split-debug-info`, and checks that both are signed with the upload key alone. It uploads the AAB, APK, Dart symbols, R8 mapping and `SHA256SUMS` as run artifacts (3-day retention).
- It publishes nothing to Play and needs no cloud account. iOS (customer app) needs a macOS runner and an Apple account (D-11); not prepared yet.
- **The repo is public**, so run artifacts are downloadable by any signed-in GitHub user. The bundles hold nothing the store copy doesn't; the symbols and mapping only de-obfuscate. Download them, upload the AAB to Play and the symbols to Sentry, and keep your own copies.

### 12.2 One-time setup (needs the user; no cost)
1. **Environment `release`** (Settings > Environments): required reviewers, "Prevent self-review", deployment branches `main` and `develop` only. Create it **before** adding secrets (a run that references a missing environment creates an unprotected one).
2. **Upload keys:** one per app, generated offline by the key owner, never on a shared machine:
   `keytool -genkeypair -v -keystore customer-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload`
   Keep the `.jks` and its passwords in Jivo's password manager (two people). With **Play App Signing** (recommended), Google holds the app-signing key and a lost upload key can be reset.
3. **Environment secrets** in `release` (names exactly; values never in git, chat or logs):

   | Secret | Customer app | Rider app |
   |---|---|---|
   | Keystore, `base64 -w0 <file>.jks` | `CUSTOMER_UPLOAD_KEYSTORE_BASE64` | `RIDER_UPLOAD_KEYSTORE_BASE64` |
   | Keystore password | `CUSTOMER_UPLOAD_KEYSTORE_PASSWORD` | `RIDER_UPLOAD_KEYSTORE_PASSWORD` |
   | Key alias | `CUSTOMER_UPLOAD_KEY_ALIAS` | `RIDER_UPLOAD_KEY_ALIAS` |
   | Key password | `CUSTOMER_UPLOAD_KEY_PASSWORD` | `RIDER_UPLOAD_KEY_PASSWORD` |
   | Sentry DSN (optional; warning if empty, D-19) | `CUSTOMER_SENTRY_DSN` | `RIDER_SENTRY_DSN` |
   | Google Maps Android API key, plain value (required; passed to Gradle as `MAPS_API_KEY`) | `CUSTOMER_MAPS_API_KEY` | n/a |

4. **Environment variables** in `release`: `PROD_API_BASE_URL` (required, an https origin such as `https://api.<domain>`; waits on D-05) and `CUSTOMER_APP_LINK_HOSTS` (optional, comma-separated App Links hosts).
5. **Google Maps API key** (Google Cloud console > APIs & Services > Credentials; DL-80). The key ships inside the APK, so its restrictions are what protect it:
   - **Application restrictions: Android apps.** Add one entry per package and certificate: `in.jivo.quick` (prod), `in.jivo.quick.staging` and `in.jivo.quick.dev`, each with the SHA-1 of the upload certificate (`keytool -list -v -keystore <file>.jks`; the workflow log prints only the SHA-256) **and** of the Play app-signing certificate (Play Console > App integrity). Dev/staging builds signed with a local debug key need that key's SHA-1 too; prefer a separate dev key rather than adding debug keys to the prod key.
   - **API restrictions:** Maps SDK for Android only.
   - Set a daily quota and a billing budget alert in the same project (check Google's current Maps Platform pricing before launch).
   - Locally, keep the key in `~/.config/jivo-quick-commerce/google-maps/android-api-key.txt` (or export `MAPS_API_KEY`); never in the repo.

With any of the required items missing, the "Release configuration is complete" step fails in seconds and lists each missing secret or variable by name.

### 12.3 App side (owners: `flutter-customer-dev`, `flutter-rider-dev`)
The workflow writes `<app>/android/key.properties` (gitignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Both `android/app/build.gradle.kts` files still sign `release` with the debug key, so until they read that file the "Outputs are signed with the upload key" step fails on purpose. Needed in each app (standard Flutter pattern; keeps debug signing when the file is absent, so local `flutter run --release` still works):

```kotlin
import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    signingConfigs {
        create("release") {
            if (!keystoreProperties.isEmpty) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (keystoreProperties.isEmpty) "debug" else "release",
            )
        }
    }
}
```

### 12.4 Runbook: cut a release build
1. Merge the release candidate to `main` (or use `develop` for an internal-testing build).
2. Actions > `release-android` > Run workflow on that branch; choose the app and a `build_number` above the last Play upload. A `release` reviewer approves the job.
3. Download the artifact; check `SHA256SUMS`; upload the AAB to the Play internal track (D-11), the Dart symbols and R8 mapping to Sentry (and the mapping to Play).
4. **Rollback:** Play cannot take back an installed build. Halt the staged rollout in Play Console, then ship a fix with a higher `build_number`. Server-side, raise `min_supported_version` only once the fixed build is live.

### 12.5 Rotation
- **Upload key compromised or lost:** with Play App Signing, request an upload key reset in Play Console, generate a new key (§12.2 step 2), replace the four `*_UPLOAD_*` secrets, and add the new certificate's SHA-1 to the Google Maps key's Android restrictions (§12.2 step 5).
- **Sentry DSN:** replace the secret; the next build picks it up. Older builds keep the old value until users update.
- **Google Maps API key leaked or abused:** create a new restricted key (§12.2 step 5), update `CUSTOMER_MAPS_API_KEY` and the local key file, ship a build, then delete the old key once enough users have updated (deleting it earlier breaks the map in older builds; manual address entry still works).

## 13. P8 drill results 2026-11-16 (staging `jqc.jivo.in`, DL-75)

Light drill only, on the shared server (backend `8369b0b`, compose project `jqc`). Logs on the server: `/srv/jqc/logs/p8-*-20261116.txt`.

### 12.1 Restore drill: PASS
- **Backup:** fresh full dump with `infra/backup/backup_db.sh` (run in a one-off `postgis/postgis:16-3.4` container on `jqc_net`): 784 KB, 1 s, sha256 + manifest in `/srv/jqc/backups/drill-20261116/`.
- **Restore:** `restore_db.sh` into `test_jivo_quick_commerce_restore_20261116` beside the live DB (checksum checked first), 3.8 s. The live DB was only read.
- **Verify:** `verify_restore.py --full --counts --source-db jivo_quick_commerce` (run with the `jqc-backend` image): **26 PASS, 0 WARN, 0 FAIL**. Every table's row count matched the live DB, the migration state and schema matched, the money and stock constraints were present, and all the 08 §6 invariants passed.
- **Cleanup:** the restore DB was dropped with `restore_db.sh --drop-only`. Only the live DB remains.
- **RTO (data):** 5.5 s from the start of the restore to a verified DB. The DB is small (largest table: 4,819 rider locations). This does not include repointing the app, which is a compose restart (seconds).
- **RPO:** **there are no scheduled backups yet.** Before the drill, the newest dump was the pre-deploy dump of 2026-11-14 10:13 UTC, about **43 hours old**, and it sits on the same disk. Until D7/D8 add a scheduled, offsite backup, the real RPO is "since the last deploy".

### 12.2 Light load test (20 sessions, 5 min): reads PASS, no impact on other sites
- **Harness:** `loadtest/` (T-812) from this Windows PC to `https://jqc.jivo.in`. It used a `light` profile defined in a scratch wrapper that loads the harness's `locustfile.py` unchanged, with the same safety checks. The profile was 4 logged-in buyers (cart plus a COD order) and 16 anonymous browsers, with 0 riders and no online payments. The test data came from `loadtest_seed --users 4 --stock-floor 50` and was removed with `loadtest_cleanup --yes`: 5 orders, 4 customers, 8 OTP requests and 332 top-up units were reversed, and a re-check found 0 left.
- **Temporary staging env** for the window, reverted afterwards (env restored from `backend.env.pre-p8-20261116`, web and worker recreated, healthy):
  - `LOADTEST_DATA_ALLOWED=true`
  - the 4 load-test numbers added to `OTP_TEST_NUMBERS`
  - `API_ANON_RATE` / `SERVICEABILITY_RATE` / `SEARCH_RATE` raised, because all 20 sessions share one client IP
- **Run 1 was discarded.** The harness's default point (28.471, 77.044) is outside the staging GGN-01 area. Run 2 used the store point (28.631878, 77.128798).

Run 2, 05:04:53 to 05:10:08 UTC: **2,517 requests, 0 HTTP errors**, about 8.3 req/s. Latency is in ms, measured from the client over the internet:

| Endpoint | n | p50 | p95 | p99 | 09 §1 target (p95) | |
|---|---:|---:|---:|---:|---:|---|
| GET serviceability | 348 | 19 | 28 | 60 | 150 | pass |
| GET home | 348 | 19 | 23 | 32 | 300 | pass |
| GET categories | 348 | 20 | 28 | 53 | 300 | pass |
| GET products (list) | 348 | 19 | 24 | 47 | 300 | pass |
| GET product detail | 348 | 20 | 35 | 65 | 300 | pass |
| GET search | 347 | 19 | 38 | 55 | 300 | pass |
| GET search suggest | 347 | 20 | 46 | 140 | 300 | pass |
| GET config/app | 20 | 88 | 300 | 300 | 300 | pass (at the limit, 20 samples) |
| Cart writes (POST/PATCH/DELETE) | 37 | 40-56 | 56-120 | 56-120 | 800 | pass |
| POST orders | 1 | 120 | 120 | 120 | 800 | pass (1 sample) |
| GET orders/{id} | 3 | 31 | 360 | 360 | 300 | 1 slow sample out of 3, not significant |
| All requests | 2,515 | 19 | 39 | 84 | | error rate 0.00% |

- The harness reported FAIL only because of 7 `JOURNEY checkout blocked: MIN_UNITS_NOT_MET` rows and the 3-sample `orders/{id}` p95. **Harness gap:** `flows._fix_blockers` handles `MIN_ORDER_NOT_MET` but not the store's minimum-units blocker `MIN_UNITS_NOT_MET`, so most staging carts stop before checkout. Order placement throughput was therefore not measured; this needs a harness fix.
- **Server during the run:**
  - host CPU 88-96% idle, load 1.1-2.3 on 14 cores
  - RAM: about 15.5-15.9 GB used, 11.6 GB available; swap steady at about 8.9 GB, already in use before the test
  - jqc-web: 2-11% CPU, with one sample at 94% (of its 2-CPU cap) in the last minute; 423-463 MiB
  - jqc-postgres: under 7% CPU, about 130 MiB
- **Other 24 sites** were checked every minute through the local nginx against a 5-sample median baseline. Abort rule: status change, or time over 2x baseline and over baseline + 100 ms.
  - 13 checks across both runs, **0 violations, 0 status changes, no abort**.
  - The worst times were within about 20 ms of baseline (for example `hr.jivo.in` 261 to 279 ms and `whatsapp.jivo.in` 68 to 85 ms).
  - Two samples went over a strict 2x but stayed far under the noise floor: `einvoice.jivo.in` 12 to 40 ms once during run 1, and `datasync.jivo.in` 6 to 13 ms in the check after run 2 ended.
- **Verdict:** at this light load, all read paths are far inside the 09 §1 targets and the other sites were not affected. The full 09 §1 capacity test (500 sessions, 50 orders/min) still waits for a dedicated server (DL-75).
