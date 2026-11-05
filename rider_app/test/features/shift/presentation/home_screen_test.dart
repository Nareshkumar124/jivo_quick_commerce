import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/shift/data/fake_today_summary.dart';
import 'package:rider_app/features/shift/domain/today_summary.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/permission_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

/// Rider home, `design/screens/rider/home.md` (UX audit RD-01).
void main() {
  late RiderTestHarness h;
  late StubbedPermissions perms;

  setUp(() {
    h = RiderTestHarness();
    perms = StubbedPermissions(allGranted);
    h.extraOverrides = [
      permissionsServiceProvider.overrideWithValue(perms.service),
    ];
  });

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).data!;

  Future<void> tapToggle(WidgetTester tester) async {
    await tester.tap(byKey('shift-toggle'));
    await tester.pumpAndSettle();
  }

  testWidgets('offline: status in words, a 72 dp "Go online" at the bottom', (
    tester,
  ) async {
    await pumpActiveHome(tester, h);
    expect(textOf(tester, 'shift-status'), "You're offline");
    expect(find.text("You won't get orders."), findsOneWidget);
    expect(find.text('Go online'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(tester.getSize(byKey('shift-toggle')).height, 72);
    // Bottom-pinned: below every body element.
    expect(
      tester.getRect(byKey('shift-toggle')).top,
      greaterThan(tester.getRect(byKey('shift-card')).bottom),
    );
  });

  testWidgets('going online and offline (fake shift API, service fake)', (
    tester,
  ) async {
    await pumpActiveHome(tester, h);
    await tapToggle(tester);

    expect(h.shift.online, isTrue);
    expect(h.location.running, isTrue);
    expect(textOf(tester, 'shift-status'), "You're online");
    expect(find.text('Waiting for orders near Sector 18.'), findsOneWidget);
    expect(find.text('Go offline'), findsOneWidget);
    expect(tester.getSize(byKey('shift-toggle')).height, 72);

    await tapToggle(tester);
    expect(h.location.running, isFalse);
    expect(h.shift.online, isFalse);
    expect(textOf(tester, 'shift-status'), "You're offline");
  });

  testWidgets('permissions missing: guard card, "Go online" disabled, '
      '"Fix permissions" opens the gate', (tester) async {
    perms.current = allGranted.copyWith(notifications: Grant.denied);
    await pumpActiveHome(tester, h);
    await tapToggle(tester);

    expect(h.shift.calls, isEmpty);
    expect(
      textOf(tester, 'shift-problem-text'),
      'Allow location and notifications',
    );
    final toggle = tester.widget<FilledButton>(byKey('shift-toggle'));
    expect(toggle.onPressed, isNull, reason: 'blocked by the guard');

    await tester.ensureVisible(byKey('shift-problem-action'));
    await tester.tap(byKey('shift-problem-action'));
    await tester.pumpAndSettle();
    expect(find.text('Before you go online'), findsOneWidget);
  });

  testWidgets('too far: the distances from the server error', (tester) async {
    h.shift.nextStartError = const ApiError(
      code: ApiErrorCode.outsideGeofence,
      statusCode: 422,
      details: {'distance_m': 3400, 'radius_m': 2000},
    );
    await pumpActiveHome(tester, h);
    await tapToggle(tester);

    expect(
      textOf(tester, 'shift-problem-text'),
      "You're too far from your store",
    );
    expect(
      find.text("You're 3.4 km from Sector 18. Go within 2 km to go online."),
      findsOneWidget,
    );
    expect(find.text('Navigate to store'), findsOneWidget);
    expect(h.location.running, isFalse);
  });

  testWidgets('a rejected document blocks going online: guard with '
      '"See documents" (DOCUMENTS_NOT_APPROVED)', (tester) async {
    h.shift.nextStartError = const ApiError(
      code: ApiErrorCode.invalidStateTransition,
      statusCode: 409,
      details: {
        'reason': 'DOCUMENTS_NOT_APPROVED',
        'doc_types': ['DL'],
      },
    );
    await pumpActiveHome(tester, h);
    await tapToggle(tester);
    expect(
      textOf(tester, 'shift-problem-text'),
      'Some documents need a new upload',
    );
    expect(find.text('See documents'), findsOneWidget);
    final toggle = tester.widget<FilledButton>(byKey('shift-toggle'));
    expect(toggle.onPressed, isNull);
  });

  testWidgets('a throttled go-online (429) reads calmly', (tester) async {
    h.shift.nextStartError = const ApiError(
      code: ApiErrorCode.rateLimited,
      statusCode: 429,
    );
    await pumpActiveHome(tester, h);
    await tapToggle(tester);
    expect(
      textOf(tester, 'shift-problem-text'),
      'Too many tries. Wait a moment, then try again.',
    );
  });

  testWidgets('auto-offline: "You were set offline" with the reason', (
    tester,
  ) async {
    h.location.pendingServerStop = 'RIDER_OFFLINE';
    await pumpActiveHome(tester, h);
    expect(textOf(tester, 'shift-status'), 'You were set offline');
    expect(find.textContaining('10 minutes'), findsOneWidget);

    await tester.tap(byKey('shift-auto-offline-close'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'shift-status'), "You're offline");
  });

  testWidgets('today tiles: server values; unknown values are "–", never 0', (
    tester,
  ) async {
    await pumpActiveHome(tester, h);
    expect(textOf(tester, 'today-delivered-value'), '6');
    expect(textOf(tester, 'today-earned-value'), '₹640');
    expect(textOf(tester, 'today-online-value'), '3h 5m');
    expect(textOf(tester, 'today-cash-value'), '₹1,840');
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('today tiles when a field is missing', (tester) async {
    h.today.summary = const TodaySummary(deliveredCount: 0);
    await pumpActiveHome(tester, h);
    expect(textOf(tester, 'today-delivered-value'), '0');
    expect(textOf(tester, 'today-earned-value'), '–');
    expect(textOf(tester, 'today-cash-value'), '–');
  });

  testWidgets('today tiles when the request fails: "–" and Retry', (
    tester,
  ) async {
    h.today.nextError = const ApiError(code: ApiErrorCode.network);
    await pumpActiveHome(tester, h);
    expect(textOf(tester, 'today-delivered-value'), '–');
    expect(byKey('today-retry'), findsOneWidget);

    await tester.tap(byKey('today-retry'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'today-delivered-value'), '6');
  });

  testWidgets('cash limit reached: deposit banner; going online still works '
      'and says prepaid only', (tester) async {
    h.today.summary = const TodaySummary(
      deliveredCount: 9,
      earnedToday: '900.00',
      onlineSeconds: 3600,
      cashInHand: '5200.00',
      cashLimit: '5000.00',
      limitReached: true,
      homeStoreName: 'Sector 18',
    );
    await pumpActiveHome(tester, h);
    expect(byKey('cash-limit-banner'), findsOneWidget);
    expect(find.textContaining('₹5,000'), findsOneWidget);

    await tapToggle(tester);
    expect(h.location.running, isTrue);
    expect(
      textOf(tester, 'shift-status'),
      "You're online: prepaid orders only",
    );
  });

  testWidgets('no text below 14 sp on home (RD-05)', (tester) async {
    await pumpActiveHome(tester, h);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final size = text.style?.fontSize;
      if (size != null) {
        expect(size, greaterThanOrEqualTo(14), reason: text.data);
      }
    }
  });

  testWidgets('200 % text on 360×640: the control stays reachable', (
    tester,
  ) async {
    await h.signedInBefore(activeRiderPhone);
    h.surface = const Size(945, 1680); // 360×640 dp at 2.625
    await h.pump(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(byKey('shift-toggle'), findsOneWidget);
    expect(
      tester.getSize(byKey('shift-toggle')).height,
      greaterThanOrEqualTo(72),
    );
  });

  test('FakeTodaySummary sample has every tile', () {
    const s = FakeTodaySummary.sample;
    expect([
      s.deliveredCount,
      s.earnedToday,
      s.onlineSeconds,
      s.cashInHand,
    ], everyElement(isNotNull));
    expect(formatOnlineTime(0), '0m');
    expect(formatOnlineTime(2700), '45m');
    expect(formatOnlineTime(19200), '5h 20m');
    expect(formatKm(1840), '1.8');
    expect(formatKm(2000), '2');
  });
}
