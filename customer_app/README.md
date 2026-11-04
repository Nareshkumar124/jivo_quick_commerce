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
- `MainActivity.kt` answers `prepare` on the `in.jivo.quick/maps` channel
  (see "Why Mappls starts lazily" below). `PlatformMapsAvailability` calls
  it only when a screen needs a map, so a map is only created when the
  config is in the APK and the SDK accepted it. A map error (for example
  failed authentication) also falls back, and the code is logged
  (`Mappls map error <code>: <message>` in `flutter logs`/logcat).

### Why Mappls starts lazily (launch crash, 2026-11-03)

**Symptom.** The app crashed at launch on a phone (dev release build), on
the thread `pool-N-thread-1`, with an uncaught `IllegalStateException`:
- no config built in: `Please apply plugin"com.mappls.services.android"…`
- config present but not registered for the package/fingerprint:
  `You are using Invalid Configuration. Please check your Package Name /
  App Fingerprint…`

**Root cause.** Not a manifest provider (the merged manifest has none from
Mappls). The flutter tool generates
`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`,
which registers every plugin on every engine start. mappls_gl's
`MapplsMapsPlugin.onAttachedToEngine` creates `GlobalMethodHandler`, whose
constructor calls `Mappls.getInstance(context)`. That runs the SDK's config
check (`MapplsApiManager.init` → `MapplsInitialiser.initialise`) on its own
executor thread, which throws and kills the process before any Dart code
can fall back. A swallowing uncaught-exception handler is not a fix: Android
still logs `FATAL EXCEPTION` to the crash buffer, and the SDK is left
half-started.

**Fix.**
1. `android/app/build.gradle.kts`, task `stripMapplsAutoRegistration`:
   before Kotlin/Java compilation it removes the `MapplsMapsPlugin` block
   from the generated registrant (the flutter tool writes that file before
   Gradle runs). It only rewrites the file when it changes, and **fails the
   build** if `MapplsMapsPlugin` is still in it afterwards, so a template
   change can't silently bring the crash back. Background engines use the
   same registrant, so they never start Mappls either.
2. `MainActivity` registers the plugin on demand. On `prepare` it checks,
   once per process and off the main thread:
   - the `mappls_olf_data` resource and `mappls-conf.txt` asset are in the
     APK (if not, the SDK is never touched);
   - the SDK's own check, `MapplsInitialiser.getInstance().initialise()`,
     passes inside a try/catch. It is the exact call that throws in both
     crash cases, so a bad config is caught here instead of on the SDK's
     thread. Failures log `Mappls unavailable: <exception>` (tag
     `JivoMaps`, never the config contents).

   Only then is `MapplsMapsPlugin()` added to the engine (main thread, once
   per engine), and `prepare` returns true. Otherwise it returns false and
   the picker shows "Map isn't available".
3. `compileOnly("com.mappls.sdk:mappls-core:1.0.2")` in
   `android/app/build.gradle.kts` makes `MapplsInitialiser` visible to
   `MainActivity`; the runtime copy still comes from mappls_gl.

**Re-check after any mappls_gl (or Flutter) upgrade:**
- `mappls-core`'s version in `android/app/build.gradle.kts` must equal the
  one mappls_gl resolves
  (`cd android && ./gradlew :app:dependencies --configuration devReleaseRuntimeClasspath | grep mappls-core`).
- `GlobalMethodHandler`/`MapplsMapsPlugin` in the new plugin: if it still
  starts the SDK on attach, keep the strip. If the strip task fails the
  build, update its regex to the new registrant format.
- `MapplsInitialiser.initialise(Context)` must still exist and still be the
  call that validates the config.
- Launch check on a device, without config (`tool/setup_mappls.sh
  --remove`) and with it: build the dev release APK, `adb logcat -b crash
  -c`, start the app, wait ~10 s, then `pidof in.jivo.quick.dev` must print
  a pid and `adb logcat -b crash -d` must have no `FATAL`. Then open "Pick
  on map": with an unregistered config it shows the fallback, and logcat
  shows `JivoMaps: Mappls unavailable: …`.

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
- **Keep `mappls_gl` pinned at exactly 2.0.7.** These depend on its
  internals and must be re-checked on any upgrade:
  - The no-config guard in `android/build.gradle.kts` matches the plugin's
    `generate<Variant>MapplsRes` task names. If they change, builds without
    config fail again.
  - `MainActivity` looks for the `mappls_olf_data` resource and the
    `mappls-conf.txt` asset that the plugin generates.
  - The lazy start above: the registrant strip, `MapplsInitialiser`, and the
    `mappls-core` version (see "Re-check after any mappls_gl upgrade").
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

## Payments: Razorpay (D-01)

`razorpay_flutter` **1.4.7, pinned exactly** sits behind `PaymentLauncher`
(`lib/features/checkout/data/`). The app never trusts the SDK's answer: an
order is shown as placed only after `POST /payments/razorpay/verify/` (or
the order's server status) confirms it (`08 §4`).
- **Which checkout opens** (`GatewayPaymentLauncher`) depends on the
  `razorpay.key_id` that `POST /orders/` returns:
  - `rzp_fake_…` in the **dev** flavor: the backend's local fake gateway
    (`06 §2.6`). No Razorpay, no money: the "Test payment (dev build)"
    sheet lets the tester pick success, a bad signature, failure, an
    external wallet (result by webhook) or closing checkout. Success makes
    up a `pay_` + 14-character id and signs `"<order_id>|<payment_id>"`
    with HMAC-SHA256 and the published dev-only secret
    `jivo-fake-razorpay-key-secret-local-only` (not a secret: only the fake
    gateway accepts it, and deployed servers refuse that gateway).
  - `rzp_fake_…` in **staging or prod**: refused as a failed payment; the
    fake is never opened there.
  - any other key, in every flavor: real Razorpay Standard Checkout, with
    the server's options passed through unchanged (key, order id, amount
    in paise, currency, name, description, prefill, `timeout`).
- **Stale results.** The plugin keeps a checkout result that arrives after
  the app was killed and replays it (its `resync`) on the next checkout.
  The launcher drains that reply first, ignores success and error events
  for another Razorpay order, and gives up after the payment window plus
  2 minutes if no event ever arrives. These rely on the plugin's channel
  name and `resync` call: re-check them on any plugin upgrade (the version
  is pinned for that reason).
- **Release builds (R8):** `android/app/proguard-rules.pro` holds Razorpay's
  documented keep rules; the Flutter Gradle plugin adds that file to every
  release build automatically. The SDK also ships its own consumer rules.
- **Native SDK pinned:** the plugin asks for `com.razorpay:checkout:1.6.+`,
  and checkout for `standard-core:latest.integration`: both float.
  `android/app/build.gradle.kts` forces **checkout 1.6.41, standard-core
  1.7.22 and core 1.0.22**, the set the R8 rules, manifest and permissions
  below were checked against. Check with
  `./gradlew :app:dependencies --configuration devReleaseRuntimeClasspath | grep razorpay`.
- `razorpay_flutter` registers through `GeneratedPluginRegistrant` like any
  plugin; the Mappls strip task removes only `MapplsMapsPlugin`.

## Play Data Safety / permissions

Everything the release manifest adds beyond what the app's own code asks
for, checked in the merged manifest
(`build/app/outputs/logs/manifest-merger-dev-release-report.txt`) with
`com.razorpay:checkout` 1.6.41. None of these shows a runtime prompt.

| Permission or component | From | Why | Kept? |
|---|---|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | the app, Razorpay `core` | API calls; Razorpay checks connectivity | Yes |
| `READ_BASIC_PHONE_STATE` | Razorpay `core` 1.0.22 | Razorpay reads basic device/network state during checkout. Android documents it as a non-dangerous permission (no prompt; network type, software version only). | Yes (PM decision, review of `06b7c07`) |
| `NFC` | Razorpay `standard-core` 1.7.22 | Razorpay's "Card Tap & Read" in Standard Checkout reads the card number and expiry by tapping the card; on by default, opted out only through Razorpay support | Yes: removing it could break card payments, which can't be tested without a device |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | `androidx.biometric` 1.1.0, through `androidx.credentials` used by `smart_auth` (OTP autofill, since Phase 1), not Razorpay | Credential Manager's biometric prompts | Yes: not proven unneeded by `smart_auth` without a device test |
| `ACCESS_WIFI_STATE` | Mappls SDK 9.0.4 (Phase 2) | map SDK network checks | Yes |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | the app (`geolocator`, Phase 2) | delivery location | Yes |
| `com.razorpay.CheckoutActivity` (not exported) | Razorpay `checkout` | the checkout screen | Yes |
| `com.razorpay.DeeplinkActivity`, **exported**, `razorpay://<applicationId>` (per flavor) | Razorpay `core` | the return link after a UPI app or bank page. Its bytecode only records the URL in Razorpay's SDK analytics, disables itself and finishes; it passes nothing to the app. | Yes |
| `MagicXActivity`, `UpiChooserSelectionReceiver` (not exported) | Razorpay | UPI app chooser | Yes |
| `RazorpayInitializer`, `CoreInitializer` (androidx.startup, not exported) | Razorpay `standard-core` | run at process start (post work to the main thread, register activity callbacks) in every flavor | Yes; **launch check on a device pending** |

**Data Safety (Play Console), for the Razorpay SDK (to confirm):** what we
can see is that customers enter card and UPI details in Razorpay's own
screens (sent to Razorpay, never to Jivo's servers), the prefill passes the
customer's name, phone and email to checkout, and the SDK has its own
analytics (seen in `DeeplinkActivity`). The Play SDK index gives no Data
Safety guidance for `com.razorpay:checkout`, so get the exact data types
from Razorpay before filling the form.

## Tests

```sh
flutter test                                    # unit + widget tests
```

Integration tests run on an emulator or device, one file at a time:

| File | Flow | Default backend |
|------|------|-----------------|
| `integration_test/login_flow_test.dart` | P1: phone, OTP, profile, address, logout | fakes; `--dart-define=REAL_API=true` for the real API |
| `integration_test/browse_flow_test.dart` | P2: login, detect location (serviceability), home, product, search, add to the dev fake cart (TODO(api) until S3-A) | **real API**; `--dart-define=FAKE_API=true` for fakes |
| `integration_test/map_picker_test.dart` | Mappls map or fallback (D-03) | none |

```sh
# P2 browse against the local backend from the Android emulator. The fake
# device location is Sector 14, Gurugram (seeded store id 1).
flutter test integration_test/browse_flow_test.dart --flavor dev \
  -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8001
```

The browse test prints `BROWSE ...` lines (mode, store, products, search
results, cart, and the `X-Store-Id` on each request) as evidence of which
backend it ran against.

On a physical phone over USB, forward the port first
(`adb -s <serial> reverse tcp:8001 tcp:8001`, again after each install) and
use `--dart-define=API_BASE_URL=http://localhost:8001`. Some phones can't
attach `flutter test` (seen on a Realme RMX5056, Android 16): with DDS it
fails with "Failed to start Dart Development Service"; with `--no-dds` it
fails with `streamListen: invalid 'streamId' parameter:
integration_test.VmServiceProxyGoldenFileComparator`, because only DDS
provides that stream. The fallback is `flutter drive` with the host driver,
whose harness doesn't use that stream (not yet verified on that phone):

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/browse_flow_test.dart --flavor dev \
  -d <serial> --no-dds --dart-define=API_BASE_URL=http://localhost:8001
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
