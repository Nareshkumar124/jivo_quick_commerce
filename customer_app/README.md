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

## Maps: Google Maps (DL-80)

The map pin picker and the live tracking map use `google_maps_flutter`.
Reverse geocoding (the address under the pin) uses the `geocoding` package,
i.e. the device's own geocoder: no API key, no billing, and no result on
devices without a geocoder service (the picker then shows coordinates).

### Google Maps key

- The Android Maps SDK key is **never committed**. Put it in
  `~/.config/jivo-quick-commerce/google-maps/android-api-key.txt`
  (on this machine `C:/Users/89 USER/.config/...`), one line, or pass it as
  the Gradle property / env var `MAPS_API_KEY` (checked first, e.g. in CI).
- `android/app/build.gradle.kts` reads it at build time and injects it as
  the manifest meta-data `com.google.android.geo.API_KEY`. The build log
  says `Google Maps key found.` or `... not found: building without maps.`
- The key is restricted in the Google Cloud console to Android apps by
  package name + SHA-1 signing fingerprint (`in.jivo.quick`,
  `in.jivo.quick.dev`, `in.jivo.quick.staging`; debug, upload and Play app
  signing certificates) and to the Maps SDK for Android API.
- **No key:** the build still succeeds; `MainActivity` answers the
  `in.jivo.quick/maps` channel with false, so no map is ever created and the
  picker shows its current-location / manual-address fallback and tracking
  shows the route sketch.
- **iOS: deferred.** There is no iOS key or config yet, so
  `PlatformMapsAvailability` reports iOS as unavailable and iOS always shows
  the fallback. To enable it later, add the key in `AppDelegate.swift`
  (`GMSServices.provideAPIKey`) from an untracked file, answer the maps
  channel there, and drop the Android-only check in
  `lib/features/location/data/maps_availability.dart`.

## Push: Firebase Cloud Messaging (D-19)

Push uses `firebase_core` 5.2.0 + `firebase_messaging` 17.1.0, and
`flutter_local_notifications` 22.3.3 for the channels and foreground
notifications. **Every environment uses the same mechanism; only the config
file differs:** each flavor reads its own
`android/app/src/<flavor>/google-services.json` (private, gitignored).

| Env (Firebase project) | Flavor | Android app id | Config source |
|---|---|---|---|
| dev (`jivo-quick`) | `dev` | `in.jivo.quick.dev` | `~/.config/jivo-quick-commerce/firebase/dev/google-services.json` |
| staging (not created yet) | `staging` | `in.jivo.quick.staging` | `…/firebase/staging/google-services.json` |
| prod (not created yet) | `prod` | `in.jivo.quick` | `…/firebase/prod/google-services.json` |

```bash
customer_app/tool/setup_firebase.sh --copy                # dev flavor <- dev env
customer_app/tool/setup_firebase.sh --copy --env staging  # when that project exists
customer_app/tool/setup_firebase.sh --copy --env all      # every env that has a file
customer_app/tool/setup_firebase.sh --remove [--env ...]  # back to "push off"
FIREBASE_CONFIG_DIR=/other/folder customer_app/tool/setup_firebase.sh --copy
```

The script copies (mode 600), checks that the file registers the flavor's
application id and that the destination is gitignored, and prints file names
only. It never reads `service-account.json` (a server credential that may
sit in the same folder). Rebuild after copying.

**Without the file** (CI, a fresh checkout, a flavor whose project doesn't
exist yet) the build still succeeds:
- `android/app/build.gradle.kts` applies the `com.google.gms.google-services`
  plugin (4.5.0) only when at least one flavor has its file, and then with
  `missingGoogleServicesStrategy = WARN`, so the other flavors build too.
- At run time `initializePush()` (`lib/features/notifications/data/push_setup.dart`)
  calls `Firebase.initializeApp()`; with no config it fails and the app runs
  with `NoopPushMessaging`: no permission prompt, no token, no registration.
  Everything else works. Logcat shows `Push: Firebase is not configured for
  this build`.

**Behaviour** (03 §2.12):
- Channels `orders` (high importance: order status, delivery OTP, support
  replies) and `general` (default: offers and the rest) are created at
  start-up. A message without `android.notification.channel_id` goes to
  `general` (manifest default), so the backend must name `orders` for order
  and support events.
- Notification permission (Android 13+ `POST_NOTIFICATIONS`) is asked right
  after sign-in and again on the first order's "Order placed" screen, each
  at most once per install; never on cold start.
- The token is registered with `POST /me/devices/` on sign-in, on each start
  while signed in and on token refresh. Logout sends it as `fcm_token`; after
  any sign-out (also an expired session) the local token is deleted, so the
  next sign-in registers a fresh one.
- Background/terminated: the system shows the notification; a tap opens its
  screen through `deep_links.dart` (`getInitialMessage` / `onMessageOpenedApp`).
  Foreground: shown as a local notification on the same channel; a tap routes
  the same way. No Dart background handler is registered (no data-only
  messages in v1).
- iOS: TODO. Needs `GoogleService-Info.plist` per flavor and the APNs key in
  the Firebase project; until then `Firebase.initializeApp()` fails on iOS and
  push is off there.

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
  plugin.

## Play Data Safety / permissions

Everything the release manifest adds beyond what the app's own code asks
for, checked in the merged manifest
(`build/app/outputs/logs/manifest-merger-dev-release-report.txt`) with
`com.razorpay:checkout` 1.6.41. Only the app's own location and notification permissions show a runtime prompt.

| Permission or component | From | Why | Kept? |
|---|---|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | the app, Razorpay `core` | API calls; Razorpay checks connectivity | Yes |
| `READ_BASIC_PHONE_STATE` | Razorpay `core` 1.0.22 | Razorpay reads basic device/network state during checkout. Android documents it as a non-dangerous permission (no prompt; network type, software version only). | Yes (PM decision, review of `06b7c07`) |
| `NFC` | Razorpay `standard-core` 1.7.22 | Razorpay's "Card Tap & Read" in Standard Checkout reads the card number and expiry by tapping the card; on by default, opted out only through Razorpay support | Yes: removing it could break card payments, which can't be tested without a device |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | `androidx.biometric` 1.1.0, through `androidx.credentials` used by `smart_auth` (OTP autofill, since Phase 1), not Razorpay | Credential Manager's biometric prompts | Yes: not proven unneeded by `smart_auth` without a device test |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | the app (`geolocator`, Phase 2) | delivery location | Yes |
| `POST_NOTIFICATIONS` (runtime prompt on Android 13+, after sign-in or the first order) | the app (FCM, D-19) | order and support notifications | Yes |
| `WAKE_LOCK`, `VIBRATE`; `FirebaseMessagingService`, `FirebaseInstanceIdReceiver`, `FirebaseInitProvider`, `ComponentDiscoveryService` | `firebase_messaging` / Firebase SDK, `flutter_local_notifications` (2026-11-17) | receiving pushes, notification vibration | Yes (checked in the dev-release merged manifest) |
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
| `integration_test/map_picker_test.dart` | Google map or fallback (DL-80) | none |

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
- **Push (D-19).** Add `GoogleService-Info.plist` per flavor (gitignored, like
  the Android file), enable the Push Notifications and Background Modes →
  Remote notifications capabilities, and upload the APNs key to the Firebase
  project. Until then push is off on iOS (`initializePush()` falls back).
