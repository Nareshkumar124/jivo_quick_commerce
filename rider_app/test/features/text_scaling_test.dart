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
}
