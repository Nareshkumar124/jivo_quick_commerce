import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/cash/data/fake_cash_backend.dart';
import 'package:rider_app/features/cash/presentation/cash_providers.dart';
import 'package:rider_app/features/earnings/data/fake_earnings_backend.dart';
import 'package:rider_app/features/earnings/presentation/earnings_providers.dart';
import 'package:rider_app/features/history/data/fake_history_backend.dart';
import 'package:rider_app/features/history/presentation/history_providers.dart';
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

  for (final flavor in [Flavor.staging, Flavor.prod]) {
    group('${flavor.name} (even with FAKE_API)', () {
      testWidgets('no records menu; a stray link goes home', (tester) async {
        final h = RiderTestHarness(flavor: flavor);
        await pumpActiveHome(tester, h);
        for (final key in _menu) {
          expect(byKey(key), findsNothing, reason: key);
        }

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        container.read(routerProvider).go(Routes.earnings);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(h.earnings.calls, isEmpty);
      });

      test('the repositories never hand out a fake', () async {
        final h = RiderTestHarness(flavor: flavor);
        final container = await h.container();

        expect(
          container.read(earningsRepositoryProvider),
          isNot(isA<FakeEarningsBackend>()),
        );
        expect(
          container.read(cashRepositoryProvider),
          isNot(isA<FakeCashBackend>()),
        );
        expect(
          container.read(taskHistoryRepositoryProvider),
          isNot(isA<FakeHistoryBackend>()),
        );
        await expectLater(
          container.read(cashRepositoryProvider).fetchLedger(),
          throwsA(
            isA<ApiError>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.notFound,
            ),
          ),
        );
      });
    });
  }

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
