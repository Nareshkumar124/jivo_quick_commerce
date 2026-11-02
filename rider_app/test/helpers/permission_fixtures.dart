import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';

/// Android 14 phone with nothing granted yet (fresh install).
const freshInstall = PermissionSnapshot(
  sdkInt: 34,
  manufacturer: 'Google',
  locationWhenInUse: Grant.denied,
  locationAlways: Grant.denied,
  notifications: Grant.denied,
  batteryOptimisationIgnored: false,
  gpsEnabled: false,
  fullScreenIntentAllowed: true,
);

/// Android 14 phone with every gate item done.
final allGranted = freshInstall.copyWith(
  locationWhenInUse: Grant.granted,
  locationAlways: Grant.granted,
  notifications: Grant.granted,
  batteryOptimisationIgnored: true,
  gpsEnabled: true,
);
