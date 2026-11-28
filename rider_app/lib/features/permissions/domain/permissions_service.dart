import 'permission_snapshot.dart';

/// Reads and requests the permissions behind the gate. The platform
/// implementation wraps permission_handler, geolocator and the device channel.
abstract interface class PermissionsService {
  Future<PermissionSnapshot> snapshot();

  /// System prompt for fine location ("While using the app").
  Future<void> requestLocationWhenInUse();

  /// "Allow all the time". On Android 11+ the system opens the app's location
  /// settings page instead of a dialog.
  Future<void> requestLocationAlways();

  Future<void> requestNotifications();

  /// The system list of battery-optimised apps, for the optional battery
  /// tip. Never the direct "ignore battery optimisations" request: Play
  /// restricts that permission to a short list of app types.
  Future<void> openBatteryOptimisationSettings();

  /// Device location settings, to switch GPS on.
  Future<void> openLocationSettings();

  /// The app's system settings page (permanently denied permissions, OEM
  /// auto-start).
  Future<void> openAppSettings();
}
