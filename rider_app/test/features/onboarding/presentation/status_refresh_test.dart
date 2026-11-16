import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

/// UX audit RA-06: "Documents under review" was a dead end. The status is
/// now checked again on every return to the app, the static screen
/// (staging, prod, SUSPENDED) has "Check status", and support can be
/// called while waiting.
void main() {
  Finder byKey(String key) => find.byKey(Key(key));

  /// The app went to the background and came back.
  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  group('application status (dev, the rider API)', () {
    late RiderTestHarness h;

    setUp(() => h = RiderTestHarness());

    testWidgets('approved while the rider was away: shown on return', (
      tester,
    ) async {
      await h.signedInBefore(pendingPhone);
      await h.pump(tester);
      expect(find.text('Documents under review'), findsOneWidget);
      // While waiting the rider can call support (not only after a
      // rejection).
      expect(byKey('call-support'), findsOneWidget);

      h.onboarding.approveCurrent();
      await resume(tester);
      expect(find.text("You're approved!"), findsOneWidget);
    });
  });

  group('static status screen (prod)', () {
    late RiderTestHarness h;

    setUp(() => h = RiderTestHarness(flavor: Flavor.prod));

    testWidgets('"Check status" follows an approval to home', (tester) async {
      await h.signedInBefore(pendingPhone);
      await h.pump(tester);
      expect(find.text('Documents under review'), findsOneWidget);
      expect(byKey('call-support'), findsOneWidget);

      h.backend.riderStatusChange = RiderStatusEnum.ACTIVE;
      await tester.tap(byKey('status-check'));
      await tester.pumpAndSettle();
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('a failed check stays on the screen and says why', (
      tester,
    ) async {
      await h.signedInBefore(pendingPhone);
      await h.pump(tester);
      h.backend.fetchMeError = const ApiError(code: ApiErrorCode.network);
      await tester.tap(byKey('status-check'));
      await tester.pumpAndSettle();
      expect(find.text('Documents under review'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(h.session.isSignedIn, isTrue);
    });

    testWidgets('a return to the app checks again', (tester) async {
      await h.signedInBefore(pendingPhone);
      await h.pump(tester);
      h.backend.riderStatusChange = RiderStatusEnum.ACTIVE;
      await resume(tester);
      expect(byKey('home-flavor'), findsOneWidget);
    });
  });
}
