import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/launch/data/fake_app_config_repository.dart';
import 'package:rider_app/features/launch/domain/launch_gate.dart';

import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  Finder updateNow() => find.byKey(const Key('update-now'));
  Finder later() => find.byKey(const Key('update-later'));

  testWidgets('fresh install: splash loads config/app, then phone login', (
    tester,
  ) async {
    await h.pump(tester);

    expect(h.config.fetchCount, 1);
    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
  });

  testWidgets('force update blocks the app: no Later, Back does nothing, '
      'Update opens the store', (tester) async {
    h.config = FakeAppConfigRepository(
      scenario: FakeConfigScenario.forceUpdate,
      delay: Duration.zero,
    );
    await h.pump(tester);

    expect(find.text('Update required'), findsOneWidget);
    expect(updateNow(), findsOneWidget);
    expect(later(), findsNothing);
    expect(
      tester.getSize(updateNow()).height,
      greaterThanOrEqualTo(56),
      reason: 'rider primary actions are at least 56 dp',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);

    await tester.tap(updateNow());
    await tester.pumpAndSettle();
    expect(h.urls.opened, [
      Uri.parse('https://play.google.com/store/apps/details?id=in.jivo.rider'),
    ]);
    expect(h.signals.current, isA<AppUpdateRequired>());
  });

  testWidgets('a 426 from any call switches to the force-update screen', (
    tester,
  ) async {
    await h.pump(tester);
    expect(find.text('Log in to Jivo Rider'), findsOneWidget);

    h.signals.reportUpdateRequired(
      AppUpdateRequired(
        minSupportedVersion: '1.2.0',
        storeUrl: Uri.parse('https://example.com/store'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(later(), findsNothing);
    await tester.tap(updateNow());
    expect(h.urls.opened.single, Uri.parse('https://example.com/store'));
  });

  testWidgets('optional update: dismissible prompt, Later continues', (
    tester,
  ) async {
    h.config = FakeAppConfigRepository(
      scenario: FakeConfigScenario.softUpdate,
      delay: Duration.zero,
    );
    await h.pump(tester);

    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(later());
    await tester.pumpAndSettle();

    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
  });

  testWidgets('maintenance shows the server message; Try again continues '
      'once config/app says maintenance is over', (tester) async {
    h.config = FakeAppConfigRepository(
      scenario: FakeConfigScenario.maintenance,
      delay: Duration.zero,
    );
    await h.pump(tester);

    expect(find.text("We'll be back soon"), findsOneWidget);
    expect(
      find.text(
        'Jivo is down for scheduled maintenance. We will be back by 6:00 AM.',
      ),
      findsOneWidget,
    );

    // Still under maintenance: stays.
    await tester.tap(find.byKey(const Key('maintenance-retry')));
    await tester.pumpAndSettle();
    expect(find.text("We'll be back soon"), findsOneWidget);

    // Maintenance is over: Try again re-reads config/app, which clears the
    // signal, and the app continues.
    h.config.scenario = FakeConfigScenario.normal;
    await tester.tap(find.byKey(const Key('maintenance-retry')));
    await tester.pumpAndSettle();
    expect(h.signals.current, isNull);
    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
  });

  testWidgets('a 503 without a message shows the default text', (tester) async {
    await h.pump(tester);
    h.signals.reportMaintenance(const MaintenanceMode());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Jivo Rider is under maintenance. Please try again in a little while.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('config/app failure: error with Retry, never continues without '
      'config', (tester) async {
    h.config.failWith = const ApiError(code: ApiErrorCode.network);
    await h.pump(tester);

    expect(find.text("Couldn't connect"), findsOneWidget);
    expect(find.text('Log in to Jivo Rider'), findsNothing);
    expect(h.config.fetchCount, 1, reason: 'no automatic retry');

    h.config.failWith = null;
    await tester.tap(find.byKey(const Key('splash-retry')));
    await tester.pumpAndSettle();

    expect(h.config.fetchCount, 2);
    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
  });

  testWidgets('storeUriOf falls back to the rider app listing', (tester) async {
    expect(storeUriOf(null), fallbackStoreUrl);
  });
}
