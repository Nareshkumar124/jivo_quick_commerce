import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/launch/data/fake_app_config_repository.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

/// UX audit RA-01: the blocking screens (force update, maintenance, splash
/// error, status) must keep their buttons on screen at 200 % text on a
/// 360×640 dp phone. Before the fix the fixed-height column overflowed and
/// cut the only way forward off the bottom.
void main() {
  late RiderTestHarness h;

  setUp(() {
    h = RiderTestHarness()..surface = const Size(945, 1680); // 360×640 dp
  });

  Future<void> doubleText(WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
  }

  /// The whole button rectangle is inside the 360×640 dp screen.
  void expectOnScreen(WidgetTester tester, String key) {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: key);
    final rect = tester.getRect(finder);
    expect(
      rect.top >= 0 &&
          rect.left >= 0 &&
          rect.bottom <= 640 + 0.01 &&
          rect.right <= 360 + 0.01,
      isTrue,
      reason: '$key at $rect',
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('forced update: "Update now" stays on screen and works', (
    tester,
  ) async {
    await h.pump(tester);
    h.signals.reportUpdateRequired(
      AppUpdateRequired(storeUrl: Uri.parse('https://example.com/store')),
    );
    await doubleText(tester);

    expectOnScreen(tester, 'update-now');
    await tester.tap(find.byKey(const Key('update-now')));
    expect(h.urls.opened, isNotEmpty);
  });

  testWidgets('optional update: "Update now" and "Later" on screen', (
    tester,
  ) async {
    h.config = FakeAppConfigRepository(
      scenario: FakeConfigScenario.softUpdate,
      delay: Duration.zero,
    );
    await h.pump(tester);
    await doubleText(tester);
    expectOnScreen(tester, 'update-now');
    expectOnScreen(tester, 'update-later');
  });

  testWidgets('maintenance with a 300-character server message', (
    tester,
  ) async {
    await h.pump(tester);
    h.signals.reportMaintenance(
      MaintenanceMode(message: List.filled(30, 'Back soon. ').join()),
    );
    await doubleText(tester);
    expectOnScreen(tester, 'maintenance-retry');
  });

  testWidgets('splash error: "Try again" on screen', (tester) async {
    h.config.failWith = const ApiError(code: ApiErrorCode.network);
    await h.pump(tester);
    await doubleText(tester);
    expectOnScreen(tester, 'splash-retry');
  });

  testWidgets('suspended: "Call support" on screen', (tester) async {
    await h.signedInBefore(suspendedPhone);
    await h.pump(tester);
    await doubleText(tester);
    expectOnScreen(tester, 'call-support');
  });
}
