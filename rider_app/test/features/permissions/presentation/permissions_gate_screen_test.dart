import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/permission_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late StubbedPermissions perms;

  Future<void> pumpGate(
    WidgetTester tester,
    PermissionSnapshot snapshot,
  ) async {
    perms = StubbedPermissions(snapshot);
    // The gate is a dev route: it opens without login or config.
    final h = RiderTestHarness();
    await h.session.restore();
    // Tall phone-like viewport so the whole checklist is built.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          ...h.overrides(),
          initialLocationProvider.overrideWithValue(Routes.permissions),
          permissionsServiceProvider.overrideWithValue(perms.service),
        ],
        child: const RiderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder primary() => find.byKey(const Key('gate-primary'));

  testWidgets('fresh install: checklist with one primary action, and the '
      'disclosure comes first', (tester) async {
    await pumpGate(tester, freshInstall);

    expect(find.text('Before you go online'), findsOneWidget);
    expect(find.text('Location: Allow all the time'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No battery restrictions'), findsOneWidget);
    expect(find.text('GPS on'), findsOneWidget);
    expect(
      find.descendant(of: primary(), matching: find.text('Continue')),
      findsOneWidget,
    );
    expect(tester.getSize(primary()).height, greaterThanOrEqualTo(56));
  });

  testWidgets('accepting the disclosure leads straight to the location '
      'prompt', (tester) async {
    await pumpGate(tester, freshInstall);

    await tester.tap(primary());
    await tester.pumpAndSettle();

    // Play's required wording for background location.
    expect(
      find.textContaining('even when the app is closed or not in use'),
      findsOneWidget,
    );
    verifyNever(() => perms.service.requestLocationWhenInUse());

    await tester.tap(find.byKey(const Key('disclosure-accept')));
    await tester.pumpAndSettle();

    verify(() => perms.service.requestLocationWhenInUse()).called(1);
    expect(find.text('Before you go online'), findsOneWidget);
  });

  testWidgets('"Not now" asks for nothing', (tester) async {
    await pumpGate(tester, freshInstall);

    await tester.tap(primary());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('disclosure-decline')));
    await tester.pumpAndSettle();

    verifyNever(() => perms.service.requestLocationWhenInUse());
    verifyNever(() => perms.service.requestLocationAlways());
  });

  testWidgets('shows OEM auto-start guidance on a Xiaomi phone', (
    tester,
  ) async {
    await pumpGate(tester, allGranted.copyWith(manufacturer: 'Xiaomi'));

    expect(find.text('All set. You can go online.'), findsOneWidget);
    expect(find.text('Keep Jivo Rider running'), findsOneWidget);
  });

  testWidgets('suggests full-screen alerts when Android 14 revoked them', (
    tester,
  ) async {
    await pumpGate(tester, allGranted.copyWith(fullScreenIntentAllowed: false));

    expect(find.text('Full-screen order alerts'), findsOneWidget);
    await tester.tap(find.text('Allow full-screen alerts'));
    verify(() => perms.service.openFullScreenIntentSettings()).called(1);
  });
}
