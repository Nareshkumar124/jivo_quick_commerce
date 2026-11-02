import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../shared/platform/device_channel.dart';
import '../domain/permission_snapshot.dart';
import '../domain/permissions_service.dart';

/// Android implementation of [PermissionsService].
class PlatformPermissionsService implements PermissionsService {
  const PlatformPermissionsService({this._device = const DeviceChannel()});

  final DeviceChannel _device;

  @override
  Future<PermissionSnapshot> snapshot() async {
    final info = await _device.deviceInfo();
    final results = await Future.wait([
      ph.Permission.locationWhenInUse.status,
      ph.Permission.locationAlways.status,
      ph.Permission.notification.status,
    ]);
    return PermissionSnapshot(
      sdkInt: info.sdkInt,
      manufacturer: info.manufacturer,
      locationWhenInUse: _grant(results[0]),
      locationAlways: _grant(results[1]),
      notifications: _grant(results[2]),
      batteryOptimisationIgnored:
          await ph.Permission.ignoreBatteryOptimizations.isGranted,
      gpsEnabled: await Geolocator.isLocationServiceEnabled(),
      fullScreenIntentAllowed: await _device.canUseFullScreenIntent(),
    );
  }

  static Grant _grant(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted || ph.PermissionStatus.limited => Grant.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => Grant.blocked,
    _ => Grant.denied,
  };

  @override
  Future<void> requestLocationWhenInUse() =>
      ph.Permission.locationWhenInUse.request();

  @override
  Future<void> requestLocationAlways() =>
      ph.Permission.locationAlways.request();

  @override
  Future<void> requestNotifications() => ph.Permission.notification.request();

  @override
  Future<void> requestIgnoreBatteryOptimisation() =>
      ph.Permission.ignoreBatteryOptimizations.request();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  @override
  Future<void> openFullScreenIntentSettings() =>
      _device.openFullScreenIntentSettings();
}
