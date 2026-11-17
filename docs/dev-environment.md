# Development environment (current dev machine)

Every development agent reads this before running anything. It records how the stack really runs on the current machine, which differs from the Linux and Docker setup that older docs assume. The PM keeps it current.

## Machine
- Windows 11. The user folder is `C:\Users\89 USER`, which contains a space.
- Shells: Git Bash (POSIX) and PowerShell 5.1. Use forward slashes in Bash.
- **No Docker.** Redis runs natively on `127.0.0.1:6380`. MinIO (the pgsty community build; local dev only) on 9000/9001 and Mailpit on 1025/8025 run natively through `infra/scripts/windows/dev-services.ps1 -Action start|stop|status|init`. Tests must still not need them; test settings use their own storage.
- **Use `127.0.0.1`, never `localhost`, in Redis URLs** (`REDIS_URL`, `CELERY_BROKER_URL`, `CHANNELS_REDIS_URL`, `REDIS_TEST_URL`). On Windows `localhost` tries IPv6 first and each new connection costs about 2 s (OBS-S3-01). The settings defaults and `infra/env/backend.env.example` use `redis://127.0.0.1:6380/<db>`.
- Never use port 6379 or the `redis-chai` / `mongo-chai` containers. Don't touch the :8001 dev server; the PM runs it from the main tree on `develop`.

## Backend
- Always run Python through `uv run`, which uses Python 3.13. Before running anything in Bash:
  ```bash
  unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
  ```
  That lets `backend/.env` apply. **Never print, cat or copy `backend/.env`.** It holds the DB, staff and Twilio credentials.
- **The DB is the remote shared PostgreSQL + PostGIS (DL-49).** Each query costs about 10 ms, so a serial full suite takes 30–60 minutes.
- **Never** run `migrate` against the dev DB, `flush`, or `DROP DATABASE`. Migrations reach the shared DB only through the PM, after the user approves.
- **Test DB and Redis per agent**, so parallel runs never collide:

  | Who | `POSTGRES_TEST_DB` | `TEST_REDIS_DB` |
  |---|---|---|
  | backend (main run) | default `test_jivo_quick_commerce` | 15 (default) |
  | backend, second worktree (`backend4`, `sms`, …) | `test_jivo_quick_commerce_<worktree>` | 12 or 13 (the PM assigns) |
  | admin | `test_jivo_quick_commerce_admin` | 14 |
  | QA instance on :8004 | QA's own settings | 5–7 |
- **Fast test loop:**
  1. While iterating, run only the test files you touched.
  2. Run the full suite **once** at the end, in parallel: `uv run pytest -n 4`, plus your env vars. `pytest-xdist` is a dev dependency (T-408c).
  3. Each xdist worker gets its own test DB (`<POSTGRES_TEST_DB>_gwN`) and its own Redis key namespace (`jqc-test-gwN`), so the suite is xdist-safe. A failure under `-n` is a real failure.
  4. **Test DB cleanup (user decision, 2026-11-05).** Each run name creates 5 DBs on the shared server: the base DB plus `_gw0`–`_gw3`. When an agent's work is **merged**, the PM drops that run name's test DBs, matching only `^test_jivo_quick_commerce_<name>(_gw[0-3])?$` and skipping any that are in use. Only active runs keep test DBs. Never touch any other database on that server; it hosts other company databases.
  5. **Never run two `-n` runs at once with the same `POSTGRES_TEST_DB` and the same `TEST_REDIS_DB`.** They would share the `_gwN` databases and namespaces. A serial run and a `-n` run can share a `TEST_REDIS_DB`.
- **Celery on Windows:** run `celery -A config worker --pool threads` and `celery -A config beat` as **separate** processes. `-B` is refused on Windows.
- **Text files:** always open them with `encoding="utf-8"`, because the Windows default is cp1252. Git uses `core.autocrlf=true`, so checked-out text files have CRLF. Tests must not compare file bytes against string constants unless `.gitattributes` forces LF for that file type (see `.gitattributes`).
- Native libraries: GDAL and GEOS come from `GDAL_LIBRARY_PATH` / `GEOS_LIBRARY_PATH` in `.env`. WeasyPrint's Pango/GTK libraries may be missing. If so, degrade cleanly, skip the render tests with a clear reason, and report it. Never install system software yourself.
- **Push (FCM, D-19).** Local settings log pushes (`ConsolePushBackend`) unless `FCM_CREDENTIALS_FILE` is set. The dev Firebase project is `jivo-quick`; its service-account key is at `%USERPROFILE%\.config\jivo-quick-commerce\firebase\dev\service-account.json` (secret: never print, copy or commit it). To switch :8001 to real FCM (PM only):
  1. Add to `backend/.env`: `FCM_CREDENTIALS_FILE=C:/Users/89 USER/.config/jivo-quick-commerce/firebase/dev/service-account.json` (forward slashes; `~` and `%USERPROFILE%` are also expanded). Leave `PUSH_BACKEND` unset or empty.
  2. Restart the dev server **and** the Celery worker (pushes are sent by the worker). `uv run python manage.py check` must show no `notifications.E002`.
  3. Sign in on the phone so the app registers its FCM token, then `uv run python manage.py send_test_push --user +919000000001` (customer) or `--user +919000000003 --event rider.offer_new --data offer_id=1 --data task_id=1` (rider). It sends synchronously and prints how many devices were reached, never the tokens.
  4. To go back to console logging, remove `FCM_CREDENTIALS_FILE` and restart.
  Tests never use the key: test settings force `LocmemPushBackend` and blank `FCM_*`.

## Flutter
- Run Flutter as **`C:\dev\flutter\bin\flutter`**, a junction to the SDK. The normal path contains a space, which breaks native-asset build hooks (`objective_c`).
- Flutter 3.47.9 / Dart 3.13.7. Use `flutter pub get --enforce-lockfile`, and keep shared versions identical (`python3 packages/tool/check_shared_versions.py`).
- **No emulator.** Don't touch the user's USB phone (`9TY5KF8H49Z5YDON`): no `adb install` and no `flutter run`. The PM does device builds and installs.
- **Customer dev flavor is HTTPS-only for LAN IPs** (T-230, `abd2c6d`): plain HTTP to a LAN IP (e.g. `http://192.168.x.x:8001`) is refused. On the phone use `adb reverse tcp:8001 tcp:<local port>` and `--dart-define=API_BASE_URL=http://localhost:8001`.
- Don't run `flutter test` or `pub get` while a `flutter build` is running in the same checkout.
- **Firebase push config (D-19).** Private, like the Mappls files: `%USERPROFILE%\.config\jivo-quick-commerce\firebase\<env>\google-services.json` (dev exists; staging/prod later). In Git Bash, run `customer_app/tool/setup_firebase.sh --copy` (dev flavor ← dev env; `--env staging|prod|all` for the others, `--remove` to undo). It copies the file to `customer_app/android/app/src/<flavor>/google-services.json` (gitignored), checks the package name and prints file names only. Never read, print or copy `service-account.json` from that folder. Without the file the app builds and runs with push off (CI does exactly that). See `customer_app/README.md` "Push".

### Rider app push (FCM, D-19)
- Same mechanism and private folder as the customer app: `%USERPROFILE%\.config\jivo-quick-commerce\firebase\<env>\google-services.json` (one file per Firebase project holds both apps; the dev file registers `in.jivo.rider.dev`). In Git Bash, run `rider_app/tool/setup_firebase.sh --copy` (dev flavor from the dev env; `--env staging|prod|all` for the others, `--remove` to undo). It copies the file to `rider_app/android/app/src/<flavor>/google-services.json` (gitignored), refuses a file that doesn't register the flavor's package (`in.jivo.rider.dev` / `.staging` / `in.jivo.rider`) and prints file names only. Never read, print or copy `service-account.json`.
- Without the file the rider app builds and runs with push off (CI does exactly that); offers still arrive on the rider socket and by polling. See `rider_app/README.md` "Push".

## Git
- Agents never commit, push or switch branches. Work only in the worktree path given in the brief.
- The git stash is shared across worktrees, so never use `git stash`.
