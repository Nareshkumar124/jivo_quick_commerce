import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/features/location/presentation/location_debug_controller.dart';
import 'package:rider_app/features/onboarding/presentation/onboarding_providers.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_block.dart';
import 'package:rider_app/features/task/presentation/task_providers.dart';

import '../../../helpers/rider_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fakes run in the dev flavor only (DL-30)', () {
    ProviderContainer containerFor(Flavor flavor, {required bool fakeApi}) {
      final c = ProviderContainer(
        overrides: [
          appEnvProvider.overrideWithValue(
            AppEnv(
              flavor: flavor,
              apiBaseUrl: Uri.parse('https://api.example.test'),
              useFakeApi: fakeApi,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('dev: offer/task and onboarding fakes, with or without FAKE_API', () {
      for (final fakeApi in [true, false]) {
        final c = containerFor(Flavor.dev, fakeApi: fakeApi);
        expect(c.read(riderWorkEnabledProvider), isTrue);
        expect(c.read(riderOnboardingEnabledProvider), isTrue);
      }
    });

    test('staging with FAKE_API=true (and prod): never', () {
      for (final flavor in [Flavor.staging, Flavor.prod]) {
        final c = containerFor(flavor, fakeApi: true);
        expect(c.read(riderWorkEnabledProvider), isFalse, reason: '$flavor');
        expect(
          c.read(riderOnboardingEnabledProvider),
          isFalse,
          reason: '$flavor',
        );
      }
    });
  });

  test('going offline is refused during a task (rule 7)', () async {
    final h = RiderTestHarness();
    h.tasks.seedTask(h.tasks.newTask(status: TaskStatus.pickedUp));
    await h.signedInBefore('+919811122231');
    final c = await h.container();
    c.read(taskBlocksGoingOfflineProvider.notifier).set(true);
    h.location.running = true;
    c.listen(locationDebugControllerProvider, (_, _) {});

    await c.read(locationDebugControllerProvider.notifier).goOffline();

    expect(
      c.read(locationDebugControllerProvider).error,
      LocationDebugError.taskActive,
    );
    expect(h.location.running, isTrue, reason: 'the service keeps running');

    c.read(taskBlocksGoingOfflineProvider.notifier).set(false);
    await c.read(locationDebugControllerProvider.notifier).goOffline();
    expect(h.location.running, isFalse);
  });

  testWidgets('the dev screen says why going offline was refused', (
    tester,
  ) async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    await h.pump(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('home-flavor'))),
    );
    c.read(taskBlocksGoingOfflineProvider.notifier).set(true);
    h.location.running = true;
    await c.read(locationDebugControllerProvider.notifier).syncWithService();
    await c.read(locationDebugControllerProvider.notifier).goOffline();
    expect(
      c.read(locationDebugControllerProvider).error,
      LocationDebugError.taskActive,
    );
  });
}
