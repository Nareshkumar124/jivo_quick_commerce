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
    required this.fullScreenIntentAllowed,
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

  final bool batteryOptimisationIgnored;

  /// Device location (GPS) switched on.
  final bool gpsEnabled;

  /// USE_FULL_SCREEN_INTENT, Android 14+. Not blocking (see PermissionGate).
  final bool fullScreenIntentAllowed;

  PermissionSnapshot copyWith({
    int? sdkInt,
    String? manufacturer,
    Grant? locationWhenInUse,
    Grant? locationAlways,
    Grant? notifications,
    bool? batteryOptimisationIgnored,
    bool? gpsEnabled,
    bool? fullScreenIntentAllowed,
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
    fullScreenIntentAllowed:
        fullScreenIntentAllowed ?? this.fullScreenIntentAllowed,
    locationPrecise: locationPrecise ?? this.locationPrecise,
  );
}
