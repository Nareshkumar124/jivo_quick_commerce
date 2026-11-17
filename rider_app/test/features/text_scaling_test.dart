import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/offers/presentation/offer_screen.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/shift/domain/today_summary.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/shared/widgets/primary_action_bar.dart';

import '../helpers/fake_permissions_service.dart';
import '../helpers/onboarding_fixtures.dart';
import '../helpers/permission_fixtures.dart';
import '../helpers/records_helpers.dart';
import '../helpers/rider_app_harness.dart';

/// Rider rows of `design/system/text-scaling-checklist.md` §4.2 (RA-05,
/// RA-15, RA-16, offer): each screen at 1.0x, 1.3x and 2.0x on a 360x640 dp
/// phone (945x1680 px at 2.625). No overflow, and the key control is there.
void main() {
  const scales = [1.0, 1.3, 2.0];
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness()..surface = const Size(945, 1680));

  void scaleText(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final scale in [...scales, 1.5]) {
    final label = '${scale}x';

    testWidgets('history list and detail rows at $label', (tester) async {
      scaleText(tester, scale);
      await openFromHome(tester, h, 'home-history');
      await settle(tester);
      expect(byKey('history-600-status'), findsOneWidget);
      await tester.tap(byKey('history-600'));
      await settle(tester);
    });

    testWidgets('cash entries at $label', (tester) async {
      scaleText(tester, scale);
      await openFromHome(tester, h, 'home-cash');
      await settle(tester);
    });

    testWidgets('earnings rows at $label', (tester) async {
      scaleText(tester, scale);
      await openFromHome(tester, h, 'home-earnings');
      await settle(tester);
    });

    testWidgets('payouts at $label', (tester) async {
      scaleText(tester, scale);
      await openFromHome(tester, h, 'home-payouts');
      await settle(tester);
    });
  }

  for (final scale in scales) {
    final label = '${scale}x';

    testWidgets('documents tiles at $label', (tester) async {
      h.onboarding.seed(
        pendingPhone,
        pendingProfile(vehicle: VehicleType.bicycle),
      );
      await h.signedInBefore(pendingPhone);
      scaleText(tester, scale);
      await h.pump(tester);
      await tester.tap(byKey('status-next-step'));
      await settle(tester);
      await tester.scrollUntilVisible(
        byKey('doc-PHOTO'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      expect(byKey('doc-PHOTO-status'), findsOneWidget);
      final tile = tester.getRect(byKey('doc-PHOTO'));
      expect(tile.right, lessThanOrEqualTo(360.01));
      // The name keeps room: it is never squeezed to a few letters.
      expect(tile.width, greaterThan(300));
    });

    testWidgets('permissions gate rows at $label', (tester) async {
      await h.session.restore();
      scaleText(tester, scale);
      final perms = StubbedPermissions(freshInstall);
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
      await settle(tester);
      expect(find.text('Needed'), findsWidgets);
      await tester.scrollUntilVisible(
        byKey('gate-row-notifications'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      // Every row is a tap target of at least 64 dp.
      expect(
        tester.getSize(byKey('gate-row-notifications')).height,
        greaterThanOrEqualTo(64),
      );
    });

    testWidgets('offer with COD at 8 s left, $label', (tester) async {
      await h.signedInBefore('+919811122231');
      scaleText(tester, scale);
      await h.pump(tester);
      h.tasks.simulateOffer(cod: true);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byType(OfferScreen), findsOneWidget);
      h.now = h.now.add(const Duration(seconds: 22));
      await pumpFor(tester, const Duration(milliseconds: 1100));
      expect(tester.takeException(), isNull);
      final accept = tester.getRect(byKey('offer-accept'));
      expect(accept.bottom, lessThanOrEqualTo(640.01));
      expect(accept.height, greaterThanOrEqualTo(64));
    });
  }

  // P8 UX follow-ups (RA-03, RA-07, RA-13, RA-17, RA-23) at 1.3x and 2.0x.
  for (final scale in [1.3, 2.0]) {
    final label = '${scale}x';

    /// The whole rectangle of [key] is on the 360x640 dp screen.
    void expectOnScreen(WidgetTester tester, String key) {
      final rect = tester.getRect(byKey(key));
      expect(
        rect.top >= 0 && rect.bottom <= 640.01 && rect.right <= 360.01,
        isTrue,
        reason: '$key at $rect',
      );
    }

    testWidgets('RA-03 login: consent buttons and Get OTP at $label', (
      tester,
    ) async {
      scaleText(tester, scale);
      await h.pump(tester);
      await settle(tester);
      expectOnScreen(tester, 'login-get-otp');
      await tester.scrollUntilVisible(
        byKey('login-terms-button'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await settle(tester);
      expect(
        tester.getSize(byKey('login-terms-button')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('RA-07 registration: vehicle check mark at $label', (
      tester,
    ) async {
      await h.signedInBefore(nonePhone);
      scaleText(tester, scale);
      await h.pump(tester);
      await scrollTo(
        tester,
        byKey('register-vehicle-SCOOTER'),
        listKey: const Key('register-form'),
      );
      await tester.tap(byKey('register-vehicle-SCOOTER'));
      await settle(tester);
      expect(byKey('register-vehicle-SCOOTER-check'), findsOneWidget);
      // The mark sits inside its own tile.
      final tile = tester.getRect(byKey('register-vehicle-SCOOTER'));
      final check = tester.getRect(byKey('register-vehicle-SCOOTER-check'));
      expect(tile.contains(check.center), isTrue);
    });

    testWidgets('RA-13/RA-17 home: online status and deposit banner at '
        '$label', (tester) async {
      h.today.summary = const TodaySummary(
        deliveredCount: 9,
        earnedToday: '900.00',
        onlineSeconds: 3600,
        cashInHand: '4800.00',
        cashLimit: '5000.00',
        depositRequired: true,
        homeStoreName: 'Sector 18 Noida Dark Store, Gate 2',
      );
      h.extraOverrides = [
        permissionsServiceProvider.overrideWithValue(
          StubbedPermissions(allGranted).service,
        ),
      ];
      await h.signedInBefore(activeRiderPhone);
      scaleText(tester, scale);
      await h.pump(tester);
      await settle(tester);
      await tester.tap(byKey('shift-toggle'));
      await settle(tester);
      final body = tester.widget<Text>(byKey('shift-status-body'));
      expect(body.maxLines, 3);
      expect(body.semanticsLabel, body.data, reason: 'full text spoken');
      await scrollTo(
        tester,
        byKey('cash-limit-how'),
        listKey: const Key('home-list'),
      );
      await settle(tester);
      expect(byKey('cash-limit-banner'), findsOneWidget);
    });

    testWidgets('RA-17 cash screen: the shared deposit banner at $label', (
      tester,
    ) async {
      h.cash.limitReached = true;
      scaleText(tester, scale);
      await openFromHome(tester, h, 'home-cash');
      await settle(tester);
      expect(byKey('cash-limit-banner'), findsOneWidget);
      expect(tester.getRect(byKey('cash-limit-banner')).right, lessThan(361));
    });

    testWidgets('RA-23 inbox entries at $label', (tester) async {
      await h.signedInBefore(activeRiderPhone);
      scaleText(tester, scale);
      await h.pump(tester);
      await tester.tap(byKey('home-appbar-inbox'));
      await settle(tester);
      expect(byKey('inbox-3-icon'), findsOneWidget);
    });
  }

  // RD-12: every task step at 1.3x and 2.0x on 360x640: no overflow, and
  // the bar's primary action is fully on screen.
  for (final scale in [1.3, 2.0]) {
    final label = '${scale}x';

    void expectPrimaryOnScreen(WidgetTester tester) {
      final primary = find.descendant(
        of: find.byType(PrimaryActionBar),
        matching: find.byType(FilledButton),
      );
      expect(primary, findsOneWidget);
      final rect = tester.getRect(primary);
      expect(
        rect.top >= 0 && rect.bottom <= 640.01 && rect.right <= 360.01,
        isTrue,
        reason: 'primary at $rect',
      );
      expect(rect.height, greaterThanOrEqualTo(56));
    }

    for (final status in [
      TaskStatus.assigned,
      TaskStatus.atStore,
      TaskStatus.pickedUp,
      TaskStatus.atCustomer,
    ]) {
      testWidgets('task step ${status.name} (COD) at $label', (tester) async {
        h.tasks.seedTask(h.tasks.newTask(cod: true, status: status));
        await h.signedInBefore('+919811122231');
        scaleText(tester, scale);
        await h.pump(tester);
        await settle(tester);
        expectPrimaryOnScreen(tester);
      });
    }

    testWidgets('COD collect and UPI QR steps at $label', (tester) async {
      h.tasks.seedTask(
        h.tasks.newTask(cod: true, status: TaskStatus.atCustomer),
      );
      await h.signedInBefore('+919811122231');
      scaleText(tester, scale);
      await h.pump(tester);
      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tester.tap(byKey('otp-continue'));
      await settle(tester);
      expectPrimaryOnScreen(tester);

      await tester.tap(byKey('cod-upi'));
      await settle(tester);
      expectPrimaryOnScreen(tester);
    });
  }
}
