# customer_app

The Jivo Quick Commerce customer app (Android + iOS). It is a standalone
Flutter project with its own `pubspec.lock`. Shared code comes from
`../packages/jivo_core` and `../packages/jivo_api` as path dependencies. Run
every command from this directory, starting with `flutter pub get`.

Lint rules are shared through `../packages/analysis_options.yaml`. Packages
used by both apps must resolve to the same version; CI checks this with
`python3 ../packages/tool/check_shared_versions.py`.

Product spec: `docs/03-customer-app.md`. Architecture: `docs/02-system-architecture.md`.

## Flavors

| Flavor | Entry point | Android app ID | Launcher name | Backend |
|--------|-------------|----------------|---------------|---------|
| dev | `lib/main_dev.dart` | `in.jivo.quick.dev` | Jivo Dev | local stack, default `http://10.0.2.2:8001` |
| staging | `lib/main_staging.dart` | `in.jivo.quick.staging` | Jivo Staging | `API_BASE_URL` required |
| prod | `lib/main_prod.dart` | `in.jivo.quick` | Jivo | `API_BASE_URL` required, https only |

On Android, always pass the flavor **and** its entry point. Plain `flutter run`
fails because there is no `lib/main.dart` and no default flavor.

```sh
flutter run --flavor dev -t lib/main_dev.dart
flutter build apk --flavor dev -t lib/main_dev.dart
flutter build apk --flavor staging -t lib/main_staging.dart --dart-define=API_BASE_URL=https://<staging-api>
```

## Configuration (`--dart-define`)

Values are compiled in per build and never hard-coded. See `AppEnv` in
`packages/jivo_core`.

| Key | Meaning |
|-----|---------|
| `API_BASE_URL` | Backend origin. Optional for dev, required for staging and prod. |
| `SENTRY_DSN` | Sentry DSN. Absent means Sentry is off. |
| `FAKE_API` | `true` uses fake repositories (dev/staging only, ignored in prod). |

To keep a set of values in a file, use `--dart-define-from-file=<file>.json`
and keep that file out of git.

Reaching the local backend:
- **Android emulator:** the default `http://10.0.2.2:8001` works. The dev
  flavor allows cleartext HTTP; staging and prod do not.
- **Physical Android device over USB:** run `adb reverse tcp:8001 tcp:8001`,
  then pass `--dart-define=API_BASE_URL=http://localhost:8001`. Over Wi-Fi,
  use `http://<your-LAN-IP>:8001` instead.
- **iOS simulator:** `--dart-define=API_BASE_URL=http://localhost:8001`. See the
  iOS notes below for plain HTTP.
- **No backend yet:** `--dart-define=FAKE_API=true`.

## Tests

```sh
flutter test                                    # unit + widget tests
flutter test integration_test --flavor dev -d <device>          # needs the local backend
flutter test integration_test --flavor dev -d <device> --dart-define=FAKE_API=true
```

## iOS: what still needs Xcode

These were set up on Linux, so only the Android flavors exist so far.
- Bundle ID `in.jivo.quick` and display name "Jivo" are set.
- **Flavors.** There are no `dev`/`staging`/`prod` schemes or build
  configurations yet. Until they exist, run iOS without `--flavor`, e.g.
  `flutter run -t lib/main_dev.dart`. To add them in Xcode:
  - Duplicate the Debug/Release/Profile build configurations per flavor
    (`Debug-dev`, `Release-dev`, ...).
  - Add a shared scheme per flavor.
  - Set `PRODUCT_BUNDLE_IDENTIFIER` (`in.jivo.quick.dev`, `.staging`) and the
    display name per configuration through xcconfig files.
- **Plain HTTP for dev.** App Transport Security blocks `http://localhost:8001`.
  Allow local networking for the dev configuration only (for example
  `NSAllowsLocalNetworking` in a dev-only Info.plist), never for prod.
- **iOS build check.** Run `flutter build ios --no-codesign` on a Mac.
