import 'package:mocktail/mocktail.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';
import 'package:rider_app/features/permissions/domain/permissions_service.dart';

class MockPermissionsService extends Mock implements PermissionsService {}

/// A mock whose snapshot is [initial] and whose request methods succeed
/// without changing it (tests update [current] themselves).
class StubbedPermissions {
  StubbedPermissions(PermissionSnapshot initial) : current = initial {
    when(() => service.snapshot()).thenAnswer((_) async => current);
    when(() => service.requestLocationWhenInUse()).thenAnswer((_) async {});
    when(() => service.requestLocationAlways()).thenAnswer((_) async {});
    when(() => service.requestNotifications()).thenAnswer((_) async {});
    when(() => service.requestIgnoreBatteryOptimisation())
        .thenAnswer((_) async {});
    when(() => service.openLocationSettings()).thenAnswer((_) async {});
    when(() => service.openAppSettings()).thenAnswer((_) async {});
    when(() => service.openFullScreenIntentSettings()).thenAnswer((_) async {});
  }

  final service = MockPermissionsService();
  PermissionSnapshot current;
}
