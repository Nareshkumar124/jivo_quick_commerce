---
name: phone-build-install
description: "Build the customer or rider dev APK and install, launch and verify it on the user's USB phone (Realme 9TY5KF8H49Z5YDON; there is no emulator). Use whenever the user asks to put a build on the phone, test an app on device, reinstall after an integration test, or the app on the phone can't reach the local backend."
---

# Build and install on the USB phone

Only the PM touches the phone; agents never run `adb install` or `flutter run`. Device `9TY5KF8H49Z5YDON`. Flutter is `/c/dev/flutter/bin/flutter` (the normal path has a space).

| App | Folder | Package | Extra step |
|---|---|---|---|
| customer | `customer_app/` | `in.jivo.quick.dev` | `bash tool/setup_mappls.sh --copy` (Mappls config, never print or commit it) |
| rider | `rider_app/` | `in.jivo.rider.dev` | – |

Choose the tree: the main tree (`/c/jivo_projects/jivo_quick_commerce`, develop) for merged code, or `.worktrees/customer` / `.worktrees/rider` to try an agent's unmerged run. Don't build in a worktree while its agent is running `flutter test`/`pub get`.

## 1. Phone and backend ready
```bash
adb devices                                  # 9TY5KF8H49Z5YDON  device   (not "unauthorized": ask the user to accept the prompt)
adb -s 9TY5KF8H49Z5YDON reverse tcp:8001 tcp:8001
adb -s 9TY5KF8H49Z5YDON reverse tcp:9000 tcp:9000     # MinIO: images, invoices, KYC uploads
adb -s 9TY5KF8H49Z5YDON reverse --list
curl -s http://127.0.0.1:8001/health/ready   # else start the stack (local-stack skill)
```

## 2. Build
```bash
cd <tree>/customer_app && bash tool/setup_mappls.sh --copy      # customer only
/c/dev/flutter/bin/flutter pub get --enforce-lockfile
/c/dev/flutter/bin/flutter build apk --flavor dev -t lib/main_dev.dart --dart-define=API_BASE_URL=http://localhost:8001
```
Run the build with `run_in_background: true` (first Gradle build in a worktree takes several minutes). Output: `build/app/outputs/flutter-apk/app-dev-release.apk`.

## 3. Install and launch
```bash
adb -s 9TY5KF8H49Z5YDON install -r build/app/outputs/flutter-apk/app-dev-release.apk
adb -s 9TY5KF8H49Z5YDON shell monkey -p in.jivo.quick.dev -c android.intent.category.LAUNCHER 1     # rider: in.jivo.rider.dev
```
**`INSTALL_FAILED_UPDATE_INCOMPATIBLE`** = the installed app was signed with a different key (another machine or worktree). Uninstalling wipes the user's login and app data: **ask the user** before `adb uninstall <package>`.

## 4. Verify
```bash
adb -s 9TY5KF8H49Z5YDON shell pidof in.jivo.quick.dev        # prints a PID when running
```
Then watch the :8001 runserver output (read the background task's output file) for requests carrying the app's headers, e.g. `GET /api/v1/config/app/` or `/api/v1/serviceability/` with 200s. No requests at all → `adb reverse` is missing. Crash on start: `adb -s 9TY5KF8H49Z5YDON logcat -d -s flutter AndroidRuntime | tail -50`.

Test login: `+919000000001` / `…002` / `…003`, OTP `123456` (no SMS). Staff passwords come only from `SEED_DEMO_STAFF_PASSWORD` in `backend/.env`; never show them.

## Reconnect / "network error" on the phone
USB replug, phone reboot or `adb kill-server` drop the reverse rules:
```bash
adb devices && adb -s 9TY5KF8H49Z5YDON reverse tcp:8001 tcp:8001 && adb -s 9TY5KF8H49Z5YDON reverse tcp:9000 tcp:9000
```
Then reopen the app. Images broken but API fine → only the 9000 rule is missing or MinIO is stopped.

## After an integration test
`flutter test integration_test/...` on the phone replaces the app with a test build. Afterwards rebuild (step 2) and `install -r` the normal dev build so the user's app keeps working.

Report to the user: tree + branch/commit, APK size (`ls -la` on the apk), install result, launch PID, and what to try on the phone.
