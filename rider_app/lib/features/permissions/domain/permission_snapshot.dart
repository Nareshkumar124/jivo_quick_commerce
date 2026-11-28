import 'package:flutter/foundation.dart';

/// State of one runtime permission, reduced to what the gate needs.
enum Grant {
  granted,

  /// Not granted, but the app can still show the system prompt.
  denied,

  /// Permanently denied (or restricted): only the app's system settings page
  /// can change it.
  blocked,
}

/// Everything the permissions gate checks, read from the device at one point
/// in time (`docs/04-rider-app.md` §2.1).
@immutable
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.sdkInt,
    required this.manufacturer,
    required this.locationWhenInUse,
    required this.locationAlways,
    required this.notifications,
    required this.batteryOptimisationIgnored,
    required this.gpsEnabled,
    this.locationPrecise = true,
  });

  /// Android API level (`Build.VERSION.SDK_INT`).
  final int sdkInt;

  /// `Build.MANUFACTURER`, for OEM auto-start guidance.
  final String manufacturer;

  /// Fine location while the app is in use.
  final Grant locationWhenInUse;

  /// Whether the location grant is precise. Android 12+ lets the rider pick
  /// "Approximate" (about 2 km), which cannot guide a delivery; the gate then
  /// keeps the location step open (04 §2.1). Always true below Android 12.
  final bool locationPrecise;

  /// Background location ("Allow all the time"), Android 10+.
  final Grant locationAlways;

  /// POST_NOTIFICATIONS, Android 13+.
  final Grant notifications;

  /// The system already exempts the app from battery optimisation. Read
  /// only, for the optional battery tip: never blocking, and the app never
  /// asks for the exemption itself (Play policy, 2026-11-28).
  final bool batteryOptimisationIgnored;

  /// Device location (GPS) switched on.
  final bool gpsEnabled;

  PermissionSnapshot copyWith({
    int? sdkInt,
    String? manufacturer,
    Grant? locationWhenInUse,
    Grant? locationAlways,
    Grant? notifications,
    bool? batteryOptimisationIgnored,
    bool? gpsEnabled,
    bool? locationPrecise,
  }) => PermissionSnapshot(
    sdkInt: sdkInt ?? this.sdkInt,
    manufacturer: manufacturer ?? this.manufacturer,
    locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
    locationAlways: locationAlways ?? this.locationAlways,
    notifications: notifications ?? this.notifications,
    batteryOptimisationIgnored:
        batteryOptimisationIgnored ?? this.batteryOptimisationIgnored,
    gpsEnabled: gpsEnabled ?? this.gpsEnabled,
    locationPrecise: locationPrecise ?? this.locationPrecise,
  );
}

/// Android's app-op mode for location (`AppOpsManager`), read next to the
/// runtime permission. The permission alone can read "granted" while the
/// op says the app gets no location (device test 2026-11-17: COARSE/FINE
/// `ignore`), so the gate checks both.
enum LocationOpMode {
  /// MODE_ALLOWED: location at any time ("Allow all the time").
  allowed,

  /// MODE_FOREGROUND: only while the app is in use.
  foreground,

  /// MODE_IGNORED / MODE_ERRORED: no location.
  denied,

  /// MODE_DEFAULT or unreadable: the runtime permission decides.
  unknown;

  static LocationOpMode fromWire(Object? value) => switch (value) {
    'allowed' => allowed,
    'foreground' => foreground,
    'ignored' || 'errored' => denied,
    _ => unknown,
  };
}

/// The live grant of a location permission: the runtime [permission]
/// corrected by its app-op [op]. [background] is "Allow all the time",
/// which needs the op allowed at any time, not only in the foreground.
///
/// A permission the system reports as granted while the op denies it can
/// only be changed on the app's settings page, so it is [Grant.blocked].
/// The same holds for "all the time" granted while the op is foreground
/// only: asking again would return at once without a prompt.
Grant liveLocationGrant(
  Grant permission,
  LocationOpMode op, {
  required bool background,
}) {
  if (permission != Grant.granted) return permission;
  return switch (op) {
    LocationOpMode.unknown || LocationOpMode.allowed => Grant.granted,
    LocationOpMode.foreground => background ? Grant.blocked : Grant.granted,
    LocationOpMode.denied => Grant.blocked,
  };
}
