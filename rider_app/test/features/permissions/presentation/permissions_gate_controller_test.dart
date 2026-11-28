import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/features/permissions/domain/permission_gate.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/permission_fixtures.dart';

void main() {
  late StubbedPermissions perms;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [permissionsServiceProvider.overrideWithValue(perms.service)],
  );

  PermissionsGateController controller() =>
      container.read(permissionsGateControllerProvider.notifier);

  tearDown(() => container.dispose());

  test('evaluates the device snapshot', () async {
    perms = StubbedPermissions(freshInstall);
    container = makeContainer();

    final evaluation = await container.read(
      permissionsGateControllerProvider.future,
    );

    expect(evaluation.next!.step, GateStep.disclosure);
  });

  test(
    'accepting the disclosure goes straight to the location prompt',
    () async {
      perms = StubbedPermissions(freshInstall);
      container = makeContainer();
      await container.read(permissionsGateControllerProvider.future);

      await controller().acceptDisclosure();

      verify(() => perms.service.requestLocationWhenInUse()).called(1);
      verifyNever(() => perms.service.requestLocationAlways());
    },
  );

  test('never asks for background location before the disclosure', () async {
    perms = StubbedPermissions(
      freshInstall.copyWith(locationWhenInUse: Grant.granted),
    );
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);

    await controller().fix(
      const GateItem(GateStep.locationAlways, done: false),
    );
    verifyNever(() => perms.service.requestLocationAlways());

    await controller().acceptDisclosure();
    verify(() => perms.service.requestLocationAlways()).called(1);
  });

  test('never asks for while-in-use location before the disclosure, except '
      'to upgrade "Approximate" once background location is granted', () async {
    perms = StubbedPermissions(freshInstall);
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);

    await controller().fix(
      const GateItem(GateStep.locationWhenInUse, done: false),
    );
    verifyNever(() => perms.service.requestLocationWhenInUse());

    container.dispose();
    perms = StubbedPermissions(allGranted.copyWith(locationPrecise: false));
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);
    await controller().fix(
      const GateItem(
        GateStep.locationWhenInUse,
        done: false,
        approximate: true,
      ),
    );
    verify(() => perms.service.requestLocationWhenInUse()).called(1);
  });

  test('a blocked item opens the app settings page instead', () async {
    perms = StubbedPermissions(
      freshInstall.copyWith(notifications: Grant.blocked),
    );
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);

    await controller().fix(
      const GateItem(GateStep.notifications, done: false, blocked: true),
    );

    verify(() => perms.service.openAppSettings()).called(1);
    verifyNever(() => perms.service.requestNotifications());
  });

  test('the GPS step uses its system page', () async {
    perms = StubbedPermissions(freshInstall);
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);

    await controller().fix(const GateItem(GateStep.gps, done: false));

    verify(() => perms.service.openLocationSettings()).called(1);
  });

  test('the battery tip opens the system battery list and re-reads the '
      'device; skipping hides it for the session', () async {
    perms = StubbedPermissions(
      allGranted.copyWith(batteryOptimisationIgnored: false),
    );
    container = makeContainer();
    final before = await container.read(
      permissionsGateControllerProvider.future,
    );
    expect(before.batteryTip, isTrue);
    expect(before.canGoOnline, isTrue);

    perms.current = allGranted;
    await controller().openBatteryOptimisationSettings();

    verify(() => perms.service.openBatteryOptimisationSettings()).called(1);
    expect(
      container.read(permissionsGateControllerProvider).requireValue.batteryTip,
      isFalse,
    );

    expect(container.read(batteryTipSkippedProvider), isFalse);
    controller().skipBatteryTip();
    expect(container.read(batteryTipSkippedProvider), isTrue);
  });

  test('refresh picks up changes made in system settings', () async {
    perms = StubbedPermissions(freshInstall);
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);

    perms.current = allGranted;
    final evaluation = await controller().refresh();

    expect(evaluation.canGoOnline, isTrue);
    expect(
      container.read(permissionsGateControllerProvider).value?.canGoOnline,
      isTrue,
    );
  });

  test('coming back without "Allow all the time": explain and offer the app '
      'settings page; still blocked', () async {
    perms = StubbedPermissions(
      allGranted.copyWith(locationAlways: Grant.denied),
    );
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);
    await controller().acceptDisclosure();

    verify(() => perms.service.requestLocationAlways()).called(1);
    expect(container.read(gateNoticesProvider).alwaysNotChosen, isTrue);
    expect(
      container.read(permissionsGateControllerProvider).value!.canGoOnline,
      isFalse,
    );

    perms.current = allGranted;
    await controller().openLocationAlwaysSettings();
    verify(() => perms.service.openAppSettings()).called(1);
    expect(
      container.read(permissionsGateControllerProvider).value!.canGoOnline,
      isTrue,
    );
  });

  test('declining the disclosure requests nothing and says why', () async {
    perms = StubbedPermissions(freshInstall);
    container = makeContainer();
    await container.read(permissionsGateControllerProvider.future);
    controller().declineDisclosure();

    expect(container.read(gateNoticesProvider).disclosureDeclined, isTrue);
    verifyNever(() => perms.service.requestLocationWhenInUse());
    verifyNever(() => perms.service.requestLocationAlways());
  });
}
