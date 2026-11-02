import 'package:jivo_core/jivo_core.dart';

/// Rider-specific view of jivo_core's [AppEnv] (flavor, API base URL, Sentry
/// DSN, `FAKE_API`).
extension RiderAppEnv on AppEnv {
  /// Developer screens (location spike, offer alert test, permissions gate)
  /// exist in the dev flavor only.
  bool get showDevTools => flavor == Flavor.dev;
}
