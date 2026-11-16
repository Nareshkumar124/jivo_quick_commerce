import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/earnings/presentation/earnings_screen.dart';
import 'package:rider_app/features/shift/presentation/home_screen.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

const _menu = [
  'home-earnings',
  'home-cash',
  'home-history',
  'home-payouts',
  'home-profile',
];

void main() {
  testWidgets('dev: home lists the records, 56 dp each', (tester) async {
    final h = RiderTestHarness();
    await pumpActiveHome(tester, h);
    for (final key in _menu) {
      await scrollTo(tester, byKey(key), listKey: const Key('home-list'));
      expect(tester.getSize(byKey(key)).height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('prod: the same records menu, and the routes open', (
    tester,
  ) async {
    final h = RiderTestHarness(flavor: Flavor.prod);
    await pumpActiveHome(tester, h);
    for (final key in _menu) {
      await scrollTo(tester, byKey(key), listKey: const Key('home-list'));
      expect(byKey(key), findsOneWidget, reason: key);
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(routerProvider).go(Routes.earnings);
    await tester.pumpAndSettle();
    expect(find.byType(EarningsScreen), findsOneWidget);
  });

  test('prod never runs the fakes: AppEnv drops FAKE_API there', () {
    final env = AppEnv.resolve(
      flavor: Flavor.prod,
      apiBaseUrl: 'https://api.example.test',
      useFakeApi: true,
    );
    expect(env.useFakeApi, isFalse);
  });

  testWidgets('during a task the records are out of reach', (tester) async {
    final h = RiderTestHarness();
    h.tasks.seedTask(h.tasks.newTask(status: TaskStatus.pickedUp));
    await h.signedInBefore(activeRiderPhone);
    await h.pump(tester);

    expect(find.text('Deliver to the customer'), findsOneWidget);
    expect(byKey('home-earnings'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Deliver to the customer')),
    );
    container.read(routerProvider).go(Routes.cash);
    await tester.pumpAndSettle();
    expect(find.text('Deliver to the customer'), findsOneWidget);
    expect(h.cash.calls, isEmpty);
  });
}
