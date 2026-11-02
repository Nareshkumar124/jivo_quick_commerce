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
| `FAKE_API` | `true` uses fake repositories (dev flavor only, ignored in staging and prod). |

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

## Maps: Mappls (MapmyIndia)

The map pin picker uses the Mappls Flutter SDK (`mappls_gl`, D-03): the
map, and reverse geocoding for the address preview. The SDK authenticates
with a **config file pair**, not an API key:
- Android: `<appId>.a.olf` and `<appId>.a.conf`
- iOS: `<appId>.i.olf` and `<appId>.i.conf`

These files are **secrets**. They are bound in the Mappls console to the
app's package names and signing certificate. They live outside the repo
(default `~/.config/jivo-quick-commerce/mappls/`, `chmod 600`) and are
gitignored everywhere (`*.a.olf`, `*.a.conf`, `*.i.olf`, `*.i.conf`). Never
commit, paste or print them.

**Without the files the app still builds and runs** (CI has none):
"Pick on map" shows "Map isn't available" with "Use current location" and
"Enter address manually". The Gradle guard in `android/build.gradle.kts`
skips the plugin's `generate<Variant>MapplsRes` tasks, which would otherwise
fail the build.

### Android setup

```sh
customer_app/tool/setup_mappls.sh            # symlinks the pair into android/app/
customer_app/tool/setup_mappls.sh --copy     # or copies it (mode 600)
customer_app/tool/setup_mappls.sh --remove   # removes it again
MAPPLS_CONFIG_DIR=/other/folder customer_app/tool/setup_mappls.sh
```

Then build as usual. How it is wired:
- The mappls_gl Gradle plugin finds `*.a.olf`/`*.a.conf` next to the app
  module (`android/app/`). It turns the `.olf` file into the string resource
  `mappls_olf_data` and copies the `.conf` file to
  `android/app/src/<variant>/assets/mappls-conf.txt`. That path is
  gitignored too.
- `MainActivity.kt` answers the `in.jivo.quick/maps` channel with whether
  both are in the APK. `PlatformMapsAvailability` asks it, so a map is only
  created when the SDK can authenticate. A map error (for example failed
  authentication) also falls back, and the code is logged
  (`Mappls map error <code>: <message>` in `flutter logs`/logcat).

**Registration.** In the Mappls console, register every package name the
config must work for, with the signing certificate's fingerprints:
- packages: `in.jivo.quick.dev`, `in.jivo.quick.staging`, `in.jivo.quick`
- certificate: all flavors are currently signed with the **debug
  keystore**. The fingerprints below are for that debug keystore only.
  Never put release-keystore fingerprints in this README or anywhere in
  the repo. Register them in the Mappls console directly.
  Its SHA-1 is `76:E3:69:C1:88:DB:10:1F:AA:5C:88:FC:3B:10:FD:01:D8:FE:0A:1A`
  and its SHA-256 is
  `57:61:CC:A9:50:05:32:9A:5C:23:23:95:CA:EF:93:C8:F1:B9:34:FA:C9:F6:B3:22:04:0A:FE:FE:D5:58:90:6A`.
  The mappls_gl README asks for the SHA-256, so register both.
- Re-download the config pair after changes. A release keystore needs its
  own fingerprints.

Requirements (mappls_gl 2.0.7):
- Android minSdk 23 (the app uses 26).
- The plugin compiles against SDK 35 with NDK 28.1. It declares Kotlin
  1.9.0 and AGP 8.8.2 in its own buildscript; the app's AGP and Kotlin
  versions are used.
- It adds the `https://maven.mappls.com/repository/mappls/` Maven repository.
- **Keep `mappls_gl` pinned at exactly 2.0.7.** Two things depend on its
  internals and must be re-checked on any upgrade:
  - The no-config guard in `android/build.gradle.kts` matches the plugin's
    `generate<Variant>MapplsRes` task names. If they change, builds without
    config fail again.
  - `MainActivity` looks for the `mappls_olf_data` resource and the
    `mappls-conf.txt` asset that the plugin generates.
- **AGP upgrade risk.** The plugin uses the legacy variant API
  (`applicationVariants`), which works only with `android.newDsl=false` in
  `android/gradle.properties` (AGP 9.1). Removing that flag, or an AGP
  version that drops the legacy API, breaks the Mappls build step.
- **Kotlin Gradle Plugin warning.** The plugin applies KGP itself, and
  Flutter warns that future versions will refuse such plugins. That is
  another reason to re-check on a Flutter upgrade.
- **`js` (discontinued)** arrives transitively through `mappls_gl_web`. It
  is unused on Android/iOS.

### iOS (not set up yet)

The iOS config pair (`.i.olf`/`.i.conf`) is still pending. On a Mac:
- Add both files to the Runner target (Copy Bundle Resources) from outside
  the repo, for example with a build phase that copies them from
  `$MAPPLS_CONFIG_DIR`. They must stay untracked.
- mappls_gl needs Swift Package Manager for Flutter
  (`flutter config --enable-swift-package-manager`).
- Answer the `in.jivo.quick/maps` channel in `AppDelegate.swift`, returning
  whether the config is in the bundle.
- Drop the Android-only check in
  `lib/features/location/data/maps_availability.dart`.
- Add `NSLocationWhenInUseUsageDescription`, which is already present.

Until then iOS always shows the no-map fallback.

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
