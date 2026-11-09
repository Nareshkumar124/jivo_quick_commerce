import 'package:jivo_core/jivo_core.dart';

/// Rider-specific view of jivo_core's [AppEnv] (flavor, API base URL, Sentry
/// DSN, `FAKE_API`).
extension RiderAppEnv on AppEnv {
  /// Developer screens (location spike, offer alert test, permissions gate)
  /// exist in the dev flavor only.
  bool get showDevTools => flavor == Flavor.dev;

  /// Fakes run only in the dev flavor with `FAKE_API` (DL-30, DL-32):
  /// staging ignores `FAKE_API` and always talks to the real API (prod
  /// never enables it, see `AppEnv.resolve`).
  bool get useRiderFakes => flavor == Flavor.dev && useFakeApi;
}
