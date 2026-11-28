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
    // Live: the runtime permission corrected by the location app-op, read
    // every time (never cached; device test 2026-11-17).
    final ops = await _device.locationOps();
    final coarseOp = LocationOpMode.fromWire(ops?['coarse']);
    final whenInUse = liveLocationGrant(
      _grant(results[0]),
      coarseOp,
      background: false,
    );
    final always = liveLocationGrant(
      _grant(results[1]),
      coarseOp,
      background: true,
    );
    final fineOp = LocationOpMode.fromWire(ops?['fine']);
    return PermissionSnapshot(
      sdkInt: info.sdkInt,
      manufacturer: info.manufacturer,
      locationWhenInUse: whenInUse,
      locationPrecise:
          whenInUse != Grant.granted ||
          (fineOp != LocationOpMode.denied && await _isPrecise()),
      locationAlways: always,
      notifications: _grant(results[2]),
      batteryOptimisationIgnored: await _device
          .isIgnoringBatteryOptimizations(),
      gpsEnabled: await Geolocator.isLocationServiceEnabled(),
    );
  }

  /// Android 12+ "Precise" vs "Approximate". Assumes precise if the check
  /// fails, so a plugin error never blocks a rider who granted it.
  static Future<bool> _isPrecise() async {
    try {
      return await Geolocator.getLocationAccuracy() !=
          LocationAccuracyStatus.reduced;
    } on Object {
      return true;
    }
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
  Future<void> openBatteryOptimisationSettings() =>
      _device.openBatteryOptimizationSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => ph.openAppSettings();
}
