import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/data/foreground_location_service.dart';
import 'package:rider_app/features/location/data/location_service_protocol.dart';

import '../../../helpers/rider_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stopAndAwaitTeardown', () {
    test('returns only after the service says it is destroyed', () async {
      final data = StreamController<Object>.broadcast();
      var done = false;
      final stopping = stopAndAwaitTeardown(
        taskData: data.stream,
        requestStop: () async {},
        timeout: const Duration(seconds: 5),
      ).then((_) => done = true);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      data.add({'type': 'stats', 'stats': <String, Object>{}});
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: 'stats are not the teardown');

      data.add(LocationMessages.destroyed);
      await stopping;
      expect(done, isTrue);
    });

    test('a teardown sent during the stop request is not missed', () async {
      final data = StreamController<Object>.broadcast();
      await stopAndAwaitTeardown(
        taskData: data.stream,
        requestStop: () async => data.add(LocationMessages.destroyed),
        timeout: const Duration(seconds: 5),
      );
    });

    test(
      'gives up after the timeout (service killed without onDestroy)',
      () async {
        final data = StreamController<Object>.broadcast();
        final watch = Stopwatch()..start();
        await stopAndAwaitTeardown(
          taskData: data.stream,
          requestStop: () async {},
          timeout: const Duration(milliseconds: 50),
        );
        expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(45));
      },
    );
  });

  test(
    'sign-out deletes the buffer only after the service is torn down',
    () async {
      final events = <String>[];
      final h = RiderTestHarness();
      h.location
        ..running = true
        ..onStop = () async {
          events.add('stop requested');
          // The service's final flush and last buffer write.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          events.add('service torn down');
        };
      h.cleaner.onClear = () => events.add('buffer deleted');
      await h.signedInBefore('+919811122231');
      final c = await h.container();
      // The account controller registers the sign-out hook.
      c.read(riderAccountControllerProvider);

      await h.session.signOut(reason: SignOutReason.sessionExpired);

      expect(events, ['stop requested', 'service torn down', 'buffer deleted']);
    },
  );
}
